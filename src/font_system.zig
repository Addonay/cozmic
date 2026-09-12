//! Port of cosmic-text `font/system.rs` (font database + match cache).
//!
//! Self-contained: defines local `Weight` / `Stretch` / `Style` / `Family`
//! aliases at the top instead of importing `attrs.zig`. Unify these aliases
//! with the attrs/font/fallback modules later; keep this file compiling
//! standalone until then.
//!
//! Full `Fallbacks` iteration lives in `fallback.zig` and real font parsing
//! in `font.zig` (unification TODOs below); this file owns database query,
//! `FontMatchKey` ordering, match-codepoint caches, and system-font loading.
//!
//! C-INTEROP WIRING POINTS (the only intended stubs):
//! - fontconfig: `loadSystemFonts` enumerates faces through the runtime
//!   loader in `fontconfig.zig` (lazy sources, no bytes); the per-file
//!   directory scan below is the cross-platform fallback.
//! - variable-weight matching: `FontMatchKey.init` reads the face's
//!   `variable_wght_min/max` (`fvar` via FreeType `FT_Get_MM_Var` / skrifa
//!   `axes().get_by_tag("wght")` in production); see `variableWeightMatch`.

const std = @import("std");
const builtin = @import("builtin");
const shape_hb = @import("shape_hb.zig");
const shape_mod = @import("shape.zig");
const font_parse = @import("font_parse.zig");
const fontconfig = @import("fontconfig.zig");

// ---------------------------------------------------------------------------
// Local aliases (do NOT import attrs.zig yet; see header TODO).
// ---------------------------------------------------------------------------

pub const Weight = u16;
pub const WEIGHT_NORMAL: Weight = 400;

pub const Stretch = enum(u8) {
    ultra_condensed = 1,
    extra_condensed = 2,
    condensed = 3,
    semi_condensed = 4,
    normal = 5,
    semi_expanded = 6,
    expanded = 7,
    extra_expanded = 8,
    ultra_expanded = 9,

    pub fn toNumber(self: Stretch) u16 {
        return @backingInt(self);
    }

    pub fn fromNumber(n: u16) ?Stretch {
        return switch (n) {
            1 => .ultra_condensed,
            2 => .extra_condensed,
            3 => .condensed,
            4 => .semi_condensed,
            5 => .normal,
            6 => .semi_expanded,
            7 => .expanded,
            8 => .extra_expanded,
            9 => .ultra_expanded,
            else => null,
        };
    }
};

pub const Style = enum(u8) {
    normal = 0,
    italic = 1,
    oblique = 2,
};

pub const FamilyTag = enum(u8) {
    name,
    serif,
    sans_serif,
    cursive,
    fantasy,
    monospace,
};

pub const Family = union(FamilyTag) {
    name: []const u8,
    serif: void,
    sans_serif: void,
    cursive: void,
    fantasy: void,
    monospace: void,
};

pub const FontId = u32;

pub const DEFAULT_MONO_FAMILY = "Noto Sans Mono";
pub const DEFAULT_SANS_FAMILY = "Open Sans";
pub const DEFAULT_SERIF_FAMILY = "DejaVu Serif";
pub const FALLBACK_LOCALE = "en-US";

/// Upper bound for reading a single font file (64 MiB), matching the other
/// font readers in this port.
pub const MAX_FONT_BYTES: usize = 1 << 26;

/// Attributes used for font matching (borrowed family name).
pub const AttrsForMatch = struct {
    family: Family,
    weight: Weight = WEIGHT_NORMAL,
    stretch: Stretch = .normal,
    style: Style = .normal,
};

// ---------------------------------------------------------------------------
// Face info + database.
// ---------------------------------------------------------------------------

/// Per-face metadata (mirrors the `fontdb::FaceInfo` subset cosmic-text
/// uses: id/path/index/families/post-script/weight/stretch/style/mono).
pub const FaceInfo = struct {
    id: FontId,
    path: []u8,
    index: u32,
    families: [][]u8,
    post_script_name: []u8,
    weight: Weight,
    stretch: Stretch,
    style: Style,
    monospaced: bool,
    /// Variable `wght`-axis range (from `fvar`/`FT_Get_MM_Var`); null when the
    /// face is not variable or the range is unknown. Used by
    /// `variableWeightMatch` / `FontMatchKey.init` (M2 wiring point).
    variable_wght_min: ?Weight = null,
    variable_wght_max: ?Weight = null,
};

/// Variable-weight coverage check (M2 wiring point).
/// Mirrors `FontMatchKey::new`'s `variable_weight_match` axis query
/// (`system.rs:38-44`): true when the wanted weight differs from the face's
/// nominal weight but lies inside the face's `wght` variation range.
/// Production wiring fills `variable_wght_min/max` from the font's `fvar`
/// table (FreeType `FT_Get_MM_Var` / skrifa `axes().get_by_tag("wght")`);
/// the comparison itself is already verbatim.
pub fn variableWeightMatch(wanted: Weight, nominal: Weight, wght_min: ?Weight, wght_max: ?Weight) bool {
    if (wanted == nominal) return false;
    const lo = wght_min orelse return false;
    const hi = wght_max orelse return false;
    const lo_u = if (lo <= hi) lo else hi;
    const hi_u = if (lo <= hi) hi else lo;
    return wanted >= lo_u and wanted <= hi_u;
}

/// Owned font database with `fontdb::Database::query` equivalent.
pub const FontDb = struct {
    faces: std.ArrayList(FaceInfo),
    next_id: FontId = 0,
    mono_family: []u8,
    sans_family: []u8,
    serif_family: []u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) std.mem.Allocator.Error!FontDb {
        const mono = try allocator.dupe(u8, DEFAULT_MONO_FAMILY);
        errdefer allocator.free(mono);
        const sans = try allocator.dupe(u8, DEFAULT_SANS_FAMILY);
        errdefer allocator.free(sans);
        const serif = try allocator.dupe(u8, DEFAULT_SERIF_FAMILY);
        errdefer allocator.free(serif);
        return .{
            .faces = .empty,
            .mono_family = mono,
            .sans_family = sans,
            .serif_family = serif,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *FontDb) void {
        for (self.faces.items) |*f| {
            self.allocator.free(f.path);
            for (f.families) |fam| self.allocator.free(fam);
            self.allocator.free(f.families);
            self.allocator.free(f.post_script_name);
        }
        self.faces.deinit(self.allocator);
        self.allocator.free(self.mono_family);
        self.allocator.free(self.sans_family);
        self.allocator.free(self.serif_family);
        self.* = undefined;
    }

    pub fn setMonoFamily(self: *FontDb, name: []const u8) std.mem.Allocator.Error!void {
        const duped = try self.allocator.dupe(u8, name);
        self.allocator.free(self.mono_family);
        self.mono_family = duped;
    }

    pub fn setSansFamily(self: *FontDb, name: []const u8) std.mem.Allocator.Error!void {
        const duped = try self.allocator.dupe(u8, name);
        self.allocator.free(self.sans_family);
        self.sans_family = duped;
    }

    pub fn setSerifFamily(self: *FontDb, name: []const u8) std.mem.Allocator.Error!void {
        const duped = try self.allocator.dupe(u8, name);
        self.allocator.free(self.serif_family);
        self.serif_family = duped;
    }

    pub fn addFace(
        self: *FontDb,
        path: []const u8,
        index: u32,
        families: []const []const u8,
        post_script_name: []const u8,
        weight: Weight,
        stretch: Stretch,
        style: Style,
        monospaced: bool,
    ) std.mem.Allocator.Error!FontId {
        const id = self.next_id;
        self.next_id += 1;
        const owned_path = try self.allocator.dupe(u8, path);
        errdefer self.allocator.free(owned_path);
        const owned_post = try self.allocator.dupe(u8, post_script_name);
        errdefer self.allocator.free(owned_post);
        var owned_families = try self.allocator.alloc([]u8, families.len);
        errdefer self.allocator.free(owned_families);
        // C4: only free slots that were actually initialized. Freeing the
        // whole slice on OOM would free uninitialized memory.
        var initialized: usize = 0;
        errdefer {
            for (owned_families[0..initialized]) |fam| self.allocator.free(fam);
        }
        for (families, 0..) |fam, i| {
            owned_families[i] = try self.allocator.dupe(u8, fam);
            initialized += 1;
        }
        try self.faces.append(self.allocator, .{
            .id = id,
            .path = owned_path,
            .index = index,
            .families = owned_families,
            .post_script_name = owned_post,
            .weight = weight,
            .stretch = stretch,
            .style = style,
            .monospaced = monospaced,
        });
        return id;
    }

    pub fn face(self: *const FontDb, id: FontId) ?*const FaceInfo {
        for (self.faces.items) |*f| {
            if (f.id == id) return f;
        }
        return null;
    }

    /// Parse face `index` of in-memory `bytes` and insert it, returning the new
    /// `FontId`. `path` is display/provenance only ("" for byte-registered
    /// fonts). Mirrors `fontdb::Database::load_font_source`.
    pub fn addFaceFromBytes(
        self: *FontDb,
        bytes: []const u8,
        index: u32,
        path: []const u8,
    ) (std.mem.Allocator.Error || font_parse.ParseError)!FontId {
        var meta = try font_parse.parseFaceMeta(self.allocator, bytes, index);
        defer meta.deinit();
        const fam_const = try self.allocator.alloc([]const u8, meta.families.len);
        defer self.allocator.free(fam_const);
        for (meta.families, 0..) |fam, i| fam_const[i] = fam;
        const style: Style = switch (meta.style) {
            .normal => .normal,
            .italic => .italic,
            .oblique => .oblique,
        };
        const stretch = Stretch.fromNumber(meta.stretch) orelse .normal;
        const id = try self.addFace(
            path,
            index,
            fam_const,
            meta.post_script_name,
            meta.weight,
            stretch,
            style,
            meta.monospaced,
        );
        if (meta.variable_wght_min) |min| {
            if (meta.variable_wght_max) |max| {
                _ = self.setVariableWghtRange(id, min, max);
            }
        }
        return id;
    }

    /// Read one font file and insert every face it contains (collections
    /// included). Per-file failures are counted, never fatal.
    pub fn loadFontFile(
        self: *FontDb,
        io: std.Io,
        path: []const u8,
        stats: *LoadStats,
    ) void {
        const bytes = std.Io.Dir.cwd().readFileAlloc(
            io,
            path,
            self.allocator,
            .limited(MAX_FONT_BYTES),
        ) catch {
            stats.file_errors += 1;
            return;
        };
        defer self.allocator.free(bytes);
        const count = font_parse.fontsInCollection(bytes);
        if (count == 0) {
            stats.file_errors += 1;
            return;
        }
        var index: u32 = 0;
        while (index < count) : (index += 1) {
            _ = self.addFaceFromBytes(bytes, index, path) catch {
                stats.file_errors += 1;
                continue;
            };
            stats.faces_added += 1;
        }
    }

    /// Recursively load every font file under `dir_path` (fontdb
    /// `Database::load_fonts_dir`). `dir_path` may be absolute or relative to
    /// the cwd. A missing directory is counted in `dirs_missing`.
    pub fn loadFontsDir(
        self: *FontDb,
        io: std.Io,
        dir_path: []const u8,
        stats: *LoadStats,
    ) void {
        var dir = if (std.fs.path.isAbsolute(dir_path))
            std.Io.Dir.openDirAbsolute(io, dir_path, .{ .iterate = true }) catch {
                stats.dirs_missing += 1;
                return;
            }
        else
            std.Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true }) catch {
                stats.dirs_missing += 1;
                return;
            };
        defer dir.close(io);
        stats.dirs_scanned += 1;
        var walker = dir.walk(self.allocator) catch {
            stats.file_errors += 1;
            return;
        };
        defer walker.deinit();
        while (true) {
            const entry_opt = walker.next(io) catch {
                stats.file_errors += 1;
                break;
            };
            const entry = entry_opt orelse break;
            if (entry.kind != .file) continue;
            if (!hasFontExtension(entry.basename)) continue;
            stats.files_seen += 1;
            const full = std.fs.path.join(self.allocator, &.{ dir_path, entry.path }) catch {
                stats.file_errors += 1;
                continue;
            };
            defer self.allocator.free(full);
            self.loadFontFile(io, full, stats);
        }
    }

    pub fn len(self: *const FontDb) usize {
        return self.faces.items.len;
    }

    /// Default family name for a generic selector.
    pub fn familyName(self: *const FontDb, family: Family) []const u8 {
        return switch (family) {
            .name => |n| n,
            .monospace => self.mono_family,
            .sans_serif => self.sans_family,
            .serif => self.serif_family,
            .cursive => self.sans_family,
            .fantasy => self.sans_family,
        };
    }

    pub fn faceContainsFamily(self: *const FontDb, id: FontId, name: []const u8) bool {
        const f = self.face(id) orelse return false;
        for (f.families) |fam| {
            if (std.mem.eql(u8, fam, name)) return true;
        }
        return false;
    }

    /// Set a face's variable `wght` range (M2 wiring point).
    /// Returns false for unknown ids. Production fills this from the font's
    /// `fvar` table at load time; tests use it to simulate variable fonts.
    pub fn setVariableWghtRange(self: *FontDb, id: FontId, min: Weight, max: Weight) bool {
        for (self.faces.items) |*f| {
            if (f.id == id) {
                f.variable_wght_min = min;
                f.variable_wght_max = max;
                return true;
            }
        }
        return false;
    }

    fn faceHasFamily(f: *const FaceInfo, name: []const u8) bool {
        for (f.families) |fam| {
            if (std.mem.eql(u8, fam, name)) return true;
        }
        return false;
    }

    fn familyMatches(self: *const FontDb, f: *const FaceInfo, family: Family) bool {
        switch (family) {
            .name => |n| {
                return faceHasFamily(f, n);
            },
            .monospace => return f.monospaced,
            // M1: generic families resolve via the configured default family
            // names (fontdb `set_*_family`), not "match any face". This keeps
            // `query(.sans_serif)` scoped to the sans default instead of
            // returning the globally closest weight/style face.
            .sans_serif => return faceHasFamily(f, self.sans_family),
            .serif => return faceHasFamily(f, self.serif_family),
            .cursive => return faceHasFamily(f, self.familyName(.cursive)),
            .fantasy => return faceHasFamily(f, self.familyName(.fantasy)),
        }
    }

    /// `fontdb::Database::query` equivalent for a single family.
    /// Among family-matching faces, picks the minimum by
    /// (weight_diff, stretch_diff, style_diff, id).
    pub fn query(
        self: *const FontDb,
        family: Family,
        weight: Weight,
        stretch: Stretch,
        style: Style,
    ) ?FontId {
        var best: ?FontId = null;
        var best_score: QueryScore = undefined;
        var first = true;
        for (self.faces.items) |*f| {
            if (!self.familyMatches(f, family)) continue;
            const score = QueryScore{
                .w = absDiffU16(weight, f.weight),
                .s = absDiffU16(stretch.toNumber(), f.stretch.toNumber()),
                .y = styleDiff(style, f.style),
                .id = f.id,
            };
            if (first or scoreLess(score, best_score)) {
                best = f.id;
                best_score = score;
                first = false;
            }
        }
        return best;
    }
};

const QueryScore = struct {
    w: u16,
    s: u16,
    y: u8,
    id: FontId,
};

fn scoreLess(a: QueryScore, b: QueryScore) bool {
    if (a.w != b.w) return a.w < b.w;
    if (a.s != b.s) return a.s < b.s;
    if (a.y != b.y) return a.y < b.y;
    return a.id < b.id;
}

