//! Minimal PNG encoder/decoder for image regression tests.
//!
//! Encodes 8-bit RGBA (color type 6) PNGs using filter type 0 per scanline
//! and decodes non-interlaced 8-bit PNGs of color types 0 (gray), 2 (RGB),
//! 4 (gray + alpha) and 6 (RGBA), supporting multiple IDAT chunks and all
//! five scanline filters. Decoded pixels are RGBA8, non-premultiplied,
//! row-major, top-down.
//!
//! This file is standalone: it must not import anything from `src/`.

const std = @import("std");
const flate = std.compress.flate;

const Allocator = std.mem.Allocator;

/// PNG file signature (spec section 5.2).
pub const signature = [8]u8{ 0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n' };

pub const Error = error{
    /// The byte stream is not a well-formed PNG.
    InvalidPng,
    /// The PNG is well-formed but uses a feature this decoder does not
    /// implement (bit depth other than 8, interlacing, unknown color type).
    UnsupportedPng,
    /// `rgba.len` does not match `width * height * 4`.
    InvalidDimensions,
    OutOfMemory,
};

/// Decoded image: RGBA8, non-premultiplied, row-major, top-down.
pub const Image = struct {
    width: u32,
    height: u32,
    data: []u8,
    allocator: Allocator,

    pub fn deinit(self: *Image) void {
        self.allocator.free(self.data);
        self.* = undefined;
    }
};

/// Encode `rgba` (`width * height * 4` bytes, non-premultiplied RGBA8,
/// row-major, top-down) into a complete PNG file image.
pub fn encodeAlloc(allocator: Allocator, width: u32, height: u32, rgba: []const u8) Error![]u8 {
    if (width == 0 or height == 0) return error.InvalidDimensions;
    const row_bytes = std.math.mul(usize, width, 4) catch return error.InvalidDimensions;
    const expected_len = std.math.mul(usize, row_bytes, height) catch return error.InvalidDimensions;
    if (rgba.len != expected_len) return error.InvalidDimensions;

    const zlib_data = try compressScanlines(allocator, width, height, rgba);
    defer allocator.free(zlib_data);

    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    try out.appendSlice(allocator, &signature);

    var ihdr: [13]u8 = undefined;
    std.mem.writeInt(u32, ihdr[0..4], width, .big);
    std.mem.writeInt(u32, ihdr[4..8], height, .big);
    ihdr[8] = 8; // bit depth
    ihdr[9] = 6; // color type: RGBA
    ihdr[10] = 0; // compression method: deflate
    ihdr[11] = 0; // filter method: adaptive filtering
    ihdr[12] = 0; // interlace method: none
    try writeChunk(allocator, &out, "IHDR", &ihdr);
    try writeChunk(allocator, &out, "IDAT", zlib_data);
    try writeChunk(allocator, &out, "IEND", &.{});

    return out.toOwnedSlice(allocator);
}

/// Decode a complete PNG file image into a freshly allocated `Image`.
pub fn decodeAlloc(allocator: Allocator, bytes: []const u8) Error!Image {
    if (bytes.len < signature.len) return error.InvalidPng;
    if (!std.mem.eql(u8, bytes[0..signature.len], &signature)) return error.InvalidPng;

    var width: u32 = 0;
    var height: u32 = 0;
    var channels: usize = 0;
    var seen_ihdr = false;
    var seen_iend = false;
    var idat: std.ArrayList(u8) = .empty;
    defer idat.deinit(allocator);

    var pos: usize = signature.len;
    while (pos < bytes.len) {
        // Chunk layout: length(4) type(4) data(length) crc(4).
        if (bytes.len - pos < 8) return error.InvalidPng;
        const chunk_len = std.mem.readInt(u32, bytes[pos..][0..4], .big);
        const chunk_type = bytes[pos + 4 ..][0..4];
        const data_start = pos + 8;
        const data_end = std.math.add(usize, data_start, chunk_len) catch return error.InvalidPng;
        const crc_end = std.math.add(usize, data_end, 4) catch return error.InvalidPng;
        if (crc_end > bytes.len) return error.InvalidPng;
        const chunk_data = bytes[data_start..data_end];

        var crc = std.hash.Crc32.init();
        crc.update(chunk_type);
        crc.update(chunk_data);
        const stored_crc = std.mem.readInt(u32, bytes[data_end..][0..4], .big);
        if (crc.final() != stored_crc) return error.InvalidPng;

        if (std.mem.eql(u8, chunk_type, "IHDR")) {
            if (seen_ihdr or pos != signature.len) return error.InvalidPng;
            if (chunk_data.len != 13) return error.InvalidPng;
            width = std.mem.readInt(u32, chunk_data[0..4], .big);
            height = std.mem.readInt(u32, chunk_data[4..8], .big);
            const bit_depth = chunk_data[8];
            const color_type = chunk_data[9];
            const compression_method = chunk_data[10];
            const filter_method = chunk_data[11];
            const interlace_method = chunk_data[12];

            // The spec caps dimensions at 2^31-1; reject zero as well.
            if (width == 0 or height == 0) return error.InvalidPng;
            if (width > std.math.maxInt(i31) or height > std.math.maxInt(i31)) return error.InvalidPng;
            if (bit_depth != 8) return error.UnsupportedPng;
            if (compression_method != 0 or filter_method != 0) return error.InvalidPng;
            if (interlace_method != 0) return error.UnsupportedPng;
            channels = switch (color_type) {
                0 => 1, // grayscale
                2 => 3, // truecolor
                4 => 2, // grayscale + alpha
                6 => 4, // truecolor + alpha
                else => return error.UnsupportedPng,
            };
            seen_ihdr = true;
        } else if (std.mem.eql(u8, chunk_type, "IDAT")) {
            if (!seen_ihdr or seen_iend) return error.InvalidPng;
            idat.appendSlice(allocator, chunk_data) catch return error.OutOfMemory;
        } else if (std.mem.eql(u8, chunk_type, "IEND")) {
            if (!seen_ihdr or seen_iend) return error.InvalidPng;
            if (chunk_data.len != 0) return error.InvalidPng;
            seen_iend = true;
            break;
        } else if (chunk_type[0] & 0x20 == 0) {
            // Unknown critical chunk: not safe to ignore.
            return error.UnsupportedPng;
        }
        // Ancillary chunks (lowercase first letter) are skipped.
        pos = crc_end;
    }
    if (!seen_ihdr) return error.InvalidPng;
    if (!seen_iend) return error.InvalidPng;
    if (idat.items.len == 0) return error.InvalidPng;

    const stride = std.math.mul(usize, width, channels) catch return error.InvalidPng;
    const filtered_row = std.math.add(usize, stride, 1) catch return error.InvalidPng;
    const raw_len = std.math.mul(usize, filtered_row, height) catch return error.InvalidPng;

    // `allocRemaining` reports `StreamTooLong` when the limit is reached, so
    // read raw_len + 1 bytes; anything past `raw_len` means corrupt input.
    const raw_limit = std.math.add(usize, raw_len, 1) catch return error.InvalidPng;

    var input: std.Io.Reader = .fixed(idat.items);
    var window: [flate.max_window_len]u8 = undefined;
    var decompress: flate.Decompress = .init(&input, .zlib, &window);
    const raw = decompress.reader.allocRemaining(allocator, .limited(raw_limit)) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.StreamTooLong, error.ReadFailed => return error.InvalidPng,
    };
    defer allocator.free(raw);
    if (raw.len != raw_len) return error.InvalidPng;

    const out_stride = std.math.mul(usize, width, 4) catch return error.InvalidPng;
    const out_len = std.math.mul(usize, out_stride, height) catch return error.InvalidPng;
    const out = allocator.alloc(u8, out_len) catch return error.OutOfMemory;
    errdefer allocator.free(out);

    var y: usize = 0;
    while (y < height) : (y += 1) {
        const row_start = y * filtered_row;
        const filter: u8 = raw[row_start];
        const row = raw[row_start + 1 ..][0..stride];
        const prev: ?[]const u8 = if (y == 0) null else raw[row_start - filtered_row + 1 ..][0..stride];
        try unfilterRow(filter, row, prev, channels);
        expandRow(out[y * out_stride ..][0..out_stride], row, channels);
    }

    return .{
        .width = width,
        .height = height,
        .data = out,
        .allocator = allocator,
    };
}

