//! Port of cosmic-text `layout.rs` (layout + render-adjacent types).
//!
//! Canonical owners live in `attrs.zig` / `glyph_cache.zig`; this module
//! re-exports them (`Color`, `Weight`, `CacheKeyFlags`, `UnderlineStyle`,
//! `TextDecoration`, `DecorationMetrics`, `GlyphDecorationData`) so existing
//! `layout.Color` etc. paths keep working.
//!
//! This module owns only the layout types per `types.zig`: `LayoutGlyph`,
//! `LayoutLine`, `PhysicalGlyph`, `DecorationSpan`, `GlyphRange`, `Wrap`,
//! `Align`, `Ellipsize`, `EllipsizeHeightLimit`, `Hinting`.
//!
//! `FontId` is a placeholder `u32` for now.
//! TODO(font): replace `FontId` with the real font-module ID type once ported.

const std = @import("std");
const attrs = @import("attrs.zig");
const glyph_cache = @import("glyph_cache.zig");

// Canonical re-exports (owners: `attrs.zig`, `glyph_cache.zig`).
pub const Color = attrs.Color;
pub const Weight = attrs.Weight;
pub const WEIGHT_NORMAL: Weight = Weight.normal;
pub const CacheKeyFlags = attrs.CacheKeyFlags;
pub const UnderlineStyle = attrs.UnderlineStyle;
pub const TextDecoration = attrs.TextDecoration;
pub const DecorationMetrics = attrs.DecorationMetrics;
pub const GlyphDecorationData = attrs.GlyphDecorationData;
pub const SubpixelBin = glyph_cache.SubpixelBin;

/// Placeholder font identifier.
/// TODO(font): replace with the real font-module ID type once ported.
pub const FontId = u32;

/// Unicode BiDi embedding level: even = left-to-right, odd = right-to-left.
/// See `bidi_para.zig` for the `Level` concept (`ltr() == 0`).
pub const Level = u8;
pub const LEVEL_LTR: Level = 0;

pub fn levelIsLtr(level: Level) bool {
    return level % 2 == 0;
}

/// A laid out glyph.
pub const LayoutGlyph = struct {
    /// Start index of cluster in original line.
    start: usize,
    /// End index of cluster in original line.
    end: usize,
    /// Font size of the glyph.
    font_size: f32,
    /// Font weight of the glyph.
    font_weight: Weight,
    /// Line height of the glyph, overrides buffer setting.
    line_height_opt: ?f32,
    /// Font id of the glyph (placeholder `u32`; see `FontId` TODO).
    font_id: FontId,
    /// Glyph id within the font.
    glyph_id: u16,
    /// X offset of hitbox.
    x: f32,
    /// Y offset of hitbox.
    y: f32,
    /// Width of hitbox.
    w: f32,
    /// Unicode BiDi embedding level; LTR when divisible by 2.
    level: Level,
    /// X offset in line (logical units; see `physical`).
    x_offset: f32,
    /// Y offset in line (logical units; see `physical`).
    y_offset: f32,
    /// Optional color override.
    color_opt: ?Color,
    /// Metadata from `Attrs`.
    metadata: usize,
    /// Cache key flags.
    cache_key_flags: CacheKeyFlags,

    /// Convert to integer `PhysicalGlyph` for rendering.
    ///
    /// Verbatim port of cosmic-text `LayoutGlyph::physical` (layout.rs:88-107):
    /// X is binned + offset via `CacheKey::new`, Y is truncated (hinted) before
    /// binning. `PhysicalGlyph.cache_key` is the real `glyph_cache.CacheKey`.
    pub fn physical(self: LayoutGlyph, offset_x: f32, offset_y: f32, scale: f32) PhysicalGlyph {
        const x_off = self.font_size * self.x_offset;
        const y_off = self.font_size * self.y_offset;
        const fx = @mulAdd(f32, self.x + x_off, scale, offset_x);
        // Hinting snap in Y axis, matching `math::truncf` in cosmic-text.
        const fy = @trunc(@mulAdd(f32, self.y - y_off, scale, offset_y));
        const result = glyph_cache.CacheKey.new(
            self.font_id,
            self.glyph_id,
            self.font_size * scale,
            .{ .x = fx, .y = fy },
            self.font_weight.value,
            .{ .bits = self.cache_key_flags.bits },
        );
        return .{ .cache_key = result.key, .x = result.x, .y = result.y };
    }
};

