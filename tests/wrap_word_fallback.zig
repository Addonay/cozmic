//! Port of upstream `tests/wrap_word_fallback.rs`: a single word wider than the
//! buffer must fall back to glyph wrapping, so no layout line ever overflows
//! the configured width.

const std = @import("std");
const cozmic = @import("cozmic");
const fonts = @import("common/fonts.zig");

test "wrap: word fallback never overflows the buffer width" {
    const alloc = std.testing.allocator;
    var fs = try fonts.fontSystem(alloc);
    defer fs.deinit();

    var attrs = fonts.attrsWithFamily(alloc, "Inter");
    defer attrs.deinit();

    var buffer = try cozmic.Buffer.initWithAllocator(alloc, cozmic.Metrics.new(14, 20));
    defer buffer.deinit();
    var borrowed = buffer.borrowWith(&fs);

    borrowed.setWrap(.word_or_glyph);
    borrowed.setSize(50.0, 1000.0);
    try borrowed.setText(
        "Lorem ipsum dolor sit amet, qui minim labore adipisicing minim sint cillum sint consectetur cupidatat.",
        &attrs,
        .advanced,
        null,
    );

    var measured: f32 = 0;
    var runs: usize = 0;
    var it = try borrowed.layoutRuns();
    while (it.next()) |run| {
        measured = @max(measured, run.line_w);
        runs += 1;
    }

    // The assertion below is vacuous with zero runs, so require real output.
    try std.testing.expect(runs > 0);
    const limit = buffer.size().width orelse 0;
    try std.testing.expect(measured <= limit);
}
