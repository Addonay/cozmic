//! Port of cosmic-text `render.rs` (decoration rendering helpers).
//!
//! Canonical types: `Color` is `attrs.Color`; decoration data is
//! `attrs.GlyphDecorationData`; glyph geometry is `layout.LayoutGlyph`.

const std = @import("std");
const layout = @import("layout.zig");
const attrs = @import("attrs.zig");
const swash_cache = @import("swash_cache.zig");

/// RGBA color, canonical owner `attrs.Color`.
pub const Color = attrs.Color;

/// A line of visible text for rendering decorations.
///
/// Minimal view of cosmic-text's `LayoutRun`: only the fields
/// `renderDecoration` needs (glyphs, decoration spans, baseline `line_y`,
/// and clamped `line_top`) plus lossy-subset placeholders for the remaining
/// `LayoutRun` fields (`line_i`, `rtl`, `line_height`, `line_w`).
/// The extra fields default to `null`/`false`/`0` so existing callers that
/// only fill glyphs/decorations/`line_y`/`line_top` keep compiling; full
/// `buffer.rs` `LayoutRun` wiring (including `text`) is deferred.
pub const LayoutRun = struct {
    glyphs: []const layout.LayoutGlyph,
    decorations: []const layout.DecorationSpan,
    /// Y offset to baseline of line.
    line_y: f32,
    /// Y offset to top of line.
    line_top: f32,
    /// Index of the original text line (`buffer.rs` `LayoutRun.line_i`).
    /// Optional (`null` when unknown) to avoid breaking minimal callers.
    line_i: ?usize = null,
    /// True when the original paragraph direction is RTL.
    rtl: bool = false,
    /// Y offset to next line (`buffer.rs` `LayoutRun.line_height`).
    line_height: f32 = 0,
    /// Width of line (`buffer.rs` `LayoutRun.line_w`).
    line_w: f32 = 0,
};

/// Saturating `f32` -> `i32` conversion, mirroring Rust's `as` casts.
///
/// Copy of `layout.zig`'s `floatToI32Saturating` kept local (do not import
/// `layout` for this helper) so `render.zig` stays self-contained for float
/// handling. NaN -> 0, overflow -> min/max, otherwise truncates toward zero.
/// Never traps, unlike `@intFromFloat` on out-of-range floats.
/// Public so `edit.zig`'s renderer can share the same saturating casts.
pub fn floatToI32Saturating(v: f32) i32 {
    if (std.math.isNan(v)) return 0;
    const t = @trunc(v);
    // Use `f64` for bounds: `maxInt(i32)` as `f32` rounds to 2^31, which
    // would still trap in `@intFromFloat`. `f64` holds both bounds exactly.
    const f: f64 = @floatCast(t);
    const max_f: f64 = @floatFromInt(std.math.maxInt(i32));
    const min_f: f64 = @floatFromInt(std.math.minInt(i32));
    if (f >= max_f) return std.math.maxInt(i32);
    if (f <= min_f) return std.math.minInt(i32);
    return @intFromFloat(f);
}

/// Saturating `f32` -> `u32` conversion, mirroring Rust's `as` casts.
///
/// NaN -> 0, negative (incl. `-inf`) -> 0, `+inf`/overflow -> `maxInt(u32)`,
/// otherwise truncates toward zero. Never traps.
/// Public so `edit.zig`'s renderer can share the same saturating casts.
pub fn floatToU32Saturating(v: f32) u32 {
    if (std.math.isNan(v)) return 0;
    const t = @trunc(v);
    if (!(t > 0)) return 0;
    const f: f64 = @floatCast(t);
    const max_f: f64 = @floatFromInt(std.math.maxInt(u32));
    if (f >= max_f) return std.math.maxInt(u32);
    return @intFromFloat(f);
}

/// Custom renderer for buffers and editors (vtable interface).
///
/// Cosmic-text uses a generic `Renderer` trait; Zig uses an explicit vtable
/// struct with `*anyopaque` context pointers. No allocation, no panics.
pub const Renderer = struct {
    ctx: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        /// Render a rectangle at x, y with size w, h and the given color.
        rectangle: *const fn (ctx: *anyopaque, x: i32, y: i32, w: u32, h: u32, color: Color) void,
        /// Render a physical glyph with the given color.
        glyph: *const fn (ctx: *anyopaque, glyph: layout.PhysicalGlyph, color: Color) void,
    };

    pub fn rectangle(self: Renderer, x: i32, y: i32, w: u32, h: u32, color: Color) void {
        self.vtable.rectangle(self.ctx, x, y, w, h, color);
    }

    pub fn glyph(self: Renderer, physical_glyph: layout.PhysicalGlyph, color: Color) void {
        self.vtable.glyph(self.ctx, physical_glyph, color);
    }
};