/// Range of glyph indices in `LayoutLine.glyphs` covered by a decoration span.
pub const GlyphRange = struct {
    start: usize,
    end: usize,
};

/// A span of consecutive glyphs sharing the same text decoration.
pub const DecorationSpan = struct {
    /// Range of glyph indices in `LayoutLine.glyphs` covered by this span.
    glyph_range: GlyphRange,
    /// The decoration config and metrics (canonical `attrs.GlyphDecorationData`).
    data: GlyphDecorationData,
    /// Fallback color from the first glyph's `color_opt`.
    color_opt: ?Color,
    /// Font size from the first glyph (used to scale EM-unit metrics).
    font_size: f32,
};

/// A glyph with integer offsets and a real glyph-cache key, ready for rendering.
pub const PhysicalGlyph = struct {
    cache_key: glyph_cache.CacheKey,
    /// Integer component of X offset in line.
    x: i32,
    /// Integer component of Y offset in line.
    y: i32,
};

/// A line of laid out glyphs.
pub const LayoutLine = struct {
    /// Width of the line.
    w: f32,
    /// Maximum ascent of the glyphs in line.
    max_ascent: f32,
    /// Maximum descent of the glyphs in line.
    max_descent: f32,
    /// Maximum line height of any spans in line.
    line_height_opt: ?f32,
    /// Glyphs in line.
    glyphs: std.ArrayList(LayoutGlyph),
    /// Text decoration spans covering ranges of glyphs.
    decorations: std.ArrayList(DecorationSpan),

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) LayoutLine {
        return .{
            .w = 0,
            .max_ascent = 0,
            .max_descent = 0,
            .line_height_opt = null,
            .glyphs = .empty,
            .decorations = .empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *LayoutLine) void {
        self.glyphs.deinit(self.allocator);
        self.decorations.deinit(self.allocator);
    }
};

/// Wrapping mode.
pub const Wrap = enum {
    none,
    glyph,
    word,
    word_or_glyph,

    pub fn toString(self: Wrap) []const u8 {
        return switch (self) {
            .none => "No Wrap",
            .word => "Word Wrap",
            .word_or_glyph => "Word Wrap or Character",
            .glyph => "Character",
        };
    }
};

/// Align or justify.
pub const Align = enum {
    left,
    right,
    center,
    justified,
    end,

    pub fn toString(self: Align) []const u8 {
        return switch (self) {
            .left => "Left",
            .right => "Right",
            .center => "Center",
            .justified => "Justified",
            .end => "End",
        };
    }
};

/// Height limit selecting the last visual line to ellipsize.
pub const EllipsizeHeightLimit = union(enum) {
    /// Number of lines to show before ellipsizing. Ignored (treated as
    /// `Lines(1)`) when `Wrap` is `None`.
    lines: usize,
    /// Ellipsize the last line that fits within the height limit. Behaves as
    /// `Lines(1)` when `Wrap` is `None`.
    height: f32,

    /// `Lines(0)` behaves as `Lines(1)` (shape.rs:2354-2359).
    pub fn maxLines(self: EllipsizeHeightLimit) usize {
        return switch (self) {
            .lines => |n| @max(n, 1),
            .height => 1,
        };
    }
};

/// Ellipsize mode. Default is `none`.
pub const Ellipsize = union(enum) {
    /// No ellipsizing.
    none: void,
    /// Ellipsize the start of the last fitting visual line.
    start: EllipsizeHeightLimit,
    /// Ellipsize the middle of the last fitting visual line.
    middle: EllipsizeHeightLimit,
    /// Ellipsize the end of the last fitting visual line.
    end: EllipsizeHeightLimit,

    pub const default: Ellipsize = .{ .none = {} };
};

