//! FreeType-backed raster registry: the seam between glyph cache keys and
//! real glyph bitmaps.
//!
//! `swash_cache.SwashCache` originally rasterized through `FallbackRaster`, a
//! solid-mask stand-in with no font bytes. `Raster` here owns what FreeType
//! needs (one `FT_Library` plus faces keyed by cozmic `font_id`) and turns a
//! `glyph_cache.CacheKey`'s font/glyph/size/flags into a
//! `raster_ft.Rendered`. Attach it with `SwashCache.setRaster` and
//! `getImage`/`withPixels` serve real coverage masks or (for color fonts)
//! straight-RGBA color images; with nothing attached the cache keeps its
//! previous stand-in behaviour.
//!
//! ## Lifetime and ownership
//!
//! - `addFont` **copies** `bytes`: `raster_ft.Face.initMemory` borrows the
//!   buffer for the lifetime of the face, so the caller keeps ownership of
//!   its slice. The copy lives in the matching `FaceEntry` and is freed after
//!   `Face.deinit` (order matters: FreeType must never see freed bytes).
//! - `addFontSource` registers a **path** without reading it; the bytes are
//!   read on the first `rasterize`/`getFace` and freed after `Face.deinit` in
//!   `deinit`. Unknown or unloadable sources resolve to a `null` face (a
//!   cache miss), never a panic. A non-OOM load failure is negatively cached
//!   (`load_error`) and retried once on a later call, so a file that reappears
//!   recovers; `error.OutOfMemory` is transient and never cached (`rasterize`
//!   propagates it instead of converting it to a miss).
//! - `raster_ft.Face` stores a pointer to the `Raster.library` field, so a
//!   `Raster` must not be moved or copied after the first `addFont`. `init`
//!   returning by value is safe because it cannot have faces yet; keep the
//!   value pinned afterwards (a local or allocated `Raster`, not a temporary).
//! - `Rendered.bitmap` borrows the FreeType glyph slot and is invalidated by
//!   the next `rasterize` call. The one consumer (`SwashCache`) copies it into
//!   its own image immediately.
//! - Not thread-safe, like the underlying FreeType objects: one `Raster` per
//!   thread, or serialize access externally. Independent `Raster`s may run on
//!   different threads; the one piece of process-wide state they share is the
//!   single-threaded `std.Io.Threaded.global_single_threaded` instance used by
//!   lazy reads, which is serialized by the module-level `lazyReadMutex`.

const std = @import("std");
const raster_ft = @import("raster_ft.zig");
const glyph_cache = @import("glyph_cache.zig");
const font_system = @import("font_system.zig");

/// Upper bound for lazily reading a single font file (64 MiB), matching the
/// other font readers in this port.
pub const MAX_SOURCE_BYTES: usize = 1 << 26;

/// Where a registered face's bytes come from. All memory (the byte copy or
/// the path string) is owned by the `FaceEntry`.
pub const FaceSource = union(enum) {
    /// Eagerly registered owned bytes (`Raster.addFont`); loaded immediately.
    bytes: []u8,
    /// Lazily loaded file registered by `Raster.addFontSource`; read on first
    /// `rasterize`/`getFace`.
    path: struct {
        path: []u8,
        index: i32,
    },
};

/// One registered font: the cozmic id, its source, the owned byte copy
/// FreeType borrows (once loaded), and the live face.
pub const FaceEntry = struct {
    font_id: u32,
    source: FaceSource,
    /// Owned bytes once loaded; aliases `source.bytes` for eager entries.
    bytes: ?[]u8 = null,
    face: ?raster_ft.Face = null,
    loaded: bool = false,
    /// Negative cache: a failed lazy load is not retried on every call.
    load_error: bool = false,
    /// One extra attempt is allowed after a negative-cache hit, so a file
    /// that reappears clears `load_error`; only a persistent failure of that
    /// retry stays cached (OOM never sets this). Reset when a load succeeds.
    /// Mirrors `shape_hb.FontEntry.load_retried`.
    load_retried: bool = false,

    fn destroy(self: *FaceEntry, allocator: std.mem.Allocator) void {
        if (self.face) |*face| face.deinit();
        switch (self.source) {
            // `self.bytes` aliases `source.bytes` for eager entries, so free
            // the source allocation exactly once.
            .bytes => |bytes| allocator.free(bytes),
            .path => |p| {
                if (self.bytes) |bytes| allocator.free(bytes);
                allocator.free(p.path);
            },
        }
        self.* = undefined;
    }
};

/// Minimal mutual-exclusion lock for the process-wide lazy-read guard.
///
/// `dynload.Mutex` cannot be reused here: `dynload.zig` is the root of a
/// separate module, and importing that file into the cozmic module is rejected
/// ("file exists in modules 'cozmic' and 'dynload'"). Zig 0.17 has no
/// `std.Thread.Mutex`, and `std.Io.Mutex` needs an `Io` this module does not
/// own, so this is the same CAS-plus-yield lock `dynload` uses; contention
/// only happens while a font file is read.
const SpinMutex = struct {
    inner: std.atomic.Mutex = .unlocked,

    fn lock(self: *SpinMutex) void {
        while (!self.inner.tryLock()) {
            std.Thread.yield() catch std.atomic.spinLoopHint();
        }
    }

    fn unlock(self: *SpinMutex) void {
        self.inner.unlock();
    }
};

/// Process-wide lock for lazy source reads.
///
/// `Raster` has no `std.Io` parameter, so lazy loads go through the
/// process-wide single-threaded I/O instance; that instance is shared by every
/// `Raster`, so two independent rasters loading files on different threads
/// would race inside it without this lock.
var lazyReadMutex: SpinMutex = .{};

/// Read a lazily registered font file. `Raster` has no `std.Io` parameter, so
/// lazy loads go through the process-wide single-threaded I/O instance;
/// callers that own a real `Io` can still register bytes eagerly. The read is
/// serialized against other rasters by `lazyReadMutex`; the per-raster state
/// (entries, `FT_Face`s) is still single-threaded by contract.
fn readSourceFile(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    lazyReadMutex.lock();
    defer lazyReadMutex.unlock();
    return std.Io.Dir.cwd().readFileAlloc(
        std.Io.Threaded.global_single_threaded.io(),
        path,
        allocator,
        .limited(MAX_SOURCE_BYTES),
    );
}

