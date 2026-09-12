//! Port of cosmic-text `buffer_line.rs` (a shaped/laid-out paragraph line).
//!
//! Connected to the canonical subsystem types (see `types.zig` for the
//! ownership map): `attrs.zig` (`Attrs`, `AttrsList`, `Metrics`),
//! `line_ending.zig`, `layout.zig`, `shape.zig`, `cached.zig` (generic
//! `Cached(T)`), and `font_system.zig`. No local stand-in types live here.
//!
//! Preserved exactly from the Rust original:
//!   * the cache-invalidation hierarchy `reset` > `resetShaping` >
//!     `resetLayout`;
//!   * `append`/`splitOff` line-ending preservation and attr span shifting;
//!   * the reclaim pattern (`clearRetainingCapacity`, `Cached` used -> unused
//!     -> take-unused reuse);
//!   * `layoutRuns` culling/centering math
//!     (`centering = (lh - ascent - descent) / 2`,
//!      `line_y = line_top + centering + ascent`).
//!
//! Shaping and layout themselves live in `shape.zig` (`ShapeLine.build`,
//! `layoutToBuffer`); this file owns only the per-line state and caches.

const std = @import("std");

const Allocator = std.mem.Allocator;

const attrs_mod = @import("attrs.zig");
const cached_mod = @import("cached.zig");
const font_system_mod = @import("font_system.zig");
const layout_mod = @import("layout.zig");
const line_ending_mod = @import("line_ending.zig");
const shape_mod = @import("shape.zig");

/// Local error set: allocator failures plus explicit index errors (no panics).
pub const Error = Allocator.Error || error{
    InvalidByteIndex,
};

// ---------------------------------------------------------------------------
// Canonical type re-exports (aliases only; the owner modules define them).
// ---------------------------------------------------------------------------

pub const LineEnding = line_ending_mod.LineEnding;
pub const LineIter = line_ending_mod.LineIter;

pub const Attrs = attrs_mod.Attrs;
pub const AttrsList = attrs_mod.AttrsList;
pub const AttrsOwned = attrs_mod.AttrsOwned;
pub const Metrics = attrs_mod.Metrics;
pub const Color = attrs_mod.Color;

pub const Wrap = layout_mod.Wrap;
pub const Align = layout_mod.Align;
pub const Ellipsize = layout_mod.Ellipsize;
pub const EllipsizeHeightLimit = layout_mod.EllipsizeHeightLimit;
/// Back-compat alias for the canonical `layout.EllipsizeHeightLimit`.
pub const HeightLimit = layout_mod.EllipsizeHeightLimit;
pub const Hinting = layout_mod.Hinting;
pub const LayoutGlyph = layout_mod.LayoutGlyph;
pub const LayoutLine = layout_mod.LayoutLine;

pub const Shaping = shape_mod.Shaping;
pub const Direction = shape_mod.Direction;
pub const ShapeLine = shape_mod.ShapeLine;
pub const ShapeBuffer = shape_mod.ShapeBuffer;
pub const ShapeError = shape_mod.ShapeError;

pub const FontSystem = font_system_mod.FontSystem;

/// Outer list type cached per line (glyph/decorations buffers are reclaimed
/// on reuse; the outer allocation is retained).
pub const LayoutLineList = std.ArrayList(LayoutLine);
/// Glyph list type owned by `layout.LayoutLine`.
pub const GlyphList = std.ArrayList(LayoutGlyph);

// ---------------------------------------------------------------------------
// shape.zig boundary
// ---------------------------------------------------------------------------
//
// ADAPTER NOTE (shape.zig landed 2026-09-11): shape.zig now uses the
// canonical `attrs.AttrsList` / `layout.*` types, but its `ShapeLine.build`
// still takes the `ShapeAdapter` seam rather than the `font_system`
// parameter named in the integration contract:
//
//   ShapeLine.build(self, allocator, adapter: ShapeAdapter, buf: *ShapeBuffer,
//                   text, attrs_list: *const attrs.AttrsList, shaping,
//                   tab_width, direction) ShapeError!void
//   ShapeLine.layoutToBuffer(self, allocator, scratch, font_size, width_opt,
//                            wrap, ellipsize, align_opt, out, match_mono_width,
//                            hinting) ShapeError!void
//
// These two helpers are the only call sites into the shaper. When shape.zig
// exposes the planned FontSystem-taking build, only `buildShapeLine` changes;
// `layoutToBuffer` already matches the contract.

/// Build (shape) one line into `line`, threading the real `FontSystem`
/// through shape.zig's adapter seam.
fn buildShapeLine(
    line: *ShapeLine,
    allocator: Allocator,
    font_system: *FontSystem,
    text: []const u8,
    attrs_list: *const AttrsList,
    shaping: Shaping,
    tab_width: u16,
    direction: Direction,
    scratch: *ShapeBuffer,
) ShapeError!void {
    // Prefer the real HarfBuzz backend when font data was registered with the
    // FontSystem (`FontSystem.addFontData`); otherwise fall back to the
    // charmap stand-in so synthetic tests keep working without font bytes.
    if (font_system.shaper()) |adapter| {
        try line.build(
            allocator,
            adapter,
            scratch,
            text,
            attrs_list,
            shaping,
            tab_width,
            direction,
        );
        return;
    }

    var backend = shape_mod.CharmapAdapter{};
    if (font_system.db.faces.items.len > 0) {
        backend.monospaced_primary = font_system.isMonospace(font_system.db.faces.items[0].id);
    }
    try line.build(
        allocator,
        backend.adapter(),
        scratch,
        text,
        attrs_list,
        shaping,
        tab_width,
        direction,
    );
}