/// Filter each scanline (type 0) and zlib-compress the result.
fn compressScanlines(allocator: Allocator, width: u32, height: u32, rgba: []const u8) Error![]u8 {
    var out: std.Io.Writer.Allocating = std.Io.Writer.Allocating.initCapacity(allocator, 1024) catch
        return error.OutOfMemory;
    defer out.deinit();

    var window: [flate.max_window_len]u8 = undefined;
    var compress = flate.Compress.init(&out.writer, &window, .zlib, .default) catch return error.OutOfMemory;

    const stride = std.math.mul(usize, width, 4) catch return error.InvalidDimensions;
    var y: u32 = 0;
    while (y < height) : (y += 1) {
        compress.writer.writeByte(0) catch return error.OutOfMemory;
        const row = rgba[@as(usize, y) * stride ..][0..stride];
        compress.writer.writeAll(row) catch return error.OutOfMemory;
    }
    compress.finish() catch return error.OutOfMemory;

    return out.toOwnedSlice() catch return error.OutOfMemory;
}

/// Append one PNG chunk (`length`, `type`, `data`, `crc32(type ++ data)`).
fn writeChunk(
    allocator: Allocator,
    out: *std.ArrayList(u8),
    comptime chunk_type: *const [4]u8,
    data: []const u8,
) Error!void {
    if (data.len > std.math.maxInt(u32)) return error.InvalidDimensions;

    var crc = std.hash.Crc32.init();
    crc.update(chunk_type);
    crc.update(data);

    var header: [8]u8 = undefined;
    std.mem.writeInt(u32, header[0..4], @intCast(data.len), .big);
    header[4..8].* = chunk_type.*;

    var crc_bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &crc_bytes, crc.final(), .big);

    out.appendSlice(allocator, &header) catch return error.OutOfMemory;
    out.appendSlice(allocator, data) catch return error.OutOfMemory;
    out.appendSlice(allocator, &crc_bytes) catch return error.OutOfMemory;
}

