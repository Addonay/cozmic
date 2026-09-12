//! Minimal cross-platform runtime dynamic-library loader shared by the
//! vendored HarfBuzz/FreeType bindings (`src/harfbuzz`, `src/freetype`).
//!
//! The port must not hard-link system HarfBuzz/FreeType: the generated
//! bindings (`c_bindings_dyn.zig`) declare every C entry point as a
//! function-pointer variable and `loadDynamic` fills them from a
//! `dynload.Library` resolved here. POSIX builds go through `std.DynLib`
//! (`dlopen`/`dlsym`); Windows builds declare the kernel32
//! `LoadLibraryA`/`GetProcAddress`/`FreeLibrary` entry points locally, because
//! `std.DynLib` is not implemented for Windows in this Zig version.
//!
//! Only the active platform branch is analyzed: the `switch`/`if` guards below
//! are comptime-known, so the `std.DynLib` code never reaches the Windows
//! compile and the Windows externs never reach the POSIX compile.
//!
//! Diagnostics are coarse on purpose: `open` returns `null` when every
//! candidate name fails, `lookupSymbol` returns `null` for a missing symbol,
//! and the caller turns that into a named error. Nothing aborts or panics.
//!
//! This file itself keeps no shared mutable state; the per-library `dyn.zig`
//! loaders own their caches and serialize the first load with the `Mutex`
//! below. Shaping/layout text remains single-threaded by contract.

const std = @import("std");
const builtin = @import("builtin");

/// Stack buffer for NUL-terminated library/symbol names. All candidate names
/// in this port are short; longer names are rejected (returning `null`).
const name_buffer_len = 512;

/// Minimal mutual-exclusion lock for the per-library first-load guards.
///
/// Zig 0.17 no longer ships `std.Thread.Mutex`, and its replacement
/// `std.Io.Mutex` needs an `Io` instance that a library-internal loader does
/// not have. The guarded section is a one-time `open` plus symbol binding, so
/// a CAS lock with a yielding backoff is enough: contention can only happen
/// on the very first load, and yielding keeps the waiter from starving the
/// loading thread on single-core hosts.
pub const Mutex = struct {
    inner: std.atomic.Mutex = .unlocked,

    pub fn lock(self: *Mutex) void {
        while (!self.inner.tryLock()) {
            std.Thread.yield() catch std.atomic.spinLoopHint();
        }
    }

    pub fn unlock(self: *Mutex) void {
        self.inner.unlock();
    }
};

/// A loaded shared library handle.
///
/// One `Library` per C library is kept for the process lifetime by the
/// per-library `dyn.zig` loaders (a `dlopen` cache); `close` exists for tests
/// and is not called on the normal path.
pub const Library = struct {
    handle: Handle,

    /// `*std.DynLib` where it exists (POSIX), a Win32 `HMODULE` otherwise.
    /// Chosen with a comptime `switch` so the POSIX arm is not analyzed on
    /// Windows.
    const Handle = switch (builtin.os.tag) {
        .windows => *anyopaque,
        else => *std.DynLib,
    };

    /// Try each candidate name in order; the first successful load wins.
    /// Returns `null` when every candidate is missing or cannot be loaded.
    /// Never panics.
    pub fn open(candidates: []const []const u8) ?Library {
        return if (builtin.os.tag == .windows)
            openWindows(candidates)
        else
            openPosix(candidates);
    }

    /// Resolve `name` to its address; `null` when the symbol does not exist
    /// or `name` does not fit the sentinel buffer.
    pub fn lookupSymbol(self: *const Library, name: []const u8) ?*anyopaque {
        return if (builtin.os.tag == .windows)
            lookupWindows(self, name)
        else
            lookupPosix(self, name);
    }

    /// Release the handle. Not needed for the process-lifetime caches, but
    /// used by tests; the `Library` must not be used afterwards.
    pub fn close(self: *Library) void {
        if (builtin.os.tag == .windows) {
            closeWindows(self);
        } else {
            closePosix(self);
        }
    }
};

// ---------------------------------------------------------------------------
// POSIX (dlopen / dlsym)
// ---------------------------------------------------------------------------

fn openPosix(candidates: []const []const u8) ?Library {
    for (candidates) |name| {
        const lib = std.DynLib.open(name) catch continue;
        // `std.DynLib.open` returns the wrapper by value; keep it behind a
        // stable pointer so `Library` stays copyable. The loader caches one
        // `Library` per process lifetime, so this is a one-time allocation.
        const handle = std.heap.page_allocator.create(std.DynLib) catch {
            var owned = lib;
            owned.close();
            return null;
        };
        handle.* = lib;
        return .{ .handle = handle };
    }
    return null;
}

