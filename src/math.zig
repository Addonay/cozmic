//! Float helpers for layout math.
//!
//! Port of cosmic-text `math.rs`. The Rust source selects `libm` without
//! the `std` feature and `f32` methods with it; Zig's `std.math` covers
//! both, so these thin wrappers delegate to it.

const std = @import("std");

/// Round toward negative infinity, matching Rust's `f32::floor`/`libm::floorf`.
pub inline fn floorf(x: f32) f32 {
    return std.math.floor(x);
}

/// Round away from zero on half values, matching Rust's `f32::round`/
/// `libm::roundf`.
pub inline fn roundf(x: f32) f32 {
    return std.math.round(x);
}

/// Round toward zero, matching Rust's `f32::trunc`/`libm::truncf`.
pub inline fn truncf(x: f32) f32 {
    return std.math.trunc(x);
}

test "floorf rounds toward negative infinity" {
    const testing = std.testing;

    try testing.expectEqual(@as(f32, 1), floorf(1.0));
    try testing.expectEqual(@as(f32, 1), floorf(1.5));
    try testing.expectEqual(@as(f32, 1), floorf(1.9));
    try testing.expectEqual(@as(f32, -2), floorf(-1.5));
    try testing.expectEqual(@as(f32, -2), floorf(-1.1));
    try testing.expectEqual(@as(f32, 0), floorf(0.0));
    try testing.expectEqual(@as(f32, -1), floorf(-0.1));
    try testing.expectEqual(@as(f32, 2), floorf(2.0));
}

test "roundf rounds half away from zero" {
    const testing = std.testing;

    try testing.expectEqual(@as(f32, 0), roundf(0.0));
    try testing.expectEqual(@as(f32, 1), roundf(0.5));
    try testing.expectEqual(@as(f32, -1), roundf(-0.5));
    try testing.expectEqual(@as(f32, 2), roundf(1.5));
    try testing.expectEqual(@as(f32, -2), roundf(-1.5));
    try testing.expectEqual(@as(f32, 2), roundf(1.6));
    try testing.expectEqual(@as(f32, 1), roundf(1.4));
    try testing.expectEqual(@as(f32, -1), roundf(-1.4));
    try testing.expectEqual(@as(f32, 3), roundf(2.5));
    try testing.expectEqual(@as(f32, -3), roundf(-2.5));
}

test "truncf rounds toward zero" {
    const testing = std.testing;

    try testing.expectEqual(@as(f32, 1), truncf(1.9));
    try testing.expectEqual(@as(f32, -1), truncf(-1.9));
    try testing.expectEqual(@as(f32, 1), truncf(1.5));
    try testing.expectEqual(@as(f32, -1), truncf(-1.5));
    try testing.expectEqual(@as(f32, 0), truncf(0.7));
    try testing.expectEqual(@as(f32, 0), truncf(-0.7));
    try testing.expectEqual(@as(f32, 0), truncf(0.0));
    try testing.expectEqual(@as(f32, 123), truncf(123.456));
}

test "math parity with builtins over a value sweep" {
    const testing = std.testing;

    const values = [_]f32{
        0.0,            -0.0,            0.25,         -0.25,         0.5,   -0.5,
        0.75,           -0.75,           1.0,          -1.0,          1.5,   -1.5,
        2.5,            -2.5,            100.25,       -100.75,       0.1,   -0.1,
        999.99,         -999.99,         1e10,         -1e10,         1e-10, -1e-10,
        // Large magnitudes near `f32` max (3.4028235e38) and subnormals.
        1e38,           -1e38,           3.4028235e38, -3.4028235e38, 1e-40, -1e-40,
        1.40129846e-45, -1.40129846e-45,
    };
    for (values) |v| {
        try testing.expectEqual(@floor(v), floorf(v));
        try testing.expectEqual(@round(v), roundf(v));
        try testing.expectEqual(@trunc(v), truncf(v));
    }

    // Signed zero is preserved bit-for-bit like the builtins/Rust methods.
    try testing.expectEqual(@as(u32, @bitCast(@as(f32, -0.0))), @as(u32, @bitCast(floorf(-0.0))));
    try testing.expectEqual(@as(u32, @bitCast(@as(f32, -0.0))), @as(u32, @bitCast(truncf(-0.0))));
    try testing.expectEqual(@as(u32, @bitCast(@as(f32, 0.0))), @as(u32, @bitCast(floorf(0.0))));

    // Subnormals truncate/floor/round without flushing surprises.
    const sub_pos: f32 = 1.40129846e-45; // smallest positive subnormal
    const sub_neg: f32 = -1.40129846e-45;
    try testing.expectEqual(@trunc(sub_pos), truncf(sub_pos));
    try testing.expectEqual(@trunc(sub_neg), truncf(sub_neg));
    try testing.expectEqual(@floor(sub_pos), floorf(sub_pos));

    // Infinities pass through like the Rust methods.
    try testing.expectEqual(std.math.inf(f32), floorf(std.math.inf(f32)));
    try testing.expectEqual(-std.math.inf(f32), floorf(-std.math.inf(f32)));
    try testing.expectEqual(std.math.inf(f32), roundf(std.math.inf(f32)));
    try testing.expectEqual(std.math.inf(f32), truncf(std.math.inf(f32)));

    // NaN propagates.
    try testing.expect(std.math.isNan(floorf(std.math.nan(f32))));
    try testing.expect(std.math.isNan(roundf(std.math.nan(f32))));
    try testing.expect(std.math.isNan(truncf(std.math.nan(f32))));
}
