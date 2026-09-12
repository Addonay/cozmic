const std = @import("std");

// Although this function looks imperative, it does not perform the build
// directly and instead it mutates the build graph (`b`) that will be then
// executed by an external runner. The functions in `std.Build` implement a DSL
// for defining build steps and express dependencies between them, allowing the
// build runner to parallelize the build automatically (and the cache system to
// know when a step doesn't need to be re-run).
pub fn build(b: *std.Build) void {
    // Standard target options allow the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const enable_vi = b.option(bool, "vi", "Enable Vi editor + syntax support (default false)") orelse false;
    const enable_syntect = b.option(bool, "syntect", "Enable syntax highlighting stub (default false)") orelse false;
    // `vi` / `syntect` are stubs until the vi/syntect editors land. They are
    // wired to both the library (as `build_options`) and the benches so the
    // flags stay live; library code may `@import("build_options")` to gate
    // the stub editors.
    // It's also possible to define more custom flags to toggle optional features
    // of this build script using `b.option()`. All defined flags (including
    // target and optimize options) will be listed when running `zig build --help`
    // in this directory.

    // This creates a module, which represents a collection of source files alongside
    // some compilation options, such as optimization mode and linked system libraries.
    // Zig modules are the preferred way of making Zig code available to consumers.
    // addModule defines a module that we intend to make available for importing
    // to our consumers. We must give it a name because a Zig package can expose
    // multiple modules and consumers will need to be able to specify which
    // module they want to access.
    const lib_opts = b.addOptions();
    lib_opts.addOption(bool, "vi", enable_vi);
    lib_opts.addOption(bool, "syntect", enable_syntect);

    // Full UCD tables/algorithms (UAX #9 BiDi, #14 line break, #24 scripts,
    // #29 grapheme/word/sentence, properties, normalization, casing) come from
    // the pinned `ezi_code` package. `src/unicode.zig` is the only consumer:
    // the dependency's `unicode` module is imported there under the name
    // `ezi_unicode`, so the rest of cozmic keeps calling `unicode.*`.
    const ezi = b.dependency("ezi_code", .{
        .target = target,
        .optimize = optimize,
    });

    // Public module graph: the `cozmic` module plus the supporting
    // `dynload`/`freetype`/`harfbuzz` modules. The bench harness builds a
    // second, private instance of this graph (see `bench-optimize` below).
    const mod = createCozmicGraph(b, target, optimize, lib_opts.createModule(), ezi, true);

    // Here we define an executable. An executable needs to have a root module
    // which needs to expose a `main` function. While we could add a main function
    // to the module defined above, it's sometimes preferable to split business
    // logic and the CLI into two separate modules.
    //
    // If your goal is to create a Zig library for others to use, consider if
    // it might benefit from also exposing a CLI tool. A parser library for a
    // data serialization format could also bundle a CLI syntax checker, for example.
    //
    // If instead your goal is to create an executable, consider if users might
    // be interested in also being able to embed the core functionality of your
    // program in their own executable in order to avoid the overhead involved in
    // subprocessing your CLI tool.
    //
    // If neither case applies to you, feel free to delete the declaration you
    // don't need and to put everything under a single module.
    const exe = b.addExecutable(.{
        .name = "cozmic",
        .root_module = b.createModule(.{
            // b.createModule defines a new module just like b.addModule but,
            // unlike b.addModule, it does not expose the module to consumers of
            // this package, which is why in this case we don't have to give it a name.
            .root_source_file = b.path("src/main.zig"),
            // Target and optimization levels must be explicitly wired in when
            // defining an executable or library (in the root module), and you
            // can also hardcode a specific target for an executable or library
            // definition if desireable (e.g. firmware for embedded devices).
            .target = target,
            .optimize = optimize,
            // List of modules available for import in source files part of the
            // root module.
            .imports = &.{
                // Here "cozmic" is the name you will use in your source code to
                // import this module (e.g. `@import("cozmic")`). The name is
                // repeated because you are allowed to rename your imports, which
                // can be extremely useful in case of collisions (which can happen
                // importing modules from different packages).
                .{ .name = "cozmic", .module = mod },
            },
        }),
    });

    // This declares intent for the executable to be installed into the
    // install prefix when running `zig build` (i.e. when executing the default
    // step). By default the install prefix is `zig-out/` but can be overridden
    // by passing `--prefix` or `-p`.
    b.installArtifact(exe);

    // This creates a top level step. Top level steps have a name and can be
    // invoked by name when running `zig build` (e.g. `zig build run`).
    // This will evaluate the `run` step rather than the default step.
    // For a top level step to actually do something, it must depend on other
    // steps (e.g. a Run step, as we will see in a moment).
    const run_step = b.step("run", "Run the app");

    // This creates a RunArtifact step in the build graph. A RunArtifact step
    // invokes an executable compiled by Zig. Steps will only be executed by the
    // runner if invoked directly by the user (in the case of top level steps)
    // or if another step depends on it, so it's up to you to define when and
    // how this Run step will be executed. In our case we want to run it when
    // the user runs `zig build run`, so we create a dependency link.
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    // By making the run step depend on the default step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    run_cmd.addPassthruArgs();

    // Creates an executable that will run `test` blocks from the provided module.
    // Here `mod` needs to define a target, which is why earlier we made sure to
    // set the releative field.
    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    // A run step that will run the test executable.
    const run_mod_tests = b.addRunArtifact(mod_tests);
    // Tests resolve fixtures relative to the package root (`tests/fonts`,
    // `tests/images`), independent of the invocation cwd.
    run_mod_tests.setCwd(b.path("."));

    // Creates an executable that will run `test` blocks from the executable's
    // root module. Note that test executables only test one module at a time,
    // hence why we have to create two separate ones.
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    // A run step that will run the second test executable.
    const run_exe_tests = b.addRunArtifact(exe_tests);
    run_exe_tests.setCwd(b.path("."));

    // A top level step for running all tests. dependOn can be called multiple
    // times and since the two run steps do not depend on one another, this will
    // make the two of them run in parallel.
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);

    // Drift gate for the checked-in generated bindings. `check-bindings` runs
    // `tools/gen_dyn_bindings.py --check` for HarfBuzz and FreeType; it is pure
    // text I/O (no network, ~0.1 s) and `zig build test` depends on it, so an
    // edited `c_bindings.zig` or scan set cannot silently outdate its
    // `c_bindings_dyn.zig` twin. `has_side_effects` forces the check to run
    // even when the build cache still considers its directory inputs fresh.
    // `hb_ft_*` is excluded for HarfBuzz: only the optional FreeType bridge
    // uses those entry points (see `src/harfbuzz/freetype.zig`), and a
    // HarfBuzz built without FreeType must still load and shape.
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
        const check = b.addSystemCommand(&.{ "python3", "tools/gen_dyn_bindings.py" });
        check.has_side_effects = true;
        check.addArg("--check");
        check.addArg("--bindings");
        check.addFileArg(b.path(entry.bindings));
        check.addArg("--scan");
        for ([_][]const u8{ "src", "benches", "tests" }) |scan| {
            check.addDirectoryArg(b.path(scan));
        }
        check.addArg("--out");
        check.addFileArg(b.path(entry.generated));
        if (entry.exclude_prefix) |prefix| {
            check.addArg("--exclude-prefix");
            check.addArg(prefix);
        }
        check_bindings.dependOn(&check.step);
    }
    test_step.dependOn(check_bindings);

    // Ported upstream suites under `tests/` (direction, wrap stability,
    // image rendering, ...); see `tests/all.zig`.
    const upstream_tests_mod = b.createModule(.{
        .root_source_file = b.path("tests/all.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "cozmic", .module = mod },
        },
    });
    upstream_tests_mod.link_libc = true;
    const upstream_tests = b.addTest(.{ .root_module = upstream_tests_mod });
    const run_upstream_tests = b.addRunArtifact(upstream_tests);
    run_upstream_tests.setCwd(b.path("."));
    test_step.dependOn(&run_upstream_tests.step);

    const bench_opts = b.addOptions();
    bench_opts.addOption(bool, "vi", enable_vi);
    bench_opts.addOption(bool, "syntect", enable_syntect);
    const bench_build_options = bench_opts.createModule();

    // Benchmarks must measure optimized code: a Debug harness is roughly an
    // order of magnitude slower (the 361 KB emoji sample alone blows the
    // 5-minute budget) and its timings do not reflect shipped behavior.
    // `-Dbench-optimize` overrides this; `-Doptimize` still controls the app
    // and tests, which is why benches get their own library instantiation.
    const bench_optimize = b.option(
        std.lang.Optimize,
        "bench-optimize",
        "Optimize mode for benchmark artifacts (default: ReleaseFast)",
    ) orelse .fast;
    const bench_ezi = b.dependency("ezi_code", .{
        .target = target,
        .optimize = bench_optimize,
    });
    const bench_core = createCozmicGraph(
        b,
        target,
        bench_optimize,
        bench_build_options,
        bench_ezi,
        false,
    );

    // `zig build bench -- [--format json] [--quick] [--iter N] [--warmup N]`
    const bench_step = b.step("bench", "Run benchmarks (-- --quick for a fast harness smoke run)");
    var prev_bench: ?*std.Build.Step = null;
    for ([_]struct { name: []const u8, src: []const u8 }{
        .{ .name = "bench-layout", .src = "benches/layout.zig" },
        .{ .name = "bench-shaping", .src = "benches/shaping.zig" },
    }) |bench| {
        const bench_mod = b.createModule(.{
            .root_source_file = b.path(bench.src),
            .target = target,
            .optimize = bench_optimize,
            .imports = &.{
                .{ .name = "cozmic", .module = bench_core },
                .{ .name = "build_options", .module = bench_build_options },
            },
        });
        const bench_exe = b.addExecutable(.{ .name = bench.name, .root_module = bench_mod });
        const bench_run = b.addRunArtifact(bench_exe);
        bench_run.addPassthruArgs();
        // Resolve `tests/fonts` relative to the package root, not the
        // invocation cwd, so every row measures the same files.
        bench_run.setCwd(b.path("."));
        // Run benches one at a time: parallel run steps interleave their JSON
        // lines and make every measurement contend for CPU.
        if (prev_bench) |prev| bench_run.step.dependOn(prev);
        bench_step.dependOn(&bench_run.step);
        prev_bench = &bench_run.step;
    }

    // Dual-engine compare: Zig benches + Rust criterion benches, joined table.
    // `zig build bench-compare [-- --no-zig|--no-rust|--quick|--iters N|--measurement-time S|--out file]`
    // `--zig-bin` pins the compiler this build was launched with, so the
    // script does not depend on `zig` being on PATH.
    const compare_step = b.step("bench-compare", "Run cozmic + cosmic-text benches, join as table");
    var compare = b.addSystemCommand(&.{ "python3", "tools/bench_compare.py" });
    compare.addArg("--zig-bin");
    compare.addArg(b.graph.zig_exe);
    compare.addPassthruArgs();
    compare_step.dependOn(&compare.step);

    // Just like flags, top level steps are also listed in the `--help` menu.
    //
    // The Zig build system is entirely implemented in userland, which means
    // that it cannot hook into private compiler APIs. All compilation work
    // orchestrated by the build system will result in other Zig compiler
    // subcommands being invoked with the right flags defined. You can observe
    // these invocations when one fails (or you pass a flag to increase
    // verbosity) to validate assumptions and diagnose problems.
    //
    // Lastly, the Zig build system is relatively simple and self-contained,
    // and reading its source code will allow you to master it.
}

