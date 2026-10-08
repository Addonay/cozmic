const std = @import("std");
const c = @import("cozmic");
pub fn main(init: std.process.Init) !void {
    const a = init.arena.allocator();
    var fs = try c.FontSystem.init(std.heap.c_allocator);
    defer fs.deinit();
    const stats = fs.loadFontsDir(init.io, "tests/fonts");
    if (stats.file_errors != 0 or !fs.hasShaper()) return error.BadFixtures;
    fs.setRunCacheEnabled(false);
    var attrs = c.Attrs.init(a);
    defer attrs.deinit();
    attrs.family = .{ .name = "Inter" };
    const latin = try repeat(a, "The quick brown fox jumps over the lazy dog. ", 100);
    const arabic = try repeat(a, "مرحبا بالعالم ", 100);
    for ([_]struct { name: []const u8, text: []const u8 }{ .{ .name = "small", .text = "Hello, world!" }, .{ .name = "latin", .text = latin }, .{ .name = "arabic", .text = arabic } }) |case| {
        var times: [100]u64 = undefined;
        var glyphs: usize = 0;
        var checksum: f32 = 0;
        for (0..105) |i| {
            var b = try c.Buffer.initWithAllocator(std.heap.c_allocator, c.Metrics.new(10, 10));
            defer b.deinit();
            b.setWrap(.word);
            b.setSize(80, null);
            try b.setText(case.text, &attrs, .advanced, null);
            const start = std.Io.Clock.now(.awake, init.io);
            try b.shapeUntilScroll(&fs, false);
            glyphs = 0;
            checksum = 0;
            var it = b.layoutRuns();
            while (it.next()) |r| for (r.glyphs) |g| {
                glyphs += 1;
                checksum += g.w;
            };
            const elapsed = start.durationTo(std.Io.Clock.now(.awake, init.io)).nanoseconds;
            std.mem.doNotOptimizeAway(glyphs);
            std.mem.doNotOptimizeAway(checksum);
            if (i >= 5) times[i - 5] = @intCast(elapsed);
        }
        std.mem.sort(u64, &times, {}, std.sort.asc(u64));
        std.debug.print("MATCHED {s} median_ns={d} glyphs={d} width_sum={d}\n", .{ case.name, times[50], glyphs, checksum });
    }
}
fn repeat(a: std.mem.Allocator, text: []const u8, count: usize) ![]u8 {
    const out = try a.alloc(u8, text.len * count);
    for (0..count) |i| @memcpy(out[i * text.len ..][0..text.len], text);
    return out;
}
