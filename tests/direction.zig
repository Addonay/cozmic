//! Port of upstream `tests/direction.rs`: paragraph base-direction handling.
//! Runs the vendored `tests/fonts` corpus through the real HarfBuzz pipeline.

const std = @import("std");
const cozmic = @import("cozmic");
const fonts = @import("common/fonts.zig");

fn firstRunRtl(buffer: *const cozmic.Buffer) !bool {
    var it = buffer.layoutRuns();
    // An empty layout is a failure, never a silent "LTR": upstream expects at
    // least one run in every direction test.
    const run = it.next() orelse return error.TestUnexpectedResult;
    return run.rtl;
}

fn makeBuffer(
    alloc: std.mem.Allocator,
    fs: *cozmic.FontSystem,
    text: []const u8,
    direction: cozmic.Direction,
) !cozmic.Buffer {
    var buffer = try cozmic.Buffer.initWithAllocator(alloc, cozmic.Metrics.new(14, 20));
    errdefer buffer.deinit();
    buffer.setWrap(.none);
    buffer.setDirection(direction);
    var attrs = cozmic.Attrs.init(alloc);
    defer attrs.deinit();
    try buffer.setText(text, &attrs, .advanced, null);
    try buffer.shapeUntilScroll(fs, false);
    return buffer;
}

test "direction: auto detects per paragraph" {
    const alloc = std.testing.allocator;
    var fs = try fonts.fontSystem(alloc);
    defer fs.deinit();

    // Default Auto behavior: direction follows the first strong character.
    var ltr = try makeBuffer(alloc, &fs, "hello", .auto);
    defer ltr.deinit();
    try std.testing.expect(!(try firstRunRtl(&ltr)));

    var rtl = try makeBuffer(alloc, &fs, "سلام", .auto);
    defer rtl.deinit();
    try std.testing.expect(try firstRunRtl(&rtl));
}

test "direction: forced RTL overrides LTR content" {
    const alloc = std.testing.allocator;
    var fs = try fonts.fontSystem(alloc);
    defer fs.deinit();

    var buffer = try makeBuffer(alloc, &fs, "hello", .right_to_left);
    defer buffer.deinit();
    try std.testing.expect(try firstRunRtl(&buffer));
}

test "direction: forced LTR overrides RTL content" {
    const alloc = std.testing.allocator;
    var fs = try fonts.fontSystem(alloc);
    defer fs.deinit();

    var buffer = try makeBuffer(alloc, &fs, "سلام", .left_to_right);
    defer buffer.deinit();
    try std.testing.expect(!(try firstRunRtl(&buffer)));
}

test "direction: forced LTR keeps RTL glyphs" {
    const alloc = std.testing.allocator;
    var fs = try fonts.fontSystem(alloc);
    defer fs.deinit();

    // A line whose content is entirely RTL must still produce glyphs when the
    // base direction is forced to LTR (incongruent span on the no-wrap path).
    var buffer = try makeBuffer(alloc, &fs, "سلام", .left_to_right);
    defer buffer.deinit();
    var it = buffer.layoutRuns();
    const run = it.next() orelse return error.TestUnexpectedResult;
    try std.testing.expect(run.glyphs.len > 0);
}

test "direction: force LTR overrides first strong RTL" {
    const alloc = std.testing.allocator;
    var fs = try fonts.fontSystem(alloc);
    defer fs.deinit();

    var buffer = try makeBuffer(alloc, &fs, "   سلام", .left_to_right);
    defer buffer.deinit();
    try std.testing.expect(!(try firstRunRtl(&buffer)));
}

test "direction: force LTR overrides weak" {
    const alloc = std.testing.allocator;
    var fs = try fonts.fontSystem(alloc);
    defer fs.deinit();

    var buffer = try makeBuffer(alloc, &fs, "   ()", .left_to_right);
    defer buffer.deinit();
    try std.testing.expect(!(try firstRunRtl(&buffer)));

    buffer.setDirection(.right_to_left);
    try buffer.shapeUntilScroll(&fs, false);
    try std.testing.expect(try firstRunRtl(&buffer));
}

test "direction: changing direction reshapes cached lines" {
    const alloc = std.testing.allocator;
    var fs = try fonts.fontSystem(alloc);
    defer fs.deinit();

    var buffer = try cozmic.Buffer.initWithAllocator(alloc, cozmic.Metrics.new(14, 20));
    defer buffer.deinit();
    var attrs = cozmic.Attrs.init(alloc);
    defer attrs.deinit();
    try buffer.setText("hello", &attrs, .advanced, null);
    try buffer.shapeUntilScroll(&fs, false);
    try std.testing.expect(!(try firstRunRtl(&buffer)));

    // Switching direction must invalidate the already-shaped line.
    buffer.setDirection(.right_to_left);
    try buffer.shapeUntilScroll(&fs, false);
    try std.testing.expect(try firstRunRtl(&buffer));
}
