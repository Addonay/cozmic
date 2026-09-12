//! Port of cosmic-text `glyph_cache.rs` (subpixel binning + cache key).
//!
//! Canonical flags: `attrs.CacheKeyFlags` (re-exported here for the cache
//! API). `FontId` is still a `u32` alias, matching `fontdb::ID`.
//!
//! Thresholds in `SubpixelBin.new` are verbatim from cosmic-text
//! (sign-aware `.125/.375/.625/.875` bins).

const std = @import("std");
const attrs = @import("attrs.zig");

/// Placeholder font identifier (matches `fontdb::ID`).
/// Local alias only; unify with the font modules later.
pub const FontId = u32;

/// Font weight value (matches `fontdb::Weight`, normal = 400).
/// Local alias only; unify with `attrs.zig` later.
pub const Weight = u16;
pub const WEIGHT_NORMAL: Weight = 400;

/// Flags that change rendering (canonical owner: `attrs.zig`).
pub const CacheKeyFlags = attrs.CacheKeyFlags;

/// Binning of subpixel position for cache optimization.
///
/// Verbatim from cosmic-text: four bins at `.0/.25/.5/.75`
/// with sign-aware `.125/.375/.625/.875` thresholds.
pub const SubpixelBin = enum(u8) {
    zero = 0,
    one = 1,
    two = 2,
    three = 3,

    pub const BinResult = struct {
        pos: i32,
        bin: SubpixelBin,
    };

    /// Split `pos` into an integer part and a subpixel bin.
    ///
    /// Matches `SubpixelBin::new` exactly, including `-0.0` handling
    /// (`is_sign_negative`) and the `trunc + 1` carry at `>= .875`.
    pub fn new(pos: f32) BinResult {
        const trunc = truncToI32(pos);
        const fract: f32 = pos - @as(f32, @floatFromInt(trunc));
        if (isSignNegative(pos)) {
            if (fract > -0.125) {
                return .{ .pos = trunc, .bin = .zero };
            } else if (fract > -0.375) {
                return .{ .pos = saturatingSub(trunc, 1), .bin = .three };
            } else if (fract > -0.625) {
                return .{ .pos = saturatingSub(trunc, 1), .bin = .two };
            } else if (fract > -0.875) {
                return .{ .pos = saturatingSub(trunc, 1), .bin = .one };
            } else {
                return .{ .pos = saturatingSub(trunc, 1), .bin = .zero };
            }
        } else {
            if (fract < 0.125) {
                return .{ .pos = trunc, .bin = .zero };
            } else if (fract < 0.375) {
                return .{ .pos = trunc, .bin = .one };
            } else if (fract < 0.625) {
                return .{ .pos = trunc, .bin = .two };
            } else if (fract < 0.875) {
                return .{ .pos = trunc, .bin = .three };
            } else {
                return .{ .pos = saturatingAdd(trunc, 1), .bin = .zero };
            }
        }
    }

    pub fn asFloat(self: SubpixelBin) f32 {
        return switch (self) {
            .zero => 0.0,
            .one => 0.25,
            .two => 0.5,
            .three => 0.75,
        };
    }
};

fn isSignNegative(v: f32) bool {
    return (@as(u32, @bitCast(v)) >> 31) == 1;
}

fn truncToI32(v: f32) i32 {
    if (std.math.isNan(v)) return 0;
    const t = @trunc(v);
    const max: f32 = @floatFromInt(std.math.maxInt(i32));
    const min: f32 = @floatFromInt(std.math.minInt(i32));
    if (t >= max) return std.math.maxInt(i32);
    if (t <= min) return std.math.minInt(i32);
    return @intFromFloat(t);
}

fn saturatingAdd(a: i32, b: i32) i32 {
    return std.math.add(i32, a, b) catch {
        if (b >= 0) return std.math.maxInt(i32);
        return std.math.minInt(i32);
    };
}

fn saturatingSub(a: i32, b: i32) i32 {
    return std.math.sub(i32, a, b) catch {
        if (b >= 0) return std.math.minInt(i32);
        return std.math.maxInt(i32);
    };
}

