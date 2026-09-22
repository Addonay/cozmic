//! Real HarfBuzz shaping backend for `shape.zig`'s `ShapeAdapter` seam.
//!
//! Built on the vendored `harfbuzz` binding module (`src/harfbuzz/`, exposed
//! as the `harfbuzz` build module): blobs, faces, fonts and buffers go through
//! `hb.Blob` / `hb.Face` / `hb.Font` / `hb.Buffer`, and shaping through
//! `hb.shape`. Only APIs the wrapper does not surface are called through
//! `hb.c.hb_*` (face creation/upem); the font queries the wrapper also lacks
//! live as thin methods in `harfbuzz/font.zig` instead of hand-written externs
//! here.
//!
//! Ownership: `Backend.addFont` copies the font bytes and owns the copy until
//! `deinit`, which destroys HarfBuzz fonts/faces *before* freeing those bytes.
//! `Backend.addFontSource` registers a path instead: the file is not read
//! until the first shaping/raster query through `ensureLoaded`, so a desktop
//! font database can be registered without loading every font's bytes. A
//! failed lazy load is negatively cached (`load_error`) and degrades to
//! missing glyphs (`map_glyph` 0, `advance_em` 0, `probe_pair` count 0) or
//! `error.FontUnavailable` for `shape_run`; it never panics. `Backend.canUse`
//! reports which ids are still usable (false for unknown ids and negative
//! caches), so a caller with alternatives (`FontSystem`'s resolver) can skip a
//! broken source instead of re-selecting it on every run. `ensureLoaded`
//! retries a negatively cached source once, so a file that reappears (stale
//! fontconfig cache, package reinstalled) recovers.
//! Values returned by `Backend.adapter()` borrow the backend: the backend must
//! outlive the adapter and every shaping call through it.
//!
//! Failure policy: the vtable error set is fixed by `shape.zig`
//! (`ShapeError`), so shaping through an *unregistered* font id still panics
//! with a descriptive message instead of silently returning an empty run,
//! while a *selected but unloadable* source returns `error.FontUnavailable`.
//! Because the resolver skips ids with a cached failure (`canUse` is false
//! for them), `FontUnavailable` is only reported when a required source
//! cannot be loaded, not as a side effect of an unrelated broken entry in the
//! database. OOM is transient: it is surfaced without being cached, so the
//! next call retries. `fallback_font` returns `null` (font fallback is not
//! wired to a font database yet).
//!
//! Wiring point in `shape.zig`: replace `CharmapAdapter` with
//! `Backend.adapter()`; `shapeFallback`/`shapeRun` already implement plan
//! caching, tab rewrite, missing-glyph collection and end adjustment around
//! this vtable.
//!
//! Fallback memoization (perf): the resolver's `fallback_for` is wrapped by a
//! bounded selection cache. `Backend` implements the optional
//! `ShapeAdapter.note_fallback` hook, which `shape.zig` calls after every
//! successful fallback shape with `covered = true` when the splice replaced
//! at least one missing glyph. A covering font becomes the entry's
//! `preferred` font and is returned for attempt 0 of later runs. When the
//! preferred font misses part of a new word, the ordered resolver scan still
//! runs (with the preferred font skipped, so no candidate is shaped twice);
//! it is never trusted as exhaustive ("limited trust"). A run whose candidate
//! shapes covered *nothing* and that never had a preferred font marks the key
//! `uncovered`, so later attempt-0 queries answer `null` without reshaping the
//! candidate list. Keys with a preferred font are never marked uncovered.
//!
//! Cache key: (`FontFamilyKind`, family name, weight, stretch, style, script)
//! — the shaping-relevant `FontQuery` attrs plus the run's primary script.
//! `FontMatchAttrs` (font_system.zig) is the canonical equivalent, but it
//! lives on the far side of this file's import edge, so the fields are
//! mirrored here (same hash/eql semantics; name compared exactly, not
//! hashed-only, so a collision can never suppress a fallback).
//!
//! Bounds + invalidation: at most `FALLBACK_MEMO_CAP` (256) entries; the map
//! is cleared wholesale past the cap and reused (same policy as
//! `FontSystem.matches_cache`), so a long session cannot grow without limit.
//! `addFont`/`addFontSource` (including replacement of an existing id) clear
//! the memo, as does a lazy source recovering from a failed load, so a newly
//! registered font that covers a script is always scanned. Entry allocation
//! failures degrade to "not memoized" — a performance cache, never a shaping
//! error or a dropped glyph. Without a resolver, or when `note_fallback` is
//! never driven (direct `fallbackFor` probing), the memo records nothing and
//! `fallback_for` stays stateless.

const std = @import("std");
const attrs_mod = @import("attrs.zig");
const font_mod = @import("font.zig");
const shape_mod = @import("shape.zig");
const hb = @import("harfbuzz");

/// Runtime HarfBuzz version string, e.g. `"14.1.0"`. Loads the shared library
/// on first use; returns `""` when HarfBuzz cannot be loaded (the fallible
/// entry point is `Backend.init`, which surfaces `error.LibraryUnavailable`).
pub fn version() []const u8 {
    hb.dyn.ensureLoaded() catch return "";
    return hb.versionString();
}

// ---------------------------------------------------------------------------
// Backend
// ---------------------------------------------------------------------------

/// Upper bound for lazily reading a single font file (64 MiB), matching the
/// other font readers in this port.
pub const MAX_SOURCE_BYTES: usize = 1 << 26;

/// Where a registered font's bytes come from. All memory (the byte copy or
/// the path string) is owned by the `FontEntry`.
pub const FontSource = union(enum) {
    /// Eagerly registered owned bytes (`addFont`); loaded immediately.
    bytes: []u8,
    /// Lazily loaded file registered by `addFontSource`; read on first use.
    path: struct {
        path: []u8,
        index: u32,
    },
};

/// A registered font: its source plus the HarfBuzz objects built from it.
/// `ascent`/`descent` are EM units (descent positive, per `shape.rs:157`
/// advanced-path convention); `monospace_width` is the caller-supplied advance
/// of a space in EM units. Lazy (`.path`) entries start with `loaded = false`
/// and default metrics; `ensureLoaded` fills them in.
pub const FontEntry = struct {
    id: u32,
    source: FontSource,
    /// Owned font bytes once loaded. For `.bytes` sources this aliases
    /// `source.bytes`; for `.path` sources it is the lazily read file.
    blob: ?[]u8 = null,
    face: ?hb.Face = null,
    font: ?hb.Font = null,
    /// True once blob/face/font and the metric fields below are populated.
    loaded: bool = false,
    /// Negative cache: a failed lazy load is not retried on every call.
    load_error: bool = false,
    /// One extra attempt is allowed after a negative-cache hit, so a file
    /// that reappears clears `load_error`; a second failure stays cached.
    /// Reset when a load succeeds.
    load_retried: bool = false,
    upem: u32 = 0,
    ascent: f32 = 0.8,
    descent: f32 = 0.2,
    monospace_width: ?f32 = null,
    monospaced: bool = false,
    italic_or_oblique: bool = false,
    /// Design-unit decoration metrics from the face's `post`/`OS/2` tables
    /// (null when the sfnt tables are absent; `decorationMetrics` then uses
    /// the cosmic-text fallbacks).
    underline: ?shape_mod.DecoSpec = null,
    strikethrough: ?shape_mod.DecoSpec = null,
    /// Ascent in design units, for `decorationMetrics`.
    ascent_units: f32 = 0,
    /// Weight currently applied to `font` through `hb_font_set_variations`,
    /// or null when no variation coordinate has been applied yet. That call
    /// marks the font dirty (variation normalization plus glyph/metrics cache
    /// invalidation) every time, so the per-character cmap/advance queries and
    /// per-run shaping must only pay it when the requested weight actually
    /// differs from the applied one. Static faces benefit identically: their
    /// coordinates never change after the first application.
    applied_weight: ?u16 = null,
};

/// Fontconfig/FreeType pack named-instance bits into the high half of
/// `FC_INDEX` (`(named_instance << 16) | face`), while `hb_face_create` takes
/// a plain collection face index. Registered indices keep the packed value
/// (the FreeType raster bridge owns that semantics); HarfBuzz face creation
/// masks it through this helper.
pub fn collectionIndex(index: u32) u32 {
    return index & 0xFFFF;
}

/// Process-wide lock serializing lazy font reads.
///
/// `readSourceFile` reads through `std.Io.Threaded.global_single_threaded`, a
/// process-wide `Io` instance that is **not** concurrency-safe. Two threads
/// owning independent `Backend`s could otherwise enter the read at the same
/// time; this lock serializes lazy loads (and the per-entry `loaded` /
/// `load_error` / `load_retried` transitions) across backends. General
/// shaping stays single-threaded by contract: concurrent `shape_run` /
/// `map_glyph` / `font_metrics` calls on one backend or adapter still race the
/// shared `hb.Buffer`, `current_weight` and entry objects, and `deinit` must
/// not run concurrently with any query.
var lazy_load_mutex = LazyLoadMutex{};

const LazyLoadMutex = struct {
    inner: std.atomic.Mutex = .unlocked,

    fn lock(self: *LazyLoadMutex) void {
        while (!self.inner.tryLock()) {
            std.Thread.yield() catch std.atomic.spinLoopHint();
        }
    }

    fn unlock(self: *LazyLoadMutex) void {
        self.inner.unlock();
    }
};

/// Read a lazily registered font file. `Backend` has no `std.Io` parameter,
/// so lazy loads go through the process-wide single-threaded I/O instance
/// (serialized by `lazy_load_mutex`); callers that own a real `Io` can still
/// register bytes eagerly. All I/O failures surface as
/// `error.FontUnavailable` (OOM is preserved).
fn readSourceFile(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(
        std.Io.Threaded.global_single_threaded.io(),
        path,
        allocator,
        .limited(MAX_SOURCE_BYTES),
    );
}

// ---------------------------------------------------------------------------
// Fallback memo (perf cache; see module header)
// ---------------------------------------------------------------------------

