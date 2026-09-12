//! Port of cosmic-text `shape_run_cache.rs` (49 lines).
//!
//! Key equality is canonical: `KeyOwned` stores owned `attrs.AttrsOwned`
//! copies and compares them with `AttrsOwned.eql`, mirroring
//! `ShapeRunKey { text, default_attrs, attrs_spans }`
//! (shape_run_cache.rs:9-13). The backing store is a linear entry list (run
//! caches are tiny; lookup cost is negligible next to shaping).
//!
//! `CachedGlyph` remains the minimal shaped-glyph stand-in here (byte range +
//! shaped output). TODO(cache): replace it with `shape.ShapeGlyph` when the
//! buffer layer wires the real shaper into this cache; cross-file imports are
//! allowed now, the dependency is simply not needed for the age/eviction
//! behavior this module owns.
//!
//! Verbatim semantics preserved from `ShapeRunCache`:
//! - `get` stamps the entry with the current age and returns it (`None` miss).
//! - `insert` stamps the entry with the current age (overwrites on key clash).
//! - `trim(keep)` retains entries with `age + keep >= now`, then bumps `now`.

const std = @import("std");
const attrs = @import("attrs.zig");

/// Minimal shaped glyph the cache preserves across hits (byte range + shaped
/// output). See the module TODO about `shape.ShapeGlyph`.
pub const CachedGlyph = struct {
    start: usize,
    end: usize,
    glyph_id: u16,
    x_advance: f32,
};

/// Borrowed non-default attrs span: run-relative range plus borrowed attrs.
/// Mirrors `(Range<usize>, &AttrsOwned)` in `ShapeRunKey` (shape_run_cache.rs:12).
pub const AttrSpan = struct {
    start: usize,
    end: usize,
    attrs: *const attrs.AttrsOwned,
};

/// Borrowed lookup key: run text, default attrs, and non-default spans.
/// Mirrors `ShapeRunKey { text, default_attrs, attrs_spans }`.
pub const KeyRef = struct {
    text: []const u8,
    default_attrs: *const attrs.AttrsOwned,
    spans: []const AttrSpan,
};

/// Owned cache key. `text` and `spans` are heap-owned; each span owns an
/// `AttrsOwned` clone, so equality is content-based like the Rust derive.
pub const KeyOwned = struct {
    text: []u8,
    default_attrs: attrs.AttrsOwned,
    spans: []OwnedAttrSpan,

    /// One owned span: run-relative range plus owned attrs.
    pub const OwnedAttrSpan = struct {
        start: usize,
        end: usize,
        attrs: attrs.AttrsOwned,
    };

    /// Release text, spans, and every owned attrs clone.
    pub fn deinit(self: *KeyOwned, allocator: std.mem.Allocator) void {
        self.default_attrs.deinit();
        for (self.spans) |*span| span.attrs.deinit();
        allocator.free(self.spans);
        allocator.free(self.text);
    }

    /// Value equality against a borrowed key (`ShapeRunKey` `PartialEq`).
    pub fn eql(a: *const KeyOwned, b: *const KeyRef) bool {
        if (!std.mem.eql(u8, a.text, b.text)) return false;
        if (!a.default_attrs.eql(b.default_attrs)) return false;
        if (a.spans.len != b.spans.len) return false;
        for (a.spans, b.spans) |*x, *y| {
            if (x.start != y.start or x.end != y.end) return false;
            if (!x.attrs.eql(y.attrs)) return false;
        }
        return true;
    }
};

const Entry = struct {
    key: KeyOwned,
    age: u64,
    glyphs: []CachedGlyph,
};