/// Registry of FreeType faces, one per cozmic `font_id`.
pub const Raster = struct {
    allocator: std.mem.Allocator,
    library: raster_ft.Library,
    faces: std.ArrayList(FaceEntry) = .empty,

    /// Create an empty registry. `deinit` must be called exactly once.
    pub fn init(allocator: std.mem.Allocator) !Raster {
        return .{
            .allocator = allocator,
            .library = try raster_ft.Library.init(),
        };
    }

    pub fn deinit(self: *Raster) void {
        for (self.faces.items) |*entry| entry.destroy(self.allocator);
        self.faces.deinit(self.allocator);
        self.library.deinit();
        self.* = undefined;
    }

    /// Register (or replace) the font bytes for `font_id`; `index` selects a
    /// face inside a collection (`0` for a single-face file).
    ///
    /// The bytes are copied and stay alive for the lifetime of the entry. A
    /// repeated `font_id` replaces the previous entry (last registration
    /// wins), matching `shape_hb.Backend.addFont`.
    pub fn addFont(self: *Raster, font_id: u32, bytes: []const u8, index: i32) !void {
        const entry = try self.makeEntry(font_id, bytes, index);
        try self.insertEntry(entry);
    }

    /// Register font file `path` (face `index` inside a collection) for
    /// `font_id` **without reading the file**. The bytes are read on the first
    /// `rasterize`/`getFace`; non-OOM failures degrade to a `null` face and
    /// are negatively cached (with one retry on a later call). A repeated
    /// `font_id` replaces the previous entry.
    pub fn addFontSource(self: *Raster, font_id: u32, path: []const u8, index: i32) !void {
        const owned_path = try self.allocator.dupe(u8, path);
        const entry = FaceEntry{
            .font_id = font_id,
            .source = .{ .path = .{ .path = owned_path, .index = index } },
        };
        // `insertEntry` takes ownership and frees `owned_path` on failure.
        try self.insertEntry(entry);
    }

    /// Insert `entry`, replacing any existing entry with the same id. Takes
    /// ownership of `entry` in every case (including failure).
    fn insertEntry(self: *Raster, entry: FaceEntry) !void {
        for (self.faces.items) |*old| {
            if (old.font_id == entry.font_id) {
                old.destroy(self.allocator);
                old.* = entry;
                return;
            }
        }
        self.faces.append(self.allocator, entry) catch |err| {
            var owned = entry;
            owned.destroy(self.allocator);
            return err;
        };
    }

    /// Register every id in `ids` from `fs`: eager bytes when the font was
    /// registered through `addFontData`, otherwise a lazy source path from
    /// `fs.fontSourcePath` (the file is not read here).
    ///
    /// `FontSystem` cannot enumerate registered ids, so the caller passes the
    /// explicit list (typically `fs.fontIds()`). All ids are validated first,
    /// so a typo cannot leave a half-populated registry: an id with neither
    /// bytes nor a source path (`fs.fontBytes`/`fs.fontSourcePath`, i.e. never
    /// registered) fails with `error.FontNotRegistered`. A registered source
    /// that is currently unusable (`fs.canUseFontSource` false, e.g. a lazy
    /// source whose shaper-side load was negatively cached) is **skipped**
    /// instead: it cannot migrate to the raster, and failing the batch would
    /// block the healthy ids next to it.
    pub fn addFromFontSystem(
        self: *Raster,
        fs: *const font_system.FontSystem,
        ids: []const u32,
    ) !void {
        for (ids) |id| {
            if (fs.fontBytes(id) == null and fs.fontSourcePath(id) == null) {
                return error.FontNotRegistered;
            }
        }
        for (ids) |id| {
            if (fs.fontBytes(id)) |bytes| {
                try self.addFont(id, bytes, 0);
                continue;
            }
            const path = fs.fontSourcePath(id) orelse return error.FontNotRegistered;
            // Registered but broken: it cannot migrate and the batch must not
            // fail because of it. Re-registering the id later replaces the
            // entry with a fresh lazy source.
            if (!fs.canUseFontSource(id)) continue;
            // Keep the collection face index when the database knows it;
            // single-face files use 0.
            const index: i32 = if (fs.db.face(id)) |f|
                (if (f.index <= std.math.maxInt(i32)) @intCast(f.index) else 0)
            else
                0;
            try self.addFontSource(id, path, index);
        }
    }

    /// Borrowed face for `font_id`, or `null` when the id is not registered or
    /// its lazy source could not be loaded. Lazy entries are read on demand; a
    /// non-OOM failure is negatively cached and retried once on a later call.
    ///
    /// `error.OutOfMemory` is transient and never poisons the entry, but this
    /// infallible signature cannot report it: a direct `getFace` consumer sees
    /// the same `null` for a retryable allocation failure and for an unknown
    /// or genuinely missing font, and cannot tell them apart. Use `ensureFace`
    /// when the distinction matters (`rasterize` propagates OOM through its
    /// error union either way).
    pub fn getFace(self: *Raster, font_id: u32) ?*raster_ft.Face {
        return self.ensureFace(font_id) catch null;
    }

    /// Fallible lookup behind `getFace`/`rasterize`: a registered id whose
    /// lazy source cannot be loaded is a `null` miss (the failure is already
    /// negative-cached by `ensureEntryLoaded`), an unknown id is `null`, while
    /// `error.OutOfMemory` propagates so callers that can handle errors do not
    /// have to read a transient allocation failure as "not found".
    pub fn ensureFace(self: *Raster, font_id: u32) !?*raster_ft.Face {
        for (self.faces.items) |*entry| {
            if (entry.font_id != font_id) continue;
            if (!entry.loaded) {
                self.ensureEntryLoaded(entry) catch |err| {
                    if (err == error.OutOfMemory) return error.OutOfMemory;
                    return null;
                };
            }
            if (!entry.loaded) return null;
            return &entry.face.?;
        }
        return null;
    }

    /// True when a `null` from `rasterize` for `font_id` means "missing glyph"
    /// rather than "the registered source is currently unusable".
    ///
    /// - Unknown ids return `true`: registration is not what this answers, and
    ///   `rasterize` reports an unknown id as an ordinary (negatively cached)
    ///   `null` miss.
    /// - Loaded entries and not-yet-touched lazy entries return `true` (a load
    ///   attempt can still run).
    /// - Registered entries with a cached lazy-load failure (`load_error`)
    ///   return `false`, including the window where the single retry is still
    ///   pending, so a caller cannot mistake a source failure for a missing
    ///   glyph and cache it permanently.
    ///
    /// Never reads a file, clears the failure, or consumes the retry: callers
    /// must still call `rasterize`/`ensureFace` to give the retry a chance.
    /// Re-registering the id (`addFont`/`addFontSource`) replaces the entry and
    /// makes it usable again.
    pub fn canUse(self: *const Raster, font_id: u32) bool {
        for (self.faces.items) |*entry| {
            if (entry.font_id == font_id) return !entry.load_error;
        }
        return true;
    }

    /// Number of registered faces whose bytes are loaded (eager registrations
    /// plus lazy ones already touched). Test/consumer introspection.
    pub fn loadedCount(self: *const Raster) usize {
        var count: usize = 0;
        for (self.faces.items) |*entry| {
            if (entry.loaded) count += 1;
        }
        return count;
    }

    /// Rasterize `glyph_id` at `font_size` pixels and variable-font `weight`.
    ///
    /// `font_size` may be fractional; it is passed to FreeType's
    /// `FT_Set_Char_Size` at 72 dpi (sub-1/64px sizes are rejected). `weight`
    /// is applied as the `wght` design coordinate before loading (a no-op for
    /// static faces). Hinting is FreeType's default; `DISABLE_HINTING` adds
    /// `FT_LOAD_NO_HINTING`, `FAKE_ITALIC` applies the 14-degree skew, and
    /// `x_offset`/`y_offset` are the cache key's fractional subpixel offsets.
    /// Rendering is `FT_RENDER_MODE_NORMAL` (8-bit gray coverage) for
    /// outlines; color faces load with `FT_LOAD_COLOR` and come back as
    /// premultiplied `FT_PIXEL_MODE_BGRA` bitmaps (CBDT/sbix strikes, COLR
    /// layers), and bitmap-only faces fall back to their closest fixed strike.
    /// `SwashCache` converts those BGRA bitmaps to straight RGBA.
    ///
    /// Returns `null` when `font_id` is not registered or its lazy source
    /// could not be loaded (missing/unreadable file); `error.OutOfMemory` and
    /// other failures (bad glyph id, FreeType failure) propagate. The caller
    /// owns nothing: the returned bitmap borrows the face's glyph slot and is
    /// invalidated by the next `rasterize` call on the same font.
    pub fn rasterize(
        self: *Raster,
        font_id: u32,
        glyph_id: u16,
        font_size: f32,
        weight: u16,
        x_offset: f32,
        y_offset: f32,
        flags: glyph_cache.CacheKeyFlags,
    ) !?raster_ft.Rendered {
        const face = (try self.ensureFace(font_id)) orelse return null;
        var load_flags: c_int = raster_ft.FT_LOAD_DEFAULT;
        if (flags.contains(glyph_cache.CacheKeyFlags.DISABLE_HINTING)) {
            load_flags |= raster_ft.FT_LOAD_NO_HINTING;
        }
        const fake_italic = flags.contains(glyph_cache.CacheKeyFlags.FAKE_ITALIC);
        try face.setVariationWght(weight);
        return try face.loadRenderOffset(
            glyph_id,
            font_size,
            load_flags,
            x_offset,
            y_offset,
            fake_italic,
        );
    }

    fn makeEntry(self: *Raster, font_id: u32, bytes: []const u8, index: i32) !FaceEntry {
        const owned = try self.allocator.dupe(u8, bytes);
        errdefer self.allocator.free(owned);
        var entry = FaceEntry{
            .font_id = font_id,
            .source = .{ .bytes = owned },
            .bytes = owned,
        };
        try self.populate(&entry, index);
        return entry;
    }

    /// Build the FreeType face for `entry` from its bytes (already populated).
    fn populate(self: *Raster, entry: *FaceEntry, index: i32) !void {
        const bytes = switch (entry.source) {
            .bytes => |b| b,
            .path => entry.bytes orelse return error.FontUnavailable,
        };
        entry.face = try raster_ft.Face.initMemory(&self.library, bytes, index);
        entry.loaded = true;
    }

    /// Load `entry` lazily if needed.
    ///
    /// A non-OOM failure is negatively cached (`load_error`) and surfaces as
    /// `error.FontUnavailable` (or the underlying invalid-font error); one
    /// retry is attempted on the next call, so a file that reappears clears
    /// the cache. `load_retried` records that the single retry has been spent,
    /// and is set only once that retry itself fails persistently: an
    /// `error.OutOfMemory` during either attempt never consumes the retry.
    fn ensureEntryLoaded(self: *Raster, entry: *FaceEntry) !void {
        if (entry.loaded) return;
        const retrying = entry.load_error;
        if (retrying and entry.load_retried) return error.FontUnavailable;
        self.loadEntry(entry) catch |err| {
            if (isPersistentLoadFailure(err)) {
                entry.load_error = true;
                // The retry only counts as spent when it actually ran and
                // failed; an OOM leaves `load_retried` false so the next call
                // can try the source again.
                entry.load_retried = retrying;
            }
            return err;
        };
        entry.load_error = false;
        entry.load_retried = false;
    }

    /// OOM is transient: it must never be cached as a permanent font failure,
    /// so the next call retries. Every other load failure (missing file,
    /// unreadable path, invalid font data) is negative-cached. Mirrors
    /// `shape_hb.Backend.isPersistentLoadFailure`.
    fn isPersistentLoadFailure(err: anyerror) bool {
        return err != error.OutOfMemory;
    }

    fn loadEntry(self: *Raster, entry: *FaceEntry) !void {
        const source = switch (entry.source) {
            // Eager sources are loaded by `makeEntry`.
            .bytes => return,
            .path => |p| p,
        };
        const bytes = readSourceFile(self.allocator, source.path) catch |err| {
            return if (err == error.OutOfMemory) error.OutOfMemory else error.FontUnavailable;
        };
        entry.bytes = bytes;
        self.populate(entry, source.index) catch |err| {
            entry.bytes = null;
            self.allocator.free(bytes);
            return err;
        };
    }
};