/// Reverse one scanline filter in place. `row` is the filtered scanline,
/// which becomes the reconstructed (unfiltered) scanline; `prev` is the
/// already reconstructed scanline above it, when there is one. `bpp` is the
/// number of bytes per pixel (1 for 8-bit images).
fn unfilterRow(filter: u8, row: []u8, prev: ?[]const u8, bpp: usize) Error!void {
    switch (filter) {
        0 => {}, // None
        1 => { // Sub
            for (row, 0..) |*b, i| {
                if (i >= bpp) b.* +%= row[i - bpp];
            }
        },
        2 => { // Up
            if (prev) |p| {
                for (row, 0..) |*b, i| b.* +%= p[i];
            }
        },
        3 => { // Average
            for (row, 0..) |*b, i| {
                const left: u16 = if (i >= bpp) row[i - bpp] else 0;
                const up: u16 = if (prev) |p| p[i] else 0;
                b.* +%= @intCast((left + up) / 2);
            }
        },
        4 => { // Paeth
            for (row, 0..) |*b, i| {
                const left: i32 = if (i >= bpp) row[i - bpp] else 0;
                const up: i32 = if (prev) |p| p[i] else 0;
                const up_left: i32 = if (prev != null and i >= bpp) prev.?[i - bpp] else 0;
                b.* +%= paethPredictor(left, up, up_left);
            }
        },
        else => return error.InvalidPng,
    }
}

fn paethPredictor(a: i32, b: i32, c: i32) u8 {
    const p = a + b - c;
    const pa = @abs(p - a);
    const pb = @abs(p - b);
    const pc = @abs(p - c);
    if (pa <= pb and pa <= pc) return @intCast(a);
    if (pb <= pc) return @intCast(b);
    return @intCast(c);
}

