//! FreeType 2 backend: font metrics + glyph rasterization (real C library).
//!
//! This is a thin adapter over the vendored `freetype` binding module
//! (`src/freetype/`, the allyourcodebase bindings with `zig translate-c`
//! `c_bindings.zig`, loaded at runtime through `c_bindings_dyn.zig`). That
//! module owns the C ABI surface — `FT_FaceRec`, `FT_GlyphSlotRec`,
//! `FT_Bitmap`, the `FT_*` call signatures — and the `ft.Library` /
//! `ft.Face` wrappers. This file only:
//!
//! - exposes the loader/raster/pixel flags consumers here use as `FT_*`
//!   aliases of the vendored constants,
//! - maps FreeType's ~90 error codes down to the small `Error` set callers of
//!   this module have always seen,
//! - snapshots a rendered glyph slot into `Rendered`,
//! - loads color faces (`FT_HAS_COLOR`) with `FT_LOAD_COLOR` and falls back to
//!   the closest fixed strike for bitmap-only faces that reject char sizes, so
//!   COLR/CPAL and CBDT/sbix glyphs arrive as `FT_PIXEL_MODE_BGRA` bitmaps
//!   instead of failing or rendering empty.
//!
//! Struct layouts and offsets are asserted against the translated bindings by
//! the "ABI layout" test.
//!
//! ## Lifetime
//!
//! - `Library` owns the `FT_Library`. Every `Face` made from it borrows the
//!   library and must not outlive it (FreeType keeps no back-pointer we need,
//!   but the underlying allocator belongs to the library).
//! - `Face.initMemory` does **not** copy the font bytes: `bytes` must stay
//!   alive and at a stable address until `Face.deinit`. `Face.owns_blob` is
//!   `false` accordingly, documented rather than silently assumed.
//! - `Rendered.bitmap` borrows the face's glyph slot. It is invalidated by the
//!   next `loadRender` / `loadRenderFlags` call (and by `Face.deinit`); copy it
//!   if it must outlive the call. `Rendered` needs no `deinit`.
//! - `Face` and `Library` are single-threaded like the underlying objects: use
//!   one per thread, or serialize access externally.

const std = @import("std");
const ft = @import("freetype");

/// Vendored translate-c bindings (same names an `@cImport` would have made).
const c = ft.c;

/// Outline command type (the swash-zeno mirror) lives in `swash_cache.zig`.
/// This is a type-only back-reference: `swash_cache` reaches this file via
/// `font_raster`, and neither struct's *layout* depends on the other, so Zig
/// resolves the cycle (same accepted pattern as shape_run_cache <-> shape).
const swash_cache_mod = @import("swash_cache.zig");

// ---------------------------------------------------------------------------
// Public constants (`FT_LOAD_*`, `FT_RENDER_MODE_*`, `FT_PIXEL_MODE_*`)
// ---------------------------------------------------------------------------

/// `FT_LOAD_DEFAULT`: native hinting + no bitmap format forcing.
pub const FT_LOAD_DEFAULT: c_int = c.FT_LOAD_DEFAULT;
/// `FT_LOAD_NO_HINTING` (combine with `FT_LOAD_NO_AUTOHINT` for unhinted).
pub const FT_LOAD_NO_HINTING: c_int = @intCast(c.FT_LOAD_NO_HINTING);
/// `FT_LOAD_RENDER`: render the glyph into `slot.bitmap` while loading.
pub const FT_LOAD_RENDER: c_int = @intCast(c.FT_LOAD_RENDER);
/// `FT_LOAD_NO_BITMAP`: ignore embedded bitmap strikes, keep outlines.
pub const FT_LOAD_NO_BITMAP: c_int = @intCast(c.FT_LOAD_NO_BITMAP);
/// `FT_LOAD_COLOR`: load color layers (COLR/CPAL) and colored embedded bitmap
/// strikes (CBDT/sbix) as premultiplied BGRA.
pub const FT_LOAD_COLOR: c_int = @intCast(c.FT_LOAD_COLOR);
/// `FT_LOAD_TARGET_NORMAL` (the default rendering target).
pub const FT_LOAD_TARGET_NORMAL: c_int = @intCast(c.FT_LOAD_TARGET_NORMAL);
/// `FT_RENDER_MODE_NORMAL`: anti-aliased 8-bit coverage.
pub const FT_RENDER_MODE_NORMAL: c_int = c.FT_RENDER_MODE_NORMAL;
/// `FT_PIXEL_MODE_MONO`: 1 bit/pixel, MSB first.
pub const FT_PIXEL_MODE_MONO: u8 = @intCast(c.FT_PIXEL_MODE_MONO);
/// `FT_PIXEL_MODE_GRAY`: 8-bit coverage (or LCD bytes, see below).
pub const FT_PIXEL_MODE_GRAY: u8 = @intCast(c.FT_PIXEL_MODE_GRAY);
/// `FT_PIXEL_MODE_GRAY2`: 2-bit embedded AA bitmap.
pub const FT_PIXEL_MODE_GRAY2: u8 = @intCast(c.FT_PIXEL_MODE_GRAY2);
/// `FT_PIXEL_MODE_GRAY4`: 4-bit embedded AA bitmap.
pub const FT_PIXEL_MODE_GRAY4: u8 = @intCast(c.FT_PIXEL_MODE_GRAY4);
/// `FT_PIXEL_MODE_LCD`: 8-bit per subpixel, 3x wider than the glyph.
pub const FT_PIXEL_MODE_LCD: u8 = @intCast(c.FT_PIXEL_MODE_LCD);
/// `FT_PIXEL_MODE_LCD_V`: 8-bit per subpixel, 3x taller than the glyph.
pub const FT_PIXEL_MODE_LCD_V: u8 = @intCast(c.FT_PIXEL_MODE_LCD_V);
/// `FT_PIXEL_MODE_BGRA`: 4x8-bit premultiplied color, blue first.
pub const FT_PIXEL_MODE_BGRA: u8 = @intCast(c.FT_PIXEL_MODE_BGRA);
/// `FT_GLYPH_FORMAT_BITMAP` = `FT_MAKE_TAG('b','i','t','s')`.
pub const FT_GLYPH_FORMAT_BITMAP: u32 = @intCast(c.FT_GLYPH_FORMAT_BITMAP);
/// `FT_KERNING_DEFAULT`: full, grid-fitted kerning.
pub const FT_KERNING_DEFAULT: c_uint = @intCast(c.FT_KERNING_DEFAULT);

// ABI type aliases kept for callers that name these structs directly; the
// layouts and `extern fn` signatures live in the vendored bindings now.
pub const FT_Library = c.FT_Library;
pub const FT_Face = c.FT_Face;
pub const FT_GlyphSlot = c.FT_GlyphSlot;
pub const FT_Generic = c.FT_Generic;
pub const FT_Vector = c.FT_Vector;
pub const FT_BBox = c.FT_BBox;
pub const FT_Glyph_Metrics = c.FT_Glyph_Metrics;
pub const FT_Bitmap = c.FT_Bitmap;
pub const FT_GlyphSlotRec = c.FT_GlyphSlotRec;
pub const FT_FaceRec = c.FT_FaceRec;

// ---------------------------------------------------------------------------
// Error mapping.
// ---------------------------------------------------------------------------

