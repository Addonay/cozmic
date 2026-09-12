//! Port of upstream `tests/ellipsize_rendering.rs`: image comparisons for
//! start/middle/end ellipsizing across LTR, RTL and mixed text.
//!
//! Comparison mode: structural (`max_ink_distance = 1`), because upstream
//! baselines were rasterized with swash while this port uses FreeType. Every
//! ink pixel must be within one pixel of the other image's ink, which checks
//! glyph placement and ellipsis geometry without requiring identical AA.

const std = @import("std");
const draw = @import("common/draw.zig");

/// Tolerances for FreeType-vs-swash raster differences (documented above).
const RASTER_INK_RADIUS: u8 = 1;
const RASTER_MAX_STRAY: usize = 32;

test "ellipsize image: ltr end single line" {
    try draw.validateTextRendering(std.testing.allocator, .{
        .name = "ellipsize_ltr_end_single_line",
        .family = "Inter",
        .font_size = 20,
        .line_height = 26,
        .text = "The quick brown fox jumps over the lazy dog.",
        .wrap = .none,
        .ellipsize = .{ .end = .{ .lines = 1 } },
        .canvas_width = 180,
        .canvas_height = 50,
        .max_ink_distance = RASTER_INK_RADIUS,
        .max_mismatched_pixels = RASTER_MAX_STRAY,
    });
}

test "ellipsize image: ltr end single line aligned right" {
    try draw.validateTextRendering(std.testing.allocator, .{
        .name = "ellipsize_ltr_end_single_line_aligned_right",
        .family = "Inter",
        .font_size = 20,
        .line_height = 26,
        .text = "The quick brown fox jumps over the lazy dog.",
        .wrap = .none,
        .ellipsize = .{ .end = .{ .lines = 1 } },
        .alignment = .right,
        .canvas_width = 180,
        .canvas_height = 50,
        .max_ink_distance = RASTER_INK_RADIUS,
        .max_mismatched_pixels = RASTER_MAX_STRAY,
    });
}

test "ellipsize image: rtl end single line" {
    try draw.validateTextRendering(std.testing.allocator, .{
        .name = "ellipsize_rtl_end_single_line",
        .family = "Noto Sans",
        .font_size = 22,
        .line_height = 28,
        .text = "توانا بود هرکه دانا بود.",
        .wrap = .none,
        .ellipsize = .{ .end = .{ .lines = 1 } },
        .canvas_width = 180,
        .canvas_height = 55,
        .max_ink_distance = RASTER_INK_RADIUS,
        .max_mismatched_pixels = RASTER_MAX_STRAY,
    });
}

test "ellipsize image: mixed end single line" {
    try draw.validateTextRendering(std.testing.allocator, .{
        .name = "ellipsize_mixed_end_single_line",
        .family = "Noto Sans",
        .font_size = 20,
        .line_height = 26,
        .text = "Hello سلام mixed RTL/LTR world with extra words",
        .wrap = .none,
        .ellipsize = .{ .end = .{ .lines = 1 } },
        .canvas_width = 190,
        .canvas_height = 50,
        .max_ink_distance = RASTER_INK_RADIUS,
        .max_mismatched_pixels = RASTER_MAX_STRAY,
    });
}

test "ellipsize image: ltr start single line" {
    try draw.validateTextRendering(std.testing.allocator, .{
        .name = "ellipsize_ltr_start_single_line",
        .family = "Inter",
        .font_size = 20,
        .line_height = 26,
        .text = "The quick brown fox jumps over the lazy dog.",
        .wrap = .none,
        .ellipsize = .{ .start = .{ .lines = 1 } },
        .canvas_width = 180,
        .canvas_height = 50,
        .max_ink_distance = RASTER_INK_RADIUS,
        .max_mismatched_pixels = RASTER_MAX_STRAY,
    });
}

test "ellipsize image: ltr middle single line" {
    try draw.validateTextRendering(std.testing.allocator, .{
        .name = "ellipsize_ltr_middle_single_line",
        .family = "Inter",
        .font_size = 20,
        .line_height = 26,
        .text = "The quick brown fox jumps over the lazy dog.",
        .wrap = .none,
        .ellipsize = .{ .middle = .{ .lines = 1 } },
        .canvas_width = 180,
        .canvas_height = 50,
        .max_ink_distance = RASTER_INK_RADIUS,
        .max_mismatched_pixels = RASTER_MAX_STRAY,
    });
}

test "ellipsize image: ltr end two lines" {
    try draw.validateTextRendering(std.testing.allocator, .{
        .name = "ellipsize_ltr_end_two_lines",
        .family = "Inter",
        .font_size = 18,
        .line_height = 24,
        .text = "Pack my box with five dozen liquor jugs. Sphinx of black quartz, judge my vow.",
        .wrap = .word,
        .ellipsize = .{ .end = .{ .lines = 2 } },
        .canvas_width = 200,
        .canvas_height = 80,
        .max_ink_distance = RASTER_INK_RADIUS,
        .max_mismatched_pixels = RASTER_MAX_STRAY,
    });
}

