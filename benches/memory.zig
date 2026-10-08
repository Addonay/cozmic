//! Heap footprint of the matched workload (`benches/matched.zig`): the
//! vendored fonts directory, a word-wrapped buffer at 80px, Inter.
//!
//! Every allocation goes through a counting wrapper around the C allocator,
//! so the report is cozmic's own heap (plus the bundled C libraries', which
//! allocate through `malloc` and are therefore *not* counted; see
//! `docs/BENCHMARKS.md` for process RSS). Prints live bytes after each phase
//! and the peak across the run.
const std = @import("std");
const c = @import("cozmic");

const Counting = struct {
    parent: std.mem.Allocator,
    live: usize = 0,
    peak: usize = 0,
    allocs: usize = 0,

    fn allocator(self: *Counting) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{
            .alloc = alloc,
            .resize = resize,
            .remap = remap,
            .free = free,
        } };
    }

    fn grew(self: *Counting, old: usize, new: usize) void {
        self.live = self.live - old + new;
        self.peak = @max(self.peak, self.live);
    }

    fn alloc(ctx: *anyopaque, len: usize, a: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *Counting = @ptrCast(@alignCast(ctx));
        const p = self.parent.rawAlloc(len, a, ra) orelse return null;
        self.allocs += 1;
        self.grew(0, len);
        return p;
    }
    fn resize(ctx: *anyopaque, m: []u8, a: std.mem.Alignment, n: usize, ra: usize) bool {
        const self: *Counting = @ptrCast(@alignCast(ctx));
        if (!self.parent.rawResize(m, a, n, ra)) return false;
        self.grew(m.len, n);
        return true;
    }
    fn remap(ctx: *anyopaque, m: []u8, a: std.mem.Alignment, n: usize, ra: usize) ?[*]u8 {
        const self: *Counting = @ptrCast(@alignCast(ctx));
        const p = self.parent.rawRemap(m, a, n, ra) orelse return null;
        self.grew(m.len, n);
        return p;
    }
    fn free(ctx: *anyopaque, m: []u8, a: std.mem.Alignment, ra: usize) void {
        const self: *Counting = @ptrCast(@alignCast(ctx));
        self.parent.rawFree(m, a, ra);
        self.grew(m.len, 0);
    }
};

fn report(phase: []const u8, counting: *const Counting) void {
    std.debug.print("MEMORY {s} live_kib={d} peak_kib={d} allocs={d}\n", .{
        phase, counting.live / 1024, counting.peak / 1024, counting.allocs,
    });
}

pub fn main(init: std.process.Init) !void {
    var counting: Counting = .{ .parent = std.heap.c_allocator };
    const a = counting.allocator();

    var fs = try c.FontSystem.init(a);
    defer fs.deinit();
    const stats = fs.loadFontsDir(init.io, "tests/fonts");
    if (stats.file_errors != 0 or !fs.hasShaper()) return error.BadFixtures;
    report("fonts-registered", &counting);

    var attrs = c.Attrs.init(a);
    defer attrs.deinit();
    attrs.family = .{ .name = "Inter" };

    const latin = try repeat(init.arena.allocator(), "The quick brown fox jumps over the lazy dog. ", 100);
    const arabic = try repeat(init.arena.allocator(), "مرحبا بالعالم ", 100);
    var buffer = try c.Buffer.initWithAllocator(a, c.Metrics.new(10, 10));
    defer buffer.deinit();
    buffer.setWrap(.word);
    buffer.setSize(80, null);

    try buffer.setText(latin, &attrs, .advanced, null);
    try buffer.shapeUntilScroll(&fs, false);
    report("latin-shaped", &counting);

    try buffer.setText(arabic, &attrs, .advanced, null);
    try buffer.shapeUntilScroll(&fs, false);
    report("arabic-shaped", &counting);

    fs.setRunCacheEnabled(false);
    try buffer.setText(latin, &attrs, .advanced, null);
    try buffer.shapeUntilScroll(&fs, false);
    report("latin-no-run-cache", &counting);
}

fn repeat(a: std.mem.Allocator, text: []const u8, count: usize) ![]u8 {
    const out = try a.alloc(u8, text.len * count);
    for (0..count) |i| @memcpy(out[i * text.len ..][0..text.len], text);
    return out;
}
