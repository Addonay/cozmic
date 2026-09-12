//! Real sfnt face-metadata parsing (fontdb `parse_face_info` parity).
//!
//! Port of fontdb 0.23's `parse_face_info` / `parse_names` / `parse_os2` /
//! `parse_post` (see `.reference/cosmic-text` + the fontdb crate) to pure Zig.
//! Unlike `font.zig`'s `sniffMetrics` (metrics only), this module extracts the
//! per-face identity data `FontDb` needs for matching:
//!
//! - `name` records: typographic family (ID 16) with fallback to family
//!   (ID 1), English-US first; PostScript name (ID 6).
//! - `OS/2`: weight class, width class, italic/oblique selection bits.
//! - `post`: isFixedPitch (monospaced) and italic angle.
//! - `fvar`: `wght` axis range for variable fonts (fills the M2 wiring point
//!   `FontDb.setVariableWghtRange`).
//!
//! Behavior mirrors fontdb rather than ttf-parser directly:
//! OS/2 missing => normal/400/normal (no `head.macStyle` fallback), weight 0
//! clamps to 400, post italic angle != 0 upgrades a normal style to italic,
//! MacRoman names are only consulted when no Unicode English-US family was
//! found. Collections (`ttcf`) are supported; every function is total over
//! arbitrary bytes (no unwrap/panic).

const std = @import("std");

pub const ParseError = error{ InvalidFont, OutOfMemory };

pub const FaceStyle = enum { normal, italic, oblique };

/// Owned per-face metadata. Free with `deinit`.
pub const FaceMeta = struct {
    allocator: std.mem.Allocator,
    families: [][]u8,
    post_script_name: []u8,
    weight: u16,
    /// fontdb `Stretch` numbering (1..9, normal = 5).
    stretch: u8,
    style: FaceStyle,
    monospaced: bool,
    variable_wght_min: ?u16 = null,
    variable_wght_max: ?u16 = null,

    pub fn deinit(self: *FaceMeta) void {
        freeFamilies(self.allocator, self.families);
        self.allocator.free(self.post_script_name);
        self.* = undefined;
    }
};

/// Number of faces in `blob`: 1 for a single sfnt, `numFonts` for a `ttcf`
/// (clamped to the number of offsets the header area can actually hold, so a
/// malformed count cannot drive an unbounded face loop).
pub fn fontsInCollection(blob: []const u8) u32 {
    if (blob.len >= 12 and std.mem.eql(u8, blob[0..4], "ttcf")) {
        const count = readU32BE(blob, 8);
        const max_by_len: usize = (blob.len - 12) / 4;
        return @intCast(@min(@as(usize, count), max_by_len));
    }
    return 1;
}

/// Parse face `index` of `blob` (fontdb `Database::load_font_source` calls
/// this once per face in the collection). Returns owned metadata.
pub fn parseFaceMeta(
    allocator: std.mem.Allocator,
    blob: []const u8,
    index: u32,
) ParseError!FaceMeta {
    const sfnt = sfntOffset(blob, index) orelse return error.InvalidFont;
    const dir = tableDirectory(blob, sfnt) orelse return error.InvalidFont;

    const names = try parseNames(allocator, blob, dir);
    errdefer {
        freeFamilies(allocator, names.families);
        allocator.free(names.post_script_name);
    }

    const os2 = parseOs2(blob, dir);
    const post = parsePost(blob, dir);
    const fvar = parseFvar(blob, dir);
    const style: FaceStyle = if (os2.style == .normal and post.italic) .italic else os2.style;

    return .{
        .allocator = allocator,
        .families = names.families,
        .post_script_name = names.post_script_name,
        .weight = os2.weight,
        .stretch = os2.stretch,
        .style = style,
        .monospaced = post.monospaced,
        .variable_wght_min = fvar.min,
        .variable_wght_max = fvar.max,
    };
}

// ---------------------------------------------------------------------------
// sfnt container + table directory.
// ---------------------------------------------------------------------------

const TableDir = struct {
    num_tables: usize,
    /// Absolute offset of the first 16-byte table record.
    records_offset: usize,
};

fn sfntOffset(blob: []const u8, index: u32) ?usize {
    if (blob.len >= 4 and std.mem.eql(u8, blob[0..4], "ttcf")) {
        if (blob.len < 12) return null;
        const count = readU32BE(blob, 8);
        if (index >= count) return null;
        const field = 12 + @as(usize, index) * 4;
        if (field + 4 > blob.len) return null;
        return readU32BE(blob, field);
    }
    if (index != 0) return null;
    return 0;
}

