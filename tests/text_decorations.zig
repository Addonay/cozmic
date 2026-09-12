//! Port of upstream `tests/text_decorations.rs`: underline (single/double),
//! strikethrough, overline, per-decoration colors, and their BiDi layout.
//!
//! Comparison mode: structural (`max_ink_distance = 1`), because upstream
//! baselines were rasterized with swash while this port uses FreeType.
//! Decoration rectangles are drawn by our own code and are pixel-exact; the
//! radius absorbs glyph AA so offsets/thickness are still checked.

const std = @import("std");
const cozmic = @import("cozmic");
const draw = @import("common/draw.zig");

const RASTER_INK_RADIUS: u8 = 1;
const RASTER_MAX_STRAY: usize = 32;
const RASTER_CHROMA_MASS_PCT: u8 = 2;

fn red() cozmic.Color {
    return cozmic.Color.rgb(0xFF, 0x00, 0x00);
}

fn cyan() cozmic.Color {
    return cozmic.Color.rgb(0x00, 0xFF, 0xFF);
}

fn deco(
    underline: cozmic.UnderlineStyle,
    underline_color: ?cozmic.Color,
    strikethrough: bool,
    strikethrough_color: ?cozmic.Color,
    overline: bool,
) draw.SpanDecoration {
    return .{
        .underline = underline,
        .underline_color = underline_color,
        .strikethrough = strikethrough,
        .strikethrough_color = strikethrough_color,
        .overline = overline,
    };
}

test "decorations image: all variants" {
    const spans = [_]draw.SpanSpec{
        .{ .text = "Under ", .decoration = deco(.single, null, false, null, false) },
        .{ .text = "Double ", .decoration = deco(.double, null, false, null, false) },
        .{ .text = "Strike ", .decoration = deco(.none, null, true, null, false) },
        .{ .text = "Over ", .decoration = deco(.none, null, false, null, true) },
        .{ .text = "RedUl ", .decoration = deco(.single, red(), false, null, false) },
        .{ .text = "CyanSt ", .decoration = deco(.none, null, true, cyan(), false) },
        .{ .text = "All", .decoration = deco(.single, null, true, null, true) },
        .{ .text = " Plain" },
    };
    try draw.validateTextRendering(std.testing.allocator, .{
        .name = "text_decorations",
        .family = "Noto Sans",
        .font_size = 20,
        .line_height = 26,
        .rich_spans = &spans,
        .canvas_width = 600,
        .canvas_height = 50,
        .max_ink_distance = RASTER_INK_RADIUS,
        .max_mismatched_pixels = RASTER_MAX_STRAY,
        .max_color_mass_diff_pct = RASTER_CHROMA_MASS_PCT,
    });
}

test "decorations image: rtl" {
    const spans = [_]draw.SpanSpec{
        .{ .text = "زیر خط ", .decoration = deco(.single, null, false, null, false) },
        .{ .text = "دوتایی ", .decoration = deco(.double, null, false, null, false) },
        .{ .text = "خط ", .decoration = deco(.none, null, true, null, false) },
        .{ .text = "رو ", .decoration = deco(.none, null, false, null, true) },
        .{ .text = "زیر خط قرمز ", .decoration = deco(.single, red(), false, null, false) },
        .{ .text = "فیروزه ای ", .decoration = deco(.none, null, true, cyan(), false) },
        .{ .text = "همگی", .decoration = deco(.single, null, true, null, true) },
        .{ .text = " هیچ" },
    };
    try draw.validateTextRendering(std.testing.allocator, .{
        .name = "text_decoration_rtl",
        .family = "Noto Sans",
        .font_size = 20,
        .line_height = 26,
        .rich_spans = &spans,
        .canvas_width = 600,
        .canvas_height = 50,
        .max_ink_distance = RASTER_INK_RADIUS,
        .max_mismatched_pixels = RASTER_MAX_STRAY,
        .max_color_mass_diff_pct = RASTER_CHROMA_MASS_PCT,
    });
}

test "decorations image: bidi" {
    const spans = [_]draw.SpanSpec{
        .{ .text = "زیرخط ", .decoration = deco(.single, null, false, null, false) },
        .{ .text = "Double ", .decoration = deco(.double, null, false, null, false) },
        .{ .text = "خط ", .decoration = deco(.none, null, true, null, false) },
        .{ .text = "Over ", .decoration = deco(.none, null, false, null, true) },
        .{ .text = "Red زیر خط ", .decoration = deco(.single, red(), false, null, false) },
        .{ .text = "CyanSt ", .decoration = deco(.none, null, true, cyan(), false) },
        .{ .text = "All", .decoration = deco(.single, null, true, null, true) },
        .{ .text = " Plain" },
    };
    try draw.validateTextRendering(std.testing.allocator, .{
        .name = "text_decoration_bidi",
        .family = "Noto Sans",
        .font_size = 20,
        .line_height = 26,
        .rich_spans = &spans,
        .canvas_width = 600,
        .canvas_height = 50,
        .max_ink_distance = RASTER_INK_RADIUS,
        .max_mismatched_pixels = RASTER_MAX_STRAY,
        .max_color_mass_diff_pct = RASTER_CHROMA_MASS_PCT,
    });
}

test "decorations image: multiline bidi" {
    const spans = [_]draw.SpanSpec{
        .{ .text = "زیرخط ", .decoration = deco(.single, null, false, null, false) },
        .{ .text = "Double ", .decoration = deco(.double, null, false, null, false) },
        .{ .text = "خط ", .decoration = deco(.none, null, true, null, false) },
        .{ .text = "Over \n", .decoration = deco(.none, null, false, null, true) },
        .{ .text = "Red زیر خط ", .decoration = deco(.single, red(), false, null, false) },
        .{ .text = "CyanSt ", .decoration = deco(.none, null, true, cyan(), false) },
        .{ .text = "All", .decoration = deco(.single, null, true, null, true) },
        .{ .text = " Plain" },
    };
    try draw.validateTextRendering(std.testing.allocator, .{
        .name = "text_decoration_multiline_bidi",
        .family = "Noto Sans",
        .font_size = 20,
        .line_height = 26,
        .rich_spans = &spans,
        .canvas_width = 400,
        .canvas_height = 80,
        .max_ink_distance = RASTER_INK_RADIUS,
        .max_mismatched_pixels = RASTER_MAX_STRAY,
        .max_color_mass_diff_pct = RASTER_CHROMA_MASS_PCT,
    });
}