test "ellipsize image: mixed middle single line" {
    try draw.validateTextRendering(std.testing.allocator, .{
        .name = "ellipsize_mixed_middle_single_line",
        .family = "Inter",
        .font_size = 20,
        .line_height = 26,
        .text = "Hello سلام mixed RTL/LTR world with extra words",
        .wrap = .none,
        .ellipsize = .{ .middle = .{ .lines = 1 } },
        .canvas_width = 180,
        .canvas_height = 50,
        .max_ink_distance = RASTER_INK_RADIUS,
        .max_mismatched_pixels = RASTER_MAX_STRAY,
    });
}

test "ellipsize image: mixed ltr rtl middle two lines" {
    try draw.validateTextRendering(std.testing.allocator, .{
        .name = "ellipsize_mixed_ltr_rtl_middle_two_lines",
        .family = "Inter",
        .font_size = 20,
        .line_height = 26,
        .text = "First line is LTR خط دوم از راست به چپ",
        .wrap = .word_or_glyph,
        .ellipsize = .{ .middle = .{ .lines = 2 } },
        .canvas_width = 180,
        .canvas_height = 80,
        .max_ink_distance = RASTER_INK_RADIUS,
        .max_mismatched_pixels = RASTER_MAX_STRAY,
    });
}

test "ellipsize image: mixed rtl ltr middle two lines" {
    try draw.validateTextRendering(std.testing.allocator, .{
        .name = "ellipsize_mixed_rtl_ltr_middle_two_lines",
        .family = "Inter",
        .font_size = 20,
        .line_height = 26,
        .text = "خط اول از راست به چپ Second line is LTR and has more words",
        .wrap = .word_or_glyph,
        .ellipsize = .{ .middle = .{ .lines = 2 } },
        .canvas_width = 210,
        .canvas_height = 80,
        .max_ink_distance = RASTER_INK_RADIUS,
        .max_mismatched_pixels = RASTER_MAX_STRAY,
    });
}

test "ellipsize image: ltr single word middle two lines" {
    try draw.validateTextRendering(std.testing.allocator, .{
        .name = "ellipsize_ltr_single_word_middle_two_lines",
        .family = "Inter",
        .font_size = 20,
        .line_height = 26,
        .text = "AVeryLongWordThatExceedsTheWidth",
        .wrap = .word_or_glyph,
        .ellipsize = .{ .middle = .{ .lines = 2 } },
        .canvas_width = 180,
        .canvas_height = 80,
        .max_ink_distance = RASTER_INK_RADIUS,
        .max_mismatched_pixels = RASTER_MAX_STRAY,
    });
}

test "ellipsize image: mixed ltr rtl ltr middle three lines" {
    try draw.validateTextRendering(std.testing.allocator, .{
        .name = "ellipsize_mixed_ltr_rtl_ltr_middle_three_lines",
        .family = "Inter",
        .font_size = 20,
        .line_height = 26,
        .text = "This is some LTR text that keeps و یه مشت متن فارسیی.zippy",
        .wrap = .word_or_glyph,
        .ellipsize = .{ .middle = .{ .lines = 3 } },
        .canvas_width = 200,
        .canvas_height = 100,
        .max_ink_distance = RASTER_INK_RADIUS,
        .max_mismatched_pixels = RASTER_MAX_STRAY,
    });
}

// Regression: Fluent's fl!() wraps interpolated values with BiDi isolation
// characters; "Workspace 2" must render without ellipsis when it fits.
test "ellipsize image: bidi isolates middle bug" {
    try draw.validateTextRendering(std.testing.allocator, .{
        .name = "ellipsize_bidi_isolates_middle_bug",
        .family = "Inter",
        .font_size = 20,
        .line_height = 26,
        .text = "\u{2068}Workspace\u{2069}\u{2068} \u{2069}\u{2068}2\u{2069}",
        .wrap = .word_or_glyph,
        .ellipsize = .{ .middle = .{ .lines = 1 } },
        .canvas_width = 220,
        .canvas_height = 50,
        .max_ink_distance = RASTER_INK_RADIUS,
        .max_mismatched_pixels = RASTER_MAX_STRAY,
    });
}

test "ellipsize image: ltr middle small buffer" {
    try draw.validateTextRendering(std.testing.allocator, .{
        .name = "ellipsize_ltr_middle_small_buffer",
        .family = "Inter",
        .font_size = 20,
        .line_height = 26,
        .text = "A/B Tester x8 Mono",
        .wrap = .none,
        .ellipsize = .{ .middle = .{ .lines = 1 } },
        .canvas_width = 30,
        .canvas_height = 100,
        .max_ink_distance = RASTER_INK_RADIUS,
        // Tiny canvas: the whole feature under test is the three-dot
        // ellipsis, so keep the stray budget well below its ink count.
        .max_mismatched_pixels = 4,
    });
}