/// Upper bound on memo entries; past the cap the map is cleared wholesale and
/// reused (mirrors `FontSystem.MATCHES_CACHE_LIMIT`).
pub const FALLBACK_MEMO_CAP: usize = 256;

/// Upper bound on resolver probes while locating/skipping the memoized font;
/// guarantees no loop on a resolver that keeps yielding candidates.
pub const FALLBACK_PROBE_CAP: usize = 1024;

/// Memo key: shaping-relevant query attrs + the run's primary script. Mirrors
/// `FontMatchAttrs` (font_system.zig) plus `script`; `family_name` is owned by
/// the map key and borrowed in lookup keys.
pub const FallbackMemoKey = struct {
    family_kind: shape_mod.FontFamilyKind,
    family_name: []const u8,
    weight: u16,
    stretch: u8,
    style: u8,
    script: shape_mod.Script,
};

/// Memo value: first-try font and/or a trusted negative.
pub const FallbackMemoValue = struct {
    /// Font that most recently covered at least one missing glyph for this
    /// key; returned for attempt 0 of later runs.
    preferred: ?shape_mod.FontId = null,
    /// No candidate covered anything while scanning this key; later attempt-0
    /// queries answer `null` without rescanning. Never set while a
    /// `preferred` font exists (limited trust; see `memoMaybeMarkUncovered`).
    uncovered: bool = false,
};

/// Exact-match hash/eql (same field set as the key comparison in
/// `FontSystem.MatchContext`, plus `script`). The name is compared byte-wise,
/// never hashed-only, so a collision cannot produce a false negative.
pub const FallbackMemoContext = struct {
    pub fn hash(_: @This(), k: FallbackMemoKey) u64 {
        var h = std.hash.Wyhash.init(0);
        h.update(&[_]u8{@backingInt(k.family_kind)});
        h.update(std.mem.asBytes(&k.weight));
        h.update(&[_]u8{ k.stretch, k.style, @backingInt(k.script) });
        h.update(k.family_name);
        return h.final();
    }
    pub fn eql(_: @This(), a: FallbackMemoKey, b: FallbackMemoKey) bool {
        return a.family_kind == b.family_kind and
            a.weight == b.weight and
            a.stretch == b.stretch and
            a.style == b.style and
            a.script == b.script and
            std.mem.eql(u8, a.family_name, b.family_name);
    }
};

pub const FallbackMemoMap = std.HashMapUnmanaged(
    FallbackMemoKey,
    FallbackMemoValue,
    FallbackMemoContext,
    80,
);

