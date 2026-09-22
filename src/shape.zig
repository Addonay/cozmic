//! Port of cosmic-text `shape.rs` (3084 lines): shaping core types + layout engine.
//!
//! Type ownership follows `types.zig`; canonical owners are imported:
//! - `attrs.zig`: Metrics, Color, Weight, Style (`FontStyle`), Attrs,
//!   AttrsList, UnderlineStyle, TextDecoration, CacheKeyFlags,
//!   DecorationMetrics, GlyphDecorationData.
//! - `layout.zig`: LayoutGlyph, LayoutLine, DecorationSpan, Wrap, Align,
//!   Ellipsize, EllipsizeHeightLimit, Hinting.
//! - `unicode.zig`: Script/scriptOf/collectScripts, grapheme clusters,
//!   UAX#14 line breaks, UAX#9 paragraph levels.
//! `FontId` is a placeholder `u32` owned by `layout.zig` until `font.zig`
//! becomes the canonical owner.
//!
//! Section map to `shape.rs` (verbatim ports are marked with line refs):
//! - `Shaping`, `Direction` ........................... shape.rs:26-106
//! - `ShapeBuffer` (plan cache FIFO cap 6) ............ shape.rs:108-141
//! - HarfBuzz path (`shape_fallback`, `shape_run`) .... shape.rs:143-438
//!   via the narrow `ShapeAdapter` vtable + pure-Zig `CharmapAdapter`.
//!   WIRING POINT (`hb_shape_plan_execute`): replace `CharmapAdapter.shapeRun`
//!   with `harfrust` plan lookup + `shape_with_plan`; the surrounding logic
//!   (tab rewrite, plan-cache FIFO, missing-glyph splice, end adjustment,
//!   script collection) is already verbatim.
//! - Fallback memoization: the optional `ShapeAdapter.VTable.note_fallback`
//!   hook reports each fallback attempt's coverage after the splice; it
//!   defaults to a no-op, so adapters and tests without a cache need no
//!   changes. The bounded cache itself lives in `shape_hb.Backend`
//!   (per query attrs + script, invalidated on font registration); `shapeRun`
//!   remains cache-agnostic and only reports outcomes.
//! - `shape_run_cached` key building .................. shape.rs:440-498
//! - Basic path (`shape_skip` + repatch) .............. shape.rs:500-638
//! - `override_fake_italic` ........................... shape.rs:640-650
//! - `ShapeGlyph` ..................................... shape.rs:652-708
//! - `decoration_metrics` ............................. shape.rs:710-731
//! - `ELLIPSIS_SPAN`, `shape_ellipsis` ................ shape.rs:733-773
//! - `ShapeWord` fast/slow paths ...................... shape.rs:775-912
//! - `ShapeSpan` splitting ............................ shape.rs:914-1212
//! - `ShapeLine::build`, `adjust_levels` .............. shape.rs:1215-1530
//! - `reorder` (L2) ................................... shape.rs:1532-1587
//! - `layout`, `fit_glyphs`, `layout_spans`, .......... shape.rs:1589-2302
//!   `layout_middle`, ellipsis helpers
//! - `layout_to_buffer` full engine ................... shape.rs:2304-3083

const std = @import("std");
const attrs_mod = @import("attrs.zig");
const layout = @import("layout.zig");
const unicode = @import("unicode.zig");

pub const ShapeError = error{
    OutOfMemory,
    /// BiDi level overflow in `reorder` (`new_lowest_ge_rtl`, shape.rs:1556).
    LevelOverflow,
    /// Glyph byte-offset underflow in `rebaseGlyphs`.
    GlyphUnderflow,
    /// Ellipsis range references a missing `ellipsis_span`.
    EllipsisNotShaped,
    /// A lazily registered font source could not be loaded (missing file,
    /// unreadable path, invalid font data). Shaping callers propagate it;
    /// non-fallible adapter queries degrade instead.
    FontUnavailable,
};

// ---------------------------------------------------------------------------
// Canonical re-exports (owners: attrs.zig / layout.zig / unicode.zig)
// ---------------------------------------------------------------------------

/// Placeholder font identifier (owned by `layout.zig` until `font.zig`).
pub const FontId = layout.FontId;

pub const Weight = attrs_mod.Weight;
pub const WEIGHT_NORMAL: Weight = Weight.normal;

pub const Color = attrs_mod.Color;

pub const CacheKeyFlags = attrs_mod.CacheKeyFlags;
/// Skew by 14 degrees to synthesize italic (glyph_cache.rs bit 1).
pub const FLAG_FAKE_ITALIC: CacheKeyFlags = .{ .bits = 1 };

/// Unicode BiDi embedding level: even = LTR, odd = RTL.
pub const Level = layout.Level;
pub const LEVEL_LTR: Level = 0;
pub const LEVEL_RTL: Level = 1;
pub const levelIsRtl = unicode.levelIsRtl;

pub const Metrics = attrs_mod.Metrics;
pub const FontStyle = attrs_mod.Style;
pub const UnderlineStyle = attrs_mod.UnderlineStyle;
pub const TextDecoration = attrs_mod.TextDecoration;
pub const DecorationMetrics = attrs_mod.DecorationMetrics;
pub const GlyphDecorationData = attrs_mod.GlyphDecorationData;

pub const Attrs = attrs_mod.Attrs;
pub const AttrsList = attrs_mod.AttrsList;
pub const Span = attrs_mod.Span;

pub const BidiClass = unicode.BidiClass;
pub const Script = unicode.Script;
pub const scriptOf = unicode.scriptOf;
pub const collectScripts = unicode.collectScripts;

/// Grapheme cursor over a byte range (UAX#29 via `unicode.zig`).
pub const GraphemeCursor = unicode.GraphemeIndices;

pub const Wrap = layout.Wrap;
pub const Align = layout.Align;
pub const Ellipsize = layout.Ellipsize;
pub const EllipsizeHeightLimit = layout.EllipsizeHeightLimit;
pub const Hinting = layout.Hinting;
pub const LayoutGlyph = layout.LayoutGlyph;
pub const LayoutLine = layout.LayoutLine;
pub const DecorationSpan = layout.DecorationSpan;

/// Hash canonical owned attrs for run-cache keys.
pub fn hashAttrs(a: *const attrs_mod.AttrsOwned) u64 {
    var h = std.hash.Wyhash.init(0);
    a.hash(&h);
    return h.final();
}

/// `true` when `family` is an explicit font name (drives Basic repatch).
fn familyIsNamed(a: *const attrs_mod.AttrsOwned) bool {
    return switch (a.family_owned.as_family()) {
        .name => true,
        else => false,
    };
}

/// `Attrs::compatible` (attrs.rs:413-418): same shaping-relevant font
/// selection, so one HarfBuzz run covers both.
pub fn attrsCompatible(a: *const attrs_mod.AttrsOwned, b: *const attrs_mod.AttrsOwned) bool {
    return a.family_owned.eql(&b.family_owned) and
        a.stretch.eql(b.stretch) and
        a.style.eql(b.style) and
        a.weight.eql(b.weight);
}

fn letterSpacing(a: *const attrs_mod.AttrsOwned) f32 {
    return if (a.letter_spacing_opt) |ls| ls.value else 0;
}

fn metricsOpt(a: *const attrs_mod.AttrsOwned) ?attrs_mod.Metrics {
    return if (a.metrics_opt) |m| m.to_metrics() else null;
}

// ---------------------------------------------------------------------------
// UTF-8 / Unicode helpers (self-contained; ezi-code UAX logic is the oracle)
// ---------------------------------------------------------------------------

fn utf8CharLen(first: u8) usize {
    if (first < 0x80) return 1;
    if (first >> 5 == 0b110) return 2;
    if (first >> 4 == 0b1110) return 3;
    if (first >> 3 == 0b11110) return 4;
    return 1;
}

const Decoded = struct {
    cp: u21,
    len: usize,
};

fn decodeOne(text: []const u8, i: usize) Decoded {
    const first = text[i];
    const len = utf8CharLen(first);
    if (i + len > text.len) return .{ .cp = 0xFFFD, .len = 1 };
    if (len == 1) {
        if (first < 0x80) return .{ .cp = first, .len = 1 };
        return .{ .cp = 0xFFFD, .len = 1 };
    }
    var cp: u21 = switch (len) {
        2 => @as(u21, first & 0x1F),
        3 => @as(u21, first & 0x0F),
        else => @as(u21, first & 0x07),
    };
    var j: usize = 1;
    while (j < len) : (j += 1) {
        const b = text[i + j];
        if (b >> 6 != 0b10) return .{ .cp = 0xFFFD, .len = 1 };
        cp = (cp << 6) | @as(u21, b & 0x3F);
    }
    // Reject overlongs / surrogates / out-of-range.
    const min: u21 = switch (len) {
        2 => 0x80,
        3 => 0x800,
        else => 0x10000,
    };
    if (cp < min or (cp >= 0xD800 and cp <= 0xDFFF) or cp > 0x10FFFF) {
        return .{ .cp = 0xFFFD, .len = 1 };
    }
    return .{ .cp = cp, .len = len };
}

fn isAsciiPunct(cp: u21) bool {
    return (cp < 0x80) and switch (@as(u8, @intCast(cp))) {
        '!', '"', '#', '$', '%', '&', '\'', '(', ')', '*', '+', ',', '-', '.', '/', ':', ';', '<', '=', '>', '?', '@', '[', '\\', ']', '^', '_', '`', '{', '|', '}', '~' => true,
        else => false,
    };
}

// ---------------------------------------------------------------------------
// Shaping strategy + base direction (shape.rs:26-106)
// ---------------------------------------------------------------------------

/// The shaping strategy of some text (shape.rs:26-44).
pub const Shaping = enum {
    /// Basic shaping with no font fallback (cheap; caller controls text+font).
    basic,
    /// Advanced shaping and font fallback.
    advanced,

    pub fn run(
        self: Shaping,
        alloc: std.mem.Allocator,
        adapter: ShapeAdapter,
        buf: *ShapeBuffer,
        out: *std.ArrayList(ShapeGlyph),
        line: []const u8,
        attrs: *const AttrsList,
        start_run: usize,
        end_run: usize,
        span_rtl: bool,
    ) ShapeError!void {
        switch (self) {
            .basic => try shapeSkip(alloc, adapter, out, line, attrs, start_run, end_run),
            .advanced => try shapeRun(alloc, adapter, buf, out, line, attrs, start_run, end_run, span_rtl),
        }
    }
};

/// Base direction used when shaping text (shape.rs:84-106).
pub const Direction = enum {
    auto,
    left_to_right,
    right_to_left,

    /// Base paragraph level for the bidi algorithm, or `null` to auto-detect
    /// from the text (shape.rs:96-106).
    pub fn bidiLevel(self: Direction) ?Level {
        return switch (self) {
            .auto => null,
            .left_to_right => LEVEL_LTR,
            .right_to_left => LEVEL_RTL,
        };
    }
};

// ---------------------------------------------------------------------------
// Scripts: canonical in `unicode.zig` (`Script`, `scriptOf`,
// `collectScripts`); re-exported at the top of this file.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// ShapeBuffer scratch (shape.rs:108-141)
// ---------------------------------------------------------------------------

pub const NUM_SHAPE_PLANS: usize = 6;

const PlanEntry = struct {
    font_id: FontId,
    script: Script,
    rtl: bool,
};

/// FIFO plan cache: up to `NUM_SHAPE_PLANS` plans; inserting past capacity
/// evicts the least recently *added* (shape.rs:113-115, 209-220).
pub const PlanCache = struct {
    entries: [NUM_SHAPE_PLANS]PlanEntry = undefined,
    len: usize = 0,

    pub fn find(self: *const PlanCache, font_id: FontId, script: Script, rtl: bool) ?usize {
        for (self.entries[0..self.len], 0..) |e, i| {
            if (e.font_id == font_id and e.script == script and e.rtl == rtl) return i;
        }
        return null;
    }

    /// Returns the plan index, evicting the front entry when full.
    pub fn getOrPut(self: *PlanCache, font_id: FontId, script: Script, rtl: bool) usize {
        if (self.find(font_id, script, rtl)) |i| return i;
        if (self.len >= NUM_SHAPE_PLANS) {
            // pop_front (shape.rs:211-213).
            std.mem.copyForwards(PlanEntry, self.entries[0 .. NUM_SHAPE_PLANS - 1], self.entries[1..NUM_SHAPE_PLANS]);
            self.len = NUM_SHAPE_PLANS - 1;
        }
        self.entries[self.len] = .{ .font_id = font_id, .script = script, .rtl = rtl };
        self.len += 1;
        return self.len - 1;
    }
};

pub const VisualLine = struct {
    ranges: std.ArrayList(VlRange) = .empty,
    spaces: u32 = 0,
    w: f32 = 0,
    ellipsized: bool = false,
    elided_byte_range: ?[2]usize = null,

    pub fn clear(self: *VisualLine) void {
        self.ranges.clearRetainingCapacity();
        self.spaces = 0;
        self.w = 0;
        self.ellipsized = false;
        self.elided_byte_range = null;
    }

    pub fn deinit(self: *VisualLine, alloc: std.mem.Allocator) void {
        self.ranges.deinit(alloc);
    }
};

/// Scratch buffers for shaped text (shape.rs:110-135).
///
/// Pooling note: `visual_lines` / `cached_visual_lines` / `glyph_sets` retain
/// `ArrayList` capacity across layouts exactly like the Rust scratch sets.
/// `span_pool` / `word_pool` recycle span/word *shells* for the buffer-layer
/// rebuild cycle; word glyph payloads are owned slices (see `freeShapeWord`
/// via `ShapeWord.deinitChildren`), so unlike Rust's nested-`Vec` take/restore
/// they do not retain inner capacity — documented trade-off of the
/// slice-based word payload design (TODO(shape): revisit with an arena paged
/// store).
pub const ShapeBuffer = struct {
    plans: PlanCache = .{},
    scripts: std.ArrayList(Script) = .empty,
    span_pool: std.ArrayList(ShapeSpan) = .empty,
    word_pool: std.ArrayList(ShapeWord) = .empty,
    visual_lines: std.ArrayList(VisualLine) = .empty,
    cached_visual_lines: std.ArrayList(VisualLine) = .empty,
    glyph_sets: std.ArrayList(std.ArrayList(LayoutGlyph)) = .empty,

    pub fn init() ShapeBuffer {
        return .{};
    }

    pub fn deinit(self: *ShapeBuffer, alloc: std.mem.Allocator) void {
        self.scripts.deinit(alloc);
        for (self.span_pool.items) |*s| s.deinitChildren(alloc);
        self.span_pool.deinit(alloc);
        for (self.word_pool.items) |*w| w.deinitChildren(alloc);
        self.word_pool.deinit(alloc);
        for (self.visual_lines.items) |*vl| vl.deinit(alloc);
        self.visual_lines.deinit(alloc);
        for (self.cached_visual_lines.items) |*vl| vl.deinit(alloc);
        self.cached_visual_lines.deinit(alloc);
        for (self.glyph_sets.items) |*g| g.deinit(alloc);
        self.glyph_sets.deinit(alloc);
    }

    pub fn takeVisualLine(self: *ShapeBuffer) VisualLine {
        return self.cached_visual_lines.pop() orelse .{};
    }

    pub fn takeGlyphSet(self: *ShapeBuffer) std.ArrayList(LayoutGlyph) {
        return self.glyph_sets.pop() orelse .empty;
    }
};

// ---------------------------------------------------------------------------
// Shaping adapter (narrow HarfBuzz/swash seam; pure-Zig fallback included)
// ---------------------------------------------------------------------------

/// One shaped glyph from the backend. `cluster` is the byte offset (relative
/// to the run start) of the shaping cluster, mirroring `info.cluster`.
pub const ShapedRunGlyph = struct {
    glyph_id: u16,
    cluster: usize,
    x_advance: f32,
    y_advance: f32,
    x_offset: f32,
    y_offset: f32,
};

/// EM-normalized font metrics for shaping.
pub const ShapingFontMetrics = struct {
    ascent: f32,
    descent: f32,
    monospace_width: ?f32 = null,
    italic_or_oblique: bool = false,
    monospaced: bool = false,
    /// Design-unit underline metrics from the face (`post`), or null to use
    /// the cosmic-text fallbacks in `decorationMetrics`.
    underline: ?DecoSpec = null,
    /// Design-unit strikeout metrics from the face (`OS/2`), or null fallback.
    strikethrough: ?DecoSpec = null,
    /// Design units per em and ascent in design units, for
    /// `decorationMetrics` (shape.rs:710-731).
    units_per_em: f32 = 0,
    ascent_units: f32 = 0,
};

pub const ProbeResult = struct {
    /// Shaped glyph count for the probe text.
    count: usize,
    /// Raw charmap ids for comparison (contextual-alternate detection).
    shaped_ids: [2]u16 = .{ 0, 0 },
    charmap_ids: [2]u16 = .{ 0, 0 },
};

/// Narrow adapter interface standing in for HarfBuzz (`harfrust` shape plans +
/// `shape_with_plan`) and the font fallback iterator.
/// Family selector for a font query, mirroring the canonical family kinds
/// without importing attrs/font_system types (keeps this module standalone).
pub const FontFamilyKind = enum { name, serif, sans_serif, cursive, fantasy, monospace };

/// Match attributes for per-run font selection, passed to the adapter's
/// `font_for` / `fallback_for` (primitives only; see `fontQueryFor`).
pub const FontQuery = struct {
    family_kind: FontFamilyKind,
    /// Borrowed family name; only meaningful for `.name`.
    family_name: []const u8 = "",
    /// OS/2 weight class (400 = normal).
    weight: u16 = 400,
    /// OS/2 width class 1..9 (5 = normal).
    stretch: u8 = 5,
    /// 0 = normal, 1 = italic, 2 = oblique.
    style: u8 = 0,
};

/// Build the adapter query for an owned attribute span.
pub fn fontQueryFor(a: *const attrs_mod.AttrsOwned) FontQuery {
    const family = a.family_owned.as_family();
    return .{
        .family_kind = switch (family) {
            .name => .name,
            .serif => .serif,
            .sans_serif => .sans_serif,
            .cursive => .cursive,
            .fantasy => .fantasy,
            .monospace => .monospace,
        },
        .family_name = switch (family) {
            .name => |n| n,
            else => "",
        },
        .weight = a.weight.value,
        .stretch = a.stretch.to_number(),
        .style = @backingInt(a.style),
    };
}