/// Round `font_size` to the nearest whole pixel and clamp to
/// `[1, maxInt(u16)]`; NaN maps to the minimum. FreeType's
/// `FT_Set_Pixel_Sizes` rejects zero, so the floor is load-bearing.
pub fn pixelSize(font_size: f32) u16 {
    if (std.math.isNan(font_size)) return 1;
    const rounded = @round(font_size);
    if (!(rounded >= 1.0)) return 1; // also covers -inf
    const max: f32 = @floatFromInt(std.math.maxInt(u16));
    if (rounded >= max) return std.math.maxInt(u16);
    return @intFromFloat(rounded);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

const testing = std.testing;

fn readTestFont(allocator: std.mem.Allocator) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(
        std.testing.io,
        "tests/fonts/Inter-Regular.ttf",
        allocator,
        .limited(1 << 24),
    );
}

/// Installed color-font candidates (same list as the `raster_ft` and
/// `swash_cache` color tests). Tests skip when none is present so hosts
/// without a system color emoji font stay green.
const system_color_font_paths = [_][]const u8{
    "/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf",
    "/usr/share/fonts/noto/NotoColorEmoji.ttf",
    "/usr/share/fonts/google-noto-emoji/NotoColorEmoji.ttf",
    "/usr/share/fonts/emoji/NotoColorEmoji.ttf",
};

