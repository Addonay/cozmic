//! Runtime-loaded fontconfig enumeration for lazy system-font registration.
//!
//! `Fontconfig.load()` `dlopen`s libfontconfig, resolves the `Fc*` entry
//! points it needs (all-or-nothing: any missing symbol makes it return null),
//! and loads a font configuration with `FcInitLoadConfigAndFonts`.
//! `Fontconfig.list()` then copies family/slant/weight/width/spacing/
//! file/index/postscript metadata for every configured face into owned
//! `Face` values. No font file is opened and no bytes are retained; the
//! lazy source registration in `font_system.zig` re-reads the file on first
//! shaping/rasterization.
//!
//! Mirrors the `dlopen` pattern of ZUI's `src/fonts/discovery.zig` /
//! `src/fonts/tables.zig` (runtime system libs, never link-time), with
//! `std.DynLib` instead of the hand-rolled loader.

const std = @import("std");
const builtin = @import("builtin");

/// Targets where `std.DynLib` has a backend. Windows is excluded because this
/// Zig release's `std.DynLib` is POSIX/Darwin-only; its `.dll` candidate
/// names stay in `libCandidates` for a future loader, but `load()` returns
/// null there and discovery uses the directory-scan fallback.
const dynlib_supported = switch (builtin.os.tag) {
    .linux,
    .freebsd,
    .netbsd,
    .openbsd,
    .dragonfly,
    .illumos,
    .macos,
    .ios,
    .tvos,
    .watchos,
    .visionos,
    .driverkit,
    .maccatalyst,
    => true,
    else => false,
};

pub const FcChar8 = u8;
pub const FcBool = c_int;

pub const FcResult = enum(c_int) {
    FcResultMatch = 0,
    FcResultNoMatch = 1,
    FcResultTypeMismatch = 2,
    FcResultNoId = 3,
    FcResultOutOfMemory = 4,
};

pub const FcConfig = opaque {};
pub const FcPattern = opaque {};
pub const FcObjectSet = opaque {};

/// `FcFontSet` as declared in fontconfig's public header (stable ABI).
///
/// `fonts` mirrors the C `FcPattern **` as a many-pointer of optional
/// elements: the outer optional models a null array pointer and the inner
/// one a null slot, both of which `list()` must tolerate on a corrupt set.
/// Optional pointers are pointer-sized, so the layout stays ABI-identical.
pub const FcFontSet = extern struct {
    nfont: c_int,
    sfont: c_int,
    fonts: ?[*]?*FcPattern,
};

// Object names (`fontconfig.h`).
pub const FC_FAMILY: [*:0]const u8 = "family";
pub const FC_STYLE: [*:0]const u8 = "style";
pub const FC_SLANT: [*:0]const u8 = "slant";
pub const FC_WEIGHT: [*:0]const u8 = "weight";
pub const FC_WIDTH: [*:0]const u8 = "width";
pub const FC_SPACING: [*:0]const u8 = "spacing";
pub const FC_FILE: [*:0]const u8 = "file";
pub const FC_INDEX: [*:0]const u8 = "index";
pub const FC_POSTSCRIPT_NAME: [*:0]const u8 = "postscriptname";

// Weight constants (`FC_WEIGHT_*`, fontconfig.h).
pub const FC_WEIGHT_THIN: c_int = 0;
pub const FC_WEIGHT_EXTRALIGHT: c_int = 40;
pub const FC_WEIGHT_LIGHT: c_int = 50;
pub const FC_WEIGHT_DEMILIGHT: c_int = 55;
pub const FC_WEIGHT_BOOK: c_int = 75;
pub const FC_WEIGHT_REGULAR: c_int = 80;
pub const FC_WEIGHT_MEDIUM: c_int = 100;
pub const FC_WEIGHT_DEMIBOLD: c_int = 180;
pub const FC_WEIGHT_BOLD: c_int = 200;
pub const FC_WEIGHT_EXTRABOLD: c_int = 205;
pub const FC_WEIGHT_BLACK: c_int = 210;
pub const FC_WEIGHT_EXTRABLACK: c_int = 215;

// Slant constants (`FC_SLANT_*`, fontconfig.h).
pub const FC_SLANT_ROMAN: c_int = 0;
pub const FC_SLANT_ITALIC: c_int = 100;
pub const FC_SLANT_OBLIQUE: c_int = 110;

// Width constants (`FC_WIDTH_*`, fontconfig.h).
pub const FC_WIDTH_ULTRACONDENSED: c_int = 50;
pub const FC_WIDTH_EXTRACONDENSED: c_int = 63;
pub const FC_WIDTH_CONDENSED: c_int = 75;
pub const FC_WIDTH_SEMICONDENSED: c_int = 87;
pub const FC_WIDTH_NORMAL: c_int = 100;
pub const FC_WIDTH_SEMIEXPANDED: c_int = 113;
pub const FC_WIDTH_EXPANDED: c_int = 125;
pub const FC_WIDTH_EXTRAEXPANDED: c_int = 150;
pub const FC_WIDTH_ULTRAEXPANDED: c_int = 200;