/// Errors surfaced by this module.
pub const Error = error{
    /// The font data was recognized as a known format but is structurally
    /// broken (`FT_Err_Invalid_File_Format`).
    InvalidFileFormat,
    /// No FreeType driver recognized the data (`FT_Err_Unknown_File_Format`).
    UnknownFileFormat,
    /// Bad face index, out-of-range glyph, or other invalid argument
    /// (`FT_Err_Invalid_Argument`).
    InvalidArgument,
    /// `FT_Err_Invalid_Glyph_Index` (returned by some drivers instead of
    /// `InvalidArgument` for out-of-range glyph ids).
    InvalidGlyphIndex,
    /// A zero width/height reached `FT_Set_Pixel_Sizes`
    /// (`FT_Err_Invalid_Pixel_Size`); rejected before calling FreeType.
    InvalidPixelSize,
    /// FreeType ran out of memory (`FT_Err_Out_Of_Memory`). Transient: the
    /// operation may succeed on retry once memory is available again, so
    /// callers must not cache it as a permanent failure (unlike the other
    /// `FreeTypeFailure` cases).
    OutOfMemory,
    /// The system FreeType shared library could not be loaded at runtime
    /// (no candidate `libfreetype.so*`/`libfreetype*.dylib`/`freetype*.dll`
    /// was found) or it lacks one of the entry points this port uses.
    /// Raised by `Library.init` before `FT_Init_FreeType` runs.
    LibraryUnavailable,
    /// A null/deinitialized handle, or an unmapped non-zero FreeType code.
    FreeTypeFailure,
};

/// Map a raw `FT_Error` code from a `ft.c` call.
fn ftError(code: c_int) Error {
    return switch (code) {
        c.FT_Err_Unknown_File_Format => error.UnknownFileFormat,
        c.FT_Err_Invalid_File_Format => error.InvalidFileFormat,
        c.FT_Err_Invalid_Argument => error.InvalidArgument,
        c.FT_Err_Invalid_Glyph_Index => error.InvalidGlyphIndex,
        c.FT_Err_Invalid_Pixel_Size => error.InvalidPixelSize,
        c.FT_Err_Out_Of_Memory => error.OutOfMemory,
        else => error.FreeTypeFailure,
    };
}

/// Map an error from the vendored `ft.Library` / `ft.Face` wrappers (which
/// surface the full FreeType error set) onto this module's small set.
fn wrapperError(err: ft.Error) Error {
    return switch (err) {
        error.UnknownFileFormat => error.UnknownFileFormat,
        error.InvalidFileFormat => error.InvalidFileFormat,
        error.InvalidArgument => error.InvalidArgument,
        error.InvalidGlyphIndex => error.InvalidGlyphIndex,
        error.InvalidPixelSize => error.InvalidPixelSize,
        error.OutOfMemory => error.OutOfMemory,
        else => error.FreeTypeFailure,
    };
}

/// OpenType axis tag `wght` (`FT_MAKE_TAG('w','g','h','t')`, same as
/// HarfBuzz `HB_TAG('w','g','h','t')` = 0x77676874) as stored in
/// `FT_Var_Axis.tag` (`FT_ULong`).
const WGHT_AXIS_TAG: c.FT_ULong = 0x77676874;

// ---------------------------------------------------------------------------
// Library.
// ---------------------------------------------------------------------------

/// An initialized `FT_Library`.
pub const Library = struct {
    /// Vendored wrapper around the raw `FT_Library`; `null` before `init` and
    /// after `deinit`.
    handle: ?ft.Library,

    /// `FT_Init_FreeType`. Loads the system FreeType shared library first
    /// (`error.LibraryUnavailable` when that fails: missing library or
    /// missing entry point); the load is cached process-wide.
    pub fn init() Error!Library {
        ft.dyn.ensureLoaded() catch return error.LibraryUnavailable;
        const handle = ft.Library.init() catch |err| return wrapperError(err);
        return .{ .handle = handle };
    }

    /// `FT_Done_FreeType`. Safe to call twice; the second call is a no-op.
    ///
    /// The return code is intentionally dropped: FreeType only fails this for
    /// invalid/unbalanced handles, which is a caller bug with no recovery
    /// path. The wrapper is cleared *before* the call so a double `deinit`
    /// cannot double-free.
    pub fn deinit(self: *Library) void {
        if (self.handle) |handle| {
            self.handle = null;
            handle.deinit();
        }
    }

    pub const Version = struct {
        major: c_int,
        minor: c_int,
        patch: c_int,
    };

    /// `FT_Library_Version`; `null` when the library is not live.
    pub fn version(self: *const Library) ?Version {
        const handle = self.handle orelse return null;
        const v = handle.version();
        if (v.major == 0 and v.minor == 0 and v.patch == 0) return null;
        return .{ .major = v.major, .minor = v.minor, .patch = v.patch };
    }
};

// ---------------------------------------------------------------------------
// Face.
// ---------------------------------------------------------------------------