fn absDiffU16(a: u16, b: u16) u16 {
    return if (a >= b) a - b else b - a;
}

fn styleDiff(wanted: Style, got: Style) u8 {
    if (wanted == got) return 0;
    return switch (wanted) {
        .italic => if (got == .oblique) @as(u8, 1) else @as(u8, 2),
        .oblique => if (got == .italic) @as(u8, 1) else @as(u8, 2),
        .normal => 2,
    };
}

fn isEmojiPostScript(post: []const u8) bool {
    return std.mem.containsAtLeast(u8, post, 1, "Emoji");
}

// ---------------------------------------------------------------------------
// FontMatchKey (field order is the sort order, exactly as Rust).
// ---------------------------------------------------------------------------

/// Sort key for fallback candidates.
///
/// Field declaration order IS the derived-`Ord` order in Rust
/// (`not_emoji`, `font_weight_diff`, `font_stretch_diff`,
/// `font_style_diff`, `font_weight`, `font_stretch`, `id`,
/// `variable_weight_match`), so keep this layout verbatim.
pub const FontMatchKey = struct {
    not_emoji: bool,
    font_weight_diff: u16,
    font_stretch_diff: u16,
    font_style_diff: u8,
    font_weight: u16,
    font_stretch: u16,
    id: FontId,
    variable_weight_match: bool,

    pub fn init(attrs: AttrsForMatch, face: *const FaceInfo) FontMatchKey {
        return .{
            .not_emoji = !isEmojiPostScript(face.post_script_name),
            .font_weight_diff = absDiffU16(attrs.weight, face.weight),
            .font_stretch_diff = absDiffU16(attrs.stretch.toNumber(), face.stretch.toNumber()),
            .font_style_diff = styleDiff(attrs.style, face.style),
            .font_weight = face.weight,
            .font_stretch = face.stretch.toNumber(),
            .id = face.id,
            // M2: variable-weight match when the wanted weight lies inside
            // the face's `wght` axis range despite a nominal diff.
            // `variable_wght_min/max` are filled from `fvar` at load time
            // (FreeType `FT_Get_MM_Var` / skrifa `axes().get_by_tag("wght")`);
            // see `variableWeightMatch` and `setVariableWghtRange`.
            .variable_weight_match = variableWeightMatch(
                attrs.weight,
                face.weight,
                face.variable_wght_min,
                face.variable_wght_max,
            ),
        };
    }

    pub fn lessThan(a: FontMatchKey, b: FontMatchKey) bool {
        // NOTE: this reproduces Rust's derived-`Ord` (lexicographic,
        // ascending per field) exactly, quirks included: `false < true`
        // means emoji faces (`not_emoji=false`) sort BEFORE non-emoji at
        // equal diffs. Do not "fix" the polarity here; parity beats intent.
        if (a.not_emoji != b.not_emoji) return !a.not_emoji and b.not_emoji;
        if (a.font_weight_diff != b.font_weight_diff) return a.font_weight_diff < b.font_weight_diff;
        if (a.font_stretch_diff != b.font_stretch_diff) return a.font_stretch_diff < b.font_stretch_diff;
        if (a.font_style_diff != b.font_style_diff) return a.font_style_diff < b.font_style_diff;
        if (a.font_weight != b.font_weight) return a.font_weight < b.font_weight;
        if (a.font_stretch != b.font_stretch) return a.font_stretch < b.font_stretch;
        if (a.id != b.id) return a.id < b.id;
        if (a.variable_weight_match != b.variable_weight_match) {
            return !a.variable_weight_match and b.variable_weight_match;
        }
        return false;
    }

    pub fn eql(a: FontMatchKey, b: FontMatchKey) bool {
        return a.not_emoji == b.not_emoji and
            a.font_weight_diff == b.font_weight_diff and
            a.font_stretch_diff == b.font_stretch_diff and
            a.font_style_diff == b.font_style_diff and
            a.font_weight == b.font_weight and
            a.font_stretch == b.font_stretch and
            a.id == b.id and
            a.variable_weight_match == b.variable_weight_match;
    }
};

fn matchKeyLess(_: void, a: FontMatchKey, b: FontMatchKey) bool {
    return a.lessThan(b);
}

// ---------------------------------------------------------------------------
// Match-attribute cache key.
// ---------------------------------------------------------------------------

pub const FontMatchAttrs = struct {
    family_tag: FamilyTag,
    family_name: []u8,
    weight: Weight,
    stretch: u16,
    style: u8,

    pub fn fromAttrs(allocator: std.mem.Allocator, attrs: AttrsForMatch) std.mem.Allocator.Error!FontMatchAttrs {
        const name: []const u8 = switch (attrs.family) {
            .name => |n| n,
            else => "",
        };
        return .{
            .family_tag = std.meta.activeTag(attrs.family),
            .family_name = try allocator.dupe(u8, name),
            .weight = attrs.weight,
            .stretch = attrs.stretch.toNumber(),
            .style = @backingInt(attrs.style),
        };
    }

    pub fn free(self: *FontMatchAttrs, allocator: std.mem.Allocator) void {
        allocator.free(self.family_name);
    }
};

pub const MatchContext = struct {
    pub fn hash(_: @This(), k: FontMatchAttrs) u64 {
        var h = std.hash.Wyhash.init(0);
        h.update(&[_]u8{@backingInt(k.family_tag)});
        h.update(std.mem.asBytes(&k.weight));
        h.update(std.mem.asBytes(&k.stretch));
        h.update(&[_]u8{k.style});
        h.update(k.family_name);
        return h.final();
    }
    pub fn eql(_: @This(), a: FontMatchAttrs, b: FontMatchAttrs) bool {
        return a.family_tag == b.family_tag and
            a.weight == b.weight and
            a.stretch == b.stretch and
            a.style == b.style and
            std.mem.eql(u8, a.family_name, b.family_name);
    }
};

// ---------------------------------------------------------------------------
// Codepoint support cache (per-font caps 512/1024, verbatim logic).
// ---------------------------------------------------------------------------

pub const CodepointSupport = struct {
    pub const SUPPORTED_MAX: usize = 512;
    pub const NOT_SUPPORTED_MAX: usize = 1024;

    supported: std.ArrayList(u32),
    not_supported: std.ArrayList(u32),

    pub fn init() CodepointSupport {
        return .{ .supported = .empty, .not_supported = .empty };
    }

    pub fn deinit(self: *CodepointSupport, allocator: std.mem.Allocator) void {
        self.supported.deinit(allocator);
        self.not_supported.deinit(allocator);
    }

    const Bound = struct {
        found: bool,
        pos: usize,
    };

    fn lowerBound(items: []const u32, v: u32) Bound {
        var lo: usize = 0;
        var hi: usize = items.len;
        while (lo < hi) {
            const mid = lo + (hi - lo) / 2;
            if (items[mid] < v) {
                lo = mid + 1;
            } else if (items[mid] > v) {
                hi = mid;
            } else {
                return .{ .found = true, .pos = mid };
            }
        }
        return .{ .found = false, .pos = lo };
    }

    fn unknownHas(
        self: *CodepointSupport,
        allocator: std.mem.Allocator,
        font_codepoints: []const u32,
        cp: u32,
        sup_pos: usize,
        not_pos: usize,
    ) std.mem.Allocator.Error!bool {
        var present = false;
        for (font_codepoints) |c| {
            if (c == cp) {
                present = true;
                break;
            }
        }
        if (present) {
            if (sup_pos != SUPPORTED_MAX) {
                try self.supported.insert(allocator, sup_pos, cp);
                if (self.supported.items.len > SUPPORTED_MAX) {
                    self.supported.items.len = SUPPORTED_MAX;
                }
            }
        } else {
            if (not_pos != NOT_SUPPORTED_MAX) {
                try self.not_supported.insert(allocator, not_pos, cp);
                if (self.not_supported.items.len > NOT_SUPPORTED_MAX) {
                    self.not_supported.items.len = NOT_SUPPORTED_MAX;
                }
            }
        }
        return present;
    }

    /// Mirrors `FontCachedCodepointSupportInfo::has_codepoint`.
    pub fn hasCodepoint(
        self: *CodepointSupport,
        allocator: std.mem.Allocator,
        font_codepoints: []const u32,
        cp: u32,
    ) std.mem.Allocator.Error!bool {
        const s = lowerBound(self.supported.items, cp);
        if (s.found) return true;
        const n = lowerBound(self.not_supported.items, cp);
        if (n.found) return false;
        return self.unknownHas(allocator, font_codepoints, cp, s.pos, n.pos);
    }
};

// ---------------------------------------------------------------------------
// Font system.
// ---------------------------------------------------------------------------

pub const FontCacheKey = struct {
    id: FontId,
    weight: Weight,
};

/// Placeholder for a loaded font entry.
/// Production wiring stores the real `font.zig` `Font` here
/// (see header unification TODO); the cache behavior (insert-once,
/// failed loads cached as null) is already exact.
pub const FontCacheEntry = struct {
    id: FontId,
    weight: Weight,
};

pub const LoadStats = struct {
    /// Directories opened and walked by the parse-based fallback scan.
    dirs_scanned: usize = 0,
    /// Directories the fallback scan could not open.
    dirs_missing: usize = 0,
    /// Font files encountered by the fallback directory walk.
    files_seen: usize = 0,
    /// Faces inserted into the database (fontconfig entries or scanned
    /// faces) and registered as lazy shaper sources.
    faces_added: usize = 0,
    /// Per-file/entry failures; never fatal.
    file_errors: usize = 0,
};

/// Host OS family used by system-font directory discovery.
pub const Platform = enum { linux, windows, macos, other };

/// Pure environment inputs for `resolveSystemFontDirs`; tests pass explicit
/// strings, `loadSystemFonts` passes the process env.
pub const SystemFontEnv = struct {
    xdg_data_home: ?[]const u8 = null,
    home: ?[]const u8 = null,
    windir: ?[]const u8 = null,
    local_appdata: ?[]const u8 = null,
};

/// Host platform at comptime (`.other` for unsupported/unix targets).
pub fn hostPlatform() Platform {
    return switch (builtin.os.tag) {
        .windows => .windows,
        .macos, .ios, .tvos, .watchos, .visionos, .driverkit, .maccatalyst => .macos,
        .linux, .freebsd, .netbsd, .openbsd, .dragonfly, .illumos => .linux,
        else => .other,
    };
}

/// System font directories per platform (owned: free each entry and the
/// slice). Missing/empty env values drop only their own entries:
/// - linux: `/usr/share/fonts`, `/usr/local/share/fonts`,
///   `$XDG_DATA_HOME/fonts` (or `$HOME/.local/share/fonts`), `$HOME/.fonts`
/// - windows: `%WINDIR%\Fonts`, `%LOCALAPPDATA%\Microsoft\Windows\Fonts`
///   (falling back to `$HOME/AppData/Local/Microsoft/Windows/Fonts` when
///   `LOCALAPPDATA` is missing)
/// - macos: `/System/Library/Fonts`, `/System/Library/Fonts/Supplemental`,
///   `/Library/Fonts`, `$HOME/Library/Fonts`
/// - other: empty
///
/// Joining always goes through `std.fs.path.join`, so the Windows branch
/// produces the host separator (tests assert the same `join` result).
pub fn resolveSystemFontDirs(
    allocator: std.mem.Allocator,
    platform: Platform,
    env: SystemFontEnv,
) std.mem.Allocator.Error![][]u8 {
    const xdg = nonEmpty(env.xdg_data_home);
    const home = nonEmpty(env.home);
    const windir = nonEmpty(env.windir);
    const local_appdata = nonEmpty(env.local_appdata);

    var dirs = std.ArrayList([]u8).empty;
    errdefer {
        for (dirs.items) |dir| allocator.free(dir);
        dirs.deinit(allocator);
    }
    switch (platform) {
        .linux => {
            try appendJoined(&dirs, allocator, &.{"/usr/share/fonts"});
            try appendJoined(&dirs, allocator, &.{"/usr/local/share/fonts"});
            if (xdg) |dir| {
                try appendJoined(&dirs, allocator, &.{ dir, "fonts" });
            } else if (home) |dir| {
                try appendJoined(&dirs, allocator, &.{ dir, ".local/share/fonts" });
            }
            if (home) |dir| try appendJoined(&dirs, allocator, &.{ dir, ".fonts" });
        },
        .windows => {
            if (windir) |dir| try appendJoined(&dirs, allocator, &.{ dir, "Fonts" });
            if (local_appdata) |dir| {
                try appendJoined(&dirs, allocator, &.{ dir, "Microsoft", "Windows", "Fonts" });
            } else if (home) |dir| {
                try appendJoined(&dirs, allocator, &.{ dir, "AppData", "Local", "Microsoft", "Windows", "Fonts" });
            }
        },
        .macos => {
            try appendJoined(&dirs, allocator, &.{"/System/Library/Fonts"});
            try appendJoined(&dirs, allocator, &.{"/System/Library/Fonts/Supplemental"});
            try appendJoined(&dirs, allocator, &.{"/Library/Fonts"});
            if (home) |dir| try appendJoined(&dirs, allocator, &.{ dir, "Library/Fonts" });
        },
        .other => {},
    }
    return dirs.toOwnedSlice(allocator);
}

fn nonEmpty(value: ?[]const u8) ?[]const u8 {
    const raw = value orelse return null;
    return if (raw.len == 0) null else raw;
}

/// Join `parts` (copying) and append the result; frees the copy if the
/// append itself fails.
fn appendJoined(
    dirs: *std.ArrayList([]u8),
    allocator: std.mem.Allocator,
    parts: []const []const u8,
) std.mem.Allocator.Error!void {
    const joined = try std.fs.path.join(allocator, parts);
    errdefer allocator.free(joined);
    try dirs.append(allocator, joined);
}

fn freeDirList(allocator: std.mem.Allocator, dirs: [][]u8) void {
    for (dirs) |dir| allocator.free(dir);
    allocator.free(dirs);
}

fn resolverFamily(query: shape_mod.FontQuery) Family {
    return switch (query.family_kind) {
        .name => .{ .name = query.family_name },
        .serif => .serif,
        .sans_serif => .sans_serif,
        .cursive => .cursive,
        .fantasy => .fantasy,
        .monospace => .monospace,
    };
}

fn resolverStyle(style: u8) Style {
    return switch (style) {
        1 => .italic,
        2 => .oblique,
        else => .normal,
    };
}

