const std = @import("std");
const cozmic = @import("cozmic");

const hello_txt = @embedFile("data/hello.txt");
const arabic_txt = @embedFile("data/arabic.txt");

fn repeat(arena: std.mem.Allocator, text: []const u8, n: usize) ![]u8 {
    var out = try arena.alloc(u8, text.len * n);
    var i: usize = 0;
    while (i < n) : (i += 1) @memcpy(out[i * text.len ..][0..text.len], text);
    return out;
}

/// Mirrors upstream `format!("{s1}\n{s2}\n{s3}\n{s4}\n").repeat(10)` for
/// ShapeLine/Combined Stress.
fn buildStress(arena: std.mem.Allocator) ![]u8 {
    const s1 = try repeat(arena, "ASCII line for BidiParagraphs optimization. ", 15);
    const s2 = try repeat(arena, "Mixed English + العربية for BiDi optimizations. ", 12);
    const s3 = try repeat(arena, "Very long wrapping line that will trigger reorder optimizations multiple times through intensive layout processing. ", 8);
    const s4 = try repeat(arena, "Cache key generation line for ShapeRunKey optimization testing. ", 10);
    const joined = try std.fmt.allocPrint(arena, "{s}\n{s}\n{s}\n{s}\n", .{ s1, s2, s3, s4 });
    defer arena.free(joined);
    return repeat(arena, joined, 10);
}

fn initFontSystem(arena: std.mem.Allocator, io: std.Io) !cozmic.FontSystem {
    var fsys = try cozmic.FontSystem.init(arena);
    errdefer fsys.deinit();
    const fonts = [_]struct { file: []const u8, family: []const u8, mono: bool }{
        .{ .file = "tests/fonts/Inter-Regular.ttf", .family = "Inter", .mono = false },
        .{ .file = "tests/fonts/NotoSansArabic.ttf", .family = "Noto Sans Arabic", .mono = false },
        .{ .file = "tests/fonts/NotoSansHebrew.ttf", .family = "Noto Sans Hebrew", .mono = false },
        .{ .file = "tests/fonts/FiraMono-Medium.ttf", .family = "FiraMono", .mono = true },
    };
    for (fonts) |f| {
        const bytes = std.Io.Dir.cwd().readFileAlloc(io, f.file, arena, .limited(1 << 24)) catch continue;
        const id = fsys.dbMut().addFace(f.file, 0, &.{f.family}, f.family, cozmic.font_system.WEIGHT_NORMAL, .normal, .normal, f.mono) catch {
            arena.free(bytes);
            continue;
        };
        fsys.addFontData(id, bytes, 0, false, null) catch {};
        arena.free(bytes);
    }
    // Deterministic generic-family resolution, mirroring the upstream
    // bench-fairness patch (`set_sans_serif_family("Inter")` /
    // `set_monospace_family("FiraMono")`). No system fonts are registered, so
    // generic queries can only resolve to these vendored faces.
    try fsys.dbMut().setSansFamily("Inter");
    try fsys.dbMut().setMonoFamily("FiraMono");
    return fsys;
}

const default_iters: usize = 20;
const default_warmup: usize = 5;
/// `--quick` / `COZMIC_BENCH_QUICK=1`: smallest set that still yields a
/// median and exercises every row, for CI smoke runs of the harness.
const quick_iters: usize = 3;
const quick_warmup: usize = 1;

fn truthy(value: []const u8) bool {
    return value.len != 0 and
        !std.mem.eql(u8, value, "0") and
        !std.ascii.eqlIgnoreCase(value, "false") and
        !std.ascii.eqlIgnoreCase(value, "no");
}

fn parseArgs(
    args: []const []const u8,
    environ: *const std.process.Environ.Map,
) struct { iters: usize, warmup: usize, json: bool, quick: bool } {
    var iters: ?usize = null;
    var warmup: ?usize = null;
    var json = false;
    var quick = false;
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--iter") and i + 1 < args.len) {
            iters = std.fmt.parseInt(usize, args[i + 1], 10) catch iters;
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--warmup") and i + 1 < args.len) {
            warmup = std.fmt.parseInt(usize, args[i + 1], 10) catch warmup;
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--format") and i + 1 < args.len) {
            json = std.mem.eql(u8, args[i + 1], "json");
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--quick")) {
            quick = true;
        }
    }
    const env_quick = if (environ.get("COZMIC_BENCH_QUICK")) |v| truthy(v) else false;
    const use_quick = quick or env_quick;
    return .{
        .iters = @max(iters orelse if (use_quick) quick_iters else default_iters, 1),
        .warmup = warmup orelse if (use_quick) quick_warmup else default_warmup,
        .json = json,
        .quick = use_quick,
    };
}