/// Expand a reconstructed scanline of 1/2/3/4 channels to RGBA8.
fn expandRow(out: []u8, row: []const u8, channels: usize) void {
    const pixel_count = out.len / 4;
    switch (channels) {
        4 => @memcpy(out, row),
        3 => for (0..pixel_count) |i| {
            out[i * 4 + 0] = row[i * 3 + 0];
            out[i * 4 + 1] = row[i * 3 + 1];
            out[i * 4 + 2] = row[i * 3 + 2];
            out[i * 4 + 3] = 255;
        },
        2 => for (0..pixel_count) |i| {
            const gray = row[i * 2 + 0];
            out[i * 4 + 0] = gray;
            out[i * 4 + 1] = gray;
            out[i * 4 + 2] = gray;
            out[i * 4 + 3] = row[i * 2 + 1];
        },
        1 => for (0..pixel_count) |i| {
            const gray = row[i];
            out[i * 4 + 0] = gray;
            out[i * 4 + 1] = gray;
            out[i * 4 + 2] = gray;
            out[i * 4 + 3] = 255;
        },
        else => unreachable,
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "encode/decode round-trips a synthetic 3x2 RGBA image" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const width = 3;
    const height = 2;
    const pixels = [_]u8{
        255, 0, 0, 255, // opaque red
        0, 255, 0, 128, // half green
        0,  0,  255, 0, // transparent blue
        10, 20, 30,  255,
        40, 50, 60,  200,
        70, 80, 90,  1,
    };

    const png = try encodeAlloc(allocator, width, height, &pixels);
    defer allocator.free(png);

    try testing.expectEqualSlices(u8, &signature, png[0..signature.len]);

    var image = try decodeAlloc(allocator, png);
    defer image.deinit();

    try testing.expectEqual(@as(u32, width), image.width);
    try testing.expectEqual(@as(u32, height), image.height);
    try testing.expectEqualSlices(u8, &pixels, image.data);
}

test "decode reads a checked-in baseline PNG" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const bytes = try std.Io.Dir.cwd().readFileAlloc(
        std.testing.io,
        "tests/images/an_arabic_word.png",
        allocator,
        .limited(1 << 24),
    );
    defer allocator.free(bytes);

    var image = try decodeAlloc(allocator, bytes);
    defer image.deinit();

    try testing.expect(image.width > 0);
    try testing.expect(image.height > 0);
    try testing.expectEqual(
        @as(usize, image.width) * @as(usize, image.height) * 4,
        image.data.len,
    );
}

test "decode rejects garbage and truncated input" {
    const testing = std.testing;
    const allocator = testing.allocator;

    try testing.expectError(error.InvalidPng, decodeAlloc(allocator, &[_]u8{}));
    try testing.expectError(error.InvalidPng, decodeAlloc(allocator, "this is not a png file at all"));
    try testing.expectError(error.InvalidPng, decodeAlloc(allocator, &signature));
    try testing.expectError(error.InvalidPng, decodeAlloc(allocator, &(signature ++ @as([16]u8, @splat(0)))));

    const pixels = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
    const png = try encodeAlloc(allocator, 2, 1, &pixels);
    defer allocator.free(png);
    try testing.expectError(error.InvalidPng, decodeAlloc(allocator, png[0 .. png.len / 2]));
    try testing.expectError(error.InvalidPng, decodeAlloc(allocator, png[0 .. png.len - 1]));
}

test "decode rejects CRC-corrupted chunks" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const pixels = [_]u8{ 255, 0, 0, 255 };
    const encoded = try encodeAlloc(allocator, 1, 1, &pixels);
    defer allocator.free(encoded);

    // Flip a byte inside the IDAT payload; the chunk CRC must catch it.
    const idat = std.mem.indexOf(u8, encoded, "IDAT") orelse return error.TestUnexpectedResult;
    const corrupted = try allocator.dupe(u8, encoded);
    defer allocator.free(corrupted);
    corrupted[idat + 4 + 2] ^= 0xFF;
    try testing.expectError(error.InvalidPng, decodeAlloc(allocator, corrupted));
}