/// Attr-driven font-selection bridge installed on the HarfBuzz backend by
/// `FontSystem.shaper` (see `shape_hb.Backend.Resolver`). Only faces with a
/// registered shaper source (eager `addFontData` bytes or a lazy
/// `addFontSource` path) are returned, so the shaper can never be handed a
/// database-only face.
const ShaperResolver = struct {
    /// Resolver queries are infallible by contract (the `ShapeAdapter` vtable
    /// cannot report errors), so a `getFontMatches` OOM is mapped to "no
    /// match": the shaper then keeps its global primary font (or reports the
    /// fallback list exhausted). A transient allocation failure can therefore
    /// select a different font for one run instead of failing the layout
    /// call. This is the documented limitation of the OOM-as-no-match policy.
    fn matchesFor(self: *FontSystem, query: shape_mod.FontQuery) ?[]const FontMatchKey {
        const stretch = Stretch.fromNumber(query.stretch) orelse .normal;
        return self.getFontMatches(.{
            .family = resolverFamily(query),
            .weight = query.weight,
            .stretch = stretch,
            .style = resolverStyle(query.style),
        }) catch return null;
    }

    /// First usable match for `query` (lowest-id usable face in match order),
    /// or `null` when the database has no usable registered source. OOM is
    /// degraded to "no match" (see `matchesFor`).
    fn fontFor(ctx: *anyopaque, query: shape_mod.FontQuery) ?FontId {
        const self: *FontSystem = @ptrCast(@alignCast(ctx));
        const matches = matchesFor(self, query) orelse return null;
        for (matches) |m| {
            if (self.canUseFontSource(m.id)) return m.id;
        }
        return null;
    }

    /// Stateless fallback ordering: returns the (`attempt`+1)-th usable match
    /// for `query` (0-based), so `attempt = 0` is the second usable face —
    /// `fontFor` already offers the first as the primary. The result depends
    /// only on `attempt` and the current usable set, never on which font
    /// `fontFor` returned or on previous `fallbackFor` calls, so probing
    /// attempts out of order (or after a primary retry) is well-defined.
    /// `null` means the list is exhausted.
    fn fallbackFor(
        ctx: *anyopaque,
        query: shape_mod.FontQuery,
        script: shape_mod.Script,
        attempt: usize,
    ) ?FontId {
        _ = script;
        const self: *FontSystem = @ptrCast(@alignCast(ctx));
        const matches = matchesFor(self, query) orelse return null;
        var usable: usize = 0;
        for (matches) |m| {
            if (!self.canUseFontSource(m.id)) continue;
            if (usable == attempt + 1) return m.id;
            usable += 1;
        }
        return null;
    }
};

pub const FontSystem = struct {
    pub const MATCHES_CACHE_LIMIT: usize = 256;

    allocator: std.mem.Allocator,
    locale: []u8,
    db: FontDb,
    font_cache: std.AutoHashMap(FontCacheKey, ?FontCacheEntry),
    matches_cache: std.HashMap(FontMatchAttrs, []FontMatchKey, MatchContext, 80),
    support_cache: std.AutoHashMap(FontId, CodepointSupport),
    monospace_ids: std.ArrayList(FontId),
    /// Scratch buffer for shaping/layout (mirrors `shape_buffer` role).
    shape_scratch: std.ArrayList(u8),
    /// Scratch buffer for monospace fallback iteration
    /// (mirrors `monospace_fallbacks_buffer` role).
    mono_scratch: std.ArrayList(FontId),
    /// HarfBuzz shaping backend. `null` until `addFontData`/`addFontSource`
    /// is called, in which case consumers fall back to the charmap stand-in.
    shaper_backend: ?shape_hb.Backend = null,
    /// Ids registered through `addFontData`/`addFontSource`, in registration
    /// order. Used by the raster bridge to enumerate fonts.
    font_ids: std.ArrayList(FontId) = .empty,

    /// Take ownership of `db` (including on failure), copy `locale`, apply
    /// default families (mono "Noto Sans Mono", sans "Open Sans", serif
    /// "DejaVu Serif"), and build the sorted monospace id list.
    /// Mirrors `finish_with_db` + `new_with_locale_and_db`.
    pub fn initWithDb(
        allocator: std.mem.Allocator,
        db: FontDb,
        locale: []const u8,
    ) std.mem.Allocator.Error!FontSystem {
        // Optional wrappers let the pre-transfer errdefers become no-ops once
        // ownership moves into `self`, avoiding double frees on later OOM.
        var owned_db: ?FontDb = db;
        errdefer if (owned_db) |*d| d.deinit();
        {
            const d = &owned_db.?;
            try d.setMonoFamily(DEFAULT_MONO_FAMILY);
            try d.setSansFamily(DEFAULT_SANS_FAMILY);
            try d.setSerifFamily(DEFAULT_SERIF_FAMILY);
        }
        var owned_locale: ?[]u8 = try allocator.dupe(u8, locale);
        errdefer if (owned_locale) |l| allocator.free(l);
        var self = FontSystem{
            .allocator = allocator,
            .locale = owned_locale.?,
            .db = owned_db.?,
            .font_cache = std.AutoHashMap(FontCacheKey, ?FontCacheEntry).init(allocator),
            .matches_cache = std.HashMap(FontMatchAttrs, []FontMatchKey, MatchContext, 80).init(allocator),
            .support_cache = std.AutoHashMap(FontId, CodepointSupport).init(allocator),
            .monospace_ids = .empty,
            .shape_scratch = .empty,
            .mono_scratch = .empty,
        };
        // `self` now owns db/locale; only `self.deinit` may clean up.
        owned_db = null;
        owned_locale = null;
        errdefer self.deinit();
        try self.rebuildMonospaceIds();
        return self;
    }

    /// Empty system with the default locale ("en-US").
    /// App code that wants the host locale resolves it via
    /// `systemLocaleFromEnv` (from `init.environ` values) and calls
    /// `initWithDb` instead.
    pub fn init(allocator: std.mem.Allocator) std.mem.Allocator.Error!FontSystem {
        const locale = try defaultLocale(allocator);
        defer allocator.free(locale);
        const db = try FontDb.init(allocator);
        // `initWithDb` takes ownership of `db` and cleans it up on failure;
        // do not register a second errdefer over the same pointers.
        return initWithDb(allocator, db, locale);
    }

    pub fn deinit(self: *FontSystem) void {
        self.clearMatchesCache();
        self.matches_cache.deinit();
        self.font_cache.deinit();
        var it = self.support_cache.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.support_cache.deinit();
        self.monospace_ids.deinit(self.allocator);
        self.shape_scratch.deinit(self.allocator);
        self.mono_scratch.deinit(self.allocator);
        if (self.shaper_backend) |*b| b.deinit();
        self.font_ids.deinit(self.allocator);
        self.allocator.free(self.locale);
        self.db.deinit();
        self.* = undefined;
    }

    pub fn getLocale(self: *const FontSystem) []const u8 {
        return self.locale;
    }

    /// Mutable db access clears the match cache (mirrors `db_mut`).
    pub fn dbMut(self: *FontSystem) *FontDb {
        self.clearMatchesCache();
        return &self.db;
    }

    /// Name check + capacity reservation for `font_ids`, run **before** the
    /// backend registration so an OOM cannot leave a live-but-unenumerable
    /// font. Returns true when the caller must append `id` with
    /// `appendAssumeCapacity` after the backend registration succeeds.
    fn reserveFontId(self: *FontSystem, id: FontId) std.mem.Allocator.Error!bool {
        for (self.font_ids.items) |existing| {
            if (existing == id) return false;
        }
        try self.font_ids.ensureUnusedCapacity(self.allocator, 1);
        return true;
    }

    /// Register font bytes with the HarfBuzz shaping backend under `id`
    /// (lazily creates the backend). The backend copies the bytes; the caller
    /// keeps ownership. Pair it with `dbMut().addFace` so family matching and
    /// shaping use the same `id`.
    ///
    /// Fails with `error.LibraryUnavailable` / `error.MissingSymbol` when the
    /// system HarfBuzz shared library cannot be loaded on first use.
    pub fn addFontData(
        self: *FontSystem,
        id: FontId,
        bytes: []const u8,
        index: u32,
        italic_or_oblique: bool,
        monospace_em_width: ?f32,
    ) (std.mem.Allocator.Error || error{ InvalidFont, LibraryUnavailable, MissingSymbol })!void {
        // Reserve the enumerable id slot first: every later failure aborts
        // before the backend mutates, so no font is ever live but missing
        // from `fontIds()`.
        const needs_slot = try self.reserveFontId(id);
        if (self.shaper_backend == null) {
            // Build the backend locally and publish it only after the first
            // font registers: a failed add must not leave a live but empty
            // backend (subsequent shaping would panic on the missing id).
            var backend = try shape_hb.Backend.init(self.allocator);
            errdefer backend.deinit();
            try backend.addFont(id, bytes, index, italic_or_oblique, monospace_em_width);
            self.shaper_backend = backend;
        } else {
            try self.shaper_backend.?.addFont(id, bytes, index, italic_or_oblique, monospace_em_width);
        }
        if (needs_slot) self.font_ids.appendAssumeCapacity(id);
    }

    /// Register a font **file path** with the HarfBuzz shaping backend under
    /// `id` (lazily creates the backend). The path is copied; the file itself
    /// is not read until the face is first shaped/rasterized. `monospaced`
    /// records the caller-parsed face pitch (fontconfig `FC_SPACING` /
    /// `font_parse` `post`); the space advance is unknown until the file is
    /// read, so `fontMetrics(...).monospace_width` stays `null` for lazy
    /// registrations. Pair it with `dbMut().addFace`/`addFaceFromBytes` so
    /// family matching and shaping use the same `id`.
    ///
    /// Fails with `error.LibraryUnavailable` / `error.MissingSymbol` when the
    /// system HarfBuzz shared library cannot be loaded on first use.
    pub fn addFontSource(
        self: *FontSystem,
        id: FontId,
        path: []const u8,
        index: u32,
        italic_or_oblique: bool,
        monospaced: bool,
        monospace_em_width: ?f32,
    ) (std.mem.Allocator.Error || error{ InvalidFont, LibraryUnavailable, MissingSymbol })!void {
        // Reserve the enumerable id slot first (see `addFontData`).
        const needs_slot = try self.reserveFontId(id);
        if (self.shaper_backend == null) {
            // Build the backend locally and publish it only after the font
            // registers: a failed add must not leave a live but empty backend.
            var backend = try shape_hb.Backend.init(self.allocator);
            errdefer backend.deinit();
            try backend.addFontSource(id, path, index, italic_or_oblique, monospaced, monospace_em_width);
            self.shaper_backend = backend;
        } else {
            try self.shaper_backend.?.addFontSource(id, path, index, italic_or_oblique, monospaced, monospace_em_width);
        }
        if (needs_slot) self.font_ids.appendAssumeCapacity(id);
    }

    /// Ids registered through `addFontData`/`addFontSource`, in registration
    /// order.
    pub fn fontIds(self: *const FontSystem) []const FontId {
        return self.font_ids.items;
    }

    /// HarfBuzz-backed `ShapeAdapter`, or `null` when no font data has been
    /// registered (callers then use the charmap stand-in). Installs this
    /// system as the adapter's attr-driven font resolver.
    ///
    /// Lifetime: the adapter borrows both the backend and `self`; the returned
    /// value must not be stored across a move of this `FontSystem` (each call
    /// refreshes the resolver pointer to `self`).
    pub fn shaper(self: *FontSystem) ?shape_mod.ShapeAdapter {
        if (self.shaper_backend) |*b| {
            b.setResolver(.{
                .ctx = @ptrCast(self),
                .font_for = ShaperResolver.fontFor,
                .fallback_for = ShaperResolver.fallbackFor,
            });
            return b.adapter();
        }
        return null;
    }

    /// Bytes of a registered font, by `FontId` (borrowed from the backend).
    /// Returns the owned copy for eager registrations and the loaded blob for
    /// lazily registered fonts; `null` before a lazy font loads. Used by the
    /// FreeType raster bridge.
    pub fn fontBytes(self: *const FontSystem, id: FontId) ?[]const u8 {
        if (self.shaper_backend) |*b| return b.fontBytes(id);
        return null;
    }

    /// Registered source path for a lazily registered font, or `null` for
    /// eager (byte) registrations and unknown ids. Used by the FreeType
    /// raster bridge to defer loading.
    pub fn fontSourcePath(self: *const FontSystem, id: FontId) ?[]const u8 {
        if (self.shaper_backend) |*b| return b.sourcePath(id);
        return null;
    }

    /// Number of registered faces whose bytes are loaded (eager registrations
    /// plus lazy ones already touched). Forwarded to the shaper backend.
    pub fn loadedFontCount(self: *const FontSystem) usize {
        if (self.shaper_backend) |*b| return b.loadedCount();
        return 0;
    }

    /// True when `id` has a registered shaper source that is still usable:
    /// eager bytes or a lazy path that has not failed to load. Unknown ids
    /// and negatively cached (failed) lazy sources return false, so the
    /// resolver skips a broken face instead of selecting it and poisoning
    /// every run with `error.FontUnavailable`.
    pub fn canUseFontSource(self: *const FontSystem, id: FontId) bool {
        if (self.shaper_backend) |*b| return b.canUse(id);
        return false;
    }

    pub fn hasShaper(self: *const FontSystem) bool {
        return self.shaper_backend != null;
    }

    pub fn clearMatchesCache(self: *FontSystem) void {
        var it = self.matches_cache.iterator();
        while (it.next()) |entry| {
            var key = entry.key_ptr;
            key.free(self.allocator);
            self.allocator.free(entry.value_ptr.*);
        }
        self.matches_cache.clearRetainingCapacity();
    }

    pub fn matchesCacheSize(self: *const FontSystem) usize {
        return self.matches_cache.count();
    }

    pub fn rebuildMonospaceIds(self: *FontSystem) std.mem.Allocator.Error!void {
        self.monospace_ids.clearRetainingCapacity();
        for (self.db.faces.items) |*f| {
            if (f.monospaced and !isEmojiPostScript(f.post_script_name)) {
                try self.monospace_ids.append(self.allocator, f.id);
            }
        }
        std.mem.sort(FontId, self.monospace_ids.items, {}, std.sort.asc(FontId));
    }

    pub fn isMonospace(self: *const FontSystem, id: FontId) bool {
        for (self.monospace_ids.items) |m| {
            if (m == id) return true;
            if (m > id) break;
        }
        return false;
    }

    /// Cached font load. Real parsing (`font.zig` `Font.init`) plugs in at
    /// the marked line; misses for unknown ids cache as null like Rust's
    /// `or_insert_with` warning path.
    pub fn getFont(self: *FontSystem, id: FontId, weight: Weight) std.mem.Allocator.Error!?FontCacheEntry {
        const key = FontCacheKey{ .id = id, .weight = weight };
        if (self.font_cache.get(key)) |cached| return cached;
        const entry: ?FontCacheEntry = if (self.db.face(id) != null) .{
            // C-INTEROP: replace with `font.zig` Font load
            // (`Font.init` on the face bytes at `weight`).
            .id = id,
            .weight = weight,
        } else null;
        try self.font_cache.put(key, entry);
        return entry;
    }

    /// Sorted match list with `db.query` move-to-front, exactly as Rust's
    /// `get_font_matches`. Clears the cache at >= 256 entries first.
    /// The returned slice is owned by the cache; copy it if the cache
    /// may be cleared before use.
    ///
    /// C3: the `errdefer` below removes the map entry BEFORE freeing the
    /// key's `family_name` bytes. Reversing that order would hash/free
    /// use-after-free memory (`remove` hashes `family_name`). The key is
    /// copied by value for `remove`, then the copy's allocation is freed;
    /// `gop.key_ptr` is not dereferenced after `remove`.
    pub fn getFontMatches(self: *FontSystem, attrs: AttrsForMatch) std.mem.Allocator.Error![]const FontMatchKey {
        if (self.matches_cache.count() >= MATCHES_CACHE_LIMIT) {
            self.clearMatchesCache();
        }
        var owned_key = try FontMatchAttrs.fromAttrs(self.allocator, attrs);
        // If `getOrPut` itself OOMs the map keeps nothing, so free the
        // owned key here (otherwise it leaks). After a successful
        // `getOrPut` the key is owned by the map (miss) or redundant (hit).
        const gop = self.matches_cache.getOrPut(owned_key) catch |e| {
            owned_key.free(self.allocator);
            return e;
        };
        if (gop.found_existing) {
            owned_key.free(self.allocator);
            return gop.value_ptr.*;
        }
        errdefer {
            // Copy first: `remove` hashes the key, so it must run while
            // `family_name` is still alive. Free only afterwards.
            const key_copy = gop.key_ptr.*;
            const removed = self.matches_cache.remove(key_copy);
            std.debug.assert(removed);
            std.debug.assert(self.matches_cache.get(key_copy) == null);
            var tmp = key_copy;
            tmp.free(self.allocator);
        }

        var keys = std.ArrayList(FontMatchKey).empty;
        defer keys.deinit(self.allocator);
        for (self.db.faces.items) |*f| {
            try keys.append(self.allocator, FontMatchKey.init(attrs, f));
        }
        std.mem.sort(FontMatchKey, keys.items, {}, matchKeyLess);

        // db.query is better than the sort above but returns one font:
        // move it to the front (or prepend it) exactly as Rust does.
        if (self.db.query(attrs.family, attrs.weight, attrs.stretch, attrs.style)) |qid| {
            var found: ?usize = null;
            for (keys.items, 0..) |k, i| {
                if (k.id == qid) {
                    found = i;
                    break;
                }
            }
            if (found) |i| {
                const k = keys.orderedRemove(i);
                try keys.insert(self.allocator, 0, k);
            } else if (self.db.face(qid)) |face| {
                try keys.insert(self.allocator, 0, FontMatchKey.init(attrs, face));
            }
        }

        const owned = try self.allocator.dupe(FontMatchKey, keys.items);
        gop.value_ptr.* = owned;
        return owned;
    }

    /// Count of `word` codepoints covered by `font_codepoints`, using the
    /// per-font support cache. Returns null for unknown font ids.
    pub fn countSupportedCodepoints(
        self: *FontSystem,
        id: FontId,
        font_codepoints: []const u32,
        word: []const u8,
    ) std.mem.Allocator.Error!?usize {
        if (self.db.face(id) == null) return null;
        const gop = try self.support_cache.getOrPut(id);
        if (!gop.found_existing) {
            gop.value_ptr.* = CodepointSupport.init();
        }
        var count: usize = 0;
        var iter = std.unicode.Utf8View.init(word) catch return @as(?usize, 0);
        var it = iter.iterator();
        while (it.nextCodepoint()) |cp| {
            if (try gop.value_ptr.hasCodepoint(self.allocator, font_codepoints, cp)) {
                count += 1;
            }
        }
        return count;
    }

    /// Load system fonts with the host platform/env. Never fails on missing
    /// libraries/dirs/files; problems are counted in `LoadStats` instead of
    /// silently dropped. Fontconfig is preferred on this host; the
    /// parse-based directory scan is the fallback.
    pub fn loadSystemFonts(self: *FontSystem, io: std.Io) LoadStats {
        return self.loadSystemFontsWithEnv(io, getenvSpan("XDG_DATA_HOME"), getenvSpan("HOME"));
    }

    /// Env-injectable variant for tests/embedders: `xdg_data_home`/`home`
    /// override the process values; Windows-only `WINDIR`/`LOCALAPPDATA`
    /// are read from the process env when running on Windows.
    pub fn loadSystemFontsWithEnv(
        self: *FontSystem,
        io: std.Io,
        xdg_data_home: ?[]const u8,
        home: ?[]const u8,
    ) LoadStats {
        return self.loadSystemFontsConfigured(io, hostPlatform(), .{
            .xdg_data_home = xdg_data_home,
            .home = home,
            .windir = if (builtin.os.tag == .windows) getenvSpan("WINDIR") else null,
            .local_appdata = if (builtin.os.tag == .windows) getenvSpan("LOCALAPPDATA") else null,
        }, &.{}, true);
    }

    /// Full discovery pipeline, injectable for tests/embedders:
    /// 1. every `extra_dirs` entry is scanned first through the parse-based
    ///    fallback (`scanFontDir`), so explicit test/embedder dirs always
    ///    register;
    /// 2. when `use_fontconfig` is set and the runtime fontconfig loader is
    ///    available, faces are enumerated and each becomes a lazy source
    ///    with no bytes read;
    /// 3. when nothing has been registered yet (fontconfig unavailable/empty,
    ///    or every enumerated face failed to register), the platform
    ///    directories from `resolveSystemFontDirs` are parsed once for
    ///    metadata and registered lazily.
    ///
    /// `rebuildMonospaceIds` + `clearMatchesCache` always run before
    /// returning so bulk inserts cannot leave stale derived state. Tests
    /// pass `platform = .other` with `extra_dirs` for a hermetic scan, and
    /// `use_fontconfig = false` to force the fallback.
    pub fn loadSystemFontsConfigured(
        self: *FontSystem,
        io: std.Io,
        platform: Platform,
        env: SystemFontEnv,
        extra_dirs: []const []const u8,
        use_fontconfig: bool,
    ) LoadStats {
        var stats = LoadStats{};

        // (1) Explicit directories (tests/embedders) -- parse-based, lazy.
        for (extra_dirs) |dir| self.scanFontDir(io, dir, &stats);

        // (2) Fontconfig enumeration: metadata only, lazy registration.
        if (use_fontconfig) {
            if (fontconfig.Fontconfig.load()) |loaded| {
                var fc = loaded;
                defer fc.deinit();
                if (fc.list(self.allocator)) |faces| {
                    defer fontconfig.freeFaces(self.allocator, faces);
                    for (faces) |*face| self.registerFontconfigFace(face, &stats);
                } else |_| {
                    stats.file_errors += 1;
                }
            }
        }

        // (3) Directory-scan fallback when nothing has been registered yet.
        // `faces.len` (enumeration) is deliberately not consulted: fontconfig
        // can enumerate faces that all fail to register (path vanished, OOM),
        // and skipping the scan then would leave the database empty.
        if (stats.faces_added == 0) {
            const dirs = resolveSystemFontDirs(self.allocator, platform, env) catch {
                stats.file_errors += 1;
                self.finishSystemFontLoad(&stats);
                return stats;
            };
            defer freeDirList(self.allocator, dirs);
            for (dirs) |dir| self.scanFontDir(io, dir, &stats);
        }

        self.finishSystemFontLoad(&stats);
        return stats;
    }

    /// Register one fontconfig face: database metadata (`db.addFace`) plus a
    /// lazy shaper source (`addFontSource`). No font bytes are read.
    ///
    /// TODO(variable-wght): `fontconfig.Face` does not currently expose
    /// `FC_VARIABLE`, so a variable face keeps `variable_wght_min/max = null`
    /// here and `variableWeightMatch` cannot rank it (the parse-based
    /// `addFaceFromBytes` path already fills the exact `fvar` range). When
    /// fontconfig.zig grows a `variable: bool` field, store a conservative
    /// 1..1000 range via `db.setVariableWghtRange(id, 1, 1000)`: the exact
    /// axis range is unknown without reading the file, and the bounds only
    /// affect ranking, never shaping.
    fn registerFontconfigFace(self: *FontSystem, face: *const fontconfig.Face, stats: *LoadStats) void {
        if (face.path.len == 0) {
            stats.file_errors += 1;
            return;
        }
        const style: Style = switch (face.style) {
            fontconfig.STYLE_ITALIC => .italic,
            fontconfig.STYLE_OBLIQUE => .oblique,
            else => .normal,
        };
        const stretch = Stretch.fromNumber(face.stretch) orelse .normal;
        const id = self.db.addFace(
            face.path,
            face.index,
            face.families,
            face.post_script_name,
            face.weight,
            stretch,
            style,
            face.monospaced,
        ) catch {
            stats.file_errors += 1;
            return;
        };
        self.addFontSource(id, face.path, face.index, style != .normal, face.monospaced, null) catch {
            stats.file_errors += 1;
            return;
        };
        stats.faces_added += 1;
    }

    /// Refresh derived state after bulk inserts.
    fn finishSystemFontLoad(self: *FontSystem, stats: *LoadStats) void {
        self.rebuildMonospaceIds() catch {
            stats.file_errors += 1;
        };
        self.clearMatchesCache();
    }

    /// Load every font under `dir_path` into both the database and the
    /// HarfBuzz shaping backend. This is the harness equivalent of upstream
    /// `FontSystem::new_with_locale_and_db` over a `Database` populated with
    /// `Database::load_fonts_dir`: both matching and shaping see the fonts.
    ///
    /// Each file is read once (for metadata by `db.loadFontsDir`); shaper
    /// registration is lazy (`addFontSource`), so font bytes are only loaded
    /// when a face is first shaped. Test/embedder scale only.
    pub fn loadFontsDir(self: *FontSystem, io: std.Io, dir_path: []const u8) LoadStats {
        var stats = LoadStats{};
        self.db.loadFontsDir(io, dir_path, &stats);
        for (self.db.faces.items) |*f| {
            self.addFontSource(f.id, f.path, f.index, f.style != .normal, f.monospaced, null) catch {
                stats.file_errors += 1;
                continue;
            };
        }
        self.rebuildMonospaceIds() catch {
            stats.file_errors += 1;
        };
        self.clearMatchesCache();
        return stats;
    }

    /// Scan one explicit directory (absolute or relative to the cwd) into the
    /// database and the lazy shaper registry. Mirrors `loadFontsDir`'s
    /// absolute/relative branch so relative `extra_dirs` work.
    fn scanFontDir(self: *FontSystem, io: std.Io, dir_path: []const u8, stats: *LoadStats) void {
        var dir = if (std.fs.path.isAbsolute(dir_path))
            std.Io.Dir.openDirAbsolute(io, dir_path, .{ .iterate = true }) catch {
                stats.dirs_missing += 1;
                return;
            }
        else
            std.Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true }) catch {
                stats.dirs_missing += 1;
                return;
            };
        defer dir.close(io);
        stats.dirs_scanned += 1;
        var walker = dir.walk(self.allocator) catch {
            stats.file_errors += 1;
            return;
        };
        defer walker.deinit();
        // M4: walker errors must be counted, not mistaken for clean EOF.
        while (true) {
            const entry_opt = walker.next(io) catch {
                stats.file_errors += 1;
                break;
            };
            const entry = entry_opt orelse break;
            if (entry.kind != .file) continue;
            if (!hasFontExtension(entry.basename)) continue;
            stats.files_seen += 1;
            self.addScannedFile(io, dir_path, entry.path, stats);
        }
    }

    /// Read `rel_path` once to parse real per-face metadata
    /// (`FontDb.addFaceFromBytes`) and register a lazy shaper source for every
    /// face; the bytes are freed before returning and are re-read on first
    /// shaping/rasterization. Filename guesses are no longer used.
    fn addScannedFile(
        self: *FontSystem,
        io: std.Io,
        dir_path: []const u8,
        rel_path: []const u8,
        stats: *LoadStats,
    ) void {
        const full = std.fs.path.join(self.allocator, &.{ dir_path, rel_path }) catch {
            stats.file_errors += 1;
            return;
        };
        defer self.allocator.free(full);
        const bytes = std.Io.Dir.cwd().readFileAlloc(
            io,
            full,
            self.allocator,
            .limited(MAX_FONT_BYTES),
        ) catch {
            stats.file_errors += 1;
            return;
        };
        defer self.allocator.free(bytes);
        const count = font_parse.fontsInCollection(bytes);
        if (count == 0) {
            stats.file_errors += 1;
            return;
        }
        var index: u32 = 0;
        while (index < count) : (index += 1) {
            const id = self.db.addFaceFromBytes(bytes, index, full) catch {
                stats.file_errors += 1;
                continue;
            };
            const face_info = self.db.face(id) orelse {
                stats.file_errors += 1;
                continue;
            };
            const style = face_info.style;
            self.addFontSource(id, full, index, style != .normal, face_info.monospaced, null) catch {
                stats.file_errors += 1;
                continue;
            };
            stats.faces_added += 1;
        }
    }
};