fn tableDirectory(blob: []const u8, sfnt: usize) ?TableDir {
    if (sfnt > blob.len or blob.len - sfnt < 12) return null;
    const version = readU32BE(blob, sfnt);
    switch (version) {
        0x00010000, 0x4F54544F, 0x74727565, 0x74797031 => {},
        else => return null,
    }
    const num: usize = readU16BE(blob, sfnt + 4);
    if (num > 512) return null;
    if (blob.len - sfnt < 12 + num * 16) return null;
    return .{ .num_tables = num, .records_offset = sfnt + 12 };
}

fn findTable(blob: []const u8, dir: TableDir, tag: *const [4]u8) ?[]const u8 {
    var i: usize = 0;
    while (i < dir.num_tables) : (i += 1) {
        const base = dir.records_offset + i * 16;
        if (!std.mem.eql(u8, blob[base .. base + 4], tag)) continue;
        // sfnt table offsets are relative to the start of the file (also for
        // `ttcf` collections), not to the face directory.
        const offset: usize = readU32BE(blob, base + 8);
        const length: usize = readU32BE(blob, base + 12);
        if (offset > blob.len or length > blob.len - offset) return null;
        return blob[offset .. offset + length];
    }
    return null;
}

// ---------------------------------------------------------------------------
// `name` table.
// ---------------------------------------------------------------------------

const NameTable = struct {
    count: usize,
    /// Absolute offset of the first 12-byte name record.
    records_offset: usize,
    /// Absolute offset of the string storage area.
    strings_offset: usize,
};

fn parseNameTable(blob: []const u8, table: []const u8) ?NameTable {
    if (table.len < 6) return null;
    const format = readU16BE(table, 0);
    if (format != 0 and format != 1) return null;
    const count: usize = readU16BE(table, 2);
    const string_offset: usize = readU16BE(table, 4);
    if (table.len - 6 < count * 12) return null;
    if (string_offset + 6 > table.len) return null;
    const base = @intFromPtr(table.ptr) - @intFromPtr(blob.ptr);
    return .{
        .count = count,
        .records_offset = base + 6,
        .strings_offset = base + string_offset,
    };
}

fn nameData(blob: []const u8, names: NameTable, record: usize) ?[]const u8 {
    const length: usize = readU16BE(blob, record + 8);
    const offset: usize = readU16BE(blob, record + 10);
    const start = names.strings_offset + offset;
    if (start > blob.len or length > blob.len - start) return null;
    return blob[start .. start + length];
}

/// ttf-parser `Name::is_unicode`: platform 0 (Unicode) or Windows with a
/// Symbol/BMP encoding.
fn isUnicodeEncoding(platform: u16, encoding: u16) bool {
    if (platform == 0) return true;
    if (platform == 3) return encoding == 0 or encoding == 1;
    return false;
}

fn isMacRoman(platform: u16, encoding: u16) bool {
    return platform == 1 and encoding == 0;
}

/// ttf-parser maps MacRoman language 0 to English US.
fn isMacRomanEnglish(platform: u16, encoding: u16, language: u16) bool {
    return isMacRoman(platform, encoding) and language == 0;
}

fn isEnglishUs(platform: u16, language: u16) bool {
    return platform == 3 and language == 0x0409;
}

const FamilyEntry = struct {
    name: []u8,
    is_en_us: bool,
};

const Names = struct {
    families: [][]u8,
    post_script_name: []u8,
};

fn parseNames(allocator: std.mem.Allocator, blob: []const u8, dir: TableDir) ParseError!Names {
    const table = findTable(blob, dir, "name") orelse return error.InvalidFont;
    const names = parseNameTable(blob, table) orelse return error.InvalidFont;

    var families = try collectFamilies(allocator, blob, names, 16);
    if (families.len == 0) {
        freeFamilies(allocator, families);
        families = try collectFamilies(allocator, blob, names, 1);
    }
    errdefer freeFamilies(allocator, families);
    if (families.len == 0) return error.InvalidFont;

    const post_script_name = try postScriptName(allocator, blob, names);
    return .{ .families = families, .post_script_name = post_script_name };
}