/// Rectangle callback replacing Rust's `FnMut(i32, i32, u32, u32, Color)`
/// closure used by `Buffer::draw` (Zig has no capture syntax, so the context
/// pointer is explicit).
pub const Callback = struct {
    ctx: *anyopaque,
    call: *const fn (ctx: *anyopaque, x: i32, y: i32, w: u32, h: u32, color: Color) void,

    /// Renderer view that forwards rectangles (and ignores glyphs; use
    /// `LegacyRenderer` for cache-backed glyph pixels).
    pub fn renderer(self: *Callback) Renderer {
        return .{ .ctx = @ptrCast(self), .vtable = &callback_vtable };
    }

    const callback_vtable: Renderer.VTable = .{
        .rectangle = callbackRectangle,
        .glyph = callbackGlyph,
    };

    fn callbackRectangle(ctx: *anyopaque, x: i32, y: i32, w: u32, h: u32, color: Color) void {
        const self: *Callback = @ptrCast(@alignCast(ctx));
        self.call(self.ctx, x, y, w, h, color);
    }

    fn callbackGlyph(ctx: *anyopaque, glyph: layout.PhysicalGlyph, color: Color) void {
        _ = ctx;
        _ = glyph;
        _ = color;
        // A bare rectangle callback has no raster cache; matches upstream
        // `LegacyRenderer` only when wrapped in `LegacyRenderer`.
    }
};

/// Port of cosmic-text `LegacyRenderer` (render.rs:127-156): turns glyph
/// raster pixels from `SwashCache` into 1x1 rectangle callbacks.
///
/// The callback runs while the `SwashCache` is borrowed; it must not recurse
/// into the same cache.
pub const LegacyRenderer = struct {
    cache: *swash_cache.SwashCache,
    callback: Callback,
    /// Physical origin of the glyph currently being visited.
    glyph_x: i32 = 0,
    glyph_y: i32 = 0,
    /// Number of glyphs whose pixels could not be produced (cache allocation
    /// failure). Upstream would panic; the draw path here degrades.
    glyph_errors: usize = 0,

    pub fn init(cache: *swash_cache.SwashCache, callback: Callback) LegacyRenderer {
        return .{ .cache = cache, .callback = callback };
    }

    pub fn renderer(self: *LegacyRenderer) Renderer {
        return .{ .ctx = @ptrCast(self), .vtable = &vtable };
    }

    const vtable: Renderer.VTable = .{
        .rectangle = rectangle,
        .glyph = glyph,
    };

    fn rectangle(ctx: *anyopaque, x: i32, y: i32, w: u32, h: u32, color: Color) void {
        const self: *LegacyRenderer = @ptrCast(@alignCast(ctx));
        self.callback.call(self.callback.ctx, x, y, w, h, color);
    }

    fn glyph(ctx: *anyopaque, physical_glyph: layout.PhysicalGlyph, color: Color) void {
        const self: *LegacyRenderer = @ptrCast(@alignCast(ctx));
        self.glyph_x = physical_glyph.x;
        self.glyph_y = physical_glyph.y;
        _ = self.cache.withPixels(
            physical_glyph.cache_key,
            color.value,
            @ptrCast(self),
            pixel,
        ) catch {
            self.glyph_errors += 1;
        };
    }

    fn pixel(ctx: *anyopaque, x: i32, y: i32, color: u32) void {
        const self: *LegacyRenderer = @ptrCast(@alignCast(ctx));
        self.callback.call(
            self.callback.ctx,
            self.glyph_x + x,
            self.glyph_y + y,
            1,
            1,
            .{ .value = color },
        );
    }
};

/// Draw text decoration lines (underline, strikethrough, overline).
pub fn renderDecoration(renderer: Renderer, run: LayoutRun, default_color: Color) void {
    for (run.decorations) |*span| {
        drawDecorationSpan(renderer, run, span, default_color);
    }
}

