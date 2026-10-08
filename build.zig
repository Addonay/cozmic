const std = @import("std");
const clibs = @import("tools/clibs.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const enable_vi = b.option(bool, "vi", "Export the experimental Vi editor surface (default false)") orelse false;
    const enable_syntect = b.option(bool, "syntect", "Export the experimental syntax-highlighting surface (default false)") orelse false;
    const system_libs = b.option(
        bool,
        "system-libs",
        "Load the host's HarfBuzz/FreeType shared libraries at runtime instead of bundling them (default false)",
    ) orelse false;
    const color_bitmaps = b.option(
        bool,
        "color-bitmaps",
        "Bundle zlib + libpng so CBDT/sbix color emoji render (default true; ignored with -Dsystem-libs)",
    ) orelse true;

    // Benchmarks must measure optimized code: a Debug harness is roughly an
    // order of magnitude slower and its timings do not reflect shipped
    // behavior. `-Doptimize` still controls the app and tests, which is why
    // benches get their own library instantiation.
    const bench_optimize = b.option(
        std.lang.Optimize,
        "bench-optimize",
        "Optimize mode for benchmark artifacts (default: ReleaseFast)",
    ) orelse .fast;

    const feature_opts = b.addOptions();
    feature_opts.addOption(bool, "vi", enable_vi);
    feature_opts.addOption(bool, "syntect", enable_syntect);
    const build_options = feature_opts.createModule();

    const link_opts = b.addOptions();
    link_opts.addOption(bool, "bundled", !system_libs);
    const link_options = link_opts.createModule();

    // The C libraries are compiled once (always optimized, see tools/clibs.zig)
    // and shared by the library, tests and benches. `null` while the lazy
    // source packages are still being fetched; the runner then re-runs build.
    const libs: ?clibs.Libs = if (system_libs) null else clibs.build(b, .{
        .target = target,
        .optimize = optimize,
        .color_bitmaps = color_bitmaps,
    });
    if (!system_libs and libs == null) return;

    const graph: Graph = .{
        .target = target,
        .build_options = build_options,
        .link_options = link_options,
        .libs = libs,
    };
    const mod = graph.create(b, optimize, true);

    // Demo executable: shapes one line with the host's fonts.
    const exe = b.addExecutable(.{
        .name = "cozmic",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "cozmic", .module = mod }},
        }),
    });
    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();
    b.step("run", "Shape one line and print its metrics").dependOn(&run_cmd.step);

    // Tests resolve fixtures relative to the package root (`tests/fonts`,
    // `tests/images`), independent of the invocation cwd.
    const test_step = b.step("test", "Run tests");
    for ([_]*std.Build.Module{
        mod,
        exe.root_module,
        b.createModule(.{
            // Ported upstream suites (direction, wrap stability, images, ...)
            // plus regression tests; see `tests/all.zig`.
            .root_source_file = b.path("tests/all.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{.{ .name = "cozmic", .module = mod }},
        }),
    }) |test_mod| {
        const run = b.addRunArtifact(b.addTest(.{ .root_module = test_mod }));
        run.setCwd(b.path("."));
        test_step.dependOn(&run.step);
    }

    // Drift gate for the checked-in generated runtime bindings used by
    // `-Dsystem-libs`. Pure text I/O, forced to run because the cache cannot
    // see directory-scan inputs. `hb_ft_*` is excluded: only the optional
    // FreeType bridge uses it, and a HarfBuzz built without FreeType must still
    // load and shape.
    const check_bindings = b.step("check-bindings", "Verify generated dynamic bindings are up to date");
    for ([_]struct {
        bindings: []const u8,
        generated: []const u8,
        exclude_prefix: ?[]const u8 = null,
    }{
        .{
            .bindings = "src/harfbuzz/c_bindings.zig",
            .generated = "src/harfbuzz/c_bindings_dyn.zig",
            .exclude_prefix = "hb_ft_",
        },
        .{
            .bindings = "src/freetype/c_bindings.zig",
            .generated = "src/freetype/c_bindings_dyn.zig",
        },
    }) |entry| {
        const check = b.addSystemCommand(&.{ "python3", "tools/gen_dyn_bindings.py", "--check", "--bindings" });
        check.has_side_effects = true;
        check.addFileArg2(b.path(entry.bindings), .{});
        check.addArg("--scan");
        for ([_][]const u8{ "src", "benches", "tests" }) |scan| {
            check.addDirectoryArg2(b.path(scan), .{});
        }
        check.addArg("--out");
        check.addFileArg2(b.path(entry.generated), .{});
        if (entry.exclude_prefix) |prefix| check.addArgs(&.{ "--exclude-prefix", prefix });
        check_bindings.dependOn(&check.step);
    }
    test_step.dependOn(check_bindings);

    // Benches.
    const bench_core = graph.create(b, bench_optimize, false);

    const matched_exe = b.addExecutable(.{
        .name = "bench-matched",
        .root_module = b.createModule(.{
            .root_source_file = b.path("benches/matched.zig"),
            .target = target,
            .optimize = bench_optimize,
            .imports = &.{.{ .name = "cozmic", .module = bench_core }},
        }),
    });
    const matched_run = b.addRunArtifact(matched_exe);
    matched_run.setCwd(b.path("."));
    b.step("bench-matched", "Run the cold-layout workloads matched by benches/upstream/matched_probe.rs")
        .dependOn(&matched_run.step);

    const memory_exe = b.addExecutable(.{
        .name = "bench-memory",
        .root_module = b.createModule(.{
            .root_source_file = b.path("benches/memory.zig"),
            .target = target,
            .optimize = bench_optimize,
            .imports = &.{.{ .name = "cozmic", .module = bench_core }},
        }),
    });
    const memory_run = b.addRunArtifact(memory_exe);
    memory_run.setCwd(b.path("."));
    b.step("bench-memory", "Report cozmic heap usage per phase of the matched workload")
        .dependOn(&memory_run.step);

    // `zig build bench -- [--format json] [--quick] [--iter N] [--warmup N]`
    const bench_step = b.step("bench", "Run benchmarks (-- --quick for a fast harness smoke run)");
    var prev_bench: ?*std.Build.Step = null;
    for ([_]struct { name: []const u8, src: []const u8 }{
        .{ .name = "bench-layout", .src = "benches/layout.zig" },
        .{ .name = "bench-shaping", .src = "benches/shaping.zig" },
    }) |bench| {
        const bench_exe = b.addExecutable(.{
            .name = bench.name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(bench.src),
                .target = target,
                .optimize = bench_optimize,
                .imports = &.{
                    .{ .name = "cozmic", .module = bench_core },
                    .{ .name = "build_options", .module = build_options },
                },
            }),
        });
        const bench_run = b.addRunArtifact(bench_exe);
        bench_run.addPassthruArgs();
        bench_run.setCwd(b.path("."));
        // One at a time: parallel runs interleave JSON lines and contend for CPU.
        if (prev_bench) |prev| bench_run.step.dependOn(prev);
        bench_step.dependOn(&bench_run.step);
        prev_bench = &bench_run.step;
    }

    // Dual-engine compare: Zig benches + Rust criterion benches, joined table.
    // `--zig-bin` pins the compiler this build was launched with.
    const compare = b.addSystemCommand(&.{ "python3", "tools/bench_compare.py", "--zig-bin", b.graph.zig_exe });
    compare.addPassthruArgs();
    b.step("bench-compare", "Run cozmic + cosmic-text benches, join as table").dependOn(&compare.step);
}

