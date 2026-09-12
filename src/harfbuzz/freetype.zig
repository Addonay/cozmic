const freetype = @import("freetype");
const std = @import("std");
const c = @import("c.zig").c;
const dyn = @import("dyn.zig");
const dynload = @import("dynload");
const Face = @import("face.zig").Face;
const Font = @import("font.zig").Font;
const Error = @import("errors.zig").Error;

/// Ensure both C libraries backing this bridge are resolvable. HarfBuzz
/// supplies the `hb_ft_*` entry points; FreeType is reached indirectly by
/// `hb_ft_face_create_referenced` (`FT_Reference_Face`). This file is part of
/// the `harfbuzz` module but can be imported on its own, so it cannot rely on
/// `shape_hb.Backend.init` having run first.
fn ensureLibraries() Error!void {
    dyn.ensureLoaded() catch return Error.HarfbuzzFailed;
    freetype.dyn.ensureLoaded() catch return Error.HarfbuzzFailed;
}

/// State of the optional HarfBuzz FreeType bridge (`hb-ft`).
///
/// `c.required_symbols` deliberately excludes every `hb_ft_*` entry point: a
/// HarfBuzz built without FreeType support does not export them, and the core
/// shaper must load and shape regardless. They are resolved here on first use,
/// all-or-nothing, and assigned to the generated `c.hb_ft_*` variables only
/// when all three are present.
const Bridge = struct {
    /// Serializes the first resolution.
    mutex: dynload.Mutex = .{},
    state: State = .uninitialized,

    const State = enum { uninitialized, ready, unavailable };

    /// True when the running HarfBuzz exports the `hb-ft` entry points used
    /// here. Resolves and binds them on first call.
    ///
    /// A missing core library does not produce a bridge verdict: the state
    /// stays `uninitialized` (the core loader already negative-caches its own
    /// failure), so calling again is cheap and never misreports hb-ft as the
    /// problem.
    fn available(self: *Bridge) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        switch (self.state) {
            .ready => return true,
            .unavailable => return false,
            .uninitialized => {},
        }

        dyn.ensureLoaded() catch return false;

        const face_create = dyn.lookupSymbol("hb_ft_face_create_referenced") orelse
            return self.markUnavailable();
        const font_create = dyn.lookupSymbol("hb_ft_font_create_referenced") orelse
            return self.markUnavailable();
        const font_set_funcs = dyn.lookupSymbol("hb_ft_font_set_funcs") orelse
            return self.markUnavailable();

        // All-or-nothing: never leave a partially configured bridge behind.
        c.hb_ft_face_create_referenced = @ptrCast(@alignCast(face_create));
        c.hb_ft_font_create_referenced = @ptrCast(@alignCast(font_create));
        c.hb_ft_font_set_funcs = @ptrCast(@alignCast(font_set_funcs));
        self.state = .ready;
        return true;
    }

    /// Record the missing bridge and report it once. Caller holds `mutex`.
    fn markUnavailable(self: *Bridge) bool {
        self.state = .unavailable;
        std.log.warn(
            "harfbuzz has no FreeType bridge (hb_ft_* symbols missing); hb-ft face/font creation is unavailable",
            .{},
        );
        return false;
    }
};

var bridge: Bridge = .{};

/// True when the running HarfBuzz exports the `hb-ft` entry points this file
/// uses. Resolves them on first call; test/introspection helper and the
/// regression test's skip condition.
pub fn bridgeAvailable() bool {
    return bridge.available();
}

fn ensureBridge() Error!void {
    if (!bridge.available()) return Error.HarfbuzzFailed;
}

/// Creates an hb_face_t face object from the specified FT_Face.
///
/// This is the preferred variant of the hb_ft_face_create* function
/// family, because it calls FT_Reference_Face() on ft_face , ensuring
/// that ft_face remains alive as long as the resulting hb_face_t face
/// object remains alive. Also calls FT_Done_Face() when the hb_face_t
/// face object is destroyed.
///
/// Use this version unless you know you have good reasons not to.
///
/// The hb-ft entry points take the HarfBuzz copy of the translate-c
/// `FT_Face`; `@ptrCast` bridges the two structurally identical C pointer
/// types. Returns `error.HarfbuzzFailed` when either library is unavailable
/// or the running HarfBuzz has no FreeType bridge.
pub fn createFace(face: freetype.c.FT_Face) Error!Face {
    try ensureLibraries();
    try ensureBridge();
    const handle = c.hb_ft_face_create_referenced(@ptrCast(face)) orelse
        return Error.HarfbuzzFailed;
    return Face{ .handle = handle };
}

/// Creates an hb_font_t font object from the specified FT_Face.
///
/// Returns `error.HarfbuzzFailed` when either library is unavailable or the
/// running HarfBuzz has no FreeType bridge.
pub fn createFont(face: freetype.c.FT_Face) Error!Font {
    try ensureLibraries();
    try ensureBridge();
    const handle = c.hb_ft_font_create_referenced(@ptrCast(face)) orelse
        return Error.HarfbuzzFailed;
    return Font{ .handle = handle };
}

/// Configures the font-functions structure of the specified hb_font_t font
/// object to use FreeType font functions.
///
/// In particular, you can use this function to configure an existing
/// hb_face_t face object for use with FreeType font functions even if that
/// hb_face_t face object was initially created with hb_face_create(), and
/// therefore was not initially configured to use FreeType font functions.
///
/// An hb_face_t face object created with hb_ft_face_create() is preconfigured
/// for FreeType font functions and does not require this function to be used.
///
/// A no-op when the running HarfBuzz has no FreeType bridge; that absence is
/// reported once by `bridgeAvailable` (see `markUnavailable`).
pub fn setFontFuncs(font: Font) void {
    if (!bridge.available()) return;
    c.hb_ft_font_set_funcs(font.handle);
}

test {
    if (!bridgeAvailable()) return error.SkipZigTest;

    const testing = std.testing;
    try dyn.ensureLoaded();
    try freetype.dyn.ensureLoaded();

    const testFont = try freetype.testing.loadTestFont(testing.allocator);
    defer testing.allocator.free(testFont);
    const ftc = freetype.c;
    const ftok = ftc.FT_Err_Ok;

    var ft_lib: ftc.FT_Library = undefined;
    if (ftc.FT_Init_FreeType(&ft_lib) != ftok)
        return error.FreeTypeInitFailed;
    defer _ = ftc.FT_Done_FreeType(ft_lib);

    var ft_face: ftc.FT_Face = undefined;
    try testing.expect(ftc.FT_New_Memory_Face(
        ft_lib,
        testFont.ptr,
        @intCast(testFont.len),
        0,
        &ft_face,
    ) == ftok);
    defer _ = ftc.FT_Done_Face(ft_face);

    var face = try createFace(ft_face);
    defer face.destroy();

    var font = try createFont(ft_face);
    defer font.destroy();
    setFontFuncs(font);
}

test "bridge availability matches the optional hb-ft symbols" {
    // The core harfbuzz library must load with or without the bridge.
    try dyn.ensureLoaded();

    const symbols_present = dyn.lookupSymbol("hb_ft_face_create_referenced") != null and
        dyn.lookupSymbol("hb_ft_font_create_referenced") != null and
        dyn.lookupSymbol("hb_ft_font_set_funcs") != null;
    try std.testing.expectEqual(symbols_present, bridgeAvailable());
    // Calling it again must return the cached verdict.
    try std.testing.expectEqual(symbols_present, bridgeAvailable());
}