/// Age-stamped run cache. Backed by a linear entry list (run caches are tiny;
/// lookup cost is negligible next to shaping).
///
/// Capacity is explicit: `insert` overwrites on key clash and `trim` evicts;
/// nothing is ever silently dropped — every eviction goes through `trim`.
pub const ShapeRunCache = struct {
    allocator: std.mem.Allocator,
    /// Monotonic clock. `get`/`insert` stamp entries with `now`; `trim`
    /// retains `entry.age + keep >= now` and then bumps `now` (shape_run_cache.rs:37-42).
    now: u64 = 0,
    entries: std.ArrayList(Entry) = .empty,

    pub fn init(allocator: std.mem.Allocator) ShapeRunCache {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *ShapeRunCache) void {
        for (self.entries.items) |*e| {
            e.key.deinit(self.allocator);
            self.allocator.free(e.glyphs);
        }
        self.entries.deinit(self.allocator);
    }

    pub fn len(self: *const ShapeRunCache) usize {
        return self.entries.items.len;
    }

    pub fn currentAge(self: *const ShapeRunCache) u64 {
        return self.now;
    }

    fn findIndex(self: *const ShapeRunCache, key: *const KeyRef) ?usize {
        for (self.entries.items, 0..) |*e, i| {
            if (e.key.eql(key)) return i;
        }
        return null;
    }

    /// Get cache item, updating age if found (shape_run_cache.rs:24-29).
    pub fn get(self: *ShapeRunCache, key: *const KeyRef) ?[]CachedGlyph {
        const i = self.findIndex(key) orelse return null;
        self.entries.items[i].age = self.now;
        return self.entries.items[i].glyphs;
    }

    /// Deep-copy a borrowed key into an owned one (text, attrs, spans).
    fn cloneKey(self: *ShapeRunCache, key: *const KeyRef) !KeyOwned {
        const text_copy = try self.allocator.dupe(u8, key.text);
        errdefer self.allocator.free(text_copy);
        var default_copy = try key.default_attrs.clone_with(self.allocator);
        errdefer default_copy.deinit();
        const spans_copy = try self.allocator.alloc(KeyOwned.OwnedAttrSpan, key.spans.len);
        errdefer self.allocator.free(spans_copy);
        var initialized: usize = 0;
        errdefer for (spans_copy[0..initialized]) |*span| span.attrs.deinit();
        for (key.spans, 0..) |span, i| {
            spans_copy[i] = .{
                .start = span.start,
                .end = span.end,
                .attrs = try span.attrs.clone_with(self.allocator),
            };
            initialized = i + 1;
        }
        return .{ .text = text_copy, .default_attrs = default_copy, .spans = spans_copy };
    }

    /// Insert cache item with current age, cloning key and glyphs
    /// (shape_run_cache.rs:32-34). Overwrites any existing entry for `key`.
    pub fn insert(self: *ShapeRunCache, key: *const KeyRef, glyphs: []const CachedGlyph) !void {
        var owned_key = try self.cloneKey(key);
        errdefer owned_key.deinit(self.allocator);
        const glyphs_copy = try self.allocator.dupe(CachedGlyph, glyphs);
        errdefer self.allocator.free(glyphs_copy);

        if (self.findIndex(key)) |i| {
            const e = &self.entries.items[i];
            e.key.deinit(self.allocator);
            self.allocator.free(e.glyphs);
            e.key = owned_key;
            e.age = self.now;
            e.glyphs = glyphs_copy;
            return;
        }
        try self.entries.append(self.allocator, .{
            .key = owned_key,
            .age = self.now,
            .glyphs = glyphs_copy,
        });
    }

    /// Remove anything older than `keep` ages, then bump the clock
    /// (shape_run_cache.rs:37-42: retain `age + keep >= now`, `age += 1`).
    pub fn trim(self: *ShapeRunCache, keep: u64) void {
        var i: usize = 0;
        while (i < self.entries.items.len) {
            const e = &self.entries.items[i];
            if (e.age + keep >= self.now) {
                i += 1;
            } else {
                var removed = self.entries.orderedRemove(i);
                removed.key.deinit(self.allocator);
                self.allocator.free(removed.glyphs);
            }
        }
        self.now += 1;
    }
};

/// Borrowed key holder for tests: owns a default `AttrsOwned` and hands out
/// `KeyRef`s borrowing it.
const TestKey = struct {
    default_attrs: attrs.AttrsOwned,

    fn init() !TestKey {
        var scratch = attrs.Attrs.init(std.testing.allocator);
        defer scratch.deinit();
        return .{
            .default_attrs = try attrs.AttrsOwned.from_attrs(std.testing.allocator, &scratch),
        };
    }

    fn deinit(self: *TestKey) void {
        self.default_attrs.deinit();
    }

    fn ref(self: *TestKey, text: []const u8, spans: []const AttrSpan) KeyRef {
        return .{ .text = text, .default_attrs = &self.default_attrs, .spans = spans };
    }
};

fn testGlyphs() [1]CachedGlyph {
    return [_]CachedGlyph{
        .{ .start = 0, .end = 5, .glyph_id = 42, .x_advance = 0.6 },
    };
}

test "get misses on empty cache" {
    var c = ShapeRunCache.init(std.testing.allocator);
    defer c.deinit();
    var tk = try TestKey.init();
    defer tk.deinit();
    try std.testing.expect(c.get(&tk.ref("hello", &.{})) == null);
    try std.testing.expectEqual(@as(usize, 0), c.len());
}