/// A loaded `FT_Face` (one face of a font file).
pub const Face = struct {
    /// Library that created this face. Borrowed: it must outlive the face.
    library: *const Library,
    /// Vendored wrapper around the raw `FT_Face`.
    handle: ft.Face,
    /// Always `false` today: `initMemory` borrows the caller's bytes instead
    /// of copying them. Present so callers can assert the ownership contract
    /// instead of assuming it (a future file-backed loader would set `true`).
    owns_blob: bool,
    /// Last weight applied through `setVariationWght`; the face keeps its
    /// design coordinates between loads, so equal requests are skipped.
    applied_wght: ?u16 = null,

    /// Raw C `FT_Face`, borrowed. For callers that need to hand the handle to
    /// other C libraries (e.g. HarfBuzz); prefer the methods below.
    pub fn raw(self: *const Face) c.FT_Face {
        return self.handle.handle;
    }

    /// `FT_New_Memory_Face` over caller-owned bytes.
    ///
    /// The bytes are **not** copied (FreeType keeps a pointer into them), so
    /// they must stay alive and unmoved until `deinit`. `index` selects a
    /// face in a collection; out-of-range indices fail with
    /// `error.InvalidArgument`.
    pub fn initMemory(library: *const Library, bytes: []const u8, index: i32) Error!Face {
        const lib = library.handle orelse return error.FreeTypeFailure;
        if (bytes.len == 0) return error.InvalidFileFormat;
        if (bytes.len > std.math.maxInt(c_long)) return error.InvalidArgument;
        const handle = lib.initMemoryFace(bytes, index) catch |err| return switch (err) {
            // FreeType >= 2.14 surfaces the type-detection failure for
            // unrecognized data as `Invalid_Stream_Operation` (0x55) instead
            // of normalizing it to `Unknown_File_Format`; the public contract
            // of this module is the latter.
            error.InvalidStreamOperation => error.UnknownFileFormat,
            else => wrapperError(err),
        };
        return .{
            .library = library,
            .handle = handle,
            .owns_blob = false,
        };
    }

    /// `FT_Done_Face`. Not idempotent (FreeType does not allow it); call once.
    pub fn deinit(self: *Face) void {
        self.handle.deinit();
        self.* = undefined;
    }

    // -- Immutable metrics -------------------------------------------------

    /// `units_per_EM` (design units per em).
    pub fn upem(self: *const Face) u16 {
        return @intCast(self.handle.handle.*.units_per_EM);
    }

    /// Horizontal ascender in design units, positive for the usual case.
    pub fn ascent(self: *const Face) i16 {
        return @intCast(self.handle.handle.*.ascender);
    }

    /// Horizontal descender in design units: negative for the usual case
    /// (FreeType uses a y-down coordinate system).
    pub fn descent(self: *const Face) i16 {
        return @intCast(self.handle.handle.*.descender);
    }

    /// Recommended baseline-to-baseline distance in design units.
    pub fn height(self: *const Face) i16 {
        return @intCast(self.handle.handle.*.height);
    }

    /// Underline top from the baseline in design units (usually negative).
    pub fn underlinePosition(self: *const Face) i16 {
        return @intCast(self.handle.handle.*.underline_position);
    }

    /// Underline stroke thickness in design units.
    pub fn underlineThickness(self: *const Face) i16 {
        return @intCast(self.handle.handle.*.underline_thickness);
    }

    /// Number of glyphs in the face (0 for a malformed/negative count).
    pub fn glyphCount(self: *const Face) u32 {
        return @intCast(@max(self.handle.handle.*.num_glyphs, 0));
    }

    /// Family name as NUL-terminated C string, if the face has one.
    pub fn familyName(self: *const Face) ?[]const u8 {
        const name = self.handle.handle.*.family_name;
        if (name == null) return null;
        return std.mem.sliceTo(name, 0);
    }

    /// Style (subfamily) name, if the face has one.
    pub fn styleName(self: *const Face) ?[]const u8 {
        const name = self.handle.handle.*.style_name;
        if (name == null) return null;
        return std.mem.sliceTo(name, 0);
    }

    /// `FT_Get_Char_Index`: glyph id for a Unicode codepoint, 0 when absent.
    pub fn charIndex(self: *const Face, codepoint: u32) u32 {
        return @intCast(c.FT_Get_Char_Index(self.handle.handle, codepoint));
    }

    /// `FT_HAS_COLOR`: the face has color glyph tables (`COLR`/`CPAL`,
    /// `CBDT`, `sbix`, ...). Color-bearing faces load as BGRA bitmaps when
    /// `loadRender*` ORs in `FT_LOAD_COLOR`.
    pub fn hasColor(self: *const Face) bool {
        return self.handle.hasColor();
    }

    /// `FT_HAS_FIXED_SIZES`: the face has embedded bitmap strikes listed in
    /// `available_sizes` (non-scalable bitmap-only faces and faces with
    /// bitmap strikes).
    pub fn hasFixedSizes(self: *const Face) bool {
        return self.handle.hasFixedSizes();
    }

    // -- Sizing / raster ---------------------------------------------------

    /// `FT_Set_Pixel_Sizes`. Rejects zero dimensions up front with
    /// `error.InvalidPixelSize`: FreeType accepts `(0, 0)` but then renders
    /// degenerate 1x1 bitmaps.
    pub fn setPixelSizes(self: *Face, pixel_width: u32, pixel_height: u32) Error!void {
        if (pixel_width == 0 or pixel_height == 0) return error.InvalidPixelSize;
        const code = c.FT_Set_Pixel_Sizes(self.handle.handle, pixel_width, pixel_height);
        if (code != c.FT_Err_Ok) return ftError(code);
    }

    /// Load + render a glyph at a square pixel size (26.6-free, pixels).
    ///
    /// Equivalent to `loadRenderFlags(glyph, pixel_size, FT_LOAD_DEFAULT)`.
    pub fn loadRender(self: *Face, glyph: u32, pixel_size: u16) Error!Rendered {
        return self.loadRenderFlags(glyph, pixel_size, FT_LOAD_DEFAULT);
    }

    /// `FT_Set_Char_Size` at 72 dpi with `font_size` in pixels (converted to
    /// 26.6) so fractional sizes render at their exact size, matching
    /// upstream's `cache_key.font_size_bits` scaler. Zero, negative, NaN, and
    /// sub-1/64px sizes are rejected (`FT_SET_CHAR_SIZE` needs a positive
    /// 26.6 value).
    ///
    /// Bitmap-only faces (e.g. `NotoColorEmoji`: CBDT/sbix strikes, no
    /// outlines) have no scalable size and may reject the request. When the
    /// face `hasFixedSizes()`, the fixed strike closest to `font_size`
    /// (26.6-wise) is selected instead, so color emoji load at any requested
    /// size. The public error semantics are unchanged: a size request that
    /// cannot be satisfied at all is `error.InvalidPixelSize`.
    pub fn setCharSize(self: *Face, font_size: f32) Error!void {
        if (std.math.isNan(font_size) or font_size < 1.0 / 64.0) return error.InvalidPixelSize;
        const v = @as(f64, font_size) * 64.0;
        const max_f: f64 = @floatFromInt(@divTrunc(std.math.maxInt(c_long), 64));
        if (v > max_f) return error.InvalidPixelSize;
        const size: c_long = @intFromFloat(@round(v));
        const code = c.FT_Set_Char_Size(self.handle.handle, size, size, 72, 72);
        if (code == c.FT_Err_Ok) return;
        if (!self.hasFixedSizes()) return ftError(code);
        // Non-scalable face: fall back to its nearest embedded strike. A
        // selection failure means the request cannot be satisfied at all
        // (`error.InvalidPixelSize`), but OOM must stay transient/retryable
        // instead of being absorbed into that permanent error.
        self.selectClosestFixedSize(font_size) catch |err| {
            if (err == error.OutOfMemory) return error.OutOfMemory;
            return error.InvalidPixelSize;
        };
    }

    /// `FT_Select_Size` the fixed strike whose nominal `FT_Bitmap_Size.size`
    /// is closest to `font_size` pixels. `size` is in 26.6 fractional points
    /// (1 point == 1 pixel at this module's fixed 72 dpi), so the comparison
    /// is done against `font_size * 64`. Falls back to the first strike when
    /// comparisons are degenerate; `error.InvalidPixelSize` when the face
    /// lists no usable strike.
    fn selectClosestFixedSize(self: *Face, font_size: f32) Error!void {
        const rec = self.handle.handle;
        const count = rec.*.num_fixed_sizes;
        const sizes = rec.*.available_sizes;
        if (count <= 0 or sizes == null) return error.InvalidPixelSize;
        const target = @as(f64, font_size) * 64.0;
        const n: usize = @intCast(count);
        var best_index: i32 = 0;
        var best_distance = std.math.inf(f64);
        for (sizes[0..n], 0..) |strike, i| {
            const distance = @abs(@as(f64, @floatFromInt(strike.size)) - target);
            if (distance < best_distance) {
                best_distance = distance;
                best_index = @intCast(i);
            }
        }
        self.handle.selectSize(best_index) catch |err| return wrapperError(err);
    }

    /// `loadRenderFlags` plus the cache key's fractional subpixel offset and
    /// optional fake-italic skew.
    ///
    /// `font_size` is in pixels and may be fractional (see `setCharSize`).
    /// Bitmap-only faces fall back to their closest fixed strike in
    /// `setCharSize`; color faces load with `FT_LOAD_COLOR` and report
    /// `FT_PIXEL_MODE_BGRA` (see `loadRenderCurrentSize`).
    /// `x_offset`/`y_offset` are the binned fract values from the cache key,
    /// applied as an `FT_Set_Transform` translation in 26.6 so glyph coverage
    /// lands on the correct subpixel grid (swash.rs `Render::offset`).
    /// `fake_italic` applies the same 14-degree X skew as
    /// `swash.rs:70-77`. The face transform is reset after the call.
    pub fn loadRenderOffset(
        self: *Face,
        glyph: u32,
        font_size: f32,
        load_flags: c_int,
        x_offset: f32,
        y_offset: f32,
        fake_italic: bool,
    ) Error!Rendered {
        try self.setCharSize(font_size);
        var delta = c.FT_Vector{
            .x = pixelsTo26_6(x_offset),
            .y = pixelsTo26_6(y_offset),
        };
        if (fake_italic) {
            var matrix = c.FT_Matrix{
                .xx = 1 << 16,
                .xy = FAKE_ITALIC_MATRIX_XY,
                .yx = 0,
                .yy = 1 << 16,
            };
            c.FT_Set_Transform(self.handle.handle, &matrix, &delta);
        } else {
            c.FT_Set_Transform(self.handle.handle, null, &delta);
        }
        defer c.FT_Set_Transform(self.handle.handle, null, null);
        return self.loadRenderCurrentSize(glyph, load_flags);
    }

    /// Load a glyph with explicit `FT_LOAD_*` flags and render it when the
    /// load produced an outline (embedded bitmap strikes are already bitmaps).
    ///
    /// Rendering uses `FT_Render_Glyph(slot, FT_RENDER_MODE_NORMAL)`. Pass
    /// e.g. `FT_LOAD_DEFAULT | FT_LOAD_NO_HINTING` for unhinted coverage or
    /// `FT_LOAD_DEFAULT | FT_LOAD_NO_BITMAP` to force outline rendering. On
    /// faces where `hasColor()` holds, `FT_LOAD_COLOR` is always added so
    /// COLR/CPAL outlines and CBDT/sbix strikes come back as BGRA bitmaps.
    pub fn loadRenderFlags(
        self: *Face,
        glyph: u32,
        pixel_size: u16,
        load_flags: c_int,
    ) Error!Rendered {
        try self.setPixelSizes(pixel_size, pixel_size);
        return self.loadRenderCurrentSize(glyph, load_flags);
    }

    fn loadRenderCurrentSize(self: *Face, glyph: u32, load_flags: c_int) Error!Rendered {
        // Color-bearing faces only produce their BGRA bitmaps when the load
        // asks for them; the flag is a no-op for glyphs without color data.
        const flags = if (self.hasColor()) load_flags | FT_LOAD_COLOR else load_flags;
        const code = c.FT_Load_Glyph(self.handle.handle, glyph, flags);
        if (code != c.FT_Err_Ok) return ftError(code);
        const slot = self.handle.handle.*.glyph;
        if (slot == null) return error.FreeTypeFailure;
        if (slot.*.format != FT_GLYPH_FORMAT_BITMAP) {
            const render_code = c.FT_Render_Glyph(slot, @intCast(c.FT_RENDER_MODE_NORMAL));
            if (render_code != c.FT_Err_Ok) return ftError(render_code);
        }
        return snapshot(slot);
    }

    /// Decompose this glyph's outline into pixel-space, y-up path commands —
    /// the equivalent of swash's `scale_outline(...).path().commands()` that
    /// upstream's `get_outline_commands` returns. Unhinted vector geometry
    /// (swash scales outlines; hinting there only affects raster coverage),
    /// `FAKE_ITALIC` applies the same14° skew as the raster path, and the
    /// `wght` variation must already be set by the caller (see
    /// `font_raster.Raster.outlineCommands`).
    ///
    /// Returns `null` when the glyph has no scalable outline (bitmap-only
    /// strikes, unrenderable glyph ids — upstream's `None`) and an empty
    /// slice for a face glyph with zero contours (e.g. space). The caller
    /// owns the returned slice; `error.OutOfMemory` propagates and never
    /// returns a partial list.
    pub fn outlineCommands(
        self: *Face,
        alloc: std.mem.Allocator,
        glyph: u32,
        font_size: f32,
        fake_italic: bool,
    ) Error!?[]swash_cache_mod.OutlineCommand {
        try self.setCharSize(font_size);
        const no_bitmap: c_int = @intCast(c.FT_LOAD_NO_BITMAP);
        const load_flags: c_int = FT_LOAD_DEFAULT | FT_LOAD_NO_HINTING | no_bitmap;
        const code = c.FT_Load_Glyph(self.handle.handle, glyph, load_flags);
        if (code != c.FT_Err_Ok) return null; // no outline to give (upstream None)
        const slot = self.handle.handle.*.glyph;
        if (slot == null) return null;
        // Embedded bitmap strikes and color-only glyphs have no vector data
        // (upstream additionally probes swash's color-outline source; that
        // COLR path is not decomposed here yet — documented divergence).
        if (slot.*.format == FT_GLYPH_FORMAT_BITMAP) return null;
        var list: std.ArrayList(swash_cache_mod.OutlineCommand) = .empty;
        errdefer list.deinit(alloc);
        var ctx = DecomposeCtx{ .list = &list, .alloc = alloc, .fake_italic = fake_italic };
        const funcs = c.FT_Outline_Funcs{
            .move_to = decomposeMoveTo,
            .line_to = decomposeLineTo,
            .conic_to = decomposeConicTo,
            .cubic_to = decomposeCubicTo,
        };
        const dec = c.FT_Outline_Decompose(&slot.*.outline, &funcs, &ctx);
        if (ctx.oom) return error.OutOfMemory;
        if (dec != c.FT_Err_Ok) return null; // errdefer frees the partial list
        return try list.toOwnedSlice(alloc);
    }

    /// `FT_Get_Kerning` with `FT_KERNING_DEFAULT`.
    ///
    /// Returns the x kerning in 26.6 fixed point (64 = 1 pixel); FreeType
    /// reports 0 (not an error) for faces without kerning data.
    pub fn kerning(self: *const Face, left_glyph: u32, right_glyph: u32) Error!i64 {
        var v: c.FT_Vector = .{};
        const code = c.FT_Get_Kerning(
            self.handle.handle,
            left_glyph,
            right_glyph,
            @intCast(c.FT_KERNING_DEFAULT),
            &v,
        );
        if (code != c.FT_Err_Ok) return ftError(code);
        return @intCast(v.x);
    }

    // -- Variable-font instances ------------------------------------------

    /// Apply the requested OS/2 weight (100..900) as the design coordinate of
    /// the face's `wght` variation axis.
    ///
    /// Faces without MM/variation data are a no-op (no error) and cache the
    /// applied weight like variable faces do, so the fast path does not pay an
    /// `FT_Get_MM_Var` per glyph. Other axes keep their default coordinates.
    /// The coordinates are design units in 16.16 fixed point, one per axis:
    /// FreeType's `FT_Set_Var_Design_Coordinates` contract is satisfied by
    /// passing exactly `num_axis` values. The `FT_MM_Var` description is
    /// released with `FT_Done_MM_Var` on every path after it is obtained.
    pub fn setVariationWght(self: *Face, weight: u16) Error!void {
        // Fast path: the face keeps its coordinates between loads, so a
        // repeated request for the same weight is a no-op.
        if (self.applied_wght != null and self.applied_wght.? == weight) return;

        // Resolve the library before obtaining the MM description, so a null
        // handle cannot leak it.
        const lib = self.library.handle orelse return error.FreeTypeFailure;

        var mmvar_c: [*c]c.FT_MM_Var = null;
        const get_code = c.FT_Get_MM_Var(self.handle.handle, &mmvar_c);
        // No `fvar`/MM data (the common static-font case): nothing to vary.
        if (get_code != c.FT_Err_Ok) {
            // Allocation failure is transient: propagating it keeps the
            // weight uncached so the next call can retry, instead of
            // silently freezing the face at its default coordinates.
            if (get_code == c.FT_Err_Out_Of_Memory) return error.OutOfMemory;
            self.applied_wght = weight;
            return;
        }
        const mmvar: *c.FT_MM_Var = mmvar_c orelse {
            self.applied_wght = weight;
            return;
        };
        defer lib.doneMMVar(mmvar);

        const num_axes: usize = @intCast(mmvar.num_axis);
        if (num_axes == 0) {
            self.applied_wght = weight;
            return;
        }

        // One coordinate per axis. `Face` owns no allocator and this is a
        // transient C-bridge allocation (num_axes is tiny), so the C allocator
        // is used and freed before returning.
        const coords = std.heap.c_allocator.alloc(c.FT_Fixed, num_axes) catch
            return error.OutOfMemory;
        defer std.heap.c_allocator.free(coords);

        for (mmvar.axis[0..num_axes], coords) |axis, *coord| {
            if (axis.tag == WGHT_AXIS_TAG) {
                // Axis bounds are 16.16. Clamp each bound into i32 range
                // before shifting to 16.16, so corrupt `fvar` values cannot
                // overflow the shift in safe builds.
                const min_w: i64 = @max(@as(i64, axis.minimum >> 16), std.math.minInt(i32));
                const max_w: i64 = @min(@as(i64, axis.maximum >> 16), std.math.maxInt(i32));
                const lo = @min(min_w, max_w);
                const hi = @max(min_w, max_w);
                const clamped: i64 = std.math.clamp(@as(i64, weight), lo, hi);
                coord.* = @intCast(clamped << 16);
            } else {
                coord.* = axis.def;
            }
        }

        const set_code = c.FT_Set_Var_Design_Coordinates(
            self.handle.handle,
            @intCast(num_axes),
            coords.ptr,
        );
        if (set_code != c.FT_Err_Ok) return ftError(set_code);
        self.applied_wght = weight;
    }
};