/// WIRING POINT (`hb_shape_plan_execute`): implement this vtable with a real
/// HarfBuzz backend; `shapeFallback`/`shapeRun` below already implement the
/// exact surrounding logic (plan-cache FIFO, tab rewrite, missing collection,
/// end adjustment, fallback splice).
pub const ShapeAdapter = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        /// Shape `text` (already tab-rewritten by the caller) with `font`.
        shape_run: *const fn (
            ptr: *anyopaque,
            alloc: std.mem.Allocator,
            font: FontId,
            text: []const u8,
            rtl: bool,
        ) ShapeError![]ShapedRunGlyph,
        map_glyph: *const fn (ptr: *anyopaque, font: FontId, cp: u21) u16,
        advance_em: *const fn (ptr: *anyopaque, font: FontId, glyph_id: u16) f32,
        font_metrics: *const fn (ptr: *anyopaque, font: FontId) ShapingFontMetrics,
        primary_font: *const fn (ptr: *anyopaque) FontId,
        /// Apply the requested OS/2 weight (variable-font `wght` axis) to all
        /// subsequent shaping queries. Static faces ignore it. Callers use
        /// `query.weight`; the adapter keeps the value until changed.
        set_weight: *const fn (ptr: *anyopaque, weight: u16) void,
        /// Best primary font for `query`, or `null` when the backend has no
        /// matching registered face (caller then uses `primary_font`).
        font_for: *const fn (ptr: *anyopaque, query: FontQuery) ?FontId,
        /// Font used to repatch missing glyphs in Basic shaping for a generic
        /// sans/mono query (shape.rs:526-583); `null` leaves the missing
        /// glyphs as `.notdef` instead of panicking on an unknown id.
        repatch_font: *const fn (ptr: *anyopaque, query: FontQuery) ?FontId,
        /// `attempt`-th fallback font for `query` + `script`, or `null` when
        /// exhausted (stands in for `FontFallbackIter::next`).
        fallback_for: *const fn (ptr: *anyopaque, query: FontQuery, script: Script, attempt: usize) ?FontId,
        /// `attempt`-th fallback font for `script`, or `null` when exhausted
        /// (legacy script-only path; retained for backends without attr
        /// matching).
        fallback_font: *const fn (ptr: *anyopaque, script: Script, attempt: usize) ?FontId,
        /// Shape the two-char probe text for the punct-ligature check.
        probe_pair: *const fn (ptr: *anyopaque, font: FontId, c1: u21, c2: u21) ProbeResult,
        /// Optional: outcome of one fallback attempt in `shapeRun` (a no-op
        /// when unset, which is the default so charmap/test adapters need no
        /// changes). `font` was shaped for the run and `covered` is true when
        /// its glyphs replaced at least one previously missing glyph after
        /// splicing. Backends use it to memoize successful fallback selection;
        /// see `shape_hb.Backend`'s fallback memo for the key/bounds policy.
        /// Called for every successful fallback shape (including `covered =
        /// false`), so a backend can also observe scan exhaustion.
        note_fallback: ?*const fn (
            ptr: *anyopaque,
            query: FontQuery,
            script: Script,
            font: FontId,
            covered: bool,
        ) void = null,
    };

    pub fn shapeRun(self: ShapeAdapter, alloc: std.mem.Allocator, font: FontId, text: []const u8, rtl: bool) ShapeError![]ShapedRunGlyph {
        return self.vtable.shape_run(self.ptr, alloc, font, text, rtl);
    }
    pub fn mapGlyph(self: ShapeAdapter, font: FontId, cp: u21) u16 {
        return self.vtable.map_glyph(self.ptr, font, cp);
    }
    pub fn advanceEm(self: ShapeAdapter, font: FontId, glyph_id: u16) f32 {
        return self.vtable.advance_em(self.ptr, font, glyph_id);
    }
    pub fn fontMetrics(self: ShapeAdapter, font: FontId) ShapingFontMetrics {
        return self.vtable.font_metrics(self.ptr, font);
    }
    pub fn primaryFont(self: ShapeAdapter) FontId {
        return self.vtable.primary_font(self.ptr);
    }
    /// Set the weight applied by subsequent shaping queries (variable fonts;
    /// static faces ignore it).
    pub fn setWeight(self: ShapeAdapter, weight: u16) void {
        self.vtable.set_weight(self.ptr, weight);
    }
    pub fn fontFor(self: ShapeAdapter, query: FontQuery) ?FontId {
        return self.vtable.font_for(self.ptr, query);
    }
    pub fn repatchFont(self: ShapeAdapter, query: FontQuery) ?FontId {
        return self.vtable.repatch_font(self.ptr, query);
    }
    pub fn fallbackFor(self: ShapeAdapter, query: FontQuery, script: Script, attempt: usize) ?FontId {
        return self.vtable.fallback_for(self.ptr, query, script, attempt);
    }
    pub fn fallbackFont(self: ShapeAdapter, script: Script, attempt: usize) ?FontId {
        return self.vtable.fallback_font(self.ptr, script, attempt);
    }
    pub fn probePair(self: ShapeAdapter, font: FontId, c1: u21, c2: u21) ProbeResult {
        return self.vtable.probe_pair(self.ptr, font, c1, c2);
    }
    /// Report the outcome of one fallback attempt to an interested backend.
    /// No-op when the vtable leaves `note_fallback` unset (the default).
    pub fn noteFallback(self: ShapeAdapter, query: FontQuery, script: Script, font: FontId, covered: bool) void {
        if (self.vtable.note_fallback) |hook| hook(self.ptr, query, script, font, covered);
    }
};

pub const PRIMARY_FONT_ID: FontId = 1;
pub const FALLBACK_FONT_ID: FontId = 2;
pub const SANS_FALLBACK_ID: FontId = 10;
pub const MONO_FALLBACK_ID: FontId = 11;

/// Pure-Zig fallback backend: charmap-advance shaping (no GSUB/GPOS). Test
/// double and no-backend stand-in; NOT a HarfBuzz replacement.
pub const CharmapAdapter = struct {
    advance_em: f32 = 0.6,
    ascent: f32 = 0.8,
    descent: f32 = 0.2,
    /// Codepoints the primary font reports as missing (`.notdef`).
    primary_missing: []const u21 = &.{},
    /// Codepoints the fallback font reports as missing.
    fallback_missing: []const u21 = &.{},
    /// Codepoints the Basic-repatch fonts report as missing.
    repatch_missing: []const u21 = &.{},
    monospaced_primary: bool = false,
    /// Punct pairs that shape as a ligature (probe returns `count = 1`).
    ligature_probe_count: usize = 2,
    runs_shaped: usize = 0,

    pub fn adapter(self: *CharmapAdapter) ShapeAdapter {
        return .{ .ptr = self, .vtable = &.{
            .shape_run = charmapShapeRun,
            .map_glyph = mapGlyph,
            .advance_em = advanceEm,
            .font_metrics = fontMetrics,
            .primary_font = primaryFont,
            .set_weight = charmapSetWeight,
            .font_for = charmapFontFor,
            .repatch_font = charmapRepatchFont,
            .fallback_for = charmapFallbackFor,
            .fallback_font = fallbackFont,
            .probe_pair = probePair,
        } };
    }

    /// The charmap stand-in has no database; named queries keep the old
    /// primary/fallback selection by returning null from the attr query.
    fn charmapFontFor(ptr: *anyopaque, query: FontQuery) ?FontId {
        _ = ptr;
        _ = query;
        return null;
    }

    /// Generic-family repatch for Basic shaping: the stand-in exposes the
    /// legacy Sans/Mono ids, which `missingFor` maps to `repatch_missing`.
    fn charmapRepatchFont(ptr: *anyopaque, query: FontQuery) ?FontId {
        _ = ptr;
        return switch (query.family_kind) {
            .monospace => MONO_FALLBACK_ID,
            .sans_serif => SANS_FALLBACK_ID,
            else => null,
        };
    }

    fn charmapFallbackFor(ptr: *anyopaque, query: FontQuery, script: Script, attempt: usize) ?FontId {
        _ = query;
        return fallbackFont(ptr, script, attempt);
    }

    fn missingFor(self: *const CharmapAdapter, font: FontId) []const u21 {
        if (font == PRIMARY_FONT_ID) return self.primary_missing;
        if (font == FALLBACK_FONT_ID) return self.fallback_missing;
        return self.repatch_missing;
    }

    fn mapImpl(self: *const CharmapAdapter, font: FontId, cp: u21) u16 {
        if (cp == '\t') return self.mapImpl(font, ' ');
        if (cp < 0x20 or cp == 0x7F) return 0;
        for (self.missingFor(font)) |m| {
            if (m == cp) return 0;
        }
        if (cp > 0x10FFFF) return 0;
        const id: u32 = @as(u32, @intCast(cp % 0xFFFE)) + 1;
        return @intCast(id);
    }

    fn mapGlyph(ptr: *anyopaque, font: FontId, cp: u21) u16 {
        const self: *const CharmapAdapter = @ptrCast(@alignCast(ptr));
        return self.mapImpl(font, cp);
    }

    fn advanceEm(ptr: *anyopaque, font: FontId, glyph_id: u16) f32 {
        const self: *const CharmapAdapter = @ptrCast(@alignCast(ptr));
        _ = font;
        _ = glyph_id;
        return self.advance_em;
    }

    fn fontMetrics(ptr: *anyopaque, font: FontId) ShapingFontMetrics {
        const self: *const CharmapAdapter = @ptrCast(@alignCast(ptr));
        _ = font;
        return .{
            .ascent = self.ascent,
            .descent = self.descent,
            .monospace_width = if (self.monospaced_primary) self.advance_em else null,
            .monospaced = self.monospaced_primary,
            // No real face: expose a nominal upem/ascent so
            // `decorationMetrics` applies the cosmic-text fallbacks.
            .units_per_em = 1000,
            .ascent_units = self.ascent * 1000,
        };
    }

    fn primaryFont(ptr: *anyopaque) FontId {
        _ = ptr;
        return PRIMARY_FONT_ID;
    }

    /// The charmap stand-in has no variation support; the weight is ignored
    /// (`ShapeGlyph.font_weight` still records the requested value).
    fn charmapSetWeight(ptr: *anyopaque, weight: u16) void {
        _ = ptr;
        _ = weight;
    }

    fn fallbackFont(ptr: *anyopaque, script: Script, attempt: usize) ?FontId {
        _ = ptr;
        _ = script;
        if (attempt == 0) return FALLBACK_FONT_ID;
        return null;
    }

    fn probePair(ptr: *anyopaque, font: FontId, c1: u21, c2: u21) ProbeResult {
        const self: *const CharmapAdapter = @ptrCast(@alignCast(ptr));
        const m1 = self.mapImpl(font, c1);
        const m2 = self.mapImpl(font, c2);
        return .{
            .count = self.ligature_probe_count,
            .shaped_ids = .{ m1, m2 },
            .charmap_ids = .{ m1, m2 },
        };
    }

    fn charmapShapeRun(ptr: *anyopaque, alloc: std.mem.Allocator, font: FontId, text: []const u8, rtl: bool) ShapeError![]ShapedRunGlyph {
        const self: *CharmapAdapter = @ptrCast(@alignCast(ptr));
        self.runs_shaped += 1;
        var out: std.ArrayList(ShapedRunGlyph) = .empty;
        errdefer out.deinit(alloc);
        var i: usize = 0;
        while (i < text.len) {
            const d = decodeOne(text, i);
            const id = self.mapImpl(font, d.cp);
            try out.append(alloc, .{
                .glyph_id = id,
                .cluster = i,
                .x_advance = self.advance_em,
                .y_advance = 0,
                .x_offset = 0,
                .y_offset = 0,
            });
            i += d.len;
        }
        // HarfBuzz emits RTL runs in visual order (rightmost glyph first);
        // the ported end-adjustment and BiDi reorder depend on descending
        // clusters, so mirror that here instead of returning logical order.
        if (rtl) std.mem.reverse(ShapedRunGlyph, out.items);
        return out.toOwnedSlice(alloc);
    }
};

// ---------------------------------------------------------------------------
// shape_fallback (shape.rs:143-296) — adapter path
// ---------------------------------------------------------------------------

pub const FallbackResult = struct {
    glyphs: []ShapeGlyph,
    missing: []usize,

    pub fn deinit(self: *FallbackResult, alloc: std.mem.Allocator) void {
        alloc.free(self.glyphs);
        alloc.free(self.missing);
    }
};

/// Shape one font run (shape.rs:143-296). Tab rewrite, plan-cache FIFO touch,
/// per-glyph attrs (`letter_spacing`, color, fake-italic…), missing collection
/// and LTR/RTL end adjustment are verbatim; the HarfBuzz core
/// (`UnicodeBuffer` + `ShapePlan` + `shape_with_plan`) is the
/// `ShapeAdapter.shapeRun` call below (see module WIRING POINT).
/// NOTE: `buffer.guess_segment_properties()` + `assert_eq!(rtl, span_rtl)`
/// (shape.rs:174-177) live in the backend; the adapter contract requires the
/// caller to pass the span's `rtl` consistently.
pub fn shapeFallback(
    alloc: std.mem.Allocator,
    adapter: ShapeAdapter,
    buf: *ShapeBuffer,
    font: FontId,
    line: []const u8,
    attrs: *const AttrsList,
    start_run: usize,
    end_run: usize,
    span_rtl: bool,
) ShapeError!FallbackResult {
    const run = line[start_run..end_run];
    const fm = adapter.fontMetrics(font);

    // Touch the plan cache (shape.rs:197-221): keyed by font + script +
    // direction here (features/instance/language fold into the backend).
    const script: Script = scriptOf(if (run.len > 0) decodeOne(run, 0).cp else ' ');
    _ = buf.plans.getOrPut(font, script, span_rtl);

    // Tabs are shaped as spaces (shape.rs:165-173). Clusters still refer to
    // the original bytes; the rewrite is backend-local. Our charmap backend
    // already maps '\t' like a space, so no copy is needed; a real HarfBuzz
    // backend must push the rewritten string (see WIRING POINT).
    const shaped = try adapter.shapeRun(alloc, font, run, span_rtl);
    defer alloc.free(shaped);

    var glyphs: std.ArrayList(ShapeGlyph) = .empty;
    errdefer glyphs.deinit(alloc);
    try glyphs.ensureTotalCapacity(alloc, shaped.len);
    var missing: std.ArrayList(usize) = .empty;
    errdefer missing.deinit(alloc);

    for (shaped) |info| {
        const start_glyph = start_run + info.cluster;
        if (info.glyph_id == 0) {
            try missing.append(alloc, start_glyph);
        }
        const ga = attrs.get_span(start_glyph);
        glyphs.appendAssumeCapacity(.{
            .start = start_glyph,
            .end = end_run, // Set later (shape.rs:248).
            .x_advance = info.x_advance + letterSpacing(ga),
            .y_advance = info.y_advance,
            .x_offset = info.x_offset,
            .y_offset = info.y_offset,
            .ascent = fm.ascent,
            .descent = fm.descent,
            .mono_width = fm.monospace_width,
            .font_id = font,
            .font_weight = ga.weight,
            .glyph_id = info.glyph_id,
            .color_opt = ga.color_opt,
            .metadata = ga.metadata,
            .flags = overrideFakeItalic(ga.cache_key_flags, fm.italic_or_oblique, ga.style),
            .metrics_opt = metricsOpt(ga),
        });
    }

    const owned_glyphs = try glyphs.toOwnedSlice(alloc);
    adjustGlyphEnds(owned_glyphs, span_rtl);
    return .{ .glyphs = owned_glyphs, .missing = try missing.toOwnedSlice(alloc) };
}

/// End-of-glyph adjustment, verbatim from shape.rs:267-290.
pub fn adjustGlyphEnds(glyphs: []ShapeGlyph, rtl: bool) void {
    if (glyphs.len == 0) return;
    if (rtl) {
        var i: usize = 1;
        while (i < glyphs.len) : (i += 1) {
            const next_start = glyphs[i - 1].start;
            const next_end = glyphs[i - 1].end;
            if (glyphs[i].start == next_start) {
                glyphs[i].end = next_end;
            } else {
                glyphs[i].end = next_start;
            }
        }
    } else {
        var i: usize = glyphs.len - 1;
        while (i > 0) {
            const next_start = glyphs[i].start;
            const next_end = glyphs[i].end;
            if (glyphs[i - 1].start == next_start) {
                glyphs[i - 1].end = next_end;
            } else {
                glyphs[i - 1].end = next_start;
            }
            i -= 1;
        }
    }
}

// ---------------------------------------------------------------------------
// shape_run (shape.rs:298-438) + missing-glyph splice
// ---------------------------------------------------------------------------

/// Splice fallback-font glyphs over the primary run, verbatim from
/// shape.rs:373-424: skip clusters that are not missing or still missing in
/// the fallback, drop covered missing starts, remove prior glyphs in range,
/// insert fallback glyphs in range.
pub fn spliceFallback(
    glyphs: *std.ArrayList(ShapeGlyph),
    alloc: std.mem.Allocator,
    glyph_start: usize,
    fb_glyphs: *std.ArrayList(ShapeGlyph),
    fb_missing: []const usize,
    missing: *std.ArrayList(usize),
) ShapeError!void {
    var fb_i: usize = 0;
    while (fb_i < fb_glyphs.items.len) {
        const start = fb_glyphs.items[fb_i].start;
        const end = fb_glyphs.items[fb_i].end;

        var in_missing = false;
        for (missing.items) |m| {
            if (m == start) {
                in_missing = true;
                break;
            }
        }
        var in_fb_missing = false;
        for (fb_missing) |m| {
            if (m == start) {
                in_fb_missing = true;
                break;
            }
        }
        if (!in_missing or in_fb_missing) {
            fb_i += 1;
            continue;
        }

        var missing_i: usize = 0;
        while (missing_i < missing.items.len) {
            if (missing.items[missing_i] >= start and missing.items[missing_i] < end) {
                _ = missing.orderedRemove(missing_i);
            } else {
                missing_i += 1;
            }
        }

        var i: usize = glyph_start;
        while (i < glyphs.items.len) {
            if (glyphs.items[i].start >= start and glyphs.items[i].end <= end) break;
            i += 1;
        }
        while (i < glyphs.items.len) {
            if (glyphs.items[i].start >= start and glyphs.items[i].end <= end) {
                _ = glyphs.orderedRemove(i);
            } else {
                break;
            }
        }
        while (fb_i < fb_glyphs.items.len) {
            if (fb_glyphs.items[fb_i].start >= start and fb_glyphs.items[fb_i].end <= end) {
                const fb_glyph = fb_glyphs.orderedRemove(fb_i);
                try glyphs.insert(alloc, i, fb_glyph);
                i += 1;
            } else {
                break;
            }
        }
    }
}

/// Shape one bidi/atomic run with font fallback (shape.rs:298-438).
pub fn shapeRun(
    alloc: std.mem.Allocator,
    adapter: ShapeAdapter,
    buf: *ShapeBuffer,
    out: *std.ArrayList(ShapeGlyph),
    line: []const u8,
    attrs: *const AttrsList,
    start_run: usize,
    end_run: usize,
    span_rtl: bool,
) ShapeError!void {
    // Re-use the previous script buffer if possible (shape.rs:307-311).
    buf.scripts.clearRetainingCapacity();
    try collectScripts(&buf.scripts, alloc, line, start_run, end_run);

    // Per-run attr-driven primary selection (shape.rs:326-348): the query is
    // taken from the effective attrs at the run start; backends without a
    // database return null and keep their global primary font.
    const run_attrs = attrs.get_span(start_run);
    const query = fontQueryFor(run_attrs);
    // Match the backend's variation state to this run's requested weight
    // before any font-selection or shaping query (no-op for static faces).
    adapter.setWeight(query.weight);
    var primary = adapter.fontFor(query) orelse adapter.primaryFont();

    // First-use broken primary (shape.rs:326-348): a resolver can return a
    // face whose lazy load only fails when it is first used (e.g. a stale
    // fontconfig entry whose file was deleted), and the failure is only then
    // negatively cached. Re-resolve once through `fontFor` — the failed id is
    // now skipped by `canUse` — and retry shaping with the next candidate.
    // When there is no usable alternative the error is returned unchanged
    // (upstream has no missing-glyph degradation for the primary either).
    var primary_retried = false;
    const glyph_start = out.items.len;
    const first = while (true) {
        const res = shapeFallback(alloc, adapter, buf, primary, line, attrs, start_run, end_run, span_rtl) catch |err| {
            if (err != error.FontUnavailable or primary_retried) return err;
            primary_retried = true;
            const alt = adapter.fontFor(query) orelse return err;
            if (alt == primary) return err;
            primary = alt;
            continue;
        };
        break res;
    };
    defer alloc.free(first.missing);
    defer alloc.free(first.glyphs);
    try out.appendSlice(alloc, first.glyphs);

    var missing: std.ArrayList(usize) = .empty;
    defer missing.deinit(alloc);
    try missing.appendSlice(alloc, first.missing);

    // Fallback loop (shape.rs:350-425). `check_missing` diagnostics are a
    // backend logging concern and intentionally have no equivalent here.
    const script: Script = if (buf.scripts.items.len > 0) buf.scripts.items[0] else .common;
    var attempt: usize = 0;
    while (missing.items.len > 0) {
        const fb = adapter.fallbackFor(query, script, attempt) orelse break;
        attempt += 1;
        // An unloadable fallback candidate is skipped, not fatal: the
        // attempt counter already moved on, so the next candidate is tried.
        // Only OOM (and other run errors) abort the run.
        const fb_res = shapeFallback(alloc, adapter, buf, fb, line, attrs, start_run, end_run, span_rtl) catch |err| {
            if (err == error.FontUnavailable) continue;
            return err;
        };
        defer alloc.free(fb_res.missing);
        defer alloc.free(fb_res.glyphs);
        var fb_list: std.ArrayList(ShapeGlyph) = .empty;
        defer fb_list.deinit(alloc);
        // Move into a list for orderedRemove-based splicing.
        try fb_list.appendSlice(alloc, fb_res.glyphs);
        const missing_before = missing.items.len;
        try spliceFallback(out, alloc, glyph_start, &fb_list, fb_res.missing, &missing);
        // Report whether this candidate covered any previously missing glyph
        // (drives backend fallback memoization; no-op without the hook).
        adapter.noteFallback(query, script, fb, missing.items.len < missing_before);
        // Leftover fallback glyphs (outside missing ranges) are dropped here,
        // matching Rust where `fb_glyphs` is discarded at loop end.
    }
}