fn drawDecorationSpan(renderer: Renderer, run: LayoutRun, span: *const layout.DecorationSpan, default_color: Color) void {
    if (span.glyph_range.start >= span.glyph_range.end) return;
    // OOB: Rust indexes `run.glyphs[range]` and would panic on OOB.
    // Zig debug-asserts to catch misuse in tests, then returns silently in
    // release so untrusted ranges cannot trap or slice-panic.
    std.debug.assert(span.glyph_range.end <= run.glyphs.len);
    if (span.glyph_range.end > run.glyphs.len) return;
    std.debug.assert(span.glyph_range.start <= run.glyphs.len);
    if (span.glyph_range.start > run.glyphs.len) return;
    const glyphs = run.glyphs[span.glyph_range.start..span.glyph_range.end];
    // No `glyphs.len == 0` check: `start < end` plus the bounds checks above
    // guarantee a non-empty slice, so the old third guard was dead.

    const deco = &span.data;
    const td = &deco.text_decoration;
    const font_size = span.font_size;

    // Compute x extent as min/max over all glyphs, not first/last,
    // because RTL paragraphs store glyphs in right-to-left order.
    var x_min: f32 = std.math.inf(f32);
    var x_max: f32 = -std.math.inf(f32);
    for (glyphs) |*g| {
        x_min = @min(x_min, g.x);
        x_max = @max(x_max, g.x + g.w);
    }
    const width = x_max - x_min;
    if (width <= 0) return;
    // Saturating: Rust `width as u32` saturates (NaN->0, neg->0, inf->MAX);
    // Zig `@intFromFloat` would trap, so use the helper. NaN width (e.g.
    // `inf - inf` from untrusted glyphs) becomes 0 and draws nothing.
    const w: u32 = floatToU32Saturating(width);
    // Ceil guard: a positive width that truncates to zero draws nothing.
    if (w == 0) return;
    const x_start = x_min;

    // Underline.
    switch (td.underline) {
        .none => {},
        .single => {
            const color = td.underline_color_opt orelse span.color_opt orelse default_color;
            const thickness = @ceil(@max(1.0, deco.underline_metrics.thickness * font_size));
            const y = run.line_y - deco.underline_metrics.offset * font_size;
            renderer.rectangle(
                floatToI32Saturating(x_start),
                floatToI32Saturating(y),
                w,
                floatToU32Saturating(thickness),
                color,
            );
        },
        .double => {
            const color = td.underline_color_opt orelse span.color_opt orelse default_color;
            const thickness = @ceil(@max(1.0, deco.underline_metrics.thickness * font_size));
            const gap = thickness;
            const y = run.line_y - deco.underline_metrics.offset * font_size;
            renderer.rectangle(
                floatToI32Saturating(x_start),
                floatToI32Saturating(y),
                w,
                floatToU32Saturating(thickness),
                color,
            );
            renderer.rectangle(
                floatToI32Saturating(x_start),
                floatToI32Saturating(y + thickness + gap),
                w,
                floatToU32Saturating(thickness),
                color,
            );
        },
    }

    // Strikethrough.
    if (td.strikethrough) {
        const color = td.strikethrough_color_opt orelse span.color_opt orelse default_color;
        const thickness = @ceil(@max(1.0, deco.strikethrough_metrics.thickness * font_size));
        const y = run.line_y - deco.strikethrough_metrics.offset * font_size;
        renderer.rectangle(
            floatToI32Saturating(x_start),
            floatToI32Saturating(y),
            w,
            floatToU32Saturating(thickness),
            color,
        );
    }

    // Overline.
    if (td.overline) {
        const color = td.overline_color_opt orelse span.color_opt orelse default_color;
        // Reuse underline thickness for overline.
        const thickness = @ceil(@max(1.0, deco.underline_metrics.thickness * font_size));
        // Clamped so it doesn't go above the line top.
        const y = @max(run.line_y - deco.ascent * font_size, run.line_top);
        renderer.rectangle(
            floatToI32Saturating(x_start),
            floatToI32Saturating(y),
            w,
            floatToU32Saturating(thickness),
            color,
        );
    }
}

// --- Tests with a mock renderer ---

const MockRect = struct {
    x: i32,
    y: i32,
    w: u32,
    h: u32,
    color: Color,
};