/// Create the full cozmic module graph at `optimize` and return the core
/// (`src/root.zig`) module.
///
/// With `expose = true` the modules are registered as package modules (the
/// public `cozmic` module plus the `dynload`/`freetype`/`harfbuzz` supporting
/// modules, kept importable by dependents). With `expose = false` they are
/// private to this build; the bench harness uses that to instantiate the
/// library a second time at `-Dbench-optimize` (default ReleaseFast) without
/// changing what `-Doptimize` does for the app and tests.
fn createCozmicGraph(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.lang.Optimize,
    build_options: *std.Build.Module,
    ezi: *std.Build.Dependency,
    expose: bool,
) *std.Build.Module {
    // Shared runtime loader for the C libraries the vendored wrappers use.
    // HarfBuzz/FreeType are *not* link-time dependencies: the generated
    // `c_bindings_dyn.zig` files bind their entry points through this module
    // (`dlopen` on POSIX, `LoadLibraryA` on Windows), so the build machine
    // needs no -dev packages.
    const dynload_opts: std.Build.Module.CreateOptions = .{
        .root_source_file = b.path("src/dynload.zig"),
        .target = target,
        .optimize = optimize,
    };
    const dynload_mod = if (expose) b.addModule("dynload", dynload_opts) else b.createModule(dynload_opts);
    dynload_mod.link_libc = true;

    // Vendored binding libraries, importable as `@import("harfbuzz")` and
    // `@import("freetype")` (copied from .reference and adapted to Zig 0.17:
    // `c.zig` now re-exports generated dynamic bindings since @cImport is
    // gone).
    const freetype_opts: std.Build.Module.CreateOptions = .{
        .root_source_file = b.path("src/freetype/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "dynload", .module = dynload_mod },
        },
    };
    const freetype_mod = if (expose) b.addModule("freetype", freetype_opts) else b.createModule(freetype_opts);
    freetype_mod.link_libc = true;

    const harfbuzz_opts: std.Build.Module.CreateOptions = .{
        .root_source_file = b.path("src/harfbuzz/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "freetype", .module = freetype_mod },
            .{ .name = "dynload", .module = dynload_mod },
        },
    };
    const harfbuzz_mod = if (expose) b.addModule("harfbuzz", harfbuzz_opts) else b.createModule(harfbuzz_opts);
    harfbuzz_mod.link_libc = true;

    // The root source file is the "entry point" of this module. Users of this
    // module can only access public declarations contained in this file, so
    // anything meant for consumers has to be re-exported from `src/root.zig`.
    const core_opts: std.Build.Module.CreateOptions = .{
        .root_source_file = b.path("src/root.zig"),
        // The module is also the root module of test/bench executables, which
        // requires an explicit target.
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "build_options", .module = build_options },
            .{ .name = "ezi_unicode", .module = ezi.module("unicode") },
            .{ .name = "harfbuzz", .module = harfbuzz_mod },
            .{ .name = "freetype", .module = freetype_mod },
        },
    };
    const mod = if (expose) b.addModule("cozmic", core_opts) else b.createModule(core_opts);

    // Real backends: the vendored `harfbuzz` / `freetype` modules load their
    // C libraries at runtime through `dynload` (see module definitions
    // above); this module only needs libc for the `extern` calls in adapters.
    mod.link_libc = true;
    return mod;
}