/// Convert a fractional pixel offset to FreeType 26.6 fixed point with
/// round-to-nearest and saturation (never traps on NaN/overflow).
fn pixelsTo26_6(v: f32) c_long {
    if (std.math.isNan(v)) return 0;
    const scaled = v * 64.0;
    const max_f: f64 = @floatFromInt(std.math.maxInt(c_long));
    const min_f: f64 = @floatFromInt(std.math.minInt(c_long));
    if (@as(f64, scaled) >= max_f) return std.math.maxInt(c_long);
    if (@as(f64, scaled) <= min_f) return std.math.minInt(c_long);
    return @intFromFloat(@round(scaled));
}

/// tan(14 degrees) in FreeType 16.16 fixed point, the X skew applied by
/// `FAKE_ITALIC` (swash.rs:70-77: `Transform::skew(14deg, 0deg)`).
const FAKE_ITALIC_TAN: f64 = 0.24932800284318068;
const FAKE_ITALIC_MATRIX_XY: c_long = @intFromFloat(FAKE_ITALIC_TAN * 65536.0);

/// User state for `FT_Outline_Decompose` (see `Face.outlineCommands`).
/// FreeType reports points in26.6 fixed point; this converts to pixel-space
/// y-up coordinates (swash `scale_outline` convention) and applies the same
///14° FAKE_ITALIC skew the raster path uses.
const DecomposeCtx = struct {
    list: *std.ArrayList(swash_cache_mod.OutlineCommand),
    alloc: std.mem.Allocator,
    fake_italic: bool,
    /// Set instead of propagating through the C ABI: a callback can only
    /// abort with a nonzero code, which `outlineCommands` maps back to OOM.
    oom: bool = false,

    fn point(self: *DecomposeCtx, v: [*c]const c.FT_Vector) swash_cache_mod.Point {
        const y: f32 = @as(f32, @floatFromInt(v.*.y)) / 64.0;
        var x: f32 = @as(f32, @floatFromInt(v.*.x)) / 64.0;
        if (self.fake_italic) x += swash_cache_mod.fakeItalicSkewDx(y);
        return .{ .x = x, .y = y };
    }

    /// Returns0 on success, nonzero to abort the decomposition (OOM only).
    fn push(self: *DecomposeCtx, cmd: swash_cache_mod.OutlineCommand) c_int {
        self.list.append(self.alloc, cmd) catch {
            self.oom = true;
            return 1;
        };
        return 0;
    }
};