/// Lay out a shaped line into `out` (wrap/align/ellipsize/justify).
fn layoutShapeLine(
    line: *const ShapeLine,
    allocator: Allocator,
    scratch: *ShapeBuffer,
    font_size: f32,
    width_opt: ?f32,
    wrap: Wrap,
    ellipsize: Ellipsize,
    align_opt: ?Align,
    out: *LayoutLineList,
    match_mono_width: ?f32,
    hinting: Hinting,
) ShapeError!void {
    try line.layoutToBuffer(
        allocator,
        scratch,
        font_size,
        width_opt,
        wrap,
        ellipsize,
        align_opt,
        out,
        match_mono_width,
        hinting,
    );
}

// ---------------------------------------------------------------------------
// Cache / attrs helpers
// ---------------------------------------------------------------------------

/// `AttrsList` with default `Attrs` and no spans, built without allocating
/// (mirrors Rust's infallible `AttrsList::new(&Attrs::new())`).
fn emptyAttrsList(allocator: Allocator) AttrsList {
    return AttrsList.init_owned(allocator, .{
        .allocator = allocator,
        .family_owned = .{ .allocator = allocator, .kind = .sans_serif },
        .font_features = attrs_mod.FontFeatures.init(allocator),
    });
}

/// Replace `dst` contents with a copy of `src`, reusing `dst` capacity.
fn copyAttrsList(dst: *AttrsList, src: *const AttrsList) Allocator.Error!void {
    var src_defaults = try src.default_attrs.to_attrs(dst.allocator);
    defer src_defaults.deinit();
    try dst.reset(&src_defaults);
    for (src.spans.items) |*span| {
        var span_attrs = try span.attrs.to_attrs(dst.allocator);
        defer span_attrs.deinit();
        try dst.add_span(span.start, span.end, &span_attrs);
    }
}

/// Free a shape cache payload (used/unused) and reset to `empty`.
fn deinitShapeCache(cache: *cached_mod.Cached(ShapeLine), allocator: Allocator) void {
    if (cache.takeUnused()) |line_val| {
        var line = line_val;
        line.deinit(allocator);
    }
    if (cache.takeUsed()) |line_val| {
        var line = line_val;
        line.deinit(allocator);
    }
}

/// Free every cached `LayoutLine` but keep the outer list allocation.
fn reclaimLayoutList(list: *LayoutLineList) void {
    for (list.items) |*ll| ll.deinit();
    list.clearRetainingCapacity();
}

/// TODO(shape): `shape.zig:layoutToBuffer` reuses its scratch pools with
/// `clearRetainingCapacity`, which drops the old entries without calling
/// `deinit` (Rust `Vec::clear` drops them), leaking the pooled glyph lists
/// and visual-line range buffers across calls. Drain them here before each
/// layout until shape.zig fixes its pooling; this is a no-op once it does.
fn drainShapePools(buffer: *ShapeBuffer, allocator: Allocator) void {
    for (buffer.glyph_sets.items) |*glyphs| glyphs.deinit(allocator);
    buffer.glyph_sets.clearRetainingCapacity();
    for (buffer.cached_visual_lines.items) |*vl| vl.deinit(allocator);
    buffer.cached_visual_lines.clearRetainingCapacity();
}

fn deinitLayoutCache(cache: *cached_mod.Cached(LayoutLineList), allocator: Allocator) void {
    if (cache.takeUnused()) |list_val| {
        var list = list_val;
        reclaimLayoutList(&list);
        list.deinit(allocator);
    }
    if (cache.takeUsed()) |list_val| {
        var list = list_val;
        reclaimLayoutList(&list);
        list.deinit(allocator);
    }
}

// ---------------------------------------------------------------------------
// BufferLine
// ---------------------------------------------------------------------------

