const std = @import("std");
const cozmic = @import("cozmic");

const arabic_txt = @embedFile("data/arabic.txt");
const hebrew_txt = @embedFile("data/hebrew.txt");
const emoji_txt = @embedFile("data/emoji.txt");
const hello_txt = @embedFile("data/hello.txt");
const moby_txt = @embedFile("data/moby.txt");

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

/// Which shaped-run-cache semantics a timed row measures. `.off` matches
/// upstream's default features (cache disabled); `.warm` keeps the cache on,
/// lets the warmup loop fill it, and times steady-state hits — what editors
/// and frame loops pay after the first render.
const CacheMode = enum { off, warm };

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

fn timeIt(
    arena: std.mem.Allocator,
    fsys: *cozmic.FontSystem,
    text: []const u8,
    wrap: cozmic.Wrap,
    shaping: cozmic.Shaping,
    width: ?f32,
    iters: usize,
    warmup: usize,
    io: std.Io,
    cache: CacheMode,
) !struct { mean_ns: f64, median_ns: f64, glyphs: usize, runs: usize } {
    var attrs = cozmic.attrs.Attrs.init(arena);
    defer attrs.deinit();
    // Layout state is allocated per iteration and released by resetting this
    // arena. Using the process arena here accumulated every iteration of every
    // case (the 361 KB emoji sample alone grows past several GB), which OOM'd
    // the harness. `retain_with_limit` keeps hot pages between iterations
    // without letting one large case pin an unbounded amount of memory.
    var scratch_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer scratch_state.deinit();
    const scratch = scratch_state.allocator();
    var glyphs: usize = 0;
    var runs: usize = 0;
    switch (cache) {
        .off => fsys.setRunCacheEnabled(false),
        .warm => {
            fsys.setRunCacheEnabled(true);
            // Cold start here; the warmup loop below fills the cache, so the
            // timed iterations measure steady-state hits only.
            fsys.clearRunCache();
        },
    }
    // Warmup (discard).
    var k: usize = 0;
    while (k < warmup) : (k += 1) {
        _ = scratch_state.reset(.{ .retain_with_limit = 64 << 20 });
        var buf = try cozmic.Buffer.initWithAllocator(scratch, cozmic.Metrics.new(10, 10));
        defer buf.deinit();
        try buf.setText(text, &attrs, shaping, null);
        buf.setWrap(wrap);
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
        var buf = try cozmic.Buffer.initWithAllocator(scratch, cozmic.Metrics.new(10, 10));
        defer buf.deinit();
        try buf.setText(text, &attrs, shaping, null);
        buf.setWrap(wrap);
        buf.setSize(width, null);
        const t0 = std.Io.Clock.now(.awake, io);
        try buf.shapeUntilScroll(fsys, false);
        var it = buf.layoutRuns();
        var r: usize = 0;
        var g: usize = 0;
        while (it.next()) |run| {
            r += 1;
            g += run.glyphs.len;
        }
        const t1 = std.Io.Clock.now(.awake, io);
        times[k] = @intCast(t0.durationTo(t1).nanoseconds);
        runs = r;
        glyphs = g;
    }
    std.mem.sort(u64, times, {}, std.sort.asc(u64));
    var sum: f64 = 0;
    for (times) |t| sum += @floatFromInt(t);
    const mean = sum / @as(f64, @floatFromInt(times.len));
    const median: f64 = @floatFromInt(times[times.len / 2]);
    return .{ .mean_ns = mean, .median_ns = median, .glyphs = glyphs, .runs = runs };
}

/// Mirrors `load FontSystem` in benches/layout.rs with deterministic inputs:
/// construct an empty `FontSystem` and register the vendored corpus
/// (`tests/fonts`) — directory walk + per-file sfnt metadata parse + lazy
/// shaper-source registration. No glyph shaping is performed and no system
/// font is ever scanned, so this row is reproducible on any host.
///
/// Fairness note: upstream `FontSystem::new()` also scans the host font set
/// through fontdb/fontconfig, so its absolute time is host-dependent while
/// this row is not. Compare ratios/orders, not absolute times.
fn timeLoadFontSystem(
    arena: std.mem.Allocator,
    io: std.Io,
    iters: usize,
    warmup: usize,
) !struct { mean_ns: f64, median_ns: f64, faces: usize } {
    var faces: usize = 0;
    // Per-iteration arena: each load is released instead of accumulating in
    // the process arena. The measured region is FontSystem init + dir load.
    var load_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer load_state.deinit();
    const load_arena = load_state.allocator();
    var k: usize = 0;
    while (k < warmup) : (k += 1) {
        _ = load_state.reset(.{ .retain_with_limit = 16 << 20 });
        var fsys = try cozmic.FontSystem.init(load_arena);
        const stats = fsys.loadFontsDir(io, "tests/fonts");
        faces = stats.faces_added;
        fsys.deinit();
    }
    var times = try arena.alloc(u64, iters);
    defer arena.free(times);
    k = 0;
    while (k < iters) : (k += 1) {
        _ = load_state.reset(.{ .retain_with_limit = 16 << 20 });
        const t0 = std.Io.Clock.now(.awake, io);
        var fsys = try cozmic.FontSystem.init(load_arena);
        const stats = fsys.loadFontsDir(io, "tests/fonts");
        fsys.deinit();
        const t1 = std.Io.Clock.now(.awake, io);
        times[k] = @intCast(t0.durationTo(t1).nanoseconds);
        faces = stats.faces_added;
    }
    std.mem.sort(u64, times, {}, std.sort.asc(u64));
    var sum: f64 = 0;
    for (times) |t| sum += @floatFromInt(t);
    return .{
        .mean_ns = sum / @as(f64, @floatFromInt(times.len)),
        .median_ns = @floatFromInt(times[times.len / 2]),
        .faces = faces,
    };
}