/// Path of the first installed color font, or `error.SkipZigTest` when none
/// exists. Non-missing access failures propagate.
fn systemColorFontPath() ![]const u8 {
    for (system_color_font_paths) |path| {
        std.Io.Dir.cwd().access(std.testing.io, path, .{}) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => return err,
        };
        return path;
    }
    return error.SkipZigTest;
}

fn countNonZero(bytes: []const u8) usize {
    var n: usize = 0;
    for (bytes) |b| {
        if (b != 0) n += 1;
    }
    return n;
}

/// Glyph id for `codepoint` from a throwaway FreeType face over `bytes`
/// (the production path also uses FreeType's charmap via HarfBuzz, so the ids
/// agree for this font).
fn glyphId(bytes: []const u8, codepoint: u32) !u16 {
    var lib = try raster_ft.Library.init();
    defer lib.deinit();
    var face = try raster_ft.Face.initMemory(&lib, bytes, 0);
    defer face.deinit();
    const id = face.charIndex(codepoint);
    if (id == 0) return error.TestUnexpectedResult;
    return @intCast(id);
}

test "rasterize 'A' at 16px and 32px; unknown font id is a miss" {
    const allocator = testing.allocator;
    const bytes = try readTestFont(allocator);
    defer allocator.free(bytes);

    var raster = try Raster.init(allocator);
    defer raster.deinit();
    try raster.addFont(7, bytes, 0);
    const glyph = try glyphId(bytes, 'A');

    const small = (try raster.rasterize(7, glyph, 16.0, 400, 0.0, 0.0, .{})).?;
    try testing.expectEqual(raster_ft.FT_PIXEL_MODE_GRAY, small.pixel_mode);
    try testing.expect(small.width > 0);
    try testing.expect(small.height > 0);
    try testing.expect(small.advance_x > 0);
    try testing.expect(countNonZero(small.bitmap) > 0);
    // Capture scalar copies: the bitmap borrows the slot and the next call
    // invalidates it.
    const small_w = small.width;
    const small_h = small.height;
    const small_cov = countNonZero(small.bitmap);
    const small_advance = small.advance_x;

    const large = (try raster.rasterize(7, glyph, 32.0, 400, 0.0, 0.0, .{})).?;
    try testing.expect(large.width > small_w);
    try testing.expect(large.height > small_h);
    try testing.expect(countNonZero(large.bitmap) > small_cov);
    try testing.expect(large.advance_x > small_advance);

    // Unknown font id: explicit miss, not an error.
    try testing.expect(try raster.rasterize(99, glyph, 16.0, 400, 0.0, 0.0, .{}) == null);

    // DISABLE_HINTING goes through the same load path and stays gray.
    const unhinted = (try raster.rasterize(
        7,
        glyph,
        32.0,
        400,
        0.0,
        0.0,
        glyph_cache.CacheKeyFlags.DISABLE_HINTING,
    )).?;
    try testing.expectEqual(raster_ft.FT_PIXEL_MODE_GRAY, unhinted.pixel_mode);
    try testing.expect(unhinted.width > 0 and unhinted.height > 0);
}

/// Variable-font fixture reader; `error.SkipZigTest` only when it is absent
/// (same policy as `raster_ft.readTestFont`).
fn readInterVariable(allocator: std.mem.Allocator) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(
        std.testing.io,
        "tests/fonts/InterVariable.ttf",
        allocator,
        .limited(1 << 24),
    ) catch |err| switch (err) {
        error.FileNotFound => return error.SkipZigTest,
        else => return err,
    };
}

test "rasterize forwards weight to variable faces" {
    const allocator = testing.allocator;
    const bytes = try readInterVariable(allocator);
    defer allocator.free(bytes);

    var raster = try Raster.init(allocator);
    defer raster.deinit();
    try raster.addFont(8, bytes, 0);

    // Glyph ids come from a throwaway face over the same bytes.
    const glyph = try glyphId(bytes, 'A');

    const regular = (try raster.rasterize(8, glyph, 32.0, 400, 0.0, 0.0, .{})).?;
    const regular_coverage = countNonZero(regular.bitmap);
    const regular_advance = regular.advance_x;

    // The previous bitmap borrows the face slot; only the scalars above are
    // used after this call.
    const black = (try raster.rasterize(8, glyph, 32.0, 900, 0.0, 0.0, .{})).?;
    const black_coverage = countNonZero(black.bitmap);
    const black_advance = black.advance_x;

    try testing.expect(regular_coverage > 0);
    try testing.expect(black_coverage > 0);
    // The key's weight must reach FreeType: the heavier instance differs.
    try testing.expect(regular_coverage != black_coverage or regular_advance != black_advance);

    // Static faces ignore the weight and still render.
    const static_bytes = try readTestFont(allocator);
    defer allocator.free(static_bytes);
    try raster.addFont(9, static_bytes, 0);
    const static_rendered = (try raster.rasterize(
        9,
        try glyphId(static_bytes, 'A'),
        32.0,
        900,
        0.0,
        0.0,
        .{},
    )) orelse return error.TestUnexpectedResult;
    try testing.expect(countNonZero(static_rendered.bitmap) > 0);
}

test "rasterize applies fractional subpixel offsets" {
    const allocator = testing.allocator;
    const bytes = try readTestFont(allocator);
    defer allocator.free(bytes);

    var raster = try Raster.init(allocator);
    defer raster.deinit();
    try raster.addFont(7, bytes, 0);
    const glyph = try glyphId(bytes, 'A');

    const base = (try raster.rasterize(7, glyph, 24.0, 400, 0.0, 0.0, .{})).?;
    const base_w = base.width;
    const base_h = base.height;
    const base_copy = try allocator.dupe(u8, base.bitmap);
    defer allocator.free(base_copy);

    // A half-pixel horizontal shift must change the coverage bitmap.
    const shifted = (try raster.rasterize(7, glyph, 24.0, 400, 0.5, 0.0, .{})).?;
    try testing.expect(shifted.width > 0 and shifted.height > 0);
    const same_dims = shifted.width == base_w and
        shifted.height == base_h and
        shifted.bitmap.len == base_copy.len;
    const identical = same_dims and std.mem.eql(u8, base_copy, shifted.bitmap);
    try testing.expect(!identical);

    // Back to zero offset: the per-call face transform must not persist, so
    // the original pixels are reproduced exactly.
    const reset = (try raster.rasterize(7, glyph, 24.0, 400, 0.0, 0.0, .{})).?;
    try testing.expectEqual(base_w, reset.width);
    try testing.expectEqual(base_h, reset.height);
    try testing.expectEqualSlices(u8, base_copy, reset.bitmap);
}

