const std = @import("std");
const c = @import("c.zig").c;
const Face = @import("face.zig").Face;
const Error = @import("errors.zig").Error;

pub const Font = struct {
    handle: *c.hb_font_t,

    /// Constructs a new font object from the specified face.
    pub fn create(face: Face) Error!Font {
        const handle = c.hb_font_create(face.handle) orelse return Error.HarfbuzzFailed;
        return Font{ .handle = handle };
    }

    /// Decreases the reference count on the given font object. When the
    /// reference count reaches zero, the font is destroyed, freeing all memory.
    pub fn destroy(self: *Font) void {
        c.hb_font_destroy(self.handle);
    }

    pub fn setScale(self: *Font, x: u32, y: u32) void {
        c.hb_font_set_scale(
            self.handle,
            @intCast(x),
            @intCast(y),
        );
    }

    /// Fetches the font scale of the given font object.
    pub fn getScale(self: Font, x_scale: *c_int, y_scale: *c_int) void {
        c.hb_font_get_scale(self.handle, x_scale, y_scale);
    }

    /// Configures the font-functions structure of the font object to use
    /// HarfBuzz's built-in OpenType font functions (`hb_ot_font_set_funcs`
    /// from `hb-ot-font.h`, declared locally in `c_bindings.zig`).
    pub fn setOtFuncs(self: Font) void {
        c.hb_ot_font_set_funcs(self.handle);
    }

    /// Fetches the nominal glyph of the specified Unicode codepoint, or `null`
    /// when the font does not have a glyph for it.
    pub fn getNominalGlyph(self: Font, unicode: u32) ?u32 {
        var glyph: c.hb_codepoint_t = 0;
        if (c.hb_font_get_nominal_glyph(self.handle, unicode, &glyph) == 0) return null;
        return glyph;
    }

    /// Fetches the horizontal advance of the specified glyph, in font units.
    pub fn getHAdvance(self: Font, glyph: u32) i32 {
        return c.hb_font_get_glyph_h_advance(self.handle, glyph);
    }

    /// Fetches the horizontal extents of the font object. Returns `false` when
    /// the font does not have horizontal metrics.
    pub fn getHExtents(self: Font, extents: *c.hb_font_extents_t) bool {
        return c.hb_font_get_h_extents(self.handle, extents) != 0;
    }
};