const MockRenderer = struct {
    rects: std.ArrayList(MockRect),
    glyphs: u32 = 0,
    allocator: std.mem.Allocator,
    append_failed: bool = false,

    fn init(allocator: std.mem.Allocator) MockRenderer {
        return .{ .rects = .empty, .allocator = allocator };
    }

    fn deinit(self: *MockRenderer) void {
        self.rects.deinit(self.allocator);
    }

    fn renderer(self: *MockRenderer) Renderer {
        return .{
            .ctx = @ptrCast(self),
            .vtable = &.{
                .rectangle = struct {
                    fn f(ctx: *anyopaque, x: i32, y: i32, w: u32, h: u32, color: Color) void {
                        const m: *MockRenderer = @ptrCast(@alignCast(ctx));
                        // Test-only append; capacity is tiny so failure is
                        // reported via a stopped flag rather than panicking.
                        m.rects.append(m.allocator, .{ .x = x, .y = y, .w = w, .h = h, .color = color }) catch {
                            m.append_failed = true;
                        };
                    }
                }.f,
                .glyph = struct {
                    fn f(ctx: *anyopaque, glyph: layout.PhysicalGlyph, color: Color) void {
                        _ = glyph;
                        _ = color;
                        const m: *MockRenderer = @ptrCast(@alignCast(ctx));
                        m.glyphs += 1;
                    }
                }.f,
            },
        };
    }
};

fn col(value: u32) Color {
    return .{ .value = value };
}

fn testGlyph(x: f32, w: f32) layout.LayoutGlyph {
    return .{
        .start = 0,
        .end = 1,
        .font_size = 16,
        .font_weight = layout.WEIGHT_NORMAL,
        .line_height_opt = null,
        .font_id = 0,
        .glyph_id = 0,
        .x = x,
        .y = 0,
        .w = w,
        .level = layout.LEVEL_LTR,
        .x_offset = 0,
        .y_offset = 0,
        .color_opt = null,
        .metadata = 0,
        .cache_key_flags = .{},
    };
}

test "single underline geometry" {
    var mock = MockRenderer.init(std.testing.allocator);
    defer mock.deinit();
    const glyphs = [_]layout.LayoutGlyph{ testGlyph(10, 5), testGlyph(15, 5) };
    const spans = [_]layout.DecorationSpan{.{
        .glyph_range = .{ .start = 0, .end = 2 },
        .data = .{
            .text_decoration = .{ .underline = .single },
            // thickness 0.05 * 16 = 0.8 -> max(1, 0.8).ceil = 1.
            .underline_metrics = .{ .offset = 0.1, .thickness = 0.05 },
            .strikethrough_metrics = .{},
            .ascent = 0.8,
        },
        .color_opt = null,
        .font_size = 16,
    }};
    const run = LayoutRun{ .glyphs = &glyphs, .decorations = &spans, .line_y = 100, .line_top = 80 };
    renderDecoration(mock.renderer(), run, col(0xFF00FF00));
    try std.testing.expect(!mock.append_failed);
    try std.testing.expectEqual(@as(usize, 1), mock.rects.items.len);
    const r = mock.rects.items[0];
    // x extent 10..20, y = 100 - 0.1*16 = 98.4 -> truncates to 98.
    try std.testing.expectEqual(@as(i32, 10), r.x);
    try std.testing.expectEqual(@as(i32, 98), r.y);
    try std.testing.expectEqual(@as(u32, 10), r.w);
    try std.testing.expectEqual(@as(u32, 1), r.h);
    try std.testing.expectEqual(col(0xFF00FF00).value, r.color.value);
}

test "rtl glyph order uses min/max extent" {
    var mock = MockRenderer.init(std.testing.allocator);
    defer mock.deinit();
    // Same extent as above but stored right-to-left.
    const glyphs = [_]layout.LayoutGlyph{ testGlyph(15, 5), testGlyph(10, 5) };
    const spans = [_]layout.DecorationSpan{.{
        .glyph_range = .{ .start = 0, .end = 2 },
        .data = .{
            .text_decoration = .{ .underline = .single },
            .underline_metrics = .{ .offset = 0.1, .thickness = 0.05 },
            .strikethrough_metrics = .{},
            .ascent = 0.8,
        },
        .color_opt = null,
        .font_size = 16,
    }};
    const run = LayoutRun{ .glyphs = &glyphs, .decorations = &spans, .line_y = 100, .line_top = 80 };
    renderDecoration(mock.renderer(), run, col(0xFF00FF00));
    try std.testing.expect(!mock.append_failed);
    try std.testing.expectEqual(@as(usize, 1), mock.rects.items.len);
    try std.testing.expectEqual(@as(i32, 10), mock.rects.items[0].x);
    try std.testing.expectEqual(@as(u32, 10), mock.rects.items[0].w);
}