test "rasterize applies fake italic skew and fractional sizes" {
    const allocator = testing.allocator;
    const bytes = try readTestFont(allocator);
    defer allocator.free(bytes);

    var raster = try Raster.init(allocator);
    defer raster.deinit();
    try raster.addFont(7, bytes, 0);
    const glyph = try glyphId(bytes, 'A');

    const upright = (try raster.rasterize(7, glyph, 24.0, 400, 0.0, 0.0, .{})).?;
    const upright_w = upright.width;
    const upright_copy = try allocator.dupe(u8, upright.bitmap);
    defer allocator.free(upright_copy);

    // FAKE_ITALIC must reach FreeType as the 14-degree skew.
    const italic = (try raster.rasterize(
        7,
        glyph,
        24.0,
        400,
        0.0,
        0.0,
        .{ .bits = glyph_cache.CacheKeyFlags.FAKE_ITALIC.bits },
    )).?;
    try testing.expect(italic.width > 0 and italic.height > 0);
    const identical = italic.width == upright_w and std.mem.eql(u8, upright_copy, italic.bitmap);
    try testing.expect(!identical);

    // Fractional sizes render at their exact size instead of being rounded
    // to whole pixels (`setCharSize` uses FT_Set_Char_Size at 72 dpi).
    const frac = (try raster.rasterize(7, glyph, 24.5, 400, 0.0, 0.0, .{})).?;
    try testing.expect(frac.width > 0 and frac.height > 0);
}

test "addFont replaces an id and addFromFontSystem validates first" {
    const allocator = testing.allocator;
    const bytes = try readTestFont(allocator);
    defer allocator.free(bytes);

    var raster = try Raster.init(allocator);
    defer raster.deinit();

    // Re-registration replaces the old entry (same face, new copy).
    try raster.addFont(3, bytes, 0);
    try raster.addFont(3, bytes, 0);
    try testing.expectEqual(@as(usize, 1), raster.faces.items.len);

    var fs = try font_system.FontSystem.init(allocator);
    defer fs.deinit();
    try fs.addFontData(3, bytes, 0, false, null);

    try raster.addFromFontSystem(&fs, &.{3});
    const glyph = raster.getFace(3).?.charIndex('A');
    const rendered = (try raster.rasterize(3, @intCast(glyph), 12.0, 400, 0.0, 0.0, .{})) orelse
        return error.TestUnexpectedResult;
    try testing.expect(rendered.width > 0 and rendered.height > 0);

    // An unregistered id is rejected before any registration happens.
    try testing.expectError(
        error.FontNotRegistered,
        raster.addFromFontSystem(&fs, &.{ 3, 12345 }),
    );
    try testing.expect(raster.getFace(12345) == null);
}

test "addFontSource is lazy and rasterizes after first use" {
    const allocator = testing.allocator;
    const bytes = try readTestFont(allocator);
    defer allocator.free(bytes);
    const glyph = try glyphId(bytes, 'A');

    var raster = try Raster.init(allocator);
    defer raster.deinit();
    try raster.addFontSource(7, "tests/fonts/Inter-Regular.ttf", 0);

    // Registration must not read the file or build a face.
    try testing.expectEqual(@as(usize, 0), raster.loadedCount());
    try testing.expectEqual(@as(usize, 1), raster.faces.items.len);

    const rendered = (try raster.rasterize(7, glyph, 16.0, 400, 0.0, 0.0, .{})) orelse
        return error.TestUnexpectedResult;
    try testing.expect(rendered.width > 0 and rendered.height > 0);
    try testing.expect(countNonZero(rendered.bitmap) > 0);
    try testing.expectEqual(@as(usize, 1), raster.loadedCount());

    // Second use reuses the loaded face.
    const again = (try raster.rasterize(7, glyph, 32.0, 400, 0.0, 0.0, .{})) orelse
        return error.TestUnexpectedResult;
    try testing.expect(again.width > rendered.width);
    try testing.expectEqual(@as(usize, 1), raster.loadedCount());
}

test "addFontSource missing path is a null miss, retried once, no poisoning" {
    const allocator = testing.allocator;
    var raster = try Raster.init(allocator);
    defer raster.deinit();
    try raster.addFontSource(9, "tests/fonts/cozmic-does-not-exist.ttf", 0);
    try testing.expectEqual(@as(usize, 0), raster.loadedCount());

    // First touch: a null miss, not an error or panic; the negative cache is
    // armed with the single retry still pending.
    try testing.expect(try raster.rasterize(9, 5, 16.0, 400, 0.0, 0.0, .{}) == null);
    try testing.expect(raster.faces.items[0].load_error);
    try testing.expect(!raster.faces.items[0].load_retried);
    try testing.expectEqual(@as(usize, 0), raster.loadedCount());

    // Second touch consumes the retry and stays a null miss.
    try testing.expect(try raster.rasterize(9, 5, 16.0, 400, 0.0, 0.0, .{}) == null);
    try testing.expect(raster.faces.items[0].load_error);
    try testing.expect(raster.faces.items[0].load_retried);

    // Later touches are answered from the negative cache, including getFace.
    try testing.expect(try raster.rasterize(9, 5, 16.0, 400, 0.0, 0.0, .{}) == null);
    try testing.expect(raster.getFace(9) == null);
    try testing.expectEqual(@as(usize, 0), raster.loadedCount());

    // A different id is unaffected by the poisoned entry.
    const bytes = try readTestFont(allocator);
    defer allocator.free(bytes);
    try raster.addFont(10, bytes, 0);
    const rendered = (try raster.rasterize(10, try glyphId(bytes, 'A'), 16.0, 400, 0.0, 0.0, .{})) orelse
        return error.TestUnexpectedResult;
    try testing.expect(rendered.width > 0 and rendered.height > 0);
    try testing.expectEqual(@as(usize, 1), raster.loadedCount());
    try testing.expect(raster.faces.items[0].load_error);
}