/// Mirrors benches/layout.rs: Wrap(None,Glyph,Word) x Shaping(Simple,Advanced)
/// over small + Moby Dick + arabic/hebrew/emoji, plus the `load FontSystem`
/// bench. Metrics(10,10), width 80. WordOrGlyph kept as Zig-only extra row
/// (Rust bench has no such row).
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
    const samples = [_]struct { name: []const u8, text: []const u8 }{
        .{ .name = "small", .text = "Hello, world!" },
        .{ .name = "moby", .text = moby_txt },
        .{ .name = "arabic", .text = arabic_txt },
        .{ .name = "hebrew", .text = hebrew_txt },
        .{ .name = "emoji", .text = emoji_txt },
        .{ .name = "hello_mixed", .text = hello_txt },
    };
    // Comparison rows (match Rust bench): None/Glyph/Word x Simple/Advanced.
    // WordOrGlyph is extra coverage with no upstream bench row.
    const wraps = [_]cozmic.Wrap{ .none, .glyph, .word, .word_or_glyph };
    const shapings = [_]struct { name: []const u8, mode: cozmic.Shaping }{
        .{ .name = "simple", .mode = .basic },
        .{ .name = "advanced", .mode = .advanced },
    };

    if (!opts.json) try w.print("cozmic bench-layout: wrap x shaping matrix over {d} samples (iters={d} warmup={d}{s})\n", .{ samples.len, opts.iters, opts.warmup, if (opts.quick) " quick" else "" });
    for (samples) |s| {
        for (wraps) |wrap| {
            for (shapings) |shape| {
                const r = try timeIt(arena, &fsys, s.text, wrap, shape.mode, 80, opts.iters, opts.warmup, io, .off);
                const extra = if (wrap == .word_or_glyph) " (zig-only, no rust row)" else "";
                if (opts.json) {
                    try w.print("{{\"bench\":\"layout/{s}/Wrap({s}, {s})\",\"iters\":{d},\"mean_ns\":{d:.1},\"median_ns\":{d:.1},\"glyphs\":{d},\"runs\":{d}}}\n", .{ s.name, @tagName(wrap), shape.name, opts.iters, r.mean_ns, r.median_ns, r.glyphs, r.runs });
                } else {
                    try w.print("  {s} wrap={s} shape={s} width=80 runs={d} glyphs={d} mean={d:.0}ns median={d:.0}ns{s}\n", .{
                        s.name, @tagName(wrap), shape.name, r.runs, r.glyphs, r.mean_ns, r.median_ns, extra,
                    });
                }
                // Warm run-cache showcase: advanced rows on the non-emoji
                // samples (emoji's cold pass costs minutes and the other rows
                // already demonstrate the effect). The suffix keeps these rows
                // in bench_compare's COZMIC-ONLY section — upstream's
                // `shape-run-cache` feature is default-off, so a matched row
                // would not be an apples-to-apples comparison anyway.
                if (shape.mode == .advanced and !std.mem.eql(u8, s.name, "emoji")) {
                    const rw = try timeIt(arena, &fsys, s.text, wrap, shape.mode, 80, opts.iters, opts.warmup, io, .warm);
                    if (opts.json) {
                        try w.print("{{\"bench\":\"layout/{s}/Wrap({s}, {s}, run-cache warm)\",\"iters\":{d},\"mean_ns\":{d:.1},\"median_ns\":{d:.1},\"glyphs\":{d},\"runs\":{d}}}\n", .{ s.name, @tagName(wrap), shape.name, opts.iters, rw.mean_ns, rw.median_ns, rw.glyphs, rw.runs });
                    } else {
                        try w.print("  {s} wrap={s} shape={s} width=80 runs={d} glyphs={d} mean={d:.0}ns median={d:.0}ns (run-cache warm; zig-only, no rust row)\n", .{
                            s.name, @tagName(wrap), shape.name, rw.runs, rw.glyphs, rw.mean_ns, rw.median_ns,
                        });
                    }
                }
            }
        }
    }

    // `load FontSystem` (upstream benches/layout.rs).
    const fl = try timeLoadFontSystem(arena, io, opts.iters, opts.warmup);
    if (opts.json) {
        try w.print("{{\"bench\":\"loadFontSystem\",\"iters\":{d},\"mean_ns\":{d:.1},\"median_ns\":{d:.1},\"faces\":{d}}}\n", .{ opts.iters, fl.mean_ns, fl.median_ns, fl.faces });
    } else {
        try w.print("  loadFontSystem faces={d} mean={d:.0}ns median={d:.0}ns\n", .{ fl.faces, fl.mean_ns, fl.median_ns });
    }
    try w.flush();
}