// ---------------------------------------------------------------------------
// shape_run_cached key (shape.rs:440-498)
// ---------------------------------------------------------------------------

/// Run-relative non-default span for cache keys.
pub const RunKeySpan = struct {
    start: usize,
    end: usize,
    hash: u64,
};

/// Cache-key half of `shape_run_cached` (shape.rs:452-469): run text plus
/// default-attrs hash plus relativized non-default spans. The glyph
/// store/lookup itself lives in `shape_run_cache.zig` (`ShapeRunCache`,
/// whose key now uses canonical `attrs.AttrsOwned` equality).
pub const RunKey = struct {
    text: []const u8,
    default_hash: u64,
    spans: []RunKeySpan,

    pub fn deinit(self: *RunKey, alloc: std.mem.Allocator) void {
        alloc.free(self.spans);
    }
};

/// Build the run key, verbatim from shape.rs:452-469: spans matching the
/// defaults are skipped, ranges are clamped to the run and relativized, and
/// empty intersections are dropped.
pub fn buildRunKey(
    alloc: std.mem.Allocator,
    line: []const u8,
    attrs: *const AttrsList,
    start_run: usize,
    end_run: usize,
) ShapeError!RunKey {
    const default_hash = hashAttrs(&attrs.default_attrs);
    var spans: std.ArrayList(RunKeySpan) = .empty;
    errdefer spans.deinit(alloc);
    for (attrs.spans.items) |*s| {
        // Skip if attrs matches default attrs (shape.rs:463-466).
        if (s.attrs.eql(&attrs.default_attrs)) continue;
        const start = @max(s.start, start_run) -| start_run;
        const end = @min(s.end, end_run) -| start_run;
        if (end > start) {
            try spans.append(alloc, .{ .start = start, .end = end, .hash = hashAttrs(&s.attrs) });
        }
    }
    return .{
        .text = line[start_run..end_run],
        .default_hash = default_hash,
        .spans = try spans.toOwnedSlice(alloc),
    };
}

/// Rebase glyph byte offsets by a signed delta: `+start_run` on cache hit,
/// `-start_run` on store (shape.rs:470-497). Underflow is an explicit error.
pub fn rebaseGlyphs(glyphs: []ShapeGlyph, delta: isize) ShapeError!void {
    if (delta >= 0) {
        const d: usize = @intCast(delta);
        for (glyphs) |*g| {
            g.start += d;
            g.end += d;
        }
    } else {
        const d: usize = @intCast(-delta);
        for (glyphs) |*g| {
            if (g.start < d or g.end < d) return error.GlyphUnderflow;
            g.start -= d;
            g.end -= d;
        }
    }
}

// ---------------------------------------------------------------------------
// Basic path: shape_skip (shape.rs:500-638)
// ---------------------------------------------------------------------------

/// Per-character charmap shaping (shape.rs:587-638), appending directly into
/// `out` so the basic path never allocates a temporary slice per word.
pub fn shapeSkipAppend(
    alloc: std.mem.Allocator,
    adapter: ShapeAdapter,
    out: *std.ArrayList(ShapeGlyph),
    font: FontId,
    line: []const u8,
    attrs: *const AttrsList,
    start_run: usize,
    end_run: usize,
) ShapeError!void {
    // Basic shaping still needs the run's weight (variable fonts); set it
    // before any `mapGlyph`/`advanceEm`/`fontMetrics` query.
    adapter.setWeight(attrs.get_span(start_run).weight.value);
    const fm = adapter.fontMetrics(font);
    var i = start_run;
    while (i < end_run) {
        const d = decodeOne(line, i);
        const id = adapter.mapGlyph(font, d.cp);
        const ga = attrs.get_span(i);
        try out.append(alloc, .{
            .start = i,
            .end = i + d.len,
            .x_advance = adapter.advanceEm(font, id) + letterSpacing(ga),
            .y_advance = 0,
            .x_offset = 0,
            .y_offset = 0,
            .ascent = fm.ascent,
            .descent = fm.descent,
            .mono_width = fm.monospace_width,
            .font_id = font,
            .font_weight = ga.weight,
            .glyph_id = id,
            .color_opt = ga.color_opt,
            .metadata = ga.metadata,
            .flags = overrideFakeItalic(ga.cache_key_flags, fm.italic_or_oblique, ga.style),
            .metrics_opt = metricsOpt(ga),
        });
        i += d.len;
    }
}

/// Per-character charmap shaping (shape.rs:587-638) into a fresh slice
/// (compat wrapper over `shapeSkipAppend`).
pub fn shapeSkipGlyphs(
    alloc: std.mem.Allocator,
    adapter: ShapeAdapter,
    font: FontId,
    line: []const u8,
    attrs: *const AttrsList,
    start_run: usize,
    end_run: usize,
) ShapeError![]ShapeGlyph {
    var glyphs: std.ArrayList(ShapeGlyph) = .empty;
    errdefer glyphs.deinit(alloc);
    try shapeSkipAppend(alloc, adapter, &glyphs, font, line, attrs, start_run, end_run);
    return glyphs.toOwnedSlice(alloc);
}

/// Basic shaping without fallback, plus the SansSerif/Monospace repatch for
/// named families (shape.rs:500-584).
pub fn shapeSkip(
    alloc: std.mem.Allocator,
    adapter: ShapeAdapter,
    out: *std.ArrayList(ShapeGlyph),
    line: []const u8,
    attrs: *const AttrsList,
    start_run: usize,
    end_run: usize,
) ShapeError!void {
    // Attr-driven selection + weight, matching the advanced path and
    // upstream `shape_skip` (`FontFallbackIter(..., attrs.weight)`).
    const first = attrs.get_span(start_run);
    const query = fontQueryFor(first);
    adapter.setWeight(query.weight);
    const font = adapter.fontFor(query) orelse adapter.primaryFont();
    const glyph_start = out.items.len;
    // Append in place: the old shapeSkipGlyphs round-trip allocated, copied
    // and freed a fresh slice per word on the basic path.
    try shapeSkipAppend(alloc, adapter, out, font, line, attrs, start_run, end_run);

    // If any glyphs are missing and the user specified a font, fall back to a
    // default font (shape.rs:526-583). The generic family is resolved through
    // the adapter (real backends filter to registered faces; the charmap
    // stand-in returns the legacy Sans/Mono repatch ids), so a missing face
    // degrades to "left as .notdef" instead of panicking on an unknown id.
    if (familyIsNamed(first)) {
        var any_missing = false;
        for (out.items[glyph_start..]) |g| {
            if (g.glyph_id == 0) {
                any_missing = true;
                break;
            }
        }
        if (any_missing) {
            const is_mono = adapter.fontMetrics(font).monospaced;
            const fb_query = FontQuery{
                .family_kind = if (is_mono) .monospace else .sans_serif,
                .weight = first.weight.value,
                .stretch = first.stretch.to_number(),
                .style = @backingInt(first.style),
            };
            const fb_font_opt = adapter.repatchFont(fb_query) orelse
                adapter.fallbackFor(fb_query, .latin, 0);
            if (fb_font_opt) |fb_font| {
                const fb_fm = adapter.fontMetrics(fb_font);
                for (out.items[glyph_start..]) |*g| {
                    if (g.glyph_id != 0) continue;
                    const d = decodeOne(line, g.start);
                    const id = adapter.mapGlyph(fb_font, d.cp);
                    if (id != 0) {
                        const ga = attrs.get_span(g.start);
                        g.glyph_id = id;
                        g.font_id = fb_font;
                        g.mono_width = fb_fm.monospace_width;
                        g.ascent = fb_fm.ascent;
                        g.descent = fb_fm.descent;
                        g.x_advance = adapter.advanceEm(fb_font, id) + letterSpacing(ga);
                        g.flags = overrideFakeItalic(ga.cache_key_flags, fb_fm.italic_or_oblique, ga.style);
                    }
                }
            }
        }
    }
}

/// Fake-italic flag override, verbatim from shape.rs:640-650.
pub fn overrideFakeItalic(flags: CacheKeyFlags, font_italic_or_oblique: bool, style: FontStyle) CacheKeyFlags {
    if (!font_italic_or_oblique and (style == .italic or style == .oblique)) {
        return .{ .bits = flags.bits | FLAG_FAKE_ITALIC.bits };
    }
    return flags;
}

// ---------------------------------------------------------------------------
// ShapeGlyph (shape.rs:652-708); layout types are canonical in layout.zig.
// ---------------------------------------------------------------------------

/// A shaped glyph (shape.rs:652-671).
pub const ShapeGlyph = struct {
    start: usize,
    end: usize,
    x_advance: f32,
    y_advance: f32,
    x_offset: f32,
    y_offset: f32,
    ascent: f32,
    descent: f32,
    mono_width: ?f32 = null,
    font_id: FontId,
    font_weight: Weight,
    glyph_id: u16,
    color_opt: ?Color = null,
    metadata: usize = 0,
    flags: CacheKeyFlags = .{},
    metrics_opt: ?Metrics = null,

    /// Width in pixels, using the metrics override when present
    /// (shape.rs:703-707).
    pub fn width(self: ShapeGlyph, font_size: f32) f32 {
        const size = if (self.metrics_opt) |m| m.font_size else font_size;
        return size * self.x_advance;
    }

    /// Lower into a `LayoutGlyph` (shape.rs:674-701).
    pub fn layout(
        self: ShapeGlyph,
        font_size: f32,
        line_height_opt: ?f32,
        x: f32,
        y: f32,
        w: f32,
        level: Level,
    ) LayoutGlyph {
        return .{
            .start = self.start,
            .end = self.end,
            .font_size = font_size,
            .font_weight = self.font_weight,
            .line_height_opt = line_height_opt,
            .font_id = self.font_id,
            .glyph_id = self.glyph_id,
            .x = x,
            .y = y,
            .w = w,
            .level = level,
            .x_offset = self.x_offset,
            .y_offset = self.y_offset,
            .color_opt = self.color_opt,
            .metadata = self.metadata,
            .cache_key_flags = self.flags,
        };
    }
};

// LayoutGlyph, LayoutLine, DecorationSpan, Wrap, Align, Ellipsize,
// EllipsizeHeightLimit, and Hinting are canonical in `layout.zig` and
// re-exported at the top of this file.

pub fn freeLayoutLines(alloc: std.mem.Allocator, lines: []LayoutLine) void {
    for (lines) |*l| l.deinit();
    alloc.free(lines);
}

/// Underline/strikeout metrics with cosmic-text fallbacks, verbatim from
/// shape.rs:710-731: underline offset `-0.125`, thickness `1/14`; strikeout
/// offset `0.3`, thickness `1/14`; all-zero when `upem == 0`.
pub const DecorationMetricsResult = struct {
    underline: DecorationMetrics,
    strikethrough: DecorationMetrics,
    ascent: f32,
};

pub const DecoSpec = struct {
    offset: f32,
    thickness: f32,
};

pub fn decorationMetrics(
    underline_opt: ?DecoSpec,
    strikeout_opt: ?DecoSpec,
    units_per_em: f32,
    ascent_units: f32,
) DecorationMetricsResult {
    if (units_per_em == 0.0) {
        return .{ .underline = .{}, .strikethrough = .{}, .ascent = 0.0 };
    }
    return .{
        .underline = .{
            .offset = if (underline_opt) |d| d.offset / units_per_em else -0.125,
            .thickness = if (underline_opt) |d| d.thickness / units_per_em else 1.0 / 14.0,
        },
        .strikethrough = .{
            .offset = if (strikeout_opt) |d| d.offset / units_per_em else 0.3,
            .thickness = if (strikeout_opt) |d| d.thickness / units_per_em else 1.0 / 14.0,
        },
        .ascent = ascent_units / units_per_em,
    };
}

// ---------------------------------------------------------------------------
// Ellipsis span sentinel (shape.rs:733-773)
// ---------------------------------------------------------------------------

/// Span index marking the ellipsis range in `VlRange` (shape.rs:734).
pub const ELLIPSIS_SPAN: usize = std.math.maxInt(usize);

/// Shape the ellipsis (`U+2026`, falling back to `...` when unshapable),
/// verbatim from shape.rs:736-773.
pub fn shapeEllipsis(
    alloc: std.mem.Allocator,
    adapter: ShapeAdapter,
    buf: *ShapeBuffer,
    default_attrs: *const attrs_mod.AttrsOwned,
    shaping: Shaping,
    span_rtl: bool,
) ShapeError![]ShapeGlyph {
    const level: Level = if (span_rtl) LEVEL_RTL else LEVEL_LTR;
    // `AttrsList::new(attrs)` (shape.rs:742): fresh defaults, no spans.
    const owned = try default_attrs.clone_with(alloc);
    var single = attrs_mod.AttrsList.init_owned(alloc, owned);
    defer single.deinit();
    var word = try buildWord(alloc, adapter, buf, "\u{2026}", &single, 0, 3, level, false, shaping);
    defer word.deinitChildren(alloc);
    var all_missing = true;
    for (word.glyphs) |g| {
        if (g.glyph_id != 0) {
            all_missing = false;
            break;
        }
    }
    if (word.glyphs.len == 0 or all_missing) {
        // Fall back to three ASCII periods (shape.rs:760-771).
        var dots = try buildWord(alloc, adapter, buf, "...", &single, 0, 3, level, false, shaping);
        defer dots.deinitChildren(alloc);
        return alloc.dupe(ShapeGlyph, dots.glyphs) catch return error.OutOfMemory;
    }
    return alloc.dupe(ShapeGlyph, word.glyphs) catch return error.OutOfMemory;
}

// ---------------------------------------------------------------------------
// ShapeWord (shape.rs:775-912)
// ---------------------------------------------------------------------------

/// A shaped word for word wrapping (shape.rs:775-780).
pub const ShapeWord = struct {
    blank: bool = true,
    glyphs: []ShapeGlyph = &.{},

    pub fn deinitChildren(self: *ShapeWord, alloc: std.mem.Allocator) void {
        if (self.glyphs.len > 0) alloc.free(self.glyphs);
        self.glyphs = &.{};
    }

    /// Width in pixels via `ShapeGlyph::width` (shape.rs:904-911).
    pub fn width(self: *const ShapeWord, font_size: f32) f32 {
        var w: f32 = 0;
        for (self.glyphs) |g| w += g.width(font_size);
        return w;
    }
};

/// Fast-path predicate, verbatim from shape.rs:844-854: simple ASCII with no
/// control characters except `\t`, plus attrs-compatibility across the range.
pub fn isSimpleAsciiWord(line: []const u8, word_range_start: usize, word_range_end: usize, attrs: *const AttrsList) bool {
    const word = line[word_range_start..word_range_end];
    if (word.len == 0) return false;
    for (word) |b| {
        if (b >= 0x80) return false;
        if (b < 0x20 or b == 0x7F) {
            if (b != '\t') return false;
        }
    }
    const attrs_start = attrs.get_span(word_range_start);
    for (attrs.spans.items) |*s| {
        if (word_range_end <= s.start or s.end <= word_range_start) continue;
        if (!attrsCompatible(attrs_start, &s.attrs)) return false;
    }
    return true;
}

/// Shape a word into glyphs (shape.rs:821-902): fast path issues one run;
/// the slow path walks graphemes and splits on incompatible attrs.
pub fn buildWord(
    alloc: std.mem.Allocator,
    adapter: ShapeAdapter,
    buf: *ShapeBuffer,
    line: []const u8,
    attrs: *const AttrsList,
    word_start: usize,
    word_end: usize,
    level: Level,
    blank: bool,
    shaping: Shaping,
) ShapeError!ShapeWord {
    const span_rtl = levelIsRtl(level);
    var glyphs: std.ArrayList(ShapeGlyph) = .empty;
    errdefer glyphs.deinit(alloc);

    if (isSimpleAsciiWord(line, word_start, word_end, attrs)) {
        try shaping.run(alloc, adapter, buf, &glyphs, line, attrs, word_start, word_end, span_rtl);
    } else {
        // Complex text path (shape.rs:865-898).
        var start_run = word_start;
        var cur: *const attrs_mod.AttrsOwned = &attrs.default_attrs;
        var cursor = GraphemeCursor{ .text = line, .pos = word_start, .end = word_end };
        while (cursor.next()) |abs_egc| {
            const egc_attrs = attrs.get_span(abs_egc);
            if (!attrsCompatible(cur, egc_attrs)) {
                try shaping.run(alloc, adapter, buf, &glyphs, line, attrs, start_run, abs_egc, span_rtl);
                start_run = abs_egc;
                cur = egc_attrs;
            }
        }
        if (start_run < word_end) {
            try shaping.run(alloc, adapter, buf, &glyphs, line, attrs, start_run, word_end, span_rtl);
        }
    }
    return .{ .blank = blank, .glyphs = try glyphs.toOwnedSlice(alloc) };
}

// ---------------------------------------------------------------------------
// ShapeSpan (shape.rs:914-1212)
// ---------------------------------------------------------------------------

pub const DecoRange = struct {
    start: usize,
    end: usize,
    data: GlyphDecorationData,
};

/// A shaped span for bidirectional processing (shape.rs:914-923).
pub const ShapeSpan = struct {
    level: Level = LEVEL_LTR,
    words: []ShapeWord = &.{},
    decorations: []DecoRange = &.{},

    pub fn deinitChildren(self: *ShapeSpan, alloc: std.mem.Allocator) void {
        for (self.words) |*w| w.deinitChildren(alloc);
        if (self.words.len > 0) alloc.free(self.words);
        self.words = &.{};
        if (self.decorations.len > 0) alloc.free(self.decorations);
        self.decorations = &.{};
    }
};

/// One word split of a span: byte range plus the blank flag. Blank words are
/// always exactly one character (shape.rs:1087-1103).
pub const WordSplit = struct {
    start: usize,
    end: usize,
    blank: bool,
};

/// Punct-ligature probe, verbatim from shape.rs:995-1060: only ASCII
/// punctuation pairs are probed; a pair that shapes to fewer glyphs than
/// characters (or to substituted same-count glyphs) must not be split.
/// Returns `true` when the break must be skipped (keep the pair together).
pub fn probeKeepsPair(adapter: ShapeAdapter, font: FontId, c1: u21, c2: u21) bool {
    if (!isAsciiPunct(c1) or !isAsciiPunct(c2)) return false;
    const probe = adapter.probePair(font, c1, c2);
    // Fewer glyphs than chars: definitely a ligature (shape.rs:1033-1035).
    if (probe.count < 2) return true;
    // Same count but substituted ids: contextual alternate (shape.rs:1037-1056).
    if (probe.count == 2) {
        if (probe.shaped_ids[0] != probe.charmap_ids[0] or
            probe.shaped_ids[1] != probe.charmap_ids[1]) return true;
    }
    return false;
}