test "lazy load failure retries once and recovers when the file reappears" {
    const allocator = testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    // Relative to the test cwd (the package root), like the other lazy-read
    // tests; `readSourceFile` opens it through `Dir.cwd()`.
    const rel = try std.fs.path.join(
        allocator,
        &.{ ".zig-cache", "tmp", &tmp.sub_path, "reappears.ttf" },
    );
    defer allocator.free(rel);

    const bytes = try readTestFont(allocator);
    defer allocator.free(bytes);
    const glyph = try glyphId(bytes, 'A');

    var raster = try Raster.init(allocator);
    defer raster.deinit();
    try raster.addFontSource(11, rel, 0);

    // The file is missing: a null miss that arms the negative cache. No
    // `getFace` call here: it would consume the one retry before the file
    // appears.
    try testing.expect(try raster.rasterize(11, glyph, 16.0, 400, 0.0, 0.0, .{}) == null);
    try testing.expect(raster.faces.items[0].load_error);
    try testing.expect(!raster.faces.items[0].load_retried);
    try testing.expectEqual(@as(usize, 0), raster.loadedCount());

    // The font file appears after the first (negative-cached) failure.
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "reappears.ttf", .data = bytes });

    // The next touch retries once and recovers, clearing both flags.
    const rendered = (try raster.rasterize(11, glyph, 16.0, 400, 0.0, 0.0, .{})) orelse
        return error.TestUnexpectedResult;
    try testing.expect(rendered.width > 0 and rendered.height > 0);
    try testing.expectEqual(@as(usize, 1), raster.loadedCount());
    const entry = &raster.faces.items[0];
    try testing.expect(!entry.load_error);
    try testing.expect(!entry.load_retried);

    // Subsequent queries reuse the loaded face without further reads.
    const again = (try raster.rasterize(11, glyph, 32.0, 400, 0.0, 0.0, .{})) orelse
        return error.TestUnexpectedResult;
    try testing.expect(again.width > rendered.width);
    try testing.expectEqual(@as(usize, 1), raster.loadedCount());
}

test "lazy load OOM is transient and not cached as a permanent failure" {
    const allocator = testing.allocator;
    const bytes = try readTestFont(allocator);
    defer allocator.free(bytes);
    const glyph = try glyphId(bytes, 'A');

    // The raster (and therefore the lazy file read) allocates through the
    // failing allocator; `fail_index` is armed after registration so the next
    // allocation lands inside the read.
    var failing = std.testing.FailingAllocator.init(allocator, .{});
    var raster = try Raster.init(failing.allocator());
    defer raster.deinit();
    try raster.addFontSource(7, "tests/fonts/Inter-Regular.ttf", 0);

    failing.fail_index = failing.alloc_index;
    try testing.expectError(
        error.OutOfMemory,
        raster.rasterize(7, glyph, 16.0, 400, 0.0, 0.0, .{}),
    );
    const entry = &raster.faces.items[0];
    // OOM must not poison the entry: no negative cache, retry still pending,
    // and the miss is reported as an error instead of a silent null.
    try testing.expect(!entry.load_error);
    try testing.expect(!entry.load_retried);
    try testing.expect(!entry.loaded);
    try testing.expectEqual(@as(usize, 0), raster.loadedCount());

    // Once allocations succeed again, the very next call retries and loads.
    failing.fail_index = std.math.maxInt(usize);
    const rendered = (try raster.rasterize(7, glyph, 16.0, 400, 0.0, 0.0, .{})) orelse
        return error.TestUnexpectedResult;
    try testing.expect(rendered.width > 0 and rendered.height > 0);
    try testing.expectEqual(@as(usize, 1), raster.loadedCount());
    try testing.expect(!raster.faces.items[0].load_error);
    try testing.expect(!raster.faces.items[0].load_retried);
}

test "OOM during the lazy-load retry does not consume the retry" {
    const allocator = testing.allocator;
    const bytes = try readTestFont(allocator);
    defer allocator.free(bytes);
    const glyph = try glyphId(bytes, 'A');

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const rel = try std.fs.path.join(
        allocator,
        &.{ ".zig-cache", "tmp", &tmp.sub_path, "retry-oom.ttf" },
    );
    defer allocator.free(rel);

    var failing = std.testing.FailingAllocator.init(allocator, .{});
    var raster = try Raster.init(failing.allocator());
    defer raster.deinit();
    try raster.addFontSource(7, rel, 0);

    // First touch: the file is missing, a persistent failure with the single
    // retry still pending.
    try testing.expect(try raster.rasterize(7, glyph, 16.0, 400, 0.0, 0.0, .{}) == null);
    const entry = &raster.faces.items[0];
    try testing.expect(entry.load_error);
    try testing.expect(!entry.load_retried);
    try testing.expect(!entry.loaded);

    // The file appears, but the retry's file read runs out of memory. OOM is
    // transient: it must not spend the retry nor leave the entry poisoned.
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "retry-oom.ttf", .data = bytes });
    failing.fail_index = failing.alloc_index;
    try testing.expectError(
        error.OutOfMemory,
        raster.rasterize(7, glyph, 16.0, 400, 0.0, 0.0, .{}),
    );
    try testing.expect(entry.load_error);
    try testing.expect(!entry.load_retried);
    try testing.expect(!entry.loaded);

    // With allocations working again, the very next call still has its retry
    // and loads the face.
    failing.fail_index = std.math.maxInt(usize);
    const rendered = (try raster.rasterize(7, glyph, 16.0, 400, 0.0, 0.0, .{})) orelse
        return error.TestUnexpectedResult;
    try testing.expect(rendered.width > 0 and rendered.height > 0);
    try testing.expectEqual(@as(usize, 1), raster.loadedCount());
    try testing.expect(!entry.load_error);
    try testing.expect(!entry.load_retried);
}

test "canUse classifies source failures without gating the retry" {
    const allocator = testing.allocator;
    var raster = try Raster.init(allocator);
    defer raster.deinit();

    // Unknown id: `rasterize` reports an ordinary null miss, so the id must
    // stay "usable" for miss classification.
    try testing.expect(raster.canUse(4242));

    // Registered but never touched: a load attempt can still run.
    try raster.addFontSource(9, "tests/fonts/cozmic-does-not-exist.ttf", 0);
    try testing.expect(raster.canUse(9));

    // First failure: negative cache armed, retry still pending.
    try testing.expect(try raster.rasterize(9, 5, 16.0, 400, 0.0, 0.0, .{}) == null);
    try testing.expect(!raster.canUse(9));
    try testing.expect(raster.faces.items[0].load_error);
    try testing.expect(!raster.faces.items[0].load_retried);

    // `canUse` is a classification, not a gate: `rasterize` still runs and
    // consumes the retry.
    try testing.expect(try raster.rasterize(9, 5, 16.0, 400, 0.0, 0.0, .{}) == null);
    try testing.expect(!raster.canUse(9));
    try testing.expect(raster.faces.items[0].load_retried);

    // Eagerly registered ids stay usable.
    const bytes = try readTestFont(allocator);
    defer allocator.free(bytes);
    try raster.addFont(10, bytes, 0);
    try testing.expect(raster.canUse(10));
}

