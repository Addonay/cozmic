//! Shared, reference-counted font bytes.
//!
//! The shaper (HarfBuzz) and the rasterizer (FreeType) both need a face's
//! bytes for as long as the face lives. Before this module each kept its own
//! heap copy, so a rendered font cost twice its file size. A `Blob` is created
//! once and retained by every consumer, and the last `release` frees it,
//! matching upstream's `Arc<dyn AsRef<[u8]>>` font data.
//!
//! File-backed blobs are read-only memory mappings (`std.Io.File.MemoryMap`,
//! no prefault). Their pages are clean and shared with every other process
//! mapping the same font, the kernel can drop them under memory pressure, and
//! only the tables actually touched become resident, as with `fontdb`'s
//! `memmap2` sources. Where mapping is unsupported, std falls back to a
//! buffered read transparently.
//!
//! `open` deduplicates by path: while any consumer holds a blob for a path,
//! later opens of that path return the same blob. The cache is an intrusive
//! list (no allocation of its own), guarded by a private lock so `release`
//! is safe from any thread.
//!
//! As with every mmap-based font loader, truncating a font file while it is
//! mapped can fault the process; font files are expected to be replaced
//! atomically (as package managers do), not rewritten in place.

const std = @import("std");
const dynload = @import("dynload");

/// Upper bound for one font file (64 MiB), matching the other font readers.
pub const MAX_BYTES: usize = 1 << 26;

pub const Blob = struct {
    refs: std.atomic.Value(u32) = .init(1),
    /// Owns this struct, the path key and heap storage.
    allocator: std.mem.Allocator,
    bytes: []const u8,
    storage: Storage,
    /// Set for path-cached blobs; owned.
    path: ?[]u8 = null,
    /// Path-cache link (only meaningful while `path != null`).
    next: ?*Blob = null,

    const Storage = union(enum) {
        heap: []u8,
        mapped: std.Io.File.MemoryMap,
    };

    /// A new blob holding a copy of `bytes`.
    pub fn copy(allocator: std.mem.Allocator, bytes: []const u8) std.mem.Allocator.Error!*Blob {
        const owned = try allocator.dupe(u8, bytes);
        errdefer allocator.free(owned);
        const blob = try allocator.create(Blob);
        blob.* = .{ .allocator = allocator, .bytes = owned, .storage = .{ .heap = owned } };
        return blob;
    }

    pub fn retain(self: *Blob) *Blob {
        _ = self.refs.fetchAdd(1, .monotonic);
        return self;
    }

    /// Drop one reference; the last one unmaps/frees the bytes.
    pub fn release(self: *Blob) void {
        if (self.path != null) {
            // Decrement under the cache lock so a concurrent `open` cannot
            // resurrect a blob whose count just reached zero.
            cache_mutex.lock();
            const last = self.refs.fetchSub(1, .acq_rel) == 1;
            if (last) unlink(self);
            cache_mutex.unlock();
            if (last) self.destroy();
        } else if (self.refs.fetchSub(1, .acq_rel) == 1) {
            self.destroy();
        }
    }

    fn destroy(self: *Blob) void {
        const allocator = self.allocator;
        switch (self.storage) {
            .heap => |bytes| allocator.free(bytes),
            .mapped => |mm| {
                var map = mm;
                map.destroy(io());
            },
        }
        if (self.path) |p| allocator.free(p);
        allocator.destroy(self);
    }
};

pub const OpenError = std.mem.Allocator.Error || error{FontUnavailable};

var cache_mutex: dynload.Mutex = .{};
var cache_head: ?*Blob = null;

/// Lazy font reads have no caller-provided `Io` (see `shape_hb`), so they go
/// through the process-wide single-threaded instance. Callers serialize file
/// access with `dynload.source_io_mutex`.
fn io() std.Io {
    return std.Io.Threaded.global_single_threaded.io();
}

/// The blob for font file `path`, mapping it on first use. Every non-OOM
/// failure (missing, unreadable, empty or oversized file) is
/// `error.FontUnavailable`. Release the result with `Blob.release`.
pub fn open(allocator: std.mem.Allocator, path: []const u8) OpenError!*Blob {
    {
        cache_mutex.lock();
        defer cache_mutex.unlock();
        var it = cache_head;
        while (it) |blob| : (it = blob.next) {
            if (std.mem.eql(u8, blob.path.?, path)) return blob.retain();
        }
    }

    const key = try allocator.dupe(u8, path);
    errdefer allocator.free(key);
    const blob = try allocator.create(Blob);
    errdefer allocator.destroy(blob);

    const file = std.Io.Dir.cwd().openFile(io(), path, .{}) catch return error.FontUnavailable;
    defer file.close(io());
    const len = file.length(io()) catch return error.FontUnavailable;
    if (len == 0 or len > MAX_BYTES) return error.FontUnavailable;
    const mm = file.createMemoryMap(io(), .{
        .len = @intCast(len),
        .protection = .{ .read = true },
        .populate = false,
    }) catch |err| return if (err == error.OutOfMemory) error.OutOfMemory else error.FontUnavailable;
    blob.* = .{
        .allocator = allocator,
        .bytes = mm.memory,
        .storage = .{ .mapped = mm },
        .path = key,
    };

    cache_mutex.lock();
    defer cache_mutex.unlock();
    // Another thread may have mapped the same path meanwhile; keep theirs.
    var it = cache_head;
    while (it) |existing| : (it = existing.next) {
        if (std.mem.eql(u8, existing.path.?, path)) {
            blob.destroy();
            return existing.retain();
        }
    }
    blob.next = cache_head;
    cache_head = blob;
    return blob;
}

/// Caller holds `cache_mutex`.
fn unlink(blob: *Blob) void {
    var link: *?*Blob = &cache_head;
    while (link.*) |cur| : (link = &cur.next) {
        if (cur == blob) {
            link.* = cur.next;
            return;
        }
    }
}

test "copy blobs are independent and refcounted" {
    const a = std.testing.allocator;
    const blob = try Blob.copy(a, "abc");
    try std.testing.expectEqualStrings("abc", blob.bytes);
    _ = blob.retain();
    blob.release();
    try std.testing.expectEqualStrings("abc", blob.bytes);
    blob.release();
}

test "open maps a file once per path and unmaps on last release" {
    const a = std.testing.allocator;
    const path = "tests/fonts/Inter-Regular.ttf";
    const first = open(a, path) catch |err| switch (err) {
        error.FontUnavailable => return error.SkipZigTest,
        else => return err,
    };
    const second = try open(a, path);
    try std.testing.expectEqual(first, second);
    try std.testing.expect(first.bytes.len > 1024);
    // sfnt version 0x00010000 for a TrueType face.
    try std.testing.expectEqualSlices(u8, &.{ 0, 1, 0, 0 }, first.bytes[0..4]);
    second.release();
    first.release();
    try std.testing.expect(cache_head == null);
}

test "open reports missing and empty files as unavailable" {
    const a = std.testing.allocator;
    try std.testing.expectError(error.FontUnavailable, open(a, "tests/fonts/cozmic-no-such-font.ttf"));
    try std.testing.expect(cache_head == null);
}