/// Split a span into words, verbatim from shape.rs:993-1105: iterate
/// UAX#14 line-break opportunities (via `unicode.zig`), probe punct pairs,
/// peel trailing blanks into per-character blank words. `span_abs_start` is
/// the span's start in `line`. Spans never contain hard breaks — those split
/// paragraphs upstream — so mandatory breaks only occur at eot.
pub fn splitSpanWords(
    alloc: std.mem.Allocator,
    adapter: ShapeAdapter,
    font: FontId,
    span: []const u8,
    span_abs_start: usize,
    attrs: *const AttrsList,
) ShapeError![]WordSplit {
    var words: std.ArrayList(WordSplit) = .empty;
    errdefer words.deinit(alloc);

    // `BreakOpportunity.offset` is the byte index before which the break
    // sits, i.e. exactly the `end_lb` boundary used below; eot surfaces as
    // the trailing `span.len` mandatory break.
    var start_word: usize = 0;
    var it = unicode.lineBreakOpportunities(span);
    while (it.next()) |opportunity| {
        const end_lb = opportunity.offset;
        // Punct-ligature probe (shape.rs:995-1060).
        if (end_lb > 0 and end_lb < span.len) {
            const pre = decodeOneRev(span, end_lb);
            const post = decodeOne(span, end_lb).cp;
            if (isAsciiPunct(pre) and isAsciiPunct(post)) {
                // Probe with the font that actually renders this position:
                // upstream resolves `attrs_list.get_span(start_idx + end_lb)`
                // through `get_font_matches` before shaping the probe text,
                // while this port probed with the span primary and dropped
                // `attrs`. Probing the primary split pairs like `|>` whenever
                // the primary face lacked the contextual alternate the span's
                // own family carries (e.g. Inter's `|>` calt behind a Fira
                // Mono primary).
                const probe_attrs = attrs.get_span(span_abs_start + end_lb);
                const probe_font = adapter.fontFor(fontQueryFor(probe_attrs)) orelse font;
                if (probeKeepsPair(adapter, probe_font, pre, post)) continue;
            }
        }
        // Peel trailing blanks (shape.rs:1062-1073).
        var start_lb = end_lb;
        {
            var ri = end_lb;
            while (ri > start_word) {
                const d = decodeOneRevLen(span, ri);
                const is_ws = unicode.isWhitespace(d.cp);
                if (!is_ws) break;
                start_lb = ri - d.len;
                ri -= d.len;
            }
        }
        if (start_word < start_lb) {
            try words.append(alloc, .{
                .start = span_abs_start + start_word,
                .end = span_abs_start + start_lb,
                .blank = false,
            });
        }
        if (start_lb < end_lb) {
            var ci = start_lb;
            while (ci < end_lb) {
                const d = decodeOne(span, ci);
                try words.append(alloc, .{
                    .start = span_abs_start + ci,
                    .end = span_abs_start + ci + d.len,
                    .blank = true,
                });
                ci += d.len;
            }
        }
        start_word = end_lb;
    }
    return words.toOwnedSlice(alloc);
}

fn decodeOneRev(text: []const u8, end: usize) u21 {
    return decodeOneRevLen(text, end).cp;
}

fn decodeOneRevLen(text: []const u8, end: usize) Decoded {
    var s = end -| 1;
    // Walk back over continuation bytes (max 3).
    var n: usize = 0;
    while (s > 0 and n < 3 and (text[s] >> 6 == 0b10)) : (n += 1) {
        s -= 1;
    }
    const d = decodeOne(text, s);
    if (s + d.len != end) return .{ .cp = text[end - 1], .len = 1 };
    return d;
}

/// RTL reversals, verbatim from shape.rs:1107-1117: glyphs reverse in RTL
/// lines; words reverse when the span direction mismatches the line.
pub fn applySpanReversals(words: []ShapeWord, line_rtl: bool, span_rtl: bool) void {
    if (line_rtl) {
        for (words) |*w| std.mem.reverse(ShapeGlyph, w.glyphs);
    }
    if (line_rtl != span_rtl) {
        std.mem.reverse(ShapeWord, words);
    }
}

/// Build a span's words + decoration spans (shape.rs:963-1212).
pub fn buildSpan(
    alloc: std.mem.Allocator,
    adapter: ShapeAdapter,
    buf: *ShapeBuffer,
    line: []const u8,
    attrs: *const AttrsList,
    span_start: usize,
    span_end: usize,
    line_rtl: bool,
    level: Level,
    shaping: Shaping,
) ShapeError!ShapeSpan {
    const span = line[span_start..span_end];
    const font = adapter.primaryFont();
    const splits = try splitSpanWords(alloc, adapter, font, span, span_start, attrs);
    defer alloc.free(splits);

    var words: std.ArrayList(ShapeWord) = .empty;
    errdefer {
        for (words.items) |*w| w.deinitChildren(alloc);
        words.deinit(alloc);
    }
    try words.ensureTotalCapacity(alloc, splits.len);
    for (splits) |sp| {
        const w = try buildWord(alloc, adapter, buf, line, attrs, sp.start, sp.end, level, sp.blank, shaping);
        words.appendAssumeCapacity(w);
    }
    const owned_words = try words.toOwnedSlice(alloc);
    applySpanReversals(owned_words, line_rtl, levelIsRtl(level));

    // Decoration spans, verbatim from shape.rs:1125-1208.
    var decorations: std.ArrayList(DecoRange) = .empty;
    errdefer decorations.deinit(alloc);
    var any_decoration = attrs.default_attrs.text_decoration.has_decoration();
    if (!any_decoration) {
        for (attrs.spans.items) |*s| {
            const st = @max(s.start, span_start);
            const en = @min(s.end, span_end);
            if (st < en and s.attrs.text_decoration.has_decoration()) {
                any_decoration = true;
                break;
            }
        }
    }
    if (any_decoration) {
        // Primary font metrics from the first shaped glyph (Pango convention).
        var primary: ?ShapingFontMetrics = null;
        for (owned_words) |*w| {
            if (w.glyphs.len > 0) {
                primary = adapter.fontMetrics(w.glyphs[0].font_id);
                break;
            }
        }
        if (primary) |pm| {
            // Font-provided decoration metrics (shape.rs:710-731): the
            // underline/strikeout offsets and thicknesses scale by font size.
            const deco = decorationMetrics(
                pm.underline,
                pm.strikethrough,
                pm.units_per_em,
                pm.ascent_units,
            );
            const ul = deco.underline;
            const st_m = deco.strikethrough;
            const deco_ascent = if (pm.units_per_em > 0) deco.ascent else pm.ascent;
            var covered_end = span_start;
            for (attrs.spans.items) |*s| {
                const st = @max(s.start, span_start);
                const en = @min(s.end, span_end);
                if (st >= en) continue;
                if (covered_end < st and attrs.default_attrs.text_decoration.has_decoration()) {
                    try decorations.append(alloc, .{ .start = covered_end, .end = st, .data = .{
                        .text_decoration = attrs.default_attrs.text_decoration,
                        .underline_metrics = ul,
                        .strikethrough_metrics = st_m,
                        .ascent = deco_ascent,
                    } });
                }
                covered_end = en;
                if (s.attrs.text_decoration.has_decoration()) {
                    try decorations.append(alloc, .{ .start = st, .end = en, .data = .{
                        .text_decoration = s.attrs.text_decoration,
                        .underline_metrics = ul,
                        .strikethrough_metrics = st_m,
                        .ascent = deco_ascent,
                    } });
                }
            }
            if (covered_end < span_end and attrs.default_attrs.text_decoration.has_decoration()) {
                try decorations.append(alloc, .{ .start = covered_end, .end = span_end, .data = .{
                    .text_decoration = attrs.default_attrs.text_decoration,
                    .underline_metrics = ul,
                    .strikethrough_metrics = st_m,
                    .ascent = deco_ascent,
                } });
            }
        }
    }

    return .{
        .level = level,
        .words = owned_words,
        .decorations = try decorations.toOwnedSlice(alloc),
    };
}

// ---------------------------------------------------------------------------
// ShapeLine::build + adjust_levels (shape.rs:1215-1530)
// ---------------------------------------------------------------------------

/// Base level for a line: forced direction wins, else the UAX#9 P2/P3
/// first-strong paragraph level from `unicode.zig` (shape.rs:1369-1376).
pub fn baseLevelForText(text: []const u8, direction: Direction) bool {
    const base: unicode.BaseDirection = switch (direction) {
        .auto => .auto,
        .left_to_right => .ltr,
        .right_to_left => .rtl,
    };
    return unicode.levelIsRtl(unicode.paragraphLevel(text, base));
}

pub const LevelRun = struct {
    start: usize,
    end: usize,
    level: Level,
};

/// Per-byte levels + classes for a line under a paragraph base level.
pub const LevelData = struct {
    levels: []Level,
    classes: []BidiClass,

    pub fn deinit(self: *LevelData, alloc: std.mem.Allocator) void {
        alloc.free(self.levels);
        alloc.free(self.classes);
    }
};

/// Resolve per-byte BiDi levels with `unicode.baseLevels` (UAX#9 X1-X8,
/// I1/I2, and L1) and pair them with per-byte `BidiClass` values for the
/// `adjustLevelsL1` consumers. `baseLevels` already applies L1, so the
/// `adjustLevelsL1` pass in `ShapeLine.build` is idempotent.
pub fn computeLevels(alloc: std.mem.Allocator, text: []const u8, para_rtl: bool) ShapeError!LevelData {
    const levels = try unicode.baseLevels(alloc, text, if (para_rtl) .rtl else .ltr);
    errdefer alloc.free(levels);
    const classes = try alloc.alloc(BidiClass, text.len);
    errdefer alloc.free(classes);
    var i: usize = 0;
    while (i < text.len) {
        const d = decodeOne(text, i);
        const cls = unicode.bidiClass(d.cp);
        var j: usize = 0;
        while (j < d.len) : (j += 1) {
            classes[i + j] = cls;
        }
        i += d.len;
    }
    return .{ .levels = levels, .classes = classes };
}

/// UAX#9 L1 whitespace reset, verbatim from `adjust_levels`
/// (shape.rs:1480-1530): trailing whitespace/isolates (and B/S runs) reset to
/// the paragraph level.
pub fn adjustLevelsL1(levels: []Level, classes: []const BidiClass, text: []const u8, para: Level) void {
    var reset_from: ?usize = 0;
    var reset_to: ?usize = null;
    var i: usize = 0;
    while (i < text.len) {
        const d = decodeOne(text, i);
        switch (classes[i]) {
            .lre, .rle, .lro, .rlo, .pdf, .bn => {},
            .b, .s => {
                if (reset_to) |to| {
                    // Defensive flush (upstream asserts this is unreachable).
                    if (reset_from) |from| {
                        if (from < to and to <= levels.len) {
                            for (levels[from..to]) |*l| l.* = para;
                        }
                    }
                    reset_from = null;
                    reset_to = null;
                }
                reset_to = i + d.len;
                if (reset_from == null) reset_from = i;
            },
            .ws, .fsi, .lri, .rli, .pdi => {
                if (reset_from == null) reset_from = i;
            },
            else => {
                reset_from = null;
            },
        }
        if (reset_from) |from| {
            if (reset_to) |to| {
                if (from <= to and to <= levels.len) {
                    for (levels[from..to]) |*l| l.* = para;
                }
                reset_from = null;
                reset_to = null;
            }
        }
        i += d.len;
    }
    if (reset_from) |from| {
        if (from <= levels.len) {
            for (levels[from..]) |*l| l.* = para;
        }
    }
}

/// Consecutive equal-level runs (shape.rs:1384-1423).
pub fn levelRuns(alloc: std.mem.Allocator, levels: []const Level, start: usize, end: usize) ShapeError![]LevelRun {
    var runs: std.ArrayList(LevelRun) = .empty;
    errdefer runs.deinit(alloc);
    if (start >= end) return runs.toOwnedSlice(alloc);
    var rs = start;
    var rlvl = levels[start];
    var i = start + 1;
    while (i < end) : (i += 1) {
        if (levels[i] != rlvl) {
            try runs.append(alloc, .{ .start = rs, .end = i, .level = rlvl });
            rs = i;
            rlvl = levels[i];
        }
    }
    try runs.append(alloc, .{ .start = rs, .end = end, .level = rlvl });
    return runs.toOwnedSlice(alloc);
}

