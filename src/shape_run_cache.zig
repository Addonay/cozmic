//! Port of cosmic-text `shape_run_cache.rs` (49 lines).
//!
//! Key equality is canonical: `KeyOwned` stores owned `attrs.AttrsOwned`
//! copies and compares them with `AttrsOwned.eql`, mirroring
//! `ShapeRunKey { text, default_attrs, attrs_spans }`
//! (shape_run_cache.rs:9-13). The backing store is a linear entry list (run
//! caches are tiny; lookup cost is negligible next to shaping).
//!
//! `CachedGlyph` is the full `shape.ShapeGlyph`: the advanced path is now
//! wired through this cache (shape.zig `shapeRunCached`), so a hit must
//! reproduce every field — a minimal stand-in would drop color, metrics,
//! weight and font state. This creates a mutual import with `shape.zig`
//! (which needs this module for the adapter seam); Zig resolves it because
//! neither type depends on the other at comptime.
//!
//! Verbatim semantics preserved from `ShapeRunCache`:
//! - `get` stamps the entry with the current age and returns it (`None` miss).
//! - `insert` stamps the entry with the current age (overwrites on key clash).
//! - `trim(keep)` retains entries with `age + keep >= now`, then bumps `now`.
//! - `clear` drops everything while keeping the backing allocation (used by
//!   cold-cache measurements and corpus resets; upstream has no equivalent).

const std = @import("std");
const attrs = @import("attrs.zig");

/// Full shaped glyph stored across hits (port decision: store the real
/// `shape.ShapeGlyph`, mirroring upstream's `Vec<ShapeGlyph>` cache values).
pub const CachedGlyph = @import("shape.zig").ShapeGlyph;

/// Borrowed non-default attrs span: run-relative range plus borrowed attrs.
/// Mirrors `(Range<usize>, &AttrsOwned)` in `ShapeRunKey` (shape_run_cache.rs:12).
pub const AttrSpan = struct {
    start: usize,
    end: usize,
    attrs: *const attrs.AttrsOwned,
};

/// Borrowed lookup key: run text, direction, default attrs, and non-default
/// spans.
///
/// Direction is part of the key, unlike upstream's `ShapeRunKey`
/// (shape_run_cache.rs:9-13). `shape_run_cached` receives `span_rtl` and HarfBuzz
/// returns visually reversed runs with descending cluster offsets for RTL, so a
/// key that ignored it could hand LTR output back for an RTL request. Upstream's
/// cache is default-off and inherits the same gap; here the cache is on by
/// default, which makes it reachable in normal use.
pub const KeyRef = struct {
    text: []const u8,
    default_attrs: *const attrs.AttrsOwned,
    spans: []const AttrSpan,
    /// Whether the run was shaped right-to-left.
    rtl: bool,
};

/// Owned cache key. `text` and `spans` are heap-owned; each span owns an
/// `AttrsOwned` clone, so equality is content-based like the Rust derive.
pub const KeyOwned = struct {
    text: []u8,
    default_attrs: attrs.AttrsOwned,
    spans: []OwnedAttrSpan,
    /// Mirrors `KeyRef.rtl`; part of equality.
    rtl: bool = false,

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
        if (a.rtl != b.rtl) return false;
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
    /// Approximate retained bytes, charged against the cache's byte budget.
    bytes: usize,
    /// Monotonic recency stamp, bumped on every `get`/`insert`.
    ///
    /// Distinct from `age`, which is only advanced by `trim` and therefore
    /// ties every entry written since the last trim. Eviction order needs a
    /// value that actually orders accesses, or a working run is evicted at the
    /// same rate as cold churn.
    seq: u64,
};

/// Approximate heap footprint of one entry: the owned key's text and span
/// table, the glyph vector, and a flat per-entry allowance for the cloned
/// default/span attrs. Exactness is not achievable through the `attrs` API
/// (family bytes, feature vectors and metadata are individually reachable), so
/// this is a deliberate lower bound that still scales with the two unbounded
/// dimensions: run length and glyph count.
fn estimateBytes(text_len: usize, span_count: usize, glyph_count: usize) usize {
    const attrs_allowance: usize = 256;
    return @sizeOf(Entry) +
        text_len +
        span_count * @sizeOf(OwnedSpanAllowance) +
        glyph_count * @sizeOf(CachedGlyph) +
        attrs_allowance;
}