// Spacing constants (`FC_*`, fontconfig.h).
pub const FC_PROPORTIONAL: c_int = 0;
pub const FC_DUAL: c_int = 90;
pub const FC_MONO: c_int = 100;
pub const FC_CHARCELL: c_int = 110;

/// `Face.style` values (0 normal / 1 italic / 2 oblique) matching
/// `font_system.Style`.
pub const STYLE_NORMAL: u8 = 0;
pub const STYLE_ITALIC: u8 = 1;
pub const STYLE_OBLIQUE: u8 = 2;

/// Upper bound on family names copied per face (fontconfig patterns never
/// carry more than a handful; the cap keeps a corrupt list from looping).
pub const MAX_FAMILY_NAMES: usize = 32;

/// Owned metadata for one configured face. Every field is caller-owned:
/// free with `Face.deinit` / `Fontconfig.freeFaces`.
pub const Face = struct {
    path: []u8,
    index: u32,
    families: [][]u8,
    post_script_name: []u8,
    /// OS/2 `usWeightClass`-style weight (100..950).
    weight: u16,
    /// Stretch numbering 1..9 (1 = ultra-condensed, 5 = normal, 9 =
    /// ultra-expanded).
    stretch: u8,
    /// 0 normal / 1 italic / 2 oblique.
    style: u8,
    monospaced: bool,

    pub fn deinit(self: *Face, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
        for (self.families) |family| allocator.free(family);
        allocator.free(self.families);
        allocator.free(self.post_script_name);
        self.* = undefined;
    }
};

/// Free a `list()` result (every face field plus the slice itself).
pub fn freeFaces(allocator: std.mem.Allocator, faces: []Face) void {
    for (faces) |*face| face.deinit(allocator);
    allocator.free(faces);
}

// ---------------------------------------------------------------------------
// Constant mapping helpers (pure; unit-tested).
// ---------------------------------------------------------------------------

/// Absolute difference of two `c_int` values, widened to `u64`.
///
/// Totality is deliberate: pattern values come from untrusted system
/// configuration, so either operand may be any `c_int` (including
/// `INT_MIN`) and the exact difference can reach 2^32 - 1, which does not
/// fit in a `c_int`. Widening both the subtraction and the result keeps the
/// nearest-anchor comparisons below exact instead of trapping in a
/// narrowing `@intCast` (the historical `FC_WEIGHT == INT_MIN` bug).
fn absDiffCInt(a: c_int, b: c_int) u64 {
    return @abs(@as(i64, a) - @as(i64, b));
}

/// Map a fontconfig weight (0..215 scale) to an OS/2-style weight by nearest
/// anchor. Out-of-range values clamp to the extreme anchors.
pub fn weightToOs2(fc_weight: c_int) u16 {
    const Anchor = struct { fc: c_int, os2: u16 };
    const anchors = [_]Anchor{
        .{ .fc = FC_WEIGHT_THIN, .os2 = 100 },
        .{ .fc = FC_WEIGHT_EXTRALIGHT, .os2 = 200 },
        .{ .fc = FC_WEIGHT_LIGHT, .os2 = 300 },
        .{ .fc = FC_WEIGHT_DEMILIGHT, .os2 = 350 },
        .{ .fc = FC_WEIGHT_BOOK, .os2 = 400 },
        .{ .fc = FC_WEIGHT_REGULAR, .os2 = 400 },
        .{ .fc = FC_WEIGHT_MEDIUM, .os2 = 500 },
        .{ .fc = FC_WEIGHT_DEMIBOLD, .os2 = 600 },
        .{ .fc = FC_WEIGHT_BOLD, .os2 = 700 },
        .{ .fc = FC_WEIGHT_EXTRABOLD, .os2 = 800 },
        .{ .fc = FC_WEIGHT_BLACK, .os2 = 900 },
        .{ .fc = FC_WEIGHT_EXTRABLACK, .os2 = 950 },
    };
    var best = anchors[0];
    var best_dist = absDiffCInt(fc_weight, anchors[0].fc);
    for (anchors[1..]) |anchor| {
        const dist = absDiffCInt(fc_weight, anchor.fc);
        if (dist < best_dist) {
            best = anchor;
            best_dist = dist;
        }
    }
    return best.os2;
}

/// Map a fontconfig width (50..200 scale) to stretch numbering 1..9 by
/// nearest anchor. Out-of-range values clamp to 1 or 9.
pub fn stretchFromFc(fc_width: c_int) u8 {
    const Anchor = struct { fc: c_int, stretch: u8 };
    const anchors = [_]Anchor{
        .{ .fc = FC_WIDTH_ULTRACONDENSED, .stretch = 1 },
        .{ .fc = FC_WIDTH_EXTRACONDENSED, .stretch = 2 },
        .{ .fc = FC_WIDTH_CONDENSED, .stretch = 3 },
        .{ .fc = FC_WIDTH_SEMICONDENSED, .stretch = 4 },
        .{ .fc = FC_WIDTH_NORMAL, .stretch = 5 },
        .{ .fc = FC_WIDTH_SEMIEXPANDED, .stretch = 6 },
        .{ .fc = FC_WIDTH_EXPANDED, .stretch = 7 },
        .{ .fc = FC_WIDTH_EXTRAEXPANDED, .stretch = 8 },
        .{ .fc = FC_WIDTH_ULTRAEXPANDED, .stretch = 9 },
    };
    var best = anchors[0];
    var best_dist = absDiffCInt(fc_width, anchors[0].fc);
    for (anchors[1..]) |anchor| {
        const dist = absDiffCInt(fc_width, anchor.fc);
        if (dist < best_dist) {
            best = anchor;
            best_dist = dist;
        }
    }
    return best.stretch;
}