test "decode handles RGB, gray, gray+alpha and all scanline filters" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const width = 3;
    const height = 5;
    const pixels = [_]u8{
        255, 0,   0,  255, 0,  255, 0,   200, 0,  0,  255, 255,
        1,   2,   3,  4,   5,  6,   7,   8,   9,  10, 11,  12,
        200, 100, 50, 255, 25, 75,  125, 175, 0,  0,  0,   0,
        9,   9,   9,  9,   8,  7,   6,   5,   4,  3,  2,   1,
        17,  18,  19, 20,  21, 22,  23,  24,  25, 26, 27,  28,
    };

    const rgb_pixels = [_]u8{
        255, 0,   0,
        0,   255, 0,
        0,   0,   255,
        12,  34,  56,
        78,  90,  123,
        200, 100, 50,
    };

    const gray_pixels = [_]u8{ 0, 64, 128, 200, 255, 7 };
    const gray_alpha_pixels = [_]u8{ 0, 0, 64, 128, 200, 255, 255, 7 };

    // Build a filtered + zlib-compressed scanline stream for each layout and
    // split the compressed bytes across two IDAT chunks.
    const filtered_rgba = try filterAll(allocator, &pixels, width, height, 4);
    defer allocator.free(filtered_rgba);
    const zlib_rgba = try testZlib(allocator, filtered_rgba);
    defer allocator.free(zlib_rgba);
    const png_rgba = try testBuildPng(allocator, width, height, 6, zlib_rgba);
    defer allocator.free(png_rgba);

    const filtered_rgb = try filterAll(allocator, &rgb_pixels, 3, 2, 3);
    defer allocator.free(filtered_rgb);
    const zlib_rgb = try testZlib(allocator, filtered_rgb);
    defer allocator.free(zlib_rgb);
    const png_rgb = try testBuildPng(allocator, 3, 2, 2, zlib_rgb);
    defer allocator.free(png_rgb);

    const filtered_gray = try filterAll(allocator, &gray_pixels, 3, 2, 1);
    defer allocator.free(filtered_gray);
    const zlib_gray = try testZlib(allocator, filtered_gray);
    defer allocator.free(zlib_gray);
    const png_gray = try testBuildPng(allocator, 3, 2, 0, zlib_gray);
    defer allocator.free(png_gray);

    const filtered_ga = try filterAll(allocator, &gray_alpha_pixels, 2, 2, 2);
    defer allocator.free(filtered_ga);
    const zlib_ga = try testZlib(allocator, filtered_ga);
    defer allocator.free(zlib_ga);
    const png_ga = try testBuildPng(allocator, 2, 2, 4, zlib_ga);
    defer allocator.free(png_ga);

    var image = try decodeAlloc(allocator, png_rgba);
    defer image.deinit();
    try testing.expectEqualSlices(u8, &pixels, image.data);

    var image_rgb = try decodeAlloc(allocator, png_rgb);
    defer image_rgb.deinit();
    try testing.expectEqual(@as(u32, 3), image_rgb.width);
    try testing.expectEqual(@as(u32, 2), image_rgb.height);
    try testing.expectEqualSlices(u8, &[_]u8{
        255, 0,   0,   255,
        0,   255, 0,   255,
        0,   0,   255, 255,
        12,  34,  56,  255,
        78,  90,  123, 255,
        200, 100, 50,  255,
    }, image_rgb.data);

    var image_gray = try decodeAlloc(allocator, png_gray);
    defer image_gray.deinit();
    try testing.expectEqualSlices(u8, &[_]u8{
        0,   0,   0,   255,
        64,  64,  64,  255,
        128, 128, 128, 255,
        200, 200, 200, 255,
        255, 255, 255, 255,
        7,   7,   7,   255,
    }, image_gray.data);

    var image_ga = try decodeAlloc(allocator, png_ga);
    defer image_ga.deinit();
    try testing.expectEqualSlices(u8, &[_]u8{
        0,   0,   0,   0,
        64,  64,  64,  128,
        200, 200, 200, 255,
        255, 255, 255, 7,
    }, image_ga.data);
}

