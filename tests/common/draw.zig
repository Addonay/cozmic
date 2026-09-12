//! Image-test harness, port of cosmic-text `tests/common/mod.rs`.
//!
//! Renders a configured buffer through the public `Buffer.draw` path into a
//! `pixmap.Pixmap` (white canvas, `margins` on all sides, black text) and
//! compares the decoded RGBA pixels against a baseline under `tests/images/`.
//!
//! Bless mode: set `COZMIC_GENERATE_IMAGES=1` (or `true`/`t`) to write the
//! rendered image to `tests/images/<name>.png` instead of comparing. Like
//! upstream, this overwrites the baseline at that path.
//!
//! Comparison is decoded-RGBA, not PNG bytes (zlib encoders differ). A test
//! may allow `channel_tolerance` (max absolute per-channel difference that
//! still counts as equal) and `max_mismatched_pixels`; defaults are exact.
//! The upstream baselines were produced by tiny-skia + swash, while this port
//! rasterizes with FreeType, so image suites that use tolerance document the
//! backend difference locally.

const std = @import("std");
const builtin = @import("builtin");
const cozmic = @import("cozmic");
const fonts = @import("fonts.zig");
const pixmap = @import("pixmap.zig");
const png = @import("png.zig");

pub const DEFAULT_MARGINS: i32 = 5;

const IMAGE_DIRS = [_][]const u8{ "tests/images", "../tests/images", "src/../tests/images" };

/// Per-span decoration overrides for rich-text image tests.
pub const SpanDecoration = struct {
    underline: cozmic.UnderlineStyle = .none,
    underline_color: ?cozmic.Color = null,
    strikethrough: bool = false,
    strikethrough_color: ?cozmic.Color = null,
    overline: bool = false,
};

/// One rich-text span: text plus optional overrides on top of `family`.
pub const SpanSpec = struct {
    text: []const u8,
    decoration: SpanDecoration = .{},
    color: ?cozmic.Color = null,
    weight: ?cozmic.Weight = null,
};

/// Configuration for one rendered-image test.
pub const DrawTestCfg = struct {
    /// Baseline name without extension (`tests/images/<name>.png`).
    name: []const u8,
    text: []const u8 = "",
    /// Rich-text spans; when non-empty, `setRichText` is used instead of
    /// `setText` (mirrors upstream `DrawTestCfg::rich_text`). `text` is then
    /// ignored.
    rich_spans: []const SpanSpec = &.{},
    /// Named family from the vendored fixture corpus (e.g. "Inter",
    /// "Noto Sans", "Noto Sans Arabic", "Fira Mono").
    family: []const u8 = "Inter",
    font_size: f32 = 16.0,
    line_height: f32 = 20.0,
    canvas_width: u32 = 300,
    canvas_height: u32 = 300,
    wrap: cozmic.Wrap = .word_or_glyph,
    ellipsize: cozmic.Ellipsize = .{ .none = {} },
    alignment: ?cozmic.Align = null,
    margins: i32 = DEFAULT_MARGINS,
    color: cozmic.Color = .{ .value = 0xFF00_0000 },
    /// Max absolute per-channel difference still treated as equal.
    channel_tolerance: u8 = 0,
    /// Max number of differing pixels still allowed (exact mode) or of
    /// stray/missing ink pixels (structural mode).
    max_mismatched_pixels: usize = 0,
    /// When > 0, switch from pixel-exact to structural comparison: every ink
    /// pixel in either image must have an ink pixel in the other within this
    /// Chebyshev radius, and `max_mismatched_pixels` bounds the strays.
    /// This absorbs rasterizer AA differences (FreeType vs upstream swash)
    /// while still failing on moved/missing glyphs and decorations.
    max_ink_distance: u8 = 0,
    /// Optional per-channel ink-mass guard used in structural mode: each
    /// channel's total darkening must be within this percentage of the
    /// baseline. Catches colored decorations drawn in the wrong color, which
    /// a geometry-only comparison would miss.
    max_color_mass_diff_pct: u8 = 0,
};