/// fontdb `collect_families`: Unicode names first, English-US moved to the
/// front; MacRoman only when no Unicode English-US name exists.
fn collectFamilies(
    allocator: std.mem.Allocator,
    blob: []const u8,
    names: NameTable,
    wanted_id: u16,
) ParseError![][]u8 {
    var entries: std.ArrayList(FamilyEntry) = .empty;
    defer entries.deinit(allocator);
    errdefer for (entries.items) |e| allocator.free(e.name);

    var i: usize = 0;
    while (i < names.count) : (i += 1) {
        const record = names.records_offset + i * 12;
        if (readU16BE(blob, record + 6) != wanted_id) continue;
        const platform = readU16BE(blob, record);
        const encoding = readU16BE(blob, record + 2);
        const language = readU16BE(blob, record + 4);
        if (!isUnicodeEncoding(platform, encoding)) continue;
        const data = nameData(blob, names, record) orelse continue;
        const decoded = decodeUtf16Be(allocator, data) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.InvalidEncoding => continue,
        };
        try entries.append(allocator, .{
            .name = decoded,
            .is_en_us = isEnglishUs(platform, language),
        });
    }

    if (!hasEnglishUs(entries.items)) {
        i = 0;
        while (i < names.count) : (i += 1) {
            const record = names.records_offset + i * 12;
            if (readU16BE(blob, record + 6) != wanted_id) continue;
            const platform = readU16BE(blob, record);
            const encoding = readU16BE(blob, record + 2);
            const language = readU16BE(blob, record + 4);
            if (!isMacRoman(platform, encoding)) continue;
            const data = nameData(blob, names, record) orelse continue;
            const decoded = try decodeMacRoman(allocator, data);
            try entries.append(allocator, .{
                .name = decoded,
                .is_en_us = isMacRomanEnglish(platform, encoding, language),
            });
            break;
        }
    }

    // Make English US the first entry (fontdb `parse_names`).
    if (entries.items.len > 1) {
        for (entries.items, 0..) |entry, index| {
            if (entry.is_en_us and index != 0) {
                std.mem.swap(FamilyEntry, &entries.items[0], &entries.items[index]);
                break;
            }
        }
    }

    const out = try allocator.alloc([]u8, entries.items.len);
    for (entries.items, 0..) |entry, index| out[index] = entry.name;
    return out;
}

fn hasEnglishUs(entries: []const FamilyEntry) bool {
    for (entries) |entry| {
        if (entry.is_en_us) return true;
    }
    return false;
}

fn postScriptName(
    allocator: std.mem.Allocator,
    blob: []const u8,
    names: NameTable,
) ParseError![]u8 {
    var i: usize = 0;
    while (i < names.count) : (i += 1) {
        const record = names.records_offset + i * 12;
        if (readU16BE(blob, record + 6) != 6) continue;
        const platform = readU16BE(blob, record);
        const encoding = readU16BE(blob, record + 2);
        const unicode = isUnicodeEncoding(platform, encoding);
        if (!unicode and !isMacRoman(platform, encoding)) continue;
        const data = nameData(blob, names, record) orelse return error.InvalidFont;
        if (unicode) {
            return decodeUtf16Be(allocator, data) catch |err| switch (err) {
                error.OutOfMemory => error.OutOfMemory,
                error.InvalidEncoding => error.InvalidFont,
            };
        }
        return decodeMacRoman(allocator, data);
    }
    return error.InvalidFont;
}

fn decodeUtf16Be(allocator: std.mem.Allocator, data: []const u8) error{ OutOfMemory, InvalidEncoding }![]u8 {
    if (data.len % 2 != 0) return error.InvalidEncoding;
    const units = try allocator.alloc(u16, data.len / 2);
    defer allocator.free(units);
    for (units, 0..) |*unit, i| {
        unit.* = (@as(u16, data[i * 2]) << 8) | data[i * 2 + 1];
    }
    return std.unicode.utf16LeToUtf8Alloc(allocator, units) catch |err| switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => error.InvalidEncoding,
    };
}

fn decodeMacRoman(allocator: std.mem.Allocator, data: []const u8) error{OutOfMemory}![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try out.ensureTotalCapacity(allocator, data.len);
    for (data) |byte| {
        const codepoint: u21 = if (byte < 0x80) byte else mac_roman_high[byte - 0x80];
        var buf: [4]u8 = undefined;
        const len = std.unicode.utf8Encode(codepoint, &buf) catch unreachable;
        try out.appendSlice(allocator, buf[0..len]);
    }
    return out.toOwnedSlice(allocator);
}

