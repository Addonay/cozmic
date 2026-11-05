//! COLRv1 color glyphs, rendered by HarfBuzz's `hb-raster`.
//!
//! FreeType renders COLRv0, CBDT and sbix but not COLRv1: it loads such a glyph
//! as an empty one, or as its monochrome fallback outline. The bundled HarfBuzz
//! has a full paint-graph rasterizer, so those glyphs go through it instead.
//!
//! Only the bundled build has it. `-Dsystem-libs` resolves HarfBuzz at runtime
//! and hb-raster is a separate shared library there, so `supported` is false
//! and these glyphs stay as FreeType renders them. The declarations live here
//! rather than in `harfbuzz/c_bindings.zig` for that reason: the generated
//! dynamic bindings would otherwise have to resolve them.

const std = @import("std");
const raster_ft = @import("raster_ft.zig");

pub const supported = @import("link_options").bundled;

const hb_blob_t = opaque {};
const hb_face_t = opaque {};
const hb_font_t = opaque {};
const hb_raster_paint_t = opaque {};
const hb_raster_image_t = opaque {};
const hb_memory_mode_readonly: c_uint = 2;

const hb_glyph_extents_t = extern struct {
    x_bearing: i32 = 0,
    y_bearing: i32 = 0,
    width: i32 = 0,
    height: i32 = 0,
};

const hb_raster_extents_t = extern struct {
    x_origin: c_int = 0,
    y_origin: c_int = 0,
    width: c_uint = 0,
    height: c_uint = 0,
    stride: c_uint = 0,
};

extern fn hb_blob_create(data: [*]const u8, length: c_uint, mode: c_uint, user_data: ?*anyopaque, destroy: ?*const fn (?*anyopaque) callconv(.c) void) ?*hb_blob_t;
extern fn hb_blob_destroy(blob: ?*hb_blob_t) void;
extern fn hb_face_create(blob: ?*hb_blob_t, index: c_uint) ?*hb_face_t;
extern fn hb_face_destroy(face: ?*hb_face_t) void;
extern fn hb_font_create(face: ?*hb_face_t) ?*hb_font_t;
extern fn hb_font_destroy(font: ?*hb_font_t) void;
extern fn hb_font_set_scale(font: ?*hb_font_t, x_scale: c_int, y_scale: c_int) void;
extern fn hb_font_set_variation(font: ?*hb_font_t, tag: u32, value: f32) void;
extern fn hb_font_set_var_named_instance(font: ?*hb_font_t, instance_index: c_uint) void;
extern fn hb_font_get_glyph_extents(font: ?*hb_font_t, glyph: u32, extents: *hb_glyph_extents_t) c_int;
extern fn hb_font_get_glyph_h_advance(font: ?*hb_font_t, glyph: u32) i32;
extern fn hb_font_get_nominal_glyph(font: ?*hb_font_t, unicode: u32, glyph: *u32) c_int;
extern fn hb_ot_color_glyph_has_paint(face: ?*hb_face_t, glyph: u32) c_int;
extern fn hb_raster_paint_create_or_fail() ?*hb_raster_paint_t;
extern fn hb_raster_paint_destroy(paint: ?*hb_raster_paint_t) void;
extern fn hb_raster_paint_reset(paint: ?*hb_raster_paint_t) void;
extern fn hb_raster_paint_set_transform(paint: ?*hb_raster_paint_t, xx: f32, yx: f32, xy: f32, yy: f32, dx: f32, dy: f32) void;
extern fn hb_raster_paint_set_scale_factor(paint: ?*hb_raster_paint_t, x: f32, y: f32) void;
extern fn hb_raster_paint_set_glyph_extents(paint: ?*hb_raster_paint_t, extents: *const hb_glyph_extents_t) c_int;
extern fn hb_raster_paint_glyph(paint: ?*hb_raster_paint_t, font: ?*hb_font_t, glyph: u32, pen_x: f32, pen_y: f32, palette: c_uint, foreground: u32) c_int;
extern fn hb_raster_paint_render(paint: ?*hb_raster_paint_t) ?*hb_raster_image_t;
extern fn hb_raster_image_destroy(image: ?*hb_raster_image_t) void;
extern fn hb_raster_image_get_buffer(image: ?*hb_raster_image_t) ?[*]const u8;
extern fn hb_raster_image_get_extents(image: ?*hb_raster_image_t, extents: *hb_raster_extents_t) void;

const WGHT_TAG: u32 = 0x77676874;
/// Font scale per pixel: glyph coordinates are 26.6, like FreeType's.
const SUBPIXEL_SCALE: f32 = 64.0;
/// Opaque black. A color glyph has no text color at this level, and FreeType's
/// COLRv0 path uses the same default for "foreground" palette entries.
const FOREGROUND: u32 = 0x000000FF;