/// True when `COZMIC_GENERATE_IMAGES` asks for baseline generation.
pub fn generateImages() bool {
    if (!builtin.link_libc) return false;
    const raw = std.c.getenv("COZMIC_GENERATE_IMAGES") orelse return false;
    const value = std.mem.span(raw);
    if (std.mem.eql(u8, value, "1")) return true;
    return std.ascii.eqlIgnoreCase(value, "true") or std.ascii.eqlIgnoreCase(value, "t");
}

/// Render one configuration and return the RGBA canvas (caller frees).
pub fn renderToPixmap(alloc: std.mem.Allocator, cfg: DrawTestCfg) !pixmap.Pixmap {
    const margins: u32 = @intCast(@max(cfg.margins, 0));
    if (cfg.canvas_width <= margins * 2 or cfg.canvas_height <= margins * 2) {
        return error.InvalidCanvas;
    }

    var fs = try fonts.fontSystem(alloc);
    defer fs.deinit();

    var raster = try cozmic.Raster.init(alloc);
    defer raster.deinit();
    try raster.addFromFontSystem(&fs, fs.fontIds());

    var cache = cozmic.SwashCache.init(alloc, null);
    defer cache.deinit();
    cache.setRaster(&raster);

    var attrs = fonts.attrsWithFamily(alloc, cfg.family);
    defer attrs.deinit();

    var buffer = try cozmic.Buffer.initWithAllocator(
        alloc,
        cozmic.Metrics.new(cfg.font_size, cfg.line_height),
    );
    defer buffer.deinit();
    var borrowed = buffer.borrowWith(&fs);
    borrowed.setWrap(cfg.wrap);
    borrowed.setEllipsize(cfg.ellipsize);
    borrowed.setSize(
        @floatFromInt(cfg.canvas_width - margins * 2),
        @floatFromInt(cfg.canvas_height - margins * 2),
    );
    if (cfg.rich_spans.len == 0) {
        try borrowed.setText(cfg.text, &attrs, .advanced, cfg.alignment);
    } else {
        // Span attrs only need to live for the `setRichText` call (it copies
        // them into the buffer's `AttrsList`).
        var span_attrs: std.ArrayList(cozmic.Attrs) = .empty;
        defer {
            for (span_attrs.items) |*a| a.deinit();
            span_attrs.deinit(alloc);
        }
        var spans: std.ArrayList(cozmic.Buffer.RichSpan) = .empty;
        defer spans.deinit(alloc);
        try span_attrs.ensureTotalCapacity(alloc, cfg.rich_spans.len);
        try spans.ensureTotalCapacity(alloc, cfg.rich_spans.len);
        for (cfg.rich_spans) |spec| {
            var a = cozmic.Attrs.init(alloc);
            a.family = .{ .name = cfg.family };
            a.text_decoration.underline = spec.decoration.underline;
            a.text_decoration.underline_color_opt = spec.decoration.underline_color;
            a.text_decoration.strikethrough = spec.decoration.strikethrough;
            a.text_decoration.strikethrough_color_opt = spec.decoration.strikethrough_color;
            a.text_decoration.overline = spec.decoration.overline;
            if (spec.color) |c| a.color_opt = c;
            if (spec.weight) |w| a.weight = w;
            span_attrs.appendAssumeCapacity(a);
            spans.appendAssumeCapacity(.{ .text = spec.text, .attrs = a });
        }
        try borrowed.setRichText(spans.items, &attrs, .advanced, cfg.alignment);
    }

    var pm = try pixmap.Pixmap.init(alloc, cfg.canvas_width, cfg.canvas_height);
    errdefer pm.deinit();
    pm.fill(.{ .r = 255, .g = 255, .b = 255, .a = 255 });

    const Ctx = struct {
        pm: *pixmap.Pixmap,
        margins: i32,

        fn call(ctx: *anyopaque, x: i32, y: i32, w: u32, h: u32, color: cozmic.Color) void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.pm.fillRect(
                x + self.margins,
                y + self.margins,
                w,
                h,
                .{ .r = color.r(), .g = color.g(), .b = color.b(), .a = color.a() },
            );
        }
    };
    var ctx = Ctx{ .pm = &pm, .margins = cfg.margins };
    try borrowed.draw(&cache, cfg.color, .{ .ctx = &ctx, .call = Ctx.call });

    return pm;
}