pub const Backend = struct {
    allocator: std.mem.Allocator,
    buffer: hb.Buffer,
    entries: std.ArrayList(FontEntry) = .empty,
    /// Weight applied to every variation-aware HarfBuzz query
    /// (`ShapeAdapter.set_weight`). 400 = normal; static faces ignore it.
    current_weight: u16 = 400,
    /// Optional attr-driven font selection bridge owned by the caller
    /// (`FontSystem`). When null, `font_for` reports no match and
    /// `fallback_for` falls back to the script-only stub.
    resolver: ?Resolver = null,
    /// Bounded fallback-selection memo (see module header). Empty (and never
    /// consulted) without a resolver.
    fallback_memo: FallbackMemoMap = .empty,
    /// Persistent advanced-path shaped-run cache (shape.rs run cache; the
    /// adapter seam hands this out via `VTable.run_cache`). Lives on the
    /// backend so it survives Buffer/BufferLine churn — matches upstream,
    /// which stores its cache on `FontSystem`.
    run_cache: shape_mod.ShapeRunCache,
    /// When false, `runCacheFn` reports no cache and the advanced path runs
    /// uncached. Bench parity rows use this: upstream's equivalent
    /// `shape-run-cache` feature is default-off, so standard bench rows must
    /// not charge us lookups/inserts upstream never pays. Library consumers
    /// keep the default (`true`).
    run_cache_enabled: bool = true,
    /// Transient per-fallback-resolution flags, reset when `fallback_for` is
    /// asked for attempt 0 and consumed when the scan exhausts. Kept on the
    /// backend so `note_fallback` and `fallback_for` share them (shaping is
    /// single-threaded by contract; see `lazy_load_mutex`).
    memo_run_active: bool = false,
    memo_run_covered: bool = false,
    memo_run_saw_note: bool = false,

    /// Caller-owned font-selection callbacks (see `FontSystem.shaper`).
    pub const Resolver = struct {
        ctx: *anyopaque,
        font_for: *const fn (ctx: *anyopaque, query: shape_mod.FontQuery) ?shape_mod.FontId,
        fallback_for: *const fn (
            ctx: *anyopaque,
            query: shape_mod.FontQuery,
            script: shape_mod.Script,
            attempt: usize,
        ) ?shape_mod.FontId,
    };

    /// (Re)install the font-selection bridge. The ctx pointer must stay valid
    /// for as long as the adapter is used.
    pub fn setResolver(self: *Backend, resolver: ?Resolver) void {
        self.resolver = resolver;
    }

    pub fn init(allocator: std.mem.Allocator) !Backend {
        // Bind the HarfBuzz entry points before the first `c.hb_*` call; the
        // load is cached process-wide, so this is a no-op after the first
        // backend.
        try hb.dyn.ensureLoaded();
        const buffer = hb.Buffer.create() catch return error.OutOfMemory;
        return .{
            .allocator = allocator,
            .buffer = buffer,
            .run_cache = shape_mod.ShapeRunCache.init(allocator),
        };
    }

    pub fn deinit(self: *Backend) void {
        self.run_cache.deinit();
        self.clearFallbackMemo();
        self.fallback_memo.deinit(self.allocator);
        for (self.entries.items) |*e| self.destroyEntry(e);
        self.entries.deinit(self.allocator);
        self.buffer.destroy();
        self.resolver = null;
    }

    /// Register font `bytes` (face `index` inside a collection) under `id`.
    /// The bytes are copied; the caller keeps ownership of `bytes`.
    ///
    /// `index` may be a fontconfig/FreeType packed index
    /// (`(named_instance << 16) | collection_face`); only the low 16 bits are
    /// passed to HarfBuzz (see `collectionIndex`).
    ///
    /// `monospace_em_width` is the advance of a space in EM units supplied by
    /// the caller (see `FontEntry.monospace_width`); passing `null` marks the
    /// font as proportional. Registering an existing `id` replaces the old
    /// entry.
    pub fn addFont(
        self: *Backend,
        id: u32,
        bytes: []const u8,
        index: u32,
        italic_or_oblique: bool,
        monospace_em_width: ?f32,
    ) !void {
        const entry = try self.makeEntry(id, bytes, index, italic_or_oblique, monospace_em_width);
        try self.insertEntry(entry);
    }

    /// Register font file `path` (face `index` inside a collection) under
    /// `id` **without reading the file**. `index` may be a
    /// fontconfig/FreeType packed index (`(named_instance << 16) | face`);
    /// only the low 16 bits reach HarfBuzz (see `collectionIndex`). The bytes
    /// are read on the first shaping/raster query through `ensureLoaded`; a
    /// failed load degrades gracefully and is negatively cached. `monospaced`
    /// records the face's pitch as parsed by the caller (fontconfig
    /// `FC_SPACING` / `font_parse` `post`); the space advance itself is
    /// unknown until the file is read, so `monospace_width` stays `null` even
    /// for mono faces. The path is copied and owned by the entry. Registering
    /// an existing `id` replaces the old entry.
    pub fn addFontSource(
        self: *Backend,
        id: u32,
        path: []const u8,
        index: u32,
        italic_or_oblique: bool,
        monospaced: bool,
        monospace_em_width: ?f32,
    ) !void {
        const owned_path = try self.allocator.dupe(u8, path);
        const entry = FontEntry{
            .id = id,
            .source = .{ .path = .{ .path = owned_path, .index = index } },
            .monospace_width = monospace_em_width,
            .monospaced = monospaced,
            .italic_or_oblique = italic_or_oblique,
        };
        // `insertEntry` takes ownership and frees `owned_path` on failure.
        try self.insertEntry(entry);
    }

    /// Insert `entry`, replacing any existing entry with the same id. Takes
    /// ownership of `entry` in every case (including failure). Clears the
    /// fallback memo first: the usable candidate set changes, so previously
    /// memoized preferences/negatives may be stale (see module header).
    fn insertEntry(self: *Backend, entry: FontEntry) !void {
        self.clearFallbackMemo();
        for (self.entries.items) |*old| {
            if (old.id == entry.id) {
                self.destroyEntry(old);
                old.* = entry;
                return;
            }
        }
        self.entries.append(self.allocator, entry) catch |err| {
            var owned = entry;
            self.destroyEntry(&owned);
            return err;
        };
    }

    /// Ensure the (possibly lazy) font `id` has its HarfBuzz objects built.
    ///
    /// Returns `error.FontUnavailable` for a missing/unreadable/invalid
    /// source. A non-OOM failure is negatively cached (`load_error`) and one
    /// retry is attempted on the next call, so a file that reappears clears
    /// the cache. `error.OutOfMemory` is transient: it is returned without
    /// touching `load_error`/`load_retried`, so the next call tries again (an
    /// OOM on the single post-failure retry restores that retry instead of
    /// permanently poisoning the entry). Panics only for ids that were never
    /// registered (`entryFor`). Lazy reads are serialized by the module-level
    /// `lazy_load_mutex`; see the single-threaded shaping contract there.
    pub fn ensureLoaded(self: *Backend, id: shape_mod.FontId) shape_mod.ShapeError!void {
        return self.ensureEntryLoaded(self.entryFor(id));
    }

    fn ensureEntryLoaded(self: *Backend, entry: *FontEntry) shape_mod.ShapeError!void {
        if (entry.loaded) return;
        lazy_load_mutex.lock();
        defer lazy_load_mutex.unlock();
        if (entry.loaded) return;
        // Negative cache with a single escape hatch: the first touch after a
        // persistent failure re-attempts the load, so a font file that
        // reappeared (e.g. a stale fontconfig cache) recovers. Further
        // persistent failures keep failing until a load succeeds.
        const is_retry = entry.load_error;
        if (is_retry and entry.load_retried) return error.FontUnavailable;
        self.loadEntry(entry) catch |err| {
            if (isPersistentLoadFailure(err)) {
                entry.load_error = true;
                // Consume the retry only for a persistent failure; an OOM on
                // the retry leaves `load_retried` clear so the next call can
                // try again (transient OOM must not poison the entry).
                entry.load_retried = is_retry;
            }
            return err;
        };
        entry.load_error = false;
        entry.load_retried = false;
        // A source that was unusable is usable again: the candidate set
        // changed, so drop memoized selections (see module header).
        if (is_retry) self.clearFallbackMemo();
    }

    fn loadEntry(self: *Backend, entry: *FontEntry) shape_mod.ShapeError!void {
        const source = switch (entry.source) {
            // Eager sources are already loaded by `makeEntry`; recover if a
            // bytes entry was ever left unloaded instead of panicking.
            .bytes => |bytes| {
                entry.blob = bytes;
                populateLoaded(entry, 0) catch |err| {
                    entry.blob = null;
                    return mapLoadError(err);
                };
                return;
            },
            .path => |p| p,
        };
        const bytes = readSourceFile(self.allocator, source.path) catch |err| {
            return if (err == error.OutOfMemory) error.OutOfMemory else error.FontUnavailable;
        };
        entry.blob = bytes;
        populateLoaded(entry, source.index) catch |err| {
            entry.blob = null;
            self.allocator.free(bytes);
            return mapLoadError(err);
        };
    }

    fn mapLoadError(err: anyerror) shape_mod.ShapeError {
        return if (err == error.OutOfMemory) error.OutOfMemory else error.FontUnavailable;
    }

    /// OOM is transient: it must never be cached as a permanent font failure,
    /// so the next call retries. Every other load failure (missing file,
    /// unreadable path, invalid font data) is negative-cached.
    fn isPersistentLoadFailure(err: anyerror) bool {
        return err != error.OutOfMemory;
    }

    fn makeEntry(
        self: *Backend,
        id: u32,
        bytes: []const u8,
        index: u32,
        italic_or_oblique: bool,
        monospace_em_width: ?f32,
    ) !FontEntry {
        if (bytes.len == 0 or bytes.len > std.math.maxInt(c_uint)) return error.InvalidFont;
        const owned = try self.allocator.dupe(u8, bytes);
        errdefer self.allocator.free(owned);
        var entry = FontEntry{
            .id = id,
            .source = .{ .bytes = owned },
            .blob = owned,
            .monospace_width = monospace_em_width,
            .monospaced = monospace_em_width != null,
            .italic_or_oblique = italic_or_oblique,
        };
        try populateLoaded(&entry, index);
        return entry;
    }

    /// Build the HarfBuzz objects and metrics for `entry` from its blob
    /// (`entry.blob` must already be populated). On success `loaded` is true;
    /// on failure no objects remain owned by `entry` (its blob is left for
    /// the caller, which owns it in both `makeEntry` and `loadEntry`).
    fn populateLoaded(entry: *FontEntry, index: u32) !void {
        std.debug.assert(!entry.loaded);
        const bytes = entry.blob orelse return error.InvalidFont;

        // READONLY: the blob does not own or modify `bytes`; the entry frees
        // it in destroyEntry() after the face is destroyed.
        var blob = hb.Blob.create(bytes, .readonly) catch return error.OutOfMemory;
        defer blob.destroy();

        // No wrapper constructor exists for `hb_face_create`. The index may
        // be a fontconfig/FreeType packed `(named_instance << 16) | face`
        // value; HarfBuzz only understands the collection face index, so mask
        // the high bits (the raster path keeps the full packed index).
        var face = hb.Face{
            .handle = hb.c.hb_face_create(blob.handle, @intCast(collectionIndex(index))) orelse
                return error.InvalidFont,
        };
        errdefer face.destroy();

        const upem = hb.c.hb_face_get_upem(face.handle);
        if (upem == 0) return error.InvalidFont;

        var font = hb.Font.create(face) catch return error.OutOfMemory;
        errdefer font.destroy();
        font.setOtFuncs();
        font.setScale(upem, upem);

        // Scale read-back doubles as an ABI smoke test for set/get scale.
        var x_scale: c_int = 0;
        var y_scale: c_int = 0;
        font.getScale(&x_scale, &y_scale);
        std.debug.assert(x_scale == @as(c_int, @intCast(upem)) and
            y_scale == @as(c_int, @intCast(upem)));

        const upem_f: f32 = @floatFromInt(upem);
        var ascent: f32 = 0.8;
        var descent: f32 = 0.2;
        var ascent_units: f32 = 0.8 * upem_f;
        var extents: hb.c.hb_font_extents_t = undefined;
        if (font.getHExtents(&extents)) {
            ascent = @as(f32, @floatFromInt(extents.ascender)) / upem_f;
            // HarfBuzz reports the descender negative; `shape.rs:157` negates
            // the font descender for the advanced shaping path, so store the
            // positive EM descent the layout engine expects.
            descent = -@as(f32, @floatFromInt(extents.descender)) / upem_f;
            ascent_units = @floatFromInt(extents.ascender);
        }

        // Design-unit decoration metrics for `decorationMetrics`
        // (shape.rs:710-731); defaults are only used when the sfnt parse
        // failed (source == .defaults).
        const sniffed = font_mod.sniffMetrics(bytes);
        const has_face_metrics = sniffed.source == .sniffed;

        entry.face = face;
        entry.font = font;
        // Fresh hb_font_t: no wght coordinate applied yet.
        entry.applied_weight = null;
        entry.upem = upem;
        entry.ascent = ascent;
        entry.descent = descent;
        entry.underline = if (has_face_metrics) .{
            .offset = sniffed.metrics.underline_offset,
            .thickness = sniffed.metrics.underline_thickness,
        } else null;
        entry.strikethrough = if (has_face_metrics) .{
            .offset = sniffed.metrics.strikeout_offset,
            .thickness = sniffed.metrics.strikeout_thickness,
        } else null;
        entry.ascent_units = ascent_units;
        entry.loaded = true;
    }

    fn destroyEntry(self: *Backend, entry: *FontEntry) void {
        if (entry.font) |*font| font.destroy();
        if (entry.face) |*face| face.destroy();
        switch (entry.source) {
            // `entry.blob` aliases `source.bytes` for eager entries, so free
            // the source allocation exactly once.
            .bytes => |bytes| self.allocator.free(bytes),
            .path => |p| {
                if (entry.blob) |bytes| self.allocator.free(bytes);
                self.allocator.free(p.path);
            },
        }
    }

    /// Number of entries whose HarfBuzz objects are loaded (eager entries and
    /// successfully loaded lazy ones). Test/consumer introspection.
    pub fn loadedCount(self: *const Backend) usize {
        var count: usize = 0;
        for (self.entries.items) |*e| {
            if (e.loaded) count += 1;
        }
        return count;
    }

    /// True when `id` is registered and still usable as a shaping/raster
    /// source: eager entries, loaded lazy entries and not-yet-loaded lazy
    /// entries all qualify. False for unknown ids and for entries with a
    /// cached load failure (`load_error`), so a caller that owns alternatives
    /// (e.g. `FontSystem`'s resolver) can skip a broken source instead of
    /// re-selecting it on every run. Non-poisoning: never reads the file and
    /// never clears `load_error`; a successful retry through `ensureLoaded`
    /// makes the id usable again.
    pub fn canUse(self: *const Backend, id: shape_mod.FontId) bool {
        for (self.entries.items) |*e| {
            if (e.id == id) return !e.load_error;
        }
        return false;
    }

    /// Registered source path for a lazy entry; `null` for unknown ids and
    /// eager (bytes) entries.
    pub fn sourcePath(self: *const Backend, id: shape_mod.FontId) ?[]const u8 {
        for (self.entries.items) |*e| {
            if (e.id != id) continue;
            return switch (e.source) {
                .bytes => null,
                .path => |p| p.path,
            };
        }
        return null;
    }

    /// Registered bytes for `id` once loaded, or `null` for unknown ids and
    /// lazy entries that have not been loaded yet.
    pub fn fontBytes(self: *const Backend, id: shape_mod.FontId) ?[]const u8 {
        for (self.entries.items) |*e| {
            if (e.id == id) return e.blob;
        }
        return null;
    }

    // -----------------------------------------------------------------------
    // Fallback memo (see module header for design/bounds/invalidation)
    // -----------------------------------------------------------------------

    /// Drop every memo entry (keys are owned), keeping the map allocation.
    /// Called on font registration, on recovery of a failed lazy load, and
    /// when the cap is reached.
    pub fn clearFallbackMemo(self: *Backend) void {
        var it = self.fallback_memo.keyIterator();
        while (it.next()) |key| self.allocator.free(key.family_name);
        self.fallback_memo.clearRetainingCapacity();
    }

    /// Number of live memo entries (introspection/tests).
    pub fn fallbackMemoSize(self: *const Backend) usize {
        return self.fallback_memo.count();
    }

    fn memoKey(query: shape_mod.FontQuery, script: shape_mod.Script) FallbackMemoKey {
        return .{
            .family_kind = query.family_kind,
            .family_name = query.family_name,
            .weight = query.weight,
            .stretch = query.stretch,
            .style = query.style,
            .script = script,
        };
    }

    /// Borrowed-key lookup; never allocates.
    fn memoGet(self: *Backend, query: shape_mod.FontQuery, script: shape_mod.Script) ?*FallbackMemoValue {
        return self.fallback_memo.getPtr(memoKey(query, script));
    }

    /// Get-or-insert with an owned copy of the family name. On OOM the memo is
    /// skipped (`null`); the caller then runs without memoizing. This is a
    /// performance cache, never a correctness dependency, so the failure is
    /// not surfaced (the shape path has no error channel for it anyway).
    fn memoGetOrPut(self: *Backend, query: shape_mod.FontQuery, script: shape_mod.Script) ?*FallbackMemoValue {
        if (self.fallback_memo.count() >= FALLBACK_MEMO_CAP) self.clearFallbackMemo();
        const owned_name = self.allocator.dupe(u8, query.family_name) catch return null;
        var key = memoKey(query, script);
        key.family_name = owned_name;
        const gop = self.fallback_memo.getOrPut(self.allocator, key) catch {
            self.allocator.free(owned_name);
            return null;
        };
        if (gop.found_existing) {
            self.allocator.free(owned_name);
        } else {
            // `getOrPut` leaves a fresh value uninitialized.
            gop.value_ptr.* = .{};
        }
        return gop.value_ptr;
    }

    /// Record that `font` covered at least one missing glyph for `query` +
    /// `script`; it becomes the first candidate for later runs and clears any
    /// negative entry. OOM degrades to "not memoized".
    fn memoNoteCovered(
        self: *Backend,
        query: shape_mod.FontQuery,
        script: shape_mod.Script,
        font: shape_mod.FontId,
    ) void {
        const entry = self.memoGetOrPut(query, script) orelse return;
        entry.preferred = font;
        entry.uncovered = false;
    }

    /// Mark a key negative when a complete scan produced zero coverage and no
    /// font was ever preferred. Gated on `note_fallback` having been driven so
    /// direct `fallback_for` probing (tests, embedders) stays stateless; a key
    /// with a `preferred` font is never marked (limited trust: the memoized
    /// font keeps its first try and the ordered scan still runs after a miss).
    fn memoMaybeMarkUncovered(
        self: *Backend,
        query: shape_mod.FontQuery,
        script: shape_mod.Script,
    ) void {
        if (!(self.memo_run_active and self.memo_run_saw_note and !self.memo_run_covered)) return;
        const entry = self.memoGetOrPut(query, script) orelse return;
        if (entry.preferred != null) return;
        entry.uncovered = true;
    }

    /// Usable index of `target` in the resolver's ordered candidate sequence
    /// (attempt 0 yields usable index 1, since `font_for` owns index 0), or
    /// `null` when `target` is no longer in the sequence. The resolver
    /// contract makes probing side-effect free (see `font_system.zig`).
    fn probeUsableIndex(
        self: *Backend,
        resolver: Resolver,
        query: shape_mod.FontQuery,
        script: shape_mod.Script,
        target: shape_mod.FontId,
    ) ?usize {
        _ = self;
        var attempt: usize = 0;
        while (attempt < FALLBACK_PROBE_CAP) : (attempt += 1) {
            const cand = resolver.fallback_for(resolver.ctx, query, script, attempt) orelse return null;
            if (cand == target) return attempt + 1;
        }
        return null;
    }

    /// Resolver fallback starting at underlying `attempt`, skipping `skip`
    /// (the memoized font already tried at attempt 0 of this resolution). The
    /// probe guard bounds misbehaving resolvers that keep yielding `skip`.
    fn resolveSkipping(
        self: *Backend,
        resolver: Resolver,
        query: shape_mod.FontQuery,
        script: shape_mod.Script,
        attempt: usize,
        skip: shape_mod.FontId,
    ) ?shape_mod.FontId {
        _ = self;
        var a = attempt;
        var guard: usize = 0;
        while (guard < FALLBACK_PROBE_CAP) : (guard += 1) {
            const cand = resolver.fallback_for(resolver.ctx, query, script, a) orelse return null;
            if (cand != skip) return cand;
            a += 1;
        }
        return null;
    }

    /// Memoized `fallback_for`: attempt 0 returns the preferred font (or
    /// `null` for a trusted negative); later attempts continue the resolver's
    /// ordered scan with the preferred font skipped.
    fn fallbackForMemo(
        self: *Backend,
        resolver: Resolver,
        query: shape_mod.FontQuery,
        script: shape_mod.Script,
        attempt: usize,
    ) ?shape_mod.FontId {
        if (attempt == 0) {
            self.memo_run_active = true;
            self.memo_run_covered = false;
            self.memo_run_saw_note = false;
        }
        if (self.memoGet(query, script)) |entry| {
            if (entry.uncovered) return null;
            if (entry.preferred) |memo_font| {
                if (!self.canUse(memo_font)) {
                    // Face became unusable: scan normally; drop the stale
                    // preference so later words do not pay for the lookup.
                    entry.preferred = null;
                } else if (attempt == 0) {
                    return memo_font;
                } else if (self.probeUsableIndex(resolver, query, script, memo_font)) |usable_index| {
                    // `usable_index - 1` is the underlying attempt that would
                    // yield the memoized font; shift by one past it (see
                    // `probeUsableIndex`).
                    const raw = if (attempt <= usable_index - 1) attempt - 1 else attempt;
                    if (self.resolveSkipping(resolver, query, script, raw, memo_font)) |font| {
                        return font;
                    }
                    self.memoMaybeMarkUncovered(query, script);
                    return null;
                } else {
                    // The font left the candidate sequence (e.g. a load
                    // failure); continue with the plain scan.
                    entry.preferred = null;
                }
            }
        }
        const res = resolver.fallback_for(resolver.ctx, query, script, attempt);
        if (res == null) self.memoMaybeMarkUncovered(query, script);
        return res;
    }

    fn entryFor(self: *Backend, font: shape_mod.FontId) *FontEntry {
        for (self.entries.items) |*e| {
            if (e.id == font) return e;
        }
        std.debug.panic("hb_backend: font id {d} is not registered; call addFont first", .{font});
    }

    /// Borrowing adapter over this backend. `fallback_font` is not wired yet
    /// and always returns `null`; `primary_font` is the first registered
    /// entry's id (0 when the backend is empty).
    pub fn adapter(self: *Backend) shape_mod.ShapeAdapter {
        return .{ .ptr = self, .vtable = &vtable };
    }
};

