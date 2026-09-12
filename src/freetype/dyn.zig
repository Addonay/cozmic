//! Runtime loader for the system FreeType shared library.
//!
//! The `freetype` module no longer links `libfreetype` at build time: the
//! bindings in `c_bindings_dyn.zig` are function-pointer variables, and this
//! file fills them from the first candidate that `dlopen`s/`LoadLibrary`s
//! successfully. One process-wide `library` instance is kept alive for the
//! process lifetime (a `dlopen` cache); it is never closed, so all bound
//! pointers stay valid.
//!
//! Call `ensureLoaded` before touching any `c.FT_*` function: `raster_ft`'s
//! `Library.init` does that for the raster path, and the module's own tests do
//! it directly. A load failure is remembered *with its original error*
//! (`first_error`), so a missing library/symbol costs one probe per process
//! and every later call returns the same cause instead of a generic failure.
//! On a partial bind the library is deliberately left loaded: the symbols
//! bound before the failure are live pointers into it.
//!
//! Thread safety: the first load is guarded by a process-wide `dynload.Mutex`,
//! so concurrent callers cannot race the `open`/bind sequence. Beyond that the
//! vendored wrappers are not thread safe: rasterize text from one thread at a
//! time.

const std = @import("std");
const builtin = @import("builtin");
const dynload = @import("dynload");
const c = @import("c.zig").c;

/// Error set of `ensureLoaded`, kept explicit because callers switch on it.
const LoadError = error{ LibraryUnavailable, MissingSymbol };

/// Process-lifetime load state: negative cache plus the live `Library`.
const Runtime = struct {
    /// Serializes the first load; uncontended once the state is resolved.
    mutex: dynload.Mutex = .{},
    /// The loaded library; `null` until `ensure` opens it. Never closed, even
    /// after a failed bind, so bound pointers stay valid.
    library: ?dynload.Library = null,
    /// `uninitialized` until the first `ensure`; `failed` is a negative cache,
    /// `loaded` means `library` is live and every required symbol bound.
    state: State = .uninitialized,
    /// First failure, replayed by every later `ensure` call so callers see the
    /// original cause (`MissingSymbol` vs `LibraryUnavailable`).
    first_error: ?LoadError = null,

    const State = enum { uninitialized, loaded, failed };

    /// Resolve `names` and bind with `bind`, exactly once.
    ///
    /// `bind` may fail after assigning some symbols; those symbols then point
    /// into the opened library, which is therefore stored and never closed.
    /// `LoadError` must cover everything `bind` returns; a narrower set
    /// coerces, anything else is a compile error.
    fn ensure(self: *Runtime, names: []const []const u8, bind: anytype) LoadError!void {
        self.mutex.lock();
        defer self.mutex.unlock();

        switch (self.state) {
            .loaded => return,
            .failed => return self.first_error orelse error.LibraryUnavailable,
            .uninitialized => {},
        }

        var lib = dynload.Library.open(names) orelse {
            self.state = .failed;
            self.first_error = error.LibraryUnavailable;
            return error.LibraryUnavailable;
        };
        bind(&lib) catch |err| {
            // Keep the library loaded: `bind` may have written pointers into
            // it before failing, and `state = .failed` makes sure they are
            // never called.
            self.library = lib;
            self.state = .failed;
            self.first_error = err;
            return err;
        };
        self.library = lib;
        self.state = .loaded;
    }

    /// Snapshot of the load state; callers must have observed `ensure`.
    fn isLoaded(self: *const Runtime) bool {
        return self.state == .loaded and self.library != null;
    }
};

var runtime: Runtime = .{};

/// Candidate shared-object names, most specific first. Homebrew prefixes are
/// tried before the bare names on macOS; Linux/BSD rely on the loader search
/// path (`ldconfig`/`rpath`).
fn candidates() []const []const u8 {
    return switch (builtin.os.tag) {
        .macos => &[_][]const u8{
            "/opt/homebrew/lib/libfreetype.6.dylib",
            "/usr/local/lib/libfreetype.6.dylib",
            "libfreetype.6.dylib",
            "/opt/homebrew/lib/libfreetype.dylib",
            "/usr/local/lib/libfreetype.dylib",
            "libfreetype.dylib",
        },
        .windows => &[_][]const u8{
            "freetype.dll",
            "libfreetype-6.dll",
            "freetype6.dll",
        },
        else => &[_][]const u8{
            "libfreetype.so.6",
            "libfreetype.so",
        },
    };
}

