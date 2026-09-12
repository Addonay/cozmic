//! Port of cosmic-text `font/fallback/*` (fallback lists + iterator).
//!
//! Self-contained: defines local `Weight` / `Stretch` / `Style` / `Family` /
//! `Script` aliases at the top instead of importing `attrs.zig` or unicode
//! tables. Unify these aliases with the attrs/font-system modules later; keep
//! this file compiling standalone until then.
//!
//! Platform tables mirror `fallback/unix.rs` exactly (common Noto/DejaVu/
//! FreeSans/Symbols2/Emoji list, per-script `Noto Sans <Script>` entries, and
//! `han_unification` ja/ko/zh-HK/zh-TW routing). `EmptyFallback` mirrors
//! `fallback/other.rs`. Production code selects `PlatformFallback`
//! (unix) on Linux; the `Fallback` tagged union is the `Fallback` trait
//! equivalent and also carries a `custom` case for tests.
//!
//! PRODUCTION GAPS vs Rust `font/fallback/mod.rs:289-484` (`FontFallbackIter`):
//! The standalone `FontFallbackIter` below mirrors the phase order
//! (mono-buffer -> default families -> script -> common -> other -> end) and
//! the `MonospaceFallbackInfo` ordering, but `SimpleDb` is a mock (id +
//! families + mono flag + weight stub) rather than `FontSystem` + `FontDb`.
//! Implemented minimally here (C5):
//! - `ideal_weight` filtering: non-mono phases only consider candidates with
//!   `weight_diff==0` or `variable_weight_match` (Rust `font_match_keys_iter(false)`);
//!   the `other` phase and mono enumeration keep all candidates.
//! - per-candidate `weight_diff` + `codepoint_non_matches` ranking for the
//!   mono buffer via `coverage_fn` (caller-provided supported-count callback;
//!   null hook assumes full coverage). Mirrors `get_font_supported_codepoints_in_word`.
//! - `loadable_fn` null-skip: candidates where `get_font` would return null
//!   are skipped (Rust `if let Some(font) = get_font(...)`).
//! Still TODO for full production wiring (`FontSystem` integration):
//! - `per_script_monospace_font_ids` script-scoped mono filtering
//!   (currently falls back to `isMonospace` for all scripts).
//! - real shaping/codepoint caches (`shape_buffer`, `font_codepoint_support_info_cache`)
//!   instead of the `coverage_fn` stub.
//! - `check_missing` diagnostics (`warn_on_missing_glyphs` logging).
//! Keep `SimpleDb` for tests but wire to `FontSystem` when cross-file imports allow.

const std = @import("std");

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
};

pub const Style = enum {
    normal,
    italic,
    oblique,
};

pub const Family = union(enum) {
    name: []const u8,
    serif: void,
    sans_serif: void,
    cursive: void,
    fantasy: void,
    monospace: void,

    pub fn eql(a: Family, b: Family) bool {
        if (std.meta.activeTag(a) != std.meta.activeTag(b)) return false;
        return switch (a) {
            .name => |an| std.mem.eql(u8, an, b.name),
            else => true,
        };
    }
};

pub const FontId = u32;

/// Script selector for per-script fallbacks.
///
/// Covers every script named in `fallback/unix.rs`; anything else maps to
/// `unknown` (which, like Rust's `_ => &[]`, yields no script fallback).
pub const Script = enum {
    adlam,
    arabic,
    armenian,
    bengali,
    bopomofo,
    braille,
    buhid,
    chakma,
    cherokee,
    deseret,
    devanagari,
    ethiopic,
    georgian,
    gothic,
    grantha,
    gujarati,
    gurmukhi,
    han,
    hangul,
    hanunoo,
    hebrew,
    hiragana,
    javanese,
    kannada,
    katakana,
    khmer,
    lao,
    malayalam,
    mongolian,
    myanmar,
    oriya,
    runic,
    sinhala,
    syriac,
    tagalog,
    tagbanwa,
    tai_le,
    tai_tham,
    tai_viet,
    tamil,
    telugu,
    thaana,
    thai,
    tibetan,
    tifinagh,
    vai,
    yi,
    unknown,
};

// ---------------------------------------------------------------------------
// Platform tables (verbatim from fallback/unix.rs).
// ---------------------------------------------------------------------------

const COMMON_FALLBACK: []const []const u8 = &.{
    "Noto Sans",
    "DejaVu Sans",
    "FreeSans",
    "Noto Sans Mono",
    "DejaVu Sans Mono",
    "FreeMono",
    "Noto Sans Symbols",
    "Noto Sans Symbols2",
    "Noto Color Emoji",
};

const FORBIDDEN_FALLBACK: []const []const u8 = &.{};

const CJK_JP: []const []const u8 = &.{"Noto Sans CJK JP"};
const CJK_KR: []const []const u8 = &.{"Noto Sans CJK KR"};
const CJK_HK: []const []const u8 = &.{"Noto Sans CJK HK"};
const CJK_TC: []const []const u8 = &.{"Noto Sans CJK TC"};
const CJK_SC: []const []const u8 = &.{"Noto Sans CJK SC"};

