//! Static builds of the C libraries cozmic bundles by default: a trimmed
//! HarfBuzz (shaping only) and FreeType (sfnt loading, hinting, variations,
//! anti-aliased rendering), plus zlib + libpng when color bitmap glyphs are
//! enabled. `-Dsystem-libs` skips all of this and loads the host's shared
//! libraries at runtime instead.
//!
//! The C code is always compiled optimized: a Debug HarfBuzz is an order of
//! magnitude slower and would dominate test time, while cozmic's own Zig code
//! keeps the requested mode. ReleaseSmall propagates so size builds stay small.

const std = @import("std");

pub const Options = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.lang.Optimize,
    /// Bundle zlib + libpng so FreeType can decode CBDT/sbix color bitmaps.
    color_bitmaps: bool,
};

pub const Libs = struct {
    harfbuzz: *std.Build.Step.Compile,
    freetype: *std.Build.Step.Compile,
};

fn cOptimize(optimize: std.lang.Optimize) std.lang.Optimize {
    return switch (optimize) {
        .small => .small,
        else => .fast,
    };
}

/// Returns null while lazy dependencies are still being fetched; the build
/// runner re-runs `build` once they are available.
pub fn build(b: *std.Build, opts: Options) ?Libs {
    const hb_dep = b.lazyDependency("harfbuzz", .{}) orelse return null;
    const ft_dep = b.lazyDependency("freetype", .{}) orelse return null;
    const optimize = cOptimize(opts.optimize);

    const freetype = b.addLibrary(.{
        .name = "cozmic_freetype",
        .root_module = b.createModule(.{
            .target = opts.target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    const ft = freetype.root_module;
    ft.addIncludePath(b.path("src/c"));
    ft.addIncludePath(ft_dep.path("include"));
    ft.addCMacro("FT2_BUILD_LIBRARY", "1");
    ft.addCMacro("FT_CONFIG_OPTIONS_H", "<cozmic_ftoption.h>");
    ft.addCMacro("FT_CONFIG_MODULES_H", "<cozmic_ftmodule.h>");
    ft.addCSourceFiles(.{
        .root = ft_dep.path("src"),
        .files = &.{
            "base/ftsystem.c",
            "base/ftinit.c",
            "base/ftdebug.c",
            "base/ftbase.c",
            "base/ftbbox.c",
            "base/ftbitmap.c",
            "base/ftmm.c",
            "autofit/autofit.c",
            "truetype/truetype.c",
            "cff/cff.c",
            "psaux/psaux.c",
            "psnames/psnames.c",
            "pshinter/pshinter.c",
            "sfnt/sfnt.c",
            "smooth/smooth.c",
        },
        .flags = &.{ "-std=c99", "-fno-sanitize=undefined" },
    });

    if (opts.color_bitmaps) {
        if (buildPng(b, opts.target, optimize)) |png| {
            ft.addCMacro("COZMIC_FT_PNG", "1");
            ft.addIncludePath(png.zlib_include);
            ft.addIncludePath(png.png_include);
            ft.addIncludePath(png.png_conf);
            ft.addCSourceFiles(.{
                .root = ft_dep.path("src"),
                .files = &.{"gzip/ftgzip.c"},
                .flags = &.{ "-std=c99", "-fno-sanitize=undefined" },
            });
            ft.linkLibrary(png.lib);
        } else return null;
    }

    const harfbuzz = b.addLibrary(.{
        .name = "cozmic_harfbuzz",
        .root_module = b.createModule(.{
            .target = opts.target,
            .optimize = optimize,
            .link_libc = true,
            // Headers only in practice (<atomic>, <functional>); the static
            // link pulls in no libc++ objects HarfBuzz does not reference.
            .link_libcpp = true,
        }),
    });
    const hb = harfbuzz.root_module;
    // A curated subset of HarfBuzz's HB_LEAN: drops APIs cozmic never calls
    // (serialization, drawing/paint, color, math, glyph names, file opening)
    // while keeping variations, metrics, AAT and the locale-default language.
    for ([_][]const u8{
        "HB_DISABLE_DEPRECATED",
        "HB_NO_ATEXIT",
        "HB_NO_BUFFER_MESSAGE",
        "HB_NO_BUFFER_SERIALIZE",
        "HB_NO_BUFFER_VERIFY",
        "HB_NO_BITMAP",
        "HB_NO_COLOR",
        "HB_NO_DRAW",
        "HB_NO_PAINT",
        "HB_NO_ERRNO",
        "HB_NO_FACE_COLLECT_UNICODES",
        "HB_NO_GETENV",
        "HB_NO_HINTING",
        "HB_NO_LAYOUT_COLLECT_GLYPHS",
        "HB_NO_LAYOUT_FEATURE_PARAMS",
        "HB_NO_MATH",
        "HB_NO_META",
        "HB_NO_MMAP",
        "HB_NO_NAME",
        "HB_NO_OPEN",
        "HB_NO_OT_FONT_GLYPH_NAMES",
        "HB_NO_STYLE",
        "HB_NO_SUBSET_LAYOUT",
        "HB_NO_VERTICAL",
    }) |m| hb.addCMacro(m, "1");
    hb.addCSourceFiles(.{
        .root = hb_dep.path("src"),
        .files = &.{"harfbuzz.cc"},
        .flags = &.{
            "-std=c++11",
            "-fno-exceptions",
            "-fno-rtti",
            "-fno-threadsafe-statics",
            "-fno-sanitize=undefined",
        },
    });

    return .{ .harfbuzz = harfbuzz, .freetype = freetype };
}

const Png = struct {
    lib: *std.Build.Step.Compile,
    zlib_include: std.Build.LazyPath,
    png_include: std.Build.LazyPath,
    png_conf: std.Build.LazyPath,
};

fn buildPng(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.lang.Optimize) ?Png {
    const z_dep = b.lazyDependency("zlib", .{}) orelse return null;
    const png_dep = b.lazyDependency("libpng", .{}) orelse return null;

    const lib = b.addLibrary(.{
        .name = "cozmic_png",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    const m = lib.root_module;
    const flags: []const []const u8 = &.{ "-std=c99", "-fno-sanitize=undefined" };
    m.addCSourceFiles(.{
        .root = z_dep.path("."),
        .files = &.{ "adler32.c", "crc32.c", "inffast.c", "inflate.c", "inftrees.c", "zutil.c" },
        .flags = &.{ "-std=c99", "-fno-sanitize=undefined", "-DZ_HAVE_UNISTD_H" },
    });

    // libpng's configure normally generates pnglibconf.h; src/c holds a
    // read-only variant of the prebuilt default (no write support).
    m.addIncludePath(b.path("src/c"));
    m.addIncludePath(z_dep.path("."));
    m.addIncludePath(png_dep.path("."));
    for ([_][]const u8{
        "PNG_ARM_NEON_OPT",
        "PNG_INTEL_SSE_OPT",
        "PNG_MIPS_MSA_OPT",
        "PNG_MIPS_MMI_OPT",
        "PNG_POWERPC_VSX_OPT",
        "PNG_LOONGARCH_LSX_OPT",
        "PNG_RISCV_RVV_OPT",
    }) |opt| m.addCMacro(opt, "0");
    // Read side only: FreeType decodes PNG strikes, it never writes them.
    m.addCSourceFiles(.{
        .root = png_dep.path("."),
        .files = &.{
            "png.c",      "pngerror.c", "pngget.c",  "pngmem.c",   "pngread.c",
            "pngrio.c",   "pngrtran.c", "pngrutil.c", "pngset.c",  "pngtrans.c",
        },
        .flags = flags,
    });
    return .{
        .lib = lib,
        .zlib_include = z_dep.path("."),
        .png_include = png_dep.path("."),
        .png_conf = b.path("src/c"),
    };
}