/// Map a fontconfig slant to 0 normal / 1 italic / 2 oblique. Values below
/// `FC_SLANT_ITALIC` count as normal; between italic and oblique (exclusive)
/// as italic; oblique and above as oblique.
pub fn styleFromSlant(fc_slant: c_int) u8 {
    if (fc_slant >= FC_SLANT_OBLIQUE) return STYLE_OBLIQUE;
    if (fc_slant >= FC_SLANT_ITALIC) return STYLE_ITALIC;
    return STYLE_NORMAL;
}

/// Fontconfig stores the plain face index of the file in `FC_INDEX`; for
/// variable fonts FreeType may pack named-instance bits into the value, so
/// pass positive values through verbatim (the shaper opens the same face /
/// instance). Negative values (including `INT_MIN`) clamp to face 0.
pub fn faceIndexFromFc(raw: c_int) u32 {
    if (raw <= 0) return 0;
    // Saturation is deliberate: a positive `c_int` already fits in `u32` on
    // every supported ABI, but clamping keeps the helper total (no trap in
    // `@intCast`) if `c_int` were ever wider than 32 bits.
    return @intCast(@min(@as(i64, raw), std.math.maxInt(u32)));
}

// ---------------------------------------------------------------------------
// Runtime API.
// ---------------------------------------------------------------------------

const FcInitLoadConfigAndFontsFn = *const fn () callconv(.c) ?*FcConfig;
const FcConfigDestroyFn = *const fn (*FcConfig) callconv(.c) void;
const FcPatternCreateFn = *const fn () callconv(.c) ?*FcPattern;
const FcPatternDestroyFn = *const fn (*FcPattern) callconv(.c) void;
const FcObjectSetCreateFn = *const fn () callconv(.c) ?*FcObjectSet;
const FcObjectSetDestroyFn = *const fn (*FcObjectSet) callconv(.c) void;
const FcObjectSetAddFn = *const fn (*FcObjectSet, [*:0]const u8) callconv(.c) FcBool;
const FcFontListFn = *const fn (*FcConfig, *FcPattern, *FcObjectSet) callconv(.c) ?*FcFontSet;
const FcFontSetDestroyFn = *const fn (*FcFontSet) callconv(.c) void;
const FcPatternGetStringFn = *const fn (*FcPattern, [*:0]const u8, c_int, *?[*:0]const FcChar8) callconv(.c) FcResult;
const FcPatternGetIntegerFn = *const fn (*FcPattern, [*:0]const u8, c_int, *c_int) callconv(.c) FcResult;

/// Resolved function pointers. `load` is all-or-nothing so a partially
/// initialized API can never be used.
const Api = struct {
    init_load_config_and_fonts: FcInitLoadConfigAndFontsFn,
    config_destroy: FcConfigDestroyFn,
    pattern_create: FcPatternCreateFn,
    pattern_destroy: FcPatternDestroyFn,
    object_set_create: FcObjectSetCreateFn,
    object_set_destroy: FcObjectSetDestroyFn,
    object_set_add: FcObjectSetAddFn,
    font_list: FcFontListFn,
    font_set_destroy: FcFontSetDestroyFn,
    pattern_get_string: FcPatternGetStringFn,
    pattern_get_integer: FcPatternGetIntegerFn,

    fn load(lib: *std.DynLib) ?Api {
        return .{
            .init_load_config_and_fonts = lib.lookup(FcInitLoadConfigAndFontsFn, "FcInitLoadConfigAndFonts") orelse return null,
            .config_destroy = lib.lookup(FcConfigDestroyFn, "FcConfigDestroy") orelse return null,
            .pattern_create = lib.lookup(FcPatternCreateFn, "FcPatternCreate") orelse return null,
            .pattern_destroy = lib.lookup(FcPatternDestroyFn, "FcPatternDestroy") orelse return null,
            .object_set_create = lib.lookup(FcObjectSetCreateFn, "FcObjectSetCreate") orelse return null,
            .object_set_destroy = lib.lookup(FcObjectSetDestroyFn, "FcObjectSetDestroy") orelse return null,
            .object_set_add = lib.lookup(FcObjectSetAddFn, "FcObjectSetAdd") orelse return null,
            .font_list = lib.lookup(FcFontListFn, "FcFontList") orelse return null,
            .font_set_destroy = lib.lookup(FcFontSetDestroyFn, "FcFontSetDestroy") orelse return null,
            .pattern_get_string = lib.lookup(FcPatternGetStringFn, "FcPatternGetString") orelse return null,
            .pattern_get_integer = lib.lookup(FcPatternGetIntegerFn, "FcPatternGetInteger") orelse return null,
        };
    }
};