const S_ADLAM: []const []const u8 = &.{ "Noto Sans Adlam", "Noto Sans Adlam Unjoined" };
const S_ARABIC: []const []const u8 = &.{"Noto Sans Arabic"};
const S_ARMENIAN: []const []const u8 = &.{"Noto Sans Armenian"};
const S_BENGALI: []const []const u8 = &.{"Noto Sans Bengali"};
const S_BRAILLE: []const []const u8 = &.{"FreeMono"};
const S_BUHID: []const []const u8 = &.{"Noto Sans Buhid"};
const S_CHAKMA: []const []const u8 = &.{"Noto Sans Chakma"};
const S_CHEROKEE: []const []const u8 = &.{"Noto Sans Cherokee"};
const S_DESERET: []const []const u8 = &.{"Noto Sans Deseret"};
const S_DEVANAGARI: []const []const u8 = &.{"Noto Sans Devanagari"};
const S_ETHIOPIC: []const []const u8 = &.{"Noto Sans Ethiopic"};
const S_GEORGIAN: []const []const u8 = &.{"Noto Sans Georgian"};
const S_GOTHIC: []const []const u8 = &.{"Noto Sans Gothic"};
const S_GRANTHA: []const []const u8 = &.{"Noto Sans Grantha"};
const S_GUJARATI: []const []const u8 = &.{"Noto Sans Gujarati"};
const S_GURMUKHI: []const []const u8 = &.{"Noto Sans Gurmukhi"};
const S_HANUNOO: []const []const u8 = &.{"Noto Sans Hanunoo"};
const S_HEBREW: []const []const u8 = &.{"Noto Sans Hebrew"};
const S_JAVANESE: []const []const u8 = &.{"Noto Sans Javanese"};
const S_KANNADA: []const []const u8 = &.{"Noto Sans Kannada"};
const S_KHMER: []const []const u8 = &.{"Noto Sans Khmer"};
const S_LAO: []const []const u8 = &.{"Noto Sans Lao"};
const S_MALAYALAM: []const []const u8 = &.{"Noto Sans Malayalam"};
const S_MONGOLIAN: []const []const u8 = &.{"Noto Sans Mongolian"};
const S_MYANMAR: []const []const u8 = &.{"Noto Sans Myanmar"};
const S_ORIYA: []const []const u8 = &.{"Noto Sans Oriya"};
const S_RUNINC: []const []const u8 = &.{"Noto Sans Runic"};
const S_SINHALA: []const []const u8 = &.{"Noto Sans Sinhala"};
const S_SYRIAC: []const []const u8 = &.{"Noto Sans Syriac"};
const S_TAGALOG: []const []const u8 = &.{"Noto Sans Tagalog"};
const S_TAGBANWA: []const []const u8 = &.{"Noto Sans Tagbanwa"};
const S_TAI_LE: []const []const u8 = &.{"Noto Sans Tai Le"};
const S_TAI_THAM: []const []const u8 = &.{"Noto Sans Tai Tham"};
const S_TAI_VIET: []const []const u8 = &.{"Noto Sans Tai Viet"};
const S_TAMIL: []const []const u8 = &.{"Noto Sans Tamil"};
const S_TELUGU: []const []const u8 = &.{"Noto Sans Telugu"};
const S_THAANA: []const []const u8 = &.{"Noto Sans Thaana"};
const S_THAI: []const []const u8 = &.{"Noto Sans Thai"};
const S_TIBETAN: []const []const u8 = &.{"Noto Serif Tibetan"};
const S_TIFINAGH: []const []const u8 = &.{"Noto Sans Tifinagh"};
const S_VAI: []const []const u8 = &.{"Noto Sans Vai"};
const S_YI: []const []const u8 = &.{ "Noto Sans Yi", "Noto Sans CJK SC" };
const S_EMPTY: []const []const u8 = &.{};

/// Han unification routing, verbatim from `unix.rs`.
/// Matches the locale exactly; anything else (including "zh-CN")
/// falls back to Simplified Chinese.
pub fn hanUnification(locale: []const u8) []const []const u8 {
    if (std.mem.eql(u8, locale, "ja")) return CJK_JP;
    if (std.mem.eql(u8, locale, "ko")) return CJK_KR;
    if (std.mem.eql(u8, locale, "zh-HK")) return CJK_HK;
    if (std.mem.eql(u8, locale, "zh-TW")) return CJK_TC;
    return CJK_SC;
}