fn lookupPosix(self: *const Library, name: []const u8) ?*anyopaque {
    var buf: [name_buffer_len]u8 = undefined;
    const z = toSentinel(name, &buf) orelse return null;
    return self.handle.lookup(*anyopaque, z);
}

fn closePosix(self: *Library) void {
    self.handle.close();
    std.heap.page_allocator.destroy(self.handle);
}

// ---------------------------------------------------------------------------
// Windows (kernel32)
// ---------------------------------------------------------------------------

extern "kernel32" fn LoadLibraryA(name: [*:0]const u8) callconv(.winapi) ?*anyopaque;
extern "kernel32" fn GetProcAddress(module: *anyopaque, name: [*:0]const u8) callconv(.winapi) ?*anyopaque;
extern "kernel32" fn FreeLibrary(module: *anyopaque) callconv(.winapi) c_int;

fn openWindows(candidates: []const []const u8) ?Library {
    for (candidates) |name| {
        var buf: [name_buffer_len]u8 = undefined;
        const z = toSentinel(name, &buf) orelse continue;
        const hmodule = LoadLibraryA(z) orelse continue;
        return .{ .handle = hmodule };
    }
    return null;
}

fn lookupWindows(self: *const Library, name: []const u8) ?*anyopaque {
    var buf: [name_buffer_len]u8 = undefined;
    const z = toSentinel(name, &buf) orelse return null;
    return GetProcAddress(self.handle, z);
}

fn closeWindows(self: *Library) void {
    _ = FreeLibrary(self.handle);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Copy `name` plus a NUL sentinel into `buf`; `null` when it does not fit.
fn toSentinel(name: []const u8, buf: []u8) ?[:0]const u8 {
    if (name.len >= buf.len) return null;
    @memcpy(buf[0..name.len], name);
    buf[name.len] = 0;
    return buf[0..name.len :0];
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

const testing = std.testing;

test "opens a known host library and resolves a symbol" {
    const candidates: []const []const u8 = switch (builtin.os.tag) {
        .windows => &.{"kernel32.dll"},
        .macos => &.{"libSystem.B.dylib"},
        else => &.{ "libc.cozmic-does-not-exist.so", "libc.so.6", "libc.so" },
    };
    var lib = Library.open(candidates) orelse return error.HostLibraryUnavailable;
    defer lib.close();

    // Exported by glibc's libc.so.6, macOS libSystem and Windows kernel32.
    const symbol = if (builtin.os.tag == .windows) "GetCurrentProcessId" else "malloc";
    try testing.expect(Library.lookupSymbol(&lib, symbol) != null);
    // A symbol that cannot exist: null, not a crash.
    try testing.expect(Library.lookupSymbol(&lib, "cozmic_no_such_symbol_9f3d") == null);
}

test "bogus candidate names return null and never panic" {
    try testing.expect(Library.open(&[_][]const u8{}) == null);
    try testing.expect(Library.open(&[_][]const u8{"libcozmic-missing-library-9f3d.so"}) == null);
    try testing.expect(Library.open(&[_][]const u8{
        "libcozmic-missing-library-9f3d.so",
        "/nonexistent/cozmic/libnope.dylib",
    }) == null);
}

test "sentinel name handling rejects oversized names" {
    var buf: [4]u8 = undefined;
    try testing.expect(toSentinel("abc", &buf) != null);
    try testing.expectEqualStrings("abc", toSentinel("abc", &buf).?);
    try testing.expect(toSentinel("abcd", &buf) == null);
    try testing.expect(toSentinel("", &buf) != null);
}

test "mutex locks, unlocks and relocks" {
    var mutex: Mutex = .{};
    mutex.lock();
    mutex.unlock();
    try testing.expect(mutex.inner.tryLock());
    mutex.unlock();
}

test "mutex is mutually exclusive across threads" {
    var mutex = Mutex{};
    var counter: usize = 0;
    const Worker = struct {
        fn run(m: *Mutex, count: *usize) void {
            for (0..1_000) |_| {
                m.lock();
                count.* += 1;
                m.unlock();
            }
        }
    };
    var threads: [2]std.Thread = undefined;
    for (&threads) |*thread| {
        thread.* = try std.Thread.spawn(.{}, Worker.run, .{ &mutex, &counter });
    }
    for (&threads) |thread| thread.join();
    try testing.expectEqual(@as(usize, 2_000), counter);
}