fn hasFontExtension(basename: []const u8) bool {
    const ext = std.fs.path.extension(basename);
    if (std.ascii.eqlIgnoreCase(ext, ".ttf")) return true;
    if (std.ascii.eqlIgnoreCase(ext, ".otf")) return true;
    if (std.ascii.eqlIgnoreCase(ext, ".ttc")) return true;
    if (std.ascii.eqlIgnoreCase(ext, ".otc")) return true;
    if (std.ascii.eqlIgnoreCase(ext, ".woff")) return true;
    if (std.ascii.eqlIgnoreCase(ext, ".woff2")) return true;
    return false;
}

/// Process-env lookup without hidden globals in pure code paths: returns the
/// env value span or null when unlinked/empty/missing. Pure callers pass
/// explicit strings to `resolveUserFontDirs` instead.
fn getenvSpan(name: [*:0]const u8) ?[]const u8 {
    if (!builtin.link_libc) return null;
    const raw = std.c.getenv(name) orelse return null;
    const s = std.mem.span(raw);
    if (s.len == 0) return null;
    return s;
}

/// User font dirs from XDG/HOME env (M4, pure for tests).
/// Returns owned strings (caller frees each + the slice):
/// - `$XDG_DATA_HOME/fonts` when set, else `$HOME/.local/share/fonts`
/// - plus legacy `$HOME/.fonts`
/// Empty inputs yield an empty slice. Never returns hardcoded `/home/*`.
pub fn resolveUserFontDirs(
    allocator: std.mem.Allocator,
    xdg_data_home: ?[]const u8,
    home: ?[]const u8,
) std.mem.Allocator.Error![][]u8 {
    var list = std.ArrayList([]u8).empty;
    errdefer {
        for (list.items) |d| allocator.free(d);
        list.deinit(allocator);
    }
    const xdg = if (xdg_data_home) |v| (if (v.len > 0) v else null) else null;
    const h = if (home) |v| (if (v.len > 0) v else null) else null;
    if (xdg) |x| {
        const p = try std.fs.path.join(allocator, &.{ x, "fonts" });
        try list.append(allocator, p);
    } else if (h) |home_dir| {
        const p = try std.fs.path.join(allocator, &.{ home_dir, ".local/share/fonts" });
        try list.append(allocator, p);
    }
    if (h) |home_dir| {
        const p = try std.fs.path.join(allocator, &.{ home_dir, ".fonts" });
        try list.append(allocator, p);
    }
    return list.toOwnedSlice(allocator);
}

// ---------------------------------------------------------------------------
// Locale helpers.
// ---------------------------------------------------------------------------

/// Normalize "en_US.UTF-8" / "en_US@euro" -> "en-US".
pub fn normalizeLocale(allocator: std.mem.Allocator, raw: []const u8) std.mem.Allocator.Error![]u8 {
    var end = raw.len;
    for (raw, 0..) |c, i| {
        if (c == '.' or c == '@') {
            end = i;
            break;
        }
    }
    const trimmed = if (end == 0) "en-US" else raw[0..end];
    const out = try allocator.dupe(u8, trimmed);
    for (out) |*c| {
        if (c.* == '_') c.* = '-';
    }
    if (out.len == 0) {
        allocator.free(out);
        return allocator.dupe(u8, FALLBACK_LOCALE);
    }
    return out;
}