/// Per-script fallbacks, verbatim from `unix.rs`.
pub fn scriptFallbackUnix(script: Script, locale: []const u8) []const []const u8 {
    return switch (script) {
        .adlam => S_ADLAM,
        .arabic => S_ARABIC,
        .armenian => S_ARMENIAN,
        .bengali => S_BENGALI,
        .bopomofo => hanUnification(locale),
        .braille => S_BRAILLE,
        .buhid => S_BUHID,
        .chakma => S_CHAKMA,
        .cherokee => S_CHEROKEE,
        .deseret => S_DESERET,
        .devanagari => S_DEVANAGARI,
        .ethiopic => S_ETHIOPIC,
        .georgian => S_GEORGIAN,
        .gothic => S_GOTHIC,
        .grantha => S_GRANTHA,
        .gujarati => S_GUJARATI,
        .gurmukhi => S_GURMUKHI,
        .han => hanUnification(locale),
        .hangul => hanUnification("ko"),
        .hanunoo => S_HANUNOO,
        .hebrew => S_HEBREW,
        .hiragana => hanUnification("ja"),
        .javanese => S_JAVANESE,
        .kannada => S_KANNADA,
        .katakana => hanUnification("ja"),
        .khmer => S_KHMER,
        .lao => S_LAO,
        .malayalam => S_MALAYALAM,
        .mongolian => S_MONGOLIAN,
        .myanmar => S_MYANMAR,
        .oriya => S_ORIYA,
        .runic => S_RUNINC,
        .sinhala => S_SINHALA,
        .syriac => S_SYRIAC,
        .tagalog => S_TAGALOG,
        .tagbanwa => S_TAGBANWA,
        .tai_le => S_TAI_LE,
        .tai_tham => S_TAI_THAM,
        .tai_viet => S_TAI_VIET,
        .tamil => S_TAMIL,
        .telugu => S_TELUGU,
        .thaana => S_THAANA,
        .thai => S_THAI,
        .tibetan => S_TIBETAN,
        .tifinagh => S_TIFINAGH,
        .vai => S_VAI,
        .yi => S_YI,
        .unknown => S_EMPTY,
    };
}

// ---------------------------------------------------------------------------
// Fallback trait as a tagged union.
// ---------------------------------------------------------------------------

pub const PlatformFallback = struct {
    pub fn commonFallback(_: PlatformFallback) []const []const u8 {
        return COMMON_FALLBACK;
    }
    pub fn forbiddenFallback(_: PlatformFallback) []const []const u8 {
        return FORBIDDEN_FALLBACK;
    }
    pub fn scriptFallback(_: PlatformFallback, script: Script, locale: []const u8) []const []const u8 {
        return scriptFallbackUnix(script, locale);
    }
};

/// Mirrors `fallback/other.rs`: no presets on unknown platforms.
pub const EmptyFallback = struct {
    pub fn commonFallback(_: EmptyFallback) []const []const u8 {
        return S_EMPTY;
    }
    pub fn forbiddenFallback(_: EmptyFallback) []const []const u8 {
        return S_EMPTY;
    }
    pub fn scriptFallback(_: EmptyFallback, _: Script, _: []const u8) []const []const u8 {
        return S_EMPTY;
    }
};

/// Injectable fallback for tests and embedders: fixed common/forbidden
/// lists and no script-specific entries.
pub const CustomFallback = struct {
    common: []const []const u8 = &.{},
    forbidden: []const []const u8 = &.{},

    pub fn commonFallback(self: CustomFallback) []const []const u8 {
        return self.common;
    }
    pub fn forbiddenFallback(self: CustomFallback) []const []const u8 {
        return self.forbidden;
    }
    pub fn scriptFallback(_: CustomFallback, _: Script, _: []const u8) []const []const u8 {
        return S_EMPTY;
    }
};

/// `Fallback` trait equivalent.
pub const Fallback = union(enum) {
    platform_unix: PlatformFallback,
    empty: EmptyFallback,
    custom: CustomFallback,

    pub fn commonFallback(self: Fallback) []const []const u8 {
        return switch (self) {
            .platform_unix => |p| p.commonFallback(),
            .empty => |e| e.commonFallback(),
            .custom => |c| c.commonFallback(),
        };
    }

    pub fn forbiddenFallback(self: Fallback) []const []const u8 {
        return switch (self) {
            .platform_unix => |p| p.forbiddenFallback(),
            .empty => |e| e.forbiddenFallback(),
            .custom => |c| c.forbiddenFallback(),
        };
    }

    pub fn scriptFallback(self: Fallback, script: Script, locale: []const u8) []const []const u8 {
        return switch (self) {
            .platform_unix => |p| p.scriptFallback(script, locale),
            .empty => |e| e.scriptFallback(script, locale),
            .custom => |c| c.scriptFallback(script, locale),
        };
    }
};

// ---------------------------------------------------------------------------
// Flattened fallback lists (mirrors `Fallbacks`).
// ---------------------------------------------------------------------------

pub const Range = struct {
    start: usize,
    end: usize,
};