/// Mac OS Roman 0x80..0xFF -> Unicode (fontdb `MAC_ROMAN`).
const mac_roman_high = [128]u21{
    0x00C4, 0x00C5, 0x00C7, 0x00C9, 0x00D1, 0x00D6, 0x00DC, 0x00E1,
    0x00E0, 0x00E2, 0x00E4, 0x00E3, 0x00E5, 0x00E7, 0x00E9, 0x00E8,
    0x00EA, 0x00EB, 0x00ED, 0x00EC, 0x00EE, 0x00EF, 0x00F1, 0x00F3,
    0x00F2, 0x00F4, 0x00F6, 0x00F5, 0x00FA, 0x00F9, 0x00FB, 0x00FC,
    0x2020, 0x00B0, 0x00A2, 0x00A3, 0x00A7, 0x2022, 0x00B6, 0x00DF,
    0x00AE, 0x00A9, 0x2122, 0x00B4, 0x00A8, 0x2260, 0x00C6, 0x00D8,
    0x221E, 0x00B1, 0x2264, 0x2265, 0x00A5, 0x00B5, 0x2202, 0x2211,
    0x220F, 0x03C0, 0x222B, 0x00AA, 0x00BA, 0x03A9, 0x00E6, 0x00F8,
    0x00BF, 0x00A1, 0x00AC, 0x221A, 0x0192, 0x2248, 0x2206, 0x00AB,
    0x00BB, 0x2026, 0x00A0, 0x00C0, 0x00C3, 0x00D5, 0x0152, 0x0153,
    0x2013, 0x2014, 0x201C, 0x201D, 0x2018, 0x2019, 0x00F7, 0x25CA,
    0x00FF, 0x0178, 0x2044, 0x20AC, 0x2039, 0x203A, 0xFB01, 0xFB02,
    0x2021, 0x00B7, 0x201A, 0x201E, 0x2030, 0x00C2, 0x00CA, 0x00C1,
    0x00CB, 0x00C8, 0x00CD, 0x00CE, 0x00CF, 0x00CC, 0x00D3, 0x00D4,
    0xF8FF, 0x00D2, 0x00DA, 0x00DB, 0x00D9, 0x0131, 0x02C6, 0x02DC,
    0x00AF, 0x02D8, 0x02D9, 0x02DA, 0x00B8, 0x02DD, 0x02DB, 0x02C7,
};

// ---------------------------------------------------------------------------
// `OS/2`, `post`, `fvar`.
// ---------------------------------------------------------------------------

const Os2 = struct {
    style: FaceStyle = .normal,
    weight: u16 = 400,
    stretch: u8 = 5,
};

fn parseOs2(blob: []const u8, dir: TableDir) Os2 {
    const table = findTable(blob, dir, "OS/2") orelse return .{};
    if (table.len < 64) return .{};
    const version = readU16BE(table, 0);
    const weight_raw = readU16BE(table, 4);
    const width_raw = readU16BE(table, 6);
    const selection = readU16BE(table, 62);

    var style: FaceStyle = .normal;
    if (selection & 0x0001 != 0) {
        style = .italic;
    } else if (version >= 4 and selection & 0x0200 != 0) {
        style = .oblique;
    }
    return .{
        .style = style,
        .weight = if (weight_raw == 0) 400 else weight_raw,
        .stretch = if (width_raw >= 1 and width_raw <= 9) @intCast(width_raw) else 5,
    };
}

const Post = struct {
    monospaced: bool = false,
    italic: bool = false,
};

fn parsePost(blob: []const u8, dir: TableDir) Post {
    const table = findTable(blob, dir, "post") orelse return .{};
    if (table.len < 16) return .{};
    return .{
        .monospaced = readU32BE(table, 12) != 0,
        .italic = readU32BE(table, 4) != 0,
    };
}

const VarRange = struct {
    min: ?u16 = null,
    max: ?u16 = null,
};

fn parseFvar(blob: []const u8, dir: TableDir) VarRange {
    const table = findTable(blob, dir, "fvar") orelse return .{};
    if (table.len < 16) return .{};
    const axes_offset: usize = readU16BE(table, 4);
    const axis_count: usize = readU16BE(table, 8);
    const axis_size: usize = readU16BE(table, 10);
    if (axis_size < 20) return .{};

    var i: usize = 0;
    while (i < axis_count) : (i += 1) {
        const base = axes_offset + i * axis_size;
        if (base > table.len or axis_size > table.len - base) return .{};
        if (!std.mem.eql(u8, table[base .. base + 4], "wght")) continue;
        return .{
            .min = fixedToWeight(readU32BE(table, base + 4)),
            .max = fixedToWeight(readU32BE(table, base + 12)),
        };
    }
    return .{};
}