/// Host locale selection from `LC_ALL`/`LANG` values, or "en-US".
///
/// Pure function so library code never reads the process environment
/// directly (no hidden globals; explicit allocators only). App code that
/// owns a `std.process.Init` passes its values in:
/// `init.environ.getAlloc(gpa, "LC_ALL")` / `getAlloc(gpa, "LANG")`.
/// `LC_ALL` wins when set and non-empty; empty values and bare
/// `"C"`/`"POSIX"` are skipped; anything else is normalized.
/// Pass `null` for a missing variable.
pub fn systemLocaleFromEnv(
    allocator: std.mem.Allocator,
    lang: ?[]const u8,
    lc_all: ?[]const u8,
) std.mem.Allocator.Error![]u8 {
    const vars = [_]?[]const u8{ lc_all, lang };
    for (vars) |maybe| {
        const raw = maybe orelse continue;
        if (raw.len == 0) continue;
        // "C"/"POSIX" carry no language; keep looking.
        if (std.mem.eql(u8, raw, "C") or std.mem.eql(u8, raw, "POSIX")) continue;
        return normalizeLocale(allocator, raw);
    }
    return allocator.dupe(u8, FALLBACK_LOCALE);
}

/// Default locale when no environment values are available ("en-US").
pub fn defaultLocale(allocator: std.mem.Allocator) std.mem.Allocator.Error![]u8 {
    return allocator.dupe(u8, FALLBACK_LOCALE);
}

// ---------------------------------------------------------------------------
// Tests.
// ---------------------------------------------------------------------------

test "font match key ordering matches rust derived ord" {
    const t = std.testing;
    const alloc = t.allocator;
    var db = try FontDb.init(alloc);
    defer db.deinit();
    const plain = try db.addFace("/a.ttf", 0, &.{"Test"}, "Test-Regular", 400, .normal, .normal, false);
    const emoji = try db.addFace("/e.ttf", 0, &.{"Test"}, "Noto Color Emoji", 400, .normal, .normal, false);
    const attrs = AttrsForMatch{ .family = .{ .name = "Test" } };
    const kp = FontMatchKey.init(attrs, db.face(plain).?);
    const ke = FontMatchKey.init(attrs, db.face(emoji).?);
    try t.expect(!ke.not_emoji);
    try t.expect(kp.not_emoji);
    // Rust derived-Ord quirk: `false < true`, so the emoji key sorts
    // FIRST at equal diffs. Ported verbatim; see `lessThan` NOTE.
    try t.expect(ke.lessThan(kp));
    try t.expect(!kp.lessThan(ke));

    // Field order dominates: not_emoji is compared before weight diff,
    // so the emoji key (diff 0) still sorts before bold (diff 300).
    const bold = try db.addFace("/b.ttf", 0, &.{"Test"}, "Test-Bold", 700, .normal, .normal, false);
    const kb = FontMatchKey.init(attrs, db.face(bold).?);
    try t.expect(ke.lessThan(kb));

    // Style diff table: italic/oblique swap costs 1, normal mismatch 2.
    try t.expectEqual(@as(u8, 0), styleDiff(.italic, .italic));
    try t.expectEqual(@as(u8, 1), styleDiff(.italic, .oblique));
    try t.expectEqual(@as(u8, 1), styleDiff(.oblique, .italic));
    try t.expectEqual(@as(u8, 2), styleDiff(.normal, .italic));
    try t.expectEqual(@as(u8, 2), styleDiff(.italic, .normal));
}

test "face query picks closest weight and style" {
    const t = std.testing;
    const alloc = t.allocator;
    var db = try FontDb.init(alloc);
    defer db.deinit();
    _ = try db.addFace("/r.ttf", 0, &.{"Q"}, "Q-Regular", 400, .normal, .normal, false);
    const bold_id = try db.addFace("/b.ttf", 0, &.{"Q"}, "Q-Bold", 700, .normal, .normal, false);
    const got = db.query(.{ .name = "Q" }, 700, .normal, .normal);
    try t.expectEqual(@as(?FontId, bold_id), got);
    try t.expect(db.query(.{ .name = "Missing" }, 400, .normal, .normal) == null);
    // Style diff: italic request prefers the italic face.
    _ = try db.addFace("/i.ttf", 0, &.{"S"}, "S-Italic", 400, .normal, .italic, false);
    _ = try db.addFace("/n.ttf", 0, &.{"S"}, "S-Regular", 400, .normal, .normal, false);
    const picked = db.query(.{ .name = "S" }, 400, .normal, .italic);
    try t.expect(picked != null);
    try t.expectEqualStrings("S-Italic", db.face(picked.?).?.post_script_name);
}

test "get font matches sorts and moves query to front" {
    const t = std.testing;
    const alloc = t.allocator;
    var db = try FontDb.init(alloc);
    const rid = try db.addFace("/r.ttf", 0, &.{"Fam"}, "Fam-Regular", 400, .normal, .normal, false);
    const bid = try db.addFace("/b.ttf", 0, &.{"Fam"}, "Fam-Bold", 700, .normal, .normal, false);
    _ = try db.addFace("/e.ttf", 0, &.{"Fam"}, "Fam Emoji", 400, .normal, .normal, false);
    var sys = try FontSystem.initWithDb(alloc, db, "en-US");
    defer sys.deinit();

    const attrs = AttrsForMatch{ .family = .{ .name = "Fam" }, .weight = 700 };
    const matches = try sys.getFontMatches(attrs);
    try t.expect(matches.len >= 3);
    // Query hit (bold) moves to front even though sort already favors it.
    try t.expectEqual(bid, matches[0].id);
    // Raw sort order after the moved query hit: emoji (not_emoji=false)
    // before regular at equal weight diff (Rust derived-Ord quirk).
    try t.expectEqual(rid, matches[2].id);
    var emoji_pos: ?usize = null;
    var regular_pos: ?usize = null;
    for (matches, 0..) |k, i| {
        if (k.id == rid) regular_pos = i;
        if (std.mem.containsAtLeast(u8, sys.db.face(k.id).?.post_script_name, 1, "Emoji")) emoji_pos = i;
    }
    try t.expect(regular_pos != null and emoji_pos != null);
    try t.expect(emoji_pos.? < regular_pos.?);
    // Cached second call returns the same backing slice.
    const again = try sys.getFontMatches(attrs);
    try t.expectEqual(matches.ptr, again.ptr);
    try t.expectEqual(@as(usize, 1), sys.matchesCacheSize());
}

test "locale normalize and env selection fallback" {
    const t = std.testing;
    const alloc = t.allocator;
    const a = try normalizeLocale(alloc, "en_US.UTF-8");
    defer alloc.free(a);
    try t.expectEqualStrings("en-US", a);
    const b = try normalizeLocale(alloc, "zh_HK@euro");
    defer alloc.free(b);
    try t.expectEqualStrings("zh-HK", b);
    // LC_ALL wins over LANG; C/POSIX/empty fall through to en-US.
    const c = try systemLocaleFromEnv(alloc, "fr_FR.UTF-8", "de_DE.UTF-8");
    defer alloc.free(c);
    try t.expectEqualStrings("de-DE", c);
    const d = try systemLocaleFromEnv(alloc, "C", null);
    defer alloc.free(d);
    try t.expectEqualStrings("en-US", d);
    const e = try systemLocaleFromEnv(alloc, null, null);
    defer alloc.free(e);
    try t.expectEqualStrings("en-US", e);
    const f = try systemLocaleFromEnv(alloc, "", "POSIX");
    defer alloc.free(f);
    try t.expectEqualStrings("en-US", f);
}

test "failed addFontData does not leave a live empty shaper backend" {
    const t = std.testing;
    const alloc = t.allocator;
    var fs = try FontSystem.init(alloc);
    defer fs.deinit();

    try t.expect(!fs.hasShaper());
    // Empty bytes fail before the backend is published: shaper consumers
    // must still see "no backend" (and shape through the charmap stand-in)
    // instead of a zero-entry backend that panics on the first lookup.
    try t.expectError(error.InvalidFont, fs.addFontData(1, "", 0, false, null));
    try t.expect(!fs.hasShaper());
    try t.expect(fs.shaper() == null);
    try t.expectEqual(@as(usize, 0), fs.fontIds().len);
}

/// Vendored fixture dir candidates (same policy as the integration suites):
/// skip when the corpus is genuinely absent.
fn fontFixtureDir() ![]const u8 {
    const candidates = [_][]const u8{ "tests/fonts", "../tests/fonts", "src/../tests/fonts" };
    for (candidates) |dir| {
        if (std.Io.Dir.cwd().access(std.testing.io, dir, .{})) |_| {
            return dir;
        } else |err| {
            if (err != error.FileNotFound) return err;
        }
    }
    return error.SkipZigTest;
}

/// Join a fixture name onto `fontFixtureDir` (caller owns the result).
fn fontFixturePath(alloc: std.mem.Allocator, name: []const u8) ![]u8 {
    const dir = try fontFixtureDir();
    return std.fs.path.join(alloc, &.{ dir, name });
}

/// Read a fixture's bytes (caller owns the result).
fn fontFixtureBytes(alloc: std.mem.Allocator, name: []const u8) ![]u8 {
    const path = try fontFixturePath(alloc, name);
    defer alloc.free(path);
    return std.Io.Dir.cwd().readFileAlloc(
        std.testing.io,
        path,
        alloc,
        .limited(MAX_FONT_BYTES),
    );
}

/// Absolute path of a `std.testing.tmpDir` directory (tests that need to
/// point `resolveSystemFontDirs` at a hermetic tmp tree).
fn tmpDirAbsolute(alloc: std.mem.Allocator, tmp: std.testing.TmpDir) ![]u8 {
    const cwd = try std.process.currentPathAlloc(std.testing.io, alloc);
    defer alloc.free(cwd);
    return std.fs.path.resolveAlloc(alloc, &.{ cwd, ".zig-cache", "tmp", &tmp.sub_path });
}

test "loadFontsDir registers lazily and shaping loads only used faces" {
    const t = std.testing;
    const alloc = t.allocator;
    const dir = try fontFixtureDir();

    var fs = try FontSystem.init(alloc);
    defer fs.deinit();

    const stats = fs.loadFontsDir(std.testing.io, dir);
    try t.expect(stats.faces_added > 0);
    try t.expectEqual(@as(usize, 0), stats.file_errors);
    try t.expect(fs.hasShaper());
    // Registration must not read font bytes: every face is lazy.
    try t.expectEqual(@as(usize, 0), fs.loadedFontCount());
    try t.expectEqual(stats.faces_added, fs.fontIds().len);
    for (fs.fontIds()) |id| {
        try t.expect(fs.fontSourcePath(id) != null);
        try t.expect(fs.fontBytes(id) == null);
    }

    const adapter = fs.shaper() orelse return error.FontFixtureLoadFailed;
    const inter = adapter.fontFor(.{
        .family_kind = .name,
        .family_name = "Inter",
    }) orelse return error.FontFixtureLoadFailed;
    const glyphs = try adapter.shapeRun(alloc, inter, "Hello", false);
    defer alloc.free(glyphs);
    try t.expectEqual(@as(usize, 5), glyphs.len);
    for (glyphs) |g| try t.expect(g.glyph_id != 0);
    // "Hello" is covered by the selected Inter face; exactly one lazy face was
    // read, and its bytes are now visible to the raster bridge.
    try t.expectEqual(@as(usize, 1), fs.loadedFontCount());
    try t.expect(fs.fontBytes(inter) != null);
}

test "codepoint support cache caps and hits" {
    const t = std.testing;
    const alloc = t.allocator;
    var sup = CodepointSupport.init();
    defer sup.deinit(alloc);
    const font_cps = [_]u32{ 65, 66, 67 };
    try t.expect(try sup.hasCodepoint(alloc, &font_cps, 65));
    try t.expect(try sup.hasCodepoint(alloc, &font_cps, 65)); // cached hit
    try t.expect(!try sup.hasCodepoint(alloc, &font_cps, 90));
    try t.expect(!try sup.hasCodepoint(alloc, &font_cps, 90)); // cached miss
    try t.expectEqual(@as(usize, 1), sup.supported.items.len);
    try t.expectEqual(@as(usize, 1), sup.not_supported.items.len);
}

test "db mut clears matches cache" {
    const t = std.testing;
    const alloc = t.allocator;
    var db = try FontDb.init(alloc);
    _ = try db.addFace("/r.ttf", 0, &.{"Fam"}, "Fam-Regular", 400, .normal, .normal, false);
    var sys = try FontSystem.initWithDb(alloc, db, "en-US");
    defer sys.deinit();
    _ = try sys.getFontMatches(.{ .family = .{ .name = "Fam" } });
    try t.expectEqual(@as(usize, 1), sys.matchesCacheSize());
    _ = sys.dbMut();
    try t.expectEqual(@as(usize, 0), sys.matchesCacheSize());
}

fn addFaceOomHelper(allocator: std.mem.Allocator) !void {
    var db = try FontDb.init(allocator);
    defer db.deinit();
    _ = try db.addFace("/a.ttf", 0, &.{ "FamA", "FamB" }, "Post", 400, .normal, .normal, false);
}

test "addFace OOM frees only initialized slots (C4)" {
    // Exercises every allocation-failure point in init+addFace; the fixed
    // errdefer frees [0..initialized] so no uninitialized slot is freed
    // and no leak remains.
    try std.testing.checkAllAllocationFailures(std.testing.allocator, addFaceOomHelper, .{});
}

fn getFontMatchesOomHelper(allocator: std.mem.Allocator) !void {
    var db_opt: ?FontDb = try FontDb.init(allocator);
    errdefer if (db_opt) |*d| d.deinit();
    _ = try db_opt.?.addFace("/r.ttf", 0, &.{"Fam"}, "Fam-Regular", 400, .normal, .normal, false);
    const db = db_opt.?;
    db_opt = null;
    var sys = try FontSystem.initWithDb(allocator, db, "en-US");
    defer sys.deinit();
    _ = try sys.getFontMatches(.{ .family = .{ .name = "Fam" } });
}

test "getFontMatches OOM removes entry before freeing key (C3)" {
    // The errdefer copies the key, removes by value, then frees; every
    // failure point must leave no leak and no use-after-free (caught as
    // MemoryLeakDetected / crash under the failing allocator).
    try std.testing.checkAllAllocationFailures(std.testing.allocator, getFontMatchesOomHelper, .{});
}

test "generic families resolve via configured defaults (M1)" {
    const t = std.testing;
    const alloc = t.allocator;
    var db = try FontDb.init(alloc);
    defer db.deinit();
    // Default sans is "Open Sans", serif is "DejaVu Serif".
    _ = try db.addFace("/sans.ttf", 0, &.{"Open Sans"}, "OpenSans-Regular", 400, .normal, .normal, false);
    _ = try db.addFace("/other.ttf", 0, &.{"Other"}, "Other-Regular", 400, .normal, .normal, false);
    _ = try db.addFace("/serif.ttf", 0, &.{"DejaVu Serif"}, "DejaVuSerif-Regular", 400, .normal, .normal, false);
    const sans_hit = db.query(.sans_serif, 400, .normal, .normal);
    try t.expect(sans_hit != null);
    try t.expectEqualStrings("OpenSans-Regular", db.face(sans_hit.?).?.post_script_name);
    const serif_hit = db.query(.serif, 400, .normal, .normal);
    try t.expect(serif_hit != null);
    try t.expectEqualStrings("DejaVuSerif-Regular", db.face(serif_hit.?).?.post_script_name);
    // Unknown named family still misses (generic must not match-all).
    try t.expect(db.query(.{ .name = "Missing" }, 400, .normal, .normal) == null);
    // Custom default retargets the generic.
    try db.setSansFamily("Other");
    const retarget = db.query(.sans_serif, 400, .normal, .normal);
    try t.expect(retarget != null);
    try t.expectEqualStrings("Other-Regular", db.face(retarget.?).?.post_script_name);
}

