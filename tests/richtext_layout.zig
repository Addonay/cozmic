//! Port of upstream `tests/richtext_layout.rs`: empty lines at the start/end
//! of a span use that span's metrics, not the buffer default.

const std = @import("std");
const cozmic = @import("cozmic");
const fonts = @import("common/fonts.zig");

test "richtext: empty lines use span metrics" {
    const alloc = std.testing.allocator;
    var fs = try fonts.fontSystem(alloc);
    defer fs.deinit();

    var attrs = fonts.attrsWithFamily(alloc, "Inter");
    defer attrs.deinit();
    var small = fonts.attrsWithFamily(alloc, "Inter");
    defer small.deinit();
    const small_metrics = cozmic.Metrics.relative(8, 1.2);
    small.metrics_opt = cozmic.attrs.CacheMetrics.from_metrics(small_metrics);

    var buffer = try cozmic.Buffer.initWithAllocator(alloc, cozmic.Metrics.new(32, 44));
    defer buffer.deinit();
    var borrowed = buffer.borrowWith(&fs);

    // The empty lines from \n\n at start and end should use 8.0 * 1.2 = 9.6.
    // All newlines are inside the small span so the empty lines are clearly
    // within it.
    try borrowed.setRichText(
        &.{
            .{ .text = "Before", .attrs = attrs },
            .{ .text = "\n\n\nSmall\n\n", .attrs = small },
            .{ .text = "After", .attrs = attrs },
        },
        &attrs,
        .advanced,
        null,
    );
    borrowed.setSize(500.0, 500.0);

    var heights: [8]f32 = undefined;
    var count: usize = 0;
    var it = try borrowed.layoutRuns();
    while (it.next()) |run| {
        if (count < heights.len) heights[count] = run.line_height;
        count += 1;
    }

    try std.testing.expectEqual(@as(usize, 6), count);
    const eps = 0.1;
    try std.testing.expectApproxEqAbs(@as(f32, 44.0), heights[0], eps);
    try std.testing.expectApproxEqAbs(@as(f32, 9.6), heights[1], eps);
    try std.testing.expectApproxEqAbs(@as(f32, 9.6), heights[2], eps);
    try std.testing.expectApproxEqAbs(@as(f32, 9.6), heights[4], eps);
    try std.testing.expectApproxEqAbs(@as(f32, 44.0), heights[5], eps);
}