fn fixedToWeight(raw: u32) u16 {
    const signed: i32 = @bitCast(raw);
    const value = @as(f32, @floatFromInt(signed)) / 65536.0;
    const rounded = std.math.round(value);
    return @intFromFloat(std.math.clamp(rounded, 0.0, 65535.0));
}

// ---------------------------------------------------------------------------
// Byte readers.
// ---------------------------------------------------------------------------

fn readU16BE(b: []const u8, at: usize) u16 {
    return (@as(u16, b[at]) << 8) | @as(u16, b[at + 1]);
}

fn readU32BE(b: []const u8, at: usize) u32 {
    return (@as(u32, b[at]) << 24) |
        (@as(u32, b[at + 1]) << 16) |
        (@as(u32, b[at + 2]) << 8) |
        @as(u32, b[at + 3]);
}

fn freeFamilies(allocator: std.mem.Allocator, families: [][]u8) void {
    for (families) |family| allocator.free(family);
    if (families.len != 0) allocator.free(families);
}

// ---------------------------------------------------------------------------
// Tests (synthetic sfnt blobs; layout mirrors the real spec).
// ---------------------------------------------------------------------------

const testing = std.testing;

const Table = struct { tag: *const [4]u8, data: []const u8 };

fn align4(n: usize) usize {
    return (n + 3) & ~@as(usize, 3);
}

fn buildSfnt(allocator: std.mem.Allocator, tables: []const Table) ![]u8 {
    var total: usize = 12 + tables.len * 16;
    for (tables) |table| total += align4(table.data.len);
    const buf = try allocator.alloc(u8, total);
    errdefer allocator.free(buf);
    @memset(buf, 0);
    writeU32BE(buf, 0, 0x00010000);
    writeU16BE(buf, 4, @intCast(tables.len));
    var offset: usize = 12 + tables.len * 16;
    for (tables, 0..) |table, i| {
        const record = 12 + i * 16;
        @memcpy(buf[record .. record + 4], table.tag);
        writeU32BE(buf, record + 8, @intCast(offset));
        writeU32BE(buf, record + 12, @intCast(table.data.len));
        @memcpy(buf[offset .. offset + table.data.len], table.data);
        offset += align4(table.data.len);
    }
    return buf;
}

fn buildTtc(allocator: std.mem.Allocator, faces: []const []const u8) ![]u8 {
    var buf: std.ArrayList(u8) = .empty;
    errdefer buf.deinit(allocator);
    try buf.appendSlice(allocator, "ttcf");
    try appendU32BE(&buf, allocator, 0x00010000);
    try appendU32BE(&buf, allocator, @intCast(faces.len));
    var offset: u32 = @intCast(12 + faces.len * 4);
    for (faces) |face| {
        try appendU32BE(&buf, allocator, offset);
        offset += @intCast(face.len);
    }
    for (faces) |face| try buf.appendSlice(allocator, face);

    // In a real collection, table record offsets are relative to the file
    // start; `buildSfnt` wrote them relative to the face start, so relocate.
    var face_start: usize = 12 + faces.len * 4;
    for (faces) |face| {
        const count: usize = readU16BE(buf.items, face_start + 4);
        var i: usize = 0;
        while (i < count) : (i += 1) {
            const record = face_start + 12 + i * 16;
            const rel = readU32BE(buf.items, record + 8);
            writeU32BE(buf.items, record + 8, @intCast(face_start + rel));
        }
        face_start += face.len;
    }
    return buf.toOwnedSlice(allocator);
}

const NameRec = struct {
    platform: u16 = 3,
    encoding: u16 = 1,
    language: u16 = 0x0409,
    id: u16,
    data: []const u8,
};

fn buildNameTable(allocator: std.mem.Allocator, recs: []const NameRec) ![]u8 {
    var strings: std.ArrayList(u8) = .empty;
    defer strings.deinit(allocator);
    var records: std.ArrayList(u8) = .empty;
    defer records.deinit(allocator);
    for (recs) |rec| {
        try appendU16BE(&records, allocator, rec.platform);
        try appendU16BE(&records, allocator, rec.encoding);
        try appendU16BE(&records, allocator, rec.language);
        try appendU16BE(&records, allocator, rec.id);
        try appendU16BE(&records, allocator, @intCast(rec.data.len));
        try appendU16BE(&records, allocator, @intCast(strings.items.len));
        try strings.appendSlice(allocator, rec.data);
    }
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try appendU16BE(&out, allocator, 0);
    try appendU16BE(&out, allocator, @intCast(recs.len));
    try appendU16BE(&out, allocator, @intCast(6 + records.items.len));
    try out.appendSlice(allocator, records.items);
    try out.appendSlice(allocator, strings.items);
    return out.toOwnedSlice(allocator);
}