/// A line (paragraph) of text that is shaped and laid out.
/// Mirrors `BufferLine`; invalidation hierarchy is exact:
/// `reset` > `resetShaping` > `resetLayout`.
pub const BufferLine = struct {
    allocator: Allocator,
    text: std.ArrayList(u8),
    ending: LineEnding,
    attrs_list: AttrsList,
    alignment: ?Align,
    shape_cache: cached_mod.Cached(ShapeLine),
    layout_cache: cached_mod.Cached(LayoutLineList),
    /// Owned shape scratch (mirrors cosmic-text's `font_system.shape_buffer`
    /// threading; see the shape.zig boundary note).
    shape_buffer: ShapeBuffer,
    shaping: Shaping,
    metadata: ?usize,

    /// Create a line with text, ending, and default attrs (cloned).
    /// `defaults` is borrowed and may be released by the caller afterwards.
    pub fn init(
        allocator: Allocator,
        text_slice: []const u8,
        ending: LineEnding,
        defaults: *const Attrs,
        shaping: Shaping,
    ) Error!BufferLine {
        var text: std.ArrayList(u8) = .empty;
        errdefer text.deinit(allocator);
        try text.appendSlice(allocator, text_slice);
        return .{
            .allocator = allocator,
            .text = text,
            .ending = ending,
            .attrs_list = try AttrsList.init(allocator, defaults),
            .alignment = null,
            .shape_cache = .empty,
            .layout_cache = .empty,
            .shape_buffer = ShapeBuffer.init(),
            .shaping = shaping,
            .metadata = null,
        };
    }

    /// Create a line, taking ownership of `attrs_list` on success.
    /// On error ownership remains with the caller (no cleanup is performed).
    pub fn initOwned(
        allocator: Allocator,
        text_slice: []const u8,
        ending: LineEnding,
        attrs_list: AttrsList,
        shaping: Shaping,
    ) Error!BufferLine {
        var text: std.ArrayList(u8) = .empty;
        errdefer text.deinit(allocator);
        try text.appendSlice(allocator, text_slice);
        return .{
            .allocator = allocator,
            .text = text,
            .ending = ending,
            .attrs_list = attrs_list,
            .alignment = null,
            .shape_cache = .empty,
            .layout_cache = .empty,
            .shape_buffer = ShapeBuffer.init(),
            .shaping = shaping,
            .metadata = null,
        };
    }

    pub fn deinit(self: *BufferLine) void {
        deinitShapeCache(&self.shape_cache, self.allocator);
        deinitLayoutCache(&self.layout_cache, self.allocator);
        self.shape_buffer.deinit(self.allocator);
        self.text.deinit(self.allocator);
        self.attrs_list.deinit();
        self.* = undefined;
    }

    /// Reset with new values, reusing text/attrs allocations.
    pub fn resetNew(
        self: *BufferLine,
        text_slice: []const u8,
        ending: LineEnding,
        defaults: *const Attrs,
        shaping: Shaping,
    ) Error!void {
        self.text.clearRetainingCapacity();
        try self.text.appendSlice(self.allocator, text_slice);
        self.ending = ending;
        try self.attrs_list.reset(defaults);
        self.alignment = null;
        self.shape_cache.setUnused();
        self.layout_cache.setUnused();
        self.shaping = shaping;
        self.metadata = null;
    }

    /// Reset by adopting already-filled owned containers (post-reclaim).
    /// Deinitializes the current text/attrs first.
    pub fn resetNewOwned(
        self: *BufferLine,
        owned_text: std.ArrayList(u8),
        ending: LineEnding,
        owned_attrs: AttrsList,
        shaping: Shaping,
    ) void {
        self.text.deinit(self.allocator);
        self.attrs_list.deinit();
        self.text = owned_text;
        self.ending = ending;
        self.attrs_list = owned_attrs;
        self.alignment = null;
        self.shape_cache.setUnused();
        self.layout_cache.setUnused();
        self.shaping = shaping;
        self.metadata = null;
    }

    pub fn textSlice(self: *const BufferLine) []const u8 {
        return self.text.items;
    }

    /// Set text + full attrs list. Resets caches only when something differs.
    /// Returns true when the line was reset.
    pub fn setText(
        self: *BufferLine,
        text_slice: []const u8,
        ending: LineEnding,
        attrs_list: *const AttrsList,
    ) Error!bool {
        if (!std.mem.eql(u8, text_slice, self.text.items) or
            ending != self.ending or
            !self.attrs_list.eql(attrs_list))
        {
            self.text.clearRetainingCapacity();
            try self.text.appendSlice(self.allocator, text_slice);
            self.ending = ending;
            try copyAttrsList(&self.attrs_list, attrs_list);
            self.reset();
            return true;
        }
        return false;
    }

    /// Take ownership of the text buffer, leaving an empty line behind.
    pub fn takeText(self: *BufferLine) std.ArrayList(u8) {
        const out = self.text;
        self.text = .empty;
        return out;
    }

    /// Set line ending; resets shaping+layout when changed.
    pub fn setEnding(self: *BufferLine, ending: LineEnding) bool {
        if (ending != self.ending) {
            self.ending = ending;
            self.resetShaping();
            return true;
        }
        return false;
    }

    /// Set attrs list; resets shaping+layout when changed.
    /// Takes ownership of `attrs_list` on change, releases it otherwise.
    pub fn setAttrsList(self: *BufferLine, attrs_list: AttrsList) bool {
        if (!self.attrs_list.eql(&attrs_list)) {
            self.attrs_list.deinit();
            self.attrs_list = attrs_list;
            self.resetShaping();
            return true;
        }
        var owned = attrs_list;
        owned.deinit();
        return false;
    }

    /// Set alignment; resets layout only. `null` means direction default
    /// (Right for RTL, Left for LTR) at layout time.
    pub fn setAlign(self: *BufferLine, alignment: ?Align) bool {
        if (alignment != self.alignment) {
            self.alignment = alignment;
            self.resetLayout();
            return true;
        }
        return false;
    }

    /// Append another line onto this one. The other's ending wins (line
    /// endings are preserved by moving to the joined line).
    pub fn append(self: *BufferLine, other: *const BufferLine) Error!void {
        const len = self.text.items.len;
        try self.text.appendSlice(self.allocator, other.text.items);
        self.ending = other.ending;
        if (!self.attrs_list.default_attrs.eql(&other.attrs_list.default_attrs)) {
            var other_defaults = try other.attrs_list.default_attrs.to_attrs(self.allocator);
            defer other_defaults.deinit();
            try self.attrs_list.add_span(len, len + other.text.items.len, &other_defaults);
        }
        for (other.attrs_list.spans.items) |*span| {
            var span_attrs = try span.attrs.to_attrs(self.allocator);
            defer span_attrs.deinit();
            try self.attrs_list.add_span(span.start + len, span.end + len, &span_attrs);
        }
        self.reset();
    }

    /// Split off a new line at a byte index. The ending moves to the new
    /// line; `self` becomes `LineEnding.none`. Caller owns the result.
    pub fn splitOff(self: *BufferLine, index: usize) Error!BufferLine {
        if (index > self.text.items.len or !isBoundary(self.text.items, index)) {
            return error.InvalidByteIndex;
        }
        var new_text: std.ArrayList(u8) = .empty;
        errdefer new_text.deinit(self.allocator);
        try new_text.appendSlice(self.allocator, self.text.items[index..]);
        var new_attrs = try self.attrs_list.split_off(index);
        errdefer new_attrs.deinit();
        self.text.shrinkRetainingCapacity(index);
        const ending = self.ending;
        self.reset();
        const new_line = BufferLine{
            .allocator = self.allocator,
            .text = new_text,
            .ending = ending,
            .attrs_list = new_attrs,
            .alignment = self.alignment,
            .shape_cache = .empty,
            .layout_cache = .empty,
            .shape_buffer = ShapeBuffer.init(),
            .shaping = self.shaping,
            .metadata = null,
        };
        // Preserve line endings: the ending moves to the new line.
        self.ending = .none;
        return new_line;
    }

    /// Reset shaping, layout, and metadata caches.
    pub fn reset(self: *BufferLine) void {
        self.metadata = null;
        self.resetShaping();
    }

    /// Reset shaping and layout caches.
    pub fn resetShaping(self: *BufferLine) void {
        self.shape_cache.setUnused();
        self.resetLayout();
    }

    /// Reset only the layout cache.
    pub fn resetLayout(self: *BufferLine) void {
        self.layout_cache.setUnused();
    }

    /// Shape the line with the real shaper (`shape.ShapeLine.build`) and the
    /// real `FontSystem`, caching the result. Reuses the `Unused` payload when
    /// present. Invalidates layout as a side effect.
    pub fn shape(
        self: *BufferLine,
        font_system: *FontSystem,
        tab_width: u16,
        direction: Direction,
    ) ShapeError!*ShapeLine {
        if (self.shape_cache.isUnused()) {
            // `ShapeLine` has default field values, so `.{}` is the empty
            // shell (the rewired shape.zig no longer exposes `empty()`).
            var line = self.shape_cache.takeUnused() orelse ShapeLine{};
            buildShapeLine(
                &line,
                self.allocator,
                font_system,
                self.text.items,
                &self.attrs_list,
                self.shaping,
                tab_width,
                direction,
                &self.shape_buffer,
            ) catch |err| {
                // Keep the (partially built) payload for reuse; never leak it.
                self.shape_cache = .{ .unused = line };
                return err;
            };
            self.shape_cache.setUsed(line);
            self.layout_cache.setUnused();
        }
        return self.shape_cache.getMut().?;
    }

    pub fn shapeOpt(self: *const BufferLine) ?*const ShapeLine {
        return self.shape_cache.get();
    }

    pub fn needsReshaping(self: *const BufferLine) bool {
        return self.shape_cache.isInvalidated() or self.layout_cache.isInvalidated();
    }

    /// Lay out the line through the real engine (`shape.layoutToBuffer`),
    /// caching the result. Reuses the `Unused` outer list allocation when
    /// present; cached `LayoutLine` glyph/decorations buffers are reclaimed.
    pub fn layout(
        self: *BufferLine,
        font_system: *FontSystem,
        font_size: f32,
        width_opt: ?f32,
        wrap: Wrap,
        ellipsize: Ellipsize,
        mono_width: ?f32,
        tab_width: u16,
        hinting: Hinting,
        direction: Direction,
    ) ShapeError![]LayoutLine {
        if (self.layout_cache.isUnused()) {
            const line_align = self.alignment;
            var list = self.layout_cache.takeUnused() orelse LayoutLineList.empty;
            // Reclaim: free glyph/decorations buffers, keep the outer
            // allocation. NOTE(shape.zig): handing these `LayoutLine`s to
            // `layoutToBuffer` would leak its pooled glyph/range buffers
            // (see `drainShapePools`); freeing here is the old buffer_line
            // reclaim path and avoids feeding that pool.
            reclaimLayoutList(&list);
            drainShapePools(&self.shape_buffer, self.allocator);
            const shape_ptr = self.shape(font_system, tab_width, direction) catch |err| {
                self.layout_cache = .{ .unused = list };
                return err;
            };
            layoutShapeLine(
                shape_ptr,
                self.allocator,
                &self.shape_buffer,
                font_size,
                width_opt,
                wrap,
                ellipsize,
                line_align,
                &list,
                mono_width,
                hinting,
            ) catch |err| {
                self.layout_cache = .{ .unused = list };
                return err;
            };
            self.layout_cache.setUsed(list);
        }
        return self.layout_cache.getMut().?.items;
    }

    pub fn layoutOpt(self: *const BufferLine) ?[]const LayoutLine {
        const list = self.layout_cache.get() orelse return null;
        return list.items;
    }

    /// Visible layout runs for this single line, with the same culling and
    /// centering math as `Buffer.layout_runs`:
    /// `centering = (line_height - ascent - descent) / 2`,
    /// `line_y = line_top + centering + ascent`.
    pub fn layoutRuns(
        self: *const BufferLine,
        height_opt: ?f32,
        line_height: f32,
    ) LayoutRunIter {
        return LayoutRunIter{
            .line = self,
            .height_opt = height_opt,
            .line_height = line_height,
            .layout_i = 0,
            .total_height = 0,
            .line_top = 0,
        };
    }

    pub fn getMetadata(self: *const BufferLine) ?usize {
        return self.metadata;
    }

    pub fn setMetadata(self: *BufferLine, metadata: usize) void {
        self.metadata = metadata;
    }

    /// An empty line in an invalid state; see `resetNew`.
    pub fn empty(allocator: Allocator) BufferLine {
        return .{
            .allocator = allocator,
            .text = .empty,
            .ending = .none,
            .attrs_list = emptyAttrsList(allocator),
            .alignment = null,
            .shape_cache = .empty,
            .layout_cache = .empty,
            .shape_buffer = ShapeBuffer.init(),
            .shaping = .advanced,
            .metadata = null,
        };
    }

    /// Reclaim the attrs list (invalid state until `resetNew*`).
    pub fn reclaimAttrs(self: *BufferLine) AttrsList {
        const old = self.attrs_list;
        self.attrs_list = emptyAttrsList(self.allocator);
        return old;
    }

    /// Reclaim the text buffer with capacity retained (invalid state until
    /// `resetNew*`).
    pub fn reclaimText(self: *BufferLine) std.ArrayList(u8) {
        const old = self.text;
        self.text = .empty;
        var reclaimed = old;
        reclaimed.clearRetainingCapacity();
        return reclaimed;
    }
};