test "variable weight match covers wght range (M2)" {
    const t = std.testing;
    try t.expect(!variableWeightMatch(600, 400, null, null));
    try t.expect(!variableWeightMatch(400, 400, 100, 900));
    try t.expect(variableWeightMatch(600, 400, 100, 900));
    try t.expect(!variableWeightMatch(50, 400, 100, 900));
    try t.expect(!variableWeightMatch(950, 400, 100, 900));
    const alloc = t.allocator;
    var db = try FontDb.init(alloc);
    defer db.deinit();
    const vid = try db.addFace("/v.ttf", 0, &.{"V"}, "V-Regular", 400, .normal, .normal, false);
    try t.expect(db.setVariableWghtRange(vid, 100, 900));
    const attrs = AttrsForMatch{ .family = .{ .name = "V" }, .weight = 600 };
    const key = FontMatchKey.init(attrs, db.face(vid).?);
    try t.expectEqual(@as(u16, 200), key.font_weight_diff);
    try t.expect(key.variable_weight_match);
    const plain = FontMatchKey.init(.{ .family = .{ .name = "V" } }, db.face(vid).?);
    try t.expect(!plain.variable_weight_match);
}

test "user font dirs use XDG/HOME, never hardcoded (M4)" {
    const t = std.testing;
    const alloc = t.allocator;
    // XDG set: XDG/fonts + HOME/.fonts.
    {
        const dirs = try resolveUserFontDirs(alloc, "/tmp/xdg", "/home/user");
        defer {
            for (dirs) |d| alloc.free(d);
            alloc.free(dirs);
        }
        try t.expectEqual(@as(usize, 2), dirs.len);
        try t.expectEqualStrings("/tmp/xdg/fonts", dirs[0]);
        try t.expectEqualStrings("/home/user/.fonts", dirs[1]);
        for (dirs) |d| try t.expect(std.mem.indexOf(u8, d, "/home/addo") == null);
    }
    // XDG unset: HOME/.local/share/fonts + HOME/.fonts.
    {
        const dirs = try resolveUserFontDirs(alloc, null, "/home/user");
        defer {
            for (dirs) |d| alloc.free(d);
            alloc.free(dirs);
        }
        try t.expectEqual(@as(usize, 2), dirs.len);
        try t.expectEqualStrings("/home/user/.local/share/fonts", dirs[0]);
        try t.expectEqualStrings("/home/user/.fonts", dirs[1]);
    }
    // No env: no user dirs.
    {
        const dirs = try resolveUserFontDirs(alloc, null, null);
        defer alloc.free(dirs);
        try t.expectEqual(@as(usize, 0), dirs.len);
    }
    // Empty strings count as unset.
    {
        const dirs = try resolveUserFontDirs(alloc, "", "");
        defer alloc.free(dirs);
        try t.expectEqual(@as(usize, 0), dirs.len);
    }
}

test "resolve system font dirs per platform (M4)" {
    const t = std.testing;
    const alloc = t.allocator;

    // linux with XDG_DATA_HOME: system dirs, XDG/fonts, HOME/.fonts.
    {
        const dirs = try resolveSystemFontDirs(alloc, .linux, .{
            .xdg_data_home = "/xdg",
            .home = "/home/user",
        });
        defer freeDirList(alloc, dirs);
        try t.expectEqual(@as(usize, 4), dirs.len);
        try t.expectEqualStrings("/usr/share/fonts", dirs[0]);
        try t.expectEqualStrings("/usr/local/share/fonts", dirs[1]);
        const xdg_fonts = try std.fs.path.join(alloc, &.{ "/xdg", "fonts" });
        defer alloc.free(xdg_fonts);
        try t.expectEqualStrings(xdg_fonts, dirs[2]);
        const legacy = try std.fs.path.join(alloc, &.{ "/home/user", ".fonts" });
        defer alloc.free(legacy);
        try t.expectEqualStrings(legacy, dirs[3]);
    }
    // linux with HOME only: `.local/share/fonts` replaces XDG/fonts.
    {
        const dirs = try resolveSystemFontDirs(alloc, .linux, .{ .home = "/home/user" });
        defer freeDirList(alloc, dirs);
        try t.expectEqual(@as(usize, 4), dirs.len);
        const local_fonts = try std.fs.path.join(alloc, &.{ "/home/user", ".local/share/fonts" });
        defer alloc.free(local_fonts);
        try t.expectEqualStrings(local_fonts, dirs[2]);
        const legacy = try std.fs.path.join(alloc, &.{ "/home/user", ".fonts" });
        defer alloc.free(legacy);
        try t.expectEqualStrings(legacy, dirs[3]);
    }
    // Empty env strings count as unset; only system dirs remain.
    {
        const dirs = try resolveSystemFontDirs(alloc, .linux, .{ .xdg_data_home = "", .home = "" });
        defer freeDirList(alloc, dirs);
        try t.expectEqual(@as(usize, 2), dirs.len);
        try t.expectEqualStrings("/usr/share/fonts", dirs[0]);
        try t.expectEqualStrings("/usr/local/share/fonts", dirs[1]);
    }
    // windows: WINDIR + LOCALAPPDATA (joined portably).
    {
        const dirs = try resolveSystemFontDirs(alloc, .windows, .{
            .windir = "C:\\Windows",
            .local_appdata = "C:\\Users\\user\\AppData\\Local",
        });
        defer freeDirList(alloc, dirs);
        try t.expectEqual(@as(usize, 2), dirs.len);
        const fonts = try std.fs.path.join(alloc, &.{ "C:\\Windows", "Fonts" });
        defer alloc.free(fonts);
        try t.expectEqualStrings(fonts, dirs[0]);
        const user_fonts = try std.fs.path.join(alloc, &.{
            "C:\\Users\\user\\AppData\\Local",
            "Microsoft",
            "Windows",
            "Fonts",
        });
        defer alloc.free(user_fonts);
        try t.expectEqualStrings(user_fonts, dirs[1]);
    }
    // windows without LOCALAPPDATA: HOME fallback via AppData/Local.
    {
        const dirs = try resolveSystemFontDirs(alloc, .windows, .{
            .windir = "C:\\Windows",
            .home = "C:\\Users\\user",
        });
        defer freeDirList(alloc, dirs);
        try t.expectEqual(@as(usize, 2), dirs.len);
        const user_fonts = try std.fs.path.join(alloc, &.{
            "C:\\Users\\user",
            "AppData",
            "Local",
            "Microsoft",
            "Windows",
            "Fonts",
        });
        defer alloc.free(user_fonts);
        try t.expectEqualStrings(user_fonts, dirs[1]);
    }
    // macos: system dirs plus $HOME/Library/Fonts.
    {
        const dirs = try resolveSystemFontDirs(alloc, .macos, .{ .home = "/Users/user" });
        defer freeDirList(alloc, dirs);
        try t.expectEqual(@as(usize, 4), dirs.len);
        try t.expectEqualStrings("/System/Library/Fonts", dirs[0]);
        try t.expectEqualStrings("/System/Library/Fonts/Supplemental", dirs[1]);
        try t.expectEqualStrings("/Library/Fonts", dirs[2]);
        const user_fonts = try std.fs.path.join(alloc, &.{ "/Users/user", "Library/Fonts" });
        defer alloc.free(user_fonts);
        try t.expectEqualStrings(user_fonts, dirs[3]);
    }
    // other: never guesses a path.
    {
        const dirs = try resolveSystemFontDirs(alloc, .other, .{
            .xdg_data_home = "/xdg",
            .home = "/home/user",
            .windir = "C:\\Windows",
            .local_appdata = "C:\\Users\\user\\AppData\\Local",
        });
        defer freeDirList(alloc, dirs);
        try t.expectEqual(@as(usize, 0), dirs.len);
    }
}

test "fallback scan registers one face lazily and shaping loads it" {
    const t = std.testing;
    const alloc = t.allocator;
    const fixture_dir = try fontFixtureDir();
    const fixture = try std.fs.path.join(alloc, &.{ fixture_dir, "Inter-Regular.ttf" });
    defer alloc.free(fixture);
    const bytes = try std.Io.Dir.cwd().readFileAlloc(t.io, fixture, alloc, .limited(MAX_FONT_BYTES));
    defer alloc.free(bytes);

    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(t.io, .{ .sub_path = "Inter-Regular.ttf", .data = bytes });

    // `scanFontDir` opens absolute paths; `.zig-cache/tmp/<tmp>` is created
    // relative to the test cwd.
    const cwd = try std.process.currentPathAlloc(t.io, alloc);
    defer alloc.free(cwd);
    const tmp_rel = try std.fs.path.join(alloc, &.{ ".zig-cache", "tmp", &tmp.sub_path });
    defer alloc.free(tmp_rel);
    const tmp_abs = try std.fs.path.resolveAlloc(alloc, &.{ cwd, tmp_rel });
    defer alloc.free(tmp_abs);

    var fs = try FontSystem.init(alloc);
    defer fs.deinit();

    // `.other` + no fontconfig = the explicit-dir fallback scan only.
    const stats = fs.loadSystemFontsConfigured(t.io, .other, .{}, &.{tmp_abs}, false);
    try t.expectEqual(@as(usize, 1), stats.faces_added);
    try t.expectEqual(@as(usize, 1), stats.dirs_scanned);
    try t.expectEqual(@as(usize, 0), stats.dirs_missing);
    try t.expectEqual(@as(usize, 1), stats.files_seen);
    try t.expectEqual(@as(usize, 0), stats.file_errors);
    // Metadata only: the face is registered lazily.
    try t.expectEqual(@as(usize, 1), fs.fontIds().len);
    try t.expectEqual(@as(usize, 0), fs.loadedFontCount());
    const only_id = fs.fontIds()[0];
    try t.expect(fs.fontSourcePath(only_id) != null);
    try t.expect(fs.fontBytes(only_id) == null);

    // Shaping "Hello" through Inter loads exactly that one face.
    const adapter = fs.shaper() orelse return error.FontFixtureLoadFailed;
    const inter = adapter.fontFor(.{
        .family_kind = .name,
        .family_name = "Inter",
    }) orelse return error.FontFixtureLoadFailed;
    const glyphs = try adapter.shapeRun(alloc, inter, "Hello", false);
    defer alloc.free(glyphs);
    try t.expectEqual(@as(usize, 5), glyphs.len);
    for (glyphs) |g| try t.expect(g.glyph_id != 0);
    try t.expectEqual(@as(usize, 1), fs.loadedFontCount());
}

test "fontconfig discovery registers lazily or skips" {
    const t = std.testing;
    const alloc = t.allocator;

    var fc = fontconfig.Fontconfig.load() orelse return error.SkipZigTest;
    defer fc.deinit();
    const faces = try fc.list(alloc);
    defer fontconfig.freeFaces(alloc, faces);
    try t.expect(faces.len > 0);
    for (faces) |face| {
        try t.expect(face.path.len > 0);
        try t.expect(face.style <= fontconfig.STYLE_OBLIQUE);
        try t.expect(face.weight > 0);
        try t.expect(face.stretch >= 1 and face.stretch <= 9);
    }
    // (path, index) dedup guarantee.
    for (faces, 0..) |a, i| {
        for (faces[i + 1 ..]) |b| {
            if (std.mem.eql(u8, a.path, b.path)) {
                try t.expect(a.index != b.index);
            }
        }
    }

    // The configured pipeline uses fontconfig (no directory walk) and still
    // retains no bytes: every face is a lazy source.
    var fs = try FontSystem.init(alloc);
    defer fs.deinit();
    const stats = fs.loadSystemFontsConfigured(t.io, .other, .{}, &.{}, true);
    try t.expect(stats.faces_added > 0);
    try t.expectEqual(@as(usize, 0), stats.dirs_scanned);
    try t.expectEqual(@as(usize, 0), stats.dirs_missing);
    try t.expectEqual(@as(usize, stats.faces_added), fs.fontIds().len);
    try t.expectEqual(@as(usize, 0), fs.loadedFontCount());
}

test "shapeRun recovers from a first-use broken primary without pre-touching it" {
    const t = std.testing;
    const alloc = t.allocator;
    const inter = try fontFixturePath(alloc, "Inter-Regular.ttf");
    defer alloc.free(inter);

    var fs = try FontSystem.init(alloc);
    defer fs.deinit();

    // Broken face sorts first (lowest id, exact weight/style match) and its
    // failure is still unknown on the first shape: the resolver returns it as
    // the primary.
    const broken_path = "tests/fonts/cozmic-does-not-exist.ttf";
    const broken_id = try fs.db.addFace(broken_path, 0, &.{"FreshFam"}, "FreshFam-Broken", 400, .normal, .normal, false);
    const inter_id = try fs.db.addFace(inter, 0, &.{"FreshFam"}, "FreshFam-Inter", 400, .normal, .normal, false);
    try fs.addFontSource(broken_id, broken_path, 0, false, false, null);
    try fs.addFontSource(inter_id, inter, 0, false, false, null);

    const adapter = fs.shaper() orelse return error.FontFixtureLoadFailed;
    const query = shape_mod.FontQuery{ .family_kind = .name, .family_name = "FreshFam" };
    try t.expectEqual(@as(?shape_mod.FontId, broken_id), adapter.fontFor(query));
    try t.expect(fs.canUseFontSource(broken_id));

    // No `shapeRun`/`mapGlyph` pre-touch of the broken id: the whole layout
    // run must recover by re-resolving to the valid fallback.
    var defaults = shape_mod.Attrs.init(alloc);
    defer defaults.deinit();
    defaults.family = .{ .name = "FreshFam" };
    var attrs = try shape_mod.AttrsList.init(alloc, &defaults);
    defer attrs.deinit();
    var buf = shape_mod.ShapeBuffer.init();
    defer buf.deinit(alloc);
    var out: std.ArrayList(shape_mod.ShapeGlyph) = .empty;
    defer out.deinit(alloc);
    try shape_mod.shapeRun(alloc, adapter, &buf, &out, "Hello", &attrs, 0, 5, false);
    try t.expectEqual(@as(usize, 5), out.items.len);
    for (out.items) |g| {
        try t.expect(g.glyph_id != 0);
        try t.expectEqual(inter_id, g.font_id);
    }
    // The broken source is negatively cached and stays in the database.
    try t.expect(!fs.canUseFontSource(broken_id));
    try t.expectEqual(@as(usize, 1), fs.loadedFontCount());
}