/// Everything needed to instantiate the cozmic module graph at some optimize
/// mode. The main graph is exposed to dependents; the bench graph is a private
/// second instance at `-Dbench-optimize`.
const Graph = struct {
    target: std.Build.ResolvedTarget,
    build_options: *std.Build.Module,
    link_options: *std.Build.Module,
    libs: ?clibs.Libs,

    /// Returns the core (`src/root.zig`) module. With `expose` the modules are
    /// registered as package modules (`cozmic`, plus `dynload`/`freetype`/
    /// `harfbuzz`, kept importable by dependents).
    fn create(g: Graph, b: *std.Build, optimize: std.lang.Optimize, expose: bool) *std.Build.Module {
        const ezi = b.dependency("ezi_code", .{ .target = g.target, .optimize = optimize });

        // Runtime loader for `-Dsystem-libs`; also owns the process-wide lock
        // that serializes lazy font-file reads between shaping and raster.
        const dynload_mod = module(b, expose, "dynload", .{
            .root_source_file = b.path("src/dynload.zig"),
            .target = g.target,
            .optimize = optimize,
            .link_libc = true,
        });

        // Vendored binding modules. `c.zig` re-exports the static `extern`
        // declarations when bundled, or the generated function-pointer
        // bindings when loading system libraries.
        const freetype_mod = module(b, expose, "freetype", .{
            .root_source_file = b.path("src/freetype/main.zig"),
            .target = g.target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "dynload", .module = dynload_mod },
                .{ .name = "link_options", .module = g.link_options },
            },
        });
        const harfbuzz_mod = module(b, expose, "harfbuzz", .{
            .root_source_file = b.path("src/harfbuzz/main.zig"),
            .target = g.target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "freetype", .module = freetype_mod },
                .{ .name = "dynload", .module = dynload_mod },
                .{ .name = "link_options", .module = g.link_options },
            },
        });
        if (g.libs) |libs| {
            freetype_mod.linkLibrary(libs.freetype);
            harfbuzz_mod.linkLibrary(libs.harfbuzz);
        }

        // Consumers can only reach what `src/root.zig` re-exports.
        return module(b, expose, "cozmic", .{
            .root_source_file = b.path("src/root.zig"),
            .target = g.target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "build_options", .module = g.build_options },
                // Full UCD tables/algorithms; only `src/unicode.zig` imports it.
                .{ .name = "ezi_unicode", .module = ezi.module("unicode") },
                .{ .name = "harfbuzz", .module = harfbuzz_mod },
                .{ .name = "freetype", .module = freetype_mod },
                .{ .name = "dynload", .module = dynload_mod },
                .{ .name = "link_options", .module = g.link_options },
            },
        });
    }

    fn module(b: *std.Build, expose: bool, name: []const u8, opts: std.Build.Module.CreateOptions) *std.Build.Module {
        return if (expose) b.addModule(name, opts) else b.createModule(opts);
    }
};