/// A shaped line / paragraph (shape.rs:1215-1222).
pub const ShapeLine = struct {
    rtl: bool = false,
    spans: []ShapeSpan = &.{},
    metrics_opt: ?Metrics = null,
    ellipsis_span: ?ShapeSpan = null,

    pub fn deinit(self: *ShapeLine, alloc: std.mem.Allocator) void {
        for (self.spans) |*s| s.deinitChildren(alloc);
        if (self.spans.len > 0) alloc.free(self.spans);
        self.spans = &.{};
        if (self.ellipsis_span) |*e| {
            e.deinitChildren(alloc);
            self.ellipsis_span = null;
        }
    }

    /// Shape a line into spans (shape.rs:1348-1477): base direction, L1 level
    /// adjustment, level-run spans, tab floor stops, ellipsis pre-shaping.
    pub fn build(
        self: *ShapeLine,
        alloc: std.mem.Allocator,
        adapter: ShapeAdapter,
        buf: *ShapeBuffer,
        line: []const u8,
        attrs: *const AttrsList,
        shaping: Shaping,
        tab_width: u16,
        direction: Direction,
    ) ShapeError!void {
        // Clear stale ellipsis so reused lines reshape with current attrs
        // (shape.rs:1357-1360).
        if (self.ellipsis_span) |*e| {
            e.deinitChildren(alloc);
            self.ellipsis_span = null;
        }
        for (self.spans) |*s| s.deinitChildren(alloc);
        if (self.spans.len > 0) alloc.free(self.spans);
        self.spans = &.{};

        const rtl = baseLevelForText(line, direction);

        var spans: std.ArrayList(ShapeSpan) = .empty;
        errdefer {
            for (spans.items) |*s| s.deinitChildren(alloc);
            spans.deinit(alloc);
        }
        if (line.len > 0) {
            var ld = try computeLevels(alloc, line, rtl);
            defer ld.deinit(alloc);
            adjustLevelsL1(ld.levels, ld.classes, line, if (rtl) LEVEL_RTL else LEVEL_LTR);
            const runs = try levelRuns(alloc, ld.levels, 0, line.len);
            defer alloc.free(runs);
            for (runs) |r| {
                const span = try buildSpan(alloc, adapter, buf, line, attrs, r.start, r.end, rtl, r.level, shaping);
                try spans.append(alloc, span);
            }
        }
        self.spans = try spans.toOwnedSlice(alloc);

        // Tabs: floor to the next tab stop (shape.rs:1425-1439).
        var x: f32 = 0;
        for (self.spans) |*span| {
            for (span.words) |*word| {
                for (word.glyphs) |*glyph| {
                    const is_tab = line.len >= glyph.end and
                        glyph.end - glyph.start == 1 and
                        line[glyph.start] == '\t';
                    if (is_tab) {
                        const tab_adv = @as(f32, @floatFromInt(tab_width)) * glyph.x_advance;
                        if (tab_adv > 0) {
                            const stop = (@floor(x / tab_adv) + 1.0) * tab_adv;
                            glyph.x_advance = stop - x;
                        }
                    }
                    x += glyph.x_advance;
                }
            }
        }

        self.rtl = rtl;
        self.metrics_opt = if (attrs.default_attrs.metrics_opt) |m| m.to_metrics() else null;

        // Ellipsis pre-shaping (shape.rs:1445-1473). Uses the first span's
        // attrs when spans exist even if ellipsizing at the end.
        const ea: *const attrs_mod.AttrsOwned = if (attrs.spans.items.len == 0) &attrs.default_attrs else attrs.get_span(0);
        const glyphs = try shapeEllipsis(alloc, adapter, buf, ea, shaping, rtl);
        if (rtl) std.mem.reverse(ShapeGlyph, glyphs);
        const ewords = try alloc.alloc(ShapeWord, 1);
        ewords[0] = .{ .blank = false, .glyphs = glyphs };
        // Placeholder level; the real level is set on the VlRange at layout
        // time (shape.rs:1461-1467).
        self.ellipsis_span = .{
            .level = if (rtl) LEVEL_RTL else LEVEL_LTR,
            .words = ewords,
            .decorations = &.{},
        };
    }

    /// Words for a span index, honouring the ellipsis sentinel
    /// (shape.rs:2106-2117).
    pub fn getSpanWords(self: *const ShapeLine, span_index: usize) ShapeError![]ShapeWord {
        if (span_index == ELLIPSIS_SPAN) {
            if (self.ellipsis_span) |*e| return e.words;
            return error.EllipsisNotShaped;
        }
        return self.spans[span_index].words;
    }

    /// Width of the ellipsis at `font_size` (shape.rs:2186-2191).
    pub fn ellipsisW(self: *const ShapeLine, font_size: f32) f32 {
        if (self.ellipsis_span) |*e| {
            var w: f32 = 0;
            for (e.words) |*word| w += word.width(font_size);
            return w;
        }
        return 0;
    }

    /// Ellipsis `VlRange` at a BiDi level (shape.rs:2193-2201).
    pub fn ellipsisVlRange(level: Level) VlRange {
        return .{
            .span = ELLIPSIS_SPAN,
            .start = .{ .word = 0, .glyph = 0 },
            .end = .{ .word = 1, .glyph = 0 },
            .level = level,
        };
    }

    /// Ellipsis BiDi level from adjacent ranges, UAX#9 N1/N2 for neutrals
    /// (shape.rs:2203-2222).
    pub fn ellipsisLevelBetween(self: *const ShapeLine, before: ?*const VlRange, after: ?*const VlRange) Level {
        if (before) |a| {
            if (after) |b| {
                if (a.level == b.level) return a.level;
            } else {
                return a.level;
            }
        } else if (after) |b| {
            return b.level;
        }
        return if (self.rtl) LEVEL_RTL else LEVEL_LTR;
    }

    /// Max glyph end across non-ellipsis spans (shape.rs:2174-2184).
    pub fn maxByteOffset(self: *const ShapeLine) usize {
        var max: usize = 0;
        for (self.spans) |*span| {
            for (span.words) |*word| {
                for (word.glyphs) |*g| max = @max(max, g.end);
            }
        }
        return max;
    }

    fn byteRangeOfVlRange(self: *const ShapeLine, r: *const VlRange) ShapeError!?[2]usize {
        std.debug.assert(r.span != ELLIPSIS_SPAN);
        const words = try self.getSpanWords(r.span);
        var min_byte: usize = std.math.maxInt(usize);
        var max_byte: usize = 0;
        const end_word = r.end.word + @as(usize, if (r.end.glyph != 0) 1 else 0);
        var i = r.start.word;
        while (i < end_word and i < words.len) : (i += 1) {
            const word = &words[i];
            const a = if (i == r.start.word) r.start.glyph else 0;
            const b = if (i == r.end.word) r.end.glyph else word.glyphs.len;
            const lo = @min(a, word.glyphs.len);
            const hi = @min(b, word.glyphs.len);
            if (hi < lo) continue;
            for (word.glyphs[lo..hi]) |*g| {
                min_byte = @min(min_byte, g.start);
                max_byte = @max(max_byte, g.end);
            }
        }
        if (min_byte <= max_byte) return .{ min_byte, max_byte };
        return null;
    }

    /// Byte range replaced by the ellipsis (shape.rs:2144-2172).
    pub fn computeElidedByteRange(self: *const ShapeLine, vl: *const VisualLine, line_len: usize) ShapeError!?[2]usize {
        if (!vl.ellipsized) return null;
        var ellipsis_idx: ?usize = null;
        for (vl.ranges.items, 0..) |*r, i| {
            if (r.span == ELLIPSIS_SPAN) {
                ellipsis_idx = i;
                break;
            }
        }
        const ei = ellipsis_idx orelse return null;
        var before_end: usize = 0;
        var i: usize = ei;
        while (i > 0) {
            i -= 1;
            if (try self.byteRangeOfVlRange(&vl.ranges.items[i])) |br| {
                before_end = br[1];
                break;
            }
        }
        var after_start: usize = line_len;
        var j: usize = ei + 1;
        while (j < vl.ranges.items.len) : (j += 1) {
            if (try self.byteRangeOfVlRange(&vl.ranges.items[j])) |br| {
                after_start = br[0];
                break;
            }
        }
        return .{ before_end, after_start };
    }

    /// L2 visual reordering, verbatim from shape.rs:1532-1587. Each `VlRange`
    /// is its own element so reversal reorders even same-level neighbours.
    pub fn reorder(self: *const ShapeLine, alloc: std.mem.Allocator, ranges: []const VlRange) ShapeError![]Range {
        _ = self;
        const count = ranges.len;
        if (count == 0) return &.{};
        var elements: std.ArrayList(Range) = .empty;
        defer elements.deinit(alloc);
        for (0..count) |i| try elements.append(alloc, .{ .start = i, .end = i + 1 });

        var min_level = ranges[0].level;
        var max_level = ranges[0].level;
        for (ranges[1..]) |r| {
            min_level = @min(min_level, r.level);
            max_level = @max(max_level, r.level);
        }
        // Stop at the lowest odd level (shape.rs:1555-1556).
        if (min_level % 2 == 0) {
            if (min_level == std.math.maxInt(Level)) return error.LevelOverflow;
            min_level += 1;
        }
        while (max_level >= min_level) {
            var seq_start: usize = 0;
            while (seq_start < count) {
                if (ranges[elements.items[seq_start].start].level < max_level) {
                    seq_start += 1;
                    continue;
                }
                var seq_end = seq_start + 1;
                while (seq_end < count) {
                    if (ranges[elements.items[seq_end].start].level < max_level) break;
                    seq_end += 1;
                }
                std.mem.reverse(Range, elements.items[seq_start..seq_end]);
                seq_start = seq_end;
            }
            if (max_level == 0) break;
            max_level -= 1;
        }
        return elements.toOwnedSlice(alloc);
    }

    pub fn layout(
        self: *const ShapeLine,
        alloc: std.mem.Allocator,
        font_size: f32,
        width_opt: ?f32,
        wrap: Wrap,
        align_opt: ?Align,
        match_mono_width: ?f32,
        hinting: Hinting,
    ) ShapeError![]LayoutLine {
        var buf = ShapeBuffer.init();
        defer buf.deinit(alloc);
        var out: std.ArrayList(LayoutLine) = .empty;
        defer out.deinit(alloc);
        try self.layoutToBuffer(alloc, &buf, font_size, width_opt, wrap, .{ .none = {} }, align_opt, &out, match_mono_width, hinting);
        return out.toOwnedSlice(alloc);
    }

    fn getGlyphStartEnd(
        word_len: usize,
        start: SpanWordGlyphPos,
        span_index: usize,
        word_idx: usize,
        congruent: bool,
    ) [2]usize {
        // Verbatim from shape.rs:1614-1631 (`direction` is unused upstream).
        if (span_index != start.span or word_idx != start.word) {
            return .{ 0, word_len };
        }
        if (congruent) return .{ start.glyph, word_len };
        return .{ 0, start.glyph };
    }

    fn fitGlyphs(
        word: *const ShapeWord,
        font_size: f32,
        start: SpanWordGlyphPos,
        span_index: usize,
        word_idx: usize,
        congruent: bool,
        used: f32,
        available: f32,
        forward: bool,
    ) FitResult {
        // Verbatim from shape.rs:1633-1672.
        var w: f32 = 0;
        const se = getGlyphStartEnd(word.glyphs.len, start, span_index, word_idx, congruent);
        if (forward) {
            var glyph_end = se[0];
            var gi = se[0];
            while (gi < se[1]) : (gi += 1) {
                const g_w = word.glyphs[gi].width(font_size);
                if (used + w + g_w > available) break;
                w += g_w;
                glyph_end = gi + 1;
            }
            return .{ .end = glyph_end, .w = w };
        } else {
            var glyph_end = word.glyphs.len;
            var gi = se[1];
            while (gi > se[0]) {
                gi -= 1;
                const g_w = word.glyphs[gi].width(font_size);
                if (used + w + g_w > available) break;
                w += g_w;
                glyph_end = gi;
            }
            return .{ .end = glyph_end, .w = w };
        }
    }

    fn addToVisualLine(
        self: *const ShapeLine,
        alloc: std.mem.Allocator,
        vl: *VisualLine,
        span_index: usize,
        start: WordGlyphPos,
        end: WordGlyphPos,
        width: f32,
        blanks: u32,
    ) void {
        // Verbatim from shape.rs:1674-1696.
        if (end.word == start.word and end.glyph == start.glyph) return;
        vl.ranges.append(alloc, .{
            .span = span_index,
            .start = start,
            .end = end,
            .level = self.spans[span_index].level,
        }) catch return;
        vl.w += width;
        vl.spaces += blanks;
    }

    fn remainingContentExceeds(
        spans: []const ShapeSpan,
        font_size: f32,
        span_index: usize,
        word_idx: usize,
        word_count: usize,
        starting_word_index: usize,
        direction: LayoutDirection,
        congruent: bool,
        start_span: usize,
        span_count: usize,
        threshold: f32,
    ) bool {
        // Verbatim from shape.rs:1698-1742.
        var acc: f32 = 0;
        const lo: usize, const hi: usize = switch (direction) {
            .forward => if (congruent) .{ word_idx + 1, word_count } else .{ 0, word_idx },
            .backward => if (congruent) .{ starting_word_index, word_idx } else .{ word_idx + 1, word_count },
        };
        var wi = lo;
        while (wi < hi and wi < spans[span_index].words.len) : (wi += 1) {
            acc += spans[span_index].words[wi].width(font_size);
            if (acc > threshold) return true;
        }
        const slo: usize, const shi: usize = switch (direction) {
            .forward => .{ span_index + 1, span_count },
            .backward => .{ start_span, span_index },
        };
        var si = slo;
        while (si < shi and si < spans.len) : (si += 1) {
            for (spans[si].words) |*w| {
                acc += w.width(font_size);
                if (acc > threshold) return true;
            }
        }
        return false;
    }

    /// Fit spans into one visual line, forward or backward (shape.rs:1744-1989).
    fn layoutSpans(
        self: *const ShapeLine,
        alloc: std.mem.Allocator,
        vl: *VisualLine,
        spans: []const ShapeSpan,
        font_size: f32,
        start_opt: ?SpanWordGlyphPos,
        rtl: bool,
        width_opt: ?f32,
        ellipsize: Ellipsize,
        ellipsis_w: f32,
        direction: LayoutDirection,
    ) ShapeError!void {
        const check_ellipsizing = (ellipsize == .start or ellipsize == .end) and
            (width_opt != null and std.math.isFinite(width_opt.?));
        const max_width = width_opt orelse std.math.inf(f32);
        const span_count = spans.len;
        var total_w: f32 = 0;
        const start = start_opt orelse SpanWordGlyphPos.ZERO;

        var span_order: std.ArrayList(usize) = .empty;
        defer span_order.deinit(alloc);
        if (direction == .forward) {
            var si = start.span;
            while (si < spans.len) : (si += 1) try span_order.append(alloc, si);
        } else {
            var si = spans.len;
            while (si > start.span) {
                si -= 1;
                try span_order.append(alloc, si);
            }
        }

        outer: for (span_order.items) |span_index| {
            var word_range_width: f32 = 0;
            var blanks: u32 = 0;
            const span = &spans[span_index];
            const word_count = span.words.len;
            const starting_word_index = if (span_index == start.span) start.word else 0;
            const congruent = rtl == levelIsRtl(span.level);
            const word_forward = congruent == (direction == .forward);

            // Word visit order, verbatim from shape.rs:1797-1822.
            var word_order: std.ArrayList(usize) = .empty;
            defer word_order.deinit(alloc);
            switch (direction) {
                .forward => {
                    if (congruent) {
                        var wi = starting_word_index;
                        while (wi < word_count) : (wi += 1) try word_order.append(alloc, wi);
                    } else if (start_opt != null and span_index == start.span) {
                        var wi = start.word;
                        while (wi > 0) {
                            wi -= 1;
                            try word_order.append(alloc, wi);
                        }
                    } else {
                        var wi = word_count;
                        while (wi > 0) {
                            wi -= 1;
                            try word_order.append(alloc, wi);
                        }
                    }
                },
                .backward => {
                    if (congruent) {
                        var wi = word_count;
                        while (wi > starting_word_index) {
                            wi -= 1;
                            try word_order.append(alloc, wi);
                        }
                    } else if (start_opt != null and span_index == start.span) {
                        const hi = if (start.glyph > 0) start.word + 1 else start.word;
                        var wi: usize = 0;
                        while (wi < hi) : (wi += 1) try word_order.append(alloc, wi);
                    } else {
                        var wi: usize = 0;
                        while (wi < word_count) : (wi += 1) try word_order.append(alloc, wi);
                    }
                },
            }

            for (word_order.items) |word_idx| {
                const word = &span.words[word_idx];
                var word_width: f32 = 0;
                if (span_index == start.span and word_idx == start.word) {
                    const se = getGlyphStartEnd(word.glyphs.len, start, span_index, word_idx, congruent);
                    var gi = se[0];
                    while (gi < se[1]) : (gi += 1) word_width += word.glyphs[gi].width(font_size);
                } else {
                    word_width = word.width(font_size);
                }

                const overflowing = check_ellipsizing and
                    ((total_w + word_range_width + word_width > max_width) or
                        (remainingContentExceeds(spans, font_size, span_index, word_idx, word_count, starting_word_index, direction, congruent, start.span, span_count, ellipsis_w) and
                            total_w + word_range_width + word_width + ellipsis_w > max_width));
                if (overflowing) {
                    const available = @max(max_width - ellipsis_w, 0.0);
                    const fit = fitGlyphs(word, font_size, start, span_index, word_idx, congruent, total_w + word_range_width, available, word_forward);
                    if (word_forward) {
                        if (span_index == start.span and !congruent) {
                            self.addToVisualLine(alloc, vl, span_index, .{ .word = 0, .glyph = 0 }, .{ .word = word_idx, .glyph = fit.end }, word_range_width + fit.w, blanks);
                        } else if (span_index == start.span) {
                            self.addToVisualLine(alloc, vl, span_index, start.wordGlyphPos(), .{ .word = word_idx, .glyph = fit.end }, word_range_width + fit.w, blanks);
                        } else {
                            self.addToVisualLine(alloc, vl, span_index, .{ .word = 0, .glyph = 0 }, .{ .word = word_idx, .glyph = fit.end }, word_range_width + fit.w, blanks);
                        }
                    } else {
                        // Verbatim cap for incongruent-forward continuations
                        // (shape.rs:1891-1905).
                        const range_end: WordGlyphPos = if (span_index == start.span and !congruent)
                            start.wordGlyphPos()
                        else
                            .{ .word = span.words.len, .glyph = 0 };
                        self.addToVisualLine(alloc, vl, span_index, .{ .word = word_idx, .glyph = fit.end }, range_end, word_range_width + fit.w, blanks);
                    }
                    vl.ellipsized = true;
                    break :outer;
                }

                word_range_width += word_width;
                if (word.blank) blanks += 1;

                // Backward-only commit at the starting point (shape.rs:1925-1949).
                if (direction == .backward and word_idx == start.word and span_index == start.span) {
                    if (word_forward) {
                        self.addToVisualLine(alloc, vl, span_index, .{ .word = 0, .glyph = 0 }, start.wordGlyphPos(), word_range_width, blanks);
                    } else {
                        self.addToVisualLine(alloc, vl, span_index, start.wordGlyphPos(), .{ .word = span.words.len, .glyph = 0 }, word_range_width, blanks);
                    }
                    break :outer;
                }
            }

            total_w += word_range_width;
            // Tail commit, verbatim from shape.rs:1952-1983.
            if (congruent) {
                if (span_index == start.span) {
                    self.addToVisualLine(alloc, vl, span_index, start.wordGlyphPos(), .{ .word = span.words.len, .glyph = 0 }, word_range_width, blanks);
                } else {
                    self.addToVisualLine(alloc, vl, span_index, .{ .word = 0, .glyph = 0 }, .{ .word = span.words.len, .glyph = 0 }, word_range_width, blanks);
                }
            } else if (span_index == start.span and (start.word != 0 or start.glyph != 0)) {
                self.addToVisualLine(alloc, vl, span_index, .{ .word = 0, .glyph = 0 }, start.wordGlyphPos(), word_range_width, blanks);
            } else {
                self.addToVisualLine(alloc, vl, span_index, .{ .word = 0, .glyph = 0 }, .{ .word = span.words.len, .glyph = 0 }, word_range_width, blanks);
            }
        }

        if (direction == .backward) {
            std.mem.reverse(VlRange, vl.ranges.items);
        }
    }

    /// Middle ellipsization: forward half + backward half (shape.rs:1991-2104).
    fn layoutMiddle(
        self: *const ShapeLine,
        alloc: std.mem.Allocator,
        vl: *VisualLine,
        spans: []const ShapeSpan,
        font_size: f32,
        start_opt: ?SpanWordGlyphPos,
        rtl: bool,
        width: f32,
        ellipsize: Ellipsize,
        ellipsis_w: f32,
    ) ShapeError!void {
        std.debug.assert(ellipsize == .middle);
        {
            var test_vl = VisualLine{};
            defer test_vl.deinit(alloc);
            try self.layoutSpans(alloc, &test_vl, spans, font_size, start_opt, rtl, width, .{ .end = .{ .lines = 1 } }, ellipsis_w, .forward);
            if (!test_vl.ellipsized and test_vl.w <= width) {
                // Fits without ellipsis (shape.rs:2018-2021).
                vl.ranges.clearRetainingCapacity();
                try vl.ranges.appendSlice(alloc, test_vl.ranges.items);
                vl.w = test_vl.w;
                vl.spaces = test_vl.spaces;
                vl.ellipsized = false;
                return;
            }
        }
        var first_half = VisualLine{};
        defer first_half.deinit(alloc);
        try self.layoutSpans(alloc, &first_half, spans, font_size, start_opt, rtl, width / 2.0, .{ .end = .{ .lines = 1 } }, 0, .forward);
        const overflowed = first_half.ellipsized;
        const last = if (first_half.ranges.items.len > 0) &first_half.ranges.items[first_half.ranges.items.len - 1] else null;
        if (last != null and overflowed) {
            const r = last.?;
            const congruent = rtl == levelIsRtl(self.spans[r.span].level);
            const resume_pos: SpanWordGlyphPos = if (congruent)
                .{ .span = r.span, .word = r.end.word, .glyph = r.end.glyph }
            else
                .{ .span = r.span, .word = r.start.word, .glyph = r.start.glyph };
            var second_half = VisualLine{};
            defer second_half.deinit(alloc);
            try self.layoutSpans(alloc, &second_half, spans, font_size, resume_pos, rtl, @max(width - first_half.w - ellipsis_w, 0.0), .{ .start = .{ .lines = 1 } }, 0, .backward);
            const lvl = self.ellipsisLevelBetween(last, if (second_half.ranges.items.len > 0) &second_half.ranges.items[0] else null);
            try vl.ranges.appendSlice(alloc, first_half.ranges.items);
            try vl.ranges.append(alloc, ellipsisVlRange(lvl));
            try vl.ranges.appendSlice(alloc, second_half.ranges.items);
            vl.ellipsized = true;
            vl.w = first_half.w + second_half.w + ellipsis_w;
            vl.spaces = first_half.spaces + second_half.spaces;
        } else if (last == null and overflowed and width > ellipsis_w) {
            // Only the ellipsis fits (shape.rs:2082-2095).
            try vl.ranges.append(alloc, ellipsisVlRange(if (self.rtl) LEVEL_RTL else LEVEL_LTR));
            vl.ellipsized = true;
            vl.w = ellipsis_w;
            vl.spaces = 0;
        } else {
            // Everything fit in the forward pass (shape.rs:2096-2103).
            vl.ranges.clearRetainingCapacity();
            try vl.ranges.appendSlice(alloc, first_half.ranges.items);
            vl.w = first_half.w;
            vl.spaces = first_half.spaces;
            vl.ellipsized = false;
        }
    }

    /// One visual line with ellipsis policy (shape.rs:2224-2302).
    fn layoutLine(
        self: *const ShapeLine,
        alloc: std.mem.Allocator,
        vl: *VisualLine,
        spans: []const ShapeSpan,
        font_size: f32,
        start_opt: ?SpanWordGlyphPos,
        rtl: bool,
        width_opt: ?f32,
        ellipsize: Ellipsize,
    ) ShapeError!void {
        const ellipsis_w = self.ellipsisW(font_size);
        if (ellipsize == .start and width_opt != null) {
            try self.layoutSpans(alloc, vl, spans, font_size, start_opt, rtl, width_opt, ellipsize, ellipsis_w, .backward);
            if (vl.ellipsized) {
                const lvl = self.ellipsisLevelBetween(null, if (vl.ranges.items.len > 0) &vl.ranges.items[0] else null);
                try vl.ranges.insert(alloc, 0, ellipsisVlRange(lvl));
                vl.w += ellipsis_w;
            }
        } else if (ellipsize == .middle and width_opt != null) {
            try self.layoutMiddle(alloc, vl, spans, font_size, start_opt, rtl, width_opt.?, ellipsize, ellipsis_w);
        } else {
            try self.layoutSpans(alloc, vl, spans, font_size, start_opt, rtl, width_opt, ellipsize, ellipsis_w, .forward);
            if (vl.ellipsized) {
                const lvl = self.ellipsisLevelBetween(if (vl.ranges.items.len > 0) &vl.ranges.items[vl.ranges.items.len - 1] else null, null);
                try vl.ranges.append(alloc, ellipsisVlRange(lvl));
                vl.w += ellipsis_w;
            }
        }
        if (vl.ellipsized) {
            vl.elided_byte_range = try self.computeElidedByteRange(vl, self.maxByteOffset());
        }
    }

    /// Full wrap + align + justify engine (shape.rs:2304-3083).
    pub fn layoutToBuffer(
        self: *const ShapeLine,
        alloc: std.mem.Allocator,
        buf: *ShapeBuffer,
        font_size: f32,
        width_opt: ?f32,
        wrap: Wrap,
        ellipsize: Ellipsize,
        align_opt: ?Align,
        out: *std.ArrayList(LayoutLine),
        match_mono_width: ?f32,
        hinting: Hinting,
    ) ShapeError!void {
        // Take scratch pools (shape.rs:2319-2333).
        var visual_lines = buf.visual_lines;
        buf.visual_lines = .empty;
        defer buf.visual_lines = visual_lines;
        var cached = buf.cached_visual_lines;
        buf.cached_visual_lines = .empty;
        defer buf.cached_visual_lines = cached;
        // Drop the previous pool's visual lines with their `ranges` storage;
        // `clearRetainingCapacity` alone would leak those allocations.
        for (cached.items) |*l| l.deinit(alloc);
        cached.clearRetainingCapacity();
        for (visual_lines.items) |*l| {
            l.clear();
            cached.append(alloc, l.*) catch {
                l.deinit(alloc);
                continue;
            };
            l.ranges = .empty;
        }
        visual_lines.clearRetainingCapacity();
        var glyph_pool = buf.glyph_sets;
        buf.glyph_sets = .empty;
        defer buf.glyph_sets = glyph_pool;
        // Drop the previous pool's retained glyph buffers; they still own
        // their `items` capacity (`clearRetainingCapacity` keeps it).
        for (glyph_pool.items) |*g| g.deinit(alloc);
        glyph_pool.clearRetainingCapacity();
        for (out.items) |*l| {
            l.decorations.deinit(alloc);
            l.decorations = .empty;
            var g = l.glyphs;
            g.clearRetainingCapacity();
            glyph_pool.append(alloc, g) catch {
                g.deinit(alloc);
                continue;
            };
        }
        out.clearRetainingCapacity();

        var current: VisualLine = if (cached.pop()) |vl| vl else .{};
        // On error the in-progress line is still owned here; pools restore
        // via the defers above. Ownership transfers to `cached`/`visual_lines`
        // at the final hand-off below, so disarm the errdefer there to avoid
        // freeing ranges the restored pools still reference.
        var current_owned = true;
        errdefer if (current_owned) current.deinit(alloc);

        if (wrap == .none) {
            try self.layoutLine(alloc, &current, self.spans, font_size, null, self.rtl, width_opt, ellipsize);
        } else {
            var total_h: f32 = 0;
            var total_n: usize = 0;
            const max_n_opt: ?usize = switch (ellipsize) {
                .start => |l| l.maxLines(),
                .middle => |l| l.maxLines(),
                .end => |l| l.maxLines(),
                .none => null,
            };
            const max_h_opt: ?f32 = switch (ellipsize) {
                .start => |l| switch (l) {
                    .height => |h| h,
                    else => null,
                },
                .middle => |l| switch (l) {
                    .height => |h| h,
                    else => null,
                },
                .end => |l| switch (l) {
                    .height => |h| h,
                    else => null,
                },
                .none => null,
            };
            const line_h = if (self.metrics_opt) |m| m.line_height else font_size;
            var ctx = EllipsizeCtx{
                .line = self,
                .alloc = alloc,
                .font_size = font_size,
                .width_opt = width_opt,
                .ellipsize = ellipsize,
                .max_n_opt = max_n_opt,
                .max_h_opt = max_h_opt,
                .line_h = line_h,
            };
            var broke_outer = false;
            if (try ctx.tryLastLine(&current, null, &total_n, &total_h)) {
                broke_outer = true;
            }
            if (!broke_outer) {
                outer: for (self.spans, 0..) |*span, span_index| {
                    var word_range_width: f32 = 0;
                    var width_before_last_blank: f32 = 0;
                    var blanks: u32 = 0;
                    if (self.rtl != levelIsRtl(span.level)) {
                        // Incongruent walk (shape.rs:2413-2598).
                        var fitting_start = WordGlyphPos{ .word = span.words.len, .glyph = 0 };
                        var ri = span.words.len;
                        while (ri > 0) {
                            ri -= 1;
                            const i = ri;
                            const word = &span.words[i];
                            const word_width = word.width(font_size);
                            const limit = width_opt orelse std.math.inf(f32);
                            if (current.w + (word_range_width + word_width) <= limit or
                                (word.blank and current.w + word_range_width <= limit))
                            {
                                if (word.blank) {
                                    blanks += 1;
                                    width_before_last_blank = word_range_width;
                                }
                                word_range_width += word_width;
                            } else if (wrap == .glyph or
                                (wrap == .word_or_glyph and word_width > limit))
                            {
                                if (word_range_width > 0 and wrap == .word_or_glyph and word_width > limit) {
                                    self.addToVisualLine(alloc, &current, span_index, .{ .word = i + 1, .glyph = 0 }, fitting_start, word_range_width, blanks);
                                    try pushVisualLine(alloc, &visual_lines, &cached, &current);
                                    blanks = 0;
                                    word_range_width = 0;
                                    fitting_start = .{ .word = i, .glyph = 0 };
                                    total_n += 1;
                                    total_h += line_h;
                                    if (try ctx.tryLastLine(&current, .{ .span = span_index, .word = fitting_start.word, .glyph = fitting_start.glyph }, &total_n, &total_h)) break :outer;
                                }
                                var gi = word.glyphs.len;
                                while (gi > 0) {
                                    gi -= 1;
                                    const gw = word.glyphs[gi].width(font_size);
                                    if (current.w + (word_range_width + gw) <= limit) {
                                        word_range_width += gw;
                                    } else {
                                        self.addToVisualLine(alloc, &current, span_index, .{ .word = i, .glyph = gi + 1 }, fitting_start, word_range_width, blanks);
                                        try pushVisualLine(alloc, &visual_lines, &cached, &current);
                                        blanks = 0;
                                        word_range_width = gw;
                                        fitting_start = .{ .word = i, .glyph = gi + 1 };
                                        total_n += 1;
                                        total_h += line_h;
                                        if (try ctx.tryLastLine(&current, .{ .span = span_index, .word = fitting_start.word, .glyph = fitting_start.glyph }, &total_n, &total_h)) break :outer;
                                    }
                                }
                            } else {
                                if (word_range_width > 0) {
                                    const trailing = (i + 1 < span.words.len) and span.words[i + 1].blank;
                                    if (trailing) {
                                        blanks -|= 1;
                                        self.addToVisualLine(alloc, &current, span_index, .{ .word = i + 2, .glyph = 0 }, fitting_start, width_before_last_blank, blanks);
                                    } else {
                                        self.addToVisualLine(alloc, &current, span_index, .{ .word = i + 1, .glyph = 0 }, fitting_start, word_range_width, blanks);
                                    }
                                }
                                if (current.ranges.items.len > 0) {
                                    try pushVisualLine(alloc, &visual_lines, &cached, &current);
                                    blanks = 0;
                                    total_n += 1;
                                    total_h += line_h;
                                    const resume_pos: WordGlyphPos = if (word.blank) .{ .word = i, .glyph = 0 } else .{ .word = i + 1, .glyph = 0 };
                                    if (try ctx.tryLastLine(&current, .{ .span = span_index, .word = resume_pos.word, .glyph = resume_pos.glyph }, &total_n, &total_h)) break :outer;
                                }
                                if (word.blank) {
                                    word_range_width = 0;
                                    fitting_start = .{ .word = i, .glyph = 0 };
                                } else {
                                    word_range_width = word_width;
                                    fitting_start = .{ .word = i + 1, .glyph = 0 };
                                }
                            }
                        }
                        self.addToVisualLine(alloc, &current, span_index, .{ .word = 0, .glyph = 0 }, fitting_start, word_range_width, blanks);
                    } else {
                        // Congruent walk (shape.rs:2599-2776).
                        var fitting_start = WordGlyphPos{ .word = 0, .glyph = 0 };
                        for (span.words, 0..) |*word, i| {
                            const word_width = word.width(font_size);
                            const limit = width_opt orelse std.math.inf(f32);
                            if (current.w + (word_range_width + word_width) <= limit or
                                (word.blank and current.w + word_range_width <= limit))
                            {
                                if (word.blank) {
                                    blanks += 1;
                                    width_before_last_blank = word_range_width;
                                }
                                word_range_width += word_width;
                            } else if (wrap == .glyph or
                                (wrap == .word_or_glyph and word_width > limit))
                            {
                                if (word_range_width > 0 and wrap == .word_or_glyph and word_width > limit) {
                                    self.addToVisualLine(alloc, &current, span_index, fitting_start, .{ .word = i, .glyph = 0 }, word_range_width, blanks);
                                    try pushVisualLine(alloc, &visual_lines, &cached, &current);
                                    blanks = 0;
                                    word_range_width = 0;
                                    fitting_start = .{ .word = i, .glyph = 0 };
                                    total_n += 1;
                                    total_h += line_h;
                                    if (try ctx.tryLastLine(&current, .{ .span = span_index, .word = fitting_start.word, .glyph = fitting_start.glyph }, &total_n, &total_h)) break :outer;
                                }
                                for (word.glyphs, 0..) |*glyph, gi| {
                                    const gw = glyph.width(font_size);
                                    if (current.w + (word_range_width + gw) <= limit) {
                                        word_range_width += gw;
                                    } else {
                                        self.addToVisualLine(alloc, &current, span_index, fitting_start, .{ .word = i, .glyph = gi }, word_range_width, blanks);
                                        try pushVisualLine(alloc, &visual_lines, &cached, &current);
                                        blanks = 0;
                                        word_range_width = gw;
                                        fitting_start = .{ .word = i, .glyph = gi };
                                        total_n += 1;
                                        total_h += line_h;
                                        if (try ctx.tryLastLine(&current, .{ .span = span_index, .word = fitting_start.word, .glyph = fitting_start.glyph }, &total_n, &total_h)) break :outer;
                                    }
                                }
                            } else {
                                if (word_range_width > 0) {
                                    const trailing = i > 0 and span.words[i - 1].blank;
                                    if (trailing) {
                                        blanks -|= 1;
                                        self.addToVisualLine(alloc, &current, span_index, fitting_start, .{ .word = i - 1, .glyph = 0 }, width_before_last_blank, blanks);
                                    } else {
                                        self.addToVisualLine(alloc, &current, span_index, fitting_start, .{ .word = i, .glyph = 0 }, word_range_width, blanks);
                                    }
                                }
                                if (current.ranges.items.len > 0) {
                                    try pushVisualLine(alloc, &visual_lines, &cached, &current);
                                    blanks = 0;
                                    total_n += 1;
                                    total_h += line_h;
                                    const resume_pos: WordGlyphPos = if (i > 0 and span.words[i - 1].blank)
                                        .{ .word = i - 1, .glyph = 0 }
                                    else
                                        .{ .word = i, .glyph = 0 };
                                    if (try ctx.tryLastLine(&current, .{ .span = span_index, .word = resume_pos.word, .glyph = resume_pos.glyph }, &total_n, &total_h)) break :outer;
                                }
                                if (word.blank) {
                                    word_range_width = 0;
                                    fitting_start = .{ .word = i + 1, .glyph = 0 };
                                } else {
                                    word_range_width = word_width;
                                    fitting_start = .{ .word = i, .glyph = 0 };
                                }
                            }
                        }
                        self.addToVisualLine(alloc, &current, span_index, fitting_start, .{ .word = span.words.len, .glyph = 0 }, word_range_width, blanks);
                    }
                }
            }
        }

        if (current.ranges.items.len == 0) {
            current.clear();
            try cached.append(alloc, current);
            current_owned = false;
        } else {
            try visual_lines.append(alloc, current);
            current_owned = false;
        }

        // Emit LayoutLines (shape.rs:2788-3064).
        const alignment: Align = align_opt orelse if (self.rtl) .right else .left;
        var line_width: f32 = 0;
        if (width_opt) |w| {
            line_width = w;
        } else {
            for (visual_lines.items) |*vl| line_width = @max(line_width, vl.w);
        }
        const start_x: f32 = if (self.rtl) line_width else 0;
        const n_vl = visual_lines.items.len;
        for (visual_lines.items, 0..) |*vl, index| {
            if (vl.ranges.items.len == 0) continue;
            const new_order = try self.reorder(alloc, vl.ranges.items);
            defer alloc.free(new_order);
            {
                var ll = try self.emitLine(alloc, &glyph_pool, .{
                    .vl = vl,
                    .index = index,
                    .n_vl = n_vl,
                    .new_order = new_order,
                    .font_size = font_size,
                    .line_width = line_width,
                    .start_x = start_x,
                    .alignment = alignment,
                    .match_mono_width = match_mono_width,
                    .hinting = hinting,
                });
                errdefer ll.deinit();
                try out.append(alloc, ll);
            }
        }

        // Empty lines still produce one line (shape.rs:3066-3076).
        if (out.items.len == 0) {
            try out.append(alloc, .{
                .w = 0,
                .max_ascent = 0,
                .max_descent = 0,
                .line_height_opt = if (self.metrics_opt) |m| m.line_height else null,
                .glyphs = .empty,
                .decorations = .empty,
                .allocator = alloc,
            });
        }
    }

    /// Emit one `LayoutLine` from a visual line (shape.rs:2801-3063): L2
    /// reorder walk, align correction, justification expansion, mono/hint
    /// rounding, ellipsis fixups, decoration spans. Pops a glyph vec from the
    /// pool; on error all owned memory is freed (never silently dropped).
    fn emitLine(
        self: *const ShapeLine,
        alloc: std.mem.Allocator,
        glyph_pool: *std.ArrayList(std.ArrayList(LayoutGlyph)),
        args: EmitLineArgs,
    ) ShapeError!LayoutLine {
        var glyphs: std.ArrayList(LayoutGlyph) = if (glyph_pool.pop()) |g| g else .empty;
        errdefer glyphs.deinit(alloc);
        glyphs.clearRetainingCapacity();
        var decorations: std.ArrayList(DecorationSpan) = .empty;
        errdefer decorations.deinit(alloc);

        const vl = args.vl;
        var x = args.start_x;
        var y: f32 = 0;
        var max_ascent: f32 = 0;
        var max_descent: f32 = 0;
        const correction: f32 = switch (args.alignment) {
            .left => if (self.rtl) @max(args.line_width - vl.w, 0) else 0,
            .right => if (self.rtl) 0 else @max(args.line_width - vl.w, 0),
            .center => @max(args.line_width - vl.w, 0) / 2.0,
            .end => @max(args.line_width - vl.w, 0),
            .justified => 0,
        };
        if (self.rtl) {
            x -= correction;
        } else {
            x += correction;
        }
        if (args.hinting == .enabled) x = @round(x);
        // Justification expansion applies to blank words only, never the last
        // line (shape.rs:2851-2859).
        const justification: f32 = if (args.alignment == .justified and vl.spaces > 0 and args.index != args.n_vl - 1)
            (args.line_width - vl.w) / @as(f32, @floatFromInt(vl.spaces))
        else
            0;
        var emit = EmitCtx{
            .line = self,
            .vl = vl,
            .font_size = args.font_size,
            .match_mono_width = args.match_mono_width,
            .hinting = args.hinting,
            .justification = justification,
            .x = &x,
            .y = &y,
            .max_ascent = &max_ascent,
            .max_descent = &max_descent,
            .glyphs = &glyphs,
            .decorations = &decorations,
            .alloc = alloc,
        };
        if (self.rtl) {
            var oi = args.new_order.len;
            while (oi > 0) {
                oi -= 1;
                try emit.processRange(args.new_order[oi]);
            }
        } else {
            for (args.new_order) |r| try emit.processRange(r);
        }
        var line_height_opt: ?f32 = null;
        for (glyphs.items) |*g| {
            if (g.line_height_opt) |gh| {
                line_height_opt = if (line_height_opt) |lh| @max(lh, gh) else gh;
            }
        }
        return .{
            .w = if (args.alignment != .justified) vl.w else if (self.rtl) args.start_x - x else x,
            .max_ascent = max_ascent,
            .max_descent = max_descent,
            .line_height_opt = line_height_opt,
            .glyphs = glyphs,
            .decorations = decorations,
            .allocator = alloc,
        };
    }
};

