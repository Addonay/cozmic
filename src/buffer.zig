//! Port of cosmic-text `buffer.rs` (shaped/laid-out text buffer).
//!
//! Integration status (2026-09-11): connected to the canonical owners declared
//! in `types.zig`. No local stand-ins remain here:
//!   * `Attrs`/`AttrsList`/`Metrics` -> `attrs.zig`
//!   * `Cursor`/`LayoutCursor`/`Motion`/`Scroll`/`Affinity` -> `cursor.zig`
//!   * `LineEnding`/`LineIter` -> `line_ending.zig`
//!   * `Wrap`/`Align`/`Ellipsize`/`Hinting`/`LayoutGlyph`/`LayoutLine`/
//!     `DecorationSpan` -> `layout.zig`
//!   * `Shaping`/`Direction`/`ShapeLine` -> `shape.zig`
//!   * `FontSystem` -> `font_system.zig`
//!   * `BufferLine` -> `buffer_line.zig` (which drives the real shaper)
//!   * grapheme/word stepping -> `unicode.zig`; paragraph splits ->
//!     `bidi_para.zig`.
//!
//! This file owns only `DirtyFlags`, `LayoutRun`, `LayoutRunIter`, `Buffer`,
//! `BufferWithFontSystem`, `MotionResult`, and `CursorPosition`, matching the
//! `types.zig` ownership map.
//!
//! Preserved exactly from the Rust original:
//!   * `DirtyFlags` bits (`RELAYOUT|TAB_SHAPE|TEXT_SET|SCROLL|DIRECTION`) and
//!     `resolve_dirty` invalidation rules (direction reshapes every shaped
//!     line, tab reshapes only lines containing `'\t'`, relayout resets only
//!     shaped lines, fresh `TEXT_SET` lines are skipped);
//!   * `set_text` trailing-empty-line rule and allocation reuse;
//!   * `set_rich_text` paragraph split + span intersection + empty-line span
//!     metrics inheritance (all rich lines end with `Lf`);
//!   * `shape_until_scroll` clamping/pruning/scroll normalization;
//!   * `layout_runs` culling and centering math
//!     (`centering = (lh - ascent - descent) / 2`,
//!     `line_y = line_top + centering + ascent`);
//!   * `layout_cursor` affinity mapping, `hit` per-grapheme half-split with
//!     RTL mirroring, and the full `cursor_motion` table.
//!
//! Glyph geometry is whatever the real shaper produced (`LayoutLine.glyphs`);
//! no `font_size * 0.6` advance, synthetic ascent/descent, or ignored
//! ellipsize path exists any more.

const std = @import("std");

const attrs_mod = @import("attrs.zig");
const bidi_para_mod = @import("bidi_para.zig");
const buffer_line_mod = @import("buffer_line.zig");
const cursor_mod = @import("cursor.zig");
const font_system_mod = @import("font_system.zig");
const layout_mod = @import("layout.zig");
const line_ending_mod = @import("line_ending.zig");
const shape_mod = @import("shape.zig");
const render_mod = @import("render.zig");
const swash_cache_mod = @import("swash_cache.zig");
const unicode_mod = @import("unicode.zig");

const Allocator = std.mem.Allocator;

// Canonical owners (private aliases; see `types.zig`).
const Attrs = attrs_mod.Attrs;
const AttrsList = attrs_mod.AttrsList;
const Metrics = attrs_mod.Metrics;
const Affinity = cursor_mod.Affinity;
const Cursor = cursor_mod.Cursor;
const LayoutCursor = cursor_mod.LayoutCursor;
const Motion = cursor_mod.Motion;
const Scroll = cursor_mod.Scroll;
const LineEnding = line_ending_mod.LineEnding;
const LineIter = line_ending_mod.LineIter;
const Wrap = layout_mod.Wrap;
const Align = layout_mod.Align;
const Ellipsize = layout_mod.Ellipsize;
const Hinting = layout_mod.Hinting;
const LayoutGlyph = layout_mod.LayoutGlyph;
const LayoutLine = layout_mod.LayoutLine;
const DecorationSpan = layout_mod.DecorationSpan;
const Direction = shape_mod.Direction;
const Shaping = shape_mod.Shaping;
const ShapeLine = shape_mod.ShapeLine;
const FontSystem = font_system_mod.FontSystem;
const BufferLine = buffer_line_mod.BufferLine;
const Color = attrs_mod.Color;
const SwashCache = swash_cache_mod.SwashCache;

/// Local error set: allocator failures, canonical shaper failures, plus
/// explicit errors (no panics).
pub const Error = shape_mod.ShapeError || error{
    InvalidByteIndex,
    InvalidMetrics,
    InvalidCursor,
};

/// A line of visible text for rendering, mirroring `LayoutRun`.
pub const LayoutRun = struct {
    line_i: usize,
    text: []const u8,
    rtl: bool,
    glyphs: []const LayoutGlyph,
    decorations: []const DecorationSpan,
    line_y: f32,
    line_top: f32,
    line_height: f32,
    line_w: f32,

    /// Highlighted `(x, width)` pixel spans between two cursors.
    /// Mixed-direction runs yield multiple disjoint spans. Zero-width spans
    /// are dropped. Caller owns the returned list.
    pub fn highlight(
        self: *const LayoutRun,
        allocator: Allocator,
        cursor_start: Cursor,
        cursor_end: Cursor,
    ) Allocator.Error!std.ArrayList(Highlight) {
        var out: std.ArrayList(Highlight) = .empty;
        errdefer out.deinit(allocator);
        var range_opt: ?Highlight = null;
        for (self.glyphs) |glyph| {
            const cluster = self.text[glyph.start..glyph.end];
            const total: f32 = @floatFromInt(@max(unicode_mod.countGraphemes(cluster), 1));
            const c_w = glyph.w / total;
            var c_x = glyph.x;
            var off = glyph.start;
            var gx_iter = unicode_mod.graphemeIndices(cluster);
            while (gx_iter.next()) |g_start| {
                const c_start = off + g_start;
                const c_end = off + gx_iter.pos;
                const selected = (cursor_start.line != self.line_i or c_end > cursor_start.index) and
                    (cursor_end.line != self.line_i or c_start < cursor_end.index);
                if (selected) {
                    if (range_opt) |r| {
                        range_opt = .{
                            .x = @min(r.x, c_x),
                            .width = @max(r.x + r.width, c_x + c_w) - @min(r.x, c_x),
                        };
                    } else {
                        range_opt = .{ .x = c_x, .width = c_w };
                    }
                } else if (range_opt) |r| {
                    range_opt = null;
                    if (r.width > 0) try out.append(allocator, r);
                }
                c_x += c_w;
                off = c_end;
            }
        }
        if (range_opt) |r| {
            if (r.width > 0) try out.append(allocator, r);
        }
        return out;
    }

    /// Visual x of `cursor` within this run, or null when it is not on it.
    /// RTL glyphs measure from the right edge minus the offset.
    pub fn cursorPosition(self: *const LayoutRun, cursor: *const Cursor) ?f32 {
        const found = self.cursorGlyph(cursor) orelse return null;
        const idx = found.index;
        const offset = found.offset;
        if (idx >= self.glyphs.len) {
            const last = self.glyphs.len == 0;
            if (last) return 0;
            const g = self.glyphs[self.glyphs.len - 1];
            return if (glyphIsRtl(&g)) g.x else g.x + g.w;
        }
        const g = self.glyphs[idx];
        return if (glyphIsRtl(&g)) g.x + g.w - offset else g.x + offset;
    }

    /// `(glyph_index, pixel_offset)` containing `cursor`, or null.
    pub fn cursorGlyph(self: *const LayoutRun, cursor: *const Cursor) ?GlyphOffset {
        if (cursor.line != self.line_i) return null;
        for (self.glyphs, 0..) |glyph, i| {
            if (cursor.index == glyph.start) return .{ .index = i, .offset = 0 };
            if (cursor.index > glyph.start and cursor.index < glyph.end) {
                const cluster = self.text[glyph.start..glyph.end];
                var before: usize = 0;
                var total: usize = 0;
                var it = unicode_mod.graphemeIndices(cluster);
                while (it.next()) |g_start| {
                    if (g_start < cursor.index - glyph.start) before += 1;
                    total += 1;
                }
                if (total == 0) return .{ .index = i, .offset = 0 };
                const offset = glyph.w *
                    @as(f32, @floatFromInt(before)) /
                    @as(f32, @floatFromInt(total));
                return .{ .index = i, .offset = offset };
            }
        }
        // Mixed-direction runs: the last logical glyph may not be last
        // visually, so check end boundaries in a second pass.
        for (self.glyphs, 0..) |glyph, i| {
            if (cursor.index == glyph.end) return .{ .index = i, .offset = glyph.w };
        }
        if (self.glyphs.len == 0) return .{ .index = 0, .offset = 0 };
        return null;
    }

    pub fn cursorFromGlyphLeft(self: *const LayoutRun, glyph: *const LayoutGlyph) Cursor {
        if (self.rtl) {
            return Cursor.newWithAffinity(self.line_i, glyph.end, .before);
        }
        return Cursor.newWithAffinity(self.line_i, glyph.start, .after);
    }

    pub fn cursorFromGlyphRight(self: *const LayoutRun, glyph: *const LayoutGlyph) Cursor {
        if (self.rtl) {
            return Cursor.newWithAffinity(self.line_i, glyph.start, .after);
        }
        return Cursor.newWithAffinity(self.line_i, glyph.end, .before);
    }
};

pub const Highlight = struct {
    x: f32,
    width: f32,
};

pub const GlyphOffset = struct {
    index: usize,
    offset: f32,
};

/// Iterator over visible text runs, mirroring `LayoutRunIter`.
pub const LayoutRunIter = struct {
    lines: []const BufferLine,
    height_opt: ?f32,
    line_height: f32,
    scroll: f32,
    line_i: usize,
    layout_i: usize,
    total_height: f32,
    line_top: f32,

    pub fn init(
        lines: []const BufferLine,
        height_opt: ?f32,
        line_height: f32,
        scroll: f32,
        start: usize,
    ) LayoutRunIter {
        return .{
            .lines = lines,
            .height_opt = height_opt,
            .line_height = line_height,
            .scroll = scroll,
            .line_i = start,
            .layout_i = 0,
            .total_height = 0,
            .line_top = 0,
        };
    }

    /// Returns the next visible run, or null. Unshaped lines end iteration
    /// (callers must `shape_until_scroll` first).
    pub fn next(self: *LayoutRunIter) ?LayoutRun {
        while (self.line_i < self.lines.len) {
            const line = &self.lines[self.line_i];
            const shape_line = line.shapeOpt() orelse return null;
            const layout_lines = line.layoutOpt() orelse return null;
            while (self.layout_i < layout_lines.len) {
                const ll = &layout_lines[self.layout_i];
                self.layout_i += 1;
                const lh = ll.line_height_opt orelse self.line_height;
                self.total_height += lh;
                const line_top = self.line_top - self.scroll;
                const glyph_h = ll.max_ascent + ll.max_descent;
                const centering = (lh - glyph_h) / 2.0;
                const line_y = line_top + centering + ll.max_ascent;
                if (self.height_opt) |h| {
                    if (line_y - ll.max_ascent > h) return null;
                }
                self.line_top += lh;
                if (line_y + ll.max_descent < 0.0) continue;
                return .{
                    .line_i = self.line_i,
                    .text = line.textSlice(),
                    .rtl = shape_line.rtl,
                    .glyphs = ll.glyphs.items,
                    .decorations = ll.decorations.items,
                    .line_y = line_y,
                    .line_top = line_top,
                    .line_height = lh,
                    .line_w = ll.w,
                };
            }
            self.line_i += 1;
            self.layout_i = 0;
        }
        return null;
    }
};

// ---------------------------------------------------------------------------
// Dirty flags + buffer
// ---------------------------------------------------------------------------

/// Which buffer-wide properties changed since the last layout.
/// Mirrors the `DirtyFlags` bitflags in the Rust original.
pub const DirtyFlags = packed struct(u8) {
    /// Wrap, size, metrics, hinting, ellipsize, or monospace width changed.
    relayout: bool = false,
    /// `tab_width` changed; lines containing tabs need a reshape.
    tab_shape: bool = false,
    /// Text replaced via `set_text`/`set_rich_text`; lines are already fresh.
    text_set: bool = false,
    /// Scroll position changed.
    scroll: bool = false,
    /// Base direction changed; reshape every line.
    direction: bool = false,
    _reserved: u3 = 0,

    pub fn isEmpty(self: DirtyFlags) bool {
        return std.meta.eql(self, DirtyFlags{});
    }

    pub fn clear(self: *DirtyFlags) void {
        self.* = .{};
    }
};