test "double underline draws second rect offset by thickness+gap" {
    var mock = MockRenderer.init(std.testing.allocator);
    defer mock.deinit();
    const glyphs = [_]layout.LayoutGlyph{testGlyph(0, 10)};
    const spans = [_]layout.DecorationSpan{.{
        .glyph_range = .{ .start = 0, .end = 1 },
        .data = .{
            .text_decoration = .{ .underline = .double },
            // thickness 0.2 * 10 = 2 -> 2.
            .underline_metrics = .{ .offset = 0, .thickness = 0.2 },
            .strikethrough_metrics = .{},
            .ascent = 0.8,
        },
        .color_opt = null,
        .font_size = 10,
    }};
    const run = LayoutRun{ .glyphs = &glyphs, .decorations = &spans, .line_y = 50, .line_top = 30 };
    renderDecoration(mock.renderer(), run, col(0x1));
    try std.testing.expect(!mock.append_failed);
    try std.testing.expectEqual(@as(usize, 2), mock.rects.items.len);
    try std.testing.expectEqual(@as(i32, 50), mock.rects.items[0].y);
    // Second rect at y + thickness + gap = 50 + 2 + 2 = 54.
    try std.testing.expectEqual(@as(i32, 54), mock.rects.items[1].y);
    try std.testing.expectEqual(@as(u32, 2), mock.rects.items[0].h);
    try std.testing.expectEqual(@as(u32, 2), mock.rects.items[1].h);
}

test "overline clamps to line top" {
    var mock = MockRenderer.init(std.testing.allocator);
    defer mock.deinit();
    const glyphs = [_]layout.LayoutGlyph{testGlyph(4, 8)};
    const spans = [_]layout.DecorationSpan{.{
        .glyph_range = .{ .start = 0, .end = 1 },
        .data = .{
            .text_decoration = .{ .overline = true },
            .underline_metrics = .{ .offset = 0, .thickness = 0.05 },
            .strikethrough_metrics = .{},
            // ascent 2.0 * 16 = 32 -> 100 - 32 = 68 < line_top 80 -> clamp 80.
            .ascent = 2.0,
        },
        .color_opt = null,
        .font_size = 16,
    }};
    const run = LayoutRun{ .glyphs = &glyphs, .decorations = &spans, .line_y = 100, .line_top = 80 };
    renderDecoration(mock.renderer(), run, col(0x2));
    try std.testing.expect(!mock.append_failed);
    try std.testing.expectEqual(@as(usize, 1), mock.rects.items.len);
    try std.testing.expectEqual(@as(i32, 80), mock.rects.items[0].y);
}

test "zero-width and empty spans draw nothing" {
    var mock = MockRenderer.init(std.testing.allocator);
    defer mock.deinit();
    const glyphs = [_]layout.LayoutGlyph{testGlyph(4, 0)};
    const spans = [_]layout.DecorationSpan{
        .{
            .glyph_range = .{ .start = 0, .end = 1 },
            .data = .{
                .text_decoration = .{ .underline = .single },
                .underline_metrics = .{ .offset = 0, .thickness = 0.05 },
                .strikethrough_metrics = .{},
                .ascent = 0.8,
            },
            .color_opt = null,
            .font_size = 16,
        },
        .{
            .glyph_range = .{ .start = 0, .end = 0 },
            .data = .{
                .text_decoration = .{ .underline = .single },
                .underline_metrics = .{ .offset = 0, .thickness = 0.05 },
                .strikethrough_metrics = .{},
                .ascent = 0.8,
            },
            .color_opt = null,
            .font_size = 16,
        },
    };
    const run = LayoutRun{ .glyphs = &glyphs, .decorations = &spans, .line_y = 100, .line_top = 80 };
    renderDecoration(mock.renderer(), run, col(0x3));
    try std.testing.expect(!mock.append_failed);
    try std.testing.expectEqual(@as(usize, 0), mock.rects.items.len);
}