/// Test helper: build the filtered scanline stream, applying filter type
/// `y % 5` to row `y` (so a 5-row image exercises every filter).
fn filterAll(allocator: Allocator, pixels: []const u8, width: u32, height: u32, channels: usize) ![]u8 {
    const stride = @as(usize, width) * channels;
    const out = try allocator.alloc(u8, (stride + 1) * height);
    errdefer allocator.free(out);
    for (0..height) |y| {
        const filter: u8 = @intCast(y % 5);
        out[y * (stride + 1)] = filter;
        const dst = out[y * (stride + 1) + 1 ..][0..stride];
        const cur = pixels[y * stride ..][0..stride];
        const prev: ?[]const u8 = if (y == 0) null else pixels[(y - 1) * stride ..][0..stride];
        for (cur, 0..) |v, i| {
            const left: u8 = if (i >= channels) cur[i - channels] else 0;
            const up: u8 = if (prev) |p| p[i] else 0;
            const up_left: u8 = if (prev != null and i >= channels) prev.?[i - channels] else 0;
            dst[i] = switch (filter) {
                0 => v,
                1 => v -% left,
                2 => v -% up,
                3 => v -% @as(u8, @intCast((@as(u16, left) + up) / 2)),
                4 => v -% testPaeth(left, up, up_left),
                else => unreachable,
            };
        }
    }
    return out;
}

fn testPaeth(a: u8, b: u8, c: u8) u8 {
    const p = @as(i32, a) + @as(i32, b) - @as(i32, c);
    const pa = @abs(p - @as(i32, a));
    const pb = @abs(p - @as(i32, b));
    const pc = @abs(p - @as(i32, c));
    if (pa <= pb and pa <= pc) return a;
    if (pb <= pc) return b;
    return c;
}

fn testZlib(allocator: Allocator, raw: []const u8) ![]u8 {
    var out: std.Io.Writer.Allocating = try .initCapacity(allocator, raw.len + 64);
    defer out.deinit();
    var window: [flate.max_window_len]u8 = undefined;
    var compress = try flate.Compress.init(&out.writer, &window, .zlib, .default);
    try compress.writer.writeAll(raw);
    try compress.finish();
    return out.toOwnedSlice();
}

fn testBuildPng(
    allocator: Allocator,
    width: u32,
    height: u32,
    color_type: u8,
    zlib_data: []const u8,
) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try out.appendSlice(allocator, &signature);

    var ihdr: [13]u8 = undefined;
    std.mem.writeInt(u32, ihdr[0..4], width, .big);
    std.mem.writeInt(u32, ihdr[4..8], height, .big);
    ihdr[8] = 8;
    ihdr[9] = color_type;
    ihdr[10] = 0;
    ihdr[11] = 0;
    ihdr[12] = 0;
    try testChunk(allocator, &out, "IHDR", &ihdr);

    // Two IDAT chunks exercise multi-chunk concatenation.
    const split = zlib_data.len / 2;
    if (split == 0) {
        try testChunk(allocator, &out, "IDAT", zlib_data);
    } else {
        try testChunk(allocator, &out, "IDAT", zlib_data[0..split]);
        try testChunk(allocator, &out, "IDAT", zlib_data[split..]);
    }
    try testChunk(allocator, &out, "IEND", &.{});
    return out.toOwnedSlice(allocator);
}

fn testChunk(allocator: Allocator, out: *std.ArrayList(u8), comptime chunk_type: *const [4]u8, data: []const u8) !void {
    var crc = std.hash.Crc32.init();
    crc.update(chunk_type);
    crc.update(data);
    var header: [8]u8 = undefined;
    std.mem.writeInt(u32, header[0..4], @intCast(data.len), .big);
    header[4..8].* = chunk_type.*;
    var crc_bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &crc_bytes, crc.final(), .big);
    try out.appendSlice(allocator, &header);
    try out.appendSlice(allocator, data);
    try out.appendSlice(allocator, &crc_bytes);
}