/// Resolve the FreeType shared library and bind every required symbol.
///
/// Idempotent. After the first failure this returns the original error on
/// every later call: `error.LibraryUnavailable` when no candidate opened,
/// `error.MissingSymbol` when the file lacks a required entry point. The
/// loaded library is intentionally never unloaded, including after a partial
/// bind, so no bound pointer is ever left dangling.
pub fn ensureLoaded() error{ LibraryUnavailable, MissingSymbol }!void {
    return runtime.ensure(candidates(), c.loadDynamic);
}

/// True once `ensureLoaded` has succeeded. Test/introspection helper.
pub fn isLoaded() bool {
    return runtime.isLoaded();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "ensureLoaded loads the system FreeType and binds functions" {
    try ensureLoaded();
    try std.testing.expect(isLoaded());

    // A trivial bound entry point pair; would be a null call without the
    // loader. This mirrors what `raster_ft.Library.init` relies on.
    var handle: c.FT_Library = undefined;
    if (c.FT_Init_FreeType(&handle) != c.FT_Err_Ok)
        return error.FreeTypeInitFailed;
    _ = c.FT_Done_FreeType(handle);

    // The negative cache must not turn a successful load into a failure.
    try ensureLoaded();
    try std.testing.expect(isLoaded());
}

/// Test bind hook: binds two real symbols through the generated binder, then
/// fails exactly like a library missing the next symbol would (partial bind).
fn bindThenFail(lib: *dynload.Library) LoadError!void {
    try c.loadDynamicSymbols(lib, &.{
        "FT_Init_FreeType",
        "FT_Done_FreeType",
    });
    return error.MissingSymbol;
}

test "a missing symbol is retained and the partially bound library stays loaded" {
    var rt: Runtime = .{};
    try std.testing.expectError(error.MissingSymbol, rt.ensure(candidates(), bindThenFail));
    try std.testing.expectEqual(Runtime.State.failed, rt.state);
    try std.testing.expectEqual(error.MissingSymbol, rt.first_error.?);
    // The library opened and both FT entry points above were assigned before
    // the failure; they must not have been closed out from under those
    // pointers.
    try std.testing.expect(rt.library != null);
    var handle: c.FT_Library = undefined;
    try std.testing.expect(c.FT_Init_FreeType(&handle) == c.FT_Err_Ok);
    _ = c.FT_Done_FreeType(handle);

    // The second call reports the original cause, not a generic failure.
    try std.testing.expectError(error.MissingSymbol, rt.ensure(candidates(), bindThenFail));
    try std.testing.expectEqual(error.MissingSymbol, rt.first_error.?);
}

test "a missing library failure is retained verbatim" {
    var rt: Runtime = .{};
    const missing = [_][]const u8{"libcozmic-missing-library-9f3d.so"};
    try std.testing.expectError(error.LibraryUnavailable, rt.ensure(&missing, c.loadDynamic));
    try std.testing.expectError(error.LibraryUnavailable, rt.ensure(&missing, c.loadDynamic));
    try std.testing.expectEqual(error.LibraryUnavailable, rt.first_error.?);
    try std.testing.expect(rt.library == null);
}

test "concurrent first load is serialized" {
    var rt: Runtime = .{};
    var failed = std.atomic.Value(bool).init(false);
    const Worker = struct {
        fn load(target: *Runtime, did_fail: *std.atomic.Value(bool)) void {
            target.ensure(candidates(), c.loadDynamic) catch {
                did_fail.store(true, .release);
                return;
            };
        }
    };
    var thread = try std.Thread.spawn(.{}, Worker.load, .{ &rt, &failed });
    Worker.load(&rt, &failed);
    thread.join();

    try std.testing.expect(!failed.load(.acquire));
    try std.testing.expect(rt.state == .loaded);
    try std.testing.expect(rt.library != null);
}