/// Platform-appropriate library candidate names. macOS also probes the
/// Homebrew/usr-local prefixes so a non-standard install is found without
/// DYLD settings; Windows names match msys2/vcpkg builds.
fn libCandidates() []const []const u8 {
    return switch (builtin.os.tag) {
        .linux, .freebsd, .netbsd, .openbsd, .dragonfly, .illumos => &[_][]const u8{
            "libfontconfig.so.1",
            "libfontconfig.so",
        },
        .macos, .ios, .tvos, .watchos, .visionos, .driverkit, .maccatalyst => &[_][]const u8{
            "libfontconfig.1.dylib",
            "libfontconfig.dylib",
            "/opt/homebrew/lib/libfontconfig.1.dylib",
            "/opt/homebrew/lib/libfontconfig.dylib",
            "/usr/local/lib/libfontconfig.1.dylib",
            "/usr/local/lib/libfontconfig.dylib",
        },
        .windows => &[_][]const u8{
            "fontconfig-1.dll",
            "libfontconfig-1.dll",
        },
        else => &[_][]const u8{},
    };
}

/// Open the first candidate library that resolves the full symbol set and
/// yields a font configuration. Returns null (never an error) when no
/// candidate works.
fn loadFrom(candidates: []const []const u8) ?Fontconfig {
    for (candidates) |name| {
        var lib = std.DynLib.open(name) catch continue;
        const api = Api.load(&lib) orelse {
            lib.close();
            continue;
        };
        const config = api.init_load_config_and_fonts() orelse {
            lib.close();
            continue;
        };
        return .{ .lib = lib, .api = api, .config = config };
    }
    return null;
}

/// Loaded libfontconfig plus configuration. `load()` returns null when the
/// library is unavailable, symbols are missing, or the config cannot be
/// created (including platforms where `std.DynLib` has no implementation).
pub const Fontconfig = struct {
    lib: std.DynLib,
    api: Api,
    config: *FcConfig,

    /// Never fails: null means "fontconfig not usable here".
    ///
    /// The condition is comptime-known, so the `std.DynLib` code below is
    /// not even semantically analyzed on targets without a backend (e.g.
    /// Windows), which keeps this module cross-compilable.
    pub fn load() ?Fontconfig {
        if (dynlib_supported) {
            return loadFrom(libCandidates());
        } else {
            return null;
        }
    }

    pub fn deinit(self: *Fontconfig) void {
        self.api.config_destroy(self.config);
        if (dynlib_supported) self.lib.close();
        self.* = undefined;
    }

    /// True when a temporary load + list round-trip could be started.
    pub fn isAvailable() bool {
        var fc = load() orelse return false;
        fc.deinit();
        return true;
    }

    /// Copy metadata for every configured face. The returned slice (and every
    /// `Face` inside) is owned by the caller: free with `freeFaces`.
    /// Duplicate (path, index) entries are collapsed.
    ///
    /// The `FcFontSet` returned by the library is untrusted: null array
    /// pointers, bogus counts, and null pattern slots are skipped rather
    /// than followed, so a corrupt system configuration cannot make this
    /// function read out of bounds.
    pub fn list(self: *Fontconfig, allocator: std.mem.Allocator) ![]Face {
        const api = &self.api;

        const pattern = api.pattern_create() orelse return error.OutOfMemory;
        defer api.pattern_destroy(pattern);
        const objects = api.object_set_create() orelse return error.OutOfMemory;
        defer api.object_set_destroy(objects);
        for ([_][*:0]const u8{
            FC_FAMILY,
            FC_STYLE,
            FC_SLANT,
            FC_WEIGHT,
            FC_WIDTH,
            FC_SPACING,
            FC_FILE,
            FC_INDEX,
            FC_POSTSCRIPT_NAME,
        }) |object| {
            if (api.object_set_add(objects, object) == 0) return error.OutOfMemory;
        }

        const set = api.font_list(self.config, pattern, objects) orelse return error.FontconfigListFailed;
        defer api.font_set_destroy(set);

        var faces = std.ArrayList(Face).empty;
        errdefer {
            for (faces.items) |*face| face.deinit(allocator);
            faces.deinit(allocator);
        }
        var seen = std.HashMapUnmanaged(FaceKey, void, FaceKeyContext, 80).empty;
        defer seen.deinit(allocator);

        const count = fontSetCount(set.*);
        const patterns = set.fonts orelse return faces.toOwnedSlice(allocator);
        var i: usize = 0;
        while (i < count) : (i += 1) {
            // A corrupt set can carry null slots inside its populated range;
            // skip them instead of handing a null pattern to fontconfig.
            const pattern_ptr = patterns[i] orelse continue;
            var face = self.faceFromPattern(allocator, pattern_ptr) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.FontconfigFaceMissingPath => continue,
            };
            const key = FaceKey{ .path = face.path, .index = face.index };
            if (seen.contains(key)) {
                face.deinit(allocator);
                continue;
            }
            seen.put(allocator, key, {}) catch |err| {
                face.deinit(allocator);
                return err;
            };
            faces.append(allocator, face) catch |err| {
                face.deinit(allocator);
                return err;
            };
        }
        return faces.toOwnedSlice(allocator);
    }

    fn faceFromPattern(self: *Fontconfig, allocator: std.mem.Allocator, pattern: *FcPattern) !Face {
        const api = &self.api;

        var path_raw: ?[*:0]const FcChar8 = null;
        if (api.pattern_get_string(pattern, FC_FILE, 0, &path_raw) != .FcResultMatch) {
            return error.FontconfigFaceMissingPath;
        }
        const path_ptr = path_raw orelse return error.FontconfigFaceMissingPath;
        // `std.mem.span` yields a NUL-terminated `[:0]const u8` whose length
        // stays `usize` through `dupe`; no narrowing cast is involved. The
        // string itself is fontconfig-owned and NUL-terminated by the ABI.
        const path = try allocator.dupe(u8, std.mem.span(path_ptr));
        errdefer allocator.free(path);

        var families = std.ArrayList([]u8).empty;
        errdefer {
            for (families.items) |family| allocator.free(family);
            families.deinit(allocator);
        }
        var family_id: c_int = 0;
        // Bounded count plus `usize` lengths: the loop can never overflow the
        // c_int counter and `dupe` never narrows the family length.
        while (family_id < MAX_FAMILY_NAMES) : (family_id += 1) {
            var family_raw: ?[*:0]const FcChar8 = null;
            if (api.pattern_get_string(pattern, FC_FAMILY, family_id, &family_raw) != .FcResultMatch) break;
            const family_ptr = family_raw orelse continue;
            const family_src = std.mem.span(family_ptr);
            if (family_src.len == 0) continue;
            var duplicate = false;
            for (families.items) |existing| {
                if (std.mem.eql(u8, existing, family_src)) {
                    duplicate = true;
                    break;
                }
            }
            if (duplicate) continue;
            try families.append(allocator, try allocator.dupe(u8, family_src));
        }

        var post_src: []const u8 = "";
        var post_raw: ?[*:0]const FcChar8 = null;
        if (api.pattern_get_string(pattern, FC_POSTSCRIPT_NAME, 0, &post_raw) == .FcResultMatch) {
            if (post_raw) |ptr| post_src = std.mem.span(ptr);
        }
        const post = try allocator.dupe(u8, post_src);
        errdefer allocator.free(post);

        return .{
            .path = path,
            .index = faceIndexFromFc(patternInteger(api, pattern, FC_INDEX, 0)),
            .families = try families.toOwnedSlice(allocator),
            .post_script_name = post,
            .weight = weightToOs2(patternInteger(api, pattern, FC_WEIGHT, FC_WEIGHT_REGULAR)),
            .stretch = stretchFromFc(patternInteger(api, pattern, FC_WIDTH, FC_WIDTH_NORMAL)),
            .style = styleFromSlant(patternInteger(api, pattern, FC_SLANT, FC_SLANT_ROMAN)),
            .monospaced = patternInteger(api, pattern, FC_SPACING, FC_PROPORTIONAL) >= FC_MONO,
        };
    }
};