test "getFace hides retryable OOM as null while ensureFace reports it" {
    const allocator = testing.allocator;
    const bytes = try readTestFont(allocator);
    defer allocator.free(bytes);

    var failing = std.testing.FailingAllocator.init(allocator, .{});
    var raster = try Raster.init(failing.allocator());
    defer raster.deinit();
    try raster.addFontSource(7, "tests/fonts/Inter-Regular.ttf", 0);

    // The infallible lookup cannot distinguish the transient allocation
    // failure from an unknown id: both are `null`.
    failing.fail_index = failing.alloc_index;
    try testing.expect(raster.getFace(7) == null);
    const entry = &raster.faces.items[0];
    try testing.expect(!entry.load_error);
    try testing.expect(!entry.load_retried);
    try testing.expect(!entry.loaded);

    // The fallible lookup reports the real, retryable error instead.
    failing.fail_index = std.math.maxInt(usize);
    const face = (try raster.ensureFace(7)) orelse return error.TestUnexpectedResult;
    try testing.expect(face.charIndex('A') != 0);
    try testing.expectEqual(@as(usize, 1), raster.loadedCount());
}

test "independent rasters load lazy sources concurrently" {
    const allocator = testing.allocator;
    const bytes = try readTestFont(allocator);
    defer allocator.free(bytes);
    const glyph = try glyphId(bytes, 'A');

    const Loader = struct {
        fn run(path: []const u8, glyph_id: u16, ok: *std.atomic.Value(bool)) void {
            var raster = Raster.init(std.heap.page_allocator) catch {
                ok.store(false, .release);
                return;
            };
            defer raster.deinit();
            raster.addFontSource(1, path, 0) catch {
                ok.store(false, .release);
                return;
            };
            const rendered = raster.rasterize(1, glyph_id, 16.0, 400, 0.0, 0.0, .{}) catch {
                ok.store(false, .release);
                return;
            };
            const r = rendered orelse {
                ok.store(false, .release);
                return;
            };
            ok.store(r.width > 0 and r.height > 0 and countNonZero(r.bitmap) > 0, .release);
        }
    };

    var results: [4]std.atomic.Value(bool) = undefined;
    var threads: [4]std.Thread = undefined;
    var spawned: usize = 0;
    errdefer for (threads[0..spawned]) |thread| thread.join();
    for (&results) |*result| {
        result.* = std.atomic.Value(bool).init(false);
        threads[spawned] = try std.Thread.spawn(
            .{},
            Loader.run,
            .{ "tests/fonts/Inter-Regular.ttf", glyph, result },
        );
        spawned += 1;
    }
    for (threads[0..spawned]) |thread| thread.join();
    for (results) |result| try testing.expect(result.load(.acquire));
}

test "load failure classification: only OOM is transient" {
    try testing.expect(!Raster.isPersistentLoadFailure(error.OutOfMemory));
    // A FreeType-side OOM (`FT_Err_Out_Of_Memory`) arrives through
    // `raster_ft.Error` as the very same `error.OutOfMemory` value, so the
    // classification covers it without a separate branch. This assignment
    // also pins `raster_ft.Error` to include it.
    const ft_oom: raster_ft.Error = error.OutOfMemory;
    try testing.expect(!Raster.isPersistentLoadFailure(ft_oom));

    // Persistent failures: real font/data/handle errors stay negative-cached.
    try testing.expect(Raster.isPersistentLoadFailure(error.FileNotFound));
    try testing.expect(Raster.isPersistentLoadFailure(error.AccessDenied));
    try testing.expect(Raster.isPersistentLoadFailure(error.FontUnavailable));
    try testing.expect(Raster.isPersistentLoadFailure(error.FreeTypeFailure));
    try testing.expect(Raster.isPersistentLoadFailure(error.LibraryUnavailable));
    try testing.expect(Raster.isPersistentLoadFailure(error.InvalidFileFormat));
    try testing.expect(Raster.isPersistentLoadFailure(error.UnknownFileFormat));
    try testing.expect(Raster.isPersistentLoadFailure(error.InvalidArgument));
    try testing.expect(Raster.isPersistentLoadFailure(error.InvalidGlyphIndex));
    try testing.expect(Raster.isPersistentLoadFailure(error.InvalidPixelSize));
}

test "replacing a loaded lazy entry with eager bytes frees the old face" {
    const allocator = testing.allocator;
    const bytes = try readTestFont(allocator);
    defer allocator.free(bytes);
    const glyph = try glyphId(bytes, 'A');

    var raster = try Raster.init(allocator);
    defer raster.deinit();
    try raster.addFontSource(4, "tests/fonts/Inter-Regular.ttf", 0);
    const first = (try raster.rasterize(4, glyph, 16.0, 400, 0.0, 0.0, .{})) orelse
        return error.TestUnexpectedResult;
    const first_w = first.width;
    try testing.expect(first_w > 0);
    try testing.expectEqual(@as(usize, 1), raster.loadedCount());
    try testing.expect(raster.faces.items[0].bytes != null);

    // Same id, eager bytes: `insertEntry` destroys the loaded lazy entry
    // (face, lazy byte copy, path) before installing the eager copy. Running
    // under `std.testing.allocator` catches a leak or use-after-free here.
    try raster.addFont(4, bytes, 0);
    try testing.expectEqual(@as(usize, 1), raster.faces.items.len);
    try testing.expectEqual(@as(usize, 1), raster.loadedCount());
    switch (raster.faces.items[0].source) {
        .bytes => {},
        .path => return error.TestUnexpectedResult,
    }

    const second = (try raster.rasterize(4, glyph, 32.0, 400, 0.0, 0.0, .{})) orelse
        return error.TestUnexpectedResult;
    try testing.expect(second.width > first_w);
    try testing.expectEqual(@as(usize, 1), raster.loadedCount());
}

test "addFromFontSystem skips known-failed lazy sources" {
    const allocator = testing.allocator;

    var fs = try font_system.FontSystem.init(allocator);
    defer fs.deinit();
    const broken_id: font_system.FontId = 31;
    try fs.addFontSource(
        broken_id,
        "tests/fonts/cozmic-does-not-exist.ttf",
        0,
        false,
        false,
        null,
    );

    // Force the shaper's lazy load to fail: the source stays registered (path
    // still present) but `canUseFontSource` turns false.
    const adapter = fs.shaper() orelse return error.TestUnexpectedResult;
    try testing.expectError(
        error.FontUnavailable,
        adapter.shapeRun(allocator, broken_id, "A", false),
    );
    try testing.expect(!fs.canUseFontSource(broken_id));
    try testing.expect(fs.fontSourcePath(broken_id) != null);

    var raster = try Raster.init(allocator);
    defer raster.deinit();
    // Registered but unusable: skipped, not fatal. The shaper-side failure
    // cannot migrate to the raster, and failing the batch would block healthy
    // ids.
    try raster.addFromFontSystem(&fs, &.{broken_id});
    try testing.expectEqual(@as(usize, 0), raster.faces.items.len);

    // Only an id with neither bytes nor a source path is "not registered".
    try testing.expectError(
        error.FontNotRegistered,
        raster.addFromFontSystem(&fs, &.{broken_id + 1000}),
    );
}