/// Metrics hinting strategy. Default is `disabled`.
pub const Hinting = enum {
    /// No metrics hinting; glyphs keep subpixel coordinates.
    disabled,
    /// Snap glyphs to integral X coordinates during layout.
    enabled,

    pub const default: Hinting = .disabled;
};

test "Wrap display strings match cosmic-text" {
    try std.testing.expectEqualStrings("No Wrap", Wrap.none.toString());
    try std.testing.expectEqualStrings("Character", Wrap.glyph.toString());
    try std.testing.expectEqualStrings("Word Wrap", Wrap.word.toString());
    try std.testing.expectEqualStrings("Word Wrap or Character", Wrap.word_or_glyph.toString());
}

test "Align display strings match cosmic-text" {
    try std.testing.expectEqualStrings("Left", Align.left.toString());
    try std.testing.expectEqualStrings("Right", Align.right.toString());
    try std.testing.expectEqualStrings("Center", Align.center.toString());
    try std.testing.expectEqualStrings("Justified", Align.justified.toString());
    try std.testing.expectEqualStrings("End", Align.end.toString());
}

test "Ellipsize defaults to none" {
    const e: Ellipsize = Ellipsize.default;
    try std.testing.expect(e == .none);
    try std.testing.expect(Ellipsize.default == .none);
}

test "EllipsizeHeightLimit lines clamp to at least one" {
    const zero: EllipsizeHeightLimit = .{ .lines = 0 };
    const three: EllipsizeHeightLimit = .{ .lines = 3 };
    const height: EllipsizeHeightLimit = .{ .height = 20 };
    try std.testing.expectEqual(@as(usize, 1), zero.maxLines());
    try std.testing.expectEqual(@as(usize, 3), three.maxLines());
    try std.testing.expectEqual(@as(usize, 1), height.maxLines());
}

test "Hinting defaults to disabled" {
    try std.testing.expect(Hinting.default == .disabled);
}

test "LayoutLine defaults" {
    var line = LayoutLine.init(std.testing.allocator);
    defer line.deinit();
    try std.testing.expectEqual(@as(f32, 0), line.w);
    try std.testing.expectEqual(@as(f32, 0), line.max_ascent);
    try std.testing.expectEqual(@as(f32, 0), line.max_descent);
    try std.testing.expect(line.line_height_opt == null);
    try std.testing.expectEqual(@as(usize, 0), line.glyphs.items.len);
    try std.testing.expectEqual(@as(usize, 0), line.decorations.items.len);
}

test "LayoutGlyph.physical truncates Y like CacheKey::new positions" {
    const g = LayoutGlyph{
        .start = 0,
        .end = 1,
        .font_size = 16,
        .font_weight = WEIGHT_NORMAL,
        .line_height_opt = null,
        .font_id = 0,
        .glyph_id = 0,
        .x = 10.7,
        .y = 20.9,
        .w = 5,
        .level = LEVEL_LTR,
        .x_offset = 0,
        .y_offset = 0,
        .color_opt = null,
        .metadata = 0,
        .cache_key_flags = .{},
    };
    const p = g.physical(0, 0, 1);
    try std.testing.expectEqual(@as(i32, 10), p.x);
    try std.testing.expectEqual(@as(i32, 20), p.y);
    // Y is truncated before binning: 20.9 -> 20.0 -> bin zero.
    try std.testing.expectEqual(SubpixelBin.zero, p.cache_key.y_bin);
    // X bin carries the fractional part: 10.7 -> bin three at int 10.
    try std.testing.expectEqual(SubpixelBin.three, p.cache_key.x_bin);
    try std.testing.expectEqual(@as(u16, 0), p.cache_key.glyph_id);
}