fn decomposeMoveTo(to: [*c]const c.FT_Vector, user: ?*anyopaque) callconv(.c) c_int {
    const ctx: *DecomposeCtx = @ptrCast(@alignCast(user.?));
    return ctx.push(.{ .move_to = ctx.point(to) });
}

fn decomposeLineTo(to: [*c]const c.FT_Vector, user: ?*anyopaque) callconv(.c) c_int {
    const ctx: *DecomposeCtx = @ptrCast(@alignCast(user.?));
    return ctx.push(.{ .line_to = ctx.point(to) });
}

fn decomposeConicTo(control: [*c]const c.FT_Vector, to: [*c]const c.FT_Vector, user: ?*anyopaque) callconv(.c) c_int {
    const ctx: *DecomposeCtx = @ptrCast(@alignCast(user.?));
    return ctx.push(.{ .quad_to = .{ .control = ctx.point(control), .to = ctx.point(to) } });
}

fn decomposeCubicTo(c1: [*c]const c.FT_Vector, c2: [*c]const c.FT_Vector, to: [*c]const c.FT_Vector, user: ?*anyopaque) callconv(.c) c_int {
    const ctx: *DecomposeCtx = @ptrCast(@alignCast(user.?));
    return ctx.push(.{ .curve_to = .{ .c1 = ctx.point(c1), .c2 = ctx.point(c2), .to = ctx.point(to) } });
}

/// A rendered glyph bitmap. `bitmap` borrows the face's glyph slot (see the
/// module docs): it is valid until the next `Face.loadRender*` call or
/// `Face.deinit`.
pub const Rendered = struct {
    /// Physical bitmap width in pixels (3x the logical width for
    /// `FT_PIXEL_MODE_LCD`).
    width: u32,
    /// Physical bitmap height in rows (3x the logical height for
    /// `FT_PIXEL_MODE_LCD_V`).
    height: u32,
    /// `bitmap_left`: left bearing in whole pixels, i.e. pen-x to the left
    /// edge of the bitmap.
    left: i32,
    /// `bitmap_top`: top bearing in whole pixels, i.e. baseline y-up to the
    /// top edge of the bitmap.
    top: i32,
    /// Fitted horizontal advance in 26.6 fixed point (`/ 64` = pixels).
    advance_x: i64,
    /// One of `FT_PIXEL_MODE_*`.
    pixel_mode: u8,
    /// Borrowed coverage/color bytes: `height * stride()` bytes when the
    /// bitmap is non-empty, otherwise an empty slice. Rows may include
    /// padding; use `rowSlice` for exact row bytes.
    bitmap: []const u8,
    /// Signed stride: positive = top row first (down flow), negative =
    /// bottom-up (up flow, `buffer` points at the bottom row).
    pitch: i32,

    /// Absolute row stride in bytes.
    pub fn stride(self: Rendered) usize {
        if (self.pitch < 0) return @intCast(-@as(i64, self.pitch));
        return @intCast(self.pitch);
    }

    /// Exact bytes of visual row `row` (0 = top), padding excluded.
    /// Returns an empty slice when `row` is out of range or the bitmap is
    /// empty. Handles negative pitch (up-flow) by walking rows in reverse
    /// memory order.
    pub fn rowSlice(self: Rendered, row: u32) []const u8 {
        if (row >= self.height) return &.{};
        const stride_bytes = self.stride();
        if (stride_bytes == 0) return &.{};
        const physical_row: u32 = if (self.pitch < 0) self.height - 1 - row else row;
        const start = @as(usize, physical_row) * stride_bytes;
        if (start >= self.bitmap.len) return &.{};
        const packed_len = packedRowBytes(self.pixel_mode, self.width);
        return self.bitmap[start..][0..@min(packed_len, self.bitmap.len - start)];
    }
};

/// Packed (unpadded) bytes per row for a pixel mode, mirroring FreeType's own
/// `ft_glyphslot_preset_bitmap` sizes:
/// - MONO: `(width + 7) / 8`
/// - GRAY / LCD / LCD_V: `width` (LCD/LCD_V widths already count subpixels)
/// - BGRA: `width * 4`
/// - anything else: 0 (unknown layout)
pub fn packedRowBytes(pixel_mode: u8, width: u32) usize {
    return switch (pixel_mode) {
        FT_PIXEL_MODE_MONO => (@as(usize, width) + 7) / 8,
        FT_PIXEL_MODE_GRAY, FT_PIXEL_MODE_LCD, FT_PIXEL_MODE_LCD_V => @as(usize, width),
        FT_PIXEL_MODE_BGRA => @as(usize, width) * 4,
        else => 0,
    };
}

