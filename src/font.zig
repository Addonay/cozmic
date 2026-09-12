//! Port of cosmic-text `font/mod.rs` (font handle + metrics).
//!
//! Self-contained: defines local `Weight` / `Stretch` / `Style` / `Family`
//! aliases at the top instead of importing `attrs.zig` (not yet unified).
//! Unify these aliases with the attrs/font-system modules later; keep this
//! file compiling standalone until then.
//!
//! Backend note: cosmic-text parses fonts with skrifa/harfrust and exposes
//! swash access. This port sniffs core metrics with a pure-Zig sfnt header
//! parser (head/hhea/post/OS/2) so `Font` works without C dependencies.
//!
//! C-INTEROP WIRING POINT (clearly marked, the only intended stubs):
//! - FreeType: replace/extend `sniffMetrics` with `FT_New_Memory_Face` +
//!   `FT_Get_HoriHeader`-style ascent/descent/underline reads. The commented
//!   `cImport` below shows where `linkLibC`/`linkSystemLibrary("freetype2")`
//!   and `@cImport(@cInclude("ft2build.h"))` plug in (see
//!   `.reference/freetype-ref` for the wrap pattern).
//! - HarfBuzz: shaping goes through `harfrust::Shaper` in Rust; the Zig
//!   equivalent calls `hb_shape` on the owned `blob` at the shaping layer
//!   (see `.reference/harfbuzz-ref`), not here. `Font` keeps the owned bytes
//!   alive for that call.

const std = @import("std");

// ---------------------------------------------------------------------------
// Local attribute aliases (do NOT import attrs.zig yet; see header TODO).
// ---------------------------------------------------------------------------

/// Font weight value (matches `fontdb::Weight`, normal = 400).
pub const Weight = u16;
pub const WEIGHT_THIN: Weight = 100;
pub const WEIGHT_NORMAL: Weight = 400;
pub const WEIGHT_BOLD: Weight = 700;

/// Font stretch (matches `fontdb::Stretch` numbering 1..9).
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

/// Font style (matches `fontdb::Style`).
pub const Style = enum {
    normal,
    italic,
    oblique,
};

/// Font family selector (matches `fontdb::Family` variants).
pub const Family = union(enum) {
    name: []const u8,
    serif: void,
    sans_serif: void,
    cursive: void,
    fantasy: void,
    monospace: void,

    pub fn isMonospace(self: Family) bool {
        return self == .monospace;
    }
};

/// Font identifier (matches `fontdb::ID`, a `u32`).
pub const FontId = u32;

// ---------------------------------------------------------------------------
// C-interop wiring point.
// ---------------------------------------------------------------------------
//
// To wire FreeType, add to `build.zig`:
//     exe.linkLibC();
//     exe.linkSystemLibrary("freetype2");
// and uncomment:
//
// const ft = @cImport({
//     @cInclude("ft2build.h");
//     @cInclude("freetype/freetype.h");
// });
//
// Then extend `sniffMetrics` (or add `loadMetricsFreetype`) to call
// `ft.FT_New_Memory_Face` on `Font.blob` and read horizontal metrics.
// HarfBuzz shaping (`hb_shape`) likewise operates on `Font.blob` at the
// shaping layer; see `.reference/harfbuzz-ref`.

// ---------------------------------------------------------------------------
// Metrics + font handle.
// ---------------------------------------------------------------------------

/// Unscaled font metrics sniffed from the sfnt tables.
///
/// Units are font design units (divide by `units_per_em` for EM units).
/// Mirrors the subset of `skrifa::metrics::Metrics` cosmic-text uses
/// (upem/ascent/descent plus underline/strikeout).
pub const FontMetrics = struct {
    units_per_em: u16 = 1000,
    ascent: f32 = 800,
    descent: f32 = -200,
    underline_offset: f32 = -75,
    underline_thickness: f32 = 50,
    strikeout_offset: f32 = 250,
    strikeout_thickness: f32 = 50,
};

/// Placeholder for `swash::FontRef { data, offset, key }`.
///
/// The real swash path needs the font offset + cache key inside a TTC/OTC
/// collection. For now the offset is always 0 and the key is the font id;
/// the shaping/raster layer replaces this with real FreeType/swash calls.
/// This is an explicitly marked C-interop placeholder, not a silent stub:
/// callers get validly-typed but clearly-documented values.
pub const SwashRef = struct {
    offset: u32,
    key: u32,
};

