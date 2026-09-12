//! Small RGBA pixmap used by image regression tests.
//!
//! Standalone on purpose: imported directly by `draw.zig` harnesses and test
//! scaffolding, never through `src/` (mirrors `tests/common/png.zig`).
//!
//! Pixel storage is RGBA8, non-premultiplied, row-major, top-down.
//! `fillRect` performs source-over blending with premultiplied intermediates,
//! rounded to nearest, matching tiny-skia's default for fully covered pixels.

const std = @import("std");

const Allocator = std.mem.Allocator;

pub const Error = error{
    /// `width * height * 4` does not fit in `usize`.
    InvalidDimensions,
    OutOfMemory,
};

/// Straight (non-premultiplied) RGBA color.
pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

/// RGBA8 pixel buffer: `data.len == width * height * 4`.
pub const Pixmap = struct {
    width: u32,
    height: u32,
    data: []u8,
    allocator: Allocator,

    /// Allocate a zeroed (transparent) pixmap.
    pub fn init(allocator: Allocator, width: u32, height: u32) Error!Pixmap {
        const row_bytes = std.math.mul(usize, width, 4) catch return error.InvalidDimensions;
        const len = std.math.mul(usize, row_bytes, height) catch return error.InvalidDimensions;
        const data = allocator.alloc(u8, len) catch return error.OutOfMemory;
        @memset(data, 0);
        return .{
            .width = width,
            .height = height,
            .data = data,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Pixmap) void {
        self.allocator.free(self.data);
        self.* = undefined;
    }

    /// Replace every pixel with `color`.
    pub fn fill(self: *Pixmap, color: Color) void {
        var i: usize = 0;
        while (i < self.data.len) : (i += 4) {
            self.data[i + 0] = color.r;
            self.data[i + 1] = color.g;
            self.data[i + 2] = color.b;
            self.data[i + 3] = color.a;
        }
    }

    /// Blend `color` over the pixels inside the rectangle, source-over.
    ///
    /// The rectangle is integer-aligned and clamped to the pixmap; negative
    /// coordinates and rectangles extending past the edges are supported.
    /// Fully transparent sources are a no-op.
    pub fn fillRect(self: *Pixmap, x: i32, y: i32, w: u32, h: u32, color: Color) void {
        if (w == 0 or h == 0 or color.a == 0) return;

        const x0: i64 = @max(@as(i64, x), 0);
        const y0: i64 = @max(@as(i64, y), 0);
        const x1: i64 = @min(@as(i64, x) + @as(i64, w), @as(i64, self.width));
        const y1: i64 = @min(@as(i64, y) + @as(i64, h), @as(i64, self.height));
        if (x0 >= x1 or y0 >= y1) return;

        const row_bytes = @as(usize, self.width) * 4;
        var yy: i64 = y0;
        while (yy < y1) : (yy += 1) {
            const row = self.data[@as(usize, @intCast(yy)) * row_bytes ..][0..row_bytes];
            var xx: i64 = x0;
            while (xx < x1) : (xx += 1) {
                blendPixel(row[@as(usize, @intCast(xx)) * 4 ..][0..4], color);
            }
        }
    }
};

/// Source-over blend of `src` onto one non-premultiplied RGBA pixel.
///
/// Works in premultiplied space:
///   src_pm  = round(src * src_a / 255)
///   dst_pm  = round(dst * dst_a / 255)
///   out_a   = src_a + round(dst_a * (255 - src_a) / 255)
///   out_pm  = src_pm + round(dst_pm * (255 - src_a) / 255)
/// and unpremultiplies the result. For an opaque destination this reduces to
/// tiny-skia's `dst = src + dst * (1 - a)` with round-to-nearest.
fn blendPixel(pixel: *[4]u8, src: Color) void {
    const src_a: u32 = src.a;
    if (src_a == 0) return;
    const inv_a: u32 = 255 - src_a;

    const src_pm_r = div255(@as(u32, src.r) * src_a);
    const src_pm_g = div255(@as(u32, src.g) * src_a);
    const src_pm_b = div255(@as(u32, src.b) * src_a);

    if (src_a == 255) {
        pixel.* = .{ src.r, src.g, src.b, 255 };
        return;
    }

    const dst_a: u32 = pixel[3];
    const dst_pm_r = div255(@as(u32, pixel[0]) * dst_a);
    const dst_pm_g = div255(@as(u32, pixel[1]) * dst_a);
    const dst_pm_b = div255(@as(u32, pixel[2]) * dst_a);

    const out_a = src_a + div255(dst_a * inv_a);
    if (out_a == 0) {
        pixel.* = .{ 0, 0, 0, 0 };
        return;
    }

    pixel[0] = unpremultiply(src_pm_r + div255(dst_pm_r * inv_a), out_a);
    pixel[1] = unpremultiply(src_pm_g + div255(dst_pm_g * inv_a), out_a);
    pixel[2] = unpremultiply(src_pm_b + div255(dst_pm_b * inv_a), out_a);
    pixel[3] = @intCast(out_a);
}

/// Round `v / 255` to nearest.
inline fn div255(v: u32) u32 {
    return (v + 127) / 255;
}

/// Round `c * 255 / a` to nearest; `a != 0` and `c <= a` (so the result
/// always fits in `u8`).
inline fn unpremultiply(c: u32, a: u32) u8 {
    return @intCast((c * 255 + a / 2) / a);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

/// Read one pixel. Test-only convenience; panics on out-of-range access.
fn pixelAt(pixmap: *const Pixmap, x: u32, y: u32) [4]u8 {
    const offset = (@as(usize, y) * pixmap.width + x) * 4;
    return pixmap.data[offset..][0..4].*;
}

const black = Color{ .r = 0, .g = 0, .b = 0, .a = 255 };
const white = Color{ .r = 255, .g = 255, .b = 255, .a = 255 };

test "fillRect performs source-over blending with rounded premultiplied math" {
    const testing = std.testing;
    var pixmap = try Pixmap.init(testing.allocator, 2, 1);
    defer pixmap.deinit();

    pixmap.fill(white);
    pixmap.fillRect(0, 0, 2, 1, .{ .r = 0, .g = 0, .b = 0, .a = 128 });

    for (0..2) |x| {
        const px = pixelAt(&pixmap, @intCast(x), 0);
        // 255 * 127 / 255 = 127 (round-to-nearest).
        try testing.expect(px[0] == 127 or px[0] == 128);
        try testing.expect(px[0] == px[1] and px[1] == px[2]);
        try testing.expectEqual(@as(u8, 255), px[3]);
    }
}

test "fillRect known source-over values on an opaque destination" {
    const testing = std.testing;
    var pixmap = try Pixmap.init(testing.allocator, 1, 1);
    defer pixmap.deinit();

    pixmap.fill(.{ .r = 200, .g = 100, .b = 50, .a = 255 });
    pixmap.fillRect(0, 0, 1, 1, .{ .r = 100, .g = 50, .b = 25, .a = 128 });

    // src_pm = (50, 25, 13), out = src_pm + round(dst * 127 / 255), a stays 255.
    const px = pixelAt(&pixmap, 0, 0);
    try testing.expectEqualSlices(u8, &.{ 150, 75, 38, 255 }, &px);
}

test "fillRect with a transparent source leaves pixels unchanged" {
    const testing = std.testing;
    var pixmap = try Pixmap.init(testing.allocator, 4, 2);
    defer pixmap.deinit();

    pixmap.fill(.{ .r = 10, .g = 20, .b = 30, .a = 200 });
    const before = try testing.allocator.dupe(u8, pixmap.data);
    defer testing.allocator.free(before);

    pixmap.fillRect(-1, -1, 10, 10, .{ .r = 255, .g = 0, .b = 0, .a = 0 });
    try testing.expectEqualSlices(u8, before, pixmap.data);
}

test "fillRect clamps to the pixmap bounds" {
    const testing = std.testing;
    var pixmap = try Pixmap.init(testing.allocator, 4, 4);
    defer pixmap.deinit();
    pixmap.fill(black);

    // Top-left corner clipped by negative coordinates: only (0, 0) is hit.
    pixmap.fillRect(-1, -1, 2, 2, white);
    // Bottom-right corner clipped by the far edge: only (3, 3) is hit.
    pixmap.fillRect(3, 3, 100, 100, .{ .r = 255, .g = 0, .b = 0, .a = 255 });
    // Empty and fully out-of-bounds rectangles write nothing.
    pixmap.fillRect(0, 0, 0, 4, .{ .r = 0, .g = 255, .b = 0, .a = 255 });
    pixmap.fillRect(0, 0, 4, 0, .{ .r = 0, .g = 255, .b = 0, .a = 255 });
    pixmap.fillRect(10, 10, 5, 5, .{ .r = 0, .g = 255, .b = 0, .a = 255 });
    pixmap.fillRect(-10, -10, 3, 3, .{ .r = 0, .g = 255, .b = 0, .a = 255 });

    for (0..4) |y| {
        for (0..4) |x| {
            const expected: [4]u8 = if (x == 0 and y == 0)
                .{ 255, 255, 255, 255 }
            else if (x == 3 and y == 3)
                .{ 255, 0, 0, 255 }
            else
                .{ 0, 0, 0, 255 };
            const px = pixelAt(&pixmap, @intCast(x), @intCast(y));
            try testing.expectEqualSlices(u8, &expected, &px);
        }
    }

    // Extremes must not overflow the clamping arithmetic; the rectangle
    // covers everything.
    pixmap.fillRect(
        std.math.minInt(i32),
        std.math.minInt(i32),
        std.math.maxInt(u32),
        std.math.maxInt(u32),
        .{ .r = 0, .g = 0, .b = 255, .a = 255 },
    );
    for (0..16) |i| {
        try testing.expectEqualSlices(u8, &.{ 0, 0, 255, 255 }, pixmap.data[i * 4 ..][0..4]);
    }
}

test "fillRect rounds premultiplied channels without overflow" {
    const testing = std.testing;
    var pixmap = try Pixmap.init(testing.allocator, 3, 1);
    defer pixmap.deinit();
    pixmap.fill(.{ .r = 1, .g = 254, .b = 128, .a = 255 });

    // Opaque sources replace the destination exactly.
    pixmap.fillRect(0, 0, 1, 1, .{ .r = 1, .g = 254, .b = 128, .a = 255 });
    const px0 = pixelAt(&pixmap, 0, 0);
    try testing.expectEqualSlices(u8, &.{ 1, 254, 128, 255 }, &px0);

    // Nearly transparent source: faint, rounded contribution.
    pixmap.fillRect(1, 0, 1, 1, .{ .r = 255, .g = 255, .b = 255, .a = 1 });
    const px1 = pixelAt(&pixmap, 1, 0);
    try testing.expectEqualSlices(u8, &.{ 2, 254, 128, 255 }, &px1);

    // Half-transparent black over the original destination.
    pixmap.fillRect(2, 0, 1, 1, .{ .r = 0, .g = 0, .b = 0, .a = 128 });
    const px2 = pixelAt(&pixmap, 2, 0);
    try testing.expectEqualSlices(u8, &.{ 0, 127, 64, 255 }, &px2);
}