/// HarfBuzz's view of one registered face. Borrows the font bytes, which must
/// outlive it.
pub const Font = struct {
    face: *hb_face_t,
    font: *hb_font_t,
    applied_wght: ?u16 = null,

    /// `index` may be FreeType's packed `(named_instance << 16) | face`.
    pub fn create(bytes: []const u8, index: i32) ?Font {
        if (bytes.len > std.math.maxInt(c_uint)) return null;
        const blob = hb_blob_create(bytes.ptr, @intCast(bytes.len), hb_memory_mode_readonly, null, null) orelse return null;
        // The face keeps its own reference.
        defer hb_blob_destroy(blob);
        const packed_index: u32 = @bitCast(index);
        const face = hb_face_create(blob, packed_index & 0xFFFF) orelse return null;
        const font = hb_font_create(face) orelse {
            hb_face_destroy(face);
            return null;
        };
        const named_instance = packed_index >> 16;
        if (named_instance != 0) hb_font_set_var_named_instance(font, named_instance - 1);
        return .{ .face = face, .font = font };
    }

    pub fn destroy(self: *Font) void {
        hb_font_destroy(self.font);
        hb_face_destroy(self.face);
        self.* = undefined;
    }

    pub fn hasPaint(self: *const Font, glyph: u32) bool {
        return hb_ot_color_glyph_has_paint(self.face, glyph) != 0;
    }

    pub fn nominalGlyph(self: *const Font, codepoint: u32) ?u32 {
        var glyph: u32 = 0;
        if (hb_font_get_nominal_glyph(self.font, codepoint, &glyph) == 0) return null;
        return glyph;
    }

    fn setWeight(self: *Font, weight: u16) void {
        if (self.applied_wght == weight) return;
        hb_font_set_variation(self.font, WGHT_TAG, @floatFromInt(weight));
        self.applied_wght = weight;
    }
};

/// The reusable paint context and the image of the last rendered glyph.
pub const Painter = struct {
    paint: ?*hb_raster_paint_t = null,
    image: ?*hb_raster_image_t = null,

    pub fn deinit(self: *Painter) void {
        self.releaseImage();
        if (self.paint) |paint| hb_raster_paint_destroy(paint);
        self.* = undefined;
    }

    /// Frees the pixels of the last `render`.
    pub fn releaseImage(self: *Painter) void {
        if (self.image) |image| hb_raster_image_destroy(image);
        self.image = null;
    }

    /// Renders one glyph with the same contract as FreeType's path: offsets in
    /// pixels (y up), premultiplied BGRA, valid until the next call. Null when
    /// HarfBuzz cannot render it, so the caller can fall back.
    pub fn render(
        self: *Painter,
        font: *Font,
        glyph: u32,
        font_size: f32,
        weight: u16,
        x_offset: f32,
        y_offset: f32,
        italic_skew: f32,
    ) ?raster_ft.Rendered {
        self.releaseImage();
        if (self.paint == null) self.paint = hb_raster_paint_create_or_fail();
        const paint = self.paint orelse return null;
        hb_raster_paint_reset(paint);

        const scale = std.math.lossyCast(c_int, @round(font_size * SUBPIXEL_SCALE));
        if (scale <= 0) return null;
        font.setWeight(weight);
        hb_font_set_scale(font.font, scale, scale);

        var extents = hb_glyph_extents_t{};
        if (hb_font_get_glyph_extents(font.font, glyph, &extents) == 0) return null;
        const pen_x = x_offset * SUBPIXEL_SCALE;
        const pen_y = y_offset * SUBPIXEL_SCALE;
        // Round outward: the pen is fractional, and hb-raster clips to these.
        extents.x_bearing +|= @as(i32, @intFromFloat(@floor(pen_x)));
        extents.y_bearing +|= @as(i32, @intFromFloat(@ceil(pen_y)));
        extents.width +|= 1;
        extents.height -|= 1;

        hb_raster_paint_set_scale_factor(paint, SUBPIXEL_SCALE, SUBPIXEL_SCALE);
        hb_raster_paint_set_transform(paint, 1, 0, italic_skew, 1, 0, 0);
        if (hb_raster_paint_set_glyph_extents(paint, &extents) == 0) return null;
        if (hb_raster_paint_glyph(paint, font.font, glyph, pen_x, pen_y, 0, FOREGROUND) == 0) {
            hb_raster_paint_reset(paint);
            return null;
        }
        const image = hb_raster_paint_render(paint) orelse return null;
        self.image = image;

        var out = hb_raster_extents_t{};
        hb_raster_image_get_extents(image, &out);
        const buffer = hb_raster_image_get_buffer(image) orelse return null;
        if (out.width == 0 or out.height == 0) return null;
        const size = @as(usize, out.stride) * out.height;
        return .{
            .width = out.width,
            .height = out.height,
            .left = out.x_origin,
            .top = out.y_origin + @as(i32, @intCast(out.height)),
            .advance_x = hb_font_get_glyph_h_advance(font.font, glyph),
            .pixel_mode = raster_ft.FT_PIXEL_MODE_BGRA,
            .bitmap = buffer[0..size],
            // Row 0 is the bottom edge: hb-raster's y axis points up.
            .pitch = -@as(i32, @intCast(out.stride)),
        };
    }
};