// ---------------------------------------------------------------------------
// ShapeAdapter vtable
// ---------------------------------------------------------------------------

const vtable: shape_mod.ShapeAdapter.VTable = .{
    .shape_run = shapeRunFn,
    .map_glyph = mapGlyphFn,
    .advance_em = advanceEmFn,
    .font_metrics = fontMetricsFn,
    .primary_font = primaryFontFn,
    .set_weight = setWeightFn,
    .font_for = fontForFn,
    .repatch_font = repatchFontFn,
    .fallback_for = fallbackForFn,
    .fallback_font = fallbackFontFn,
    .probe_pair = probePairFn,
    .note_fallback = noteFallbackFn,
    .run_cache = runCacheFn,
};

fn runCacheFn(ptr: *anyopaque) ?*shape_mod.ShapeRunCache {
    const self: *Backend = @ptrCast(@alignCast(ptr));
    if (!self.run_cache_enabled) return null;
    return &self.run_cache;
}

/// Apply `weight` as the OpenType `wght` variation coordinate on `entry`'s
/// HarfBuzz font. Non-variable fonts ignore variation coordinates.
fn applyWeight(entry: *FontEntry, weight: u16) void {
    // Callers run `ensureLoaded` first; guard anyway so an unloaded entry can
    // never dereference a null font.
    const font = entry.font orelse return;
    // Set-on-change only: hb_font_set_variations invalidates the font's
    // normalized-coordinate and glyph caches on every call, so re-setting an
    // already-applied weight on each cmap/advance query or shape run would
    // destroy exactly the caches the next call wants to reuse.
    if (entry.applied_weight == weight) return;
    var variation = hb.c.hb_variation_t{
        .tag = hb.c.HB_TAG('w', 'g', 'h', 't'),
        .value = @floatFromInt(weight),
    };
    hb.c.hb_font_set_variations(font.handle, &variation, 1);
    entry.applied_weight = weight;
}

fn setWeightFn(ptr: *anyopaque, weight: u16) void {
    const self: *Backend = @ptrCast(@alignCast(ptr));
    self.current_weight = weight;
}

fn shapeRunImpl(
    self: *Backend,
    alloc: std.mem.Allocator,
    font: shape_mod.FontId,
    text: []const u8,
    rtl: bool,
) shape_mod.ShapeError![]shape_mod.ShapedRunGlyph {
    if (text.len == 0) return alloc.alloc(shape_mod.ShapedRunGlyph, 0);
    std.debug.assert(text.len <= std.math.maxInt(c_int));
    const entry = self.entryFor(font);
    try self.ensureEntryLoaded(entry);
    applyWeight(entry, self.current_weight);

    self.buffer.reset();
    self.buffer.setDirection(if (rtl) .rtl else .ltr);
    self.buffer.addUTF8(text);
    self.buffer.guessSegmentProperties();
    hb.shape(entry.font.?, self.buffer, null);

    const len = self.buffer.getLength();
    const infos = self.buffer.getGlyphInfos();
    // `hb_buffer_get_glyph_positions` only returns NULL from a buffer message
    // callback (never our case) or for an empty buffer; the old extern-based
    // code asserted on a length mismatch and skipped the copy loop instead of
    // indexing a null pointer.
    const positions_opt = self.buffer.getGlyphPositions();
    std.debug.assert(len == infos.len and (positions_opt != null or len == 0));

    var out: std.ArrayList(shape_mod.ShapedRunGlyph) = .empty;
    errdefer out.deinit(alloc);
    const count: usize = @intCast(len);
    try out.ensureTotalCapacity(alloc, count);
    if (positions_opt) |positions| {
        std.debug.assert(count == positions.len);
        const upem_f: f32 = @floatFromInt(entry.upem);
        var i: usize = 0;
        while (i < count) : (i += 1) {
            const info = infos[i];
            const pos = positions[i];
            // HarfBuzz emits horizontal runs in visual order (RTL clusters run
            // right-to-left), matching the CharmapAdapter convention that
            // `adjustGlyphEnds` and the BiDi reorder rely on.
            out.appendAssumeCapacity(.{
                .glyph_id = if (info.codepoint > std.math.maxInt(u16)) 0 else @intCast(info.codepoint),
                .cluster = info.cluster,
                .x_advance = @as(f32, @floatFromInt(pos.x_advance)) / upem_f,
                .y_advance = @as(f32, @floatFromInt(pos.y_advance)) / upem_f,
                .x_offset = @as(f32, @floatFromInt(pos.x_offset)) / upem_f,
                .y_offset = @as(f32, @floatFromInt(pos.y_offset)) / upem_f,
            });
        }
    }
    return out.toOwnedSlice(alloc);
}