/// Upper bound on the number of font-set entries `list()` will walk.
///
/// `FcFontSet`'s C contract is that `fonts` has room for `sfont` slots and
/// `nfont` of them are populated; a corrupt or unusual set can report any
/// counts while the array is shorter, and the allocation size cannot be
/// read portably. 1 << 20 patterns (~8 MiB of pointer array on 64-bit) is
/// orders of magnitude larger than any real fontconfig font set (large
/// system installs enumerate well under 100k faces), so normal data is
/// never truncated while a bogus count cannot drive an unbounded walk.
const MAX_FONTSET_ITEMS: usize = 1 << 20;

/// Number of usable patterns in a fontconfig font set.
///
/// `nfont`/`sfont`/`fonts` come from the runtime library and are treated as
/// untrusted: a null `fonts` array or a zero/negative `nfont` means "empty"
/// (never a sign-extension to a huge `usize`), and a positive count is
/// clamped to `sfont` when `sfont > 0`, else to `MAX_FONTSET_ITEMS`. A
/// positive `sfont` is itself capped at `MAX_FONTSET_ITEMS`, so neither
/// field can produce unbounded trust. `sfont == 0` with a populated array
/// is accepted as old-library bookkeeping, but only within that bound.
fn fontSetCount(set: FcFontSet) usize {
    if (set.fonts == null or set.nfont <= 0) return 0;
    const nfont: usize = @intCast(set.nfont);
    const capacity: usize = if (set.sfont > 0)
        @min(@as(usize, @intCast(set.sfont)), MAX_FONTSET_ITEMS)
    else
        MAX_FONTSET_ITEMS;
    return @min(nfont, capacity);
}

/// Fetch an integer pattern property. Any `c_int` stored by fontconfig is
/// returned verbatim, including `INT_MIN`/`INT_MAX`: callers validate or
/// clamp through the mapping helpers, so this function never narrows.
/// Missing, mismatched, or unreadable properties fall back to `default`.
fn patternInteger(api: *const Api, pattern: *FcPattern, object: [*:0]const u8, default: c_int) c_int {
    var value: c_int = default;
    if (api.pattern_get_integer(pattern, object, 0, &value) != .FcResultMatch) return default;
    return value;
}