const EmitLineArgs = struct {
    vl: *VisualLine,
    index: usize,
    n_vl: usize,
    new_order: []const Range,
    font_size: f32,
    line_width: f32,
    start_x: f32,
    alignment: Align,
    match_mono_width: ?f32,
    hinting: Hinting,
};

const EllipsizeCtx = struct {
    line: *const ShapeLine,
    alloc: std.mem.Allocator,
    font_size: f32,
    width_opt: ?f32,
    ellipsize: Ellipsize,
    max_n_opt: ?usize,
    max_h_opt: ?f32,
    line_h: f32,

    /// `try_ellipsize_last_line` closure, verbatim from shape.rs:2370-2396:
    /// when the line cap (`Lines`, `max(1)`) or the height lookahead
    /// (`total + 2*lh > max`) trips, the remainder is laid out with ellipsis.
    fn tryLastLine(self: *EllipsizeCtx, vl: *VisualLine, start: ?SpanWordGlyphPos, n: *usize, total_h: *f32) ShapeError!bool {
        if (self.max_n_opt == n.* + 1) {
            try self.line.layoutLine(self.alloc, vl, self.line.spans, self.font_size, start, self.line.rtl, self.width_opt, self.ellipsize);
            return true;
        }
        if (self.max_h_opt) |max_h| {
            if (total_h.* + self.line_h * 2.0 > max_h) {
                try self.line.layoutLine(self.alloc, vl, self.line.spans, self.font_size, start, self.line.rtl, self.width_opt, self.ellipsize);
                return true;
            }
        }
        return false;
    }
};

const EmitCtx = struct {
    line: *const ShapeLine,
    vl: *VisualLine,
    font_size: f32,
    match_mono_width: ?f32,
    hinting: Hinting,
    justification: f32,
    x: *f32,
    y: *f32,
    max_ascent: *f32,
    max_descent: *f32,
    glyphs: *std.ArrayList(LayoutGlyph),
    decorations: *std.ArrayList(DecorationSpan),
    alloc: std.mem.Allocator,

    fn processRange(self: *EmitCtx, range: Range) ShapeError!void {
        // Verbatim glyph emission from shape.rs:2869-3011.
        for (self.vl.ranges.items[range.start..range.end]) |*r| {
            const is_ellipsis = r.span == ELLIPSIS_SPAN;
            const span_words = try self.line.getSpanWords(r.span);
            const deco_spans: []const DecoRange = if (is_ellipsis) &.{} else self.line.spans[r.span].decorations;
            var deco_cursor: usize = 0;
            const stop = r.end.word + @as(usize, if (r.end.glyph != 0) 1 else 0);
            var i = r.start.word;
            while (i < stop and i < span_words.len) : (i += 1) {
                const word = &span_words[i];
                const a = if (i == r.start.word) r.start.glyph else 0;
                const b = if (i == r.end.word) r.end.glyph else word.glyphs.len;
                const lo = @min(a, word.glyphs.len);
                const hi = @min(b, word.glyphs.len);
                if (hi <= lo and !(i == r.start.word and i == r.end.word and a == b)) {
                    if (hi < lo) continue;
                }
                for (word.glyphs[lo..hi]) |*glyph| {
                    const size = if (glyph.metrics_opt) |m| m.font_size else self.font_size;
                    const match_em = if (self.match_mono_width) |w| w / self.font_size else null;
                    var glyph_size = size;
                    if (match_em) |mem_w| {
                        if (glyph.mono_width) |gw| {
                            if (gw != mem_w) {
                                const factor = gw / mem_w;
                                glyph_size = @max(@round(factor), 1.0) / factor * self.font_size;
                            }
                        }
                    }
                    var x_adv = glyph_size * glyph.x_advance + if (word.blank) self.justification else 0;
                    if (match_em) |mem_w| {
                        if (mem_w > 0) x_adv = @round(x_adv / mem_w) * mem_w;
                    }
                    if (self.hinting == .enabled) x_adv = @round(x_adv);
                    if (self.line.rtl) self.x.* -= x_adv;
                    const y_adv = glyph_size * glyph.y_advance;
                    var lg = glyph.layout(
                        glyph_size,
                        if (glyph.metrics_opt) |m| m.line_height else null,
                        self.x.*,
                        self.y.*,
                        x_adv,
                        r.level,
                    );
                    // Ellipsis glyphs point at the elision boundary
                    // (shape.rs:2950-2969).
                    if (is_ellipsis) {
                        if (self.vl.elided_byte_range) |eb| {
                            const boundary = if (eb[0] == 0) eb[1] else eb[0];
                            lg.start = boundary;
                            lg.end = boundary;
                        }
                    }
                    try self.glyphs.append(self.alloc, lg);
                    if (deco_cursor >= deco_spans.len or glyph.start < deco_spans[deco_cursor].start) {
                        deco_cursor = 0;
                    }
                    while (deco_cursor < deco_spans.len and deco_spans[deco_cursor].end <= glyph.start) {
                        deco_cursor += 1;
                    }
                    const match_deco: ?*const DecoRange = if (deco_cursor < deco_spans.len and glyph.start >= deco_spans[deco_cursor].start)
                        &deco_spans[deco_cursor]
                    else
                        null;
                    const gi = self.glyphs.items.len - 1;
                    const extends = if (self.decorations.items.len > 0 and match_deco != null)
                        std.meta.eql(self.decorations.items[self.decorations.items.len - 1].data, match_deco.?.data)
                    else
                        false;
                    if (extends) {
                        self.decorations.items[self.decorations.items.len - 1].glyph_range.end = gi + 1;
                    } else if (match_deco) |md| {
                        try self.decorations.append(self.alloc, .{
                            .glyph_range = .{ .start = gi, .end = gi + 1 },
                            .data = md.data,
                            .color_opt = self.glyphs.items[gi].color_opt,
                            .font_size = self.glyphs.items[gi].font_size,
                        });
                    }
                    if (!self.line.rtl) self.x.* += x_adv;
                    self.y.* += y_adv;
                    self.max_ascent.* = @max(self.max_ascent.*, glyph_size * glyph.ascent);
                    self.max_descent.* = @max(self.max_descent.*, glyph_size * glyph.descent);
                }
            }
        }
    }
};

fn pushVisualLine(
    alloc: std.mem.Allocator,
    visual_lines: *std.ArrayList(VisualLine),
    cached: *std.ArrayList(VisualLine),
    current: *VisualLine,
) ShapeError!void {
    try visual_lines.append(alloc, current.*);
    current.* = if (cached.pop()) |vl| vl else .{};
}

// ---------------------------------------------------------------------------
// Small position/range types (shape.rs:1224-1302)
// ---------------------------------------------------------------------------

pub const WordGlyphPos = struct {
    word: usize = 0,
    glyph: usize = 0,

    pub const ZERO: WordGlyphPos = .{};
};

pub const SpanWordGlyphPos = struct {
    span: usize = 0,
    word: usize = 0,
    glyph: usize = 0,

    pub const ZERO: SpanWordGlyphPos = .{};

    pub fn wordGlyphPos(self: SpanWordGlyphPos) WordGlyphPos {
        return .{ .word = self.word, .glyph = self.glyph };
    }
};

pub const LayoutDirection = enum {
    forward,
    backward,
};

pub const VlRange = struct {
    span: usize = 0,
    start: WordGlyphPos = .{},
    end: WordGlyphPos = .{},
    level: Level = LEVEL_LTR,
};

pub const Range = struct {
    start: usize,
    end: usize,
};

const FitResult = struct {
    end: usize,
    w: f32,
};

// ===========================================================================
// Tests
// ===========================================================================

/// Canonical default `AttrsList` for tests (caller deinits).
fn testAttrsList(alloc: std.mem.Allocator) !AttrsList {
    var defaults = Attrs.init(alloc);
    defer defaults.deinit();
    return AttrsList.init(alloc, &defaults);
}