test "addFromFontSystem migrates valid ids around a failed lazy source" {
    const allocator = testing.allocator;
    const bytes = try readTestFont(allocator);
    defer allocator.free(bytes);

    var fs = try font_system.FontSystem.init(allocator);
    defer fs.deinit();

    // Known-failed lazy source: registered (path present) but unusable.
    const broken_id: font_system.FontId = 41;
    try fs.addFontSource(
        broken_id,
        "tests/fonts/cozmic-does-not-exist.ttf",
        0,
        false,
        false,
        null,
    );
    const adapter = fs.shaper() orelse return error.TestUnexpectedResult;
    try testing.expectError(
        error.FontUnavailable,
        adapter.shapeRun(allocator, broken_id, "A", false),
    );
    try testing.expect(!fs.canUseFontSource(broken_id));
    try testing.expect(fs.fontSourcePath(broken_id) != null);

    // Healthy siblings: one eager (bytes) and one lazy (real path).
    const eager_id: font_system.FontId = 42;
    try fs.addFontData(eager_id, bytes, 0, false, null);
    const lazy_id: font_system.FontId = 43;
    try fs.addFontSource(lazy_id, "tests/fonts/Inter-Regular.ttf", 0, false, false, null);

    var raster = try Raster.init(allocator);
    defer raster.deinit();

    // Mixed batch: the broken id is skipped, the other two register.
    try raster.addFromFontSystem(&fs, &.{ broken_id, eager_id, lazy_id });
    try testing.expectEqual(@as(usize, 2), raster.faces.items.len);
    try testing.expect(raster.getFace(broken_id) == null);

    const glyph = try glyphId(bytes, 'A');
    const eager = (try raster.rasterize(eager_id, glyph, 16.0, 400, 0.0, 0.0, .{})) orelse
        return error.TestUnexpectedResult;
    try testing.expect(eager.width > 0 and eager.height > 0);
    const lazy = (try raster.rasterize(lazy_id, glyph, 16.0, 400, 0.0, 0.0, .{})) orelse
        return error.TestUnexpectedResult;
    try testing.expect(lazy.width > 0 and lazy.height > 0);
    try testing.expectEqual(@as(usize, 2), raster.loadedCount());

    // A genuinely unregistered id still fails the batch before registering
    // anything, so the registry is unchanged.
    try testing.expectError(
        error.FontNotRegistered,
        raster.addFromFontSystem(&fs, &.{ 9999, eager_id }),
    );
    try testing.expectEqual(@as(usize, 2), raster.faces.items.len);
}

test "addFromFontSystem migrates lazy sources" {
    const allocator = testing.allocator;
    const bytes = try readTestFont(allocator);
    defer allocator.free(bytes);
    const glyph = try glyphId(bytes, 'A');

    var fs = try font_system.FontSystem.init(allocator);
    defer fs.deinit();
    try fs.addFontSource(21, "tests/fonts/Inter-Regular.ttf", 0, false, false, null);
    try testing.expectEqual(@as(usize, 0), fs.loadedFontCount());

    var raster = try Raster.init(allocator);
    defer raster.deinit();
    try raster.addFromFontSystem(&fs, &.{21});
    try testing.expectEqual(@as(usize, 0), raster.loadedCount());
    try testing.expectEqualStrings(
        "tests/fonts/Inter-Regular.ttf",
        fs.fontSourcePath(21).?,
    );

    const rendered = (try raster.rasterize(21, glyph, 16.0, 400, 0.0, 0.0, .{})) orelse
        return error.TestUnexpectedResult;
    try testing.expect(countNonZero(rendered.bitmap) > 0);
    try testing.expectEqual(@as(usize, 1), raster.loadedCount());
}

test "pixelSize rounds to whole pixels and clamps to at least one" {
    try testing.expectEqual(@as(u16, 1), pixelSize(0.0));
    try testing.expectEqual(@as(u16, 1), pixelSize(0.4));
    try testing.expectEqual(@as(u16, 1), pixelSize(0.5)); // ties round away from zero
    try testing.expectEqual(@as(u16, 16), pixelSize(16.4));
    try testing.expectEqual(@as(u16, 17), pixelSize(16.6));
    try testing.expectEqual(@as(u16, 1), pixelSize(-5.0));
    try testing.expectEqual(@as(u16, 1), pixelSize(std.math.nan(f32)));
    try testing.expectEqual(std.math.maxInt(u16), pixelSize(std.math.inf(f32)));
    try testing.expectEqual(std.math.maxInt(u16), pixelSize(1e9));
}

test "rasterize color glyphs as BGRA (static fixtures stay gray)" {
    const allocator = testing.allocator;
    var raster = try Raster.init(allocator);
    defer raster.deinit();

    // Static fixture regression: the scalable outline path is unchanged.
    const bytes = try readTestFont(allocator);
    defer allocator.free(bytes);
    try raster.addFont(12, bytes, 0);
    const gray = (try raster.rasterize(12, try glyphId(bytes, 'A'), 24.0, 400, 0.0, 0.0, .{})).?;
    try testing.expectEqual(raster_ft.FT_PIXEL_MODE_GRAY, gray.pixel_mode);
    try testing.expect(gray.width > 0 and gray.height > 0);
    try testing.expect(countNonZero(gray.bitmap) > 0);

    // Color face: the resolved emoji glyph must come back as a premultiplied
    // BGRA bitmap (no color font installed => skip).
    const path = try systemColorFontPath();
    try raster.addFontSource(13, path, 0);
    const face = raster.getFace(13) orelse return error.TestUnexpectedResult;
    try testing.expect(face.hasColor());
    const emoji = face.charIndex(0x1F600); // GRINNING FACE
    try testing.expect(emoji != 0);
    const colored = (try raster.rasterize(
        13,
        @intCast(emoji),
        109.0,
        400,
        0.0,
        0.0,
        .{},
    )) orelse return error.TestUnexpectedResult;
    try testing.expectEqual(raster_ft.FT_PIXEL_MODE_BGRA, colored.pixel_mode);
    try testing.expect(colored.width > 0 and colored.height > 0);
    try testing.expect(countNonZero(colored.bitmap) > 0);
}