/// Flattened fallback lists with ranges into one `lists` buffer.
/// Mirrors `Fallbacks::new`/`extend` (common + forbidden first, then one
/// range per requested script, looked up lazily via `extend`).
pub const Fallbacks = struct {
    lists: std.ArrayList([]const u8),
    common_range: Range,
    forbidden_range: Range,
    script_ranges: std.AutoHashMap(Script, Range),
    locale: []u8,
    allocator: std.mem.Allocator,

    pub fn init(
        allocator: std.mem.Allocator,
        fallback: Fallback,
        scripts: []const Script,
        locale: []const u8,
    ) std.mem.Allocator.Error!Fallbacks {
        var lists = std.ArrayList([]const u8).empty;
        errdefer lists.deinit(allocator);

        try lists.appendSlice(allocator, fallback.commonFallback());
        const common_range = Range{ .start = 0, .end = lists.items.len };
        try lists.appendSlice(allocator, fallback.forbiddenFallback());
        const forbidden_range = Range{ .start = common_range.end, .end = lists.items.len };

        var script_ranges = std.AutoHashMap(Script, Range).init(allocator);
        errdefer script_ranges.deinit();
        for (scripts) |script| {
            if (script_ranges.get(script) != null) continue;
            const start = lists.items.len;
            try lists.appendSlice(allocator, fallback.scriptFallback(script, locale));
            try script_ranges.put(script, .{ .start = start, .end = lists.items.len });
        }

        const owned_locale = try allocator.dupe(u8, locale);
        return .{
            .lists = lists,
            .common_range = common_range,
            .forbidden_range = forbidden_range,
            .script_ranges = script_ranges,
            .locale = owned_locale,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Fallbacks) void {
        self.lists.deinit(self.allocator);
        self.script_ranges.deinit();
        self.allocator.free(self.locale);
        self.* = undefined;
    }

    /// Lazily add script ranges missing from the map (mirrors `extend`).
    pub fn extend(self: *Fallbacks, fallback: Fallback, scripts: []const Script) std.mem.Allocator.Error!void {
        for (scripts) |script| {
            if (self.script_ranges.get(script) != null) continue;
            const start = self.lists.items.len;
            try self.lists.appendSlice(self.allocator, fallback.scriptFallback(script, self.locale));
            try self.script_ranges.put(script, .{ .start = start, .end = self.lists.items.len });
        }
    }

    pub fn commonFallback(self: *const Fallbacks) []const []const u8 {
        return self.lists.items[self.common_range.start..self.common_range.end];
    }

    pub fn forbiddenFallback(self: *const Fallbacks) []const []const u8 {
        return self.lists.items[self.forbidden_range.start..self.forbidden_range.end];
    }

    pub fn scriptFallback(self: *const Fallbacks, script: Script) []const []const u8 {
        if (self.script_ranges.get(script)) |r| {
            return self.lists.items[r.start..r.end];
        }
        return &.{};
    }
};

// ---------------------------------------------------------------------------
// Monospace fallback ordering.
// ---------------------------------------------------------------------------

/// Mirrors `MonospaceFallbackInfo` derived `Ord`:
/// `font_weight_diff` (None first), then `codepoint_non_matches`
/// (None first), then `font_weight`, then `id`.
pub const MonospaceFallbackInfo = struct {
    font_weight_diff: ?u16,
    codepoint_non_matches: ?usize,
    font_weight: u16,
    id: FontId,

    fn optU16Less(a: ?u16, b: ?u16) ?bool {
        if (a == null and b == null) return null;
        if (a == null) return true;
        if (b == null) return false;
        if (a.? != b.?) return a.? < b.?;
        return null;
    }

    fn optUsizeLess(a: ?usize, b: ?usize) ?bool {
        if (a == null and b == null) return null;
        if (a == null) return true;
        if (b == null) return false;
        if (a.? != b.?) return a.? < b.?;
        return null;
    }

    pub fn lessThan(a: MonospaceFallbackInfo, b: MonospaceFallbackInfo) bool {
        if (optU16Less(a.font_weight_diff, b.font_weight_diff)) |r| return r;
        if (optUsizeLess(a.codepoint_non_matches, b.codepoint_non_matches)) |r| return r;
        if (a.font_weight != b.font_weight) return a.font_weight < b.font_weight;
        return a.id < b.id;
    }

    pub fn eql(a: MonospaceFallbackInfo, b: MonospaceFallbackInfo) bool {
        return a.font_weight_diff == b.font_weight_diff and
            a.codepoint_non_matches == b.codepoint_non_matches and
            a.font_weight == b.font_weight and
            a.id == b.id;
    }
};

// ---------------------------------------------------------------------------
// Minimal mock database + fallback iterator.
// ---------------------------------------------------------------------------

/// Minimal face view for the standalone iterator.
/// Production wiring replaces this with `FontSystem` + `FontDb`
/// (see `font_system.zig`; unification TODO in header).
/// `weight` + `variable_wght_*` drive the C5 `ideal_weight` filtering and
/// mono ranking; defaults preserve the legacy "all NORMAL, full coverage"
/// test behaviour.
pub const SimpleFace = struct {
    id: FontId,
    families: []const []const u8,
    monospaced: bool = false,
    weight: Weight = WEIGHT_NORMAL,
    variable_wght_min: ?Weight = null,
    variable_wght_max: ?Weight = null,
};

/// Variable-weight coverage for the mock db (mirrors
/// `font_system.variableWeightMatch`; TODO unify when imports allow).
fn simpleVariableMatch(wanted: Weight, nominal: Weight, lo: ?Weight, hi: ?Weight) bool {
    if (wanted == nominal) return false;
    const l = lo orelse return false;
    const h = hi orelse return false;
    const lo_u = if (l <= h) l else h;
    const hi_u = if (l <= h) h else l;
    return wanted >= lo_u and wanted <= hi_u;
}

fn absDiffU16(a: u16, b: u16) u16 {
    return if (a >= b) a - b else b - a;
}

pub const SimpleDb = struct {
    faces: []const SimpleFace,

    pub fn face(self: SimpleDb, id: FontId) ?*const SimpleFace {
        for (self.faces) |*f| {
            if (f.id == id) return f;
        }
        return null;
    }

    pub fn faceContainsFamily(self: SimpleDb, id: FontId, family_name: []const u8) bool {
        const f = self.face(id) orelse return false;
        for (f.families) |name| {
            if (std.mem.eql(u8, name, family_name)) return true;
        }
        return false;
    }

    pub fn isMonospace(self: SimpleDb, id: FontId) bool {
        const f = self.face(id) orelse return false;
        return f.monospaced;
    }

    pub fn weightOf(self: SimpleDb, id: FontId) Weight {
        const f = self.face(id) orelse return WEIGHT_NORMAL;
        return f.weight;
    }
};

/// Minimal match-key view (id only; full weight/style ordering lives in
/// `font_system.zig`'s `FontMatchKey`).
pub const SimpleMatchKey = struct {
    id: FontId,
};

fn familyName(family: Family) ?[]const u8 {
    return switch (family) {
        .name => |n| n,
        else => null,
    };
}

/// Standalone fallback iterator yielding font ids.
///
/// State-machine order mirrors `FontFallbackIter::next_item`:
/// mono-buffer pop -> default families (mono vs non-mono branch) ->
/// script -> common -> other -> end.
///
/// C5 minimal production steps (see header gaps):
/// - `ideal_weight` filters non-mono phases (`weight_diff==0` or variable).
/// - mono buffer ranks by (`weight_diff`, `codepoint_non_matches`) via
///   `coverage_fn`; null hook assumes full coverage.
/// - `loadable_fn` null-skips candidates where `get_font` would return null.
/// Set `ideal_weight`/`word`/`coverage_fn`/`loadable_fn` after `init`
/// (defaults preserve legacy tests: NORMAL, empty word, full coverage).
pub const FontFallbackIter = struct {
    db: *const SimpleDb,
    font_match_keys: []const SimpleMatchKey,
    default_families: []const Family,
    scripts: []const Script,
    fallbacks: *const Fallbacks,
    default_i: usize = 0,
    script_i: [2]usize = .{ 0, 0 },
    common_i: usize = 0,
    other_i: usize = 0,
    end: bool = false,
    /// Wanted weight for filtering/ranking (Rust `ideal_weight`).
    ideal_weight: Weight = WEIGHT_NORMAL,
    /// Word for codepoint-coverage ranking (Rust `word`).
    word: []const u8 = "",
    /// Returns supported-codepoint count for (id, word), or null for
    /// unknown/unloadable (skipped, like `get_font_supported_...` None).
    /// Null hook assumes full coverage.
    coverage_fn: ?*const fn (id: FontId, word: []const u8) ?usize = null,
    /// Returns false when `get_font(id, ideal_weight)` would return null.
    /// Null hook means all loadable.
    loadable_fn: ?*const fn (id: FontId) bool = null,
    mono_buffer: std.ArrayList(MonospaceFallbackInfo),
    seen: std.ArrayList(FontId),
    allocator: std.mem.Allocator,

    pub fn init(
        allocator: std.mem.Allocator,
        db: *const SimpleDb,
        font_match_keys: []const SimpleMatchKey,
        default_families: []const Family,
        scripts: []const Script,
        fallbacks: *const Fallbacks,
    ) FontFallbackIter {
        return .{
            .db = db,
            .font_match_keys = font_match_keys,
            .default_families = default_families,
            .scripts = scripts,
            .fallbacks = fallbacks,
            .mono_buffer = .empty,
            .seen = .empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *FontFallbackIter) void {
        self.mono_buffer.deinit(self.allocator);
        self.seen.deinit(self.allocator);
    }

    fn alreadyYielded(self: *const FontFallbackIter, id: FontId) bool {
        for (self.seen.items) |s| {
            if (s == id) return true;
        }
        return false;
    }

    fn markYielded(self: *FontFallbackIter, id: FontId) std.mem.Allocator.Error!void {
        if (!self.alreadyYielded(id)) {
            try self.seen.append(self.allocator, id);
        }
    }

    /// Null-skip: false when `get_font` would return null (Rust
    /// `if let Some(font) = get_font(...)`).
    fn isLoadable(self: *const FontFallbackIter, id: FontId) bool {
        if (self.loadable_fn) |f| return f(id);
        // Unknown ids are unloadable (mirrors `db.face(id)?` null-skip).
        if (self.db.face(id) == null) return false;
        return true;
    }

    fn weightDiffFor(self: *const FontFallbackIter, id: FontId) u16 {
        return absDiffU16(self.ideal_weight, self.db.weightOf(id));
    }

    fn variableMatchFor(self: *const FontFallbackIter, id: FontId) bool {
        const f = self.db.face(id) orelse return false;
        return simpleVariableMatch(self.ideal_weight, f.weight, f.variable_wght_min, f.variable_wght_max);
    }

    /// Non-mono weight gate (Rust `font_match_keys_iter(false)`):
    /// exact weight or variable-range cover passes.
    fn passesWeightFilter(self: *const FontFallbackIter, id: FontId) bool {
        if (self.weightDiffFor(id) == 0) return true;
        return self.variableMatchFor(id);
    }

    fn wordCharCount(self: *const FontFallbackIter) usize {
        var n: usize = 0;
        var i: usize = 0;
        while (i < self.word.len) {
            const first = self.word[i];
            const len: usize = if (first < 0x80) 1 else if (first >> 5 == 0b110) 2 else if (first >> 4 == 0b1110) 3 else if (first >> 3 == 0b11110) 4 else 1;
            if (i + len > self.word.len) {
                n += 1;
                break;
            }
            n += 1;
            i += len;
        }
        return n;
    }

    /// Supported-codepoint count for ranking (Rust
    /// `get_font_supported_codepoints_in_word`); null means skip (unknown
    /// font / load failure). Null hook assumes full coverage.
    fn supportedCount(self: *const FontFallbackIter, id: FontId) ?usize {
        if (!self.isLoadable(id)) return null;
        if (self.coverage_fn) |f| return f(id, self.word);
        return self.wordCharCount();
    }

    fn monoInfoFor(self: *const FontFallbackIter, id: FontId, is_default: bool) ?MonospaceFallbackInfo {
        const sup = self.supportedCount(id) orelse return null;
        const total = self.wordCharCount();
        const non_matches = if (total >= sup) total - sup else 0;
        const face_w = self.db.weightOf(id);
        return .{
            .font_weight_diff = if (is_default) null else @as(?u16, self.weightDiffFor(id)),
            .codepoint_non_matches = @as(?usize, non_matches),
            .font_weight = face_w,
            .id = id,
        };
    }

    fn popMonoBuffer(self: *FontFallbackIter) ?FontId {
        // Skip stale entries (already yielded or since-unloadable) like Rust's
        // `pop_first` + `get_font` null-skip.
        while (self.mono_buffer.items.len > 0) {
            var best: usize = 0;
            for (self.mono_buffer.items[1..], 1..) |item, i| {
                if (item.lessThan(self.mono_buffer.items[best])) best = i;
            }
            const info = self.mono_buffer.orderedRemove(best);
            if (self.alreadyYielded(info.id)) continue;
            if (!self.isLoadable(info.id)) continue;
            return info.id;
        }
        return null;
    }

    /// Filtered family lookup for default/script/common phases: weight-gated
    /// + loadable (Rust `font_match_keys_iter(false)` + `get_font` null-skip).
    fn findFamily(self: *FontFallbackIter, family_name: []const u8) ?FontId {
        for (self.font_match_keys) |k| {
            if (self.alreadyYielded(k.id)) continue;
            if (!self.passesWeightFilter(k.id)) continue;
            if (!self.isLoadable(k.id)) continue;
            if (self.db.faceContainsFamily(k.id, family_name)) return k.id;
        }
        return null;
    }

    pub fn next(self: *FontFallbackIter) std.mem.Allocator.Error!?FontId {
        // 1. Mono-buffer pop (skip ids already yielded via another phase).
        while (self.popMonoBuffer()) |id| {
            // popMonoBuffer already skips yielded/unloadable.
            try self.markYielded(id);
            return id;
        }

        // 2. Default families.
        while (self.default_i < self.default_families.len) {
            const family = self.default_families[self.default_i];
            self.default_i += 1;
            const is_mono = family == .monospace;
            if (is_mono) {
                // Monospace branch: buffer every monospaced candidate with
                // real weight-diff + coverage ranking (C5), then pop best.
                // Rust also prefers the default mono family with diff=None;
                // without a configured mono name we rank purely by the
                // buffered keys (weight diff, non-matches, weight, id).
                for (self.font_match_keys) |k| {
                    if (!self.db.isMonospace(k.id)) continue;
                    if (self.alreadyYielded(k.id)) continue;
                    if (self.monoInfoFor(k.id, false)) |info| {
                        try self.mono_buffer.append(self.allocator, info);
                    }
                }
                if (self.popMonoBuffer()) |id| {
                    try self.markYielded(id);
                    return id;
                }
                continue;
            }
            // Non-mono branch: first family-name hit wins; a miss ends the
            // default-family phase (mirrors `break 'DEF_FAM`).
            const name = familyName(family) orelse continue;
            if (self.findFamily(name)) |id| {
                try self.markYielded(id);
                return id;
            }
            break;
        }

        // 3. Script fallbacks.
        while (self.script_i[0] < self.scripts.len) {
            const families = self.fallbacks.scriptFallback(self.scripts[self.script_i[0]]);
            while (self.script_i[1] < families.len) {
                const name = families[self.script_i[1]];
                self.script_i[1] += 1;
                if (self.findFamily(name)) |id| {
                    try self.markYielded(id);
                    return id;
                }
            }
            self.script_i[0] += 1;
            self.script_i[1] = 0;
        }

        // 4. Common fallbacks.
        const common = self.fallbacks.commonFallback();
        while (self.common_i < common.len) {
            const name = common[self.common_i];
            self.common_i += 1;
            if (self.findFamily(name)) |id| {
                try self.markYielded(id);
                return id;
            }
        }

        // 5. Other: every remaining match key not forbidden and not seen.
        // No weight gate here (Rust iterates all keys); forbidden + null-skip only.
        const forbidden = self.fallbacks.forbiddenFallback();
        while (self.other_i < self.font_match_keys.len) {
            const id = self.font_match_keys[self.other_i].id;
            self.other_i += 1;
            if (self.alreadyYielded(id)) continue;
            if (!self.isLoadable(id)) continue;
            var skip = false;
            for (forbidden) |ban| {
                if (self.db.faceContainsFamily(id, ban)) {
                    skip = true;
                    break;
                }
            }
            if (!skip) {
                try self.markYielded(id);
                return id;
            }
        }

        // 6. End.
        self.end = true;
        return null;
    }
};

// ---------------------------------------------------------------------------
// Tests.
// ---------------------------------------------------------------------------

test "han unification routing" {
    const t = std.testing;
    try t.expectEqualStrings("Noto Sans CJK JP", hanUnification("ja")[0]);
    try t.expectEqualStrings("Noto Sans CJK KR", hanUnification("ko")[0]);
    try t.expectEqualStrings("Noto Sans CJK HK", hanUnification("zh-HK")[0]);
    try t.expectEqualStrings("Noto Sans CJK TC", hanUnification("zh-TW")[0]);
    try t.expectEqualStrings("Noto Sans CJK SC", hanUnification("en-US")[0]);
    try t.expectEqualStrings("Noto Sans CJK SC", hanUnification("zh-CN")[0]);
    // Hangul/hiragana/katakana ignore the request locale by design.
    try t.expectEqualStrings("Noto Sans CJK KR", scriptFallbackUnix(.hangul, "en-US")[0]);
    try t.expectEqualStrings("Noto Sans CJK JP", scriptFallbackUnix(.hiragana, "en-US")[0]);
    try t.expectEqualStrings("Noto Sans CJK JP", scriptFallbackUnix(.katakana, "ko")[0]);
    try t.expectEqualStrings("Noto Sans CJK SC", scriptFallbackUnix(.han, "en-US")[0]);
    try t.expectEqualStrings("Noto Sans CJK JP", scriptFallbackUnix(.han, "ja")[0]);
}

test "unix common list contents" {
    const t = std.testing;
    const fb = Fallback{ .platform_unix = .{} };
    const common = fb.commonFallback();
    try t.expectEqual(@as(usize, 9), common.len);
    try t.expectEqualStrings("Noto Sans", common[0]);
    try t.expectEqualStrings("Noto Color Emoji", common[common.len - 1]);
    try t.expectEqual(@as(usize, 0), fb.forbiddenFallback().len);
    try t.expectEqualStrings("Noto Sans Arabic", fb.scriptFallback(.arabic, "en-US")[0]);
    try t.expectEqual(@as(usize, 0), fb.scriptFallback(.unknown, "en-US").len);
    const empty = Fallback{ .empty = .{} };
    try t.expectEqual(@as(usize, 0), empty.commonFallback().len);
}

test "monospace fallback info orders none weight first" {
    const t = std.testing;
    var a = MonospaceFallbackInfo{
        .font_weight_diff = null,
        .codepoint_non_matches = @as(?usize, 5),
        .font_weight = 400,
        .id = 2,
    };
    var b = MonospaceFallbackInfo{
        .font_weight_diff = @as(?u16, 0),
        .codepoint_non_matches = @as(?usize, 0),
        .font_weight = 400,
        .id = 1,
    };
    try t.expect(a.lessThan(b));
    try t.expect(!b.lessThan(a));
    // Equal diffs fall through to weight then id.
    a = .{ .font_weight_diff = @as(?u16, 0), .codepoint_non_matches = @as(?usize, 0), .font_weight = 400, .id = 2 };
    b = .{ .font_weight_diff = @as(?u16, 0), .codepoint_non_matches = @as(?usize, 0), .font_weight = 700, .id = 1 };
    try t.expect(a.lessThan(b));
}

test "fallback order with mock db" {
    const t = std.testing;
    const alloc = t.allocator;
    const faces = [_]SimpleFace{
        .{ .id = 0, .families = &.{"TestSans"} },
        .{ .id = 1, .families = &.{"Noto Sans Arabic"} },
        .{ .id = 2, .families = &.{"Noto Sans"} },
        .{ .id = 3, .families = &.{"Other"} },
    };
    const db = SimpleDb{ .faces = &faces };
    const keys = [_]SimpleMatchKey{ .{ .id = 0 }, .{ .id = 1 }, .{ .id = 2 }, .{ .id = 3 } };
    const defaults = [_]Family{.{ .name = "TestSans" }};
    const scripts = [_]Script{.arabic};

    const fb = Fallback{ .platform_unix = .{} };
    var fallbacks = try Fallbacks.init(alloc, fb, &scripts, "en-US");
    defer fallbacks.deinit();

    var it = FontFallbackIter.init(alloc, &db, &keys, &defaults, &scripts, &fallbacks);
    defer it.deinit();

    // Default -> script -> common -> other.
    try t.expectEqual(@as(?FontId, 0), try it.next());
    try t.expectEqual(@as(?FontId, 1), try it.next());
    try t.expectEqual(@as(?FontId, 2), try it.next());
    try t.expectEqual(@as(?FontId, 3), try it.next());
    try t.expectEqual(@as(?FontId, null), try it.next());
    try t.expect(it.end);
}

test "forbidden families are skipped in other phase" {
    const t = std.testing;
    const alloc = t.allocator;
    const faces = [_]SimpleFace{
        .{ .id = 0, .families = &.{"Banned"} },
        .{ .id = 1, .families = &.{"Kept"} },
    };
    const db = SimpleDb{ .faces = &faces };
    const keys = [_]SimpleMatchKey{ .{ .id = 0 }, .{ .id = 1 } };
    const banned: []const []const u8 = &.{"Banned"};
    const fb = Fallback{ .custom = .{ .common = &.{}, .forbidden = banned } };
    var fallbacks = try Fallbacks.init(alloc, fb, &.{}, "en-US");
    defer fallbacks.deinit();
    const no_defaults: []const Family = &.{};
    const no_scripts: []const Script = &.{};
    var it = FontFallbackIter.init(alloc, &db, &keys, no_defaults, no_scripts, &fallbacks);
    defer it.deinit();
    try t.expectEqual(@as(?FontId, 1), try it.next());
    try t.expectEqual(@as(?FontId, null), try it.next());
}

const C5Coverage = struct {
    fn partial(id: FontId, word: []const u8) ?usize {
        _ = word;
        // id 10 covers all, id 11 covers all-but-one, id 99 unknown.
        if (id == 10) return 2;
        if (id == 11) return 1;
        return null;
    }
    fn isLoadable(id: FontId) bool {
        return id != 99;
    }
};

test "ideal weight filters to variable match (C5)" {
    const t = std.testing;
    const alloc = t.allocator;
    const faces = [_]SimpleFace{
        .{ .id = 0, .families = &.{"Var"}, .weight = 400 },
        .{ .id = 1, .families = &.{"Var"}, .weight = 400, .variable_wght_min = 100, .variable_wght_max = 900 },
    };
    const db = SimpleDb{ .faces = &faces };
    const keys = [_]SimpleMatchKey{ .{ .id = 0 }, .{ .id = 1 } };
    const defaults = [_]Family{.{ .name = "Var" }};
    const fb = Fallback{ .custom = .{} };
    var fallbacks = try Fallbacks.init(alloc, fb, &.{}, "en-US");
    defer fallbacks.deinit();
    const no_scripts: []const Script = &.{};

    // Ideal 600: both nominal diff 200, only the variable face passes.
    {
        var it = FontFallbackIter.init(alloc, &db, &keys, &defaults, no_scripts, &fallbacks);
        defer it.deinit();
        it.ideal_weight = 600;
        try t.expectEqual(@as(?FontId, 1), try it.next());
        // Other phase has no weight gate, so the skipped face appears last.
        try t.expectEqual(@as(?FontId, 0), try it.next());
        try t.expectEqual(@as(?FontId, null), try it.next());
    }
    // Ideal 400: both diff 0, order preserved.
    {
        var it = FontFallbackIter.init(alloc, &db, &keys, &defaults, no_scripts, &fallbacks);
        defer it.deinit();
        it.ideal_weight = 400;
        try t.expectEqual(@as(?FontId, 0), try it.next());
        try t.expectEqual(@as(?FontId, 1), try it.next());
    }
}

test "monospace ranks by coverage then weight, skips unloadable (C5)" {
    const t = std.testing;
    const alloc = t.allocator;
    const faces = [_]SimpleFace{
        .{ .id = 10, .families = &.{"MonoA"}, .monospaced = true, .weight = 400 },
        .{ .id = 11, .families = &.{"MonoB"}, .monospaced = true, .weight = 400 },
        .{ .id = 99, .families = &.{"MonoBad"}, .monospaced = true, .weight = 400 },
    };
    const db = SimpleDb{ .faces = &faces };
    const keys = [_]SimpleMatchKey{ .{ .id = 10 }, .{ .id = 11 }, .{ .id = 99 } };
    const defaults = [_]Family{.monospace};
    const fb = Fallback{ .custom = .{} };
    var fallbacks = try Fallbacks.init(alloc, fb, &.{}, "en-US");
    defer fallbacks.deinit();
    const no_scripts: []const Script = &.{};

    var it = FontFallbackIter.init(alloc, &db, &keys, &defaults, no_scripts, &fallbacks);
    defer it.deinit();
    it.ideal_weight = 400;
    it.word = "ab";
    it.coverage_fn = C5Coverage.partial;
    it.loadable_fn = C5Coverage.isLoadable;
    // Full coverage (non_matches 0) before partial (non_matches 1);
    // unloadable 99 never yields.
    try t.expectEqual(@as(?FontId, 10), try it.next());
    try t.expectEqual(@as(?FontId, 11), try it.next());
    try t.expectEqual(@as(?FontId, null), try it.next());
    try t.expect(it.end);
}