/// Minimal shaped glyph for layout tests.
fn testGlyph(start: usize, end: usize, x_advance: f32) ShapeGlyph {
    return .{
        .start = start,
        .end = end,
        .x_advance = x_advance,
        .y_advance = 0,
        .x_offset = 0,
        .y_offset = 0,
        .ascent = 1,
        .descent = 0,
        .font_id = 1,
        .font_weight = Weight.normal,
        .glyph_id = 1,
    };
}

test "Shaping + Direction basics" {
    try std.testing.expectEqual(@as(?Level, null), Direction.auto.bidiLevel());
    try std.testing.expectEqual(@as(?Level, LEVEL_LTR), Direction.left_to_right.bidiLevel());
    try std.testing.expectEqual(@as(?Level, LEVEL_RTL), Direction.right_to_left.bidiLevel());
    try std.testing.expect(levelIsRtl(LEVEL_RTL));
    try std.testing.expect(!levelIsRtl(LEVEL_LTR));
}

test "RTL line takes its paragraph level from unicode.zig" {
    var backend = CharmapAdapter{};
    var buf = ShapeBuffer.init();
    defer buf.deinit(std.testing.allocator);
    var line = ShapeLine{};
    defer line.deinit(std.testing.allocator);
    var attrs = try testAttrsList(std.testing.allocator);
    defer attrs.deinit();
    // Hebrew alef-bet: first-strong P2 paragraph level is RTL.
    try line.build(std.testing.allocator, backend.adapter(), &buf, "\u{05D0}\u{05D1}", &attrs, .advanced, 4, .auto);
    try std.testing.expect(line.rtl);
    try std.testing.expectEqual(@as(usize, 1), line.spans.len);
    try std.testing.expectEqual(@as(Level, 1), line.spans[0].level);
}

test "ShapeWord fast path issues a single run" {
    var backend = CharmapAdapter{};
    var buf = ShapeBuffer.init();
    defer buf.deinit(std.testing.allocator);
    var attrs = try testAttrsList(std.testing.allocator);
    defer attrs.deinit();
    const word = try buildWord(std.testing.allocator, backend.adapter(), &buf, "hello", &attrs, 0, 5, LEVEL_LTR, false, .advanced);
    defer {
        var w = word;
        w.deinitChildren(std.testing.allocator);
    }
    try std.testing.expect(!word.blank);
    try std.testing.expectEqual(@as(usize, 5), word.glyphs.len);
    try std.testing.expectEqual(@as(usize, 1), backend.runs_shaped);
    try std.testing.expectEqual(@as(usize, 0), word.glyphs[0].start);
    try std.testing.expectEqual(@as(usize, 4), word.glyphs[4].start);
    try std.testing.expectEqual(@as(usize, 5), word.glyphs[4].end);
}

test "ShapeWord slow path splits on incompatible attrs" {
    var backend = CharmapAdapter{};
    var buf = ShapeBuffer.init();
    defer buf.deinit(std.testing.allocator);
    var defaults = Attrs.init(std.testing.allocator);
    defer defaults.deinit();
    var bold = Attrs.init(std.testing.allocator);
    defer bold.deinit();
    bold.weight = Weight.bold;
    var attrs = try AttrsList.init(std.testing.allocator, &defaults);
    defer attrs.deinit();
    try attrs.add_span(2, 5, &bold);
    const word = try buildWord(std.testing.allocator, backend.adapter(), &buf, "hello", &attrs, 0, 5, LEVEL_LTR, false, .advanced);
    defer {
        var w = word;
        w.deinitChildren(std.testing.allocator);
    }
    try std.testing.expectEqual(@as(usize, 5), word.glyphs.len);
    try std.testing.expectEqual(@as(usize, 2), backend.runs_shaped);
    try std.testing.expectEqual(Weight.normal, word.glyphs[0].font_weight);
    try std.testing.expectEqual(Weight.bold, word.glyphs[2].font_weight);
}

test "Span split separates trailing blanks per char" {
    var backend = CharmapAdapter{};
    var attrs = try testAttrsList(std.testing.allocator);
    defer attrs.deinit();
    const splits = try splitSpanWords(std.testing.allocator, backend.adapter(), PRIMARY_FONT_ID, "日本語  ", 0, &attrs);
    defer std.testing.allocator.free(splits);
    // UAX#14 allows a break on both sides of ID (CJK) characters; trailing
    // blanks peel into separate one-character blank words.
    try std.testing.expectEqual(@as(usize, 5), splits.len);
    try std.testing.expect(!splits[0].blank);
    try std.testing.expect(!splits[1].blank);
    try std.testing.expect(!splits[2].blank);
    try std.testing.expect(splits[3].blank);
    try std.testing.expect(splits[4].blank);
    try std.testing.expectEqual(@as(usize, 1), splits[3].end - splits[3].start);
    try std.testing.expectEqual(@as(usize, 1), splits[4].end - splits[4].start);
    // Concatenation covers the input.
    try std.testing.expectEqual(@as(usize, 0), splits[0].start);
    try std.testing.expectEqual(@as(usize, 11), splits[4].end);
}

test "shape uses unicode.zig line breaks for CJK" {
    var backend = CharmapAdapter{};
    var attrs = try testAttrsList(std.testing.allocator);
    defer attrs.deinit();
    const text = "日本語テキスト";
    const splits = try splitSpanWords(std.testing.allocator, backend.adapter(), PRIMARY_FONT_ID, text, 0, &attrs);
    defer std.testing.allocator.free(splits);
    // UAX#14 ID/ID breaks: one word per character, never one whole word.
    try std.testing.expect(splits.len > 1);
    try std.testing.expectEqual(text.len, splits[splits.len - 1].end);
    for (splits) |s| {
        try std.testing.expect(s.end > s.start);
        try std.testing.expect(s.end - s.start < text.len);
    }
}

test "Punct ligature probe keeps pair together" {
    var backend = CharmapAdapter{ .ligature_probe_count = 2 };
    var attrs = try testAttrsList(std.testing.allocator);
    defer attrs.deinit();
    // No ligature: split allowed between '|' and '>'.
    const plain = try splitSpanWords(std.testing.allocator, backend.adapter(), PRIMARY_FONT_ID, "a|> b", 0, &attrs);
    defer std.testing.allocator.free(plain);
    try std.testing.expect(plain.len > 1);

    backend.ligature_probe_count = 1; // shaper merges the pair
    const joined = try splitSpanWords(std.testing.allocator, backend.adapter(), PRIMARY_FONT_ID, "a|> b", 0, &attrs);
    defer std.testing.allocator.free(joined);
    // The break inside "|>" is skipped: fewer words than the split version.
    try std.testing.expect(joined.len < plain.len);
    // Non-punctuation pairs never probe: UAX#14 CJK breaks stay put.
    const words = try splitSpanWords(std.testing.allocator, backend.adapter(), PRIMARY_FONT_ID, "日本", 0, &attrs);
    defer std.testing.allocator.free(words);
    try std.testing.expectEqual(@as(usize, 2), words.len);
}

test "RTL reversals mirror shape.rs" {
    var glyphs = [_]ShapeGlyph{ testGlyph(0, 1, 1), testGlyph(1, 2, 1) };
    glyphs[1].glyph_id = 2;
    var words = [_]ShapeWord{
        .{ .blank = false, .glyphs = glyphs[0..1] },
        .{ .blank = false, .glyphs = glyphs[1..2] },
    };
    // Matching directions: no change.
    applySpanReversals(&words, false, false);
    try std.testing.expectEqual(@as(usize, 0), words[0].glyphs[0].start);
    // Mismatched span: words reverse.
    applySpanReversals(&words, false, true);
    try std.testing.expectEqual(@as(usize, 1), words[0].glyphs[0].start);
    // RTL line: glyphs reverse back and words reverse again.
    applySpanReversals(&words, true, true);
    try std.testing.expectEqual(@as(usize, 1), words[0].glyphs[0].start);
}

test "adjustLevelsL1 resets trailing whitespace to para level" {
    const text = "a  ";
    var levels = [_]Level{ 1, 1, 1 };
    const classes = [_]BidiClass{ .on, .ws, .ws };
    adjustLevelsL1(&levels, &classes, text, LEVEL_LTR);
    try std.testing.expectEqual(@as(Level, 1), levels[0]);
    try std.testing.expectEqual(@as(Level, LEVEL_LTR), levels[1]);
    try std.testing.expectEqual(@as(Level, LEVEL_LTR), levels[2]);
}

test "reorderL2 reverses odd runs verbatim" {
    var line = ShapeLine{};
    const ranges = [_]VlRange{
        .{ .level = 0 },
        .{ .level = 1 },
        .{ .level = 1 },
        .{ .level = 0 },
    };
    const order = try line.reorder(std.testing.allocator, &ranges);
    defer std.testing.allocator.free(order);
    try std.testing.expectEqual(@as(usize, 4), order.len);
    try std.testing.expectEqual(@as(usize, 0), order[0].start);
    try std.testing.expectEqual(@as(usize, 2), order[1].start);
    try std.testing.expectEqual(@as(usize, 1), order[2].start);
    try std.testing.expectEqual(@as(usize, 3), order[3].start);
}

test "tab stops use floor like shape.rs" {
    var backend = CharmapAdapter{ .advance_em = 10 };
    var buf = ShapeBuffer.init();
    defer buf.deinit(std.testing.allocator);
    var line = ShapeLine{};
    defer line.deinit(std.testing.allocator);
    var attrs = try testAttrsList(std.testing.allocator);
    defer attrs.deinit();
    // 'a' (10px) then tab with tab_width=8 spaces of 10px => stop at 80.
    try line.build(std.testing.allocator, backend.adapter(), &buf, "a\tb", &attrs, .basic, 8, .left_to_right);
    var total: f32 = 0;
    var tab_adv: f32 = 0;
    for (line.spans) |*s| {
        for (s.words) |*w| {
            for (w.glyphs) |*g| {
                if (g.end - g.start == 1 and "a\tb"[g.start] == '\t') tab_adv = g.x_advance;
                total += g.x_advance;
            }
        }
    }
    try std.testing.expectEqual(@as(f32, 70), tab_adv);
    try std.testing.expectEqual(@as(f32, 90), total);
}

test "ellipsis levels follow N1/N2" {
    var line = ShapeLine{ .rtl = false };
    const l = VlRange{ .level = LEVEL_LTR };
    const r = VlRange{ .level = LEVEL_RTL };
    try std.testing.expectEqual(LEVEL_LTR, line.ellipsisLevelBetween(&l, &l));
    try std.testing.expectEqual(LEVEL_LTR, line.ellipsisLevelBetween(&l, null));
    try std.testing.expectEqual(LEVEL_RTL, line.ellipsisLevelBetween(null, &r));
    try std.testing.expectEqual(LEVEL_LTR, line.ellipsisLevelBetween(null, null));
    line.rtl = true;
    try std.testing.expectEqual(LEVEL_RTL, line.ellipsisLevelBetween(null, null));
    // Mismatched neighbours fall back to the line direction.
    line.rtl = false;
    try std.testing.expectEqual(LEVEL_LTR, line.ellipsisLevelBetween(&l, &r));
}

test "ellipsis Start prepends, End appends, Middle splits" {
    var backend = CharmapAdapter{ .advance_em = 1.0 };
    var buf = ShapeBuffer.init();
    defer buf.deinit(std.testing.allocator);
    var line = ShapeLine{};
    defer line.deinit(std.testing.allocator);
    var attrs = try testAttrsList(std.testing.allocator);
    defer attrs.deinit();
    try line.build(std.testing.allocator, backend.adapter(), &buf, "aaaa bbbb cccc", &attrs, .basic, 4, .left_to_right);

    var vl_end = VisualLine{};
    defer vl_end.deinit(std.testing.allocator);
    try line.layoutLine(std.testing.allocator, &vl_end, line.spans, 10, null, false, 25, .{ .end = .{ .lines = 1 } });
    try std.testing.expect(vl_end.ellipsized);
    try std.testing.expectEqual(ELLIPSIS_SPAN, vl_end.ranges.items[vl_end.ranges.items.len - 1].span);

    var vl_start = VisualLine{};
    defer vl_start.deinit(std.testing.allocator);
    try line.layoutLine(std.testing.allocator, &vl_start, line.spans, 10, null, false, 25, .{ .start = .{ .lines = 1 } });
    try std.testing.expect(vl_start.ellipsized);
    try std.testing.expectEqual(ELLIPSIS_SPAN, vl_start.ranges.items[0].span);

    var vl_mid = VisualLine{};
    defer vl_mid.deinit(std.testing.allocator);
    try line.layoutLine(std.testing.allocator, &vl_mid, line.spans, 10, null, false, 60, .{ .middle = .{ .lines = 1 } });
    try std.testing.expect(vl_mid.ellipsized);
    var found_ellipsis = false;
    for (vl_mid.ranges.items, 0..) |rr, i| {
        if (rr.span == ELLIPSIS_SPAN) {
            found_ellipsis = true;
            try std.testing.expect(i > 0);
            try std.testing.expect(i + 1 < vl_mid.ranges.items.len);
        }
    }
    try std.testing.expect(found_ellipsis);
    // Elided byte range covers the seam.
    const elided = try line.computeElidedByteRange(&vl_end, line.maxByteOffset());
    try std.testing.expect(elided != null);
    try std.testing.expect(elided.?[0] <= elided.?[1]);
}

test "wrap stability: unbounded width then relayout matches" {
    var backend = CharmapAdapter{ .advance_em = 10 };
    var buf = ShapeBuffer.init();
    defer buf.deinit(std.testing.allocator);
    var line = ShapeLine{};
    defer line.deinit(std.testing.allocator);
    var attrs = try testAttrsList(std.testing.allocator);
    defer attrs.deinit();
    try line.build(std.testing.allocator, backend.adapter(), &buf, "aaa bbb ccc ddd", &attrs, .basic, 4, .left_to_right);

    const full = try line.layout(std.testing.allocator, 10, null, .word, .left, null, .disabled);
    defer freeLayoutLines(std.testing.allocator, full);
    try std.testing.expectEqual(@as(usize, 1), full.len);
    const w = full[0].w;

    const relaid = try line.layout(std.testing.allocator, 10, w, .word, .left, null, .disabled);
    defer freeLayoutLines(std.testing.allocator, relaid);
    try std.testing.expectEqual(full.len, relaid.len);
    try std.testing.expectEqual(full[0].glyphs.items.len, relaid[0].glyphs.items.len);

    // Narrower width wraps into more lines covering the same glyphs.
    const narrow = try line.layout(std.testing.allocator, 10, 70, .word, .left, null, .disabled);
    defer freeLayoutLines(std.testing.allocator, narrow);
    try std.testing.expect(narrow.len > 1);
    var count: usize = 0;
    for (narrow) |*l| count += l.glyphs.items.len;
    // Trailing blanks are excluded from wrapped lines; every non-blank glyph stays.
    try std.testing.expect(count >= full[0].glyphs.items.len - narrow.len);
}

test "reusable ShapeBuffer does not leak cached visual lines" {
    const alloc = std.testing.allocator;
    var backend = CharmapAdapter{ .advance_em = 1 };
    var buf = ShapeBuffer.init();
    defer buf.deinit(alloc);
    var line = ShapeLine{};
    defer line.deinit(alloc);
    var attrs = try testAttrsList(alloc);
    defer attrs.deinit();
    try line.build(alloc, backend.adapter(), &buf, "one two three four five six seven eight", &attrs, .basic, 4, .left_to_right);

    var out: std.ArrayList(LayoutLine) = .empty;
    defer {
        for (out.items) |*l| l.deinit();
        out.deinit(alloc);
    }
    var i: usize = 0;
    while (i < 8) : (i += 1) {
        // Reusing the scratch buffer across layouts previously leaked
        // `VisualLine.ranges` because the cached pool was cleared without
        // deinit; `std.testing.allocator` fails this test on that leak.
        try line.layoutToBuffer(alloc, &buf, 10, 40, .word, .{ .none = {} }, null, &out, null, .disabled);
    }
    try std.testing.expect(out.items.len > 0);
}

test "empty line yields one empty LayoutLine" {
    var backend = CharmapAdapter{};
    var buf = ShapeBuffer.init();
    defer buf.deinit(std.testing.allocator);
    var line = ShapeLine{};
    defer line.deinit(std.testing.allocator);
    var defaults = Attrs.init(std.testing.allocator);
    defer defaults.deinit();
    _ = defaults.with_metrics(.{ .font_size = 12, .line_height = 15 });
    var attrs = try AttrsList.init(std.testing.allocator, &defaults);
    defer attrs.deinit();
    try line.build(std.testing.allocator, backend.adapter(), &buf, "", &attrs, .basic, 4, .left_to_right);
    const lines = try line.layout(std.testing.allocator, 12, null, .word, .left, null, .disabled);
    defer freeLayoutLines(std.testing.allocator, lines);
    try std.testing.expectEqual(@as(usize, 1), lines.len);
    try std.testing.expectEqual(@as(usize, 0), lines[0].glyphs.items.len);
    try std.testing.expectEqual(@as(?f32, 15), lines[0].line_height_opt);
}

test "run key skips defaults, clamps and relativizes" {
    var defaults = Attrs.init(std.testing.allocator);
    defer defaults.deinit();
    var plain = Attrs.init(std.testing.allocator);
    defer plain.deinit();
    var bold = Attrs.init(std.testing.allocator);
    defer bold.deinit();
    bold.weight = Weight.bold;
    var attrs = try AttrsList.init(std.testing.allocator, &defaults);
    defer attrs.deinit();
    try attrs.add_span(0, 2, &plain); // matches defaults: skipped
    try attrs.add_span(2, 100, &bold); // clamped to the run
    try attrs.add_span(50, 60, &bold); // outside: dropped
    var key = try buildRunKey(std.testing.allocator, "abcdef", &attrs, 1, 5);
    defer key.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("bcde", key.text);
    try std.testing.expectEqual(hashAttrs(&attrs.default_attrs), key.default_hash);
    try std.testing.expectEqual(@as(usize, 1), key.spans.len);
    try std.testing.expectEqual(@as(usize, 1), key.spans[0].start);
    try std.testing.expectEqual(@as(usize, 4), key.spans[0].end);
}

test "rebaseGlyphs round-trips cache store/hit offsets" {
    var glyphs = [_]ShapeGlyph{testGlyph(3, 4, 1)};
    try rebaseGlyphs(&glyphs, -3); // store: strip run position
    try std.testing.expectEqual(@as(usize, 0), glyphs[0].start);
    try rebaseGlyphs(&glyphs, 3); // hit: restore run position
    try std.testing.expectEqual(@as(usize, 3), glyphs[0].start);
    try std.testing.expectError(error.GlyphUnderflow, rebaseGlyphs(&glyphs, -4));
}

test "decorationMetrics fallbacks match shape.rs" {
    const m = decorationMetrics(null, null, 1000, 800);
    try std.testing.expectEqual(@as(f32, -0.125), m.underline.offset);
    try std.testing.expectEqual(@as(f32, 1.0 / 14.0), m.underline.thickness);
    try std.testing.expectEqual(@as(f32, 0.3), m.strikethrough.offset);
    try std.testing.expectEqual(@as(f32, 1.0 / 14.0), m.strikethrough.thickness);
    try std.testing.expectEqual(@as(f32, 0.8), m.ascent);
    const zero = decorationMetrics(null, null, 0, 800);
    try std.testing.expectEqual(@as(f32, 0), zero.ascent);
    const custom = decorationMetrics(.{ .offset = -100, .thickness = 50 }, .{ .offset = 200, .thickness = 40 }, 1000, 800);
    try std.testing.expectEqual(@as(f32, -0.1), custom.underline.offset);
    try std.testing.expectEqual(@as(f32, 0.05), custom.underline.thickness);
    try std.testing.expectEqual(@as(f32, 0.2), custom.strikethrough.offset);
}