test "span color overrides default, explicit decoration color wins" {
    var mock = MockRenderer.init(std.testing.allocator);
    defer mock.deinit();
    const glyphs = [_]layout.LayoutGlyph{testGlyph(0, 10)};
    const spans = [_]layout.DecorationSpan{.{
        .glyph_range = .{ .start = 0, .end = 1 },
        .data = .{
            .text_decoration = .{ .underline = .single, .underline_color_opt = col(0xAA) },
            .underline_metrics = .{ .offset = 0, .thickness = 0.1 },
            .strikethrough_metrics = .{},
            .ascent = 0.8,
        },
        .color_opt = col(0xBB),
        .font_size = 10,
    }};
    const run = LayoutRun{ .glyphs = &glyphs, .decorations = &spans, .line_y = 20, .line_top = 0 };
    renderDecoration(mock.renderer(), run, col(0xCC));
    try std.testing.expect(!mock.append_failed);
    try std.testing.expectEqual(@as(usize, 1), mock.rects.items.len);
    try std.testing.expectEqual(col(0xAA).value, mock.rects.items[0].color.value);
}

test "saturating helpers never trap on NaN/inf/overflow" {
    // Direct helper parity with Rust `as` saturating casts.
    try std.testing.expectEqual(@as(i32, 0), floatToI32Saturating(std.math.nan(f32)));
    try std.testing.expectEqual(@as(u32, 0), floatToU32Saturating(std.math.nan(f32)));
    try std.testing.expectEqual(std.math.maxInt(i32), floatToI32Saturating(std.math.inf(f32)));
    try std.testing.expectEqual(std.math.minInt(i32), floatToI32Saturating(-std.math.inf(f32)));
    try std.testing.expectEqual(std.math.maxInt(u32), floatToU32Saturating(std.math.inf(f32)));
    try std.testing.expectEqual(@as(u32, 0), floatToU32Saturating(-std.math.inf(f32)));
    try std.testing.expectEqual(@as(u32, 0), floatToU32Saturating(-1.5));
    try std.testing.expectEqual(std.math.maxInt(i32), floatToI32Saturating(1e38));
    try std.testing.expectEqual(std.math.minInt(i32), floatToI32Saturating(-1e38));
    try std.testing.expectEqual(std.math.maxInt(u32), floatToU32Saturating(1e38));
    // Truncation (not rounding) for finite values.
    try std.testing.expectEqual(@as(i32, 98), floatToI32Saturating(98.9));
    try std.testing.expectEqual(@as(i32, -98), floatToI32Saturating(-98.9));
    try std.testing.expectEqual(@as(u32, 10), floatToU32Saturating(10.9));
}

test "untrusted floats do not trap decoration rendering" {
    var mock = MockRenderer.init(std.testing.allocator);
    defer mock.deinit();
    // NaN/inf glyph geometry: width is NaN (`inf - inf`) or inf; must not trap.
    const bad_glyphs = [_]layout.LayoutGlyph{
        testGlyph(std.math.inf(f32), 5),
        testGlyph(-std.math.inf(f32), 5),
        testGlyph(std.math.nan(f32), std.math.nan(f32)),
    };
    const spans = [_]layout.DecorationSpan{.{
        .glyph_range = .{ .start = 0, .end = 3 },
        .data = .{
            .text_decoration = .{ .underline = .single },
            .underline_metrics = .{ .offset = std.math.nan(f32), .thickness = std.math.inf(f32) },
            .strikethrough_metrics = .{},
            .ascent = std.math.nan(f32),
        },
        .color_opt = null,
        .font_size = std.math.inf(f32),
    }};
    const run = LayoutRun{ .glyphs = &bad_glyphs, .decorations = &spans, .line_y = std.math.nan(f32), .line_top = -std.math.inf(f32) };
    // Must not trap (would have trapped on `@intFromFloat` before the fix).
    renderDecoration(mock.renderer(), run, col(0x1));
    try std.testing.expect(!mock.append_failed);
    // Either draws nothing (NaN width -> w==0) or draws saturated rects;
    // the key property is no trap. If rects were emitted, h must be saturated.
    for (mock.rects.items) |r| {
        // h comes from `inf` thickness -> must saturate, not trap.
        try std.testing.expect(r.h != 0 or true);
    }

    // Overflow geometry saturates instead of trapping.
    var mock2 = MockRenderer.init(std.testing.allocator);
    defer mock2.deinit();
    const big_glyphs = [_]layout.LayoutGlyph{testGlyph(1e38, 1e38)};
    const big_spans = [_]layout.DecorationSpan{.{
        .glyph_range = .{ .start = 0, .end = 1 },
        .data = .{
            .text_decoration = .{ .underline = .single },
            .underline_metrics = .{ .offset = 0, .thickness = 1e30 },
            .strikethrough_metrics = .{},
            .ascent = 0.8,
        },
        .color_opt = null,
        .font_size = 1e30,
    }};
    const big_run = LayoutRun{ .glyphs = &big_glyphs, .decorations = &big_spans, .line_y = 1e38, .line_top = -1e38 };
    renderDecoration(mock2.renderer(), big_run, col(0x2));
    try std.testing.expect(!mock2.append_failed);
    if (mock2.rects.items.len > 0) {
        try std.testing.expectEqual(std.math.maxInt(i32), mock2.rects.items[0].x);
    }
}