/// Difference statistics between a rendered pixmap and a baseline image.
pub const DiffStats = struct {
    /// Pixels with at least one channel over the tolerance (exact mode).
    mismatched_pixels: usize = 0,
    /// Largest absolute per-channel difference observed.
    max_channel_diff: u8 = 0,
    /// Ink pixels in the actual image with no baseline ink within radius.
    stray_ink: usize = 0,
    /// Baseline ink pixels with no actual ink within radius.
    missing_ink: usize = 0,
};

/// Channel threshold below which a pixel counts as ink (text coverage).
const INK_THRESHOLD: u8 = 250;

fn isInk(px: []const u8) bool {
    return px[0] < INK_THRESHOLD or px[1] < INK_THRESHOLD or px[2] < INK_THRESHOLD;
}

fn hasInkWithin(
    ink: []const bool,
    width: usize,
    height: usize,
    x: usize,
    y: usize,
    radius: usize,
) bool {
    const x0 = x -| radius;
    const y0 = y -| radius;
    const x1 = @min(width - 1, x + radius);
    const y1 = @min(height - 1, y + radius);
    var yy = y0;
    while (yy <= y1) : (yy += 1) {
        var xx = x0;
        while (xx <= x1) : (xx += 1) {
            if (ink[yy * width + xx]) return true;
        }
    }
    return false;
}

/// Structural comparison: ink pixels must be within `radius` of an ink pixel
/// in the other image. Ignores anti-aliasing intensity entirely. Propagates
/// allocation errors instead of degrading to a vacuous pass.
pub fn structuralDiff(
    allocator: std.mem.Allocator,
    actual: []const u8,
    reference: []const u8,
    width: usize,
    height: usize,
    radius: usize,
) !DiffStats {
    std.debug.assert(actual.len == reference.len and actual.len == width * height * 4);
    const count = width * height;
    const actual_ink = try allocator.alloc(bool, count);
    defer allocator.free(actual_ink);
    const ref_ink = try allocator.alloc(bool, count);
    defer allocator.free(ref_ink);
    var i: usize = 0;
    while (i < count) : (i += 1) {
        actual_ink[i] = isInk(actual[i * 4 .. i * 4 + 4]);
        ref_ink[i] = isInk(reference[i * 4 .. i * 4 + 4]);
    }

    var stats = DiffStats{};
    i = 0;
    while (i < count) : (i += 1) {
        const x = i % width;
        const y = i / width;
        if (actual_ink[i] and !hasInkWithin(ref_ink, width, height, x, y, radius)) {
            stats.stray_ink += 1;
        }
        if (ref_ink[i] and !hasInkWithin(actual_ink, width, height, x, y, radius)) {
            stats.missing_ink += 1;
        }
    }
    return stats;
}

/// Compare two RGBA buffers of identical dimensions.
pub fn diffRgba(
    actual: []const u8,
    reference: []const u8,
    channel_tolerance: u8,
) DiffStats {
    std.debug.assert(actual.len == reference.len and actual.len % 4 == 0);
    var stats = DiffStats{};
    var i: usize = 0;
    while (i < actual.len) : (i += 4) {
        var bad = false;
        inline for (0..4) |c| {
            const a = actual[i + c];
            const b = reference[i + c];
            const d: u8 = if (a > b) a - b else b - a;
            stats.max_channel_diff = @max(stats.max_channel_diff, d);
            if (d > channel_tolerance) bad = true;
        }
        if (bad) stats.mismatched_pixels += 1;
    }
    return stats;
}