fn timeCold(
    arena: std.mem.Allocator,
    fsys: *cozmic.FontSystem,
    text: []const u8,
    width: ?f32,
    iters: usize,
    warmup: usize,
    io: std.Io,
) !struct { mean_ns: f64, median_ns: f64, glyphs: usize } {
    var attrs = cozmic.attrs.Attrs.init(arena);
    defer attrs.deinit();
    // Per-iteration scratch arena: buffer/layout state is released between
    // iterations instead of accumulating in the process arena (the stress
    // samples otherwise grow into the GB range and OOM the harness).
    var scratch_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer scratch_state.deinit();
    const scratch = scratch_state.allocator();
    var glyphs: usize = 0;
    var k: usize = 0;
    while (k < warmup) : (k += 1) {
        _ = scratch_state.reset(.{ .retain_with_limit = 64 << 20 });
        var buf = try cozmic.Buffer.initWithAllocator(scratch, cozmic.Metrics.new(14, 20));
        defer buf.deinit();
        try buf.setText(text, &attrs, .advanced, null);
        buf.setSize(width, null);
        try buf.shapeUntilScroll(fsys, false);
        var it = buf.layoutRuns();
        while (it.next()) |_| {}
    }
    var times = try arena.alloc(u64, iters);
    defer arena.free(times);
    k = 0;
    while (k < iters) : (k += 1) {
        _ = scratch_state.reset(.{ .retain_with_limit = 64 << 20 });
        var buf = try cozmic.Buffer.initWithAllocator(scratch, cozmic.Metrics.new(14, 20));
        defer buf.deinit();
        try buf.setText(text, &attrs, .advanced, null);
        buf.setSize(width, null);
        const t0 = std.Io.Clock.now(.awake, io);
        try buf.shapeUntilScroll(fsys, false);
        var it = buf.layoutRuns();
        var g: usize = 0;
        while (it.next()) |run| g += run.glyphs.len;
        const t1 = std.Io.Clock.now(.awake, io);
        times[k] = @intCast(t0.durationTo(t1).nanoseconds);
        glyphs = g;
    }
    std.mem.sort(u64, times, {}, std.sort.asc(u64));
    var sum: f64 = 0;
    for (times) |t| sum += @floatFromInt(t);
    return .{
        .mean_ns = sum / @as(f64, @floatFromInt(times.len)),
        .median_ns = @floatFromInt(times[times.len / 2]),
        .glyphs = glyphs,
    };
}

/// Mirrors benches/text_shaping_benchmarks.rs (Advanced only, Metrics 14/20,
/// width 500): ASCII fast path, BiDi mixed, hello.txt mixed, layout-heavy,
/// combined stress, plus BidiParagraphs counting.
pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();
    const io = init.io;
    const args = try init.minimal.args.toSlice(arena);
    const opts = parseArgs(args[1..], init.environ_map);

    var out_buf: [8192]u8 = undefined;
    // Streaming (not positional) writes: stdout may be a redirected regular
    // file shared with the other bench process, and positional writers each
    // start at offset 0, which clobbers earlier output.
    var out: std.Io.File.Writer = .initStreaming(.stdout(), io, &out_buf);
    const w = &out.interface;

    var fsys = try initFontSystem(arena, io);
    defer fsys.deinit();
    const ascii50 = try repeat(arena, "Pure ASCII text for BidiParagraphs optimization testing.\n", 50);
    const bidi30 = try repeat(arena, "Mixed English and العربية النص العربي text for BiDi testing.\nThis tests adjust_levels and combined BiDi optimizations.\n", 30);
    const longwrap = try repeat(arena, "This is a very long line that will wrap multiple times and stress the reorder optimization through intensive layout processing with comprehensive buffer reuse testing. ", 30);
    const stress = try buildStress(arena);
    const para_ascii = try repeat(arena, "Simple ASCII text\nwith multiple lines\n", 50);
    const para_mixed = try repeat(arena, "Mixed English and العربية text\nwith multiple lines\n", 30);

    const cases = [_]struct { name: []const u8, text: []const u8 }{
        .{ .name = "ascii-fast-path", .text = ascii50 },
        .{ .name = "bidi-mixed", .text = bidi30 },
        .{ .name = "hello-mixed", .text = hello_txt },
        .{ .name = "layout-heavy", .text = longwrap },
        .{ .name = "combined-stress", .text = stress },
        .{ .name = "arabic", .text = arabic_txt[0..@min(arabic_txt.len, 4096)] },
    };

    if (!opts.json) try w.print("cozmic bench-shaping: {d} cases (iters={d} warmup={d}{s})\n", .{ cases.len, opts.iters, opts.warmup, if (opts.quick) " quick" else "" });
    for (cases) |c| {
        const r = try timeCold(arena, &fsys, c.text, 500, opts.iters, opts.warmup, io);
        if (opts.json) {
            try w.print("{{\"bench\":\"shaping/{s}\",\"iters\":{d},\"mean_ns\":{d:.1},\"median_ns\":{d:.1},\"glyphs\":{d}}}\n", .{ c.name, opts.iters, r.mean_ns, r.median_ns, r.glyphs });
        } else {
            try w.print("  {s} cold glyphs={d} mean={d:.0}ns median={d:.0}ns\n", .{ c.name, r.glyphs, r.mean_ns, r.median_ns });
        }
    }
    // BidiParagraphs counting (no FontSystem, mirrors Rust BidiParagraphs benches).
    for ([_]struct { name: []const u8, text: []const u8 }{
        .{ .name = "bidi-paras-ascii", .text = para_ascii },
        .{ .name = "bidi-paras-mixed", .text = para_mixed },
    }) |c| {
        const t0 = std.Io.Clock.now(.awake, io);
        var n: usize = 0;
        var k: usize = 0;
        while (k < opts.iters) : (k += 1) {
            var it = cozmic.bidi_para.BidiParagraphs.init(c.text);
            while (it.next()) |_| n += 1;
        }
        const t1 = std.Io.Clock.now(.awake, io);
        const total_ns: f64 = @floatFromInt(@as(u64, @intCast(t0.durationTo(t1).nanoseconds)));
        const mean = total_ns / @as(f64, @floatFromInt(opts.iters));
        if (opts.json) {
            try w.print("{{\"bench\":\"shaping/{s}\",\"iters\":{d},\"mean_ns\":{d:.1},\"median_ns\":{d:.1},\"glyphs\":{d}}}\n", .{ c.name, opts.iters, mean, mean, n / @max(opts.iters, 1) });
        } else {
            try w.print("  {s} paras={d} mean={d:.0}ns/iter\n", .{ c.name, n / @max(opts.iters, 1), mean });
        }
    }
    try w.flush();
}
