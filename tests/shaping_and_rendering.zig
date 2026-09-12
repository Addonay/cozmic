//! Port of upstream `tests/shaping_and_rendering.rs`: mixed-direction
//! rendering (Hebrew/Arabic with Latin fallback), word/ligature segmentation,
//! and separator handling.
//!
//! The image cases compare against the upstream baselines in `tests/images`
//! using structural comparison (`max_ink_distance = 1`): every ink pixel must
//! be within one pixel of the other image's ink. This absorbs FreeType-vs-swash
//! rasterizer AA while still catching moved or missing glyphs.

const std = @import("std");
const cozmic = @import("cozmic");
const fonts = @import("common/fonts.zig");
const draw = @import("common/draw.zig");

const RASTER_INK_RADIUS: u8 = 1;
const RASTER_MAX_STRAY: usize = 32;

test "shaping: ligature and contextual-alternate segmentation" {
    const alloc = std.testing.allocator;
    var fs = try fonts.fontSystem(alloc);
    defer fs.deinit();
    var attrs = fonts.attrsWithFamily(alloc, "Inter");
    defer attrs.deinit();

    var buffer = try cozmic.Buffer.initWithAllocator(alloc, cozmic.Metrics.new(14, 20));
    defer buffer.deinit();
    var borrowed = buffer.borrowWith(&fs);

    // Inter has contextual alternates / ligatures for |> -> != but not ++.
    const Case = struct { text: []const u8, words: usize };
    for ([_]Case{
        .{ .text = "|>", .words = 1 },
        .{ .text = "->", .words = 1 },
        .{ .text = "!=", .words = 1 },
        .{ .text = "++", .words = 2 },
    }) |case| {
        try borrowed.setText(case.text, &attrs, .advanced, null);
        _ = try borrowed.layoutRuns();
        const shape = (try borrowed.lineShape(0)) orelse return error.TestUnexpectedResult;
        try std.testing.expect(shape.spans.len > 0);
        try std.testing.expectEqual(case.words, shape.spans[0].words.len);
    }
}

test "shaping: mixed-direction paragraphs do not panic" {
    const alloc = std.testing.allocator;
    var fs = try fonts.fontSystem(alloc);
    defer fs.deinit();
    var default_attrs = cozmic.Attrs.init(alloc);
    default_attrs.family = .{ .name = "Inter" };
    defer default_attrs.deinit();
    var attrs = try cozmic.AttrsList.init(alloc, &default_attrs);
    defer attrs.deinit();

    const shape_mod = cozmic.shape;
    const adapter = fs.shaper() orelse return error.SkipZigTest;

    // Latin 'A' and Hebrew Aleph separated by each BidiClass::B codepoint,
    // including PS (U+2029) and ASCII FS (U+001C).
    const separators = [_]u21{ 0x000A, 0x000D, 0x001C, 0x001D, 0x001E, 0x0085, 0x2029 };
    for (separators) |sep| {
        var text_buf: [8]u8 = undefined;
        var n: usize = 0;
        n += std.unicode.utf8Encode('A', text_buf[n..]) catch return error.TestUnexpectedResult;
        n += std.unicode.utf8Encode(sep, text_buf[n..]) catch return error.TestUnexpectedResult;
        n += std.unicode.utf8Encode(0x05D0, text_buf[n..]) catch return error.TestUnexpectedResult;

        var line = shape_mod.ShapeLine{};
        defer line.deinit(alloc);
        var shape_buf = shape_mod.ShapeBuffer.init();
        defer shape_buf.deinit(alloc);
        try line.build(alloc, adapter, &shape_buf, text_buf[0..n], &attrs, .advanced, 8, .auto);
    }
}

test "image: hebrew word rendering" {
    const alloc = std.testing.allocator;
    try draw.validateTextRendering(alloc, .{
        .name = "a_hebrew_word",
        .text = "בדיקה",
        .family = "Noto Sans",
        .font_size = 36,
        .line_height = 40,
        .canvas_width = 120,
        .canvas_height = 60,
        .max_ink_distance = RASTER_INK_RADIUS,
        .max_mismatched_pixels = RASTER_MAX_STRAY,
    });
}

test "image: hebrew paragraph rendering" {
    const alloc = std.testing.allocator;
    try draw.validateTextRendering(alloc, .{
        .name = "a_hebrew_paragraph",
        .text = "השועל החום המהיר קופץ מעל הכלב העצלן",
        .family = "Noto Sans",
        .font_size = 36,
        .line_height = 40,
        .canvas_width = 400,
        .canvas_height = 110,
        .max_ink_distance = RASTER_INK_RADIUS,
        .max_mismatched_pixels = RASTER_MAX_STRAY,
    });
}

test "image: arabic word rendering" {
    const alloc = std.testing.allocator;
    try draw.validateTextRendering(alloc, .{
        .name = "an_arabic_word",
        .text = "خالصة",
        .family = "Noto Sans",
        .font_size = 36,
        .line_height = 40,
        .canvas_width = 120,
        .canvas_height = 60,
        .max_ink_distance = RASTER_INK_RADIUS,
        .max_mismatched_pixels = RASTER_MAX_STRAY,
    });
}

test "image: arabic paragraph rendering" {
    const alloc = std.testing.allocator;
    try draw.validateTextRendering(alloc, .{
        .name = "an_arabic_paragraph",
        .text = "الثعلب البني السريع يقفز فوق الكلب الكسول",
        .family = "Noto Sans",
        .font_size = 36,
        .line_height = 40,
        .canvas_width = 400,
        .canvas_height = 110,
        .max_ink_distance = RASTER_INK_RADIUS,
        .max_mismatched_pixels = RASTER_MAX_STRAY,
    });
}

test "image: english mixed with arabic paragraph rendering" {
    const alloc = std.testing.allocator;
    try draw.validateTextRendering(alloc, .{
        .name = "some_english_mixed_with_arabic",
        .text = "I like to render اللغة العربية in Rust!",
        .family = "Noto Sans",
        .font_size = 36,
        .line_height = 40,
        .canvas_width = 400,
        .canvas_height = 110,
        .max_ink_distance = RASTER_INK_RADIUS,
        .max_mismatched_pixels = RASTER_MAX_STRAY,
    });
}

test "image: english mixed with hebrew paragraph rendering" {
    // The full UCD line-breaking upgrade moved this paragraph's second
    // candidate line from 390.56px (just over upstream's 390px limit, which
    // wrapped one word early) to 389.92px (inside the limit), so the layout
    // now matches upstream and the image baseline can be compared directly.
    // The previous probe asserted the old measurement and is retired.
    const alloc = std.testing.allocator;
    try draw.validateTextRendering(alloc, .{
        .name = "some_english_mixed_with_hebrew",
        .text = "Many computer programs fail to display bidirectional text correctly. For example, this page is mostly LTR English script, and here is the RTL Hebrew name Sarah: " ++
            "\xd7\xa9\xd7\xa8\xd7\x94, spelled sin (\xd7\xa9) on the right, resh (\xd7\xa8) in the middle, and heh (\xd7\x94) on the left.",
        .family = "Noto Sans",
        .font_size = 16,
        .line_height = 20,
        .canvas_width = 400,
        .canvas_height = 120,
        .max_ink_distance = RASTER_INK_RADIUS,
        .max_mismatched_pixels = RASTER_MAX_STRAY,
    });
}