/// Per-channel ink mass (total darkening) ratios, actual / reference.
pub const ChannelMassStats = struct {
    ratio: [3]f32,
};

/// Compute per-channel darkening mass for both images. Catches color swaps
/// (e.g. a red underline drawn black) that geometry-only checks miss.
pub fn channelMassStats(actual: []const u8, reference: []const u8) ChannelMassStats {
    std.debug.assert(actual.len == reference.len and actual.len % 4 == 0);
    var actual_mass = [3]u64{ 0, 0, 0 };
    var ref_mass = [3]u64{ 0, 0, 0 };
    var i: usize = 0;
    while (i < actual.len) : (i += 4) {
        inline for (0..3) |c| {
            actual_mass[c] += 255 - actual[i + c];
            ref_mass[c] += 255 - reference[i + c];
        }
    }
    var stats = ChannelMassStats{ .ratio = .{ 1, 1, 1 } };
    inline for (0..3) |c| {
        if (ref_mass[c] > 0) {
            stats.ratio[c] = @as(f32, @floatFromInt(actual_mass[c])) /
                @as(f32, @floatFromInt(ref_mass[c]));
        }
    }
    return stats;
}

fn readBaseline(alloc: std.mem.Allocator, name: []const u8) ![]u8 {
    var last_err: anyerror = error.FileNotFound;
    for (IMAGE_DIRS) |dir| {
        const file_name = try std.fmt.allocPrint(alloc, "{s}.png", .{name});
        defer alloc.free(file_name);
        const path = try std.fs.path.join(alloc, &.{ dir, file_name });
        defer alloc.free(path);
        if (std.Io.Dir.cwd().readFileAlloc(std.testing.io, path, alloc, .limited(1 << 26))) |bytes| {
            return bytes;
        } else |err| {
            last_err = err;
        }
    }
    return last_err;
}

/// Directory that bless mode writes to. Defaults to `tests/images`
/// (upstream behaviour); set `COZMIC_IMAGE_DIR` to keep generated images
/// elsewhere, which makes before/after diagnostics non-destructive.
fn blessDir() []const u8 {
    if (builtin.link_libc) {
        if (std.c.getenv("COZMIC_IMAGE_DIR")) |raw| {
            const dir = std.mem.span(raw);
            if (dir.len > 0) return dir;
        }
    }
    return IMAGE_DIRS[0];
}

/// Write the rendered pixmap as the baseline (bless mode).
pub fn bless(alloc: std.mem.Allocator, cfg: DrawTestCfg, pm: *const pixmap.Pixmap) !void {
    const bytes = try png.encodeAlloc(alloc, pm.width, pm.height, pm.data);
    defer alloc.free(bytes);
    const file_name = try std.fmt.allocPrint(alloc, "{s}.png", .{cfg.name});
    defer alloc.free(file_name);
    const path = try std.fs.path.join(alloc, &.{ blessDir(), file_name });
    defer alloc.free(path);
    try std.Io.Dir.cwd().writeFile(std.testing.io, .{ .sub_path = path, .data = bytes });
}