/// A loaded font: owned bytes plus sniffed metrics.
///
/// Owns `blob`; free with `deinit`. `metrics` is a best-effort pure-Zig
/// parse (see `sniffMetrics`); failures fall back to defaults rather than
/// erroring so system-font scans never drop a file silently without reason
/// (callers can inspect `metrics_source` to tell).
pub const Font = struct {
    id: FontId,
    blob: []u8,
    font_metrics: FontMetrics,
    metrics_source: MetricsSource,
    mono_em_width: ?f32,
    italic_or_oblique: bool,
    allocator: std.mem.Allocator,

    pub const MetricsSource = enum {
        sniffed,
        defaults,
    };

    /// Load a font from borrowed bytes, duplicating them.
    /// `mono_em_width` is the precomputed `advance(' ') / upem` for
    /// monospaced faces (mirrors `Font::monospace_em_width`), or null.
    pub fn init(
        allocator: std.mem.Allocator,
        id: FontId,
        bytes: []const u8,
        italic_or_oblique: bool,
        mono_em_width: ?f32,
    ) std.mem.Allocator.Error!Font {
        const owned = try allocator.dupe(u8, bytes);
        const sniffed = sniffMetrics(owned);
        return .{
            .id = id,
            .blob = owned,
            .font_metrics = sniffed.metrics,
            .metrics_source = sniffed.source,
            .mono_em_width = mono_em_width,
            .italic_or_oblique = italic_or_oblique,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Font) void {
        self.allocator.free(self.blob);
        self.* = undefined;
    }

    pub fn fontId(self: *const Font) FontId {
        return self.id;
    }

    pub fn metrics(self: *const Font) *const FontMetrics {
        return &self.font_metrics;
    }

    pub fn data(self: *const Font) []const u8 {
        return self.blob;
    }

    pub fn monoEmWidth(self: *const Font) ?f32 {
        return self.mono_em_width;
    }

    pub fn isItalicOrOblique(self: *const Font) bool {
        return self.italic_or_oblique;
    }

    /// `asSwash` equivalent placeholder (see `SwashRef` docs).
    pub fn asSwash(self: *const Font) SwashRef {
        return .{ .offset = 0, .key = self.id };
    }
};

/// Sniff core metrics from sfnt tables with bounds checks only.
/// Never fails: returns defaults when tables are missing or truncated.
pub fn sniffMetrics(blob: []const u8) struct { metrics: FontMetrics, source: Font.MetricsSource } {
    var m = FontMetrics{};
    var found_any = false;

    const dir = parseTableDirectory(blob) orelse return .{ .metrics = m, .source = .defaults };

    if (findTable(blob, dir, "head")) |slice| {
        if (slice.len >= 20) {
            const upem = readU16BE(slice, 18);
            if (upem != 0) {
                m.units_per_em = upem;
                found_any = true;
            }
        }
    }
    if (findTable(blob, dir, "hhea")) |slice| {
        if (slice.len >= 8) {
            m.ascent = @floatFromInt(readI16BE(slice, 4));
            m.descent = @floatFromInt(readI16BE(slice, 6));
            found_any = true;
        }
    }
    if (findTable(blob, dir, "post")) |slice| {
        if (slice.len >= 12) {
            m.underline_offset = @floatFromInt(readI16BE(slice, 8));
            const thick = readI16BE(slice, 10);
            if (thick != 0) m.underline_thickness = @floatFromInt(thick);
            found_any = true;
        }
    }
    if (findTable(blob, dir, "OS/2")) |slice| {
        if (slice.len >= 30) {
            const size = readI16BE(slice, 26);
            const pos = readI16BE(slice, 28);
            if (size != 0) m.strikeout_thickness = @floatFromInt(size);
            // Rust/skrifa strikeout offset is measured from the baseline;
            // OS/2 yStrikeoutPosition is likewise baseline-relative.
            if (pos != 0) m.strikeout_offset = @floatFromInt(pos);
            found_any = true;
        }
    }

    // Rescale defaults if upem was sniffed but hhea/post were absent, so
    // EM-relative defaults stay proportional instead of 1000-upem based.
    if (found_any and findTable(blob, dir, "hhea") == null) {
        const upem: f32 = @floatFromInt(m.units_per_em);
        m.ascent = upem * 0.8;
        m.descent = upem * -0.2;
    }

    return .{ .metrics = m, .source = if (found_any) .sniffed else .defaults };
}

const TableDir = struct {
    num_tables: usize,
    records_offset: usize,
};

fn parseTableDirectory(blob: []const u8) ?TableDir {
    if (blob.len < 12) return null;
    const num_tables: usize = readU16BE(blob, 4);
    if (num_tables > 64) return null;
    if (blob.len < 12 + num_tables * 16) return null;
    return .{ .num_tables = num_tables, .records_offset = 12 };
}

fn findTable(blob: []const u8, dir: TableDir, tag: *const [4]u8) ?[]const u8 {
    var i: usize = 0;
    while (i < dir.num_tables) : (i += 1) {
        const base = dir.records_offset + i * 16;
        if (blob[base] == tag[0] and blob[base + 1] == tag[1] and blob[base + 2] == tag[2] and blob[base + 3] == tag[3]) {
            const offset: usize = readU32BE(blob, base + 8);
            const length: usize = readU32BE(blob, base + 12);
            if (offset > blob.len) return null;
            if (length > blob.len - offset) return null;
            return blob[offset .. offset + length];
        }
    }
    return null;
}

fn readU16BE(b: []const u8, at: usize) u16 {
    return (@as(u16, b[at]) << 8) | @as(u16, b[at + 1]);
}

fn readI16BE(b: []const u8, at: usize) i16 {
    return @bitCast(readU16BE(b, at));
}

fn readU32BE(b: []const u8, at: usize) u32 {
    return (@as(u32, b[at]) << 24) |
        (@as(u32, b[at + 1]) << 16) |
        (@as(u32, b[at + 2]) << 8) |
        @as(u32, b[at + 3]);
}

// ---------------------------------------------------------------------------
// Tests.
// ---------------------------------------------------------------------------

test "empty blob yields defaults" {
    const r = sniffMetrics(&.{});
    try std.testing.expect(r.source == .defaults);
    try std.testing.expectEqual(@as(u16, 1000), r.metrics.units_per_em);
}

test "truncated header yields defaults" {
    const r = sniffMetrics(&.{ 0, 1, 0, 0 });
    try std.testing.expect(r.source == .defaults);
}

test "sniff head and hhea tables" {
    // Minimal sfnt: numTables=2, head(upem=2048) + hhea(ascent=1536, descent=-512).
    var blob = std.ArrayList(u8).empty;
    defer blob.deinit(std.testing.allocator);
    // sfnt header: scaler 0x00010000, numTables 2, searchRange etc zero.
    try blob.appendSlice(std.testing.allocator, &.{ 0, 1, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0 });
    // head record: tag, checksum, offset=44, length=20.
    try blob.appendSlice(std.testing.allocator, &.{ 'h', 'e', 'a', 'd', 0, 0, 0, 0, 0, 0, 0, 44, 0, 0, 0, 20 });
    // hhea record: offset=64, length=8.
    try blob.appendSlice(std.testing.allocator, &.{ 'h', 'h', 'e', 'a', 0, 0, 0, 0, 0, 0, 0, 64, 0, 0, 0, 8 });
    // head data (20 bytes): unitsPerEm=2048 at byte 18.
    try blob.appendSlice(std.testing.allocator, &.{
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x08, 0x00,
    });
    // hhea data: version(4) + ascent 1536 (0x0600) + descent -512 (0xFE00).
    try blob.appendSlice(std.testing.allocator, &.{ 0, 1, 0, 0, 0x06, 0x00, 0xFE, 0x00 });

    const r = sniffMetrics(blob.items);
    try std.testing.expect(r.source == .sniffed);
    try std.testing.expectEqual(@as(u16, 2048), r.metrics.units_per_em);
    try std.testing.expectEqual(@as(f32, 1536), r.metrics.ascent);
    try std.testing.expectEqual(@as(f32, -512), r.metrics.descent);
}

test "font init owns blob and reports metrics" {
    var f = try Font.init(std.testing.allocator, 9, &.{ 0, 1, 2, 3 }, true, 0.6);
    defer f.deinit();
    try std.testing.expectEqual(@as(FontId, 9), f.fontId());
    try std.testing.expectEqual(@as(usize, 4), f.data().len);
    try std.testing.expect(f.isItalicOrOblique());
    try std.testing.expectEqual(@as(?f32, 0.6), f.monoEmWidth());
    // Short blob => defaults.
    try std.testing.expectEqual(@as(u16, 1000), f.metrics().units_per_em);
    const sw = f.asSwash();
    try std.testing.expectEqual(@as(u32, 0), sw.offset);
    try std.testing.expectEqual(@as(u32, 9), sw.key);
}

test "style and stretch aliases behave" {
    try std.testing.expectEqual(@as(u16, 5), Stretch.normal.toNumber());
    try std.testing.expect(Stretch.fromNumber(5) == .normal);
    try std.testing.expect(Stretch.fromNumber(99) == null);
    const fam: Family = .monospace;
    try std.testing.expect(fam.isMonospace());
}