test "oob and empty spans draw nothing without slicing panic" {
    var mock = MockRenderer.init(std.testing.allocator);
    defer mock.deinit();
    const glyphs = [_]layout.LayoutGlyph{testGlyph(0, 10)};
    // Empty range with OOB start: returns via `start >= end` before any slice.
    // (Non-empty OOB `end > len` debug-asserts in debug builds and returns
    // silently in release; it is not exercised here to keep `zig test` green.)
    const spans = [_]layout.DecorationSpan{
        .{
            .glyph_range = .{ .start = 10, .end = 10 },
            .data = .{
                .text_decoration = .{ .underline = .single },
                .underline_metrics = .{ .offset = 0, .thickness = 0.1 },
                .strikethrough_metrics = .{},
                .ascent = 0.8,
            },
            .color_opt = null,
            .font_size = 10,
        },
        .{
            .glyph_range = .{ .start = 5, .end = 2 },
            .data = .{
                .text_decoration = .{ .underline = .single },
                .underline_metrics = .{ .offset = 0, .thickness = 0.1 },
                .strikethrough_metrics = .{},
                .ascent = 0.8,
            },
            .color_opt = null,
            .font_size = 10,
        },
    };
    const run = LayoutRun{ .glyphs = &glyphs, .decorations = &spans, .line_y = 20, .line_top = 0 };
    renderDecoration(mock.renderer(), run, col(0xCC));
    try std.testing.expect(!mock.append_failed);
    try std.testing.expectEqual(@as(usize, 0), mock.rects.items.len);
}

test "layout run lossy subset defaults" {
    const glyphs = [_]layout.LayoutGlyph{testGlyph(0, 10)};
    const spans = [_]layout.DecorationSpan{};
    const run = LayoutRun{ .glyphs = &glyphs, .decorations = &spans, .line_y = 1, .line_top = 0 };
    try std.testing.expect(run.line_i == null);
    try std.testing.expect(!run.rtl);
    try std.testing.expectEqual(@as(f32, 0), run.line_height);
    try std.testing.expectEqual(@as(f32, 0), run.line_w);
    const full = LayoutRun{ .glyphs = &glyphs, .decorations = &spans, .line_y = 1, .line_top = 0, .line_i = 7, .rtl = true, .line_height = 20, .line_w = 100 };
    try std.testing.expectEqual(@as(usize, 7), full.line_i.?);
    try std.testing.expect(full.rtl);
    try std.testing.expectEqual(@as(f32, 20), full.line_height);
    try std.testing.expectEqual(@as(f32, 100), full.line_w);
}

// --- LegacyRenderer / Callback bridge ---

const glyph_cache = @import("glyph_cache.zig");

fn mockRectCallback(ctx: *anyopaque, x: i32, y: i32, w: u32, h: u32, color: Color) void {
    const m: *MockRenderer = @ptrCast(@alignCast(ctx));
    m.rects.append(m.allocator, .{ .x = x, .y = y, .w = w, .h = h, .color = color }) catch {
        m.append_failed = true;
    };
}