fn shapeRunFn(
    ptr: *anyopaque,
    alloc: std.mem.Allocator,
    font: shape_mod.FontId,
    text: []const u8,
    rtl: bool,
) shape_mod.ShapeError![]shape_mod.ShapedRunGlyph {
    const self: *Backend = @ptrCast(@alignCast(ptr));
    return shapeRunImpl(self, alloc, font, text, rtl);
}

fn mapGlyphImpl(self: *Backend, font: shape_mod.FontId, cp: u21) u16 {
    const entry = self.entryFor(font);
    // Unloadable lazy source: report the codepoint as missing glyph 0.
    self.ensureEntryLoaded(entry) catch return 0;
    applyWeight(entry, self.current_weight);
    const glyph = entry.font.?.getNominalGlyph(cp) orelse return 0;
    // The seam stores glyph ids as u16; oversized ids are reported missing.
    if (glyph > std.math.maxInt(u16)) return 0;
    return @intCast(glyph);
}

fn mapGlyphFn(ptr: *anyopaque, font: shape_mod.FontId, cp: u21) u16 {
    const self: *Backend = @ptrCast(@alignCast(ptr));
    return mapGlyphImpl(self, font, cp);
}

fn advanceEmFn(ptr: *anyopaque, font: shape_mod.FontId, glyph_id: u16) f32 {
    const self: *Backend = @ptrCast(@alignCast(ptr));
    const entry = self.entryFor(font);
    // Unloadable lazy source: zero advance instead of panicking.
    self.ensureEntryLoaded(entry) catch return 0;
    applyWeight(entry, self.current_weight);
    const advance = entry.font.?.getHAdvance(glyph_id);
    return @as(f32, @floatFromInt(advance)) / @as(f32, @floatFromInt(entry.upem));
}

fn fontMetricsFn(ptr: *anyopaque, font: shape_mod.FontId) shape_mod.ShapingFontMetrics {
    const self: *Backend = @ptrCast(@alignCast(ptr));
    const entry = self.entryFor(font);
    // Unloadable lazy source: fall back to the stored (default) metrics so
    // layout keeps a sane line height instead of panicking.
    self.ensureEntryLoaded(entry) catch return .{
        .ascent = entry.ascent,
        .descent = entry.descent,
        .monospace_width = entry.monospace_width,
        .italic_or_oblique = entry.italic_or_oblique,
        .monospaced = entry.monospaced,
        .underline = entry.underline,
        .strikethrough = entry.strikethrough,
        .units_per_em = @floatFromInt(entry.upem),
        .ascent_units = entry.ascent_units,
    };
    return .{
        .ascent = entry.ascent,
        .descent = entry.descent,
        .monospace_width = entry.monospace_width,
        .italic_or_oblique = entry.italic_or_oblique,
        .monospaced = entry.monospaced,
        .underline = entry.underline,
        .strikethrough = entry.strikethrough,
        .units_per_em = @floatFromInt(entry.upem),
        .ascent_units = entry.ascent_units,
    };
}

fn primaryFontFn(ptr: *anyopaque) shape_mod.FontId {
    const self: *Backend = @ptrCast(@alignCast(ptr));
    if (self.entries.items.len == 0) return 0;
    return self.entries.items[0].id;
}

/// Font fallback is not wired to a font database yet: always exhausted.
/// Kept for backends that only install the legacy `fallback_font` hook.
fn fallbackFontFn(ptr: *anyopaque, script: shape_mod.Script, attempt: usize) ?shape_mod.FontId {
    _ = ptr;
    _ = script;
    _ = attempt;
    return null;
}

/// Attr-driven primary selection through the installed resolver.
fn fontForFn(ptr: *anyopaque, query: shape_mod.FontQuery) ?shape_mod.FontId {
    const self: *Backend = @ptrCast(@alignCast(ptr));
    const resolver = self.resolver orelse return null;
    return resolver.font_for(resolver.ctx, query);
}

/// Generic sans/mono repatch font for Basic shaping; same resolution as
/// `font_for`, but this hook is only consulted for missing-glyph repatching.
fn repatchFontFn(ptr: *anyopaque, query: shape_mod.FontQuery) ?shape_mod.FontId {
    return fontForFn(ptr, query);
}

/// Attr-driven fallback selection through the installed resolver; falls back
/// to the legacy script-only hook when no resolver is installed.
fn fallbackForFn(
    ptr: *anyopaque,
    query: shape_mod.FontQuery,
    script: shape_mod.Script,
    attempt: usize,
) ?shape_mod.FontId {
    const self: *Backend = @ptrCast(@alignCast(ptr));
    if (self.resolver) |resolver| {
        return self.fallbackForMemo(resolver, query, script, attempt);
    }
    return fallbackFontFn(ptr, script, attempt);
}

/// Fallback-memo observer: `shape.zig` reports every successful fallback
/// shape with whether it covered a previously missing glyph. Sets the
/// transient run flags consumed by `memoMaybeMarkUncovered` and records the
/// covering font as preferred. A negative note also arms the run as "saw a
/// note", so a later exhaustion can be trusted as a full zero-coverage scan.
fn noteFallbackFn(
    ptr: *anyopaque,
    query: shape_mod.FontQuery,
    script: shape_mod.Script,
    font: shape_mod.FontId,
    covered: bool,
) void {
    const self: *Backend = @ptrCast(@alignCast(ptr));
    self.memo_run_saw_note = true;
    if (!covered) return;
    self.memo_run_covered = true;
    self.memoNoteCovered(query, script, font);
}

fn probePairFn(ptr: *anyopaque, font: shape_mod.FontId, c1: u21, c2: u21) shape_mod.ProbeResult {
    const self: *Backend = @ptrCast(@alignCast(ptr));
    const entry = self.entryFor(font);
    // Unloadable lazy source: conservative empty probe with zero ids.
    self.ensureEntryLoaded(entry) catch return .{ .count = 0 };
    applyWeight(entry, self.current_weight);
    const charmap_ids: [2]u16 = .{ mapGlyphImpl(self, font, c1), mapGlyphImpl(self, font, c2) };
    var pair: [8]u8 = undefined;
    var n: usize = 0;
    n += @as(usize, std.unicode.utf8Encode(c1, pair[n..]) catch 0);
    n += @as(usize, std.unicode.utf8Encode(c2, pair[n..]) catch 0);
    if (n == 0) return .{ .count = 0, .shaped_ids = .{ 0, 0 }, .charmap_ids = charmap_ids };

    const shaped = shapeRunImpl(self, self.allocator, font, pair[0..n], false) catch {
        // Conservative: count < 2 makes `probeKeepsPair` keep the pair joined.
        return .{ .count = 0, .shaped_ids = .{ 0, 0 }, .charmap_ids = charmap_ids };
    };
    defer self.allocator.free(shaped);

    var result: shape_mod.ProbeResult = .{ .count = shaped.len, .charmap_ids = charmap_ids };
    if (shaped.len >= 1) result.shaped_ids[0] = shaped[0].glyph_id;
    if (shaped.len >= 2) result.shaped_ids[1] = shaped[1].glyph_id;
    return result;
}

// ===========================================================================
// Tests
// ===========================================================================

/// Load a checked-in font fixture from the package `tests/fonts` directory.
/// Returns `error.SkipZigTest` only when the fixture file is absent.
fn readFixture(alloc: std.mem.Allocator, comptime name: []const u8) ![]u8 {
    const candidates = [_][]const u8{
        "tests/fonts/" ++ name,
        "../tests/fonts/" ++ name,
        "src/../tests/fonts/" ++ name,
    };
    for (candidates) |path| {
        if (std.Io.Dir.cwd().readFileAlloc(std.testing.io, path, alloc, .limited(1 << 24))) |bytes| {
            return bytes;
        } else |err| {
            if (err != error.FileNotFound) return err;
        }
    }
    return error.SkipZigTest;
}

/// Locate a checked-in fixture **path** (not bytes) for `addFontSource`.
/// Returns `error.SkipZigTest` only when none of the candidates exists.
fn fixtureSourcePath(comptime name: []const u8) ![]const u8 {
    const candidates = [_][]const u8{
        "tests/fonts/" ++ name,
        "../tests/fonts/" ++ name,
        "src/../tests/fonts/" ++ name,
    };
    for (candidates) |path| {
        if (std.Io.Dir.cwd().access(std.testing.io, path, .{})) |_| {
            return path;
        } else |err| {
            if (err != error.FileNotFound) return err;
        }
    }
    return error.SkipZigTest;
}

/// Read/write big-endian u16/u32 from a byte buffer (TTC builder below).
fn readU16BE(buf: []const u8, at: usize) u16 {
    return (@as(u16, buf[at]) << 8) | @as(u16, buf[at + 1]);
}

fn readU32BE(buf: []const u8, at: usize) u32 {
    return (@as(u32, buf[at]) << 24) |
        (@as(u32, buf[at + 1]) << 16) |
        (@as(u32, buf[at + 2]) << 8) |
        @as(u32, buf[at + 3]);
}

fn writeU32BE(buf: []u8, at: usize, value: u32) void {
    buf[at] = @intCast(value >> 24);
    buf[at + 1] = @intCast((value >> 16) & 0xFF);
    buf[at + 2] = @intCast((value >> 8) & 0xFF);
    buf[at + 3] = @intCast(value & 0xFF);
}

fn align4(n: usize) usize {
    return (n + 3) & ~@as(usize, 3);
}