test "overrideFakeItalic sets the flag only for synthetic italics" {
    const none: CacheKeyFlags = .{};
    const some: CacheKeyFlags = .{ .bits = 0b110 };
    try std.testing.expect(FLAG_FAKE_ITALIC.eql(overrideFakeItalic(none, false, .italic)));
    try std.testing.expect(FLAG_FAKE_ITALIC.eql(overrideFakeItalic(none, false, .oblique)));
    try std.testing.expect(none.eql(overrideFakeItalic(none, true, .italic)));
    try std.testing.expect(none.eql(overrideFakeItalic(none, false, .normal)));
    const merged = overrideFakeItalic(some, false, .italic);
    try std.testing.expectEqual(@as(u32, 0b110 | 1), merged.bits);
}

test "shapeSkipBasic repatches missing glyphs via Sans/Mono" {
    var backend = CharmapAdapter{
        .primary_missing = &[_]u21{'é'},
        .repatch_missing = &.{},
        .monospaced_primary = false,
    };
    var buf = ShapeBuffer.init();
    defer buf.deinit(std.testing.allocator);
    var defaults = Attrs.init(std.testing.allocator);
    defer defaults.deinit();
    // Explicit family name drives the Basic Sans/Mono repatch.
    defaults.family = .{ .name = "Test Family" };
    var attrs = try AttrsList.init(std.testing.allocator, &defaults);
    defer attrs.deinit();
    var glyphs: std.ArrayList(ShapeGlyph) = .empty;
    defer glyphs.deinit(std.testing.allocator);
    try shapeSkip(std.testing.allocator, backend.adapter(), &glyphs, "aé", &attrs, 0, 3);
    try std.testing.expectEqual(@as(usize, 2), glyphs.items.len);
    try std.testing.expect(glyphs.items[0].glyph_id != 0);
    // 'é' was missing in primary but rep patched from the Sans fallback.
    try std.testing.expect(glyphs.items[1].glyph_id != 0);
    try std.testing.expectEqual(SANS_FALLBACK_ID, glyphs.items[1].font_id);
}

test "adjustGlyphEnds LTR and RTL mirror shape.rs" {
    const mk = struct {
        fn g(start: usize) ShapeGlyph {
            return testGlyph(start, 99, 1);
        }
    };
    var ltr = [_]ShapeGlyph{ mk.g(0), mk.g(1), mk.g(1) };
    adjustGlyphEnds(&ltr, false);
    try std.testing.expectEqual(@as(usize, 1), ltr[0].end);
    try std.testing.expectEqual(@as(usize, 99), ltr[1].end);
    try std.testing.expectEqual(@as(usize, 99), ltr[2].end);
    var rtl = [_]ShapeGlyph{ mk.g(1), mk.g(1), mk.g(0) };
    adjustGlyphEnds(&rtl, true);
    try std.testing.expectEqual(@as(usize, 99), rtl[0].end);
    try std.testing.expectEqual(@as(usize, 99), rtl[1].end);
    try std.testing.expectEqual(@as(usize, 1), rtl[2].end);
}

test "collectScripts skips Common/Inherited/Latin/Unknown exactly" {
    var scripts: std.ArrayList(Script) = .empty;
    defer scripts.deinit(std.testing.allocator);
    // Latin, space, digit (Common), combining mark (Inherited) skipped; Han kept.
    try collectScripts(&scripts, std.testing.allocator, "Hi 1\xcc\x81\xe4\xb8\xad", 0, 9);
    try std.testing.expectEqual(@as(usize, 1), scripts.items.len);
    try std.testing.expectEqual(Script.han, scripts.items[0]);
    scripts.clearRetainingCapacity();
    try collectScripts(&scripts, std.testing.allocator, "plain", 0, 5);
    try std.testing.expectEqual(@as(usize, 0), scripts.items.len);
}

test "spliceFallback replaces exactly the missing range" {
    var backend = CharmapAdapter{
        .primary_missing = &[_]u21{'世'},
        .fallback_missing = &.{},
        .advance_em = 10,
    };
    var buf = ShapeBuffer.init();
    defer buf.deinit(std.testing.allocator);
    var attrs = try testAttrsList(std.testing.allocator);
    defer attrs.deinit();
    var glyphs: std.ArrayList(ShapeGlyph) = .empty;
    defer glyphs.deinit(std.testing.allocator);
    // 'a' shapes in primary, '世' falls back, 'b' shapes in primary.
    try shapeRun(std.testing.allocator, backend.adapter(), &buf, &glyphs, "a\xe4\xb8\x96b", &attrs, 0, 5, false);
    try std.testing.expectEqual(@as(usize, 3), glyphs.items.len);
    try std.testing.expectEqual(PRIMARY_FONT_ID, glyphs.items[0].font_id);
    try std.testing.expectEqual(FALLBACK_FONT_ID, glyphs.items[1].font_id);
    try std.testing.expect(glyphs.items[1].glyph_id != 0);
    try std.testing.expectEqual(PRIMARY_FONT_ID, glyphs.items[2].font_id);
}

test "shapeRun forwards the run's weight to the adapter before shaping" {
    var charmap = CharmapAdapter{};
    const Recorder = struct {
        var last_weight: u16 = 0;
        fn setWeight(ptr: *anyopaque, weight: u16) void {
            _ = ptr;
            last_weight = weight;
        }
    };
    // Copy the charmap vtable and intercept only `set_weight`, so the rest of
    // the run exercises the normal charmap path.
    var vt = charmap.adapter().vtable.*;
    vt.set_weight = Recorder.setWeight;
    const adapter = ShapeAdapter{ .ptr = &charmap, .vtable = &vt };

    var defaults = Attrs.init(std.testing.allocator);
    defer defaults.deinit();
    var bold = Attrs.init(std.testing.allocator);
    defer bold.deinit();
    bold.weight = Weight.bold;
    var attrs = try AttrsList.init(std.testing.allocator, &defaults);
    defer attrs.deinit();
    try attrs.add_span(0, 3, &bold);

    var buf = ShapeBuffer.init();
    defer buf.deinit(std.testing.allocator);
    var glyphs: std.ArrayList(ShapeGlyph) = .empty;
    defer glyphs.deinit(std.testing.allocator);
    try shapeRun(std.testing.allocator, adapter, &buf, &glyphs, "abc", &attrs, 0, 3, false);
    try std.testing.expectEqual(@as(u16, 700), Recorder.last_weight);
    try std.testing.expectEqual(@as(usize, 3), glyphs.items.len);
}

test "shapeRun retries the primary once when its first load fails" {
    var charmap = CharmapAdapter{};
    const Flaky = struct {
        var font_for_calls: usize = 0;
        var shape_calls: usize = 0;
        fn shapeRun(ptr: *anyopaque, alloc: std.mem.Allocator, font: FontId, text: []const u8, rtl: bool) ShapeError![]ShapedRunGlyph {
            shape_calls += 1;
            if (font == PRIMARY_FONT_ID) return error.FontUnavailable;
            return CharmapAdapter.charmapShapeRun(ptr, alloc, font, text, rtl);
        }
        fn fontFor(ptr: *anyopaque, query: FontQuery) ?FontId {
            _ = ptr;
            _ = query;
            font_for_calls += 1;
            // First resolution: the broken primary. Second (after the failure
            // was negatively cached): the healthy fallback.
            return if (font_for_calls == 1) PRIMARY_FONT_ID else FALLBACK_FONT_ID;
        }
    };
    Flaky.font_for_calls = 0;
    Flaky.shape_calls = 0;
    var vt = charmap.adapter().vtable.*;
    vt.shape_run = Flaky.shapeRun;
    vt.font_for = Flaky.fontFor;
    const adapter = ShapeAdapter{ .ptr = &charmap, .vtable = &vt };

    var buf = ShapeBuffer.init();
    defer buf.deinit(std.testing.allocator);
    var attrs = try testAttrsList(std.testing.allocator);
    defer attrs.deinit();
    var glyphs: std.ArrayList(ShapeGlyph) = .empty;
    defer glyphs.deinit(std.testing.allocator);
    try shapeRun(std.testing.allocator, adapter, &buf, &glyphs, "abc", &attrs, 0, 3, false);
    try std.testing.expectEqual(@as(usize, 3), glyphs.items.len);
    // One failed attempt plus one successful retry, exactly one re-resolve.
    try std.testing.expectEqual(@as(usize, 2), Flaky.font_for_calls);
    try std.testing.expectEqual(@as(usize, 2), Flaky.shape_calls);
    for (glyphs.items) |g| {
        try std.testing.expectEqual(FALLBACK_FONT_ID, g.font_id);
        try std.testing.expect(g.glyph_id != 0);
    }
}

test "shapeRun returns the primary error when no alternative exists" {
    var charmap = CharmapAdapter{};
    const NoAlt = struct {
        var shape_calls: usize = 0;
        fn shapeRun(ptr: *anyopaque, alloc: std.mem.Allocator, font: FontId, text: []const u8, rtl: bool) ShapeError![]ShapedRunGlyph {
            _ = ptr;
            _ = alloc;
            _ = font;
            _ = text;
            _ = rtl;
            shape_calls += 1;
            return error.FontUnavailable;
        }
        fn fontFor(ptr: *anyopaque, query: FontQuery) ?FontId {
            _ = ptr;
            _ = query;
            // The resolver keeps returning the same (failed) id: there is no
            // alternative, so the run must fail after exactly one attempt.
            return PRIMARY_FONT_ID;
        }
    };
    NoAlt.shape_calls = 0;
    var vt = charmap.adapter().vtable.*;
    vt.shape_run = NoAlt.shapeRun;
    vt.font_for = NoAlt.fontFor;
    const adapter = ShapeAdapter{ .ptr = &charmap, .vtable = &vt };

    var buf = ShapeBuffer.init();
    defer buf.deinit(std.testing.allocator);
    var attrs = try testAttrsList(std.testing.allocator);
    defer attrs.deinit();
    var glyphs: std.ArrayList(ShapeGlyph) = .empty;
    defer glyphs.deinit(std.testing.allocator);
    try std.testing.expectError(
        error.FontUnavailable,
        shapeRun(std.testing.allocator, adapter, &buf, &glyphs, "abc", &attrs, 0, 3, false),
    );
    try std.testing.expectEqual(@as(usize, 1), NoAlt.shape_calls);
    try std.testing.expectEqual(@as(usize, 0), glyphs.items.len);
}

test "shapeRun skips a FontUnavailable fallback and reaches the next" {
    var charmap = CharmapAdapter{ .primary_missing = &[_]u21{'世'} };
    const FlakyFallback = struct {
        var shape_calls: usize = 0;
        fn shapeRun(ptr: *anyopaque, alloc: std.mem.Allocator, font: FontId, text: []const u8, rtl: bool) ShapeError![]ShapedRunGlyph {
            shape_calls += 1;
            if (font == FALLBACK_FONT_ID) return error.FontUnavailable;
            return CharmapAdapter.charmapShapeRun(ptr, alloc, font, text, rtl);
        }
        fn fallbackFor(ptr: *anyopaque, query: FontQuery, script: Script, attempt: usize) ?FontId {
            _ = ptr;
            _ = query;
            _ = script;
            return switch (attempt) {
                0 => FALLBACK_FONT_ID,
                1 => SANS_FALLBACK_ID,
                else => null,
            };
        }
    };
    FlakyFallback.shape_calls = 0;
    var vt = charmap.adapter().vtable.*;
    vt.shape_run = FlakyFallback.shapeRun;
    vt.fallback_for = FlakyFallback.fallbackFor;
    const adapter = ShapeAdapter{ .ptr = &charmap, .vtable = &vt };

    var buf = ShapeBuffer.init();
    defer buf.deinit(std.testing.allocator);
    var attrs = try testAttrsList(std.testing.allocator);
    defer attrs.deinit();
    var glyphs: std.ArrayList(ShapeGlyph) = .empty;
    defer glyphs.deinit(std.testing.allocator);
    // 'a' shapes in the primary, '世' falls back, 'b' shapes in the primary.
    try shapeRun(std.testing.allocator, adapter, &buf, &glyphs, "a\xe4\xb8\x96b", &attrs, 0, 5, false);
    try std.testing.expectEqual(@as(usize, 3), glyphs.items.len);
    try std.testing.expectEqual(PRIMARY_FONT_ID, glyphs.items[0].font_id);
    // Fallback 0 (id 2) failed to load; fallback 1 (id 10) covered the glyph.
    try std.testing.expectEqual(SANS_FALLBACK_ID, glyphs.items[1].font_id);
    try std.testing.expect(glyphs.items[1].glyph_id != 0);
    try std.testing.expectEqual(PRIMARY_FONT_ID, glyphs.items[2].font_id);
}

test "note_fallback reports splice coverage per fallback attempt" {
    const alloc = std.testing.allocator;
    var charmap = CharmapAdapter{ .primary_missing = &[_]u21{ 'x', 'y' } };
    const NoteLog = struct {
        var calls: usize = 0;
        var covered_true: usize = 0;
        var last_font: FontId = 0;
        var last_covered: bool = false;
        fn note(_: *anyopaque, query: FontQuery, script: Script, font: FontId, covered: bool) void {
            _ = query;
            _ = script;
            calls += 1;
            last_font = font;
            last_covered = covered;
            if (covered) covered_true += 1;
        }
    };
    NoteLog.calls = 0;
    NoteLog.covered_true = 0;
    // Copy the charmap vtable and intercept only `note_fallback`, so the rest
    // of the run exercises the normal charmap path (including the no-op case,
    // covered by every other test that leaves the hook unset).
    var vt = charmap.adapter().vtable.*;
    vt.note_fallback = NoteLog.note;
    const adapter = ShapeAdapter{ .ptr = &charmap, .vtable = &vt };

    var buf = ShapeBuffer.init();
    defer buf.deinit(alloc);
    var attrs = try testAttrsList(alloc);
    defer attrs.deinit();
    var glyphs: std.ArrayList(ShapeGlyph) = .empty;
    defer glyphs.deinit(alloc);

    // Both codepoints are missing in the primary and covered by fallback id 2:
    // exactly one covering attempt is reported.
    try shapeRun(alloc, adapter, &buf, &glyphs, "xy", &attrs, 0, 2, false);
    try std.testing.expectEqual(@as(usize, 1), NoteLog.calls);
    try std.testing.expectEqual(@as(usize, 1), NoteLog.covered_true);
    try std.testing.expectEqual(FALLBACK_FONT_ID, NoteLog.last_font);
    try std.testing.expect(NoteLog.last_covered);
    for (glyphs.items) |g| try std.testing.expectEqual(FALLBACK_FONT_ID, g.font_id);

    // The fallback now misses the same codepoints too: the hook still fires
    // with covered=false before the scan exits, so a backend can trust a
    // later exhaustion as a full zero-coverage scan.
    charmap.fallback_missing = &[_]u21{ 'x', 'y' };
    NoteLog.calls = 0;
    NoteLog.covered_true = 0;
    glyphs.clearRetainingCapacity();
    try shapeRun(alloc, adapter, &buf, &glyphs, "xy", &attrs, 0, 2, false);
    try std.testing.expectEqual(@as(usize, 1), NoteLog.calls);
    try std.testing.expectEqual(@as(usize, 0), NoteLog.covered_true);
    try std.testing.expect(!NoteLog.last_covered);
    for (glyphs.items) |g| {
        try std.testing.expectEqual(PRIMARY_FONT_ID, g.font_id);
        try std.testing.expectEqual(@as(u16, 0), g.glyph_id);
    }
}

test "ellipsis falls back to dots when U+2026 is missing" {
    // Basic shaping has no fallback splicing, so a missing ellipsis in the
    // primary font triggers the "..." fallback (shape.rs:759-773). (With
    // Advanced shaping the fallback font would splice U+2026 instead.)
    var backend = CharmapAdapter{ .primary_missing = &[_]u21{0x2026} };
    var buf = ShapeBuffer.init();
    defer buf.deinit(std.testing.allocator);
    var defaults = Attrs.init(std.testing.allocator);
    defer defaults.deinit();
    var attrs = try AttrsList.init(std.testing.allocator, &defaults);
    defer attrs.deinit();
    const glyphs = try shapeEllipsis(std.testing.allocator, backend.adapter(), &buf, &attrs.default_attrs, .basic, false);
    defer std.testing.allocator.free(glyphs);
    try std.testing.expectEqual(@as(usize, 3), glyphs.len);
}

test "plan cache is FIFO with cap 6" {
    var cache = PlanCache{};
    for (0..6) |i| {
        const idx = cache.getOrPut(@intCast(i + 1), .latin, false);
        try std.testing.expectEqual(i, idx);
    }
    // Hit does not reorder (least-recently-added eviction, not LRU).
    try std.testing.expectEqual(@as(usize, 0), cache.getOrPut(1, .latin, false));
    _ = cache.getOrPut(7, .latin, false);
    try std.testing.expectEqual(@as(usize, 6), cache.len);
    try std.testing.expect(cache.find(1, .latin, false) == null);
    try std.testing.expect(cache.find(7, .latin, false) != null);
}

test "fitGlyphs and remainingContentExceeds units" {
    const mk = struct {
        fn g(w: f32) ShapeGlyph {
            return testGlyph(0, 1, w);
        }
    };
    const gs = [_]ShapeGlyph{ mk.g(0.5), mk.g(0.5), mk.g(0.5) };
    var word_storage = [_]ShapeWord{.{ .blank = false, .glyphs = @constCast(&gs) }};
    const word = &word_storage[0];
    const fit = ShapeLine.fitGlyphs(word, 10, .{}, 0, 0, true, 0, 10, true);
    // Two 5px glyphs fit in 10px.
    try std.testing.expectEqual(@as(usize, 2), fit.end);
    try std.testing.expectEqual(@as(f32, 10), fit.w);
    var span_storage = [_]ShapeSpan{.{ .level = LEVEL_LTR, .words = &word_storage }};
    // Remaining content after word 0 in a 1-word span: nothing exceeds.
    try std.testing.expect(!ShapeLine.remainingContentExceeds(&span_storage, 10, 0, 0, 1, 0, .forward, true, 0, 1, 0.1));
    // A second wide word makes the remainder exceed a tiny threshold.
    const gs2 = [_]ShapeGlyph{mk.g(2.0)};
    var words2 = [_]ShapeWord{ word_storage[0], .{ .blank = false, .glyphs = @constCast(&gs2) } };
    var spans2 = [_]ShapeSpan{.{ .level = LEVEL_LTR, .words = &words2 }};
    try std.testing.expect(ShapeLine.remainingContentExceeds(&spans2, 10, 0, 0, 2, 0, .forward, true, 0, 1, 1.0));
}

test "align and justify affect line widths" {
    var backend = CharmapAdapter{ .advance_em = 10 };
    var buf = ShapeBuffer.init();
    defer buf.deinit(std.testing.allocator);
    var line = ShapeLine{};
    defer line.deinit(std.testing.allocator);
    var attrs = try testAttrsList(std.testing.allocator);
    defer attrs.deinit();
    try line.build(std.testing.allocator, backend.adapter(), &buf, "aa bb", &attrs, .basic, 4, .left_to_right);
    const left = try line.layout(std.testing.allocator, 10, null, .word, .left, null, .disabled);
    defer freeLayoutLines(std.testing.allocator, left);
    const justified = try line.layout(std.testing.allocator, 10, null, .word, .justified, null, .disabled);
    defer freeLayoutLines(std.testing.allocator, justified);
    try std.testing.expectEqual(@as(usize, 1), left.len);
    try std.testing.expectEqual(@as(f32, 500), left[0].w);
    // Justified single line keeps natural width (last line is not stretched).
    try std.testing.expectEqual(left[0].w, justified[0].w);
}

test "mono match and hinting round advances" {
    var backend = CharmapAdapter{ .advance_em = 0.55, .monospaced_primary = true };
    var buf = ShapeBuffer.init();
    defer buf.deinit(std.testing.allocator);
    var line = ShapeLine{};
    defer line.deinit(std.testing.allocator);
    var attrs = try testAttrsList(std.testing.allocator);
    defer attrs.deinit();
    try line.build(std.testing.allocator, backend.adapter(), &buf, "ab", &attrs, .basic, 4, .left_to_right);
    const hinted = try line.layout(std.testing.allocator, 10, null, .none, .left, 10.0, .enabled);
    defer freeLayoutLines(std.testing.allocator, hinted);
    try std.testing.expectEqual(@as(usize, 1), hinted.len);
    // 5.5px advances round to monospace 10px under hinting.
    for (hinted[0].glyphs.items) |gg| {
        try std.testing.expectEqual(@as(f32, 10.0), gg.w);
    }
}