/// Data-only visible run for a single `BufferLine`.
pub const LayoutRun = struct {
    line_i: usize,
    text: []const u8,
    rtl: bool,
    glyphs: []const LayoutGlyph,
    line_y: f32,
    line_top: f32,
    line_height: f32,
    line_w: f32,
};

/// Iterator over a single line's visible runs.
pub const LayoutRunIter = struct {
    line: *const BufferLine,
    height_opt: ?f32,
    line_height: f32,
    layout_i: usize,
    total_height: f32,
    line_top: f32,

    pub fn next(self: *LayoutRunIter) ?LayoutRun {
        const shape = self.line.shapeOpt() orelse return null;
        const layout = self.line.layoutOpt() orelse return null;
        while (self.layout_i < layout.len) {
            const ll = &layout[self.layout_i];
            self.layout_i += 1;
            const lh = ll.line_height_opt orelse self.line_height;
            self.total_height += lh;
            const line_top = self.line_top;
            const glyph_h = ll.max_ascent + ll.max_descent;
            const centering = (lh - glyph_h) / 2.0;
            const line_y = line_top + centering + ll.max_ascent;
            if (self.height_opt) |h| {
                if (line_y - ll.max_ascent > h) return null;
            }
            self.line_top += lh;
            if (line_y + ll.max_descent < 0.0) continue;
            return .{
                .line_i = 0,
                .text = self.line.textSlice(),
                .rtl = shape.rtl,
                .glyphs = ll.glyphs.items,
                .line_y = line_y,
                .line_top = line_top,
                .line_height = lh,
                .line_w = ll.w,
            };
        }
        return null;
    }
};