test "LayoutGlyph.physical matches glyph_cache.CacheKey.new for 3 samples" {
    const cases = [_]LayoutGlyph{
        .{
            .start = 0,
            .end = 1,
            .font_size = 16,
            .font_weight = WEIGHT_NORMAL,
            .line_height_opt = null,
            .font_id = 7,
            .glyph_id = 42,
            .x = 10.9,
            .y = 20.9,
            .w = 5,
            .level = LEVEL_LTR,
            .x_offset = 0,
            .y_offset = 0,
            .color_opt = null,
            .metadata = 0,
            .cache_key_flags = .{ .bits = 1 },
        },
        .{
            .start = 2,
            .end = 5,
            .font_size = 12.5,
            .font_weight = Weight.bold,
            .line_height_opt = 18,
            .font_id = 3,
            .glyph_id = 0,
            .x = -3.3,
            .y = 7.7,
            .w = 9.25,
            .level = LEVEL_LTR,
            .x_offset = -0.1,
            .y_offset = 0.1,
            .color_opt = Color.rgb(1, 2, 3),
            .metadata = 9,
            .cache_key_flags = .{ .bits = 6 },
        },
        .{
            .start = 0,
            .end = 3,
            .font_size = 24,
            .font_weight = Weight.light,
            .line_height_opt = null,
            .font_id = 1,
            .glyph_id = 0xFFFF,
            .x = 100.25,
            .y = -0.5,
            .w = 2.5,
            .level = LEVEL_LTR,
            .x_offset = 0.5,
            .y_offset = -0.25,
            .color_opt = null,
            .metadata = 0,
            .cache_key_flags = .{},
        },
    };
    const offsets = [_]struct { x: f32, y: f32, scale: f32 }{
        .{ .x = 0, .y = 0, .scale = 1 },
        .{ .x = 1.25, .y = -2.5, .scale = 2 },
        .{ .x = 0.5, .y = 0.5, .scale = 1.5 },
    };
    for (cases, offsets) |g, off| {
        const p = g.physical(off.x, off.y, off.scale);
        const x_off = g.font_size * g.x_offset;
        const y_off = g.font_size * g.y_offset;
        const ref = glyph_cache.CacheKey.new(
            g.font_id,
            g.glyph_id,
            g.font_size * off.scale,
            .{
                .x = @mulAdd(f32, g.x + x_off, off.scale, off.x),
                .y = @trunc(@mulAdd(f32, g.y - y_off, off.scale, off.y)),
            },
            g.font_weight.value,
            .{ .bits = g.cache_key_flags.bits },
        );
        try std.testing.expect(glyph_cache.CacheKey.eql(ref.key, p.cache_key));
        try std.testing.expectEqual(ref.x, p.x);
        try std.testing.expectEqual(ref.y, p.y);
    }
}

test "LayoutGlyph.physical carries subpixel X into the cache key" {
    // 10.9 -> fract >= .875 carries to integer 11 with bin zero;
    // 20.9 -> Y trunc 20 with bin zero (Y is hinted before binning).
    const g = LayoutGlyph{
        .start = 0,
        .end = 1,
        .font_size = 16,
        .font_weight = WEIGHT_NORMAL,
        .line_height_opt = null,
        .font_id = 7,
        .glyph_id = 42,
        .x = 10.9,
        .y = 20.9,
        .w = 5,
        .level = LEVEL_LTR,
        .x_offset = 0,
        .y_offset = 0,
        .color_opt = null,
        .metadata = 0,
        .cache_key_flags = .{},
    };
    const p = g.physical(0, 0, 1);
    try std.testing.expectEqual(@as(i32, 11), p.x);
    try std.testing.expectEqual(@as(i32, 20), p.y);
    try std.testing.expectEqual(SubpixelBin.zero, p.cache_key.x_bin);
    try std.testing.expectEqual(SubpixelBin.zero, p.cache_key.y_bin);
    try std.testing.expectEqual(@as(u16, 42), p.cache_key.glyph_id);
}