fn snapshot(slot: c.FT_GlyphSlot) Error!Rendered {
    const bmp = &slot.*.bitmap;
    const rows: usize = @intCast(bmp.rows);
    const stride_bytes: usize = if (bmp.pitch < 0)
        @intCast(-@as(i64, bmp.pitch))
    else
        @intCast(bmp.pitch);

    var bytes: []const u8 = &.{};
    if (bmp.buffer != null) {
        const buffer = bmp.buffer;
        if (bmp.width != 0 and rows != 0 and stride_bytes != 0) {
            const len = std.math.mul(usize, rows, stride_bytes) catch
                return error.FreeTypeFailure;
            bytes = buffer[0..len];
        }
    }

    return .{
        .width = @intCast(bmp.width),
        .height = @intCast(bmp.rows),
        .left = @intCast(slot.*.bitmap_left),
        .top = @intCast(slot.*.bitmap_top),
        .advance_x = @intCast(slot.*.advance.x),
        .pixel_mode = bmp.pixel_mode,
        .bitmap = bytes,
        .pitch = @intCast(bmp.pitch),
    };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

const testing = std.testing;
const font = @import("font.zig");

/// Vendored font corpus, probed like the other real-font tests in this repo
/// (`tests/fonts` when run from the package root, one level up when run from
/// `src/`).
const font_path_prefixes = [_][]const u8{
    "tests/fonts/",
    "../tests/fonts/",
    "src/../tests/fonts/",
};

fn readTestFont(allocator: std.mem.Allocator, file: []const u8) ![]u8 {
    var last_err: anyerror = error.FileNotFound;
    for (font_path_prefixes) |prefix| {
        const path = try std.fs.path.join(allocator, &.{ prefix, file });
        defer allocator.free(path);
        if (std.Io.Dir.cwd().readFileAlloc(std.testing.io, path, allocator, .limited(1 << 24))) |bytes| {
            return bytes;
        } else |e| {
            last_err = e;
        }
    }
    // Only a genuinely missing corpus skips; other I/O errors propagate so a
    // broken fixture cannot silently turn into a green skip.
    if (last_err == error.FileNotFound) return error.SkipZigTest;
    return last_err;
}

fn countNonZero(bytes: []const u8) usize {
    var n: usize = 0;
    for (bytes) |b| {
        if (b != 0) n += 1;
    }
    return n;
}

/// Installed color-font candidates probed by the color tests (NotoColorEmoji
/// in its common distro locations). Tests skip when none is present so hosts
/// without a system color emoji font stay green.
const system_color_font_paths = [_][]const u8{
    "/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf",
    "/usr/share/fonts/noto/NotoColorEmoji.ttf",
    "/usr/share/fonts/google-noto-emoji/NotoColorEmoji.ttf",
    "/usr/share/fonts/emoji/NotoColorEmoji.ttf",
};

/// Read the first installed color font. `error.SkipZigTest` when none exists;
/// other I/O errors propagate so a broken file cannot silently turn into a
/// green skip.
fn readSystemColorFont(allocator: std.mem.Allocator) ![]u8 {
    var last_err: anyerror = error.FileNotFound;
    for (system_color_font_paths) |path| {
        if (std.Io.Dir.cwd().readFileAlloc(std.testing.io, path, allocator, .limited(1 << 26))) |bytes| {
            return bytes;
        } else |e| {
            last_err = e;
        }
    }
    if (last_err == error.FileNotFound) return error.SkipZigTest;
    return last_err;
}

const FaceCase = struct {
    file: []const u8,
    family: []const u8,
};

const face_cases = [_]FaceCase{
    .{ .file = "Inter-Regular.ttf", .family = "Inter" },
    .{ .file = "FiraMono-Medium.ttf", .family = "Fira Mono" },
};

test "ABI layout matches installed FreeType (LP64)" {
    // Only x86_64/aarch64 LP64 is validated here; on other models FreeType's
    // `long`/`int` widths change the offsets and this test steps aside.
    if (@sizeOf(c_long) != 8 or @sizeOf(c_int) != 4 or @sizeOf(c_short) != 2) {
        return error.SkipZigTest;
    }

    // Self-contained structs, embedded by value in face/slot. These are the
    // vendored translate-c structs, so this pins the generated bindings to
    // the installed FreeType headers.
    try testing.expectEqual(@as(usize, 16), @sizeOf(c.FT_Generic));
    try testing.expectEqual(@as(usize, 16), @sizeOf(c.FT_Vector));
    try testing.expectEqual(@as(usize, 32), @sizeOf(c.FT_BBox));
    try testing.expectEqual(@as(usize, 64), @sizeOf(c.FT_Glyph_Metrics));
    try testing.expectEqual(@as(usize, 40), @sizeOf(c.FT_Bitmap));
    try testing.expectEqual(@as(usize, 16), @offsetOf(c.FT_Bitmap, "buffer"));
    try testing.expectEqual(@as(usize, 24), @offsetOf(c.FT_Bitmap, "num_grays"));

    // FT_GlyphSlotRec prefix offsets (C `offsetof` on the installed headers).
    try testing.expectEqual(@as(usize, 0), @offsetOf(c.FT_GlyphSlotRec, "library"));
    try testing.expectEqual(@as(usize, 16), @offsetOf(c.FT_GlyphSlotRec, "next"));
    try testing.expectEqual(@as(usize, 24), @offsetOf(c.FT_GlyphSlotRec, "glyph_index"));
    try testing.expectEqual(@as(usize, 32), @offsetOf(c.FT_GlyphSlotRec, "generic"));
    try testing.expectEqual(@as(usize, 48), @offsetOf(c.FT_GlyphSlotRec, "metrics"));
    try testing.expectEqual(@as(usize, 112), @offsetOf(c.FT_GlyphSlotRec, "linearHoriAdvance"));
    try testing.expectEqual(@as(usize, 128), @offsetOf(c.FT_GlyphSlotRec, "advance"));
    try testing.expectEqual(@as(usize, 144), @offsetOf(c.FT_GlyphSlotRec, "format"));
    try testing.expectEqual(@as(usize, 152), @offsetOf(c.FT_GlyphSlotRec, "bitmap"));
    try testing.expectEqual(@as(usize, 192), @offsetOf(c.FT_GlyphSlotRec, "bitmap_left"));
    try testing.expectEqual(@as(usize, 196), @offsetOf(c.FT_GlyphSlotRec, "bitmap_top"));
    // Unlike the old prefix-only mirror, the generated struct models the
    // private tail too, so it is larger than the public prefix.
    try testing.expect(@sizeOf(c.FT_GlyphSlotRec) > 200);

    // FT_FaceRec prefix offsets.
    try testing.expectEqual(@as(usize, 0), @offsetOf(c.FT_FaceRec, "num_faces"));
    try testing.expectEqual(@as(usize, 32), @offsetOf(c.FT_FaceRec, "num_glyphs"));
    try testing.expectEqual(@as(usize, 40), @offsetOf(c.FT_FaceRec, "family_name"));
    try testing.expectEqual(@as(usize, 48), @offsetOf(c.FT_FaceRec, "style_name"));
    try testing.expectEqual(@as(usize, 56), @offsetOf(c.FT_FaceRec, "num_fixed_sizes"));
    try testing.expectEqual(@as(usize, 64), @offsetOf(c.FT_FaceRec, "available_sizes"));
    try testing.expectEqual(@as(usize, 72), @offsetOf(c.FT_FaceRec, "num_charmaps"));
    try testing.expectEqual(@as(usize, 80), @offsetOf(c.FT_FaceRec, "charmaps"));
    try testing.expectEqual(@as(usize, 88), @offsetOf(c.FT_FaceRec, "generic"));
    try testing.expectEqual(@as(usize, 104), @offsetOf(c.FT_FaceRec, "bbox"));
    try testing.expectEqual(@as(usize, 136), @offsetOf(c.FT_FaceRec, "units_per_EM"));
    try testing.expectEqual(@as(usize, 138), @offsetOf(c.FT_FaceRec, "ascender"));
    try testing.expectEqual(@as(usize, 140), @offsetOf(c.FT_FaceRec, "descender"));
    try testing.expectEqual(@as(usize, 142), @offsetOf(c.FT_FaceRec, "height"));
    try testing.expectEqual(@as(usize, 148), @offsetOf(c.FT_FaceRec, "underline_position"));
    try testing.expectEqual(@as(usize, 150), @offsetOf(c.FT_FaceRec, "underline_thickness"));
    try testing.expectEqual(@as(usize, 152), @offsetOf(c.FT_FaceRec, "glyph"));
    try testing.expectEqual(@as(usize, 160), @offsetOf(c.FT_FaceRec, "size"));
    try testing.expectEqual(@as(usize, 168), @offsetOf(c.FT_FaceRec, "charmap"));

    // Pixel mode values must match the C enum exactly.
    try testing.expectEqual(@as(u8, 1), FT_PIXEL_MODE_MONO);
    try testing.expectEqual(@as(u8, 2), FT_PIXEL_MODE_GRAY);
    try testing.expectEqual(@as(u8, 5), FT_PIXEL_MODE_LCD);
    try testing.expectEqual(@as(u8, 7), FT_PIXEL_MODE_BGRA);
    try testing.expectEqual(c.FT_PIXEL_MODE_LCD, @as(c_int, FT_PIXEL_MODE_LCD));
}

test "Library init exposes version, deinit is idempotent" {
    var lib = try Library.init();
    defer lib.deinit();

    const version = lib.version() orelse return error.TestUnexpectedResult;
    try testing.expect(version.major >= 2);
    try testing.expect(version.minor >= 0);
    try testing.expect(version.patch >= 0);

    lib.deinit();
    try testing.expect(lib.version() == null);
}

test "face metrics agree with font.zig sfnt sniff" {
    const allocator = testing.allocator;
    for (face_cases) |case| {
        const bytes = try readTestFont(allocator, case.file);
        defer allocator.free(bytes);

        var lib = try Library.init();
        defer lib.deinit();
        var face = try Face.initMemory(&lib, bytes, 0);
        defer face.deinit();

        const sniffed = font.sniffMetrics(bytes);
        try testing.expectEqual(font.Font.MetricsSource.sniffed, sniffed.source);

        // Cross-check the FreeType values against the pure-Zig sfnt parse.
        try testing.expectEqual(sniffed.metrics.units_per_em, face.upem());
        try testing.expectEqual(
            sniffed.metrics.ascent,
            @as(f32, @floatFromInt(face.ascent())),
        );
        try testing.expectEqual(
            sniffed.metrics.descent,
            @as(f32, @floatFromInt(face.descent())),
        );

        // Sanity: scalable outlines with y-down metrics.
        try testing.expect(face.upem() > 0);
        try testing.expect(face.ascent() > 0);
        try testing.expect(face.descent() < 0);
        try testing.expect(face.glyphCount() > 100);
        // TrueType `height` is ascender - descender (fits i32).
        try testing.expectEqual(
            @as(i32, face.ascent()) - @as(i32, face.descent()),
            @as(i32, face.height()),
        );
        try testing.expect(face.underlineThickness() > 0);

        // Runtime check of the translated `family_name` field.
        try testing.expectEqualStrings(case.family, face.familyName() orelse "");
        try testing.expect(face.raw().*.num_faces == 1);
    }
}

test "charIndex resolves ASCII and Arabic codepoints" {
    const allocator = testing.allocator;

    const latin_bytes = try readTestFont(allocator, "Inter-Regular.ttf");
    defer allocator.free(latin_bytes);
    var lib = try Library.init();
    defer lib.deinit();
    var latin = try Face.initMemory(&lib, latin_bytes, 0);
    defer latin.deinit();

    const a = latin.charIndex('A');
    try testing.expect(a != 0);
    try testing.expect(latin.charIndex('V') != 0);
    try testing.expect(latin.charIndex('A') != latin.charIndex('V'));
    // U+10FFFF is a noncharacter: no glyph, but looking it up must not trap.
    try testing.expectEqual(@as(u32, 0), latin.charIndex(0x10FFFF));

    const arabic_bytes = try readTestFont(allocator, "NotoSansArabic.ttf");
    defer allocator.free(arabic_bytes);
    var arabic = try Face.initMemory(&lib, arabic_bytes, 0);
    defer arabic.deinit();
    try testing.expect(arabic.charIndex(0x645) != 0); // ARABIC LETTER MEEM

    // Kerning must answer without error (Inter has no pair kerning here).
    _ = try latin.kerning(a, latin.charIndex('V'));
}

test "loadRender returns a borrowed gray coverage bitmap" {
    const allocator = testing.allocator;
    const bytes = try readTestFont(allocator, "Inter-Regular.ttf");
    defer allocator.free(bytes);

    var lib = try Library.init();
    defer lib.deinit();
    var face = try Face.initMemory(&lib, bytes, 0);
    defer face.deinit();

    const glyph = face.charIndex('A');
    try testing.expect(glyph != 0);

    const rendered = try face.loadRender(glyph, 16);
    // Linear (unhinted) advance of the same slot, in26.6: read before the
    // second loadRender below replaces the slot contents.
    const linear_advance_26_6: i64 = @divTrunc(@as(i64, face.handle.handle.*.glyph.*.linearHoriAdvance) * 64, 65536);
    try testing.expect(rendered.width > 0);
    try testing.expect(rendered.height > 0);
    try testing.expectEqual(FT_PIXEL_MODE_GRAY, rendered.pixel_mode);
    try testing.expect(rendered.pitch > 0);
    try testing.expectEqual(
        @as(usize, rendered.height) * rendered.stride(),
        rendered.bitmap.len,
    );
    try testing.expectEqual(@as(usize, rendered.width), rendered.rowSlice(0).len);
    try testing.expect(countNonZero(rendered.bitmap) > 0);
    try testing.expect(rendered.advance_x > 0);
    // Inter ('A' linear advance 10.82px at 16px, upem 2816): hinting must
    // land the advance on the whole-pixel grid, and the hinted value must be
    // the linear advance rounded to a pixel. The exact rounding is
    // FreeType-build dependent — nearest gives 704 on older builds, floor
    // gives 640 on the FreeType 2.14.3 used here — so assert the grid plus
    // the ±1px relationship instead of pinning one historical value.
    try testing.expectEqual(@as(i64, 0), @rem(rendered.advance_x, 64));
    try testing.expect(@abs(rendered.advance_x - linear_advance_26_6) <= 64);

    // The bitmap borrows slot memory; the same call again must be stable.
    const again = try face.loadRender(glyph, 16);
    try testing.expectEqual(rendered.width, again.width);
    try testing.expectEqual(rendered.height, again.height);
}

test "color faces load BGRA bitmaps through the fixed-strike fallback" {
    const allocator = testing.allocator;
    const bytes = try readSystemColorFont(allocator);
    defer allocator.free(bytes);

    var lib = try Library.init();
    defer lib.deinit();
    var face = try Face.initMemory(&lib, bytes, 0);
    defer face.deinit();

    try testing.expect(face.hasColor());
    const glyph = face.charIndex(0x1F600); // GRINNING FACE
    try testing.expect(glyph != 0);

    // Bitmap-only color faces reject char sizes other than the strike's own
    // ppem (this face's strike is 109px); the fixed-strike fallback must kick
    // in so the load still comes back as premultiplied BGRA instead of
    // failing or rendering an empty mask.
    const rendered = try face.loadRenderOffset(glyph, 32.0, FT_LOAD_DEFAULT, 0.0, 0.0, false);
    try testing.expectEqual(FT_PIXEL_MODE_BGRA, rendered.pixel_mode);
    try testing.expect(rendered.width > 0);
    try testing.expect(rendered.height > 0);
    try testing.expect(rendered.bitmap.len > 0);
    try testing.expect(countNonZero(rendered.bitmap) > 0);
    // Packed BGRA rows are width*4 bytes; pitch may add padding.
    try testing.expectEqual(@as(usize, rendered.width) * 4, rendered.rowSlice(0).len);

    // A size that matches the strike exactly uses the direct char-size path.
    try face.setCharSize(109.0);
}

test "setVariationWght renders InterVariable 400 and 900 differently" {
    const allocator = testing.allocator;
    const bytes = try readTestFont(allocator, "InterVariable.ttf");
    defer allocator.free(bytes);

    var lib = try Library.init();
    defer lib.deinit();
    var face = try Face.initMemory(&lib, bytes, 0);
    defer face.deinit();

    const glyph = face.charIndex('A');
    try testing.expect(glyph != 0);

    try face.setVariationWght(400);
    const regular = try face.loadRender(glyph, 32);
    const regular_coverage = countNonZero(regular.bitmap);
    const regular_advance = regular.advance_x;
    try testing.expect(regular_coverage > 0);

    // `regular.bitmap` borrows the slot and is invalidated by this load; only
    // the copied scalars above are used afterwards.
    try face.setVariationWght(900);
    const black = try face.loadRender(glyph, 32);
    const black_coverage = countNonZero(black.bitmap);
    const black_advance = black.advance_x;
    try testing.expect(black_coverage > 0);

    // A heavier instance covers more pixels and/or advances further.
    try testing.expect(regular_coverage != black_coverage or regular_advance != black_advance);

    // Static faces have no `wght` axis: the request is a documented no-op.
    const static_bytes = try readTestFont(allocator, "Inter-Regular.ttf");
    defer allocator.free(static_bytes);
    var static_face = try Face.initMemory(&lib, static_bytes, 0);
    defer static_face.deinit();
    try static_face.setVariationWght(900);
    const static_glyph = static_face.charIndex('A');
    const rendered = try static_face.loadRender(static_glyph, 32);
    try testing.expect(countNonZero(rendered.bitmap) > 0);
}

test "larger pixel sizes produce larger rasters" {
    const allocator = testing.allocator;
    const bytes = try readTestFont(allocator, "FiraMono-Medium.ttf");
    defer allocator.free(bytes);

    var lib = try Library.init();
    defer lib.deinit();
    var face = try Face.initMemory(&lib, bytes, 0);
    defer face.deinit();

    const glyph = face.charIndex('A');
    const small = try face.loadRender(glyph, 8);
    const small_width = small.width;
    const small_height = small.height;
    const small_len = small.bitmap.len;
    try testing.expect(small_width > 0);
    try testing.expect(small_height > 0);

    // `small.bitmap` is invalidated by the next load; only the copied scalars
    // above may be used after this point.
    const large = try face.loadRender(glyph, 32);
    try testing.expect(large.width > small_width);
    try testing.expect(large.height > small_height);
    try testing.expect(large.bitmap.len > small_len);
    try testing.expectEqual(
        @as(usize, large.height) * large.stride(),
        large.bitmap.len,
    );

    // Unhinted rendering goes through the same path and stays gray.
    const unhinted = try face.loadRenderFlags(
        glyph,
        32,
        FT_LOAD_DEFAULT | FT_LOAD_NO_HINTING,
    );
    try testing.expectEqual(FT_PIXEL_MODE_GRAY, unhinted.pixel_mode);
    try testing.expect(unhinted.width > 0 and unhinted.height > 0);
}

test "zero-size and out-of-range glyphs fail without trapping" {
    const allocator = testing.allocator;
    const bytes = try readTestFont(allocator, "Inter-Regular.ttf");
    defer allocator.free(bytes);

    var lib = try Library.init();
    defer lib.deinit();
    var face = try Face.initMemory(&lib, bytes, 0);
    defer face.deinit();

    try testing.expectError(error.InvalidPixelSize, face.setPixelSizes(0, 16));
    try testing.expectError(error.InvalidPixelSize, face.setPixelSizes(16, 0));
    const glyph = face.charIndex('A');
    try testing.expectError(error.InvalidPixelSize, face.loadRender(glyph, 0));

    // FreeType reports Invalid_Argument (or Invalid_Glyph_Index on some
    // drivers) for ids past `num_glyphs`; either is fine, a trap is not.
    const oob = face.loadRender(face.glyphCount() + 1000, 16);
    try testing.expect(oob == error.InvalidArgument or oob == error.InvalidGlyphIndex);

    // Glyph 0 (.notdef) is always loadable: empty or non-empty, never a trap.
    const notdef = try face.loadRender(0, 16);
    try testing.expect(notdef.bitmap.len == 0 or
        notdef.bitmap.len == @as(usize, notdef.height) * notdef.stride());
}

test "invalid font data and face indices are rejected" {
    var lib = try Library.init();
    defer lib.deinit();

    try testing.expectError(error.InvalidFileFormat, Face.initMemory(&lib, &.{}, 0));

    const garbage = Face.initMemory(&lib, "not a font at all!!", 0);
    try testing.expect(garbage == error.InvalidFileFormat or
        garbage == error.UnknownFileFormat);

    const allocator = testing.allocator;
    const bytes = try readTestFont(allocator, "Inter-Regular.ttf");
    defer allocator.free(bytes);
    try testing.expectError(error.InvalidArgument, Face.initMemory(&lib, bytes, 42));
}

test "Rendered.rowSlice handles up-flow (negative pitch) bitmaps" {
    // Synthetic 2x1 gray bitmap, pitch -2: memory starts at the *bottom* row
    // (FreeType "up flow"), so the visual top row is the second chunk.
    // Each row uses 1 of its 2 stride bytes; bytes 1 and 3 are padding.
    const up_flow = Rendered{
        .width = 1,
        .height = 2,
        .left = 0,
        .top = 2,
        .advance_x = 64,
        .pixel_mode = FT_PIXEL_MODE_GRAY,
        .bitmap = &.{ 0x11, 0x00, 0x22, 0x00 },
        .pitch = -2,
    };
    try testing.expectEqual(@as(usize, 2), up_flow.stride());
    try testing.expectEqualSlices(u8, &.{0x22}, up_flow.rowSlice(0));
    try testing.expectEqualSlices(u8, &.{0x11}, up_flow.rowSlice(1));
    try testing.expectEqualSlices(u8, &.{}, up_flow.rowSlice(2));

    // Packed-row helper mirrors FreeType's preset sizes.
    try testing.expectEqual(@as(usize, 1), packedRowBytes(FT_PIXEL_MODE_MONO, 8));
    try testing.expectEqual(@as(usize, 2), packedRowBytes(FT_PIXEL_MODE_MONO, 9));
    try testing.expectEqual(@as(usize, 9), packedRowBytes(FT_PIXEL_MODE_GRAY, 9));
    try testing.expectEqual(@as(usize, 15), packedRowBytes(FT_PIXEL_MODE_LCD, 15));
    try testing.expectEqual(@as(usize, 12), packedRowBytes(FT_PIXEL_MODE_BGRA, 3));
    try testing.expectEqual(@as(usize, 0), packedRowBytes(0, 9));
}

test "error mapping: FreeType OOM is retryable, persistent codes keep theirs" {
    // `FT_Err_Out_Of_Memory` must surface as `error.OutOfMemory` so
    // `font_raster`/`shape_hb` classify it as transient instead of poisoning
    // a lazily registered face.
    try testing.expectEqual(@as(Error, error.OutOfMemory), ftError(c.FT_Err_Out_Of_Memory));
    try testing.expectEqual(@as(Error, error.OutOfMemory), wrapperError(error.OutOfMemory));

    // Persistent codes keep their existing public mappings.
    try testing.expectEqual(@as(Error, error.InvalidFileFormat), ftError(c.FT_Err_Invalid_File_Format));
    try testing.expectEqual(@as(Error, error.UnknownFileFormat), ftError(c.FT_Err_Unknown_File_Format));
    try testing.expectEqual(@as(Error, error.InvalidArgument), ftError(c.FT_Err_Invalid_Argument));
    try testing.expectEqual(@as(Error, error.InvalidGlyphIndex), ftError(c.FT_Err_Invalid_Glyph_Index));
    try testing.expectEqual(@as(Error, error.InvalidPixelSize), ftError(c.FT_Err_Invalid_Pixel_Size));
    try testing.expectEqual(@as(Error, error.FreeTypeFailure), ftError(c.FT_Err_Cannot_Open_Resource));
    try testing.expectEqual(@as(Error, error.FreeTypeFailure), ftError(c.FT_Err_Invalid_Outline));
    try testing.expectEqual(@as(Error, error.InvalidFileFormat), wrapperError(error.InvalidFileFormat));
    try testing.expectEqual(@as(Error, error.FreeTypeFailure), wrapperError(error.CannotOpenResource));
    try testing.expectEqual(@as(Error, error.FreeTypeFailure), wrapperError(error.UnknownFreetypeError));
}