test "fallbackFor is stateless and ordered after the primary" {
    const t = std.testing;
    const alloc = t.allocator;
    const inter = try fontFixturePath(alloc, "Inter-Regular.ttf");
    defer alloc.free(inter);
    const noto = try fontFixturePath(alloc, "NotoSans-Regular.ttf");
    defer alloc.free(noto);
    const arabic = try fontFixturePath(alloc, "NotoSansArabic.ttf");
    defer alloc.free(arabic);

    var fs = try FontSystem.init(alloc);
    defer fs.deinit();
    const id_a = try fs.db.addFace(inter, 0, &.{"OrderFam"}, "OrderFam-A", 400, .normal, .normal, false);
    const id_b = try fs.db.addFace(noto, 0, &.{"OrderFam"}, "OrderFam-B", 400, .normal, .normal, false);
    const id_c = try fs.db.addFace(arabic, 0, &.{"OrderFam"}, "OrderFam-C", 400, .normal, .normal, false);
    try fs.addFontSource(id_a, inter, 0, false, false, null);
    try fs.addFontSource(id_b, noto, 0, false, false, null);
    try fs.addFontSource(id_c, arabic, 0, false, false, null);

    const adapter = fs.shaper() orelse return error.FontFixtureLoadFailed;
    const query = shape_mod.FontQuery{ .family_kind = .name, .family_name = "OrderFam" };

    // Deliberately probe out of order / before `fontFor`: the attempt index
    // alone determines the result (attempt 0 = second usable match).
    try t.expectEqual(@as(?shape_mod.FontId, id_c), adapter.fallbackFor(query, .latin, 1));
    try t.expectEqual(@as(?shape_mod.FontId, id_b), adapter.fallbackFor(query, .latin, 0));
    try t.expectEqual(@as(?shape_mod.FontId, id_a), adapter.fontFor(query));
    try t.expectEqual(@as(?shape_mod.FontId, id_b), adapter.fallbackFor(query, .latin, 0));
    try t.expectEqual(@as(?shape_mod.FontId, id_c), adapter.fallbackFor(query, .latin, 1));
    try t.expect(adapter.fallbackFor(query, .latin, 2) == null);
    // Exhaustion alone does not memoize a negative: the memo only trusts runs
    // the `note_fallback` hook reported, so direct probing stays stateless.
    try t.expectEqual(@as(?shape_mod.FontId, id_b), adapter.fallbackFor(query, .latin, 0));
}

test "failed lazy source is skipped by the resolver" {
    const t = std.testing;
    const alloc = t.allocator;
    const inter = try fontFixturePath(alloc, "Inter-Regular.ttf");
    defer alloc.free(inter);
    const noto = try fontFixturePath(alloc, "NotoSans-Regular.ttf");
    defer alloc.free(noto);

    var fs = try FontSystem.init(alloc);
    defer fs.deinit();

    // Broken face sorts first (lowest id, exact weight/style match), exactly
    // like a stale fontconfig cache entry whose file was deleted.
    const broken_path = "tests/fonts/cozmic-does-not-exist.ttf";
    const broken_id = try fs.db.addFace(broken_path, 0, &.{"Fam"}, "Fam-Broken", 400, .normal, .normal, false);
    const inter_id = try fs.db.addFace(inter, 0, &.{"Fam"}, "Fam-Inter", 400, .normal, .normal, false);
    const noto_id = try fs.db.addFace(noto, 0, &.{"Fam"}, "Fam-Noto", 400, .normal, .normal, false);
    try fs.addFontSource(broken_id, broken_path, 0, false, false, null);
    try fs.addFontSource(inter_id, inter, 0, false, false, null);
    try fs.addFontSource(noto_id, noto, 0, false, false, null);

    const adapter = fs.shaper() orelse return error.FontFixtureLoadFailed;

    // Force the broken entry's load failure. Before this, it is not known to
    // be broken; afterwards `canUseFontSource` must report it unusable.
    try t.expectError(error.FontUnavailable, adapter.shapeRun(alloc, broken_id, "Hello", false));
    try t.expect(!fs.canUseFontSource(broken_id));
    try t.expect(fs.canUseFontSource(inter_id));
    try t.expect(fs.canUseFontSource(noto_id));
    try t.expect(!fs.canUseFontSource(9999));

    // The resolver never selects the failed source...
    const query = shape_mod.FontQuery{ .family_kind = .name, .family_name = "Fam" };
    const primary = adapter.fontFor(query);
    try t.expectEqual(@as(?shape_mod.FontId, inter_id), primary);
    const fallback = adapter.fallbackFor(query, .latin, 0);
    try t.expectEqual(@as(?shape_mod.FontId, noto_id), fallback);
    try t.expect(adapter.fallbackFor(query, .latin, 1) == null);

    // ...and shaping through the resolved valid face succeeds while the
    // broken source stays in the database.
    const glyphs = try adapter.shapeRun(alloc, primary.?, "Hello", false);
    defer alloc.free(glyphs);
    try t.expectEqual(@as(usize, 5), glyphs.len);
    for (glyphs) |g| try t.expect(g.glyph_id != 0);
    try t.expect(!fs.canUseFontSource(broken_id));
}

test "scanFontDir accepts a relative dir" {
    const t = std.testing;
    const alloc = t.allocator;
    const bytes = try fontFixtureBytes(alloc, "Inter-Regular.ttf");
    defer alloc.free(bytes);

    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(t.io, .{ .sub_path = "Inter-Regular.ttf", .data = bytes });

    // Relative to the test cwd; the old `openDirAbsolute`-only scan counted
    // this as `dirs_missing`.
    const rel = try std.fs.path.join(alloc, &.{ ".zig-cache", "tmp", &tmp.sub_path });
    defer alloc.free(rel);

    var fs = try FontSystem.init(alloc);
    defer fs.deinit();
    const stats = fs.loadSystemFontsConfigured(t.io, .other, .{}, &.{rel}, false);
    try t.expectEqual(@as(usize, 1), stats.dirs_scanned);
    try t.expectEqual(@as(usize, 0), stats.dirs_missing);
    try t.expectEqual(@as(usize, 1), stats.faces_added);
    try t.expectEqual(@as(usize, 0), stats.file_errors);

    // The lazily registered relative path resolves on first shaping.
    const adapter = fs.shaper() orelse return error.FontFixtureLoadFailed;
    const id = fs.fontIds()[0];
    const glyphs = try adapter.shapeRun(alloc, id, "Hello", false);
    defer alloc.free(glyphs);
    try t.expectEqual(@as(usize, 5), glyphs.len);
    for (glyphs) |g| try t.expect(g.glyph_id != 0);
}

test "lazy mono registration keeps parsed monospaced metadata" {
    const t = std.testing;
    const alloc = t.allocator;
    const bytes = try fontFixtureBytes(alloc, "FiraMono-Medium.ttf");
    defer alloc.free(bytes);

    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(t.io, .{ .sub_path = "FiraMono-Medium.ttf", .data = bytes });
    const rel = try std.fs.path.join(alloc, &.{ ".zig-cache", "tmp", &tmp.sub_path });
    defer alloc.free(rel);

    var fs = try FontSystem.init(alloc);
    defer fs.deinit();
    const stats = fs.loadSystemFontsConfigured(t.io, .other, .{}, &.{rel}, false);
    try t.expectEqual(@as(usize, 1), stats.faces_added);
    const id = fs.fontIds()[0];

    // The parse-based scan (`addScannedFile`) must forward `meta.monospaced`
    // into `addFontSource`; the lazy entry starts unloaded.
    try t.expect(fs.db.face(id).?.monospaced);
    try t.expect(fs.isMonospace(id));
    try t.expectEqual(@as(usize, 0), fs.loadedFontCount());

    // After the lazy read the flag is still there; the space advance stays
    // unknown (`null`) because the caller did not supply one.
    const adapter = fs.shaper() orelse return error.FontFixtureLoadFailed;
    const metrics = adapter.fontMetrics(id);
    try t.expect(metrics.monospaced);
    try t.expect(metrics.monospace_width == null);
    try t.expectEqual(@as(usize, 1), fs.loadedFontCount());
}

test "registered faces suppress the system fallback scan" {
    const t = std.testing;
    const alloc = t.allocator;
    const inter_bytes = try fontFixtureBytes(alloc, "Inter-Regular.ttf");
    defer alloc.free(inter_bytes);
    const noto_bytes = try fontFixtureBytes(alloc, "NotoSans-Regular.ttf");
    defer alloc.free(noto_bytes);

    // Hermetic "system" font tree: `WINDIR/Fonts` points into the tmp dir, so
    // the fallback scan is observable without touching host fonts.
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(t.io, "Extra");
    try tmp.dir.createDirPath(t.io, "Fonts");
    try tmp.dir.writeFile(t.io, .{ .sub_path = "Extra/Inter-Regular.ttf", .data = inter_bytes });
    try tmp.dir.writeFile(t.io, .{ .sub_path = "Fonts/NotoSans-Regular.ttf", .data = noto_bytes });

    const tmp_abs = try tmpDirAbsolute(alloc, tmp);
    defer alloc.free(tmp_abs);
    const extra_abs = try std.fs.path.join(alloc, &.{ tmp_abs, "Extra" });
    defer alloc.free(extra_abs);

    var fs = try FontSystem.init(alloc);
    defer fs.deinit();
    const stats = fs.loadSystemFontsConfigured(
        t.io,
        .windows,
        .{ .windir = tmp_abs },
        &.{extra_abs},
        false,
    );
    // The explicit dir registered one face, so the `faces_added == 0` gate
    // stays closed: `WINDIR/Fonts` is not scanned. Enumeration alone (zero
    // here) is deliberately not the gate.
    try t.expectEqual(@as(usize, 1), stats.faces_added);
    try t.expectEqual(@as(usize, 1), stats.dirs_scanned);
    try t.expectEqual(@as(usize, 0), stats.dirs_missing);
    try t.expectEqual(@as(usize, 1), stats.files_seen);
    try t.expectEqual(@as(usize, 1), fs.fontIds().len);
}

test "directory fallback runs when nothing was registered" {
    const t = std.testing;
    const alloc = t.allocator;
    const noto_bytes = try fontFixtureBytes(alloc, "NotoSans-Regular.ttf");
    defer alloc.free(noto_bytes);

    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(t.io, "Fonts");
    try tmp.dir.writeFile(t.io, .{ .sub_path = "Fonts/NotoSans-Regular.ttf", .data = noto_bytes });

    const tmp_abs = try tmpDirAbsolute(alloc, tmp);
    defer alloc.free(tmp_abs);

    var fs = try FontSystem.init(alloc);
    defer fs.deinit();
    // No extra dirs and no fontconfig pass: `faces_added` is still 0, so the
    // platform directory (`WINDIR/Fonts` pointing into the tmp tree) is
    // scanned and registered lazily.
    const stats = fs.loadSystemFontsConfigured(
        t.io,
        .windows,
        .{ .windir = tmp_abs },
        &.{},
        false,
    );
    try t.expectEqual(@as(usize, 1), stats.faces_added);
    try t.expectEqual(@as(usize, 1), stats.dirs_scanned);
    try t.expectEqual(@as(usize, 1), stats.files_seen);
    try t.expectEqual(@as(usize, 0), stats.file_errors);
    try t.expectEqual(@as(usize, 1), fs.fontIds().len);
    try t.expectEqual(@as(usize, 0), fs.loadedFontCount());
}

fn addFontDataOomHelper(allocator: std.mem.Allocator, bytes: []const u8) !void {
    var fs = try FontSystem.init(allocator);
    defer fs.deinit();
    fs.addFontData(1, bytes, 0, false, null) catch |err| {
        // No partial state on any failure path: either the backend entry and
        // the enumerable id both exist, or neither does.
        try std.testing.expectEqual(@as(usize, 0), fs.fontIds().len);
        try std.testing.expect(!fs.canUseFontSource(1));
        return err;
    };
    try std.testing.expect(fs.canUseFontSource(1));
    try std.testing.expectEqual(@as(usize, 1), fs.fontIds().len);
    try std.testing.expectEqual(@as(FontId, 1), fs.fontIds()[0]);
}

test "addFontData OOM never leaves a live-but-unenumerable font (C6)" {
    const bytes = try fontFixtureBytes(std.testing.allocator, "Inter-Regular.ttf");
    defer std.testing.allocator.free(bytes);
    try std.testing.checkAllAllocationFailures(std.testing.allocator, addFontDataOomHelper, .{bytes});
}

fn addFontSourceOomHelper(allocator: std.mem.Allocator, path: []const u8) !void {
    var fs = try FontSystem.init(allocator);
    defer fs.deinit();
    fs.addFontSource(1, path, 0, false, false, null) catch |err| {
        try std.testing.expectEqual(@as(usize, 0), fs.fontIds().len);
        try std.testing.expect(!fs.canUseFontSource(1));
        return err;
    };
    try std.testing.expect(fs.canUseFontSource(1));
    try std.testing.expectEqual(@as(usize, 1), fs.fontIds().len);
    try std.testing.expectEqual(@as(FontId, 1), fs.fontIds()[0]);
}

test "addFontSource OOM never leaves a live-but-unenumerable font (C6)" {
    const path = try fontFixturePath(std.testing.allocator, "Inter-Regular.ttf");
    defer std.testing.allocator.free(path);
    try std.testing.checkAllAllocationFailures(std.testing.allocator, addFontSourceOomHelper, .{path});
}

// ---------------------------------------------------------------------------
// Fallback memo integration tests (shape_hb.Backend cache over FontSystem)
// ---------------------------------------------------------------------------

/// `ShapeAdapter` test double: counts `shape_run` calls per font and preserves
/// the order fonts were shaped in, forwarding every call (including
/// `note_fallback`) to the wrapped adapter. Proves the backend memo avoids
/// reshaping fallback candidates.
const CountingAdapter = struct {
    inner: shape_mod.ShapeAdapter,
    total_runs: usize = 0,
    counts: [8]usize = @splat(0),
    seen: [16]shape_mod.FontId = @splat(0),
    seen_len: usize = 0,

    const vtable: shape_mod.ShapeAdapter.VTable = .{
        .shape_run = shapeRun,
        .map_glyph = mapGlyph,
        .advance_em = advanceEm,
        .font_metrics = fontMetrics,
        .primary_font = primaryFont,
        .set_weight = setWeight,
        .font_for = fontFor,
        .repatch_font = repatchFont,
        .fallback_for = fallbackFor,
        .fallback_font = fallbackFont,
        .probe_pair = probePair,
        .note_fallback = noteFallback,
    };

    fn fromPtr(ptr: *anyopaque) *CountingAdapter {
        return @ptrCast(@alignCast(ptr));
    }

    fn adapter(self: *CountingAdapter) shape_mod.ShapeAdapter {
        return .{ .ptr = self, .vtable = &vtable };
    }

    fn reset(self: *CountingAdapter) void {
        self.total_runs = 0;
        self.counts = @splat(0);
        self.seen = @splat(0);
        self.seen_len = 0;
    }

    fn count(self: *const CountingAdapter, font: shape_mod.FontId) usize {
        return if (font < self.counts.len) self.counts[font] else 0;
    }

    fn shapeRun(
        ptr: *anyopaque,
        alloc: std.mem.Allocator,
        font: shape_mod.FontId,
        text: []const u8,
        rtl: bool,
    ) shape_mod.ShapeError![]shape_mod.ShapedRunGlyph {
        const self = fromPtr(ptr);
        self.total_runs += 1;
        if (font < self.counts.len) self.counts[font] += 1;
        if (self.seen_len < self.seen.len) {
            self.seen[self.seen_len] = font;
            self.seen_len += 1;
        }
        return self.inner.shapeRun(alloc, font, text, rtl);
    }

    fn mapGlyph(ptr: *anyopaque, font: shape_mod.FontId, cp: u21) u16 {
        return fromPtr(ptr).inner.mapGlyph(font, cp);
    }
    fn advanceEm(ptr: *anyopaque, font: shape_mod.FontId, glyph_id: u16) f32 {
        return fromPtr(ptr).inner.advanceEm(font, glyph_id);
    }
    fn fontMetrics(ptr: *anyopaque, font: shape_mod.FontId) shape_mod.ShapingFontMetrics {
        return fromPtr(ptr).inner.fontMetrics(font);
    }
    fn primaryFont(ptr: *anyopaque) shape_mod.FontId {
        return fromPtr(ptr).inner.primaryFont();
    }
    fn setWeight(ptr: *anyopaque, weight: u16) void {
        fromPtr(ptr).inner.setWeight(weight);
    }
    fn fontFor(ptr: *anyopaque, query: shape_mod.FontQuery) ?shape_mod.FontId {
        return fromPtr(ptr).inner.fontFor(query);
    }
    fn repatchFont(ptr: *anyopaque, query: shape_mod.FontQuery) ?shape_mod.FontId {
        return fromPtr(ptr).inner.repatchFont(query);
    }
    fn fallbackFor(
        ptr: *anyopaque,
        query: shape_mod.FontQuery,
        script: shape_mod.Script,
        attempt: usize,
    ) ?shape_mod.FontId {
        return fromPtr(ptr).inner.fallbackFor(query, script, attempt);
    }
    fn fallbackFont(ptr: *anyopaque, script: shape_mod.Script, attempt: usize) ?shape_mod.FontId {
        return fromPtr(ptr).inner.fallbackFont(script, attempt);
    }
    fn probePair(ptr: *anyopaque, font: shape_mod.FontId, c1: u21, c2: u21) shape_mod.ProbeResult {
        return fromPtr(ptr).inner.probePair(font, c1, c2);
    }
    fn noteFallback(
        ptr: *anyopaque,
        query: shape_mod.FontQuery,
        script: shape_mod.Script,
        font: shape_mod.FontId,
        covered: bool,
    ) void {
        fromPtr(ptr).inner.noteFallback(query, script, font, covered);
    }
};