fn utf16be(allocator: std.mem.Allocator, ascii: []const u8) ![]u8 {
    const out = try allocator.alloc(u8, ascii.len * 2);
    for (ascii, 0..) |c, i| {
        out[i * 2] = 0;
        out[i * 2 + 1] = c;
    }
    return out;
}

fn buildOs2(version: u16, weight: u16, width: u16, selection: u16) [64]u8 {
    var out: [64]u8 = @splat(0);
    writeU16BE(&out, 0, version);
    writeU16BE(&out, 4, weight);
    writeU16BE(&out, 6, width);
    writeU16BE(&out, 62, selection);
    return out;
}

fn buildFvar(axis_tag: *const [4]u8, min: i32, default: i32, max: i32) [36]u8 {
    var out: [36]u8 = @splat(0);
    writeU32BE(&out, 0, 0x00010000);
    writeU16BE(&out, 4, 16); // axesArrayOffset
    writeU16BE(&out, 6, 2); // countSizePairs
    writeU16BE(&out, 8, 1); // axisCount
    writeU16BE(&out, 10, 20); // axisSize
    @memcpy(out[16..20], axis_tag);
    writeU32BE(&out, 20, @bitCast(min));
    writeU32BE(&out, 24, @bitCast(default));
    writeU32BE(&out, 28, @bitCast(max));
    return out;
}

fn buildSfntWith(
    allocator: std.mem.Allocator,
    family: []const u8,
    post_script: []const u8,
    os2: ?[64]u8,
    post_table: ?[16]u8,
    fvar: ?[36]u8,
) ![]u8 {
    const family_utf16 = try utf16be(allocator, family);
    defer allocator.free(family_utf16);
    const post_utf16 = try utf16be(allocator, post_script);
    defer allocator.free(post_utf16);
    const name_table = try buildNameTable(allocator, &.{
        .{ .id = 1, .data = family_utf16 },
        .{ .id = 6, .data = post_utf16 },
    });
    defer allocator.free(name_table);

    // Keep optional tables at function scope: `buildSfnt` copies the bytes
    // only when it is called, after the table list is assembled.
    var os2_buf: [64]u8 = undefined;
    var post_buf: [16]u8 = undefined;
    var fvar_buf: [36]u8 = undefined;

    var tables: std.ArrayList(Table) = .empty;
    defer tables.deinit(allocator);
    try tables.append(allocator, .{ .tag = "name", .data = name_table });
    if (os2) |data| {
        os2_buf = data;
        try tables.append(allocator, .{ .tag = "OS/2", .data = &os2_buf });
    }
    if (post_table) |data| {
        post_buf = data;
        try tables.append(allocator, .{ .tag = "post", .data = &post_buf });
    }
    if (fvar) |data| {
        fvar_buf = data;
        try tables.append(allocator, .{ .tag = "fvar", .data = &fvar_buf });
    }
    return buildSfnt(allocator, tables.items);
}

test "single sfnt parses OS/2 weight, width and post mono" {
    const allocator = testing.allocator;
    var post_bytes: [16]u8 = @splat(0);
    writeU32BE(&post_bytes, 12, 1); // isFixedPitch
    const blob = try buildSfntWith(allocator, "Test Family", "TestFamily-Bold", buildOs2(4, 700, 3, 0), post_bytes, null);
    defer allocator.free(blob);

    var meta = try parseFaceMeta(allocator, blob, 0);
    defer meta.deinit();
    try testing.expectEqualStrings("Test Family", meta.families[0]);
    try testing.expectEqualStrings("TestFamily-Bold", meta.post_script_name);
    try testing.expectEqual(@as(u16, 700), meta.weight);
    try testing.expectEqual(@as(u8, 3), meta.stretch);
    try testing.expect(meta.style == .normal);
    try testing.expect(meta.monospaced);
    try testing.expectEqual(@as(?u16, null), meta.variable_wght_min);
}