const FaceKey = struct {
    path: []const u8,
    index: u32,
};

const FaceKeyContext = struct {
    pub fn hash(_: FaceKeyContext, key: FaceKey) u64 {
        var h = std.hash.Wyhash.init(0);
        h.update(key.path);
        h.update(std.mem.asBytes(&key.index));
        return h.final();
    }

    pub fn eql(_: FaceKeyContext, a: FaceKey, b: FaceKey) bool {
        return a.index == b.index and std.mem.eql(u8, a.path, b.path);
    }
};

// ---------------------------------------------------------------------------
// Tests.
// ---------------------------------------------------------------------------

test "fontconfig mapping helpers" {
    const t = std.testing;
    // Weights: each FC_WEIGHT_* anchor maps to its OS/2 counterpart.
    try t.expectEqual(@as(u16, 100), weightToOs2(FC_WEIGHT_THIN));
    try t.expectEqual(@as(u16, 200), weightToOs2(FC_WEIGHT_EXTRALIGHT));
    try t.expectEqual(@as(u16, 300), weightToOs2(FC_WEIGHT_LIGHT));
    try t.expectEqual(@as(u16, 350), weightToOs2(FC_WEIGHT_DEMILIGHT));
    try t.expectEqual(@as(u16, 400), weightToOs2(FC_WEIGHT_BOOK));
    try t.expectEqual(@as(u16, 400), weightToOs2(FC_WEIGHT_REGULAR));
    try t.expectEqual(@as(u16, 500), weightToOs2(FC_WEIGHT_MEDIUM));
    try t.expectEqual(@as(u16, 600), weightToOs2(FC_WEIGHT_DEMIBOLD));
    try t.expectEqual(@as(u16, 700), weightToOs2(FC_WEIGHT_BOLD));
    try t.expectEqual(@as(u16, 800), weightToOs2(FC_WEIGHT_EXTRABOLD));
    try t.expectEqual(@as(u16, 900), weightToOs2(FC_WEIGHT_BLACK));
    try t.expectEqual(@as(u16, 950), weightToOs2(FC_WEIGHT_EXTRABLACK));
    // Out-of-range values clamp to the nearest extreme anchor.
    try t.expectEqual(@as(u16, 100), weightToOs2(-1000));
    try t.expectEqual(@as(u16, 950), weightToOs2(1000));

    // Widths: stretch numbering 1..9 with clamping at both ends.
    try t.expectEqual(@as(u8, 1), stretchFromFc(FC_WIDTH_ULTRACONDENSED));
    try t.expectEqual(@as(u8, 2), stretchFromFc(FC_WIDTH_EXTRACONDENSED));
    try t.expectEqual(@as(u8, 3), stretchFromFc(FC_WIDTH_CONDENSED));
    try t.expectEqual(@as(u8, 4), stretchFromFc(FC_WIDTH_SEMICONDENSED));
    try t.expectEqual(@as(u8, 5), stretchFromFc(FC_WIDTH_NORMAL));
    try t.expectEqual(@as(u8, 6), stretchFromFc(FC_WIDTH_SEMIEXPANDED));
    try t.expectEqual(@as(u8, 7), stretchFromFc(FC_WIDTH_EXPANDED));
    try t.expectEqual(@as(u8, 8), stretchFromFc(FC_WIDTH_EXTRAEXPANDED));
    try t.expectEqual(@as(u8, 9), stretchFromFc(FC_WIDTH_ULTRAEXPANDED));
    try t.expectEqual(@as(u8, 1), stretchFromFc(0));
    try t.expectEqual(@as(u8, 9), stretchFromFc(1000));

    // Slants: roman/italic/oblique plus in-between and out-of-range values.
    try t.expectEqual(STYLE_NORMAL, styleFromSlant(FC_SLANT_ROMAN));
    try t.expectEqual(STYLE_ITALIC, styleFromSlant(FC_SLANT_ITALIC));
    try t.expectEqual(STYLE_OBLIQUE, styleFromSlant(FC_SLANT_OBLIQUE));
    try t.expectEqual(STYLE_NORMAL, styleFromSlant(50));
    try t.expectEqual(STYLE_ITALIC, styleFromSlant(105));
    try t.expectEqual(STYLE_OBLIQUE, styleFromSlant(2000));
    try t.expectEqual(STYLE_NORMAL, styleFromSlant(-5));
}