/// Build a minimal valid TTC collection from `face` bytes repeated `count`
/// times (real collection fixture stand-in). Each copy's table-directory
/// offsets are rebased to the TTC file start, as the OpenType collection
/// format requires; table data stays shared per copy.
fn buildTestTtc(alloc: std.mem.Allocator, face: []const u8, count: usize) ![]u8 {
    const header_len = 12 + count * 4;
    var total = header_len;
    for (0..count) |_| total = align4(total) + face.len;
    const buf = try alloc.alloc(u8, total);
    errdefer alloc.free(buf);
    @memcpy(buf[0..4], "ttcf");
    writeU32BE(buf, 4, 0x00010000);
    writeU32BE(buf, 8, @intCast(count));
    var off: usize = header_len;
    for (0..count) |i| {
        off = align4(off);
        writeU32BE(buf, 12 + i * 4, @intCast(off));
        @memcpy(buf[off .. off + face.len], face);
        // `face`'s own table records are offsets from its start; in a
        // collection they are absolute from the TTC start.
        const num_tables = readU16BE(buf, off + 4);
        var ti: usize = 0;
        while (ti < num_tables) : (ti += 1) {
            const record = off + 12 + ti * 16;
            const rel = readU32BE(buf, record + 8);
            writeU32BE(buf, record + 8, @intCast(off + rel));
        }
        off += face.len;
    }
    return buf;
}

fn addFixtureFont(
    backend: *Backend,
    alloc: std.mem.Allocator,
    comptime name: []const u8,
    id: shape_mod.FontId,
    italic_or_oblique: bool,
    mono_width: ?f32,
) !void {
    const bytes = try readFixture(alloc, name);
    defer alloc.free(bytes);
    try backend.addFont(id, bytes, 0, italic_or_oblique, mono_width);
}

fn testAttrsList(alloc: std.mem.Allocator) !attrs_mod.AttrsList {
    var defaults = attrs_mod.Attrs.init(alloc);
    defer defaults.deinit();
    return attrs_mod.AttrsList.init(alloc, &defaults);
}

test "HarfBuzz link probe: version string and addFont" {
    try std.testing.expect(version().len > 0);

    const alloc = std.testing.allocator;
    const bytes = try readFixture(alloc, "Inter-Regular.ttf");
    defer alloc.free(bytes);

    var backend = try Backend.init(alloc);
    defer backend.deinit();
    try backend.addFont(shape_mod.PRIMARY_FONT_ID, bytes, 0, false, null);
    try std.testing.expectEqual(@as(usize, 1), backend.entries.items.len);
    const entry = backend.entries.items[0];
    try std.testing.expect(entry.upem > 0);
    try std.testing.expect(entry.ascent > 0);
    try std.testing.expect(entry.descent > 0);
    try std.testing.expect(!entry.monospaced);
    try std.testing.expect(entry.monospace_width == null);
}

test "translated hb_glyph_info_t/hb_glyph_position_t ABI sizes" {
    try std.testing.expectEqual(@as(usize, 20), @sizeOf(hb.c.hb_glyph_info_t));
    try std.testing.expectEqual(@as(usize, 20), @sizeOf(hb.c.hb_glyph_position_t));
    try std.testing.expectEqual(@as(usize, 48), @sizeOf(hb.c.hb_font_extents_t));
    try std.testing.expectEqual(@as(usize, 0), @offsetOf(hb.c.hb_glyph_info_t, "codepoint"));
    try std.testing.expectEqual(@as(usize, 8), @offsetOf(hb.c.hb_glyph_info_t, "cluster"));
    try std.testing.expectEqual(@as(usize, 0), @offsetOf(hb.c.hb_glyph_position_t, "x_advance"));
    try std.testing.expectEqual(@as(usize, 12), @offsetOf(hb.c.hb_glyph_position_t, "y_offset"));
}

test "Inter LTR: shapeRun yields 5 advancing glyphs for Hello" {
    const alloc = std.testing.allocator;
    var backend = try Backend.init(alloc);
    defer backend.deinit();
    try addFixtureFont(&backend, alloc, "Inter-Regular.ttf", shape_mod.PRIMARY_FONT_ID, false, null);

    const adapter = backend.adapter();
    const glyphs = try adapter.shapeRun(alloc, shape_mod.PRIMARY_FONT_ID, "Hello", false);
    defer alloc.free(glyphs);

    try std.testing.expectEqual(@as(usize, 5), glyphs.len);
    var prev_cluster: ?usize = null;
    for (glyphs) |g| {
        try std.testing.expect(g.glyph_id != 0);
        try std.testing.expect(g.x_advance > 0);
        try std.testing.expectEqual(@as(f32, 0), g.y_advance);
        if (prev_cluster) |prev| try std.testing.expect(g.cluster > prev);
        prev_cluster = g.cluster;
    }
    try std.testing.expectEqual(@as(usize, 0), glyphs[0].cluster);
    try std.testing.expectEqual(@as(usize, 4), glyphs[4].cluster);
}

test "vendored harfbuzz wrapper: Inter Hello shapes to 5 glyphs, adapter parity" {
    const alloc = std.testing.allocator;
    // This test drives the wrapper directly, without `Backend.init`.
    try hb.dyn.ensureLoaded();
    const bytes = try readFixture(alloc, "Inter-Regular.ttf");
    defer alloc.free(bytes);

    // Drive the wrapper's high-level API directly: Blob -> Face -> Font ->
    // Buffer -> shape.
    var blob = try hb.Blob.create(bytes, .readonly);
    defer blob.destroy();
    var face = hb.Face{
        .handle = hb.c.hb_face_create(blob.handle, 0) orelse
            return error.SkipZigTest,
    };
    defer face.destroy();
    var font = try hb.Font.create(face);
    defer font.destroy();
    font.setOtFuncs();
    const upem = hb.c.hb_face_get_upem(face.handle);
    font.setScale(upem, upem);

    var buffer = try hb.Buffer.create();
    defer buffer.destroy();
    buffer.addUTF8("Hello");
    buffer.guessSegmentProperties();
    hb.shape(font, buffer, null);

    const infos = buffer.getGlyphInfos();
    try std.testing.expectEqual(@as(usize, 5), infos.len);
    for (infos) |info| try std.testing.expect(info.codepoint != 0);
    const positions = buffer.getGlyphPositions() orelse return error.SkipZigTest;
    try std.testing.expectEqual(@as(usize, 5), positions.len);
    for (positions) |pos| try std.testing.expect(pos.x_advance > 0);

    // The adapter must produce the same glyph ids in the same order.
    var backend = try Backend.init(alloc);
    defer backend.deinit();
    try addFixtureFont(&backend, alloc, "Inter-Regular.ttf", shape_mod.PRIMARY_FONT_ID, false, null);
    const shaped = try backend.adapter().shapeRun(alloc, shape_mod.PRIMARY_FONT_ID, "Hello", false);
    defer alloc.free(shaped);
    try std.testing.expectEqual(@as(usize, 5), shaped.len);
    for (shaped, infos) |glyph, info| {
        try std.testing.expectEqual(@as(u32, glyph.glyph_id), info.codepoint);
    }
}

test "NotoSansArabic RTL: contextual forms, visual order" {
    const alloc = std.testing.allocator;
    var backend = try Backend.init(alloc);
    defer backend.deinit();
    try addFixtureFont(&backend, alloc, "NotoSansArabic.ttf", shape_mod.PRIMARY_FONT_ID, false, null);

    const adapter = backend.adapter();
    // "مرحبا" (marhaba). Observed with the checked-in font + HarfBuzz
    // 14.1.0: exactly 5 contextual forms (uniFE8E FE92 FEA3 FEAE FEE3), no
    // required ligature, emitted in visual order with byte clusters 8..0.
    const text = "\u{0645}\u{0631}\u{062D}\u{0628}\u{0627}";
    const glyphs = try adapter.shapeRun(alloc, shape_mod.PRIMARY_FONT_ID, text, true);
    defer alloc.free(glyphs);

    try std.testing.expectEqual(@as(usize, 5), glyphs.len);
    for (glyphs) |g| {
        try std.testing.expect(g.glyph_id != 0);
        try std.testing.expect(g.x_advance > 0);
    }
    var prev_cluster: usize = std.math.maxInt(usize);
    for (glyphs) |g| {
        try std.testing.expect(g.cluster < prev_cluster);
        prev_cluster = g.cluster;
    }
    try std.testing.expectEqual(@as(usize, 8), glyphs[0].cluster);
    try std.testing.expectEqual(@as(usize, 0), glyphs[4].cluster);
}

test "map_glyph, advance_em and font_metrics for Inter" {
    const alloc = std.testing.allocator;
    var backend = try Backend.init(alloc);
    defer backend.deinit();
    try addFixtureFont(&backend, alloc, "Inter-Regular.ttf", shape_mod.PRIMARY_FONT_ID, false, null);

    const adapter = backend.adapter();
    const glyph_a = adapter.mapGlyph(shape_mod.PRIMARY_FONT_ID, 'A');
    try std.testing.expect(glyph_a != 0);
    try std.testing.expect(adapter.advanceEm(shape_mod.PRIMARY_FONT_ID, glyph_a) > 0);
    // Missing codepoints map to .notdef (0).
    try std.testing.expectEqual(@as(u16, 0), adapter.mapGlyph(shape_mod.PRIMARY_FONT_ID, 0x10FFFD));

    const metrics = adapter.fontMetrics(shape_mod.PRIMARY_FONT_ID);
    try std.testing.expect(metrics.ascent > 0);
    try std.testing.expect(metrics.descent > 0);
    try std.testing.expect(metrics.monospace_width == null);
    try std.testing.expect(!metrics.monospaced);
    try std.testing.expect(!metrics.italic_or_oblique);
    // Font-provided decoration metrics flow through the adapter
    // (shape.rs:710-731) instead of the hardcoded fallbacks.
    try std.testing.expectEqual(@as(f32, @floatFromInt(backend.entries.items[0].upem)), metrics.units_per_em);
    try std.testing.expect(metrics.underline != null);
    try std.testing.expect(metrics.strikethrough != null);
    try std.testing.expect(metrics.underline.?.thickness > 0);
    try std.testing.expectEqual(shape_mod.PRIMARY_FONT_ID, adapter.primaryFont());
    try std.testing.expectEqual(@as(?shape_mod.FontId, null), adapter.fallbackFont(.latin, 0));
}