test "typographic family wins and English-US moves first" {
    const allocator = testing.allocator;
    const typo_jp = try utf16be(allocator, "Typo JP");
    defer allocator.free(typo_jp);
    const typo_us = try utf16be(allocator, "Typo US");
    defer allocator.free(typo_us);
    const legacy = try utf16be(allocator, "Legacy");
    defer allocator.free(legacy);
    const ps = try utf16be(allocator, "PostScript");
    defer allocator.free(ps);
    const name_table = try buildNameTable(allocator, &.{
        .{ .id = 1, .data = legacy },
        .{ .id = 16, .language = 0x0411, .data = typo_jp },
        .{ .id = 16, .data = typo_us },
        .{ .id = 6, .data = ps },
    });
    defer allocator.free(name_table);
    const blob = try buildSfnt(allocator, &.{.{ .tag = "name", .data = name_table }});
    defer allocator.free(blob);

    var meta = try parseFaceMeta(allocator, blob, 0);
    defer meta.deinit();
    try testing.expectEqual(@as(usize, 2), meta.families.len);
    try testing.expectEqualStrings("Typo US", meta.families[0]);
    try testing.expectEqualStrings("Typo JP", meta.families[1]);
}

test "legacy family used when no typographic family" {
    const allocator = testing.allocator;
    const legacy = try utf16be(allocator, "Legacy Family");
    defer allocator.free(legacy);
    const ps = try utf16be(allocator, "LegacyPS");
    defer allocator.free(ps);
    const name_table = try buildNameTable(allocator, &.{
        .{ .id = 1, .data = legacy },
        .{ .id = 6, .data = ps },
    });
    defer allocator.free(name_table);
    const blob = try buildSfnt(allocator, &.{.{ .tag = "name", .data = name_table }});
    defer allocator.free(blob);

    var meta = try parseFaceMeta(allocator, blob, 0);
    defer meta.deinit();
    try testing.expectEqualStrings("Legacy Family", meta.families[0]);
}

test "MacRoman family fallback decodes" {
    const allocator = testing.allocator;
    // MacRoman 0xE9 is U+00C8 (È); é is 0x8E. The table follows the canonical
    // mapping, so test both directions explicitly.
    const mac_name = [_]u8{ 'C', 'a', 'f', 0x8E }; // Cafe + acute e
    const ps = try utf16be(allocator, "CafePS");
    defer allocator.free(ps);
    const name_table = try buildNameTable(allocator, &.{
        .{ .platform = 1, .encoding = 0, .language = 0, .id = 1, .data = &mac_name },
        .{ .id = 6, .data = ps },
    });
    defer allocator.free(name_table);
    const blob = try buildSfnt(allocator, &.{.{ .tag = "name", .data = name_table }});
    defer allocator.free(blob);

    var meta = try parseFaceMeta(allocator, blob, 0);
    defer meta.deinit();
    try testing.expectEqualStrings("Caf\xC3\xA9", meta.families[0]);

    const mac_grave = [_]u8{ 'C', 'a', 'f', 0xE9 }; // 0xE9 = U+00C8 (È)
    const name_table2 = try buildNameTable(allocator, &.{
        .{ .platform = 1, .encoding = 0, .language = 0, .id = 1, .data = &mac_grave },
        .{ .id = 6, .data = ps },
    });
    defer allocator.free(name_table2);
    const blob2 = try buildSfnt(allocator, &.{.{ .tag = "name", .data = name_table2 }});
    defer allocator.free(blob2);
    var meta2 = try parseFaceMeta(allocator, blob2, 0);
    defer meta2.deinit();
    try testing.expectEqualStrings("Caf\xC3\x88", meta2.families[0]);
}

test "post italic angle upgrades normal style, oblique needs OS/2 v4" {
    const allocator = testing.allocator;
    var italic_post: [16]u8 = @splat(0);
    writeU32BE(&italic_post, 4, 0xFFFF0000); // italic angle -1.0
    const blob = try buildSfntWith(allocator, "Italic Face", "ItalicFace", buildOs2(0, 400, 5, 0), italic_post, null);
    defer allocator.free(blob);
    var meta = try parseFaceMeta(allocator, blob, 0);
    defer meta.deinit();
    try testing.expect(meta.style == .italic);

    const blob_v4 = try buildSfntWith(allocator, "Oblique Face", "ObliqueFace", buildOs2(4, 400, 5, 0x0200), null, null);
    defer allocator.free(blob_v4);
    var meta_v4 = try parseFaceMeta(allocator, blob_v4, 0);
    defer meta_v4.deinit();
    try testing.expect(meta_v4.style == .oblique);

    const blob_v0 = try buildSfntWith(allocator, "Plain Face", "PlainFace", buildOs2(0, 400, 5, 0x0200), null, null);
    defer allocator.free(blob_v0);
    var meta_v0 = try parseFaceMeta(allocator, blob_v0, 0);
    defer meta_v0.deinit();
    try testing.expect(meta_v0.style == .normal);
}