test "fontconfig mapping helpers are total at c_int extremes" {
    const t = std.testing;
    const c_min = std.math.minInt(c_int);
    const c_max = std.math.maxInt(c_int);

    // Exact differences can exceed `maxInt(c_int)` (up to 2^32 - 1); the
    // widened helper must return them instead of trapping in a cast.
    try t.expectEqual(@as(u64, 0), absDiffCInt(0, 0));
    try t.expectEqual(@as(u64, 1), absDiffCInt(c_min, c_min + 1));
    try t.expectEqual(@as(u64, 4294967295), absDiffCInt(c_min, c_max));

    // Extreme weights clamp to the extreme anchors instead of panicking.
    try t.expectEqual(@as(u16, 100), weightToOs2(c_min));
    try t.expectEqual(@as(u16, 950), weightToOs2(c_max));
    // Normal values keep the previous nearest-anchor selection:
    // FC_WEIGHT_REGULAR (80) -> OS/2 400, FC_WEIGHT_BOLD (200) -> OS/2 700.
    try t.expectEqual(@as(u16, 400), weightToOs2(FC_WEIGHT_REGULAR));
    try t.expectEqual(@as(u16, 700), weightToOs2(FC_WEIGHT_BOLD));
    try t.expectEqual(@as(u16, 400), weightToOs2(79));

    // Extreme widths clamp to 1 / 9; the canonical 50/100/200 anchors map
    // to stretch 1/5/9.
    try t.expectEqual(@as(u8, 1), stretchFromFc(c_min));
    try t.expectEqual(@as(u8, 9), stretchFromFc(c_max));
    try t.expectEqual(@as(u8, 1), stretchFromFc(50));
    try t.expectEqual(@as(u8, 5), stretchFromFc(100));
    try t.expectEqual(@as(u8, 9), stretchFromFc(200));

    // Slant is branch-only and total for extremes too.
    try t.expectEqual(STYLE_NORMAL, styleFromSlant(c_min));
    try t.expectEqual(STYLE_OBLIQUE, styleFromSlant(c_max));
}

test "fontconfig index decode clamps negatives and keeps instance bits" {
    const t = std.testing;
    try t.expectEqual(@as(u32, 0), faceIndexFromFc(-1));
    try t.expectEqual(@as(u32, 0), faceIndexFromFc(0));
    try t.expectEqual(@as(u32, 0), faceIndexFromFc(std.math.minInt(c_int)));
    try t.expectEqual(@as(u32, std.math.maxInt(c_int)), faceIndexFromFc(std.math.maxInt(c_int)));
    try t.expectEqual(@as(u32, 3), faceIndexFromFc(3));
    // FreeType variable-font named-instance bits (if fontconfig ever packs
    // them) pass through verbatim so the shaper opens the same instance.
    try t.expectEqual(@as(u32, 0x0001_0002), faceIndexFromFc(0x0001_0002));
}

test "fontconfig font-set count is total for corrupt counts" {
    const t = std.testing;
    var storage = [_]?*FcPattern{ null, null, null, null };

    // A null array pointer always means "empty", whatever the counts claim.
    try t.expectEqual(@as(usize, 0), fontSetCount(.{ .nfont = 0, .sfont = 0, .fonts = null }));
    try t.expectEqual(@as(usize, 0), fontSetCount(.{ .nfont = -1, .sfont = 0, .fonts = null }));
    try t.expectEqual(@as(usize, 0), fontSetCount(.{ .nfont = std.math.minInt(c_int), .sfont = 0, .fonts = null }));
    try t.expectEqual(@as(usize, 0), fontSetCount(.{ .nfont = 4, .sfont = 4, .fonts = null }));
    try t.expectEqual(@as(usize, 0), fontSetCount(.{ .nfont = 1000, .sfont = 2, .fonts = null }));

    // Normal sets (`nfont <= sfont`) are passed through unchanged.
    try t.expectEqual(@as(usize, 3), fontSetCount(.{ .nfont = 3, .sfont = 4, .fonts = &storage }));
    try t.expectEqual(@as(usize, 4), fontSetCount(.{ .nfont = 4, .sfont = 4, .fonts = &storage }));
    // A positive `nfont` beyond a positive capacity is clamped ...
    try t.expectEqual(@as(usize, 2), fontSetCount(.{ .nfont = 1000, .sfont = 2, .fonts = &storage }));
    // ... and `sfont == 0` with a populated array is old-library
    // bookkeeping, so a plausible `nfont` is still honored ...
    try t.expectEqual(@as(usize, 3), fontSetCount(.{ .nfont = 3, .sfont = 0, .fonts = &storage }));
    // ... but an implausible one is capped at the sane bound instead of
    // trusted, whether `nfont` alone or a corrupt positive `sfont` too is
    // huge.
    try t.expectEqual(MAX_FONTSET_ITEMS, fontSetCount(.{ .nfont = std.math.maxInt(c_int), .sfont = 0, .fonts = &storage }));
    try t.expectEqual(MAX_FONTSET_ITEMS, fontSetCount(.{ .nfont = std.math.maxInt(c_int), .sfont = std.math.maxInt(c_int), .fonts = &storage }));
    // Zero/negative counts stay empty even with a live array pointer.
    try t.expectEqual(@as(usize, 0), fontSetCount(.{ .nfont = 0, .sfont = 4, .fonts = &storage }));
    try t.expectEqual(@as(usize, 0), fontSetCount(.{ .nfont = std.math.minInt(c_int), .sfont = 4, .fonts = &storage }));
}