/// Key for building a glyph cache (mirrors `CacheKey` field-for-field).
pub const CacheKey = struct {
    font_id: FontId,
    glyph_id: u16,
    font_size_bits: u32,
    x_bin: SubpixelBin,
    y_bin: SubpixelBin,
    font_weight: Weight,
    flags: CacheKeyFlags,

    pub const NewResult = struct {
        key: CacheKey,
        x: i32,
        y: i32,
    };

    /// Build a key from a subpixel position, returning the key plus the
    /// integer (physical) offsets. Mirrors `CacheKey::new`.
    pub fn new(
        font_id: FontId,
        glyph_id: u16,
        font_size: f32,
        pos: struct { x: f32, y: f32 },
        weight: Weight,
        flags: CacheKeyFlags,
    ) NewResult {
        const xb = SubpixelBin.new(pos.x);
        const yb = SubpixelBin.new(pos.y);
        return .{
            .key = .{
                .font_id = font_id,
                .glyph_id = glyph_id,
                .font_size_bits = @bitCast(font_size),
                .x_bin = xb.bin,
                .y_bin = yb.bin,
                .font_weight = weight,
                .flags = flags,
            },
            .x = xb.pos,
            .y = yb.pos,
        };
    }

    pub fn fontSize(self: CacheKey) f32 {
        return @bitCast(self.font_size_bits);
    }

    pub fn eql(a: CacheKey, b: CacheKey) bool {
        return a.font_id == b.font_id and
            a.glyph_id == b.glyph_id and
            a.font_size_bits == b.font_size_bits and
            a.x_bin == b.x_bin and
            a.y_bin == b.y_bin and
            a.font_weight == b.font_weight and
            CacheKeyFlags.eql(a.flags, b.flags);
    }

    pub fn lessThan(a: CacheKey, b: CacheKey) bool {
        if (a.font_id != b.font_id) return a.font_id < b.font_id;
        if (a.glyph_id != b.glyph_id) return a.glyph_id < b.glyph_id;
        if (a.font_size_bits != b.font_size_bits) return a.font_size_bits < b.font_size_bits;
        if (a.x_bin != b.x_bin) return @backingInt(a.x_bin) < @backingInt(b.x_bin);
        if (a.y_bin != b.y_bin) return @backingInt(a.y_bin) < @backingInt(b.y_bin);
        if (a.font_weight != b.font_weight) return a.font_weight < b.font_weight;
        return CacheKeyFlags.lessThan(a.flags, b.flags);
    }

    pub fn hash(self: CacheKey) u64 {
        var h = std.hash.Wyhash.init(0);
        h.update(std.mem.asBytes(&self.font_id));
        h.update(std.mem.asBytes(&self.glyph_id));
        h.update(std.mem.asBytes(&self.font_size_bits));
        const xb: u8 = @backingInt(self.x_bin);
        const yb: u8 = @backingInt(self.y_bin);
        h.update(std.mem.asBytes(&xb));
        h.update(std.mem.asBytes(&yb));
        h.update(std.mem.asBytes(&self.font_weight));
        h.update(std.mem.asBytes(&self.flags.bits));
        return h.final();
    }
};

test "subpixel bins positive" {
    const t = std.testing;
    try t.expectEqualDeep(SubpixelBin.BinResult{ .pos = 0, .bin = .zero }, SubpixelBin.new(0.0));
    try t.expectEqualDeep(SubpixelBin.BinResult{ .pos = 0, .bin = .zero }, SubpixelBin.new(0.124));
    try t.expectEqualDeep(SubpixelBin.BinResult{ .pos = 0, .bin = .one }, SubpixelBin.new(0.125));
    try t.expectEqualDeep(SubpixelBin.BinResult{ .pos = 0, .bin = .one }, SubpixelBin.new(0.25));
    try t.expectEqualDeep(SubpixelBin.BinResult{ .pos = 0, .bin = .one }, SubpixelBin.new(0.374));
    try t.expectEqualDeep(SubpixelBin.BinResult{ .pos = 0, .bin = .two }, SubpixelBin.new(0.375));
    try t.expectEqualDeep(SubpixelBin.BinResult{ .pos = 0, .bin = .two }, SubpixelBin.new(0.5));
    try t.expectEqualDeep(SubpixelBin.BinResult{ .pos = 0, .bin = .two }, SubpixelBin.new(0.624));
    try t.expectEqualDeep(SubpixelBin.BinResult{ .pos = 0, .bin = .three }, SubpixelBin.new(0.625));
    try t.expectEqualDeep(SubpixelBin.BinResult{ .pos = 0, .bin = .three }, SubpixelBin.new(0.75));
    try t.expectEqualDeep(SubpixelBin.BinResult{ .pos = 0, .bin = .three }, SubpixelBin.new(0.874));
    try t.expectEqualDeep(SubpixelBin.BinResult{ .pos = 1, .bin = .zero }, SubpixelBin.new(0.875));
    try t.expectEqualDeep(SubpixelBin.BinResult{ .pos = 1, .bin = .zero }, SubpixelBin.new(0.999));
    try t.expectEqualDeep(SubpixelBin.BinResult{ .pos = 1, .bin = .zero }, SubpixelBin.new(1.0));
    try t.expectEqualDeep(SubpixelBin.BinResult{ .pos = 1, .bin = .zero }, SubpixelBin.new(1.124));
}