test "fvar wght range fills variable metadata" {
    const allocator = testing.allocator;
    const fvar = buildFvar("wght", 100 << 16, 400 << 16, 900 << 16);
    const blob = try buildSfntWith(allocator, "Variable", "VarFace", null, null, fvar);
    defer allocator.free(blob);
    var meta = try parseFaceMeta(allocator, blob, 0);
    defer meta.deinit();
    try testing.expectEqual(@as(?u16, 100), meta.variable_wght_min);
    try testing.expectEqual(@as(?u16, 900), meta.variable_wght_max);
}

test "collection parses per-face metadata" {
    const allocator = testing.allocator;
    const face_a = try buildSfntWith(allocator, "Face A", "FaceA", buildOs2(4, 400, 5, 0), null, null);
    defer allocator.free(face_a);
    const face_b = try buildSfntWith(allocator, "Face B", "FaceB", buildOs2(4, 700, 5, 0), null, null);
    defer allocator.free(face_b);
    const ttc = try buildTtc(allocator, &.{ face_a, face_b });
    defer allocator.free(ttc);

    try testing.expectEqual(@as(u32, 2), fontsInCollection(ttc));
    var meta_a = try parseFaceMeta(allocator, ttc, 0);
    defer meta_a.deinit();
    var meta_b = try parseFaceMeta(allocator, ttc, 1);
    defer meta_b.deinit();
    try testing.expectEqualStrings("Face A", meta_a.families[0]);
    try testing.expectEqualStrings("Face B", meta_b.families[0]);
    try testing.expectEqual(@as(u16, 700), meta_b.weight);

    // Malformed `numFonts` cannot drive an unbounded face loop: the count is
    // clamped to the offsets the header area can hold.
    try testing.expectEqual(@as(u32, 0), fontsInCollection("ttcf\x00\x01\x00\x00\xff\xff\xff\xff"));
    // Too short to be a collection header: treated as a single face.
    try testing.expectEqual(@as(u32, 1), fontsInCollection("ttcf"));
}

test "malformed blobs return InvalidFont, never panic" {
    const allocator = testing.allocator;
    try testing.expectError(error.InvalidFont, parseFaceMeta(allocator, &.{}, 0));
    try testing.expectError(error.InvalidFont, parseFaceMeta(allocator, &.{ 0, 1, 0, 0, 0, 0 }, 0));
    try testing.expectError(error.InvalidFont, parseFaceMeta(allocator, "ttcf", 0));
    try testing.expectError(error.InvalidFont, parseFaceMeta(allocator, "ttcf\x00\x00\x00\x01\x00\x00\x00\x05\x00\x00\x00\x14", 0));
    // sfnt header with a name table tag but no records.
    var truncated: [28]u8 = @splat(0);
    writeU32BE(&truncated, 0, 0x00010000);
    writeU16BE(&truncated, 4, 1);
    @memcpy(truncated[12..16], "name");
    writeU32BE(&truncated, 20, 28);
    writeU32BE(&truncated, 24, 8);
    try testing.expectError(error.InvalidFont, parseFaceMeta(allocator, &truncated, 0));
}

// ---------------------------------------------------------------------------
// Test byte writers (mirror the readers).
// ---------------------------------------------------------------------------

fn writeU16BE(b: []u8, at: usize, v: u16) void {
    b[at] = @intCast(v >> 8);
    b[at + 1] = @intCast(v & 0xFF);
}

fn writeU32BE(b: []u8, at: usize, v: u32) void {
    b[at] = @intCast(v >> 24);
    b[at + 1] = @intCast((v >> 16) & 0xFF);
    b[at + 2] = @intCast((v >> 8) & 0xFF);
    b[at + 3] = @intCast(v & 0xFF);
}

fn appendU16BE(list: *std.ArrayList(u8), allocator: std.mem.Allocator, v: u16) !void {
    try list.append(allocator, @intCast(v >> 8));
    try list.append(allocator, @intCast(v & 0xFF));
}

fn appendU32BE(list: *std.ArrayList(u8), allocator: std.mem.Allocator, v: u32) !void {
    try list.append(allocator, @intCast(v >> 24));
    try list.append(allocator, @intCast((v >> 16) & 0xFF));
    try list.append(allocator, @intCast((v >> 8) & 0xFF));
    try list.append(allocator, @intCast(v & 0xFF));
}
