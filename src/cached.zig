//! Generic cache-state container.
//!
//! Port of cosmic-text `cached.rs`. Self-contained; depends only on `std`
//! (for tests).
//!
//! `Cached(T)` works for any `T`, including heap-owned values such as the
//! future `ShapeLine` or `std.ArrayList(LayoutLine)`. It never allocates and
//! never frees: taking a value moves ownership to the caller, and storing a
//! value moves ownership into the cache. Callers holding owned values must
//! `takeUnused`/`takeUsed` (and clean up) before overwriting with `setUsed`.

const std = @import("std");

/// Helper for caching a value that is optionally present in the `unused`
/// state. Mirrors Rust's `Cached<T>` states `Empty`/`Unused`/`Used`.
pub fn Cached(comptime T: type) type {
    return union(enum) {
        empty,
        unused: T,
        used: T,

        const Self = @This();

        /// Get the value if in state `used`, else `null`.
        pub fn get(self: *const Self) ?*const T {
            return if (self.* == .used) &self.used else null;
        }

        /// Get the value mutably if in state `used`, else `null`.
        pub fn getMut(self: *Self) ?*T {
            return if (self.* == .used) &self.used else null;
        }

        /// Check if the value is empty (no owned value held).
        pub fn isEmpty(self: *const Self) bool {
            return self.* == .empty;
        }

        /// Check if the value is empty or unused.
        pub fn isUnused(self: *const Self) bool {
            return self.* == .empty or self.* == .unused;
        }

        /// Check if the value is used (cached for access).
        pub fn isUsed(self: *const Self) bool {
            return self.* == .used;
        }

        /// Check if the value was previously cached but invalidated.
        pub fn isInvalidated(self: *const Self) bool {
            return self.* == .unused;
        }

        /// Take the buffered value if in state `unused`, leaving `empty`.
        pub fn takeUnused(self: *Self) ?T {
            if (self.* != .unused) return null;
            const val = self.unused;
            self.* = .empty;
            return val;
        }

        /// Take the cached value if in state `used`, leaving `empty`.
        pub fn takeUsed(self: *Self) ?T {
            if (self.* != .used) return null;
            const val = self.used;
            self.* = .empty;
            return val;
        }

        /// Move the value from `used` to `unused`; no-op otherwise.
        pub fn setUnused(self: *Self) void {
            if (self.takeUsed()) |val| {
                self.* = .{ .unused = val };
            }
        }

        /// Store `val` in state `used`.
        ///
        /// Callers must take (and clean up, if owned) any previous value
        /// first; this function cannot drop a previous owned value and would
        /// leak heap-owned `T` (e.g. `ArrayList`) if it overwrote one.
        /// Debug-asserts `isEmpty` to catch such leaks in tests; release
        /// overwrites (matching Rust `set_used`, which drops the old value).
        pub fn setUsed(self: *Self, val: T) void {
            std.debug.assert(self.isEmpty());
            self.* = .{ .used = val };
        }
    };
}

test "cached empty state" {
    const testing = std.testing;

    var c: Cached(u32) = .empty;
    try testing.expect(c.isEmpty());
    try testing.expect(c.get() == null);
    try testing.expect(c.getMut() == null);
    try testing.expect(c.isUnused());
    try testing.expect(!c.isUsed());
    try testing.expect(!c.isInvalidated());
    try testing.expect(c.takeUnused() == null);
    try testing.expect(c.takeUsed() == null);

    // setUnused on empty is a no-op and stays empty.
    c.setUnused();
    try testing.expect(c.isEmpty());
    try testing.expect(c.isUnused());
    try testing.expect(!c.isInvalidated());
    try testing.expect(c.takeUnused() == null);
}

test "cached used state" {
    const testing = std.testing;

    var c: Cached(u32) = .empty;
    c.setUsed(5);
    try testing.expect(c.isUsed());
    try testing.expect(!c.isUnused());
    try testing.expect(!c.isInvalidated());

    try testing.expectEqual(@as(u32, 5), c.get().?.*);
    c.getMut().?.* = 6;
    try testing.expectEqual(@as(u32, 6), c.get().?.*);

    // Wrong-state take fails and preserves the value.
    try testing.expect(c.takeUnused() == null);
    try testing.expect(c.isUsed());
    try testing.expectEqual(@as(u32, 6), c.get().?.*);

    // Overwriting requires take-then-set (prevents leaking owned values).
    try testing.expect(c.isEmpty() == false);
    try testing.expectEqual(@as(u32, 6), c.takeUsed().?);
    try testing.expect(c.isEmpty());
    c.setUsed(7);
    try testing.expectEqual(@as(u32, 7), c.get().?.*);
}

test "cached full lifecycle" {
    const testing = std.testing;

    var c: Cached(u32) = .empty;
    c.setUsed(1);
    c.setUnused();

    // used -> unused: hidden from get, flagged invalidated.
    try testing.expect(c.get() == null);
    try testing.expect(c.getMut() == null);
    try testing.expect(c.isUnused());
    try testing.expect(!c.isUsed());
    try testing.expect(c.isInvalidated());

    // setUnused on unused is a no-op and keeps the value.
    c.setUnused();
    try testing.expect(c.isInvalidated());

    // takeUnused recovers the value and resets to empty.
    try testing.expectEqual(@as(u32, 1), c.takeUnused().?);
    try testing.expect(c.isUnused());
    try testing.expect(!c.isInvalidated());
    try testing.expect(c.takeUnused() == null);

    // takeUsed path also resets to empty.
    c.setUsed(2);
    try testing.expectEqual(@as(u32, 2), c.takeUsed().?);
    try testing.expect(c.get() == null);
    try testing.expect(!c.isUsed());
    try testing.expect(!c.isInvalidated());
    try testing.expect(c.takeUsed() == null);
}

test "cached is generic over structs" {
    const testing = std.testing;

    const Point = struct {
        x: f32,
        y: f32,
    };

    var c: Cached(Point) = .empty;
    try testing.expect(c.isUnused());
    c.setUsed(.{ .x = 1.5, .y = -2.5 });
    try testing.expect(c.isUsed());
    try testing.expectEqual(@as(f32, 1.5), c.get().?.x);
    c.setUnused();
    try testing.expect(c.isInvalidated());
    const p = c.takeUnused().?;
    try testing.expectEqual(@as(f32, 1.5), p.x);
    try testing.expectEqual(@as(f32, -2.5), p.y);
    try testing.expect(!c.isInvalidated());
}

test "cached is generic over heap-owned vectors" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Stand-in for a future `ArrayList(LayoutLine)`: proves Cached moves
    // heap ownership through unused/used without leaking or copying.
    var c: Cached(std.ArrayList(u8)) = .empty;

    var list: std.ArrayList(u8) = .empty;
    try list.appendSlice(allocator, "hello");
    c.setUsed(list);
    try testing.expect(c.isUsed());
    try testing.expectEqualStrings("hello", c.get().?.items);

    c.setUnused();
    try testing.expect(c.isInvalidated());

    var recovered = c.takeUnused().?;
    defer recovered.deinit(allocator);
    try testing.expectEqualStrings("hello", recovered.items);
    try testing.expect(!c.isInvalidated());

    // Take the used path too, with cleanup.
    var list2: std.ArrayList(u8) = .empty;
    try list2.appendSlice(allocator, "world");
    c.setUsed(list2);
    var recovered2 = c.takeUsed().?;
    defer recovered2.deinit(allocator);
    try testing.expectEqualStrings("world", recovered2.items);
    try testing.expect(c.get() == null);
}