test "subpixel bins negative" {
    const t = std.testing;
    try t.expectEqualDeep(SubpixelBin.BinResult{ .pos = 0, .bin = .zero }, SubpixelBin.new(-0.0));
    try t.expectEqualDeep(SubpixelBin.BinResult{ .pos = 0, .bin = .zero }, SubpixelBin.new(-0.124));
    try t.expectEqualDeep(SubpixelBin.BinResult{ .pos = -1, .bin = .three }, SubpixelBin.new(-0.125));
    try t.expectEqualDeep(SubpixelBin.BinResult{ .pos = -1, .bin = .three }, SubpixelBin.new(-0.25));
    try t.expectEqualDeep(SubpixelBin.BinResult{ .pos = -1, .bin = .three }, SubpixelBin.new(-0.374));
    try t.expectEqualDeep(SubpixelBin.BinResult{ .pos = -1, .bin = .two }, SubpixelBin.new(-0.375));
    try t.expectEqualDeep(SubpixelBin.BinResult{ .pos = -1, .bin = .two }, SubpixelBin.new(-0.5));
    try t.expectEqualDeep(SubpixelBin.BinResult{ .pos = -1, .bin = .two }, SubpixelBin.new(-0.624));
    try t.expectEqualDeep(SubpixelBin.BinResult{ .pos = -1, .bin = .one }, SubpixelBin.new(-0.625));
    try t.expectEqualDeep(SubpixelBin.BinResult{ .pos = -1, .bin = .one }, SubpixelBin.new(-0.75));
    try t.expectEqualDeep(SubpixelBin.BinResult{ .pos = -1, .bin = .one }, SubpixelBin.new(-0.874));
    try t.expectEqualDeep(SubpixelBin.BinResult{ .pos = -1, .bin = .zero }, SubpixelBin.new(-0.875));
    try t.expectEqualDeep(SubpixelBin.BinResult{ .pos = -1, .bin = .zero }, SubpixelBin.new(-0.999));
    try t.expectEqualDeep(SubpixelBin.BinResult{ .pos = -1, .bin = .zero }, SubpixelBin.new(-1.0));
    try t.expectEqualDeep(SubpixelBin.BinResult{ .pos = -1, .bin = .zero }, SubpixelBin.new(-1.124));
}

test "subpixel bin float values" {
    const t = std.testing;
    try t.expectEqual(@as(f32, 0.0), SubpixelBin.zero.asFloat());
    try t.expectEqual(@as(f32, 0.25), SubpixelBin.one.asFloat());
    try t.expectEqual(@as(f32, 0.5), SubpixelBin.two.asFloat());
    try t.expectEqual(@as(f32, 0.75), SubpixelBin.three.asFloat());
}

test "cache key physical int frac split" {
    const t = std.testing;
    const r = CacheKey.new(7, 42, 16.0, .{ .x = 10.7, .y = 20.9 }, WEIGHT_NORMAL, .{});
    // 10.7 -> fract .7 in [0.625, 0.875) => bin three, int 10.
    // 20.9 -> fract .9 >= .875 => carry to 21, bin zero.
    try t.expectEqual(@as(i32, 10), r.x);
    try t.expectEqual(@as(i32, 21), r.y);
    try t.expectEqual(SubpixelBin.three, r.key.x_bin);
    try t.expectEqual(SubpixelBin.zero, r.key.y_bin);
    try t.expectEqual(@as(FontId, 7), r.key.font_id);
    try t.expectEqual(@as(u16, 42), r.key.glyph_id);
    try t.expectEqual(@as(f32, 16.0), r.key.fontSize());

    const neg = CacheKey.new(0, 0, 12.0, .{ .x = -0.25, .y = -0.5 }, WEIGHT_NORMAL, .{});
    try t.expectEqual(@as(i32, -1), neg.x);
    try t.expectEqual(@as(i32, -1), neg.y);
    try t.expectEqual(SubpixelBin.three, neg.key.x_bin);
    try t.expectEqual(SubpixelBin.two, neg.key.y_bin);
}

test "cache key flags and ordering" {
    const t = std.testing;
    try t.expect(CacheKeyFlags.FAKE_ITALIC.contains(CacheKeyFlags.FAKE_ITALIC));
    try t.expect(!CacheKeyFlags.empty().contains(CacheKeyFlags.FAKE_ITALIC));
    const merged = CacheKeyFlags.FAKE_ITALIC.merge(CacheKeyFlags.DISABLE_HINTING);
    try t.expect(merged.contains(CacheKeyFlags.FAKE_ITALIC));
    try t.expect(merged.contains(CacheKeyFlags.DISABLE_HINTING));
    try t.expect(!merged.contains(CacheKeyFlags.PIXEL_FONT));

    const a = CacheKey.new(1, 1, 16.0, .{ .x = 0, .y = 0 }, 400, .{});
    const b = CacheKey.new(1, 2, 16.0, .{ .x = 0, .y = 0 }, 400, .{});
    try t.expect(CacheKey.eql(a.key, a.key));
    try t.expect(!CacheKey.eql(a.key, b.key));
    try t.expect(CacheKey.lessThan(a.key, b.key));
    try t.expect(!CacheKey.lessThan(b.key, a.key));
}