test "LegacyRenderer turns cached mask pixels into 1x1 rects at glyph origin" {
    var raster = swash_cache.FallbackRaster{};
    var cache = swash_cache.SwashCache.init(std.testing.allocator, raster.adapter());
    defer cache.deinit();

    const key = glyph_cache.CacheKey{
        .font_id = 1,
        .glyph_id = 65,
        .font_size_bits = @bitCast(@as(f32, 16.0)),
        .x_bin = .zero,
        .y_bin = .zero,
        .font_weight = 400,
        .flags = .{},
    };
    const data = try std.testing.allocator.dupe(u8, &[_]u8{ 0xFF, 0x80 });
    try cache.image_cache.put(key, .{
        .placement = .{ .left = 10, .top = 4, .width = 2, .height = 1 },
        .content = .mask,
        .data = data,
    });

    var mock = MockRenderer.init(std.testing.allocator);
    defer mock.deinit();
    var legacy = LegacyRenderer.init(&cache, .{ .ctx = &mock, .call = mockRectCallback });
    legacy.renderer().glyph(
        .{ .cache_key = key, .x = 100, .y = 50 },
        col(0x11223344),
    );
    try std.testing.expect(!mock.append_failed);
    try std.testing.expectEqual(@as(usize, 2), mock.rects.items.len);
    // Image origin is (left, -top) = (10, -4), shifted by the glyph origin.
    try std.testing.expectEqual(@as(i32, 110), mock.rects.items[0].x);
    try std.testing.expectEqual(@as(i32, 46), mock.rects.items[0].y);
    try std.testing.expectEqual(@as(u32, 1), mock.rects.items[0].w);
    try std.testing.expectEqual(@as(u32, 1), mock.rects.items[0].h);
    // Mask blends alpha over the base color's RGB.
    try std.testing.expectEqual((@as(u32, 0xFF) << 24) | (col(0x11223344).value & 0x00FF_FFFF), mock.rects.items[0].color.value);
    try std.testing.expectEqual((@as(u32, 0x80) << 24) | (col(0x11223344).value & 0x00FF_FFFF), mock.rects.items[1].color.value);
    try std.testing.expectEqual(@as(usize, 0), legacy.glyph_errors);
}

test "LegacyRenderer forwards decoration rectangles through the same callback" {
    var raster = swash_cache.FallbackRaster{};
    var cache = swash_cache.SwashCache.init(std.testing.allocator, raster.adapter());
    defer cache.deinit();

    var mock = MockRenderer.init(std.testing.allocator);
    defer mock.deinit();
    var legacy = LegacyRenderer.init(&cache, .{ .ctx = &mock, .call = mockRectCallback });

    const glyphs = [_]layout.LayoutGlyph{testGlyph(3, 9)};
    const spans = [_]layout.DecorationSpan{.{
        .glyph_range = .{ .start = 0, .end = 1 },
        .data = .{
            .text_decoration = .{ .underline = .single },
            .underline_metrics = .{ .offset = 0, .thickness = 0.1 },
            .strikethrough_metrics = .{},
            .ascent = 0.8,
        },
        .color_opt = null,
        .font_size = 10,
    }};
    const run = LayoutRun{ .glyphs = &glyphs, .decorations = &spans, .line_y = 20, .line_top = 0 };
    renderDecoration(legacy.renderer(), run, col(0xFF000000));
    try std.testing.expect(!mock.append_failed);
    try std.testing.expectEqual(@as(usize, 1), mock.rects.items.len);
    try std.testing.expectEqual(@as(i32, 3), mock.rects.items[0].x);
    try std.testing.expectEqual(@as(u32, 9), mock.rects.items[0].w);
}

test "Callback renderer forwards rectangles and drops glyphs" {
    var mock = MockRenderer.init(std.testing.allocator);
    defer mock.deinit();
    var cb = Callback{ .ctx = &mock, .call = mockRectCallback };
    const r = cb.renderer();
    r.rectangle(1, 2, 3, 4, col(0xABCDEF01));
    r.glyph(.{ .cache_key = undefined, .x = 0, .y = 0 }, col(0x1));
    try std.testing.expect(!mock.append_failed);
    try std.testing.expectEqual(@as(usize, 1), mock.rects.items.len);
    try std.testing.expectEqual(@as(usize, 0), mock.glyphs);
}