test "InterVariable: wght 900 shapes wider than wght 400" {
    const alloc = std.testing.allocator;
    var backend = try Backend.init(alloc);
    defer backend.deinit();
    try addFixtureFont(&backend, alloc, "InterVariable.ttf", shape_mod.PRIMARY_FONT_ID, false, null);

    const adapter = backend.adapter();
    const text = "Hamburgefonstiv";

    adapter.setWeight(400);
    const regular = try adapter.shapeRun(alloc, shape_mod.PRIMARY_FONT_ID, text, false);
    defer alloc.free(regular);
    var regular_total: f32 = 0;
    try std.testing.expect(regular.len > 0);
    for (regular) |g| {
        try std.testing.expect(g.glyph_id != 0);
        regular_total += g.x_advance;
    }

    adapter.setWeight(900);
    const black = try adapter.shapeRun(alloc, shape_mod.PRIMARY_FONT_ID, text, false);
    defer alloc.free(black);
    var black_total: f32 = 0;
    try std.testing.expect(black.len > 0);
    for (black) |g| {
        try std.testing.expect(g.glyph_id != 0);
        black_total += g.x_advance;
    }

    try std.testing.expect(regular_total > 0);
    try std.testing.expect(black_total > 0);
    // Inter's `wght` axis changes advance widths, so the shaped run must not
    // be byte-identical across the range.
    try std.testing.expect(@abs(black_total - regular_total) > 0.001);

    // The non-shaping queries must stay consistent (and must not panic) after
    // a weight change: the font funcs are re-queried with the same variation
    // coordinates.
    const glyph_a = adapter.mapGlyph(shape_mod.PRIMARY_FONT_ID, 'A');
    try std.testing.expect(glyph_a != 0);
    try std.testing.expect(adapter.advanceEm(shape_mod.PRIMARY_FONT_ID, glyph_a) > 0);
    const probe = adapter.probePair(shape_mod.PRIMARY_FONT_ID, 'a', 'b');
    try std.testing.expectEqual(@as(usize, 2), probe.count);
    try std.testing.expect(probe.shaped_ids[0] != 0 and probe.shaped_ids[1] != 0);
}

test "probe_pair reports shaped and charmap ids" {
    const alloc = std.testing.allocator;
    var backend = try Backend.init(alloc);
    defer backend.deinit();
    try addFixtureFont(&backend, alloc, "Inter-Regular.ttf", shape_mod.PRIMARY_FONT_ID, false, null);

    const adapter = backend.adapter();
    const probe = adapter.probePair(shape_mod.PRIMARY_FONT_ID, 'a', 'b');
    try std.testing.expectEqual(@as(usize, 2), probe.count);
    try std.testing.expect(probe.shaped_ids[0] != 0);
    try std.testing.expect(probe.shaped_ids[1] != 0);
    try std.testing.expectEqual(probe.charmap_ids[0], probe.shaped_ids[0]);
    try std.testing.expectEqual(probe.charmap_ids[1], probe.shaped_ids[1]);
}

test "integration: ShapeLine.build + layoutToBuffer over HarfBuzz" {
    const alloc = std.testing.allocator;
    var backend = try Backend.init(alloc);
    defer backend.deinit();
    try addFixtureFont(&backend, alloc, "Inter-Regular.ttf", shape_mod.PRIMARY_FONT_ID, false, null);

    var attrs = try testAttrsList(alloc);
    defer attrs.deinit();
    var buf = shape_mod.ShapeBuffer.init();
    defer buf.deinit(alloc);
    var line = shape_mod.ShapeLine{};
    defer line.deinit(alloc);

    try line.build(alloc, backend.adapter(), &buf, "hello world", &attrs, .advanced, 4, .left_to_right);
    try std.testing.expectEqual(@as(usize, 1), line.spans.len);
    // "hello", the peeled space, "world".
    try std.testing.expectEqual(@as(usize, 3), line.spans[0].words.len);
    var glyph_count: usize = 0;
    for (line.spans[0].words) |w| glyph_count += w.glyphs.len;
    try std.testing.expectEqual(@as(usize, 11), glyph_count);

    var out: std.ArrayList(shape_mod.LayoutLine) = .empty;
    defer {
        for (out.items) |*l| l.deinit();
        out.deinit(alloc);
    }
    try line.layoutToBuffer(alloc, &buf, 16, null, .none, .{ .none = {} }, null, &out, null, .disabled);
    try std.testing.expectEqual(@as(usize, 1), out.items.len);
    try std.testing.expect(out.items[0].glyphs.items.len > 0);
    try std.testing.expect(out.items[0].w > 0);
}

test "lazy addFontSource: no load at registration, loaded on first shape" {
    const alloc = std.testing.allocator;
    const path = try fixtureSourcePath("Inter-Regular.ttf");

    var backend = try Backend.init(alloc);
    defer backend.deinit();
    try backend.addFontSource(shape_mod.PRIMARY_FONT_ID, path, 0, false, false, null);

    // Registration must not read the file or build HB objects.
    try std.testing.expectEqual(@as(usize, 0), backend.loadedCount());
    try std.testing.expect(backend.canUse(shape_mod.PRIMARY_FONT_ID));
    try std.testing.expectEqualStrings(path, backend.sourcePath(shape_mod.PRIMARY_FONT_ID).?);
    try std.testing.expect(backend.fontBytes(shape_mod.PRIMARY_FONT_ID) == null);

    // First shape loads exactly that face.
    const adapter = backend.adapter();
    const glyphs = try adapter.shapeRun(alloc, shape_mod.PRIMARY_FONT_ID, "Hello", false);
    defer alloc.free(glyphs);
    try std.testing.expectEqual(@as(usize, 5), glyphs.len);
    for (glyphs) |g| try std.testing.expect(g.glyph_id != 0);
    try std.testing.expectEqual(@as(usize, 1), backend.loadedCount());
    try std.testing.expect(backend.fontBytes(shape_mod.PRIMARY_FONT_ID) != null);

    // Non-shaping queries reuse the loaded objects: still one loaded entry.
    const glyph_a = adapter.mapGlyph(shape_mod.PRIMARY_FONT_ID, 'A');
    try std.testing.expect(glyph_a != 0);
    try std.testing.expect(adapter.advanceEm(shape_mod.PRIMARY_FONT_ID, glyph_a) > 0);
    try std.testing.expectEqual(@as(f32, @floatFromInt(backend.entries.items[0].upem)), adapter.fontMetrics(shape_mod.PRIMARY_FONT_ID).units_per_em);
    try std.testing.expectEqual(@as(usize, 1), backend.loadedCount());
}

test "lazy addFontSource failure: FontUnavailable, zero queries, negative cache" {
    const alloc = std.testing.allocator;
    var backend = try Backend.init(alloc);
    defer backend.deinit();
    try backend.addFontSource(
        shape_mod.PRIMARY_FONT_ID,
        "tests/fonts/cozmic-does-not-exist.ttf",
        0,
        false,
        false,
        null,
    );
    try std.testing.expectEqual(@as(usize, 0), backend.loadedCount());
    // Not yet attempted: usable in principle, so the resolver may try it.
    try std.testing.expect(backend.canUse(shape_mod.PRIMARY_FONT_ID));

    const adapter = backend.adapter();
    // Shaping is the only fallible query; it reports the missing source.
    try std.testing.expectError(
        error.FontUnavailable,
        adapter.shapeRun(alloc, shape_mod.PRIMARY_FONT_ID, "Hello", false),
    );
    // The failure is cached and the source is now known-unusable.
    try std.testing.expect(backend.entries.items[0].load_error);
    try std.testing.expect(!backend.canUse(shape_mod.PRIMARY_FONT_ID));
    try std.testing.expect(!backend.canUse(9999));
    // Everything else degrades to zero/missing instead of panicking.
    try std.testing.expectEqual(@as(u16, 0), adapter.mapGlyph(shape_mod.PRIMARY_FONT_ID, 'A'));
    try std.testing.expectEqual(@as(f32, 0), adapter.advanceEm(shape_mod.PRIMARY_FONT_ID, 5));
    try std.testing.expectEqual(
        @as(f32, 0),
        adapter.fontMetrics(shape_mod.PRIMARY_FONT_ID).units_per_em,
    );
    const probe = adapter.probePair(shape_mod.PRIMARY_FONT_ID, 'a', 'b');
    try std.testing.expectEqual(@as(usize, 0), probe.count);
    try std.testing.expectEqual(@as(u16, 0), probe.charmap_ids[0]);
    try std.testing.expectEqual(@as(u16, 0), probe.charmap_ids[1]);

    // Negative cache: the second call retries once, still fails, and never
    // loads the entry. The retry flag blocks every later unbounded retry.
    try std.testing.expectError(
        error.FontUnavailable,
        adapter.shapeRun(alloc, shape_mod.PRIMARY_FONT_ID, "Hello", false),
    );
    try std.testing.expectEqual(@as(usize, 0), backend.loadedCount());
    try std.testing.expect(backend.entries.items[0].load_error);
    try std.testing.expect(backend.entries.items[0].load_retried);
    try std.testing.expect(!backend.canUse(shape_mod.PRIMARY_FONT_ID));
}

test "lazy load failure retries once and recovers when the file reappears" {
    const alloc = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    // Relative to the test cwd (the package root), like the other scan
    // tests; `readSourceFile` opens it through `Dir.cwd()`.
    const rel = try std.fs.path.join(
        alloc,
        &.{ ".zig-cache", "tmp", &tmp.sub_path, "reappears.ttf" },
    );
    defer alloc.free(rel);

    var backend = try Backend.init(alloc);
    defer backend.deinit();
    try backend.addFontSource(shape_mod.PRIMARY_FONT_ID, rel, 0, false, false, null);
    const adapter = backend.adapter();

    try std.testing.expectError(
        error.FontUnavailable,
        adapter.shapeRun(alloc, shape_mod.PRIMARY_FONT_ID, "Hello", false),
    );
    try std.testing.expect(backend.entries.items[0].load_error);
    try std.testing.expect(!backend.canUse(shape_mod.PRIMARY_FONT_ID));

    // The font file appears after the first (negative-cached) failure.
    const bytes = try readFixture(alloc, "Inter-Regular.ttf");
    defer alloc.free(bytes);
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "reappears.ttf", .data = bytes });

    // The next touch retries once and recovers, clearing both flags.
    const glyphs = try adapter.shapeRun(alloc, shape_mod.PRIMARY_FONT_ID, "Hello", false);
    defer alloc.free(glyphs);
    try std.testing.expectEqual(@as(usize, 5), glyphs.len);
    for (glyphs) |g| try std.testing.expect(g.glyph_id != 0);
    try std.testing.expectEqual(@as(usize, 1), backend.loadedCount());
    const entry = &backend.entries.items[0];
    try std.testing.expect(!entry.load_error);
    try std.testing.expect(!entry.load_retried);
    try std.testing.expect(backend.canUse(shape_mod.PRIMARY_FONT_ID));

    // Subsequent queries reuse the loaded face without further reads.
    try std.testing.expect(adapter.mapGlyph(shape_mod.PRIMARY_FONT_ID, 'A') != 0);
    try std.testing.expectEqual(@as(usize, 1), backend.loadedCount());
}