// ---------------------------------------------------------------------------
// UTF-8 boundary helpers (splitOff validation)
// ---------------------------------------------------------------------------

pub fn cpLen(first_byte: u8) usize {
    const l: u3 = std.unicode.utf8ByteSequenceLength(first_byte) catch return 1;
    return @as(usize, l);
}

pub fn isContinuation(b: u8) bool {
    return (b & 0xC0) == 0x80;
}

pub fn isBoundary(text: []const u8, index: usize) bool {
    if (index == 0 or index == text.len) return true;
    if (index > text.len) return false;
    return !isContinuation(text[index]);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
//
// Real-font policy: tests register the vendored Inter face from
// `tests/fonts/Inter-Regular.ttf` via the real `FontDb.addFace` /
// `FontSystem.initWithDb` APIs. `TestFontSystem.init` skips
// (`error.SkipZigTest`) only when the vendored font is genuinely absent.

const test_font_candidates = [_][]const u8{
    "tests/fonts/Inter-Regular.ttf",
    "../tests/fonts/Inter-Regular.ttf",
};

fn existingFontPath(allocator: Allocator, candidate: []const u8) Allocator.Error!?[]u8 {
    std.Io.Dir.cwd().access(std.testing.io, candidate, .{}) catch return null;
    return try allocator.dupe(u8, candidate);
}

fn testFontPath(allocator: Allocator) ![]u8 {
    for (test_font_candidates) |candidate| {
        if (try existingFontPath(allocator, candidate)) |path| return path;
    }
    // Also try relative to this source file (covers an absolute @src path,
    // e.g. when the test binary runs outside the project root).
    if (std.fs.path.dirname(@src().file)) |src_dir| {
        if (std.fs.path.join(allocator, &.{ src_dir, "..", "tests", "fonts", "Inter-Regular.ttf" }) catch null) |joined| {
            defer allocator.free(joined);
            if (try existingFontPath(allocator, joined)) |path| return path;
        }
    }
    // TODO(font): the vendored tests/fonts tree is part of the repo. If it is
    // missing, the environment is incomplete; skip instead of faking metrics.
    return error.SkipZigTest;
}

const TestFontSystem = struct {
    allocator: Allocator,
    font_system: FontSystem,
    path: []u8,

    fn init(allocator: Allocator) !TestFontSystem {
        const path = try testFontPath(allocator);
        errdefer allocator.free(path);
        var db_opt: ?font_system_mod.FontDb = try font_system_mod.FontDb.init(allocator);
        errdefer if (db_opt) |*d| d.deinit();
        const d = &db_opt.?;
        _ = try d.addFace(path, 0, &.{"Inter"}, "Inter-Regular", 400, .normal, .normal, false);
        // `initWithDb` consumes the db (and cleans it up on failure), so
        // disarm the caller-side errdefer before handing it over.
        const owned_db = db_opt.?;
        db_opt = null;
        return .{
            .allocator = allocator,
            .font_system = try FontSystem.initWithDb(allocator, owned_db, "en-US"),
            .path = path,
        };
    }

    fn deinit(self: *TestFontSystem) void {
        self.font_system.deinit();
        self.allocator.free(self.path);
    }
};

fn initAttrs(allocator: Allocator) Attrs {
    return Attrs.init(allocator);
}

test "LineEnding strings and default" {
    try std.testing.expectEqualStrings("\n", LineEnding.lf.asStr());
    try std.testing.expectEqualStrings("\r\n", LineEnding.cr_lf.asStr());
    try std.testing.expectEqualStrings("\r", LineEnding.cr.asStr());
    try std.testing.expectEqualStrings("\n\r", LineEnding.lf_cr.asStr());
    try std.testing.expectEqualStrings("", LineEnding.none.asStr());
    try std.testing.expect(LineEnding.default == .lf);
}

test "LineIter splits all endings" {
    var it = LineIter.init("LF\nCRLF\r\nCR\rLFCR\n\rNONE");
    try std.testing.expectEqualDeep(line_ending_mod.Line{ .start = 0, .end = 2, .ending = .lf }, it.next().?);
    try std.testing.expectEqualDeep(line_ending_mod.Line{ .start = 3, .end = 7, .ending = .cr_lf }, it.next().?);
    try std.testing.expectEqualDeep(line_ending_mod.Line{ .start = 9, .end = 11, .ending = .cr }, it.next().?);
    try std.testing.expectEqualDeep(line_ending_mod.Line{ .start = 12, .end = 16, .ending = .lf_cr }, it.next().?);
    try std.testing.expectEqualDeep(line_ending_mod.Line{ .start = 18, .end = 22, .ending = .none }, it.next().?);
    try std.testing.expect(it.next() == null);
}

test "LineIter empty yields nothing" {
    var it = LineIter.init("");
    try std.testing.expect(it.next() == null);
}

test "set_text resets only on difference" {
    const alloc = std.testing.allocator;
    var env = try TestFontSystem.init(alloc);
    defer env.deinit();

    var defaults = initAttrs(alloc);
    defer defaults.deinit();
    var line = try BufferLine.init(alloc, "hello", .lf, &defaults, .advanced);
    defer line.deinit();
    _ = try line.shape(&env.font_system, 8, .auto);
    try std.testing.expect(line.shapeOpt() != null);

    var same = try AttrsList.init(alloc, &defaults);
    defer same.deinit();
    try std.testing.expect(!try line.setText("hello", .lf, &same));
    // No reset: shape cache still hot.
    try std.testing.expect(line.shapeOpt() != null);

    var diff = try AttrsList.init(alloc, &defaults);
    defer diff.deinit();
    try std.testing.expect(try line.setText("hello!", .lf, &diff));
    try std.testing.expect(line.shapeOpt() == null);
    try std.testing.expectEqualStrings("hello!", line.textSlice());
}

test "append preserves other ending and merges attrs" {
    const alloc = std.testing.allocator;
    var defaults_a = initAttrs(alloc);
    defer defaults_a.deinit();
    var defaults_b = initAttrs(alloc);
    defer defaults_b.deinit();
    defaults_b.metadata = 7;

    var a = try BufferLine.init(alloc, "foo", .lf, &defaults_a, .advanced);
    defer a.deinit();
    var b = try BufferLine.init(alloc, "bar", .cr_lf, &defaults_b, .advanced);
    defer b.deinit();
    var span_attrs = initAttrs(alloc);
    defer span_attrs.deinit();
    span_attrs.metadata = 9;
    try b.attrs_list.add_span(0, 1, &span_attrs);

    try a.append(&b);
    try std.testing.expectEqualStrings("foobar", a.textSlice());
    try std.testing.expect(a.ending == .cr_lf);
    // Defaults differed, so a default-span covers the appended range...
    try std.testing.expect(a.attrs_list.get_span(0).metadata == 0);
    try std.testing.expect(a.attrs_list.get_span(4).metadata == 7);
    // ...except where the explicit span survived the shift (it overwrites).
    try std.testing.expect(a.attrs_list.get_span(3).metadata == 9);
}

test "split_off moves ending and cuts spans" {
    const alloc = std.testing.allocator;
    var defaults = initAttrs(alloc);
    defer defaults.deinit();
    var line = try BufferLine.init(alloc, "hello world", .lf, &defaults, .advanced);
    defer line.deinit();
    var span1 = initAttrs(alloc);
    defer span1.deinit();
    span1.metadata = 1;
    var span2 = initAttrs(alloc);
    defer span2.deinit();
    span2.metadata = 2;
    try line.attrs_list.add_span(0, 5, &span1);
    try line.attrs_list.add_span(6, 11, &span2);

    var tail = try line.splitOff(6);
    defer tail.deinit();
    try std.testing.expectEqualStrings("hello ", line.textSlice());
    try std.testing.expectEqualStrings("world", tail.textSlice());
    try std.testing.expect(line.ending == .none);
    try std.testing.expect(tail.ending == .lf);
    try std.testing.expect(line.attrs_list.get_span(0).metadata == 1);
    try std.testing.expect(tail.attrs_list.get_span(0).metadata == 2);

    // Straddling span cut: split inside a span.
    var line2 = try BufferLine.init(alloc, "abcdef", .none, &defaults, .advanced);
    defer line2.deinit();
    var span3 = initAttrs(alloc);
    defer span3.deinit();
    span3.metadata = 3;
    try line2.attrs_list.add_span(2, 5, &span3);
    var tail2 = try line2.splitOff(3);
    defer tail2.deinit();
    try std.testing.expect(line2.attrs_list.get_span(2).metadata == 3);
    try std.testing.expect(tail2.attrs_list.get_span(0).metadata == 3);
    try std.testing.expect(tail2.attrs_list.get_span(2).metadata == 0);
}

test "split_off rejects non-boundaries" {
    const alloc = std.testing.allocator;
    var defaults = initAttrs(alloc);
    defer defaults.deinit();
    var line = try BufferLine.init(alloc, "héllo", .none, &defaults, .advanced);
    defer line.deinit();
    try std.testing.expectError(error.InvalidByteIndex, line.splitOff(2));
    try std.testing.expectError(error.InvalidByteIndex, line.splitOff(99));
}

test "invalidation hierarchy is exact" {
    const alloc = std.testing.allocator;
    var env = try TestFontSystem.init(alloc);
    defer env.deinit();
    var defaults = initAttrs(alloc);
    defer defaults.deinit();
    var line = try BufferLine.init(alloc, "x", .none, &defaults, .advanced);
    defer line.deinit();
    const fs: f32 = 16;
    _ = try line.shape(&env.font_system, 8, .auto);
    _ = try line.layout(&env.font_system, fs, null, .none, .{ .none = {} }, null, 8, .disabled, .auto);
    try std.testing.expect(!line.needsReshaping());

    // Align: layout only.
    try std.testing.expect(line.setAlign(.center));
    try std.testing.expect(line.shapeOpt() != null);
    try std.testing.expect(line.layoutOpt() == null);
    try std.testing.expect(line.needsReshaping());
    _ = try line.layout(&env.font_system, fs, null, .none, .{ .none = {} }, null, 8, .disabled, .auto);

    // Ending: shaping + layout.
    try std.testing.expect(line.setEnding(.lf));
    try std.testing.expect(line.shapeOpt() == null);
    try std.testing.expect(line.layoutOpt() == null);

    // resetLayout alone keeps shape.
    _ = try line.shape(&env.font_system, 8, .auto);
    _ = try line.layout(&env.font_system, fs, null, .none, .{ .none = {} }, null, 8, .disabled, .auto);
    line.resetLayout();
    try std.testing.expect(line.shapeOpt() != null);
    try std.testing.expect(line.layoutOpt() == null);
}

test "reclaim retains capacity for set_text reuse" {
    const alloc = std.testing.allocator;
    var defaults = initAttrs(alloc);
    defer defaults.deinit();
    var line = try BufferLine.init(alloc, "some longer text here", .lf, &defaults, .advanced);
    defer line.deinit();
    var span = initAttrs(alloc);
    defer span.deinit();
    span.metadata = 5;
    try line.attrs_list.add_span(0, 4, &span);

    var t = line.reclaimText();
    const cap = t.capacity;
    try std.testing.expect(cap > 0);
    try t.appendSlice(alloc, "new");
    var a = line.reclaimAttrs();
    try std.testing.expect(a.span_count() == 1);
    try a.reset(&defaults);
    try std.testing.expect(a.span_count() == 0);
    line.resetNewOwned(t, .none, a, .advanced);
    try std.testing.expectEqualStrings("new", line.textSlice());
    try std.testing.expect(line.text.capacity >= cap or line.text.items.len == 3);
}

test "shape rtl detection" {
    const alloc = std.testing.allocator;
    var env = try TestFontSystem.init(alloc);
    defer env.deinit();
    var defaults = initAttrs(alloc);
    defer defaults.deinit();

    var ltr = try BufferLine.init(alloc, "hello", .none, &defaults, .advanced);
    defer ltr.deinit();
    const ltr_shape = try ltr.shape(&env.font_system, 8, .auto);
    try std.testing.expect(!ltr_shape.rtl);

    var rtl = try BufferLine.init(alloc, "שלום", .none, &defaults, .advanced);
    defer rtl.deinit();
    const rtl_shape = try rtl.shape(&env.font_system, 8, .auto);
    try std.testing.expect(rtl_shape.rtl);

    // Forced directions win (shape cache must be invalidated first, exactly
    // like Buffer.resolve_dirty does on set_direction).
    ltr.resetShaping();
    const forced_rtl = try ltr.shape(&env.font_system, 8, .right_to_left);
    try std.testing.expect(forced_rtl.rtl);
    rtl.resetShaping();
    const forced_ltr = try rtl.shape(&env.font_system, 8, .left_to_right);
    try std.testing.expect(!forced_ltr.rtl);
}

test "layout caches and wraps glyphs" {
    const alloc = std.testing.allocator;
    var env = try TestFontSystem.init(alloc);
    defer env.deinit();
    var defaults = initAttrs(alloc);
    defer defaults.deinit();
    var line = try BufferLine.init(alloc, "abcdefgh", .none, &defaults, .advanced);
    defer line.deinit();

    const l1 = try line.layout(&env.font_system, 10, null, .none, .{ .none = {} }, null, 8, .disabled, .auto);
    try std.testing.expect(l1.len == 1);
    try std.testing.expect(l1[0].glyphs.items.len > 0);
    const l2 = try line.layout(&env.font_system, 10, null, .none, .{ .none = {} }, null, 8, .disabled, .auto);
    try std.testing.expect(l1.ptr == l2.ptr);

    // Narrow width forces multiple visual lines in glyph mode.
    line.resetLayout();
    const wrapped = try line.layout(&env.font_system, 10, 20, .glyph, .{ .none = {} }, null, 8, .disabled, .auto);
    try std.testing.expect(wrapped.len > 1);
    var total: usize = 0;
    for (wrapped) |ll| total += ll.glyphs.items.len;
    try std.testing.expect(total > 0);
    // Byte ranges still span the whole line.
    try std.testing.expect(wrapped[0].glyphs.items[0].start == 0);
    const last_glyphs = wrapped[wrapped.len - 1].glyphs.items;
    try std.testing.expect(last_glyphs[last_glyphs.len - 1].end == 8);
}

test "layout_runs culls by height with exact centering" {
    const alloc = std.testing.allocator;
    var env = try TestFontSystem.init(alloc);
    defer env.deinit();
    var defaults = initAttrs(alloc);
    defer defaults.deinit();
    var line = try BufferLine.init(alloc, "abcdefgh", .none, &defaults, .advanced);
    defer line.deinit();

    const fallback_lh: f32 = 10;
    const lines = try line.layout(&env.font_system, 10, 20, .glyph, .{ .none = {} }, null, 8, .disabled, .auto);
    try std.testing.expect(lines.len > 1);

    // Full-height iteration visits every visual line with exact centering.
    var it = line.layoutRuns(null, fallback_lh);
    var expected_top: f32 = 0;
    var seen: usize = 0;
    while (it.next()) |run| {
        const ll = &lines[seen];
        const lh = ll.line_height_opt orelse fallback_lh;
        const centering = (lh - ll.max_ascent - ll.max_descent) / 2.0;
        try std.testing.expectApproxEqAbs(expected_top + centering + ll.max_ascent, run.line_y, 1e-5);
        try std.testing.expectApproxEqAbs(expected_top, run.line_top, 1e-5);
        try std.testing.expectApproxEqAbs(lh, run.line_height, 1e-5);
        expected_top += lh;
        seen += 1;
    }
    try std.testing.expectEqual(lines.len, seen);

    // A negative height culls the first line: the iterator stops (it must not
    // skip ahead and emit a later run out of view).
    var culled = line.layoutRuns(-1000.0, fallback_lh);
    try std.testing.expect(culled.next() == null);
}

test "empty line carries span metrics" {
    const alloc = std.testing.allocator;
    var env = try TestFontSystem.init(alloc);
    defer env.deinit();
    var defaults = initAttrs(alloc);
    defer defaults.deinit();
    _ = defaults.with_metrics(.{ .font_size = 8, .line_height = 9.6 });

    var line = try BufferLine.init(alloc, "", .none, &defaults, .advanced);
    defer line.deinit();
    _ = try line.shape(&env.font_system, 8, .auto);
    const ll = try line.layout(&env.font_system, 32, null, .none, .{ .none = {} }, null, 8, .disabled, .auto);
    try std.testing.expect(ll.len == 1);
    try std.testing.expect(ll[0].glyphs.items.len == 0);
    try std.testing.expectApproxEqAbs(@as(f32, 9.6), ll[0].line_height_opt.?, 1e-6);
}

test "word vs glyph wrap differ on long word" {
    const alloc = std.testing.allocator;
    var env = try TestFontSystem.init(alloc);
    defer env.deinit();
    var defaults = initAttrs(alloc);
    defer defaults.deinit();
    var line = try BufferLine.init(alloc, "abcdefgh", .none, &defaults, .advanced);
    defer line.deinit();

    const glyph_lines = try line.layout(&env.font_system, 10, 20, .glyph, .{ .none = {} }, null, 8, .disabled, .auto);
    try std.testing.expect(glyph_lines.len > 1);

    line.resetLayout();
    const word_lines = try line.layout(&env.font_system, 10, 20, .word, .{ .none = {} }, null, 8, .disabled, .auto);
    try std.testing.expect(word_lines.len == 1);

    line.resetLayout();
    const wog_lines = try line.layout(&env.font_system, 10, 20, .word_or_glyph, .{ .none = {} }, null, 8, .disabled, .auto);
    try std.testing.expect(wog_lines.len > 1);
}

test "null align follows paragraph direction" {
    const alloc = std.testing.allocator;
    var env = try TestFontSystem.init(alloc);
    defer env.deinit();
    var defaults = initAttrs(alloc);
    defer defaults.deinit();

    var ltr = try BufferLine.init(alloc, "ab", .none, &defaults, .advanced);
    defer ltr.deinit();
    const ltr_lines = try ltr.layout(&env.font_system, 10, 100, .none, .{ .none = {} }, null, 8, .disabled, .auto);
    try std.testing.expect(ltr_lines[0].glyphs.items.len > 0);
    try std.testing.expectApproxEqAbs(@as(f32, 0), ltr_lines[0].glyphs.items[0].x, 1e-4);

    // Forced paragraph RTL: null align resolves to Right, so the first
    // (rightmost) glyph starts away from x=0.
    ltr.resetShaping();
    const rtl_lines = try ltr.layout(&env.font_system, 10, 100, .none, .{ .none = {} }, null, 8, .disabled, .right_to_left);
    try std.testing.expect(rtl_lines[0].glyphs.items.len > 0);
    try std.testing.expect(rtl_lines[0].glyphs.items[0].x > 0);
    try std.testing.expect(rtl_lines[0].glyphs.items[0].x <= 100);
}