/// Render `cfg` and compare with its baseline, or bless it when requested.
/// Returns `error.ImageMismatch` (with a diagnostic print) when the decoded
/// pixels exceed the configured tolerance.
pub fn validateTextRendering(alloc: std.mem.Allocator, cfg: DrawTestCfg) !void {
    var pm = try renderToPixmap(alloc, cfg);
    defer pm.deinit();

    if (generateImages()) {
        try bless(alloc, cfg, &pm);
        return;
    }

    const ref_bytes = try readBaseline(alloc, cfg.name);
    defer alloc.free(ref_bytes);
    var reference = try png.decodeAlloc(alloc, ref_bytes);
    defer reference.deinit();

    if (reference.width != pm.width or reference.height != pm.height) {
        std.debug.print(
            "image size mismatch for {s}: baseline {}x{}, rendered {}x{}\n",
            .{ cfg.name, reference.width, reference.height, pm.width, pm.height },
        );
        return error.ImageSizeMismatch;
    }

    if (cfg.max_ink_distance > 0) {
        const stats = try structuralDiff(
            alloc,
            pm.data,
            reference.data,
            pm.width,
            pm.height,
            cfg.max_ink_distance,
        );
        if (stats.stray_ink + stats.missing_ink > cfg.max_mismatched_pixels) {
            std.debug.print(
                "image structure mismatch for {s}: {d} stray + {d} missing ink pixels (radius {d}, allowed {d})\n",
                .{
                    cfg.name,
                    stats.stray_ink,
                    stats.missing_ink,
                    cfg.max_ink_distance,
                    cfg.max_mismatched_pixels,
                },
            );
            return error.ImageMismatch;
        }
        if (cfg.max_color_mass_diff_pct > 0) {
            const mass = channelMassStats(pm.data, reference.data);
            const tol = @as(f32, @floatFromInt(cfg.max_color_mass_diff_pct)) / 100.0;
            for (mass.ratio, 0..) |ratio, channel| {
                if (@abs(ratio - 1.0) > tol) {
                    std.debug.print(
                        "image color mismatch for {s}: channel {d} ink mass ratio {d:.4} outside +/-{d}%\n",
                        .{ cfg.name, channel, ratio, cfg.max_color_mass_diff_pct },
                    );
                    return error.ImageMismatch;
                }
            }
        }
        return;
    }

    const stats = diffRgba(pm.data, reference.data, cfg.channel_tolerance);
    if (stats.mismatched_pixels > cfg.max_mismatched_pixels) {
        std.debug.print(
            "image mismatch for {s}: {d}/{d} pixels differ (max channel diff {d}, tolerance {d})\n",
            .{
                cfg.name,
                stats.mismatched_pixels,
                pm.width * pm.height,
                stats.max_channel_diff,
                cfg.channel_tolerance,
            },
        );
        return error.ImageMismatch;
    }
}

test "draw harness: render a simple string and produce non-white pixels" {
    const alloc = std.testing.allocator;
    var pm = try renderToPixmap(alloc, .{ .name = "harness_selftest", .text = "A", .family = "Inter" });
    defer pm.deinit();
    var non_white: usize = 0;
    var i: usize = 0;
    while (i < pm.data.len) : (i += 4) {
        if (pm.data[i] != 255 or pm.data[i + 1] != 255 or pm.data[i + 2] != 255) non_white += 1;
    }
    try std.testing.expect(non_white > 0);
}

test "draw harness: exact diff and ink-mass helpers detect differences" {
    const same = [_]u8{ 255, 255, 255, 255, 10, 20, 30, 255 };
    try std.testing.expectEqual(@as(usize, 0), diffRgba(&same, &same, 0).mismatched_pixels);

    const actual = [_]u8{ 255, 255, 255, 255, 0, 0, 0, 255, 255, 0, 0, 255 };
    const reference = [_]u8{ 255, 255, 255, 255, 0, 0, 0, 255, 0, 0, 0, 255 };
    const stats = diffRgba(&actual, &reference, 0);
    try std.testing.expectEqual(@as(usize, 1), stats.mismatched_pixels);
    try std.testing.expectEqual(@as(u8, 255), stats.max_channel_diff);

    // The red pixel in `actual` is black in `reference`: the red channel mass
    // differs while green/blue match.
    const mass = channelMassStats(&actual, &reference);
    try std.testing.expect(mass.ratio[0] < 1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), mass.ratio[1], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), mass.ratio[2], 1e-6);
}