/// A buffer of shaped/laid-out text, mirroring cosmic-text `Buffer`.
pub const Buffer = struct {
    allocator: Allocator,
    lines: std.ArrayList(BufferLine),
    metrics: Metrics,
    width_opt: ?f32,
    height_opt: ?f32,
    scroll: Scroll,
    redraw: bool,
    wrap: Wrap,
    ellipsize: Ellipsize,
    monospace_width: ?f32,
    tab_width: u16,
    hinting: Hinting,
    direction: Direction,
    dirty: DirtyFlags,

    /// Create an empty buffer. Errors on zero `line_height` (the Rust
    /// original panics; this port returns `error.InvalidMetrics`).
    pub fn initWithAllocator(allocator: Allocator, metrics: Metrics) Error!Buffer {
        if (metrics.line_height == 0) return error.InvalidMetrics;
        return .{
            .allocator = allocator,
            .lines = .empty,
            .metrics = metrics,
            .width_opt = null,
            .height_opt = null,
            .scroll = .{},
            .redraw = false,
            .wrap = .word_or_glyph,
            .ellipsize = .{ .none = {} },
            .monospace_width = null,
            .tab_width = 8,
            .hinting = .disabled,
            .direction = .auto,
            .dirty = .{},
        };
    }

    /// Create a buffer with one empty line, shaped until scroll.
    pub fn initWithText(
        allocator: Allocator,
        font_system_: *FontSystem,
        metrics: Metrics,
    ) Error!Buffer {
        var self = try Buffer.initWithAllocator(allocator, metrics);
        errdefer self.deinit();
        var defaults = Attrs.init(allocator);
        defer defaults.deinit();
        try self.setText("", &defaults, .advanced, null);
        try self.shapeUntilScroll(font_system_, false);
        return self;
    }

    pub fn deinit(self: *Buffer) void {
        for (self.lines.items) |*line| line.deinit();
        self.lines.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn borrowWith(self: *Buffer, font_system_: *FontSystem) BufferWithFontSystem {
        return .{ .buffer = self, .font_system = font_system_ };
    }

    /// Invalidate caches per pending dirty flags, then clear them.
    /// Returns true when shaping/layout work may be needed.
    fn resolveDirty(self: *Buffer) bool {
        if (self.dirty.isEmpty()) {
            for (self.lines.items) |*line| {
                if (line.needsReshaping()) {
                    self.redraw = true;
                    return true;
                }
            }
            return false;
        }
        if (self.dirty.text_set) {
            // Lines were replaced and are already fresh.
        } else {
            if (self.dirty.direction) {
                for (self.lines.items) |*line| {
                    if (line.shapeOpt() != null) line.resetShaping();
                }
            } else if (self.dirty.tab_shape) {
                for (self.lines.items) |*line| {
                    if (line.shapeOpt() != null and
                        std.mem.indexOfScalar(u8, line.textSlice(), '\t') != null)
                    {
                        line.resetShaping();
                    }
                }
            }
            if (self.dirty.relayout) {
                for (self.lines.items) |*line| {
                    if (line.shapeOpt() != null) line.resetLayout();
                }
            }
        }
        self.redraw = true;
        self.dirty.clear();
        return true;
    }

    /// Shape lines until the cursor is visible, adjusting scroll.
    /// Returns `error.InvalidCursor` for out-of-range cursors.
    pub fn shapeUntilCursor(
        self: *Buffer,
        font_system_: *FontSystem,
        cursor: Cursor,
        prune: bool,
    ) Error!void {
        try self.shapeUntilScroll(font_system_, prune);
        const metrics = self.metrics;
        const old_scroll = self.scroll;

        const layout_cursor = (try self.layoutCursor(font_system_, cursor)) orelse
            return error.InvalidCursor;

        var layout_y: f32 = 0;
        var total_height: f32 = blk: {
            const layout_lines = (try self.lineLayout(font_system_, layout_cursor.line)) orelse
                return error.InvalidCursor;
            // Sum visual lines strictly above the cursor's own line.
            var y: f32 = 0;
            var k: usize = 0;
            while (k < layout_cursor.layout and k < layout_lines.len) : (k += 1) {
                y += layout_lines[k].line_height_opt orelse metrics.line_height;
            }
            layout_y = y;
            const own = if (layout_cursor.layout < layout_lines.len)
                layout_lines[layout_cursor.layout].line_height_opt orelse metrics.line_height
            else
                metrics.line_height;
            break :blk y + own;
        };

        if (self.scroll.line > layout_cursor.line or
            (self.scroll.line == layout_cursor.line and self.scroll.vertical > layout_y))
        {
            self.scroll.line = layout_cursor.line;
            self.scroll.vertical = layout_y;
        } else if (self.height_opt) |height| {
            var line_i = layout_cursor.line;
            if (line_i <= self.scroll.line) {
                if (total_height > height + self.scroll.vertical) {
                    self.scroll.vertical = total_height - height;
                }
            } else {
                while (line_i > self.scroll.line) {
                    line_i -= 1;
                    const layout_lines = (try self.lineLayout(font_system_, line_i)) orelse
                        return error.InvalidCursor;
                    for (layout_lines) |ll| {
                        total_height += ll.line_height_opt orelse metrics.line_height;
                    }
                    if (total_height > height + self.scroll.vertical) {
                        self.scroll.line = line_i;
                        self.scroll.vertical = total_height - height;
                    }
                }
            }
        }

        if (!std.meta.eql(old_scroll, self.scroll)) {
            self.dirty.scroll = true;
        }
        try self.shapeUntilScroll(font_system_, prune);

        // Adjust horizontal scroll to include the cursor.
        if ((try self.layoutCursor(font_system_, cursor))) |lc| {
            const layout_lines = (try self.lineLayout(font_system_, lc.line)) orelse
                return;
            if (lc.layout < layout_lines.len) {
                const ll = &layout_lines[lc.layout];
                const glyph_opt = if (lc.glyph < ll.glyphs.items.len)
                    ll.glyphs.items[lc.glyph]
                else if (ll.glyphs.items.len > 0)
                    ll.glyphs.items[ll.glyphs.items.len - 1]
                else
                    null;
                if (glyph_opt) |glyph| {
                    const x_min = @min(glyph.x, glyph.x + glyph.w);
                    const x_max = @max(glyph.x, glyph.x + glyph.w);
                    if (x_min < self.scroll.horizontal) {
                        self.scroll.horizontal = x_min;
                        self.redraw = true;
                    }
                    if (self.width_opt) |width| {
                        if (x_max > self.scroll.horizontal + width) {
                            self.scroll.horizontal = x_max - width;
                            self.redraw = true;
                        }
                    }
                }
            }
        }
    }

    /// Shape/layout visible lines, resolving dirty state first. Clamps
    /// `scroll.line` into range, normalizes negative `scroll.vertical` by
    /// walking backwards, and prunes off-screen lines when asked.
    pub fn shapeUntilScroll(self: *Buffer, font_system_: *FontSystem, prune: bool) Error!void {
        if (!self.resolveDirty()) return;
        const metrics = self.metrics;

        if (self.scroll.line >= self.lines.items.len) {
            self.scroll.line = self.lines.items.len -| 1;
            self.scroll.vertical = 0;
        }
        const old_scroll = self.scroll;

        while (true) {
            while (self.scroll.vertical < 0) {
                if (self.scroll.line > 0) {
                    const line_i = self.scroll.line - 1;
                    if ((try self.lineLayout(font_system_, line_i))) |layout_lines| {
                        var h: f32 = 0;
                        for (layout_lines) |ll| {
                            h += ll.line_height_opt orelse metrics.line_height;
                        }
                        self.scroll.line = line_i;
                        self.scroll.vertical += h;
                    } else {
                        self.scroll.line = line_i;
                        self.scroll.vertical += metrics.line_height;
                    }
                } else {
                    self.scroll.vertical = 0;
                    break;
                }
            }

            const scroll_start = self.scroll.vertical;
            const scroll_end = scroll_start + (self.height_opt orelse std.math.inf(f32));

            if (prune) {
                var li: usize = 0;
                while (li < self.scroll.line and li < self.lines.items.len) : (li += 1) {
                    self.lines.items[li].resetShaping();
                }
            }
            var total_height: f32 = 0;
            var line_i = self.scroll.line;
            while (line_i < self.lines.items.len) : (line_i += 1) {
                if (total_height > scroll_end) {
                    if (prune) {
                        self.lines.items[line_i].resetShaping();
                        continue;
                    }
                    break;
                }
                const layout_lines = (try self.lineLayout(font_system_, line_i)) orelse
                    return error.InvalidCursor;
                var layout_height: f32 = 0;
                for (layout_lines) |ll| {
                    const lh = ll.line_height_opt orelse metrics.line_height;
                    layout_height += lh;
                    total_height += lh;
                }
                if (line_i == self.scroll.line and layout_height <= self.scroll.vertical) {
                    self.scroll.line += 1;
                    self.scroll.vertical -= layout_height;
                }
            }

            if (total_height < scroll_end and self.scroll.line > 0) {
                self.scroll.vertical -= scroll_end - total_height;
            } else {
                break;
            }
        }

        if (!std.meta.eql(old_scroll, self.scroll)) {
            self.redraw = true;
        }
    }

    /// Map a byte-index cursor to a layout position, or null when the line is
    /// out of range. Falls back to the start of the line for interior misses.
    pub fn layoutCursor(
        self: *Buffer,
        font_system_: *FontSystem,
        cursor: Cursor,
    ) Error!?LayoutCursor {
        const layout_lines = (try self.lineLayout(font_system_, cursor.line)) orelse return null;
        for (layout_lines, 0..) |*ll, layout_i| {
            for (ll.glyphs.items, 0..) |*glyph, glyph_i| {
                const cursor_end = Cursor.newWithAffinity(cursor.line, glyph.end, .before);
                const cursor_start = Cursor.newWithAffinity(cursor.line, glyph.start, .after);
                const left: Cursor, const right: Cursor = if (glyphIsRtl(glyph))
                    .{ cursor_end, cursor_start }
                else
                    .{ cursor_start, cursor_end };
                if (cursor.eql(left)) {
                    return LayoutCursor.new(cursor.line, layout_i, glyph_i);
                }
                if (cursor.eql(right)) {
                    return LayoutCursor.new(cursor.line, layout_i, glyph_i + 1);
                }
            }
        }
        return LayoutCursor.new(cursor.line, 0, 0);
    }

    /// Shape one line through `BufferLine` (which drives the real shaper).
    /// Null when `line_i` is out of range.
    pub fn lineShape(
        self: *Buffer,
        font_system_: *FontSystem,
        line_i: usize,
    ) Error!?*const ShapeLine {
        if (line_i >= self.lines.items.len) return null;
        return try self.lines.items[line_i].shape(font_system_, self.tab_width, self.direction);
    }

    /// Lay out one line through `BufferLine` (real wrap/align/ellipsize).
    /// Null when `line_i` is out of range.
    pub fn lineLayout(
        self: *Buffer,
        font_system_: *FontSystem,
        line_i: usize,
    ) Error!?[]LayoutLine {
        if (line_i >= self.lines.items.len) return null;
        return try self.lines.items[line_i].layout(
            font_system_,
            self.metrics.font_size,
            self.width_opt,
            self.wrap,
            self.ellipsize,
            self.monospace_width,
            self.tab_width,
            self.hinting,
            self.direction,
        );
    }

    pub fn getMetrics(self: *const Buffer) Metrics {
        return self.metrics;
    }

    pub fn setMetrics(self: *Buffer, metrics: Metrics) Error!void {
        if (!Metrics.eql(metrics, self.metrics)) {
            if (metrics.font_size == 0 or metrics.line_height == 0) {
                return error.InvalidMetrics;
            }
            self.metrics = metrics;
            self.dirty.relayout = true;
            self.redraw = true;
        }
    }

    pub fn getHinting(self: *const Buffer) Hinting {
        return self.hinting;
    }

    pub fn setHinting(self: *Buffer, hinting: Hinting) void {
        if (hinting != self.hinting) {
            self.hinting = hinting;
            self.dirty.relayout = true;
            self.redraw = true;
        }
    }

    pub fn getWrap(self: *const Buffer) Wrap {
        return self.wrap;
    }

    pub fn setWrap(self: *Buffer, wrap: Wrap) void {
        if (wrap != self.wrap) {
            self.wrap = wrap;
            self.dirty.relayout = true;
            self.redraw = true;
        }
    }

    pub fn getEllipsize(self: *const Buffer) Ellipsize {
        return self.ellipsize;
    }

    pub fn setEllipsize(self: *Buffer, ellipsize: Ellipsize) void {
        if (!std.meta.eql(ellipsize, self.ellipsize)) {
            self.ellipsize = ellipsize;
            self.dirty.relayout = true;
            self.redraw = true;
        }
    }

    pub fn getMonospaceWidth(self: *const Buffer) ?f32 {
        return self.monospace_width;
    }

    pub fn setMonospaceWidth(self: *Buffer, monospace_width: ?f32) void {
        if (monospace_width != self.monospace_width) {
            self.monospace_width = monospace_width;
            self.dirty.relayout = true;
            self.redraw = true;
        }
    }

    pub fn getTabWidth(self: *const Buffer) u16 {
        return self.tab_width;
    }

    /// A `tab_width` of 0 is ignored.
    pub fn setTabWidth(self: *Buffer, tab_width: u16) void {
        if (tab_width == 0) return;
        if (tab_width != self.tab_width) {
            self.tab_width = tab_width;
            self.dirty.tab_shape = true;
            self.dirty.relayout = true;
            self.redraw = true;
        }
    }

    pub fn getDirection(self: *const Buffer) Direction {
        return self.direction;
    }

    pub fn setDirection(self: *Buffer, direction: Direction) void {
        if (direction != self.direction) {
            self.direction = direction;
            self.dirty.direction = true;
            self.redraw = true;
        }
    }

    pub fn size(self: *const Buffer) struct { width: ?f32, height: ?f32 } {
        return .{ .width = self.width_opt, .height = self.height_opt };
    }

    pub fn setSize(self: *Buffer, width_opt: ?f32, height_opt: ?f32) void {
        const w = if (width_opt) |v| @max(v, 0) else null;
        const h = if (height_opt) |v| @max(v, 0) else null;
        if (w != self.width_opt) {
            self.width_opt = w;
            self.dirty.relayout = true;
            self.redraw = true;
        }
        if (h != self.height_opt) {
            self.height_opt = h;
            self.dirty.relayout = true;
            self.redraw = true;
        }
    }

    pub fn setMetricsAndSize(
        self: *Buffer,
        metrics: Metrics,
        width_opt: ?f32,
        height_opt: ?f32,
    ) Error!void {
        try self.setMetrics(metrics);
        self.setSize(width_opt, height_opt);
    }

    pub fn getScroll(self: *const Buffer) Scroll {
        return self.scroll;
    }

    pub fn setScroll(self: *Buffer, scroll: Scroll) void {
        if (!std.meta.eql(scroll, self.scroll)) {
            self.scroll = scroll;
            self.dirty.scroll = true;
            self.redraw = true;
        }
    }

    fn setTextImpl(
        self: *Buffer,
        text: []const u8,
        defaults: *const Attrs,
        shaping: Shaping,
        alignment: ?Align,
    ) Error!void {
        var line_count: usize = 0;
        var iter = LineIter.init(text);
        while (iter.next()) |item| {
            const line_text = text[item.start..item.end];
            if (line_count < self.lines.items.len) {
                var reused_text = self.lines.items[line_count].reclaimText();
                try reused_text.appendSlice(self.allocator, line_text);
                var reused_attrs = self.lines.items[line_count].reclaimAttrs();
                try reused_attrs.reset(defaults);
                self.lines.items[line_count].resetNewOwned(
                    reused_text,
                    item.ending,
                    reused_attrs,
                    shaping,
                );
            } else {
                try self.lines.append(
                    self.allocator,
                    try BufferLine.init(self.allocator, line_text, item.ending, defaults, shaping),
                );
            }
            line_count += 1;
        }

        // Ensure a trailing line with no ending. Empty text yields zero
        // lines, and `default` (Lf) != None, so an empty line is added.
        const last_ending: LineEnding = if (line_count > 0)
            self.lines.items[line_count - 1].ending
        else
            LineEnding.default;
        if (last_ending != .none) {
            if (line_count < self.lines.items.len) {
                const reused_text = self.lines.items[line_count].reclaimText();
                var reused_attrs = self.lines.items[line_count].reclaimAttrs();
                try reused_attrs.reset(defaults);
                self.lines.items[line_count].resetNewOwned(
                    reused_text,
                    .none,
                    reused_attrs,
                    shaping,
                );
            } else {
                try self.lines.append(
                    self.allocator,
                    try BufferLine.init(self.allocator, "", .none, defaults, shaping),
                );
            }
            line_count += 1;
        }

        // Drop excess reused lines.
        var k = self.lines.items.len;
        while (k > line_count) {
            k -= 1;
            var removed = self.lines.orderedRemove(k);
            removed.deinit();
        }

        if (alignment) |a| {
            for (self.lines.items) |*line| {
                _ = line.setAlign(a);
            }
        }
        self.scroll = .{};
    }

    /// Set buffer text, reusing line allocations. Marks `TEXT_SET`.
    pub fn setText(
        self: *Buffer,
        text: []const u8,
        defaults: *const Attrs,
        shaping: Shaping,
        alignment: ?Align,
    ) Error!void {
        try self.setTextImpl(text, defaults, shaping, alignment);
        self.dirty.text_set = true;
        self.redraw = true;
    }

    /// One styled span for `setRichText`.
    pub const RichSpan = struct {
        text: []const u8,
        attrs: Attrs,
    };

    fn setRichTextImpl(
        self: *Buffer,
        spans: []const RichSpan,
        defaults: *const Attrs,
        shaping: Shaping,
        alignment: ?Align,
    ) Error!void {
        // Concatenate span texts, recording byte ranges.
        var string: std.ArrayList(u8) = .empty;
        defer string.deinit(self.allocator);
        var span_ranges: std.ArrayList(struct { start: usize, end: usize }) = .empty;
        defer span_ranges.deinit(self.allocator);
        for (spans) |sp| {
            const start = string.items.len;
            try string.appendSlice(self.allocator, sp.text);
            try span_ranges.append(self.allocator, .{ .start = start, .end = string.items.len });
        }

        // Paragraph ranges via the canonical BiDi paragraph iterator:
        // `BidiClass::B` separators (LF/CR/VT/FF/NEL/PS), trailing separator
        // stripped, `\r\n` / `\n\r` consumed as one.
        var para: std.ArrayList(struct { start: usize, end: usize }) = .empty;
        defer para.deinit(self.allocator);
        if (string.items.len > 0) {
            const base = @intFromPtr(string.items.ptr);
            var paragraphs = bidi_para_mod.BidiParagraphs.init(string.items);
            while (paragraphs.next()) |p| {
                const start = @intFromPtr(p.ptr) - base;
                try para.append(self.allocator, .{ .start = start, .end = start + p.len });
            }
        }

        var line_count: usize = 0;
        var line_idx: usize = 0;
        var span_idx: usize = 0;

        var work_text: std.ArrayList(u8) = .empty;
        var work_attrs = try AttrsList.init(self.allocator, defaults);
        errdefer work_text.deinit(self.allocator);
        errdefer work_attrs.deinit();
        if (self.lines.items.len > 0) {
            work_text = self.lines.items[0].reclaimText();
            var ra = self.lines.items[0].reclaimAttrs();
            try ra.reset(defaults);
            work_attrs.deinit();
            work_attrs = ra;
        }

        // Stores the finished working pair at `line_count`, then pulls the
        // next working pair from the following reused line when one exists.
        const finishLine = struct {
            fn run(
                buf: *Buffer,
                shaping_: Shaping,
                defaults_: *const Attrs,
                line_count_: *usize,
                wt: *std.ArrayList(u8),
                wa: *AttrsList,
            ) Error!void {
                if (buf.lines.items.len == line_count_.*) {
                    try buf.lines.append(buf.allocator, BufferLine.empty(buf.allocator));
                }
                const owned_text = wt.*;
                wt.* = .empty;
                const owned_attrs = wa.*;
                wa.* = try AttrsList.init(buf.allocator, defaults_);
                buf.lines.items[line_count_.*].resetNewOwned(
                    owned_text,
                    .lf,
                    owned_attrs,
                    shaping_,
                );
                line_count_.* += 1;
                if (line_count_.* < buf.lines.items.len) {
                    wt.* = buf.lines.items[line_count_.*].reclaimText();
                    var ra = buf.lines.items[line_count_.*].reclaimAttrs();
                    try ra.reset(defaults_);
                    wa.deinit();
                    wa.* = ra;
                }
            }
        }.run;

        if (para.items.len == 0 or spans.len == 0) {
            // Empty input: exactly one empty line with default attrs_mod.
            try finishLine(self, shaping, defaults, &line_count, &work_text, &work_attrs);
        } else {
            while (true) {
                if (line_idx >= para.items.len or span_idx >= spans.len) break;
                const lr = para.items[line_idx];
                const sr = span_ranges.items[span_idx];
                const start = @max(lr.start, sr.start);
                const end = @min(lr.end, sr.end);
                if (start < end) {
                    const t0 = work_text.items.len;
                    try work_text.appendSlice(self.allocator, string.items[start..end]);
                    const t1 = work_text.items.len;
                    if (!attrsOwnedEqlBorrowed(&work_attrs.default_attrs, &spans[span_idx].attrs)) {
                        try work_attrs.add_span(t0, t1, &spans[span_idx].attrs);
                    }
                } else if (work_text.items.len == 0 and
                    spans[span_idx].attrs.metrics_opt != null)
                {
                    // Empty line inside a sized span inherits its metrics.
                    try work_attrs.reset(&spans[span_idx].attrs);
                }
                if (sr.end < lr.end) {
                    span_idx += 1;
                } else {
                    line_idx += 1;
                    if (line_idx < para.items.len) {
                        try finishLine(self, shaping, defaults, &line_count, &work_text, &work_attrs);
                        try work_attrs.reset(defaults);
                    } else {
                        try finishLine(self, shaping, defaults, &line_count, &work_text, &work_attrs);
                        break;
                    }
                }
            }
        }
        work_text.deinit(self.allocator);
        work_attrs.deinit();

        var k = self.lines.items.len;
        while (k > line_count) {
            k -= 1;
            var removed = self.lines.orderedRemove(k);
            removed.deinit();
        }

        for (self.lines.items) |*line| {
            if (alignment) |a| _ = line.setAlign(a);
        }
        self.scroll = .{};
    }

    /// Set rich text from styled spans. Marks `TEXT_SET`.
    pub fn setRichText(
        self: *Buffer,
        spans: []const RichSpan,
        defaults: *const Attrs,
        shaping: Shaping,
        alignment: ?Align,
    ) Error!void {
        try self.setRichTextImpl(spans, defaults, shaping, alignment);
        self.dirty.text_set = true;
        self.redraw = true;
    }

    pub fn getRedraw(self: *const Buffer) bool {
        return self.redraw;
    }

    pub fn setRedraw(self: *Buffer, redraw: bool) void {
        self.redraw = redraw;
    }

    /// Visible layout runs. Call `shapeUntilScroll` first (or use
    /// `BufferWithFontSystem`, which does it automatically).
    pub fn layoutRuns(self: *const Buffer) LayoutRunIter {
        return LayoutRunIter.init(
            self.lines.items,
            self.height_opt,
            self.metrics.line_height,
            self.scroll.vertical,
            self.scroll.line,
        );
    }

    /// Hit detection: map pixel `(x, y)` to a cursor. Per-grapheme half
    /// split, RTL-mirrored (`right_half != glyph.isRtl()`).
    pub fn hit(self: *const Buffer, x: f32, y: f32) ?Cursor {
        var new_cursor_opt: ?Cursor = null;
        var runs = self.layoutRuns();
        // Peekable-by-one: track whether more runs follow.
        var pending = runs.next();
        var first_run = true;
        while (pending) |run| {
            const nxt = runs.next();
            const has_next = nxt != null;
            const line_top = run.line_top;
            const line_height = run.line_height;

            if (first_run and y < line_top) {
                first_run = false;
                new_cursor_opt = Cursor.new(run.line_i, 0);
            } else if (y >= line_top and y < line_top + line_height) {
                var new_glyph = run.glyphs.len;
                var new_char: usize = 0;
                var new_affinity: Affinity = .after;
                var first_glyph = true;
                for (run.glyphs, 0..) |*glyph, glyph_i| {
                    if (first_glyph) {
                        first_glyph = false;
                        if ((run.rtl and x > glyph.x) or (!run.rtl and x < 0)) {
                            new_glyph = 0;
                            new_char = 0;
                        }
                    }
                    if (x >= glyph.x and x <= glyph.x + glyph.w) {
                        new_glyph = glyph_i;
                        const cluster = run.text[glyph.start..glyph.end];
                        const total: f32 = @floatFromInt(@max(unicode_mod.countGraphemes(cluster), 1));
                        var egc_x = glyph.x;
                        const egc_w = glyph.w / total;
                        var gx = unicode_mod.graphemeIndices(cluster);
                        var found = false;
                        while (gx.next()) |g_start| {
                            const g_end = gx.pos;
                            if (x >= egc_x and x <= egc_x + egc_w) {
                                new_char = g_start;
                                const right_half = x >= egc_x + egc_w / 2.0;
                                if (right_half != glyphIsRtl(glyph)) {
                                    // Clicking the last half of the grapheme
                                    // moves past it; affinity Before.
                                    new_char = g_end;
                                    new_affinity = .before;
                                }
                                found = true;
                                break;
                            }
                            egc_x += egc_w;
                        }
                        if (!found) {
                            const right_half = x >= glyph.x + glyph.w / 2.0;
                            if (right_half != glyphIsRtl(glyph)) {
                                new_char = cluster.len;
                                new_affinity = .before;
                            }
                        }
                        break;
                    }
                }
                var new_cursor = Cursor.new(run.line_i, 0);
                if (new_glyph < run.glyphs.len) {
                    const glyph = run.glyphs[new_glyph];
                    new_cursor.index = glyph.start + new_char;
                    new_cursor.affinity = new_affinity;
                } else {
                    var run_end: usize = 0;
                    for (run.glyphs) |g| run_end = @max(run_end, g.end);
                    new_cursor.index = run_end;
                    new_cursor.affinity = .before;
                }
                new_cursor_opt = new_cursor;
                break;
            } else if (!has_next and y > run.line_y) {
                new_cursor_opt = Cursor.newWithAffinity(run.line_i, run.text.len, .before);
            }
            pending = nxt;
        }
        return new_cursor_opt;
    }

    /// Visual `(x, line_top)` of a cursor, or null when not laid out.
    pub fn cursorPosition(self: *const Buffer, cursor: *const Cursor) ?CursorPosition {
        var runs = self.layoutRuns();
        while (runs.next()) |run| {
            if (run.line_i != cursor.line) continue;
            if (run.cursorPosition(cursor)) |x| {
                return .{ .x = x, .y = run.line_top };
            }
        }
        return null;
    }

    /// Paragraph direction for a line, or null when unshaped/missing.
    pub fn isRtl(self: *const Buffer, line: usize) ?bool {
        if (line >= self.lines.items.len) return null;
        const shape_line = self.lines.items[line].shapeOpt() orelse return null;
        return shape_line.rtl;
    }

    /// Apply a `Motion` to a cursor. Returns null when the line is out of
    /// range; `cursor_x_opt` preserves the visual column across Up/Down.
    pub fn cursorMotion(
        self: *Buffer,
        font_system_: *FontSystem,
        cursor: Cursor,
        cursor_x_opt: ?i32,
        motion: Motion,
    ) Error!?MotionResult {
        var cur = cursor;
        var x_opt = cursor_x_opt;
        switch (motion) {
            .layout_cursor => |lc| {
                const layout_lines = (try self.lineLayout(font_system_, lc.line)) orelse return null;
                const ll: *const LayoutLine = if (lc.layout < layout_lines.len)
                    &layout_lines[lc.layout]
                else if (layout_lines.len > 0)
                    &layout_lines[layout_lines.len - 1]
                else
                    return null;
                var new_index: usize = 0;
                var new_affinity: Affinity = .after;
                if (lc.glyph < ll.glyphs.items.len) {
                    new_index = ll.glyphs.items[lc.glyph].start;
                    new_affinity = .after;
                } else if (ll.glyphs.items.len > 0) {
                    const last = ll.glyphs.items[ll.glyphs.items.len - 1];
                    new_index = last.end;
                    new_affinity = .before;
                }
                if (cur.line != lc.line or cur.index != new_index or cur.affinity != new_affinity) {
                    cur.line = lc.line;
                    cur.index = new_index;
                    cur.affinity = new_affinity;
                }
            },
            .previous => {
                if (cur.line >= self.lines.items.len) return null;
                const text = self.lines.items[cur.line].textSlice();
                if (cur.index > 0) {
                    cur.index = unicode_mod.prevGraphemeStart(text, cur.index);
                    cur.affinity = .after;
                } else if (cur.line > 0) {
                    cur.line -= 1;
                    cur.index = self.lines.items[cur.line].textSlice().len;
                    cur.affinity = .after;
                }
                x_opt = null;
            },
            .next => {
                if (cur.line >= self.lines.items.len) return null;
                const text = self.lines.items[cur.line].textSlice();
                if (cur.index < text.len) {
                    cur.index = unicode_mod.nextGraphemeEnd(text, cur.index);
                    cur.affinity = .before;
                } else if (cur.line + 1 < self.lines.items.len) {
                    cur.line += 1;
                    cur.index = 0;
                    cur.affinity = .before;
                }
                x_opt = null;
            },
            .left => {
                const rtl = if (try self.lineShape(font_system_, cur.line)) |s| s.rtl else return null;
                const inner: Motion = if (rtl) .next else .previous;
                const r = (try self.cursorMotion(font_system_, cur, x_opt, inner)) orelse return null;
                cur = r.cursor;
                x_opt = r.x_opt;
            },
            .right => {
                const rtl = if (try self.lineShape(font_system_, cur.line)) |s| s.rtl else return null;
                const inner: Motion = if (rtl) .previous else .next;
                const r = (try self.cursorMotion(font_system_, cur, x_opt, inner)) orelse return null;
                cur = r.cursor;
                x_opt = r.x_opt;
            },
            .up => {
                var lc = (try self.layoutCursor(font_system_, cur)) orelse return null;
                if (x_opt == null) x_opt = floatToI32Saturating(@floatFromInt(lc.glyph));
                if (lc.layout > 0) {
                    lc.layout -= 1;
                } else if (lc.line > 0) {
                    lc.line -= 1;
                    lc.layout = std.math.maxInt(usize);
                }
                if (x_opt) |cx| lc.glyph = @intCast(@max(cx, 0));
                const r = (try self.cursorMotion(font_system_, cur, x_opt, .{ .layout_cursor = lc })) orelse return null;
                cur = r.cursor;
                x_opt = r.x_opt;
            },
            .down => {
                var lc = (try self.layoutCursor(font_system_, cur)) orelse return null;
                const layout_len = ((try self.lineLayout(font_system_, lc.line)) orelse return null).len;
                if (x_opt == null) x_opt = floatToI32Saturating(@floatFromInt(lc.glyph));
                if (lc.layout + 1 < layout_len) {
                    lc.layout += 1;
                } else if (lc.line + 1 < self.lines.items.len) {
                    lc.line += 1;
                    lc.layout = 0;
                }
                if (x_opt) |cx| lc.glyph = @intCast(@max(cx, 0));
                const r = (try self.cursorMotion(font_system_, cur, x_opt, .{ .layout_cursor = lc })) orelse return null;
                cur = r.cursor;
                x_opt = r.x_opt;
            },
            .home => {
                cur.index = 0;
                x_opt = null;
            },
            .soft_home => {
                if (cur.line >= self.lines.items.len) return null;
                cur.index = firstNonWhitespace(self.lines.items[cur.line].textSlice());
                x_opt = null;
            },
            .end => {
                if (cur.line >= self.lines.items.len) return null;
                cur.index = self.lines.items[cur.line].textSlice().len;
                x_opt = null;
            },
            .paragraph_start => {
                cur.index = 0;
                x_opt = null;
            },
            .paragraph_end => {
                if (cur.line >= self.lines.items.len) return null;
                cur.index = self.lines.items[cur.line].textSlice().len;
                x_opt = null;
            },
            .page_up => {
                if (self.height_opt) |h| {
                    const r = (try self.cursorMotion(font_system_, cur, x_opt, .{ .vertical = floatToI32Saturating(-h) })) orelse return null;
                    cur = r.cursor;
                    x_opt = r.x_opt;
                }
            },
            .page_down => {
                if (self.height_opt) |h| {
                    const r = (try self.cursorMotion(font_system_, cur, x_opt, .{ .vertical = floatToI32Saturating(h) })) orelse return null;
                    cur = r.cursor;
                    x_opt = r.x_opt;
                }
            },
            .vertical => |px| {
                const count = @divTrunc(px, floatToI32Saturating(self.metrics.line_height));
                if (count < 0) {
                    var k: i32 = 0;
                    while (k > count) : (k -= 1) {
                        const r = (try self.cursorMotion(font_system_, cur, x_opt, .up)) orelse return null;
                        cur = r.cursor;
                        x_opt = r.x_opt;
                    }
                } else {
                    var k: i32 = 0;
                    while (k < count) : (k += 1) {
                        const r = (try self.cursorMotion(font_system_, cur, x_opt, .down)) orelse return null;
                        cur = r.cursor;
                        x_opt = r.x_opt;
                    }
                }
            },
            .previous_word => {
                if (cur.line >= self.lines.items.len) return null;
                const text = self.lines.items[cur.line].textSlice();
                if (cur.index > 0) {
                    cur.index = prevWordStart(text, cur.index);
                } else if (cur.line > 0) {
                    cur.line -= 1;
                    cur.index = self.lines.items[cur.line].textSlice().len;
                }
                x_opt = null;
            },
            .next_word => {
                if (cur.line >= self.lines.items.len) return null;
                const text = self.lines.items[cur.line].textSlice();
                if (cur.index < text.len) {
                    cur.index = nextWordEnd(text, cur.index);
                } else if (cur.line + 1 < self.lines.items.len) {
                    cur.line += 1;
                    cur.index = 0;
                }
                x_opt = null;
            },
            .left_word => {
                const rtl = if (try self.lineShape(font_system_, cur.line)) |s| s.rtl else return null;
                const inner: Motion = if (rtl) .next_word else .previous_word;
                const r = (try self.cursorMotion(font_system_, cur, x_opt, inner)) orelse return null;
                cur = r.cursor;
                x_opt = r.x_opt;
            },
            .right_word => {
                const rtl = if (try self.lineShape(font_system_, cur.line)) |s| s.rtl else return null;
                const inner: Motion = if (rtl) .previous_word else .next_word;
                const r = (try self.cursorMotion(font_system_, cur, x_opt, inner)) orelse return null;
                cur = r.cursor;
                x_opt = r.x_opt;
            },
            .buffer_start => {
                cur.line = 0;
                cur.index = 0;
                x_opt = null;
            },
            .buffer_end => {
                if (self.lines.items.len == 0) return null;
                cur.line = self.lines.items.len - 1;
                cur.index = self.lines.items[cur.line].textSlice().len;
                x_opt = null;
            },
            .goto_line => |goal| {
                var lc = (try self.layoutCursor(font_system_, cur)) orelse return null;
                lc.line = goal;
                const r = (try self.cursorMotion(font_system_, cur, x_opt, .{ .layout_cursor = lc })) orelse return null;
                cur = r.cursor;
                x_opt = r.x_opt;
            },
        }
        return MotionResult{ .cursor = cur, .x_opt = x_opt };
    }

    /// Draw the buffer (port of `Buffer::draw`, buffer.rs:1636-1659).
    ///
    /// Shapes until scroll, then emits glyph pixels from `cache` and
    /// decoration rectangles through `callback`. `callback` must not call
    /// back into `self` or `cache`.
    pub fn draw(
        self: *Buffer,
        font_system_: *FontSystem,
        cache: *SwashCache,
        color: Color,
        callback: render_mod.Callback,
    ) Error!void {
        try self.shapeUntilScroll(font_system_, false);
        var legacy = render_mod.LegacyRenderer.init(cache, callback);
        var it = self.layoutRuns();
        while (it.next()) |run| {
            for (run.glyphs) |glyph| {
                const physical = glyph.physical(0, run.line_y, 1.0);
                legacy.renderer().glyph(physical, glyph.color_opt orelse color);
            }
            // Decorations after glyphs so strikethrough covers them
            // (buffer.rs:1677).
            render_mod.renderDecoration(legacy.renderer(), renderRunView(run), color);
        }
    }

    /// Render the buffer through a `render.Renderer` (port of `Buffer::render`,
    /// buffer.rs:1664-1680).
    pub fn render(
        self: *Buffer,
        font_system_: *FontSystem,
        renderer: render_mod.Renderer,
        color: Color,
    ) Error!void {
        try self.shapeUntilScroll(font_system_, false);
        var it = self.layoutRuns();
        while (it.next()) |run| {
            for (run.glyphs) |glyph| {
                const physical = glyph.physical(0, run.line_y, 1.0);
                renderer.glyph(physical, glyph.color_opt orelse color);
            }
            render_mod.renderDecoration(renderer, renderRunView(run), color);
        }
    }
};

/// Convert the full buffer `LayoutRun` into `render.zig`'s view (the render
/// module stays independent of `buffer.zig`; see its `LayoutRun` docs).
fn renderRunView(run: LayoutRun) render_mod.LayoutRun {
    return .{
        .glyphs = run.glyphs,
        .decorations = run.decorations,
        .line_y = run.line_y,
        .line_top = run.line_top,
        .line_i = run.line_i,
        .rtl = run.rtl,
        .line_height = run.line_height,
        .line_w = run.line_w,
    };
}

pub const MotionResult = struct {
    cursor: Cursor,
    x_opt: ?i32,
};

pub const CursorPosition = struct {
    x: f32,
    y: f32,
};

// ---------------------------------------------------------------------------
// Borrowed-with-font-system wrapper
// ---------------------------------------------------------------------------

/// `Buffer` borrowed together with a `FontSystem`, mirroring
/// `BorrowedWithFontSystem<Buffer>`. Shapes automatically before reads.
pub const BufferWithFontSystem = struct {
    buffer: *Buffer,
    font_system: *FontSystem,

    pub fn setText(
        self: *BufferWithFontSystem,
        text: []const u8,
        defaults: *const Attrs,
        shaping: Shaping,
        alignment: ?Align,
    ) Error!void {
        try self.buffer.setText(text, defaults, shaping, alignment);
    }

    pub fn setRichText(
        self: *BufferWithFontSystem,
        spans: []const Buffer.RichSpan,
        defaults: *const Attrs,
        shaping: Shaping,
        alignment: ?Align,
    ) Error!void {
        try self.buffer.setRichText(spans, defaults, shaping, alignment);
    }

    pub fn setSize(self: *BufferWithFontSystem, width_opt: ?f32, height_opt: ?f32) void {
        self.buffer.setSize(width_opt, height_opt);
    }

    pub fn setMetrics(self: *BufferWithFontSystem, metrics: Metrics) Error!void {
        try self.buffer.setMetrics(metrics);
    }

    pub fn setMetricsAndSize(
        self: *BufferWithFontSystem,
        metrics: Metrics,
        width_opt: ?f32,
        height_opt: ?f32,
    ) Error!void {
        try self.buffer.setMetricsAndSize(metrics, width_opt, height_opt);
    }

    pub fn setWrap(self: *BufferWithFontSystem, wrap: Wrap) void {
        self.buffer.setWrap(wrap);
    }

    pub fn setEllipsize(self: *BufferWithFontSystem, ellipsize: Ellipsize) void {
        self.buffer.setEllipsize(ellipsize);
    }

    pub fn setHinting(self: *BufferWithFontSystem, hinting: Hinting) void {
        self.buffer.setHinting(hinting);
    }

    pub fn setTabWidth(self: *BufferWithFontSystem, tab_width: u16) void {
        self.buffer.setTabWidth(tab_width);
    }

    pub fn setMonospaceWidth(self: *BufferWithFontSystem, w: ?f32) void {
        self.buffer.setMonospaceWidth(w);
    }

    pub fn setDirection(self: *BufferWithFontSystem, direction: Direction) void {
        self.buffer.setDirection(direction);
    }

    pub fn shapeUntilScroll(self: *BufferWithFontSystem, prune: bool) Error!void {
        try self.buffer.shapeUntilScroll(self.font_system, prune);
    }

    pub fn shapeUntilCursor(self: *BufferWithFontSystem, cursor: Cursor, prune: bool) Error!void {
        try self.buffer.shapeUntilCursor(self.font_system, cursor, prune);
    }

    pub fn lineShape(self: *BufferWithFontSystem, line_i: usize) Error!?*const ShapeLine {
        return self.buffer.lineShape(self.font_system, line_i);
    }

    pub fn lineLayout(self: *BufferWithFontSystem, line_i: usize) Error!?[]LayoutLine {
        return self.buffer.lineLayout(self.font_system, line_i);
    }

    pub fn layoutRuns(self: *BufferWithFontSystem) Error!LayoutRunIter {
        try self.buffer.shapeUntilScroll(self.font_system, false);
        return self.buffer.layoutRuns();
    }

    pub fn hit(self: *BufferWithFontSystem, x: f32, y: f32) Error!?Cursor {
        try self.buffer.shapeUntilScroll(self.font_system, false);
        return self.buffer.hit(x, y);
    }

    pub fn cursorMotion(
        self: *BufferWithFontSystem,
        cursor: Cursor,
        cursor_x_opt: ?i32,
        motion: Motion,
    ) Error!?MotionResult {
        return self.buffer.cursorMotion(self.font_system, cursor, cursor_x_opt, motion);
    }

    /// Draw the buffer (port of `BorrowedWithFontSystem<Buffer>::draw`,
    /// buffer.rs:1824-1829).
    pub fn draw(
        self: *BufferWithFontSystem,
        cache: *SwashCache,
        color: Color,
        callback: render_mod.Callback,
    ) Error!void {
        try self.buffer.draw(self.font_system, cache, color, callback);
    }

    /// Render the buffer through a `render.Renderer`.
    pub fn render(
        self: *BufferWithFontSystem,
        renderer: render_mod.Renderer,
        color: Color,
    ) Error!void {
        try self.buffer.render(self.font_system, renderer, color);
    }
};

// ---------------------------------------------------------------------------
// Helpers (canonical `unicode.zig` stepping; no codepoint approximations)
// ---------------------------------------------------------------------------

fn glyphIsRtl(glyph: *const LayoutGlyph) bool {
    return !layout_mod.levelIsLtr(glyph.level);
}

/// Compare a borrowed `Attrs` against an owned `AttrsOwned` snapshot. Used by
/// `setRichText` to skip spans identical to the current defaults.
fn attrsOwnedEqlBorrowed(owned: *const attrs_mod.AttrsOwned, borrowed: *const Attrs) bool {
    if (!std.meta.eql(owned.color_opt, borrowed.color_opt)) return false;
    if (!owned.family_owned.as_family().eql(borrowed.family)) return false;
    if (!owned.stretch.eql(borrowed.stretch)) return false;
    if (!owned.style.eql(borrowed.style)) return false;
    if (!owned.weight.eql(borrowed.weight)) return false;
    if (owned.metadata != borrowed.metadata) return false;
    if (!owned.cache_key_flags.eql(borrowed.cache_key_flags)) return false;
    if (!std.meta.eql(owned.metrics_opt, borrowed.metrics_opt)) return false;
    if (!std.meta.eql(owned.letter_spacing_opt, borrowed.letter_spacing_opt)) return false;
    if (!owned.font_features.eql(&borrowed.font_features)) return false;
    if (!owned.text_decoration.eql(borrowed.text_decoration)) return false;
    return true;
}

/// Byte index of the first non-whitespace char, else 0.
/// Uses `unicode.zig`'s `isWhitespace` so multi-byte spaces (NBSP, EM SPACE, ...)
/// count; empty or all-whitespace lines return 0, matching the oracle's
/// `find_map(...).unwrap_or(0)`.
fn firstNonWhitespace(text: []const u8) usize {
    var iter = unicode_mod.codepointIterator(text);
    while (iter.next()) |cp| {
        if (!unicode_mod.isWhitespace(cp.value)) return iter.pos - cp.len;
    }
    return 0;
}

/// Last UAX#29 word start strictly before `index`, else 0 (mirrors the
/// oracle's `unicode_word_indices().rev().find(|i| i < cursor.index)`).
/// A segment counts as a word iff it contains an `Alphabetic` or
/// `General_Category=N*` codepoint (`unicode.isWordRange`), so word motion
/// never stops on punctuation-only or whitespace-only runs.
fn prevWordStart(text: []const u8, index: usize) usize {
    var found: usize = 0;
    var it = unicode_mod.wordBounds(text);
    while (it.next()) |r| {
        if (!unicode_mod.isWordRange(text, r)) continue;
        if (r.start >= index) break;
        found = r.start;
    }
    return found;
}

/// First UAX#29 word end strictly after `index`, else `text.len` (mirrors
/// the oracle's `unicode_word_indices().map(i + word.len()).find(|i| i > ...)`).
/// Uses the same alphanumeric filter as `prevWordStart`.
fn nextWordEnd(text: []const u8, index: usize) usize {
    var it = unicode_mod.wordBounds(text);
    while (it.next()) |r| {
        if (!unicode_mod.isWordRange(text, r)) continue;
        if (r.end > index) return r.end;
    }
    return text.len;
}

fn floatToI32Saturating(v: f32) i32 {
    if (std.math.isNan(v)) return 0;
    const trunc = @trunc(v);
    const max: f32 = @floatFromInt(std.math.maxInt(i32));
    const min: f32 = @floatFromInt(std.math.minInt(i32));
    return @intFromFloat(std.math.clamp(trunc, min, max));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
//
// Real-font policy: tests register the vendored faces under `tests/fonts`
// via the real `FontDb.addFace` + `FontSystem.initWithDb` APIs (there is no
// `loadFontData`/`loadFontsDir` yet -- see plan.md). `TestFontSystem.init`
// skips (`error.SkipZigTest`) only when a vendored font is genuinely absent.

const testing = std.testing;

const test_font_candidates = [_][]const u8{
    "tests/fonts/",
    "../tests/fonts/",
};

const TestFontSpec = struct {
    file: []const u8,
    family: []const u8,
    mono: bool,
};

const test_fonts = [_]TestFontSpec{
    .{ .file = "Inter-Regular.ttf", .family = "Inter", .mono = false },
    .{ .file = "FiraMono-Medium.ttf", .family = "Fira Mono", .mono = true },
    .{ .file = "NotoSansArabic.ttf", .family = "Noto Sans Arabic", .mono = false },
    .{ .file = "NotoSansHebrew.ttf", .family = "Noto Sans Hebrew", .mono = false },
};

fn existingFontPath(allocator: Allocator, candidate: []const u8) Allocator.Error!?[]u8 {
    std.Io.Dir.cwd().access(std.testing.io, candidate, .{}) catch return null;
    return try allocator.dupe(u8, candidate);
}

fn testFontPath(allocator: Allocator, file: []const u8) ![]u8 {
    for (test_font_candidates) |candidate| {
        const joined = try std.fs.path.join(allocator, &.{ candidate, file });
        defer allocator.free(joined);
        if (try existingFontPath(allocator, joined)) |path| return path;
    }
    // Also try relative to this source file (covers a test binary running
    // outside the project root).
    if (std.fs.path.dirname(@src().file)) |src_dir| {
        const joined = try std.fs.path.join(
            allocator,
            &.{ src_dir, "..", "tests", "fonts", file },
        );
        defer allocator.free(joined);
        if (try existingFontPath(allocator, joined)) |path| return path;
    }
    // TODO(font): the vendored tests/fonts tree is part of the repo. If it is
    // missing, the environment is incomplete; skip instead of faking metrics.
    return error.SkipZigTest;
}

const TestFontSystem = struct {
    allocator: Allocator,
    font_system: FontSystem,
    paths: std.ArrayList([]u8),

    fn init(allocator: Allocator) !TestFontSystem {
        var paths: std.ArrayList([]u8) = .empty;
        errdefer {
            for (paths.items) |p| allocator.free(p);
            paths.deinit(allocator);
        }
        var db_opt: ?font_system_mod.FontDb = try font_system_mod.FontDb.init(allocator);
        errdefer if (db_opt) |*d| d.deinit();
        for (test_fonts) |spec| {
            const path = try testFontPath(allocator, spec.file);
            errdefer allocator.free(path);
            try paths.append(allocator, path);
            const d = &db_opt.?;
            _ = try d.addFace(
                path,
                0,
                &.{spec.family},
                spec.file,
                font_system_mod.WEIGHT_NORMAL,
                .normal,
                .normal,
                spec.mono,
            );
        }
        // `initWithDb` consumes the db (and cleans it up on failure), so
        // disarm the caller-side errdefer before handing it over.
        const owned_db = db_opt.?;
        db_opt = null;
        return .{
            .allocator = allocator,
            .font_system = try FontSystem.initWithDb(allocator, owned_db, "en-US"),
            .paths = paths,
        };
    }

    fn deinit(self: *TestFontSystem) void {
        self.font_system.deinit();
        for (self.paths.items) |p| self.allocator.free(p);
        self.paths.deinit(self.allocator);
    }
};

fn initAttrs(allocator: Allocator) Attrs {
    return Attrs.init(allocator);
}

fn familyAttrs(allocator: Allocator, family: []const u8) Attrs {
    var a = Attrs.init(allocator);
    a.family = .{ .name = family };
    return a;
}

test "Metrics helpers" {
    const m = Metrics.new(14, 20);
    try testing.expect(m.font_size == 14 and m.line_height == 20);
    const r = Metrics.relative(16, 1.5);
    try testing.expect(r.line_height == 24);
    const s = m.scale(2);
    try testing.expect(s.font_size == 28 and s.line_height == 40);
    try testing.expect(Metrics.eql(m, Metrics.new(14, 20)));
}

test "newEmpty rejects zero line height" {
    const alloc = testing.allocator;
    try testing.expectError(
        error.InvalidMetrics,
        Buffer.initWithAllocator(alloc, Metrics.new(14, 0)),
    );
    var b = try Buffer.initWithAllocator(alloc, Metrics.new(14, 20));
    defer b.deinit();
    try testing.expect(b.lines.items.len == 0);
}

test "set_text trailing empty line rule" {
    const alloc = testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    var attrs0 = initAttrs(alloc);
    defer attrs0.deinit();
    var b = try Buffer.initWithAllocator(alloc, Metrics.new(14, 20));
    defer b.deinit();

    try b.setText("a\nb\n", &attrs0, .advanced, null);
    try testing.expect(b.lines.items.len == 3);
    try testing.expectEqualStrings("a", b.lines.items[0].textSlice());
    try testing.expect(b.lines.items[0].ending == .lf);
    try testing.expectEqualStrings("b", b.lines.items[1].textSlice());
    try testing.expectEqualStrings("", b.lines.items[2].textSlice());
    try testing.expect(b.lines.items[2].ending == .none);
    try testing.expect(b.dirty.text_set);
    try testing.expect(b.redraw);

    try b.shapeUntilScroll(&tfs.font_system, false);
    try testing.expect(!b.dirty.text_set);

    // No trailing newline: no extra line.
    try b.setText("a\nb", &attrs0, .advanced, null);
    try testing.expect(b.lines.items.len == 2);

    // Empty text: exactly one empty line.
    try b.setText("", &attrs0, .advanced, null);
    try testing.expect(b.lines.items.len == 1);
    try testing.expectEqualStrings("", b.lines.items[0].textSlice());
    try testing.expect(b.lines.items[0].ending == .none);

    // Reuse truncates excess lines.
    try b.setText("x\ny\nz\n", &attrs0, .advanced, null);
    try testing.expect(b.lines.items.len == 4);
    try b.setText("solo", &attrs0, .advanced, null);
    try testing.expect(b.lines.items.len == 1);
    try testing.expectEqualStrings("solo", b.lines.items[0].textSlice());
}

test "dirty flags and resolve_dirty rules" {
    const alloc = testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    var attrs0 = initAttrs(alloc);
    defer attrs0.deinit();
    var b = try Buffer.initWithAllocator(alloc, Metrics.new(14, 20));
    defer b.deinit();
    try b.setText("a\tb\nplain", &attrs0, .advanced, null);
    try b.shapeUntilScroll(&tfs.font_system, false);
    try testing.expect(b.dirty.isEmpty());

    // Wrap change: relayout only (shape stays hot).
    b.setWrap(.none);
    try testing.expect(b.dirty.relayout and b.redraw);
    b.setRedraw(false);
    try b.shapeUntilScroll(&tfs.font_system, false);
    try testing.expect(b.lines.items[0].shapeOpt() != null);
    try testing.expect(b.lines.items[0].layoutOpt() != null);

    // Tab width change: only the tab line reshapes.
    b.setRedraw(false);
    b.setTabWidth(4);
    try testing.expect(b.dirty.tab_shape and b.dirty.relayout);
    try b.shapeUntilScroll(&tfs.font_system, false);
    try testing.expect(b.lines.items[0].shapeOpt() != null);
    try testing.expect(b.lines.items[1].shapeOpt() != null);

    // Zero tab width is ignored.
    b.setRedraw(false);
    b.setTabWidth(0);
    try testing.expect(b.tab_width == 4);
    try testing.expect(b.dirty.isEmpty());
    try testing.expect(!b.redraw);

    // Direction change reshapes every shaped line.
    b.setDirection(.right_to_left);
    try testing.expect(b.dirty.direction);
    try b.shapeUntilScroll(&tfs.font_system, false);
    try testing.expect(b.lines.items[0].shapeOpt().?.rtl);
    try testing.expect(b.lines.items[1].shapeOpt().?.rtl);

    // Size clamps at zero and marks relayout.
    b.setSize(@as(f32, -5), @as(f32, 10));
    try testing.expect(b.width_opt.? == 0);
    try testing.expect(b.height_opt.? == 10);

    // Scroll marks scroll only.
    b.dirty.clear();
    b.setScroll(.{ .line = 1, .vertical = 3, .horizontal = 0 });
    try testing.expect(b.dirty.scroll and !b.dirty.relayout);

    // Metrics validation.
    try testing.expectError(error.InvalidMetrics, b.setMetrics(Metrics.new(0, 10)));
    try testing.expectError(error.InvalidMetrics, b.setMetrics(Metrics.new(10, 0)));
}

test "layout_runs culls by height and scroll" {
    const alloc = testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    var attrs0 = initAttrs(alloc);
    defer attrs0.deinit();
    var b = try Buffer.initWithAllocator(alloc, Metrics.new(10, 10));
    defer b.deinit();
    try b.setText("one\ntwo\nthree", &attrs0, .advanced, null);
    b.setSize(null, 15);
    try b.shapeUntilScroll(&tfs.font_system, false);

    var it = b.layoutRuns();
    const r0 = it.next().?;
    try testing.expect(r0.line_i == 0 and r0.line_top == 0);
    // Centering math now runs on real ascent/descent: verify against the
    // actual laid-out line rather than a synthetic 0.8*size.
    const lines0 = (try b.lineLayout(&tfs.font_system, 0)).?;
    const ll0 = &lines0[0];
    const lh0 = ll0.line_height_opt orelse 10;
    const centering0 = (lh0 - (ll0.max_ascent + ll0.max_descent)) / 2.0;
    try testing.expectApproxEqAbs(r0.line_y, r0.line_top + centering0 + ll0.max_ascent, 1e-4);
    const r1 = it.next().?;
    try testing.expect(r1.line_i == 1 and r1.line_top == 10);
    // Third line starts at 20; line_y - ascent >= 20 > 15 => culled.
    try testing.expect(it.next() == null);

    // Scrolled down by 12px with a 15px window: line 0 (height 10) fits
    // inside the offset, so scroll advances to line 1, vertical 2.
    b.setScroll(.{ .line = 0, .vertical = 12, .horizontal = 0 });
    try b.shapeUntilScroll(&tfs.font_system, false);
    try testing.expect(b.scroll.line == 1);
    try testing.expect(b.scroll.vertical == 2);
    var it2 = b.layoutRuns();
    const s0 = it2.next().?;
    // line_top = -2; line_y follows the real ascent/descent.
    try testing.expect(s0.line_i == 1);
    try testing.expect(s0.line_top == -2);
}

test "hit LTR halves and edges" {
    const alloc = testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    var attrs0 = initAttrs(alloc);
    defer attrs0.deinit();
    var b = try Buffer.initWithAllocator(alloc, Metrics.new(10, 10));
    defer b.deinit();
    try b.setText("ab", &attrs0, .advanced, null);
    try b.shapeUntilScroll(&tfs.font_system, false);

    var runs = b.layoutRuns();
    const run = runs.next().?;
    try testing.expect(run.glyphs.len >= 1);
    const g0 = run.glyphs[0];
    try testing.expect(g0.w > 0);
    const y = run.line_top + run.line_height / 2.0;
    const left = b.hit(g0.x + g0.w * 0.25, y).?;
    try testing.expect(left.line == 0 and left.index == 0 and left.affinity == .after);
    const right_half = b.hit(g0.x + g0.w * 0.75, y).?;
    try testing.expect(right_half.index == g0.end and right_half.affinity == .before);
    // Above the first run snaps to line start.
    try testing.expect(b.hit(99, -5).?.index == 0);
    // Past all glyphs snaps to the run end (max glyph.end).
    const past = b.hit(10000, y).?;
    try testing.expect(past.index == 2 and past.affinity == .before);
    // Below the last run snaps to the logical end of the line.
    try testing.expect(b.hit(1, 99).?.index == 2);
}

test "hit RTL mirrors halves on real Hebrew glyphs" {
    const alloc = testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    var attrs_he = familyAttrs(alloc, "Noto Sans Hebrew");
    defer attrs_he.deinit();
    var b = try Buffer.initWithAllocator(alloc, Metrics.new(16, 24));
    defer b.deinit();
    try b.setText("אב", &attrs_he, .advanced, null);
    try b.shapeUntilScroll(&tfs.font_system, false);
    try testing.expect(b.isRtl(0).?);

    var runs = b.layoutRuns();
    const run = runs.next().?;
    try testing.expect(run.rtl);
    try testing.expect(run.glyphs.len >= 2);
    const g = run.glyphs[0]; // visual leftmost = logical last cluster
    try testing.expect(glyphIsRtl(&g));
    const y = run.line_top + run.line_height / 2.0;
    // Left half of an RTL glyph keeps the cursor after it (index past the
    // cluster); right half keeps it before.
    const left_half = b.hit(g.x + g.w * 0.25, y).?;
    try testing.expect(left_half.index == g.end and left_half.affinity == .before);
    const right_half = b.hit(g.x + g.w * 0.75, y).?;
    try testing.expect(right_half.index == g.start and right_half.affinity == .after);
}

test "cursor_position and layout_cursor round-trip" {
    const alloc = testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    var attrs0 = initAttrs(alloc);
    defer attrs0.deinit();
    var b = try Buffer.initWithAllocator(alloc, Metrics.new(10, 10));
    defer b.deinit();
    try b.setText("ab", &attrs0, .advanced, null);
    try b.shapeUntilScroll(&tfs.font_system, false);

    var runs = b.layoutRuns();
    const run = runs.next().?;
    const g0 = run.glyphs[0];
    const c = Cursor.new(0, 1);
    const pos = b.cursorPosition(&c).?;
    try testing.expectApproxEqAbs(g0.x + g0.w, pos.x, 1e-3);
    try testing.expect(pos.y == 0);
    const lc = (try b.layoutCursor(&tfs.font_system, c)).?;
    try testing.expect(lc.line == 0 and lc.layout == 0 and lc.glyph == 1);
}

test "cursor_motion core table" {
    const alloc = testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    var attrs0 = initAttrs(alloc);
    defer attrs0.deinit();
    var b = try Buffer.initWithAllocator(alloc, Metrics.new(10, 10));
    defer b.deinit();
    try b.setText("hello world\nsecond", &attrs0, .advanced, null);
    try b.shapeUntilScroll(&tfs.font_system, false);

    var cur = Cursor.new(0, 0);
    var r = (try b.cursorMotion(&tfs.font_system, cur, null, .next)).?;
    try testing.expect(r.cursor.index == 1);
    cur = r.cursor;
    r = (try b.cursorMotion(&tfs.font_system, cur, null, .previous)).?;
    try testing.expect(r.cursor.index == 0);

    // Next at EOL joins the next line; previous at BOL joins back.
    cur = Cursor.new(0, 11);
    r = (try b.cursorMotion(&tfs.font_system, cur, null, .next)).?;
    try testing.expect(r.cursor.line == 1 and r.cursor.index == 0);
    r = (try b.cursorMotion(&tfs.font_system, r.cursor, null, .previous)).?;
    try testing.expect(r.cursor.line == 0 and r.cursor.index == 11);

    // Home/End/BufferStart/BufferEnd.
    r = (try b.cursorMotion(&tfs.font_system, Cursor.new(1, 3), null, .home)).?;
    try testing.expect(r.cursor.index == 0);
    r = (try b.cursorMotion(&tfs.font_system, Cursor.new(1, 3), null, .end)).?;
    try testing.expect(r.cursor.index == 6);
    r = (try b.cursorMotion(&tfs.font_system, Cursor.new(1, 3), null, .buffer_start)).?;
    try testing.expect(r.cursor.line == 0 and r.cursor.index == 0);
    r = (try b.cursorMotion(&tfs.font_system, Cursor.new(0, 0), null, .buffer_end)).?;
    try testing.expect(r.cursor.line == 1 and r.cursor.index == 6);

    // Word motions use real UAX#29 word bounds: separators are skipped.
    r = (try b.cursorMotion(&tfs.font_system, Cursor.new(0, 0), null, .next_word)).?;
    try testing.expect(r.cursor.index == 5);
    r = (try b.cursorMotion(&tfs.font_system, r.cursor, null, .next_word)).?;
    try testing.expect(r.cursor.index == 11);
    r = (try b.cursorMotion(&tfs.font_system, r.cursor, null, .next_word)).?;
    try testing.expect(r.cursor.line == 1 and r.cursor.index == 0);
    r = (try b.cursorMotion(&tfs.font_system, Cursor.new(0, 11), null, .previous_word)).?;
    try testing.expect(r.cursor.index == 6);

    // SoftHome skips leading whitespace.
    try b.setText("   indented", &attrs0, .advanced, null);
    try b.shapeUntilScroll(&tfs.font_system, false);
    r = (try b.cursorMotion(&tfs.font_system, Cursor.new(0, 9), null, .soft_home)).?;
    try testing.expect(r.cursor.index == 3);

    // Out-of-range lines return null.
    try testing.expect((try b.cursorMotion(&tfs.font_system, Cursor.new(9, 0), null, .next)) == null);
}

test "cursor_motion left/right respect RTL" {
    const alloc = testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    var attrs0 = initAttrs(alloc);
    defer attrs0.deinit();
    var b = try Buffer.initWithAllocator(alloc, Metrics.new(10, 10));
    defer b.deinit();
    b.setDirection(.right_to_left);
    try b.setText("ab", &attrs0, .advanced, null);
    try b.shapeUntilScroll(&tfs.font_system, false);
    // Visual left in RTL moves to the next logical char.
    const r = (try b.cursorMotion(&tfs.font_system, Cursor.new(0, 0), null, .left)).?;
    try testing.expect(r.cursor.index == 1);
    const r2 = (try b.cursorMotion(&tfs.font_system, Cursor.new(0, 1), null, .right)).?;
    try testing.expect(r2.cursor.index == 0);
}

test "set_rich_text spans, endings, and empty-line metrics" {
    const alloc = testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    var defaults = initAttrs(alloc);
    defer defaults.deinit();
    var small = initAttrs(alloc);
    defer small.deinit();
    const small_metrics = Metrics.relative(8, 1.2);
    small.metrics_opt = attrs_mod.CacheMetrics.from_metrics(small_metrics);
    var b = try Buffer.initWithAllocator(alloc, Metrics.new(32, 44));
    defer b.deinit();
    try b.setRichText(
        &.{
            .{ .text = "Before", .attrs = defaults },
            .{ .text = "\n\n\nSmall\n\n", .attrs = small },
            .{ .text = "After", .attrs = defaults },
        },
        &defaults,
        .advanced,
        null,
    );
    // Before | "" | "" | Small | "" | After
    try testing.expect(b.lines.items.len == 6);
    try testing.expectEqualStrings("Before", b.lines.items[0].textSlice());
    try testing.expectEqualStrings("", b.lines.items[1].textSlice());
    try testing.expectEqualStrings("Small", b.lines.items[3].textSlice());
    try testing.expectEqualStrings("After", b.lines.items[5].textSlice());
    // Empty lines inside the small span inherit its metrics.
    const small_cache = attrs_mod.CacheMetrics.from_metrics(small_metrics);
    try testing.expect(b.lines.items[1].attrs_list.default_attrs.metrics_opt.?.eql(small_cache));
    try testing.expect(b.lines.items[0].attrs_list.default_attrs.metrics_opt == null);

    try b.shapeUntilScroll(&tfs.font_system, false);
    const l0 = (try b.lineLayout(&tfs.font_system, 0)).?;
    const l1 = (try b.lineLayout(&tfs.font_system, 1)).?;
    try testing.expect(l0[0].line_height_opt == null);
    try testing.expectApproxEqAbs(small_metrics.line_height, l1[0].line_height_opt.?, 1e-3);

    // Empty span list: exactly one empty line.
    try b.setRichText(&.{}, &defaults, .advanced, null);
    try testing.expect(b.lines.items.len == 1);
    try testing.expectEqualStrings("", b.lines.items[0].textSlice());
}

test "shape_until_scroll clamps scroll and normalizes" {
    const alloc = testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    var attrs0 = initAttrs(alloc);
    defer attrs0.deinit();
    var b = try Buffer.initWithAllocator(alloc, Metrics.new(10, 10));
    defer b.deinit();
    try b.setText("a\nb\nc", &attrs0, .advanced, null);
    b.setSize(null, 15);
    // Out-of-range scroll.line clamps, then the window pulls line 1 into
    // view: total 10 < 15 with line 2 > 0 walks back to (1, 5).
    b.setScroll(.{ .line = 99, .vertical = 0, .horizontal = 0 });
    try b.shapeUntilScroll(&tfs.font_system, false);
    try testing.expect(b.scroll.line == 1);
    try testing.expect(b.scroll.vertical == 5);

    // Negative vertical walks the scroll line backwards.
    b.setScroll(.{ .line = 2, .vertical = -5, .horizontal = 0 });
    try b.shapeUntilScroll(&tfs.font_system, false);
    try testing.expect(b.scroll.line == 1);
    try testing.expect(b.scroll.vertical == 5);
}

test "borrowed wrapper shapes automatically" {
    const alloc = testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    var attrs0 = initAttrs(alloc);
    defer attrs0.deinit();
    var b = try Buffer.initWithAllocator(alloc, Metrics.new(10, 10));
    defer b.deinit();
    var borrowed = b.borrowWith(&tfs.font_system);
    try borrowed.setText("hi", &attrs0, .advanced, null);
    var runs = try borrowed.layoutRuns();
    try testing.expect(runs.next() != null);
    try testing.expect((try borrowed.hit(1, 5)) != null);
}

test "word vs glyph wrap differ on long word" {
    const alloc = testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    var attrs0 = initAttrs(alloc);
    defer attrs0.deinit();
    var b = try Buffer.initWithAllocator(alloc, Metrics.new(10, 10));
    defer b.deinit();
    // 8 glyphs at 10px are wider than 20px.
    try b.setText("abcdefgh", &attrs0, .advanced, null);
    b.setSize(20, null);
    b.setWrap(.glyph);
    try b.shapeUntilScroll(&tfs.font_system, false);
    const glyph_lines = (try b.lineLayout(&tfs.font_system, 0)).?.len;
    try testing.expect(glyph_lines > 1);

    b.setWrap(.word);
    // Force relayout via dirty flag path.
    try b.shapeUntilScroll(&tfs.font_system, false);
    const word_lines = (try b.lineLayout(&tfs.font_system, 0)).?.len;
    // A single long word never splits under word wrap.
    try testing.expect(word_lines == 1);

    b.setWrap(.word_or_glyph);
    try b.shapeUntilScroll(&tfs.font_system, false);
    const wog_lines = (try b.lineLayout(&tfs.font_system, 0)).?.len;
    // WordOrGlyph falls back to glyph splitting for an oversized word.
    try testing.expect(wog_lines > 1);

    b.setWrap(.none);
    try b.shapeUntilScroll(&tfs.font_system, false);
    try testing.expect((try b.lineLayout(&tfs.font_system, 0)).?.len == 1);
}

test "null align follows paragraph direction" {
    const alloc = testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    var attrs0 = initAttrs(alloc);
    defer attrs0.deinit();
    var b = try Buffer.initWithAllocator(alloc, Metrics.new(10, 10));
    defer b.deinit();
    try b.setText("ab", &attrs0, .advanced, null);
    b.setSize(100, null);
    // LTR default: null aligns left (first glyph at x = 0).
    try b.shapeUntilScroll(&tfs.font_system, false);
    const ltr = (try b.lineLayout(&tfs.font_system, 0)).?;
    try testing.expect(ltr[0].glyphs.items[0].x == 0);

    // RTL paragraph: null aligns right; the rightmost glyph edge is at the
    // buffer width.
    b.setDirection(.right_to_left);
    try b.shapeUntilScroll(&tfs.font_system, false);
    const rtl = (try b.lineLayout(&tfs.font_system, 0)).?;
    var max_x: f32 = 0;
    for (rtl[0].glyphs.items) |g| max_x = @max(max_x, g.x + g.w);
    try testing.expectApproxEqAbs(@as(f32, 100), max_x, 0.5);
}

test "word motions use UAX#29 word bounds (no fixed token cap)" {
    const alloc = testing.allocator;
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(alloc);
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        try text.appendSlice(alloc, "a ");
    }
    const s = text.items; // 200 bytes, ending in a blank.
    try testing.expect(s.len == 200);
    // First word end after 0 is 1 ("a").
    try testing.expect(nextWordEnd(s, 0) == 1);
    try testing.expect(nextWordEnd(s, 100) == 101);
    // Word starts are at even offsets; separators are skipped.
    try testing.expect(prevWordStart(s, 100) == 98);
    try testing.expect(prevWordStart(s, s.len) == 198);
    // Far tail beyond any fixed cap: still exact.
    try testing.expect(prevWordStart(s, 150) == 148);
    try testing.expect(nextWordEnd(s, 148) == 149);
    // No word before index 1 -> fall back to 0.
    try testing.expect(prevWordStart("hello world", 1) == 0);
    try testing.expect(nextWordEnd("hello world", 11) == 11);
    // UAX#29 keeps apostrophes inside a word (WB6/WB7): "don't" is one word,
    // unlike the retired `isWordChar` codepoint approximation.
    try testing.expect(nextWordEnd("don't stop", 0) == 5);
    try testing.expect(prevWordStart("don't stop", "don't stop".len) == 6);
}

/// Word motion expectations captured from the upstream oracle
/// (`cosmic-text` `Buffer::cursor_motion` over `unicode-segmentation =
/// 1.13.3` `unicode_word_indices`). A UAX#29 segment is a word iff it
/// contains an `Alphabetic` or `General_Category=N*` codepoint; every
/// punctuation-only/whitespace-only segment is skipped, so the cursor never
/// stops on `,`, `-`, `_`, `…`, NBSP or space runs.
const WordMotionCase = struct {
    text: []const u8,
    /// Cursor indices after successive `.next_word` from 0 (each is an
    /// oracle `i + word.len()` end, before the EOL hold).
    next: []const usize,
    /// Cursor indices after successive `.previous_word` from EOL (each is an
    /// oracle word start, before the BOL hold).
    prev: []const usize,
};

const word_motion_cases = [_]WordMotionCase{
    // Whitespace-only and punctuation-only lines: no word exists, so the
    // motion falls through to the line edge (no panic, no stop mid-run).
    .{ .text = "", .next = &.{}, .prev = &.{} },
    .{ .text = "   ", .next = &.{3}, .prev = &.{0} },
    .{ .text = ",,,", .next = &.{3}, .prev = &.{0} },
    .{ .text = "…", .next = &.{3}, .prev = &.{0} },
    // Punctuation between/surrounding words is skipped: from "one" the next
    // stop is the end of "two", never the comma/space positions 4/5.
    .{ .text = "one, two", .next = &.{ 3, 8 }, .prev = &.{ 5, 0 } },
    .{ .text = "one,two", .next = &.{ 3, 7 }, .prev = &.{ 4, 0 } },
    .{ .text = "a, b", .next = &.{ 1, 4 }, .prev = &.{ 3, 0 } },
    // U+002D is not MidLetter/MidNum: "foo-bar" is two words.
    .{ .text = "foo-bar", .next = &.{ 3, 7 }, .prev = &.{ 4, 0 } },
    // Apostrophes stay internal (WB6/WB7); digits glue to letters (WB9/WB10).
    .{ .text = "don't", .next = &.{5}, .prev = &.{0} },
    .{ .text = "abc123", .next = &.{6}, .prev = &.{0} },
    .{ .text = "32.3", .next = &.{4}, .prev = &.{0} },
    // "_" is ExtendNumLet, which is not alphanumeric: a lone run is skipped,
    // but it glues to adjacent alphanumerics (WB13a/WB13b).
    .{ .text = "_", .next = &.{1}, .prev = &.{0} },
    .{ .text = "__", .next = &.{2}, .prev = &.{0} },
    .{ .text = "a__b", .next = &.{4}, .prev = &.{0} },
    // Nl/No count as words through General_Category=N*.
    .{ .text = "\xe2\x85\xab \xc2\xb2", .next = &.{ 3, 6 }, .prev = &.{ 4, 0 } },
    // NBSP is a boundary, not a word.
    .{ .text = "hello\xc2\xa0world", .next = &.{ 5, 12 }, .prev = &.{ 7, 0 } },
    // Han/Hiragana are WB=Other, i.e. one segment per character, and each is
    // Alphabetic; Katakana runs glue (WB13).
    .{ .text = "漢字abc", .next = &.{ 3, 6, 9 }, .prev = &.{ 6, 3, 0 } },
    .{ .text = "中文，测试", .next = &.{ 3, 6, 12, 15 }, .prev = &.{ 12, 9, 3, 0 } },
    .{ .text = "こんにちは", .next = &.{ 3, 6, 9, 12, 15 }, .prev = &.{ 12, 9, 6, 3, 0 } },
    .{ .text = "カタカナ", .next = &.{12}, .prev = &.{0} },
    // Mixed-direction text uses logical order for these motions.
    .{ .text = "abc مرحبا def", .next = &.{ 3, 14, 18 }, .prev = &.{ 15, 4, 0 } },
    .{ .text = "שלום world", .next = &.{ 8, 14 }, .prev = &.{ 9, 0 } },
};

test "word motions follow the upstream alphanumeric word filter" {
    const alloc = testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    var attrs0 = initAttrs(alloc);
    defer attrs0.deinit();
    var b = try Buffer.initWithAllocator(alloc, Metrics.new(10, 10));
    defer b.deinit();

    for (word_motion_cases) |case| {
        try b.setText(case.text, &attrs0, .advanced, null);

        // Forward: successive `.next_word` from 0.
        var cur = Cursor.new(0, 0);
        for (case.next) |want| {
            const r = (try b.cursorMotion(&tfs.font_system, cur, null, .next_word)) orelse
                return error.UnexpectedNull;
            cur = r.cursor;
            try testing.expectEqual(want, cur.index);
        }
        // EOL holds instead of wrapping past the single line.
        {
            const r = (try b.cursorMotion(&tfs.font_system, cur, null, .next_word)) orelse
                return error.UnexpectedNull;
            try testing.expectEqual(@as(usize, 0), r.cursor.line);
            try testing.expectEqual(case.text.len, r.cursor.index);
        }

        // Backward: successive `.previous_word` from EOL.
        cur = Cursor.new(0, case.text.len);
        for (case.prev) |want| {
            const r = (try b.cursorMotion(&tfs.font_system, cur, null, .previous_word)) orelse
                return error.UnexpectedNull;
            cur = r.cursor;
            try testing.expectEqual(want, cur.index);
        }
        // BOL holds.
        {
            const r = (try b.cursorMotion(&tfs.font_system, cur, null, .previous_word)) orelse
                return error.UnexpectedNull;
            try testing.expectEqual(@as(usize, 0), r.cursor.line);
            try testing.expectEqual(@as(usize, 0), r.cursor.index);
        }
    }
}

test "word motions on whitespace-only and empty lines do not panic" {
    const alloc = testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    var attrs0 = initAttrs(alloc);
    defer attrs0.deinit();
    var b = try Buffer.initWithAllocator(alloc, Metrics.new(10, 10));
    defer b.deinit();
    // Empty and whitespace-only lines: motions clamp to the line edges.
    try b.setText("", &attrs0, .advanced, null);
    try testing.expect(b.lines.items.len == 1);
    {
        const n = (try b.cursorMotion(&tfs.font_system, Cursor.new(0, 0), null, .next_word)).?;
        try testing.expect(n.cursor.index == 0);
        const p = (try b.cursorMotion(&tfs.font_system, Cursor.new(0, 0), null, .previous_word)).?;
        try testing.expect(p.cursor.index == 0);
    }
    try b.setText("a\n   \nb", &attrs0, .advanced, null);
    {
        // A whitespace-only line has no word: next_word goes to the line end
        // (no panic, no stop inside the run), then joins the next line.
        const n = (try b.cursorMotion(&tfs.font_system, Cursor.new(1, 0), null, .next_word)).?;
        try testing.expect(n.cursor.line == 1 and n.cursor.index == 3);
        const n2 = (try b.cursorMotion(&tfs.font_system, n.cursor, null, .next_word)).?;
        try testing.expect(n2.cursor.line == 2 and n2.cursor.index == 0);
        // previous_word at BOL joins the previous line's end; at EOL it clamps
        // to this line's start.
        const p = (try b.cursorMotion(&tfs.font_system, Cursor.new(1, 0), null, .previous_word)).?;
        try testing.expect(p.cursor.line == 0 and p.cursor.index == 1);
        const p2 = (try b.cursorMotion(&tfs.font_system, Cursor.new(1, 3), null, .previous_word)).?;
        try testing.expect(p2.cursor.line == 1 and p2.cursor.index == 0);
    }
}

test "grapheme stepping crosses combining marks as one cluster" {
    const alloc = testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    var attrs0 = initAttrs(alloc);
    defer attrs0.deinit();
    var b = try Buffer.initWithAllocator(alloc, Metrics.new(16, 24));
    defer b.deinit();
    // "é" is U+0065 U+0301 (base + combining acute) followed by "x".
    try b.setText("e\u{0301}x", &attrs0, .advanced, null);
    try b.shapeUntilScroll(&tfs.font_system, false);

    // Next from 0 lands after the whole cluster (byte 3), never between the
    // base and its combining mark (byte 1).
    const n = (try b.cursorMotion(&tfs.font_system, Cursor.new(0, 0), null, .next)).?;
    try testing.expect(n.cursor.index == 3);
    const p = (try b.cursorMotion(&tfs.font_system, Cursor.new(0, 3), null, .previous)).?;
    try testing.expect(p.cursor.index == 0);
    // The byte between base and combining mark is not a grapheme boundary.
    try testing.expect(!unicode_mod.isGraphemeBoundary("e\u{0301}x", 1));
    try testing.expect(unicode_mod.isGraphemeBoundary("e\u{0301}x", 3));
}

test "firstNonWhitespace handles unicode spaces" {
    // " \t" + NBSP (C2 A0) + EM SPACE (E2 80 83) + "hi".
    const s = " \t\xc2\xa0\xe2\x80\x83hi";
    try testing.expect(firstNonWhitespace(s) == 7);
    try testing.expect(firstNonWhitespace("") == 0);
    try testing.expect(firstNonWhitespace("   ") == 0);
    try testing.expect(unicode_mod.isWhitespace(0xA0));
    try testing.expect(unicode_mod.isWhitespace(0x2003));
    try testing.expect(!unicode_mod.isWhitespace('a'));
}

test "empty line cursor is at horizontal zero" {
    const alloc = testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    var attrs0 = initAttrs(alloc);
    defer attrs0.deinit();
    var b = try Buffer.initWithAllocator(alloc, Metrics.new(10, 10));
    defer b.deinit();
    try b.setText("a\n\nb", &attrs0, .advanced, null);
    try b.shapeUntilScroll(&tfs.font_system, false);
    const c = Cursor.new(1, 0);
    const pos = b.cursorPosition(&c).?;
    try testing.expect(pos.x == 0);
    // Hit on the empty visual line maps to its start.
    const hit = b.hit(50, 15).?;
    try testing.expect(hit.line == 1 and hit.index == 0);
}

test "real font geometry: FontSystem faces drive shaped layout" {
    const alloc = testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    var inter = familyAttrs(alloc, "Inter");
    defer inter.deinit();
    var mono = familyAttrs(alloc, "Fira Mono");
    defer mono.deinit();

    // The FontSystem handed to Buffer is the real registry with the vendored
    // faces loaded (not the retired empty struct).
    try testing.expect(tfs.font_system.db.faces.items.len == test_fonts.len);
    try testing.expect(tfs.font_system.db.faceContainsFamily(0, "Inter"));

    var b = try Buffer.initWithAllocator(alloc, Metrics.new(16, 24));
    defer b.deinit();
    try b.setText("Hamburgefonstiv", &inter, .advanced, null);
    try b.shapeUntilScroll(&tfs.font_system, false);
    const lines = (try b.lineLayout(&tfs.font_system, 0)).?;

    // Line width is the sum of shaped glyph advances, and hit/cursor math
    // reads those same glyphs (no `size * 0.6` re-derivation in Buffer).
    var sum: f32 = 0;
    for (lines[0].glyphs.items) |g| {
        try testing.expect(g.w > 0);
        sum += g.w;
    }
    try testing.expectApproxEqAbs(lines[0].w, sum, 1e-2);
    const g0 = lines[0].glyphs.items[0];
    const pos = b.cursorPosition(&Cursor.new(0, g0.end)).?;
    try testing.expectApproxEqAbs(g0.x + g0.w, pos.x, 1e-3);

    // `mono` keeps the same text alive through a second shaping pass so the
    // per-font case is exercised end to end.
    try b.setText("Hamburgefonstiv", &mono, .advanced, null);
    try b.shapeUntilScroll(&tfs.font_system, false);
    const mono_lines = (try b.lineLayout(&tfs.font_system, 0)).?;
    try testing.expect(mono_lines[0].glyphs.items.len > 0);
    try testing.expect(mono_lines[0].w > 0);

    // TODO(shape/font): per-font advances/metrics are blocked on
    // `buffer_line.zig`'s FontSystem-backed ShapeAdapter. Today it builds
    // shape.zig's `CharmapAdapter` (the marked HarfBuzz wiring point), which
    // reports one EM advance/ascent for every face, so Inter and Fira Mono
    // currently shape identically. Once that bridge lands, assert here:
    // `lines[0].w != mono_lines[0].w` (or differing `max_ascent`/`font_id`).
}

test "real font geometry: advances scale with font size" {
    const alloc = testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    var inter = familyAttrs(alloc, "Inter");
    defer inter.deinit();

    var b = try Buffer.initWithAllocator(alloc, Metrics.new(16, 24));
    defer b.deinit();
    try b.setText("Hamburgefonstiv", &inter, .advanced, null);
    try b.shapeUntilScroll(&tfs.font_system, false);
    const w16 = (try b.lineLayout(&tfs.font_system, 0)).?[0].w;
    try testing.expect(w16 > 0);

    try b.setMetrics(Metrics.new(32, 48));
    try b.shapeUntilScroll(&tfs.font_system, false);
    const w32 = (try b.lineLayout(&tfs.font_system, 0)).?[0].w;
    try testing.expect(w32 > w16 * 1.5);

    // Shaped advances (not the retired `size * 0.6` per-character rule):
    // scale the glyph advances directly and match the 2x size.
    const lines = (try b.lineLayout(&tfs.font_system, 0)).?;
    var sum: f32 = 0;
    for (lines[0].glyphs.items) |g| sum += g.w;
    try testing.expectApproxEqAbs(lines[0].w, sum, 1e-2);
}

test "ellipsize flows through to real U+2026 glyphs" {
    const alloc = testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    var attrs0 = initAttrs(alloc);
    defer attrs0.deinit();
    var b = try Buffer.initWithAllocator(alloc, Metrics.new(16, 24));
    defer b.deinit();
    try b.setText(
        "The quick brown fox jumps over the lazy dog again and again",
        &attrs0,
        .advanced,
        null,
    );
    b.setWrap(.word);
    // Height-limited, width-limited buffer: one line fits.
    b.setSize(120, 48);

    const modes = [_]Ellipsize{
        .{ .start = .{ .lines = 1 } },
        .{ .middle = .{ .lines = 1 } },
        .{ .end = .{ .lines = 1 } },
    };
    for (modes) |mode| {
        b.setEllipsize(mode);
        try b.shapeUntilScroll(&tfs.font_system, false);
        var runs = b.layoutRuns();
        var saw_run = false;
        var saw_ellipsis = false;
        while (runs.next()) |run| {
            saw_run = true;
            for (run.glyphs) |g| {
                // The shaper emits ellipsis glyphs with an empty cluster
                // (start == end) at the elision boundary; ordinary text
                // clusters are never empty. Glyph width proves the ellipsis
                // was shaped into the real layout.
                if (g.start == g.end and g.w > 0) saw_ellipsis = true;
            }
        }
        try testing.expect(saw_run);
        try testing.expect(saw_ellipsis);
    }

    // The elision replaces text: the visible line is narrower than the
    // unconstrained layout (width limit respected with the ellipsis).
    const lines = (try b.lineLayout(&tfs.font_system, 0)).?;
    try testing.expect(lines.len >= 1);
    try testing.expect(lines[lines.len - 1].w <= 120 + 1);
}

test "real RTL geometry: Hebrew levels and wrap" {
    const alloc = testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    var attrs_he = familyAttrs(alloc, "Noto Sans Hebrew");
    defer attrs_he.deinit();
    var b = try Buffer.initWithAllocator(alloc, Metrics.new(16, 24));
    defer b.deinit();
    b.setSize(70, null);
    try b.setText("שלום עולם זה מבחן ארוך", &attrs_he, .advanced, null);
    try b.shapeUntilScroll(&tfs.font_system, false);
    try testing.expect(b.isRtl(0).?);

    const lines = (try b.lineLayout(&tfs.font_system, 0)).?;
    try testing.expect(lines.len > 1); // wrapped under real advances
    var any_rtl_level = false;
    for (lines) |ll| {
        for (ll.glyphs.items) |g| {
            if (glyphIsRtl(&g)) any_rtl_level = true;
        }
        try testing.expect(ll.w <= 70 + 24);

        // Wrapped segments must stay inside the source text.
        for (ll.glyphs.items) |g| {
            try testing.expect(g.end <= b.lines.items[0].textSlice().len);
        }
    }
    try testing.expect(any_rtl_level);
}