test "insert then get hits and stamps age" {
    var c = ShapeRunCache.init(std.testing.allocator);
    defer c.deinit();
    var tk = try TestKey.init();
    defer tk.deinit();
    const glyphs = testGlyphs();
    try c.insert(&tk.ref("hello", &.{}), &glyphs);
    try std.testing.expectEqual(@as(u64, 0), c.currentAge());
    const hit = c.get(&tk.ref("hello", &.{}));
    try std.testing.expect(hit != null);
    try std.testing.expectEqual(@as(usize, 1), hit.?.len);
    try std.testing.expectEqual(@as(u16, 42), hit.?[0].glyph_id);
    // Distinct text misses.
    try std.testing.expect(c.get(&tk.ref("world", &.{})) == null);
}

test "insert overwrites existing key" {
    var c = ShapeRunCache.init(std.testing.allocator);
    defer c.deinit();
    var tk = try TestKey.init();
    defer tk.deinit();
    const g1 = [_]CachedGlyph{.{ .start = 0, .end = 1, .glyph_id = 1, .x_advance = 0.5 }};
    const g2 = [_]CachedGlyph{
        .{ .start = 0, .end = 1, .glyph_id = 2, .x_advance = 0.5 },
        .{ .start = 1, .end = 2, .glyph_id = 3, .x_advance = 0.5 },
    };
    try c.insert(&tk.ref("ab", &.{}), &g1);
    try c.insert(&tk.ref("ab", &.{}), &g2);
    try std.testing.expectEqual(@as(usize, 1), c.len());
    const hit = c.get(&tk.ref("ab", &.{})).?;
    try std.testing.expectEqual(@as(usize, 2), hit.len);
    try std.testing.expectEqual(@as(u16, 2), hit[0].glyph_id);
}

test "trim retains age+keep>=now then bumps clock" {
    var c = ShapeRunCache.init(std.testing.allocator);
    defer c.deinit();
    var tk = try TestKey.init();
    defer tk.deinit();
    const g = [_]CachedGlyph{.{ .start = 0, .end = 1, .glyph_id = 9, .x_advance = 1.0 }};
    try c.insert(&tk.ref("a", &.{}), &g); // stamped age 0, now 0
    c.trim(0); // 0+0>=0 retain; now -> 1
    try std.testing.expectEqual(@as(usize, 1), c.len());
    try std.testing.expectEqual(@as(u64, 1), c.currentAge());
    c.trim(0); // 0+0>=1 evict; now -> 2
    try std.testing.expectEqual(@as(usize, 0), c.len());
    try std.testing.expect(c.get(&tk.ref("a", &.{})) == null);
}

test "get refreshes entry so trim keeps it" {
    var c = ShapeRunCache.init(std.testing.allocator);
    defer c.deinit();
    var tk = try TestKey.init();
    defer tk.deinit();
    const g = [_]CachedGlyph{.{ .start = 0, .end = 1, .glyph_id = 9, .x_advance = 1.0 }};
    try c.insert(&tk.ref("a", &.{}), &g); // age 0
    c.trim(5); // retain; now -> 1
    _ = c.get(&tk.ref("a", &.{})); // bump entry to age 1
    c.trim(0); // 1+0>=1 retain; now -> 2
    try std.testing.expectEqual(@as(usize, 1), c.len());
    c.trim(0); // 1+0>=2 evict
    try std.testing.expectEqual(@as(usize, 0), c.len());
}

test "keys distinguish default attrs, spans, and compare by content" {
    var c = ShapeRunCache.init(std.testing.allocator);
    defer c.deinit();
    var tk = try TestKey.init();
    defer tk.deinit();
    var tk_bold = try TestKey.init();
    defer tk_bold.deinit();
    tk_bold.default_attrs.weight = attrs.Weight.bold;
    // A separately-created, equal default attrs must still hit.
    var tk_same = try TestKey.init();
    defer tk_same.deinit();

    var span_scratch = attrs.Attrs.init(std.testing.allocator);
    defer span_scratch.deinit();
    span_scratch.weight = attrs.Weight.bold;
    var owned_span = try attrs.AttrsOwned.from_attrs(std.testing.allocator, &span_scratch);
    defer owned_span.deinit();
    const spans = [_]AttrSpan{.{ .start = 0, .end = 1, .attrs = &owned_span }};

    const g = [_]CachedGlyph{.{ .start = 0, .end = 1, .glyph_id = 1, .x_advance = 1.0 }};
    try c.insert(&tk.ref("a", &.{}), &g);
    try std.testing.expect(c.get(&tk_bold.ref("a", &.{})) == null);
    try std.testing.expect(c.get(&tk.ref("a", &spans)) == null);
    try std.testing.expect(c.get(&tk_same.ref("a", &.{})) != null);
}