const OwnedSpanAllowance = struct {
    start: usize,
    end: usize,
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
    /// Sum of `Entry.bytes`. Maintained by `insert`/`enforceBudget`/`trim`
    /// so the byte budget can be checked without re-walking the entry list.
    bytes: usize = 0,
    /// Source of `Entry.seq` values. Advances on every `get` and `insert`.
    seq: u64 = 0,
    /// Count and byte ceilings applied by `enforceBudget`. Defaults match the
    /// advanced path's production budgets; a test or embedder may lower them
    /// but not raise them past what memory accounting can justify.
    max_entries: usize = 16384,
    max_bytes: usize = 64 * 1024 * 1024,

    pub fn init(allocator: std.mem.Allocator) ShapeRunCache {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *ShapeRunCache) void {
        self.clear();
        self.entries.deinit(self.allocator);
    }

    /// Drop every entry while keeping the backing allocation. Cold-cache
    /// measurements (the benches) and corpus resets use this; production
    /// callers normally rely on `enforceBudget` for bounded eviction.
    pub fn clear(self: *ShapeRunCache) void {
        for (self.entries.items) |*e| {
            e.key.deinit(self.allocator);
            self.allocator.free(e.glyphs);
        }
        self.entries.clearRetainingCapacity();
        self.bytes = 0;
    }

    pub fn len(self: *const ShapeRunCache) usize {
        return self.entries.items.len;
    }

    /// Approximate retained bytes across all entries.
    pub fn bytesUsed(self: *const ShapeRunCache) usize {
        return self.bytes;
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
        self.seq +%= 1;
        self.entries.items[i].seq = self.seq;
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
        return .{ .text = text_copy, .default_attrs = default_copy, .spans = spans_copy, .rtl = key.rtl };
    }

    /// Insert cache item with current age, cloning key and glyphs
    /// (shape_run_cache.rs:32-34). Overwrites any existing entry for `key`.
    pub fn insert(self: *ShapeRunCache, key: *const KeyRef, glyphs: []const CachedGlyph) !void {
        var owned_key = try self.cloneKey(key);
        errdefer owned_key.deinit(self.allocator);
        const glyphs_copy = try self.allocator.dupe(CachedGlyph, glyphs);
        errdefer self.allocator.free(glyphs_copy);

        const entry_bytes = estimateBytes(key.text.len, key.spans.len, glyphs.len);
        if (self.findIndex(key)) |i| {
            const e = &self.entries.items[i];
            e.key.deinit(self.allocator);
            self.allocator.free(e.glyphs);
            self.bytes -= e.bytes;
            e.key = owned_key;
            e.age = self.now;
            e.glyphs = glyphs_copy;
            e.bytes = entry_bytes;
            self.seq +%= 1;
            e.seq = self.seq;
            self.bytes += entry_bytes;
            return;
        }
        self.seq +%= 1;
        try self.entries.append(self.allocator, .{
            .key = owned_key,
            .age = self.now,
            .glyphs = glyphs_copy,
            .bytes = entry_bytes,
            .seq = self.seq,
        });
        self.bytes += entry_bytes;
    }

    /// Evict least-recently-used entries until both budgets hold.
    ///
    /// This is the real capacity bound. `trim` is an age-window filter, so it
    /// cannot serve this purpose: within a single cold burst every entry shares
    /// the same age, `trim` retains them all, and the advertised entry cap
    /// silently does nothing. Eviction uses `Entry.seq` (see that field for why
    /// `age` cannot order entries), so a run in active use is evicted last.
    ///
    /// At least one entry is always kept: an entry for text the caller is
    /// shaping right now must remain cacheable, otherwise the working set
    /// degrades to a zero hit rate.
    ///
    /// Cost is one linear scan per eviction. With the production budget of
    /// 16,384 entries that is acceptable only because evictions are rare once
    /// the cache is warm; a cold burst of a large document pays O(n) per insert
    /// past the cap. Replacing the backing store with a hash map plus an
    /// eviction list would remove the quadratic term; see the audit's
    /// optimization note. Not done here because correctness of the bound is
    /// the defect being fixed and the measured workloads stay well under it.
    pub fn enforceBudget(self: *ShapeRunCache) void {
        while (self.entries.items.len > 1 and
            (self.entries.items.len > self.max_entries or self.bytes > self.max_bytes))
        {
            self.evictLeastRecentlyUsed();
        }
    }

    fn evictLeastRecentlyUsed(self: *ShapeRunCache) void {
        var victim: usize = 0;
        for (self.entries.items, 0..) |e, i| {
            if (e.seq < self.entries.items[victim].seq) victim = i;
        }
        var removed = self.entries.orderedRemove(victim);
        self.bytes -= removed.bytes;
        removed.key.deinit(self.allocator);
        self.allocator.free(removed.glyphs);
    }

    /// Remove anything older than `keep` ages, then bump the clock
    /// (shape_run_cache.rs:37-42: retain `age + keep >= now`, `age += 1`).
    ///
    /// This is upstream's age-window filter and is **not** a capacity bound;
    /// use `enforceBudget` for that. It also decrements the byte accounting so
    /// `bytesUsed` stays truthful after a trim.
    pub fn trim(self: *ShapeRunCache, keep: u64) void {
        var i: usize = 0;
        while (i < self.entries.items.len) {
            const e = &self.entries.items[i];
            if (e.age + keep >= self.now) {
                i += 1;
            } else {
                var removed = self.entries.orderedRemove(i);
                self.bytes -= removed.bytes;
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
        return .{ .text = text, .default_attrs = &self.default_attrs, .spans = spans, .rtl = false };
    }

    /// Mutable view for tests that need to vary one key field per call.
    fn refRtl(self: *TestKey, text: []const u8, spans: []const AttrSpan) KeyRef {
        return .{ .text = text, .default_attrs = &self.default_attrs, .spans = spans, .rtl = true };
    }
};

fn testGlyphs() [1]CachedGlyph {
    return [_]CachedGlyph{testGlyph(0, 5, 42, 0.6)};
}

/// Test glyph literal helper: fills the full `ShapeGlyph` fields the cache
/// now stores, with the identity fields under test supplied explicitly.
fn testGlyph(start: usize, end: usize, glyph_id: u16, x_advance: f32) CachedGlyph {
    return .{
        .start = start,
        .end = end,
        .x_advance = x_advance,
        .y_advance = 0,
        .x_offset = 0,
        .y_offset = 0,
        .ascent = 0,
        .descent = 0,
        .font_id = 0,
        .font_weight = attrs.Weight.normal,
        .glyph_id = glyph_id,
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
    const g1 = [_]CachedGlyph{testGlyph(0, 1, 1, 0.5)};
    const g2 = [_]CachedGlyph{ testGlyph(0, 1, 2, 0.5), testGlyph(1, 2, 3, 0.5) };
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
    const g = [_]CachedGlyph{testGlyph(0, 1, 9, 1.0)};
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
    const g = [_]CachedGlyph{testGlyph(0, 1, 9, 1.0)};
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

    const g = [_]CachedGlyph{testGlyph(0, 1, 1, 1.0)};
    try c.insert(&tk.ref("a", &.{}), &g);
    try std.testing.expect(c.get(&tk_bold.ref("a", &.{})) == null);
    try std.testing.expect(c.get(&tk.ref("a", &spans)) == null);
    try std.testing.expect(c.get(&tk_same.ref("a", &.{})) != null);
}

test "enforceBudget bounds the entry count during a cold burst" {
    var c = ShapeRunCache.init(std.testing.allocator);
    defer c.deinit();
    c.max_entries = 64;
    var tk = try TestKey.init();
    defer tk.deinit();
    const g = [_]CachedGlyph{testGlyph(0, 1, 1, 0.5)};
    var text: [32]u8 = undefined;
    // Every insert shares one age, which is exactly the case the old
    // `trim(run_cache_max / 2)` policy failed to bound.
    for (0..17_000) |i| {
        try c.insert(&tk.ref(try std.fmt.bufPrint(&text, "run-{d}", .{i}), &.{}), &g);
        c.enforceBudget();
    }
    try std.testing.expect(c.len() <= 64);
    try std.testing.expectEqual(@as(usize, 64), c.len());
}

test "enforceBudget bounds retained bytes for long runs" {
    var c = ShapeRunCache.init(std.testing.allocator);
    defer c.deinit();
    // Entry budget deliberately generous so only the byte budget can fire.
    c.max_entries = 100_000;
    c.max_bytes = 256 * 1024;
    var tk = try TestKey.init();
    defer tk.deinit();

    var text: [4096]u8 = undefined;
    const long_run = text[0..4000];
    @memset(long_run, 'x');
    var glyphs: [512]CachedGlyph = undefined;
    for (&glyphs, 0..) |*g, i| g.* = testGlyph(i, i + 1, 1, 0.5);

    for (0..200) |i| {
        // Unique key per iteration: same bytes, different leading digit.
        long_run[0] = @truncate('a' + @as(u8, @intCast(i % 26)));
        try c.insert(&tk.ref(long_run, &.{}), &glyphs);
        c.enforceBudget();
        try std.testing.expect(c.bytesUsed() <= c.max_bytes);
    }
    // A long-run working set must still be able to hold something.
    try std.testing.expect(c.len() >= 1);
    try std.testing.expect(c.len() < 200);
}

test "enforceBudget keeps a repeatedly used run resident" {
    var c = ShapeRunCache.init(std.testing.allocator);
    defer c.deinit();
    c.max_entries = 8;
    var tk = try TestKey.init();
    defer tk.deinit();
    var hot: [32]u8 = undefined;
    var cold: [32]u8 = undefined;
    const hot_text = try std.fmt.bufPrint(&hot, "hot", .{});
    const hot_glyphs = [_]CachedGlyph{testGlyph(0, 3, 42, 0.5)};
    try c.insert(&tk.ref(hot_text, &.{}), &hot_glyphs);

    for (0..200) |i| {
        const cold_text = try std.fmt.bufPrint(&cold, "cold-{d}", .{i});
        try c.insert(&tk.ref(cold_text, &.{}), &hot_glyphs);
        c.enforceBudget();
        // Touching the hot run refreshes its recency, so it outranks the churn.
        _ = c.get(&tk.ref(hot_text, &.{}));
    }
    try std.testing.expect(c.len() <= 8);
    try std.testing.expect(c.get(&tk.ref(hot_text, &.{})) != null);
}

test "byte accounting stays consistent across insert, trim and clear" {
    var c = ShapeRunCache.init(std.testing.allocator);
    defer c.deinit();
    var tk = try TestKey.init();
    defer tk.deinit();
    const g = [_]CachedGlyph{testGlyph(0, 1, 1, 0.5)};
    try std.testing.expectEqual(@as(usize, 0), c.bytesUsed());
    try c.insert(&tk.ref("a", &.{}), &g);
    const one = c.bytesUsed();
    try std.testing.expect(one > 0);
    // Overwriting the same key must not double-count.
    try c.insert(&tk.ref("a", &.{}), &g);
    try std.testing.expectEqual(one, c.bytesUsed());
    try c.insert(&tk.ref("b", &.{}), &g);
    try std.testing.expectEqual(2 * one, c.bytesUsed());
    c.trim(0);
    c.trim(0); // evicts both, age 0 < now 2
    try std.testing.expectEqual(@as(usize, 0), c.bytesUsed());
    try c.insert(&tk.ref("c", &.{}), &g);
    try std.testing.expectEqual(one, c.bytesUsed());
    c.clear();
    try std.testing.expectEqual(@as(usize, 0), c.bytesUsed());
}

test "keys distinguish shaping direction" {
    var c = ShapeRunCache.init(std.testing.allocator);
    defer c.deinit();
    var tk = try TestKey.init();
    defer tk.deinit();

    const ltr = [_]CachedGlyph{testGlyph(0, 1, 7, 1.0)};
    const rtl = [_]CachedGlyph{testGlyph(0, 1, 9, 1.0)};
    try c.insert(&tk.ref("abc", &.{}), &ltr);
    try c.insert(&tk.refRtl("abc", &.{}), &rtl);
    try std.testing.expectEqual(@as(usize, 2), c.len());

    try std.testing.expectEqual(@as(u16, 7), c.get(&tk.ref("abc", &.{})).?[0].glyph_id);
    try std.testing.expectEqual(@as(u16, 9), c.get(&tk.refRtl("abc", &.{})).?[0].glyph_id);
    // An LTR insert must not be found under an RTL lookup.
    var tk2 = try TestKey.init();
    defer tk2.deinit();
    try std.testing.expect(c.get(&tk2.refRtl("zzz", &.{})) == null);
}