const MemoIds = struct { inter: FontId, arabic: FontId, hebrew: FontId };

/// Register the vendored Inter/Arabic/Hebrew fixtures as lazy shaper sources
/// with distinct families and make Inter the sans default, mirroring the
/// `bench-shaping` setup (Arabic sorts before Hebrew as the first fallback).
fn registerMemoFixtures(
    fs: *FontSystem,
    inter: []const u8,
    arabic: []const u8,
    hebrew: []const u8,
) !MemoIds {
    const ids = MemoIds{
        .inter = try fs.db.addFace(inter, 0, &.{"Inter"}, "Inter", 400, .normal, .normal, false),
        .arabic = try fs.db.addFace(arabic, 0, &.{"Noto Sans Arabic"}, "NotoSansArabic", 400, .normal, .normal, false),
        .hebrew = try fs.db.addFace(hebrew, 0, &.{"Noto Sans Hebrew"}, "NotoSansHebrew", 400, .normal, .normal, false),
    };
    try fs.addFontSource(ids.inter, inter, 0, false, false, null);
    try fs.addFontSource(ids.arabic, arabic, 0, false, false, null);
    try fs.addFontSource(ids.hebrew, hebrew, 0, false, false, null);
    try fs.dbMut().setSansFamily("Inter");
    return ids;
}

/// Shape `text` as one run, replacing `out` (keeps the memo test bodies
/// focused on call counts).
fn shapeMemoRun(
    alloc: std.mem.Allocator,
    adapter: shape_mod.ShapeAdapter,
    buf: *shape_mod.ShapeBuffer,
    out: *std.ArrayList(shape_mod.ShapeGlyph),
    attrs: *const shape_mod.AttrsList,
    text: []const u8,
) !void {
    out.clearRetainingCapacity();
    try shape_mod.shapeRun(alloc, adapter, buf, out, text, attrs, 0, text.len, false);
}

test "fallback memo: a covering fallback is tried first for later runs" {
    const t = std.testing;
    const alloc = t.allocator;
    const inter = try fontFixturePath(alloc, "Inter-Regular.ttf");
    defer alloc.free(inter);
    const arabic = try fontFixturePath(alloc, "NotoSansArabic.ttf");
    defer alloc.free(arabic);
    const hebrew = try fontFixturePath(alloc, "NotoSansHebrew.ttf");
    defer alloc.free(hebrew);

    var fs = try FontSystem.init(alloc);
    defer fs.deinit();
    const ids = try registerMemoFixtures(&fs, inter, arabic, hebrew);
    const inner = fs.shaper() orelse return error.FontFixtureLoadFailed;
    var counter = CountingAdapter{ .inner = inner };
    const adapter = counter.adapter();

    var defaults = shape_mod.Attrs.init(alloc);
    defer defaults.deinit();
    var attrs = try shape_mod.AttrsList.init(alloc, &defaults);
    defer attrs.deinit();
    var buf = shape_mod.ShapeBuffer.init();
    defer buf.deinit(alloc);
    var out: std.ArrayList(shape_mod.ShapeGlyph) = .empty;
    defer out.deinit(alloc);

    const hebrew_word = "\u{05E9}\u{05DC}\u{05D5}\u{05DD}"; // שלום
    try shapeMemoRun(alloc, adapter, &buf, &out, &attrs, hebrew_word);
    // Inter misses the script; the Arabic fallback misses it too; Hebrew
    // covers all four letters on the second fallback attempt.
    try t.expectEqual(@as(usize, 3), counter.total_runs);
    try t.expectEqual(@as(usize, 1), counter.count(ids.arabic));
    try t.expectEqual(@as(usize, 1), counter.count(ids.hebrew));
    for (out.items) |g| {
        try t.expect(g.glyph_id != 0);
        try t.expectEqual(ids.hebrew, g.font_id);
    }

    counter.reset();
    try shapeMemoRun(alloc, adapter, &buf, &out, &attrs, hebrew_word);
    // Memoized Hebrew is attempt 0: Arabic is not rescanned, only the primary
    // and the covering font are shaped.
    try t.expectEqual(@as(usize, 2), counter.total_runs);
    try t.expectEqual(@as(usize, 0), counter.count(ids.arabic));
    try t.expectEqual(@as(usize, 1), counter.count(ids.hebrew));
    try t.expectEqual(ids.hebrew, counter.seen[1]);
    try t.expectEqual(@as(usize, 1), fs.shaper_backend.?.fallbackMemoSize());
    for (out.items) |g| try t.expectEqual(ids.hebrew, g.font_id);
}

test "fallback memo: a preferred miss continues the scan without retrying" {
    const t = std.testing;
    const alloc = t.allocator;
    const inter = try fontFixturePath(alloc, "Inter-Regular.ttf");
    defer alloc.free(inter);
    const arabic = try fontFixturePath(alloc, "NotoSansArabic.ttf");
    defer alloc.free(arabic);
    const hebrew = try fontFixturePath(alloc, "NotoSansHebrew.ttf");
    defer alloc.free(hebrew);

    var fs = try FontSystem.init(alloc);
    defer fs.deinit();
    const ids = try registerMemoFixtures(&fs, inter, arabic, hebrew);
    const inner = fs.shaper() orelse return error.FontFixtureLoadFailed;
    var counter = CountingAdapter{ .inner = inner };
    const adapter = counter.adapter();

    var defaults = shape_mod.Attrs.init(alloc);
    defer defaults.deinit();
    var attrs = try shape_mod.AttrsList.init(alloc, &defaults);
    defer attrs.deinit();
    var buf = shape_mod.ShapeBuffer.init();
    defer buf.deinit(alloc);
    var out: std.ArrayList(shape_mod.ShapeGlyph) = .empty;
    defer out.deinit(alloc);

    // One Arabic letter + one Hebrew letter: no single fallback covers the
    // run, so both candidates must shape and their glyphs splice together.
    const mixed_word = "\u{0645}\u{05E9}"; // م ש
    try shapeMemoRun(alloc, adapter, &buf, &out, &attrs, mixed_word);
    try t.expectEqual(@as(usize, 3), counter.total_runs);
    try t.expectEqual(@as(usize, 1), counter.count(ids.arabic));
    try t.expectEqual(@as(usize, 1), counter.count(ids.hebrew));

    // The last covering font (Hebrew) is memoized first. It misses the Arabic
    // letter, so the ordered scan continues with Arabic; no candidate is
    // shaped twice and no candidate is skipped.
    counter.reset();
    try shapeMemoRun(alloc, adapter, &buf, &out, &attrs, mixed_word);
    try t.expectEqual(@as(usize, 3), counter.total_runs);
    try t.expectEqual(@as(usize, 1), counter.count(ids.inter));
    try t.expectEqual(@as(usize, 1), counter.count(ids.arabic));
    try t.expectEqual(@as(usize, 1), counter.count(ids.hebrew));
    try t.expectEqual(ids.hebrew, counter.seen[1]);
    try t.expectEqual(ids.arabic, counter.seen[2]);
    var covered_by_arabic = false;
    var covered_by_hebrew = false;
    for (out.items) |g| {
        try t.expect(g.glyph_id != 0);
        if (g.font_id == ids.arabic) covered_by_arabic = true;
        if (g.font_id == ids.hebrew) covered_by_hebrew = true;
    }
    try t.expect(covered_by_arabic and covered_by_hebrew);
}

test "fallback memo: a script no font covers is not rescanned" {
    const t = std.testing;
    const alloc = t.allocator;
    const inter = try fontFixturePath(alloc, "Inter-Regular.ttf");
    defer alloc.free(inter);
    const arabic = try fontFixturePath(alloc, "NotoSansArabic.ttf");
    defer alloc.free(arabic);
    const hebrew = try fontFixturePath(alloc, "NotoSansHebrew.ttf");
    defer alloc.free(hebrew);

    var fs = try FontSystem.init(alloc);
    defer fs.deinit();
    const ids = try registerMemoFixtures(&fs, inter, arabic, hebrew);
    const inner = fs.shaper() orelse return error.FontFixtureLoadFailed;
    var counter = CountingAdapter{ .inner = inner };
    const adapter = counter.adapter();

    var defaults = shape_mod.Attrs.init(alloc);
    defer defaults.deinit();
    var attrs = try shape_mod.AttrsList.init(alloc, &defaults);
    defer attrs.deinit();
    var buf = shape_mod.ShapeBuffer.init();
    defer buf.deinit(alloc);
    var out: std.ArrayList(shape_mod.ShapeGlyph) = .empty;
    defer out.deinit(alloc);

    const devanagari = "\u{0928}\u{092E}\u{0938}\u{094D}\u{0924}\u{0947}"; // नमस्ते
    try shapeMemoRun(alloc, adapter, &buf, &out, &attrs, devanagari);
    // Inter misses; both fallback candidates are shaped and cover nothing.
    try t.expectEqual(@as(usize, 3), counter.total_runs);
    try t.expectEqual(@as(usize, 1), counter.count(ids.arabic));
    try t.expectEqual(@as(usize, 1), counter.count(ids.hebrew));

    counter.reset();
    try shapeMemoRun(alloc, adapter, &buf, &out, &attrs, devanagari);
    // Negative memo: attempt 0 answers null, so only the primary is shaped.
    try t.expectEqual(@as(usize, 1), counter.total_runs);
    try t.expectEqual(@as(usize, 0), counter.count(ids.arabic));
    try t.expectEqual(@as(usize, 0), counter.count(ids.hebrew));
    for (out.items) |g| {
        try t.expectEqual(ids.inter, g.font_id);
        try t.expectEqual(@as(u16, 0), g.glyph_id);
    }
}

test "fallback memo: registering a covering font invalidates the negative" {
    const t = std.testing;
    const alloc = t.allocator;
    const inter = try fontFixturePath(alloc, "Inter-Regular.ttf");
    defer alloc.free(inter);
    const arabic = try fontFixturePath(alloc, "NotoSansArabic.ttf");
    defer alloc.free(arabic);
    const hebrew = try fontFixturePath(alloc, "NotoSansHebrew.ttf");
    defer alloc.free(hebrew);

    var fs = try FontSystem.init(alloc);
    defer fs.deinit();
    // Only Inter and Hebrew first: Arabic is absent, so Arabic text scans the
    // whole candidate list without coverage.
    const inter_id = try fs.db.addFace(inter, 0, &.{"Inter"}, "Inter", 400, .normal, .normal, false);
    const hebrew_id = try fs.db.addFace(hebrew, 0, &.{"Noto Sans Hebrew"}, "NotoSansHebrew", 400, .normal, .normal, false);
    try fs.addFontSource(inter_id, inter, 0, false, false, null);
    try fs.addFontSource(hebrew_id, hebrew, 0, false, false, null);
    try fs.dbMut().setSansFamily("Inter");

    const inner = fs.shaper() orelse return error.FontFixtureLoadFailed;
    var counter = CountingAdapter{ .inner = inner };
    const adapter = counter.adapter();

    var defaults = shape_mod.Attrs.init(alloc);
    defer defaults.deinit();
    var attrs = try shape_mod.AttrsList.init(alloc, &defaults);
    defer attrs.deinit();
    var buf = shape_mod.ShapeBuffer.init();
    defer buf.deinit(alloc);
    var out: std.ArrayList(shape_mod.ShapeGlyph) = .empty;
    defer out.deinit(alloc);

    const arabic_word = "\u{0645}\u{0631}\u{062D}\u{0628}\u{0627}"; // مرحبا
    try shapeMemoRun(alloc, adapter, &buf, &out, &attrs, arabic_word);
    try t.expectEqual(@as(usize, 2), counter.total_runs);
    try t.expectEqual(@as(usize, 1), counter.count(hebrew_id));

    counter.reset();
    try shapeMemoRun(alloc, adapter, &buf, &out, &attrs, arabic_word);
    try t.expectEqual(@as(usize, 1), counter.total_runs); // negative hit

    // Register the missing script's face: registration must clear the memo,
    // otherwise the negative would keep Arabic text uncovered forever.
    const arabic_id = try fs.db.addFace(arabic, 0, &.{"Noto Sans Arabic"}, "NotoSansArabic", 400, .normal, .normal, false);
    try fs.addFontSource(arabic_id, arabic, 0, false, false, null);
    fs.clearMatchesCache();

    counter.reset();
    try shapeMemoRun(alloc, adapter, &buf, &out, &attrs, arabic_word);
    try t.expectEqual(@as(usize, 3), counter.total_runs);
    try t.expectEqual(@as(usize, 1), counter.count(hebrew_id));
    try t.expectEqual(@as(usize, 1), counter.count(arabic_id));
    for (out.items) |g| {
        try t.expect(g.glyph_id != 0);
        try t.expectEqual(arabic_id, g.font_id);
    }
}

test "fallback memo is bounded and clears at the cap" {
    const t = std.testing;
    const alloc = t.allocator;
    const bytes = try fontFixtureBytes(alloc, "Inter-Regular.ttf");
    defer alloc.free(bytes);

    var fs = try FontSystem.init(alloc);
    defer fs.deinit();
    try fs.addFontData(1, bytes, 0, false, null);
    const adapter = fs.shaper() orelse return error.FontFixtureLoadFailed;
    const backend = &fs.shaper_backend.?;

    // Distinct queries fill the map past `FALLBACK_MEMO_CAP`.
    var name_buf: [32]u8 = undefined;
    var i: usize = 0;
    while (i < shape_hb.FALLBACK_MEMO_CAP + 10) : (i += 1) {
        const name = try std.fmt.bufPrint(&name_buf, "MemoFam{d}", .{i});
        adapter.noteFallback(.{ .family_kind = .name, .family_name = name }, .latin, 1, true);
    }
    // The cap evicts by clearing wholesale, so the map stays bounded and the
    // most recent entries still resolve to their covering font.
    try t.expect(backend.fallbackMemoSize() > 0);
    try t.expect(backend.fallbackMemoSize() <= shape_hb.FALLBACK_MEMO_CAP);
    const last_name = try std.fmt.bufPrint(&name_buf, "MemoFam{d}", .{shape_hb.FALLBACK_MEMO_CAP + 9});
    try t.expectEqual(
        @as(?shape_mod.FontId, 1),
        adapter.fallbackFor(.{ .family_kind = .name, .family_name = last_name }, .latin, 0),
    );
}