test "fontconfig list skips corrupt font-set entries instead of following them" {
    const t = std.testing;
    const Mock = struct {
        var set: FcFontSet = .{ .nfont = 0, .sfont = 0, .fonts = null };
        var list_calls: usize = 0;

        fn patternCreate() callconv(.c) ?*FcPattern {
            return @ptrFromInt(0x1000);
        }
        fn patternDestroy(_: *FcPattern) callconv(.c) void {}
        fn objectSetCreate() callconv(.c) ?*FcObjectSet {
            return @ptrFromInt(0x2000);
        }
        fn objectSetDestroy(_: *FcObjectSet) callconv(.c) void {}
        fn objectSetAdd(_: *FcObjectSet, _: [*:0]const u8) callconv(.c) FcBool {
            return 1;
        }
        fn fontList(_: *FcConfig, _: *FcPattern, _: *FcObjectSet) callconv(.c) ?*FcFontSet {
            list_calls += 1;
            return &set;
        }
        fn fontSetDestroy(_: *FcFontSet) callconv(.c) void {}
    };

    // Only the entry points `list()` uses are wired up; the rest stay
    // undefined, so an unexpected call traps in the test rather than
    // silently succeeding.
    var api: Api = undefined;
    api.pattern_create = Mock.patternCreate;
    api.pattern_destroy = Mock.patternDestroy;
    api.object_set_create = Mock.objectSetCreate;
    api.object_set_destroy = Mock.objectSetDestroy;
    api.object_set_add = Mock.objectSetAdd;
    api.font_list = Mock.fontList;
    api.font_set_destroy = Mock.fontSetDestroy;
    var fc = Fontconfig{ .lib = undefined, .api = api, .config = undefined };

    // `fonts == null` with positive counts: empty, no iteration.
    Mock.set = .{ .nfont = 4, .sfont = 4, .fonts = null };
    var faces = try fc.list(t.allocator);
    try t.expectEqual(@as(usize, 0), faces.len);
    freeFaces(t.allocator, faces);

    // Null slots inside the populated range are skipped, not dereferenced.
    var storage = [_]?*FcPattern{ null, null, null, null };
    Mock.set = .{ .nfont = 4, .sfont = 4, .fonts = &storage };
    faces = try fc.list(t.allocator);
    try t.expectEqual(@as(usize, 0), faces.len);
    freeFaces(t.allocator, faces);

    // The `nfont > sfont` clamp bounds the walk to `sfont` slots.
    Mock.set = .{ .nfont = 1000, .sfont = 2, .fonts = &storage };
    faces = try fc.list(t.allocator);
    try t.expectEqual(@as(usize, 0), faces.len);
    freeFaces(t.allocator, faces);

    try t.expectEqual(@as(usize, 3), Mock.list_calls);
}

test "patternInteger passes c_int extremes through without narrowing" {
    const t = std.testing;
    const Mock = struct {
        var value: c_int = 0;
        var result: FcResult = .FcResultMatch;
        fn get(_: *FcPattern, _: [*:0]const u8, _: c_int, out: *c_int) callconv(.c) FcResult {
            if (result != .FcResultMatch) return result;
            out.* = value;
            return .FcResultMatch;
        }
    };
    var api: Api = undefined;
    api.pattern_get_integer = Mock.get;
    const pattern: *FcPattern = undefined;

    Mock.result = .FcResultMatch;
    Mock.value = std.math.minInt(c_int);
    try t.expectEqual(std.math.minInt(c_int), patternInteger(&api, pattern, FC_WEIGHT, 0));
    Mock.value = std.math.maxInt(c_int);
    try t.expectEqual(std.math.maxInt(c_int), patternInteger(&api, pattern, FC_WEIGHT, 0));

    // A mismatch must fall back to the default, never leak the output slot.
    Mock.result = .FcResultTypeMismatch;
    Mock.value = 123;
    try t.expectEqual(@as(c_int, 400), patternInteger(&api, pattern, FC_WEIGHT, 400));
    Mock.result = .FcResultNoMatch;
    try t.expectEqual(@as(c_int, -7), patternInteger(&api, pattern, FC_WEIGHT, -7));
}

test "malformed or missing library returns null" {
    const t = std.testing;
    if (dynlib_supported) {
        // A bogus basename and a bogus path must both fail cleanly (no
        // panic, no error propagation). The branch is comptime-known so
        // targets without a `std.DynLib` backend never analyze `loadFrom`.
        try t.expect(loadFrom(&[_][]const u8{
            "zui-no-such-fontconfig-zzz.so.99",
            "/nonexistent/dir/zui-no-such-fontconfig.dylib",
        }) == null);
    } else {
        try t.expect(Fontconfig.load() == null);
    }
}

test "fontconfig load is optional and list is well-formed" {
    const t = std.testing;
    var fc = Fontconfig.load() orelse return error.SkipZigTest;
    defer fc.deinit();

    const faces = try fc.list(t.allocator);
    defer freeFaces(t.allocator, faces);
    try t.expect(faces.len > 0);
    for (faces) |face| {
        try t.expect(face.path.len > 0);
        try t.expect(face.style <= STYLE_OBLIQUE);
        try t.expect(face.weight > 0);
        try t.expect(face.stretch >= 1 and face.stretch <= 9);
    }
    // Dedup guarantee: no two faces share the same (path, index).
    for (faces, 0..) |a, i| {
        for (faces[i + 1 ..]) |b| {
            if (std.mem.eql(u8, a.path, b.path)) {
                try t.expect(a.index != b.index);
            }
        }
    }
}