test "lazy load OOM is transient and not cached as a permanent failure" {
    const alloc = std.testing.allocator;
    const path = try fixtureSourcePath("Inter-Regular.ttf");

    // The backend (and therefore the lazy file read) must allocate through
    // the failing allocator; `fail_index` is armed after registration so the
    // next allocation lands inside the file read.
    var failing = std.testing.FailingAllocator.init(alloc, .{});
    var backend = try Backend.init(failing.allocator());
    defer backend.deinit();
    try backend.addFontSource(shape_mod.PRIMARY_FONT_ID, path, 0, false, false, null);
    const adapter = backend.adapter();

    failing.fail_index = failing.alloc_index;
    try std.testing.expectError(
        error.OutOfMemory,
        adapter.shapeRun(alloc, shape_mod.PRIMARY_FONT_ID, "Hello", false),
    );
    const entry = &backend.entries.items[0];
    // OOM must not poison the entry: no negative cache, still usable.
    try std.testing.expect(!entry.load_error);
    try std.testing.expect(!entry.load_retried);
    try std.testing.expect(backend.canUse(shape_mod.PRIMARY_FONT_ID));

    // Once allocations succeed again, the very next call retries and loads.
    failing.fail_index = std.math.maxInt(usize);
    const glyphs = try adapter.shapeRun(alloc, shape_mod.PRIMARY_FONT_ID, "Hello", false);
    defer alloc.free(glyphs);
    try std.testing.expectEqual(@as(usize, 5), glyphs.len);
    for (glyphs) |g| try std.testing.expect(g.glyph_id != 0);
    try std.testing.expectEqual(@as(usize, 1), backend.loadedCount());
}

test "load failure classification: only OOM is transient" {
    try std.testing.expect(!Backend.isPersistentLoadFailure(error.OutOfMemory));
    try std.testing.expect(Backend.isPersistentLoadFailure(error.FileNotFound));
    try std.testing.expect(Backend.isPersistentLoadFailure(error.AccessDenied));
    try std.testing.expect(Backend.isPersistentLoadFailure(error.InvalidFont));
}

test "replacing a loaded lazy entry frees the old face and reloads" {
    const alloc = std.testing.allocator;
    const path_a = try fixtureSourcePath("Inter-Regular.ttf");
    const path_b = try fixtureSourcePath("NotoSans-Regular.ttf");

    var backend = try Backend.init(alloc);
    defer backend.deinit();
    try backend.addFontSource(shape_mod.PRIMARY_FONT_ID, path_a, 0, false, false, null);
    const adapter = backend.adapter();

    const first = try adapter.shapeRun(alloc, shape_mod.PRIMARY_FONT_ID, "Hello", false);
    defer alloc.free(first);
    try std.testing.expectEqual(@as(usize, 5), first.len);
    try std.testing.expectEqual(@as(usize, 1), backend.loadedCount());

    // Same id, different path: `insertEntry` destroys the loaded entry
    // (font, face, blob, path) before installing the new one. Running under
    // `std.testing.allocator` catches a leak or use-after-free here.
    try backend.addFontSource(shape_mod.PRIMARY_FONT_ID, path_b, 0, false, false, null);
    try std.testing.expectEqual(@as(usize, 1), backend.entries.items.len);
    try std.testing.expectEqual(@as(usize, 0), backend.loadedCount());
    try std.testing.expectEqualStrings(path_b, backend.sourcePath(shape_mod.PRIMARY_FONT_ID).?);

    const second = try adapter.shapeRun(alloc, shape_mod.PRIMARY_FONT_ID, "Hello", false);
    defer alloc.free(second);
    try std.testing.expectEqual(@as(usize, 5), second.len);
    for (second) |g| try std.testing.expect(g.glyph_id != 0);
    try std.testing.expectEqual(@as(usize, 1), backend.loadedCount());

    // The second face really is different (not a stale alias of the first).
    var identical = first.len == second.len;
    if (identical) {
        for (first, second) |a, b| {
            if (a.glyph_id != b.glyph_id or a.x_advance != b.x_advance) {
                identical = false;
                break;
            }
        }
    }
    try std.testing.expect(!identical);

    // Lazy -> eager replacement exercises the `.path` destroy branch while
    // the `.bytes` branch installs the new source.
    const bytes = try readFixture(alloc, "Inter-Regular.ttf");
    defer alloc.free(bytes);
    try backend.addFont(shape_mod.PRIMARY_FONT_ID, bytes, 0, false, null);
    try std.testing.expectEqual(@as(usize, 1), backend.entries.items.len);
    try std.testing.expectEqual(@as(usize, 1), backend.loadedCount());
    try std.testing.expect(backend.sourcePath(shape_mod.PRIMARY_FONT_ID) == null);
    const third = try adapter.shapeRun(alloc, shape_mod.PRIMARY_FONT_ID, "Hello", false);
    defer alloc.free(third);
    try std.testing.expectEqual(@as(usize, 5), third.len);
    for (third) |g| try std.testing.expect(g.glyph_id != 0);
}

test "packed fontconfig index masks to the collection face for HarfBuzz" {
    const alloc = std.testing.allocator;

    // `(named_instance << 16) | collection_face` -> collection face.
    try std.testing.expectEqual(@as(u32, 2), collectionIndex(0x0001_0002));
    try std.testing.expectEqual(@as(u32, 0), collectionIndex(0));
    try std.testing.expectEqual(@as(u32, 0xFFFF), collectionIndex(0x0000_FFFF));
    try std.testing.expectEqual(@as(u32, 0xFFFF), collectionIndex(0xABCD_FFFF));

    // No `.ttc` fixture is checked in, so build a real collection from the
    // Inter fixture (three copies; table offsets rebased to the file start).
    const face = try readFixture(alloc, "Inter-Regular.ttf");
    defer alloc.free(face);
    const ttc = try buildTestTtc(alloc, face, 3);
    defer alloc.free(ttc);
    try std.testing.expectEqual(@as(u32, 3), fontsInTestCollection(ttc));

    var backend = try Backend.init(alloc);
    defer backend.deinit();
    // The packed index must select collection face 2 (not 0x10002).
    try backend.addFont(shape_mod.PRIMARY_FONT_ID, ttc, 0x0001_0002, false, null);
    try std.testing.expect(backend.entries.items[0].upem > 0);
    const glyphs = try backend.adapter().shapeRun(alloc, shape_mod.PRIMARY_FONT_ID, "Hello", false);
    defer alloc.free(glyphs);
    try std.testing.expectEqual(@as(usize, 5), glyphs.len);
    for (glyphs) |g| {
        try std.testing.expect(g.glyph_id != 0);
        try std.testing.expect(g.x_advance > 0);
    }
}

fn fontsInTestCollection(ttc: []const u8) u32 {
    if (ttc.len < 12 or !std.mem.eql(u8, ttc[0..4], "ttcf")) return 0;
    return readU32BE(ttc, 8);
}

test "OOM on the post-failure retry does not permanently poison the entry" {
    const alloc = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const rel = try std.fs.path.join(
        alloc,
        &.{ ".zig-cache", "tmp", &tmp.sub_path, "retry-oom.ttf" },
    );
    defer alloc.free(rel);

    var failing = std.testing.FailingAllocator.init(alloc, .{});
    var backend = try Backend.init(failing.allocator());
    defer backend.deinit();
    try backend.addFontSource(shape_mod.PRIMARY_FONT_ID, rel, 0, false, false, null);
    const adapter = backend.adapter();

    // 1. Persistent failure (file absent) caches `load_error`, leaving the
    // single retry available.
    try std.testing.expectError(
        error.FontUnavailable,
        adapter.shapeRun(alloc, shape_mod.PRIMARY_FONT_ID, "Hello", false),
    );
    const entry = &backend.entries.items[0];
    try std.testing.expect(entry.load_error);
    try std.testing.expect(!entry.load_retried);

    // 2. The file reappears, but the retry hits OOM: the retry must be
    // restored, not consumed, or the entry would be poisoned forever.
    const bytes = try readFixture(alloc, "Inter-Regular.ttf");
    defer alloc.free(bytes);
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "retry-oom.ttf", .data = bytes });

    failing.fail_index = failing.alloc_index;
    try std.testing.expectError(
        error.OutOfMemory,
        adapter.shapeRun(alloc, shape_mod.PRIMARY_FONT_ID, "Hello", false),
    );
    try std.testing.expect(entry.load_error);
    try std.testing.expect(!entry.load_retried);
    // The source is still known-broken (resolver skips it), but the retry
    // escape hatch stays available for a direct shaping call.
    try std.testing.expect(!backend.canUse(shape_mod.PRIMARY_FONT_ID));

    // 3. Allocations work again: the next call retries and loads.
    failing.fail_index = std.math.maxInt(usize);
    const glyphs = try adapter.shapeRun(alloc, shape_mod.PRIMARY_FONT_ID, "Hello", false);
    defer alloc.free(glyphs);
    try std.testing.expectEqual(@as(usize, 5), glyphs.len);
    for (glyphs) |g| try std.testing.expect(g.glyph_id != 0);
    try std.testing.expect(!entry.load_error);
    try std.testing.expect(!entry.load_retried);
    try std.testing.expectEqual(@as(usize, 1), backend.loadedCount());
}
