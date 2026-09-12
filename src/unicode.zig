//! UAX adapter for cozmic.
//!
//! OWNERSHIP: this file (`src/unicode.zig`) is the only file that imports
//! `ezi_unicode`; do not move its declarations or the dependency into other
//! files.
//!
//! SOURCE OF TRUTH: the pinned `ezi_code` package (see `build.zig.zon` and
//! `tools/pin.env` `EZI_CODE_REV`), imported through its `unicode` module as
//! `ezi_unicode`. Every UCD table/algorithm is delegated:
//! - UAX#24 scripts: `ezi.scripts.scriptType`
//! - UAX#29 graphemes/words: `ezi.segmentation.{graphemeBreakProperty,
//!   checkBoundary, wordBreakProperty, wordIterator, inCB}` +
//!   `ezi.emoji.isExtendedPictographic`
//! - UAX#14 line breaking: `ezi.segmentation.{lineBreak, lineBreakIterator}`
//! - UAX#9 BiDi: `ezi.properties.bidiClass`, `ezi.bidi.{paragraphLevel,
//!   resolveParagraph, Paragraph.lineLevels, reorderVisual, mirror}`
//! - properties/whitespace: `ezi.properties.*`
//!
//! PUBLIC API: every previously exported declaration keeps its name and
//! signature. Additive-only changes: `BidiClass` gained the `es`/`et`
//! variants (European Separator/Terminator, which the old shard folded into
//! `.on`), the shard predicates/enums that used to be private are `pub`
//! (`lineBreakClass`, `wordBreakProperty`, `isSpacingMark`, `isPrepend`,
//! `inCB`, `isExtendedPictographic`, `LineClass`, `WordProp`, `InCB`), and
//! `isAlphabetic`/`isNumeric` expose the two halves of Unicode's
//! alphanumeric test. `isWordRange` keeps its signature but now applies the
//! exact `unicode-segmentation` `is_alphanumeric` filter (previously any
//! non-whitespace, non-hard-separator segment counted, so punctuation-only
//! runs were treated as words).
//!
//! API NOTES:
//! - Iterators are allocation-free and borrow the input (returned
//!   slices/offsets stay valid only while the input lives).
//! - Fallible helpers take an explicit allocator and return
//!   `error.OutOfMemory` (never panic, never truncate).
//! - Invalid UTF-8 decodes lossily as U+FFFD (cozmic's decoder for the
//!   grapheme/UTF-8 cursor helpers; ezi's byte iterators for word/line
//!   segmentation), so no input is rejected.
//! - BiDi levels are per-*byte* (every byte of a codepoint shares its level),
//!   as before; `baseLevels` applies UAX#9 L1 for the whole slice it is given.
//!
//! CONVENTIONS: Zig 0.17, explicit allocators, no panics (`unreachable`,
//! `catch unreachable`, `std.debug.assert` are absent; `@intCast` is used
//! only where the value was range-checked into `u21`/byte bounds first).

const std = @import("std");
const ezi = @import("ezi_unicode");

const Allocator = std.mem.Allocator;

pub const CodePoint: type = u21;

/// Replacement character used for lossy decoding.
pub const REPLACEMENT: CodePoint = 0xFFFD;

/// Bidi embedding level: even = LTR, odd = RTL (matches `shape.zig:Level`).
pub const Level: type = u8;
pub const LEVEL_LTR: Level = 0;
pub const LEVEL_RTL: Level = 1;

pub fn levelIsRtl(level: Level) bool {
    return level % 2 == 1;
}

pub const UnicodeError = Allocator.Error;

// ---------------------------------------------------------------------------
// UTF-8 helpers (lossy; mirrors shape/buffer/edit decodeOne)
// ---------------------------------------------------------------------------

const Decoded = struct {
    cp: CodePoint,
    len: usize,
};

fn utf8CharLen(first: u8) usize {
    if (first < 0x80) return 1;
    if (first >> 5 == 0b110) return 2;
    if (first >> 4 == 0b1110) return 3;
    if (first >> 3 == 0b11110) return 4;
    return 1;
}

fn decodeOne(text: []const u8, i: usize) Decoded {
    if (i >= text.len) return .{ .cp = REPLACEMENT, .len = 1 };
    const first = text[i];
    const len = utf8CharLen(first);
    if (len == 1) {
        if (first < 0x80) return .{ .cp = first, .len = 1 };
        return .{ .cp = REPLACEMENT, .len = 1 };
    }
    if (i + len > text.len) return .{ .cp = REPLACEMENT, .len = 1 };
    var cp: u21 = switch (len) {
        2 => @as(u21, first & 0x1F),
        3 => @as(u21, first & 0x0F),
        else => @as(u21, first & 0x07),
    };
    var j: usize = 1;
    while (j < len) : (j += 1) {
        const b = text[i + j];
        if (b >> 6 != 0b10) return .{ .cp = REPLACEMENT, .len = 1 };
        cp = (cp << 6) | @as(u21, b & 0x3F);
    }
    const min: u21 = switch (len) {
        2 => 0x80,
        3 => 0x800,
        else => 0x10000,
    };
    if (cp < min or (cp >= 0xD800 and cp <= 0xDFFF) or cp > 0x10FFFF) {
        return .{ .cp = REPLACEMENT, .len = 1 };
    }
    return .{ .cp = cp, .len = len };
}

pub fn isContinuation(b: u8) bool {
    return (b & 0xC0) == 0x80;
}

/// Byte index is a UTF-8 boundary (mirrors buffer/edit `isBoundary`).
pub fn isBoundary(text: []const u8, index: usize) bool {
    if (index == 0 or index == text.len) return true;
    if (index > text.len) return false;
    return !isContinuation(text[index]);
}

pub const Codepoint = struct {
    value: CodePoint,
    len: usize,
};

/// Allocation-free codepoint cursor (same shape as
/// `buffer.zig:CodepointIterator` / `edit.zig:CodepointIterator`).
pub const CodepointIterator = struct {
    slice: []const u8,
    pos: usize = 0,

    pub fn next(self: *CodepointIterator) ?Codepoint {
        if (self.pos >= self.slice.len) return null;
        const d = decodeOne(self.slice, self.pos);
        self.pos += d.len;
        return .{ .value = d.cp, .len = d.len };
    }
};

pub fn codepointIterator(slice: []const u8) CodepointIterator {
    return .{ .slice = slice };
}

/// Decode the whole string into caller-owned codepoints (lossy).
/// Caller owns the slice; freed with `alloc.free`.
pub fn decodeCodepoints(alloc: Allocator, text: []const u8) UnicodeError![]CodePoint {
    var out: std.ArrayList(CodePoint) = .empty;
    errdefer out.deinit(alloc);
    var i: usize = 0;
    while (i < text.len) {
        const d = decodeOne(text, i);
        try out.append(alloc, d.cp);
        i += d.len;
    }
    return out.toOwnedSlice(alloc);
}

// ---------------------------------------------------------------------------
// White_Space (PropList oracle: ezi-code `properties.isWhitespace`)
// ---------------------------------------------------------------------------

/// Full Unicode `White_Space` property (ezi PropList tables).
pub fn isWhitespace(cp: CodePoint) bool {
    return ezi.properties.isWhitespace(cp);
}

/// ASCII-only whitespace (for callers that must not treat NBSP as blank).
pub fn isAsciiWhitespace(cp: CodePoint) bool {
    return switch (cp) {
        0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x20 => true,
        else => false,
    };
}

// ---------------------------------------------------------------------------
// Scripts (UAX#24 oracle: ezi-code `scripts.scriptType`)
// ---------------------------------------------------------------------------

/// UAX#24 script values relevant to cozmic shaping/font fallback.
/// Superset of `shape.zig:Script` (which stops at devanagari/thai and folds
/// Bengali/Tamil/Khmer/etc into `unknown`/`other`); variant names for the
/// shared scripts are spelled identically so `collectScripts` filtering
/// (`Common|Inherited|Latin|Unknown` skipped) ports verbatim. Any assigned
/// script outside this list maps to `.other`.
pub const Script = enum {
    common,
    inherited,
    latin,
    greek,
    cyrillic,
    armenian,
    hebrew,
    arabic,
    devanagari,
    bengali,
    tamil,
    telugu,
    kannada,
    malayalam,
    thai,
    lao,
    tibetan,
    myanmar,
    khmer,
    han,
    hiragana,
    katakana,
    hangul,
    unknown,
    other,
};

fn mapScriptType(s: ezi.scripts.ScriptType) Script {
    return switch (s) {
        .common => .common,
        .inherited => .inherited,
        .latin => .latin,
        .greek => .greek,
        .cyrillic => .cyrillic,
        .armenian => .armenian,
        .hebrew => .hebrew,
        .arabic => .arabic,
        .devanagari => .devanagari,
        .bengali => .bengali,
        .tamil => .tamil,
        .telugu => .telugu,
        .kannada => .kannada,
        .malayalam => .malayalam,
        .thai => .thai,
        .lao => .lao,
        .tibetan => .tibetan,
        .myanmar => .myanmar,
        .khmer => .khmer,
        .han => .han,
        .hiragana => .hiragana,
        .katakana => .katakana,
        .hangul => .hangul,
        .unknown => .unknown,
        else => .other,
    };
}

/// UAX#24 `Script(cp)` (ezi's 2-level page table over Scripts.txt).
/// Unassigned/out-of-range codepoints yield `.unknown`; assigned scripts that
/// cozmic does not track yield `.other` (so fallback still triggers).
pub fn scriptOf(cp: CodePoint) Script {
    return mapScriptType(ezi.scripts.scriptType(cp));
}

/// Collect distinct non-trivial scripts in a byte range.
/// Same skip set as `shape.zig:collectScripts` (shape.rs:313-322:
/// `Common | Inherited | Latin | Unknown` are skipped); allocator-explicit.
pub fn collectScripts(
    out: *std.ArrayList(Script),
    alloc: Allocator,
    text: []const u8,
    start: usize,
    end: usize,
) UnicodeError!void {
    const hi = @min(end, text.len);
    var i = @min(start, hi);
    while (i < hi) {
        const d = decodeOne(text, i);
        switch (scriptOf(d.cp)) {
            .common, .inherited, .latin, .unknown => {},
            else => |s| {
                var found = false;
                for (out.items) |have| {
                    if (have == s) {
                        found = true;
                        break;
                    }
                }
                if (!found) try out.append(alloc, s);
            },
        }
        i += d.len;
    }
}

// ---------------------------------------------------------------------------
// Grapheme properties (UAX#29 oracle: ezi-code `segmentation.*`)
// ---------------------------------------------------------------------------

/// Cursor state for the incremental UAX#29 grapheme algorithm (ezi
/// `BoundaryState`; same field names/semantics as the old local shard state).
pub const GraphemeState = ezi.segmentation.BoundaryState;

/// True for UAX#29 `Extend` (GB9), i.e. Grapheme_Cluster_Break=Extend.
/// Note this includes emoji modifiers (U+1F3FB..U+1F3FF), which are GB9
/// Extend but not DerivedCoreProperties Grapheme_Extend.
pub fn isGraphemeExtend(cp: CodePoint) bool {
    return ezi.segmentation.graphemeBreakProperty(cp) == .extend;
}

/// True for UAX#29 `SpacingMark` (GB9a).
pub fn isSpacingMark(cp: CodePoint) bool {
    return ezi.segmentation.graphemeBreakProperty(cp) == .spacing_mark;
}

/// True for UAX#29 `Prepend` (GB9b).
pub fn isPrepend(cp: CodePoint) bool {
    return ezi.segmentation.graphemeBreakProperty(cp) == .prepend;
}

/// Indic Conjunct Break (GB9c), from ezi DerivedCoreProperties.
pub const InCB = ezi.segmentation.InCB;

/// `InCB(cp)` used by UAX#29 GB9c.
pub fn inCB(cp: CodePoint) InCB {
    return ezi.segmentation.inCB(cp);
}

/// UTS#51 `Extended_Pictographic` (UAX#29 GB11). Oracle: ezi emoji tables.
pub fn isExtendedPictographic(cp: CodePoint) bool {
    return ezi.emoji.isExtendedPictographic(cp);
}

/// Allocation-free grapheme-cluster cursor over UTF-8 bytes.
/// Same shape as `shape.zig:GraphemeCursor` (`text/pos/end`, `next() ?usize`
/// yielding the *start* of the next cluster). Clusters are
/// `[prev_start, next_start)`; the final cluster ends at `end`.
/// `pos` after `next()` is the cluster's end (consumers rely on that).
pub const GraphemeIndices = struct {
    text: []const u8,
    pos: usize,
    end: usize,
    state: GraphemeState = .{},

    pub fn next(self: *GraphemeIndices) ?usize {
        if (self.pos >= self.end) return null;
        const start = self.pos;
        var consumed_first = false;
        while (self.pos < self.end) {
            const d = decodeOne(self.text, self.pos);
            const decision = ezi.segmentation.checkBoundary(self.state, d.cp);
            if (decision.should_break and consumed_first) break;
            self.state = decision.new_state;
            self.pos += d.len;
            consumed_first = true;
        }
        return start;
    }

    /// Start offsets as an owned slice (includes no sentinel; add `end`
    /// separately). Caller owns; freed with `alloc.free`.
    pub fn collectStarts(self: *GraphemeIndices, alloc: Allocator) UnicodeError![]usize {
        var out: std.ArrayList(usize) = .empty;
        errdefer out.deinit(alloc);
        while (self.next()) |s| try out.append(alloc, s);
        return out.toOwnedSlice(alloc);
    }
};

/// Iterate grapheme-cluster starts in `text` (UAX#29).
pub fn graphemeIndices(text: []const u8) GraphemeIndices {
    return .{ .text = text, .pos = 0, .end = text.len };
}

/// Byte offset is a grapheme boundary (sot/eot always true).
pub fn isGraphemeBoundary(text: []const u8, index: usize) bool {
    if (index == 0 or index == text.len) return true;
    if (!isBoundary(text, index)) return false;
    var it = graphemeIndices(text);
    while (it.next()) |s| {
        if (s == index) return true;
        if (s > index) return false;
    }
    return false;
}

/// Count grapheme clusters (allocation-free).
pub fn countGraphemes(text: []const u8) usize {
    var it = graphemeIndices(text);
    var n: usize = 0;
    while (it.next() != null) n += 1;
    return n;
}

/// Previous grapheme-cluster start at or before `index` (codepoint-correct
/// Backspace/Delete primitive for buffer/edit; mirrors their `prevCharStart`
/// but cluster-aware).
pub fn prevGraphemeStart(text: []const u8, index: usize) usize {
    const clamped = @min(index, text.len);
    var last: usize = 0;
    var it = graphemeIndices(text);
    while (it.next()) |s| {
        if (s >= clamped) break;
        last = s;
    }
    return last;
}

/// Next grapheme-cluster end at or after `index`.
pub fn nextGraphemeEnd(text: []const u8, index: usize) usize {
    const clamped = @min(index, text.len);
    var it = graphemeIndices(text);
    while (it.next()) |s| {
        if (s > clamped) return s;
    }
    return text.len;
}

// ---------------------------------------------------------------------------
// Words (UAX#29 oracle: ezi-code `segmentation.wordIterator`)
// ---------------------------------------------------------------------------

/// UAX#29 `Word_Break` property (ezi generated table).
pub const WordProp = ezi.segmentation.WordBreakProperty;

/// `Word_Break(cp)`.
pub fn wordBreakProperty(cp: CodePoint) WordProp {
    return ezi.segmentation.wordBreakProperty(cp);
}

/// Byte range of one UAX#29 word segment.
pub const WordRange = struct {
    start: usize,
    end: usize,
};

/// Allocation-free UAX#29 word cursor.
/// Yields every segment (words *and* separators, like ezi-code `WordIterator`;
/// callers that want words only skip ranges that `isWordRange` rejects). Same
/// byte-range shape as `shape.zig:WordSplit` without the blank flag.
pub const WordBounds = struct {
    text: []const u8,
    /// End of the most recently yielded segment (= start of the next).
    pos: usize = 0,
    it: ezi.segmentation.WordIterator,

    pub fn next(self: *WordBounds) ?WordRange {
        if (self.pos >= self.text.len) return null;
        const start = self.pos;
        const segment = self.it.next() orelse return null;
        self.pos = start + segment.len;
        return .{ .start = start, .end = self.pos };
    }

    pub fn reset(self: *WordBounds) void {
        self.pos = 0;
        self.it.reset();
    }
};

/// Iterate UAX#29 word segments in `text`.
pub fn wordBounds(text: []const u8) WordBounds {
    return .{ .text = text, .it = ezi.segmentation.wordIterator(text) };
}

/// True for the Unicode `Alphabetic` derived property (UCD
/// DerivedCoreProperties). This is one half of the `unicode-segmentation`
/// `is_alphanumeric` predicate that backs `unicode_word_indices`.
pub fn isAlphabetic(cp: CodePoint) bool {
    return ezi.properties.isAlphabetic(cp);
}

/// True for `General_Category = N*` (`Nd`/`Nl`/`No`). This is the other half
/// of the `unicode-segmentation` `is_alphanumeric` predicate.
pub fn isNumeric(cp: CodePoint) bool {
    return ezi.properties.isNumeric(cp);
}

/// True when the range contains something worth treating as a word: at least
/// one codepoint with the `Alphabetic` property or `General_Category=N*`.
///
/// This is exactly the filter behind `unicode-segmentation`'s
/// `unicode_word_indices` (`split_word_bound_indices().filter(|(_, s)|
/// s.chars().any(is_alphanumeric))`), which cosmic-text uses for both word
/// motion (`cursor_motion`) and word selection (`Selection::Word`). So
/// whitespace, punctuation-only, symbol-only and emoji-only segments are not
/// words, and `_` alone is not a word either (`ExtendNumLet` is not
/// alphanumeric); apostrophes and mid-numerals stay inside a word via
/// WB6/WB7/WB11/WB12, and CJK/kana characters are words one segment at a time.
pub fn isWordRange(text: []const u8, r: WordRange) bool {
    var i = r.start;
    while (i < r.end) {
        const d = decodeOne(text, i);
        if (isAlphabetic(d.cp) or isNumeric(d.cp)) return true;
        i += d.len;
    }
    return false;
}

// ---------------------------------------------------------------------------
// Line breaking (UAX#14 oracle: ezi-code `segmentation.lineBreakIterator`)
// ---------------------------------------------------------------------------

/// UAX#14 `Line_Break` property (ezi generated table).
pub const LineClass = ezi.segmentation.LineBreak;

/// `Line_Break(cp)`.
pub fn lineBreakClass(cp: CodePoint) LineClass {
    return ezi.segmentation.lineBreak(cp);
}

/// UAX#14 break kind (ezi `LineBreakKind`).
pub const LineBreakKind = ezi.segmentation.LineBreakKind;

pub const BreakOpportunity = struct {
    /// Byte offset *before which* the break sits (like UAX#14 positions).
    offset: usize,
    kind: LineBreakKind,
};

/// Allocation-free UAX#14 cursor over UTF-8 bytes.
/// Yields break opportunities as `{offset, kind}` with `offset` the byte index
/// *before which* the break sits. sot (0) is never yielded (LB2); eot
/// (`text.len` as `.mandatory`) is yielded last when text is non-empty.
/// Mandatory breaks after BK/CR/LF/NL surface as `.mandatory`.
pub const LineBreakOpportunities = struct {
    text: []const u8,
    /// End of the most recently yielded segment (= the next break offset).
    pos: usize = 0,
    it: ezi.segmentation.LineBreakIterator,

    pub fn next(self: *LineBreakOpportunities) ?BreakOpportunity {
        if (self.pos >= self.text.len) return null;
        const start = self.pos;
        const segment = self.it.next() orelse return null;
        self.pos = start + segment.slice.len;
        return .{ .offset = self.pos, .kind = segment.kind };
    }

    pub fn reset(self: *LineBreakOpportunities) void {
        self.pos = 0;
        self.it.reset();
    }
};

/// Iterate UAX#14 break opportunities in `text`.
pub fn lineBreakOpportunities(text: []const u8) LineBreakOpportunities {
    return .{ .text = text, .it = ezi.segmentation.lineBreakIterator(text) };
}

/// Collect break offsets (opportunity + mandatory) into an owned slice.
/// Includes the trailing `text.len` sentinel when text is non-empty.
pub fn collectLineBreaks(alloc: Allocator, text: []const u8) UnicodeError![]usize {
    var out: std.ArrayList(usize) = .empty;
    errdefer out.deinit(alloc);
    var it = lineBreakOpportunities(text);
    while (it.next()) |b| try out.append(alloc, b.offset);
    return out.toOwnedSlice(alloc);
}

// ---------------------------------------------------------------------------
// Bidi (UAX#9 oracle: ezi-code `bidi/algorithm.zig`)
// ---------------------------------------------------------------------------

/// Bidi_Class (UCD DerivedBidiClass). `.es`/`.et` are an additive extension:
/// the old shard folded European Separator/Terminator into `.on`.
pub const BidiClass = enum {
    l,
    r,
    al,
    en,
    an,
    nsm,
    bn,
    b,
    s,
    ws,
    on,
    /// Common separator (U+002C, U+003A, U+00A0, ...; W6 resolves it).
    cs,
    /// European separator (U+002B, U+002D, ...).
    es,
    /// European terminator (U+0023, U+0024, U+0025, ...).
    et,
    lre,
    rle,
    lro,
    rlo,
    pdf,
    lri,
    rli,
    fsi,
    pdi,
};

fn mapBidiClass(c: ezi.properties.BidiClass) BidiClass {
    return switch (c) {
        .left_to_right => .l,
        .right_to_left => .r,
        .arabic_letter => .al,
        .european_number => .en,
        .european_separator => .es,
        .european_terminator => .et,
        .arabic_number => .an,
        .common_separator => .cs,
        .non_spacing_mark => .nsm,
        .boundary_neutral => .bn,
        .paragraph_separator => .b,
        .segment_separator => .s,
        .whitespace => .ws,
        .other_neutral => .on,
        .left_to_right_embedding => .lre,
        .left_to_right_override => .lro,
        .right_to_left_embedding => .rle,
        .right_to_left_override => .rlo,
        .pop_directional_format => .pdf,
        .left_to_right_isolate => .lri,
        .right_to_left_isolate => .rli,
        .first_strong_isolate => .fsi,
        .pop_directional_isolate => .pdi,
    };
}

/// `Bidi_Class(cp)` (full UCD table).
pub fn bidiClass(cp: CodePoint) BidiClass {
    return mapBidiClass(ezi.properties.bidiClass(cp));
}

/// Base paragraph direction (mirrors ezi-code `BaseDirection`).
pub const BaseDirection = enum {
    ltr,
    rtl,
    auto,
};

fn toEziBase(base: BaseDirection) ezi.bidi.BaseDirection {
    return switch (base) {
        .ltr => .ltr,
        .rtl => .rtl,
        .auto => .auto,
    };
}

/// Paragraph embedding level P2/P3 over codepoints (ezi
/// `bidi.paragraphLevel`, isolate-aware first-strong scan).
pub fn paragraphLevelForCodepoints(cps: []const CodePoint, base: BaseDirection) Level {
    return ezi.bidi.paragraphLevel(cps, toEziBase(base));
}

/// Streaming P2/P3 over UTF-8 text; allocation-free and isolate-aware.
/// Mirrors ezi's codepoint scan, decoding with cozmic's lossy decoder so
/// malformed UTF-8 behaves exactly like the rest of this file.
pub fn paragraphLevel(text: []const u8, base: BaseDirection) Level {
    switch (base) {
        .ltr => return LEVEL_LTR,
        .rtl => return LEVEL_RTL,
        .auto => {},
    }
    var i: usize = 0;
    while (i < text.len) {
        const d = decodeOne(text, i);
        i += d.len;
        const c = ezi.properties.bidiClass(d.cp);
        if (ezi.bidi.isIsolateInitiator(c)) {
            var depth: usize = 1;
            while (i < text.len and depth > 0) {
                const dd = decodeOne(text, i);
                i += dd.len;
                const cc = ezi.properties.bidiClass(dd.cp);
                if (ezi.bidi.isIsolateInitiator(cc)) {
                    depth += 1;
                } else if (cc == .pop_directional_isolate) {
                    depth -= 1;
                }
            }
            continue;
        }
        switch (c) {
            .right_to_left, .arabic_letter => return LEVEL_RTL,
            .left_to_right => return LEVEL_LTR,
            else => {},
        }
    }
    return LEVEL_LTR;
}

/// One paragraph slice with its embedding level (UAX#9 P1-P3).
pub const BidiParagraph = struct {
    start: usize,
    end: usize,
    level: Level,
};

/// Allocation-free paragraph cursor splitting on `B` (paragraph separators:
/// LF/CR/NEL/PS; CRLF is one separator). Each item carries its own base level
/// under `base` (with `.auto` running first-strong per paragraph).
pub const BidiParagraphs = struct {
    text: []const u8,
    pos: usize = 0,
    base: BaseDirection = .auto,

    pub fn next(self: *BidiParagraphs) ?BidiParagraph {
        if (self.pos > self.text.len) return null;
        if (self.pos == self.text.len) return null;
        const start = self.pos;
        var i = start;
        while (i < self.text.len) {
            const d = decodeOne(self.text, i);
            if (d.cp == 0x000D and i + d.len < self.text.len) {
                const d2 = decodeOne(self.text, i + d.len);
                if (d2.cp == 0x000A) {
                    i += d.len + d2.len;
                    break;
                }
            }
            if (ezi.properties.bidiClass(d.cp) == .paragraph_separator) {
                i += d.len;
                break;
            }
            i += d.len;
        }
        const end = i;
        self.pos = end;
        const level = paragraphLevel(self.text[start..end], self.base);
        return .{ .start = start, .end = end, .level = level };
    }

    pub fn reset(self: *BidiParagraphs) void {
        self.pos = 0;
    }
};

/// Iterate UAX#9 paragraphs in `text` under `base`.
pub fn bidiParagraphs(text: []const u8, base: BaseDirection) BidiParagraphs {
    return .{ .text = text, .base = base };
}

/// Resolve embedding levels for one paragraph's bytes (UAX#9 P-X/I/L1 via ezi
/// `bidi.resolveParagraph` + `Paragraph.lineLevels`). Returns per-*byte*
/// levels (like `shape.zig:computeLevels`: every byte of a codepoint shares
/// its level). Caller owns; freed with `alloc.free`. Errors only on OOM.
pub fn baseLevels(alloc: Allocator, text: []const u8, base: BaseDirection) UnicodeError![]Level {
    const levels = try alloc.alloc(Level, text.len);
    errdefer alloc.free(levels);
    if (text.len == 0) return levels;

    // Decode once so ezi can resolve over codepoints; remember byte spans to
    // expand the per-codepoint levels back to per-byte levels.
    var cps: std.ArrayList(CodePoint) = .empty;
    defer cps.deinit(alloc);
    var starts: std.ArrayList(usize) = .empty;
    defer starts.deinit(alloc);
    var lens: std.ArrayList(usize) = .empty;
    defer lens.deinit(alloc);
    var i: usize = 0;
    while (i < text.len) {
        const d = decodeOne(text, i);
        try cps.append(alloc, d.cp);
        try starts.append(alloc, i);
        try lens.append(alloc, d.len);
        i += d.len;
    }

    var para = try ezi.bidi.resolveParagraph(alloc, cps.items, toEziBase(base));
    defer para.deinit();
    // L1 (trailing whitespace/separators reset) + BN level propagation.
    const line = try para.lineLevels(alloc, 0, cps.items.len);
    defer alloc.free(line);

    for (starts.items, lens.items, line) |st, ln, lv| {
        var o: usize = 0;
        while (o < ln and st + o < levels.len) : (o += 1) levels[st + o] = lv;
    }
    return levels;
}

/// UAX#9 L2 visual reorder: permutation of `0..levels.len` in display order.
/// Oracle: ezi-code `bidi.reorderVisual`. Caller owns; freed with
/// `alloc.free`.
pub fn reorderVisual(alloc: Allocator, levels: []const Level) UnicodeError![]usize {
    return ezi.bidi.reorderVisual(alloc, levels);
}

/// Mirror a codepoint at a resolved level (UAX#9 L4).
/// Oracle: ezi-code `bidi.mirror` (full BidiMirroring table).
pub fn mirrorCodepoint(cp: CodePoint, level: Level) CodePoint {
    return ezi.bidi.mirror(cp, level);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "whitespace: full White_Space set incl NBSP vs ASCII" {
    const ws = [_]CodePoint{
        0x09,   0x0A,   0x0B,   0x0C,   0x0D,   0x20,   0x85,   0xA0,   0x1680,
        0x2000, 0x2001, 0x2002, 0x2003, 0x2004, 0x2005, 0x2006, 0x2007, 0x2008,
        0x2009, 0x200A, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000,
    };
    for (ws) |cp| try std.testing.expect(isWhitespace(cp));
    // NBSP is whitespace (glue in line breaking, but White_Space true).
    try std.testing.expect(isWhitespace(0xA0));
    try std.testing.expect(isWhitespace(' '));
    // Non-members adjacent to the set.
    try std.testing.expect(!isWhitespace('A'));
    try std.testing.expect(!isWhitespace('0'));
    try std.testing.expect(!isWhitespace(0x200B)); // ZWSP is not White_Space
    try std.testing.expect(!isWhitespace(0x0084));
    try std.testing.expect(!isWhitespace(0x00A1));
}

test "script: coverage beyond Han (Bengali/Tamil/Khmer + core)" {
    try std.testing.expectEqual(Script.latin, scriptOf('A'));
    try std.testing.expectEqual(Script.common, scriptOf(' '));
    try std.testing.expectEqual(Script.common, scriptOf('0'));
    try std.testing.expectEqual(Script.greek, scriptOf(0x03B1));
    try std.testing.expectEqual(Script.cyrillic, scriptOf(0x0410));
    try std.testing.expectEqual(Script.armenian, scriptOf(0x0531));
    try std.testing.expectEqual(Script.hebrew, scriptOf(0x05D0));
    try std.testing.expectEqual(Script.arabic, scriptOf(0x0627));
    try std.testing.expectEqual(Script.devanagari, scriptOf(0x0928));
    // Previously missing in shape.zig:352-373.
    try std.testing.expectEqual(Script.bengali, scriptOf(0x0995)); // BENGALI KA
    try std.testing.expectEqual(Script.tamil, scriptOf(0x0B95)); // TAMIL KA
    try std.testing.expectEqual(Script.khmer, scriptOf(0x1780)); // KHMER KA
    try std.testing.expectEqual(Script.telugu, scriptOf(0x0C15));
    try std.testing.expectEqual(Script.thai, scriptOf(0x0E01));
    try std.testing.expectEqual(Script.myanmar, scriptOf(0x1000));
    try std.testing.expectEqual(Script.han, scriptOf(0x4E00));
    try std.testing.expectEqual(Script.hiragana, scriptOf(0x3041));
    try std.testing.expectEqual(Script.katakana, scriptOf(0x30AB));
    try std.testing.expectEqual(Script.hangul, scriptOf(0xAC00));
    try std.testing.expectEqual(Script.inherited, scriptOf(0x0301));
    try std.testing.expectEqual(Script.inherited, scriptOf(0x200D));
    try std.testing.expectEqual(Script.unknown, scriptOf(0x0378));
    // collectScripts skips Common/Inherited/Latin/Unknown (shape.rs:313-322).
    {
        var list: std.ArrayList(Script) = .empty;
        defer list.deinit(std.testing.allocator);
        // "Hi" latin skipped, combining acute inherited skipped, Han kept.
        try collectScripts(&list, std.testing.allocator, "Hi\xcc\x81\xe4\xb8\xad", 0, 6);
        try std.testing.expectEqual(@as(usize, 1), list.items.len);
        try std.testing.expectEqual(Script.han, list.items[0]);
    }
    {
        var list: std.ArrayList(Script) = .empty;
        defer list.deinit(std.testing.allocator);
        // Bengali + Tamil both surface (deduped).
        try collectScripts(&list, std.testing.allocator, "\xe0\xa6\x95\xe0\xae\x95", 0, 6);
        try std.testing.expectEqual(@as(usize, 2), list.items.len);
    }
}

test "grapheme: ZWJ and combining clusters (UAX#29 GB9/GB11)" {
    // a + combining acute is one cluster (GB9).
    {
        const text = "a\xcc\x81";
        try std.testing.expectEqual(@as(usize, 1), countGraphemes(text));
        var it = graphemeIndices(text);
        try std.testing.expectEqual(@as(?usize, 0), it.next());
        try std.testing.expectEqual(@as(?usize, null), it.next());
        try std.testing.expect(isGraphemeBoundary(text, 0));
        try std.testing.expect(!isGraphemeBoundary(text, 1));
        try std.testing.expect(isGraphemeBoundary(text, 3));
    }
    // Emoji ZWJ sequence is one cluster (GB11: EP Extend* ZWJ x EP).
    {
        // U+1F468 MAN + ZWJ + U+1F469 WOMAN.
        const text = "\xf0\x9f\x91\xa8\xe2\x80\x8d\xf0\x9f\x91\xa9";
        try std.testing.expectEqual(@as(usize, 1), countGraphemes(text));
    }
    // Two flags (4 RI) are two clusters (GB12/13 pair splitting).
    {
        // U+1F1FA U+1F1F8 U+1F1EB U+1F1F7.
        const text = "\xf0\x9f\x87\xba\xf0\x9f\x87\xb8\xf0\x9f\x87\xab\xf0\x9f\x87\xb7";
        try std.testing.expectEqual(@as(usize, 2), countGraphemes(text));
    }
    // Single flag (2 RI) is one cluster.
    {
        const text = "\xf0\x9f\x87\xba\xf0\x9f\x87\xb8";
        try std.testing.expectEqual(@as(usize, 1), countGraphemes(text));
    }
    // CRLF is one cluster (GB3).
    {
        try std.testing.expectEqual(@as(usize, 3), countGraphemes("a\r\nb"));
        var it = graphemeIndices("a\r\nb");
        var starts: [4]usize = undefined;
        var n: usize = 0;
        while (it.next()) |s| {
            starts[n] = s;
            n += 1;
        }
        try std.testing.expectEqual(@as(usize, 3), n);
        try std.testing.expectEqual(@as(usize, 0), starts[0]);
        try std.testing.expectEqual(@as(usize, 1), starts[1]);
        try std.testing.expectEqual(@as(usize, 3), starts[2]);
    }
    // Hangul L+V is one cluster (GB6).
    {
        const text = "\xe1\x84\x80\xe1\x85\xa1"; // U+1100 U+1161
        try std.testing.expectEqual(@as(usize, 1), countGraphemes(text));
    }
    // Prepend does not break (GB9b).
    {
        const text = "\xd8\x80a"; // U+0600 ARABIC NUMBER SIGN + 'a'
        try std.testing.expectEqual(@as(usize, 1), countGraphemes(text));
    }
    // Cluster-aware cursor motion: Backspace over "a + acute".
    {
        const text = "a\xcc\x81";
        try std.testing.expectEqual(@as(usize, 0), prevGraphemeStart(text, 3));
        try std.testing.expectEqual(@as(usize, 3), nextGraphemeEnd(text, 0));
    }
}

test "word: CJK and NBSP (UAX#29 WB5/WB3d)" {
    // UCD WordBreakProperty.txt leaves Han unlisted (WB=Other): each
    // ideograph is its own segment. (Dictionary-based CJK word segmentation
    // is not part of UAX#29; the old shard folded Han into ALetter and glued
    // 日本 into a single "word".)
    {
        const text = "\xe6\x97\xa5\xe6\x9c\xac"; // 日本
        var it = wordBounds(text);
        const first = it.next().?;
        const second = it.next().?;
        try std.testing.expect(it.next() == null);
        try std.testing.expectEqual(@as(usize, 0), first.start);
        try std.testing.expectEqual(@as(usize, 3), first.end);
        try std.testing.expectEqual(@as(usize, 3), second.start);
        try std.testing.expectEqual(@as(usize, 6), second.end);
    }
    {
        // "hello world" splits into word/space/word.
        var it = wordBounds("hello world");
        const w0 = it.next().?;
        const sp = it.next().?;
        const w1 = it.next().?;
        try std.testing.expect(it.next() == null);
        try std.testing.expectEqualStrings("hello", "hello world"[w0.start..w0.end]);
        try std.testing.expectEqualStrings(" ", "hello world"[sp.start..sp.end]);
        try std.testing.expectEqualStrings("world", "hello world"[w1.start..w1.end]);
    }
    {
        // UCD WordBreakProperty.txt: NBSP (00A0) is not listed, i.e. WB=Other
        // and WB999 splits it from adjacent words. That contradicts the old
        // ExtendNumLet approximation, which glued "hello<NBSP>world" into one
        // segment; the UCD/ezi behavior is three segments and `isWordRange`
        // still rejects the NBSP segment because it is White_Space.
        const text = "hello\xc2\xa0world";
        var it = wordBounds(text);
        const w0 = it.next().?;
        const nb = it.next().?;
        const w1 = it.next().?;
        try std.testing.expect(it.next() == null);
        try std.testing.expectEqualStrings("hello", text[w0.start..w0.end]);
        try std.testing.expectEqualStrings("\xc2\xa0", text[nb.start..nb.end]);
        try std.testing.expectEqualStrings("world", text[w1.start..w1.end]);
        try std.testing.expect(!isWordRange(text, nb));
    }
    {
        // Digits join letters (WB9/10) and comma-between-digits holds (WB12).
        var it = wordBounds("abc123");
        var n: usize = 0;
        while (it.next()) |_| n += 1;
        try std.testing.expectEqual(@as(usize, 1), n);
    }
    {
        // Katakana runs join (WB13).
        const text = "\xe3\x82\xab\xe3\x82\xbf\xe3\x82\xab\xe3\x83\x8a"; // カタカナ
        var it = wordBounds(text);
        var n: usize = 0;
        while (it.next()) |_| n += 1;
        try std.testing.expectEqual(@as(usize, 1), n);
    }
}

test "line: hyphen CJK NBSP WJ (UAX#14)" {
    // "foo-bar": break after hyphen, not before.
    {
        const text = "foo-bar";
        const breaks = try collectLineBreaks(std.testing.allocator, text);
        defer std.testing.allocator.free(breaks);
        // Offsets: after '-' (4) + eot (7). No break before '-' (3).
        var has_after = false;
        var has_before = false;
        for (breaks) |b| {
            if (b == 4) has_after = true;
            if (b == 3) has_before = true;
        }
        try std.testing.expect(has_after);
        try std.testing.expect(!has_before);
    }
    // CJK ideographs break on both sides.
    {
        const text = "\xe6\x97\xa5\xe6\x9c\xac\xe8\xaa\x9e"; // 日本語
        const breaks = try collectLineBreaks(std.testing.allocator, text);
        defer std.testing.allocator.free(breaks);
        // Each 3-byte char boundary is a break (3, 6) + eot (9).
        try std.testing.expectEqual(@as(usize, 3), breaks.len);
        try std.testing.expectEqual(@as(usize, 3), breaks[0]);
        try std.testing.expectEqual(@as(usize, 6), breaks[1]);
        try std.testing.expectEqual(@as(usize, 9), breaks[2]);
    }
    // NBSP (GL): no break on either side.
    {
        const text = "a\xc2\xa0b";
        var it = lineBreakOpportunities(text);
        var found_inner = false;
        while (it.next()) |br| {
            if (br.offset == 1 or br.offset == 3) found_inner = true;
        }
        try std.testing.expect(!found_inner);
    }
    // WJ (U+2060): no break on either side.
    {
        const text = "a\xe2\x81\xa0b";
        var it = lineBreakOpportunities(text);
        var found_inner = false;
        while (it.next()) |br| {
            if (br.offset == 1 or br.offset == 4) found_inner = true;
        }
        try std.testing.expect(!found_inner);
    }
    // Space yields an opportunity after it (LB18); letters must not split.
    {
        const text = "ab cd";
        const breaks = try collectLineBreaks(std.testing.allocator, text);
        defer std.testing.allocator.free(breaks);
        var has_space_break = false;
        var has_letter_break = false;
        for (breaks) |b| {
            if (b == 3) has_space_break = true;
            if (b == 1) has_letter_break = true;
        }
        try std.testing.expect(has_space_break);
        // LB28: AL x AL -- no break between 'a' and 'b'.
        try std.testing.expect(!has_letter_break);
    }
    // LB23: letters and digits glue ("abc123").
    {
        const text = "abc123";
        const breaks = try collectLineBreaks(std.testing.allocator, text);
        defer std.testing.allocator.free(breaks);
        for (breaks) |b| {
            try std.testing.expectEqual(@as(usize, 6), b);
        }
    }
    // "hello(world)" keeps CP/OP attachment (LB30): no breaks inside the
    // word-paren run (offsets 5..15 are the interior boundaries), while the
    // spaces still yield opportunities.
    {
        const text = "say hello(world) now";
        const breaks = try collectLineBreaks(std.testing.allocator, text);
        defer std.testing.allocator.free(breaks);
        var has_inner = false;
        for (breaks) |b| {
            if (b >= 5 and b <= 15) has_inner = true;
        }
        try std.testing.expect(!has_inner);
        var has_space = false;
        for (breaks) |b| {
            if (b == 4 or b == 17) has_space = true;
        }
        try std.testing.expect(has_space);
    }
    // Mandatory break after LF (LB5).
    {
        var it = lineBreakOpportunities("a\nb");
        const first = it.next().?;
        try std.testing.expectEqual(@as(usize, 2), first.offset);
        try std.testing.expectEqual(LineBreakKind.mandatory, first.kind);
    }
}

test "bidi: mixed paragraph and explicit embeddings (UAX#9)" {
    const alloc = std.testing.allocator;
    // Pure LTR.
    {
        const lv = try baseLevels(alloc, "abc", .auto);
        defer alloc.free(lv);
        try std.testing.expectEqual(@as(usize, 3), lv.len);
        for (lv) |l| try std.testing.expectEqual(LEVEL_LTR, l);
    }
    // Mixed LTR paragraph with Hebrew run: Hebrew at level 1.
    {
        // "ab" + U+05D0 U+05D1.
        const text = "ab\xd7\x90\xd7\x91";
        const lv = try baseLevels(alloc, text, .ltr);
        defer alloc.free(lv);
        try std.testing.expectEqual(@as(usize, 6), lv.len);
        try std.testing.expectEqual(LEVEL_LTR, lv[0]);
        try std.testing.expectEqual(LEVEL_LTR, lv[1]);
        try std.testing.expectEqual(@as(Level, 1), lv[2]);
        try std.testing.expectEqual(@as(Level, 1), lv[4]);
        // L2 reorder of [0,0,1,1] keeps LTR run then reverses RTL run.
        const order = try reorderVisual(alloc, &[_]Level{ 0, 0, 1, 1 });
        defer alloc.free(order);
        try std.testing.expectEqualSlices(usize, &[_]usize{ 0, 1, 3, 2 }, order);
    }
    // Arabic letters are AL and must resolve to R via W3: level 1 in an LTR
    // paragraph (regression: W3 was missing, leaving Arabic at level 0).
    {
        // "ab" + U+0645 U+0631.
        const text = "ab\xd9\x85\xd8\xb1";
        const lv = try baseLevels(alloc, text, .ltr);
        defer alloc.free(lv);
        try std.testing.expectEqual(@as(usize, 6), lv.len);
        try std.testing.expectEqual(LEVEL_LTR, lv[0]);
        try std.testing.expectEqual(LEVEL_LTR, lv[1]);
        try std.testing.expectEqual(@as(Level, 1), lv[2]);
        try std.testing.expectEqual(@as(Level, 1), lv[4]);
    }
    // RTL paragraph with embedded LTR word.
    {
        // U+05D0 + " " + "ab".
        const text = "\xd7\x90 ab";
        const lv = try baseLevels(alloc, text, .auto);
        defer alloc.free(lv);
        // Paragraph level is RTL (first strong Hebrew).
        try std.testing.expectEqual(@as(Level, 1), paragraphLevel(text, .auto));
        // "ab" rises to level 2 (I1 even + L).
        try std.testing.expectEqual(@as(Level, 2), lv[3]);
        try std.testing.expectEqual(@as(Level, 2), lv[4]);
    }
    // Explicit embedding: RLE ... PDF raises the inner run.
    {
        // U+202B RLE + "ab" + U+202C PDF.
        const text = "\xe2\x80\xab ab\xe2\x80\xac";
        const lv = try baseLevels(alloc, text, .ltr);
        defer alloc.free(lv);
        // RLE/PDF are BN (X9-removed) but carry the surrounding/next level;
        // the inner "ab" sits above the paragraph level.
        const inner_a = lv[3];
        try std.testing.expect(inner_a > LEVEL_LTR);
    }
    // Paragraph split: "a\nb" yields two paragraphs.
    {
        var it = bidiParagraphs("a\nb", .auto);
        const p0 = it.next().?;
        const p1 = it.next().?;
        try std.testing.expect(it.next() == null);
        try std.testing.expectEqual(@as(usize, 0), p0.start);
        try std.testing.expectEqual(@as(usize, 2), p0.end);
        try std.testing.expectEqual(@as(usize, 2), p1.start);
        try std.testing.expectEqual(@as(usize, 3), p1.end);
        try std.testing.expectEqual(LEVEL_LTR, p0.level);
        try std.testing.expectEqual(LEVEL_LTR, p1.level);
    }
}

test "bidi: directional marks, Arabic digits, controls, Latin-1 (UAX#9 classes)" {
    // Implicit directional marks are strong, not X9-removed BN.
    try std.testing.expectEqual(BidiClass.l, bidiClass(0x200E)); // LRM
    try std.testing.expectEqual(BidiClass.r, bidiClass(0x200F)); // RLM
    try std.testing.expectEqual(BidiClass.al, bidiClass(0x061C)); // ALM
    // Arabic-Indic digits are AN; Extended Arabic-Indic digits are EN
    // (DerivedBidiClass: digits stop folding into the surrounding AL block).
    var cp: CodePoint = 0x0660;
    while (cp <= 0x0669) : (cp += 1) try std.testing.expectEqual(BidiClass.an, bidiClass(cp));
    cp = 0x06F0;
    while (cp <= 0x06F9) : (cp += 1) try std.testing.expectEqual(BidiClass.en, bidiClass(cp));
    cp = 0x0600;
    while (cp <= 0x0605) : (cp += 1) try std.testing.expectEqual(BidiClass.an, bidiClass(cp));
    try std.testing.expectEqual(BidiClass.an, bidiClass(0x066B));
    try std.testing.expectEqual(BidiClass.an, bidiClass(0x066C));
    try std.testing.expectEqual(BidiClass.an, bidiClass(0x06DD));
    // Latin-1 supplement: NBSP/NNBSP are CS, symbols are ON, superscripts are
    // EN, ordinals are letters (not the broad L range).
    try std.testing.expectEqual(BidiClass.cs, bidiClass(0x00A0));
    try std.testing.expectEqual(BidiClass.cs, bidiClass(0x202F));
    try std.testing.expectEqual(BidiClass.en, bidiClass(0x00B9));
    try std.testing.expectEqual(BidiClass.on, bidiClass(0x00BC));
    try std.testing.expectEqual(BidiClass.l, bidiClass(0x00BA));
    try std.testing.expectEqual(BidiClass.on, bidiClass(0x00A9));
    try std.testing.expectEqual(BidiClass.on, bidiClass(0x00AE));
    try std.testing.expectEqual(BidiClass.on, bidiClass(0x00D7));
    try std.testing.expectEqual(BidiClass.on, bidiClass(0x00F7));
    try std.testing.expectEqual(BidiClass.bn, bidiClass(0x00AD));
    try std.testing.expectEqual(BidiClass.l, bidiClass(0x00B5));
    // European Separator / European Terminator (DerivedBidiClass).
    try std.testing.expectEqual(BidiClass.es, bidiClass(0x002B));
    try std.testing.expectEqual(BidiClass.es, bidiClass(0x002D));
    try std.testing.expectEqual(BidiClass.cs, bidiClass(0x002F));
    try std.testing.expectEqual(BidiClass.et, bidiClass(0x0023));
    try std.testing.expectEqual(BidiClass.et, bidiClass(0x0024));
    try std.testing.expectEqual(BidiClass.et, bidiClass(0x0025));
    // White space vs separators.
    cp = 0x2000;
    while (cp <= 0x200A) : (cp += 1) try std.testing.expectEqual(BidiClass.ws, bidiClass(cp));
    try std.testing.expectEqual(BidiClass.ws, bidiClass(0x2028)); // LINE SEPARATOR
    try std.testing.expectEqual(BidiClass.b, bidiClass(0x2029)); // PARAGRAPH SEPARATOR
    // UCD DerivedBidiClass: TAB/VT/US are S, FORM FEED is WS, and
    // FILE/GROUP/RECORD separators are B.
    try std.testing.expectEqual(BidiClass.s, bidiClass(0x0009));
    try std.testing.expectEqual(BidiClass.s, bidiClass(0x000B));
    try std.testing.expectEqual(BidiClass.s, bidiClass(0x001F));
    try std.testing.expectEqual(BidiClass.ws, bidiClass(0x000C));
    try std.testing.expectEqual(BidiClass.b, bidiClass(0x001C));
    try std.testing.expectEqual(BidiClass.b, bidiClass(0x001D));
    try std.testing.expectEqual(BidiClass.b, bidiClass(0x001E));
    // Embedding/isolate controls keep their own classes.
    try std.testing.expectEqual(BidiClass.lre, bidiClass(0x202A));
    try std.testing.expectEqual(BidiClass.rle, bidiClass(0x202B));
    try std.testing.expectEqual(BidiClass.pdf, bidiClass(0x202C));
    try std.testing.expectEqual(BidiClass.lro, bidiClass(0x202D));
    try std.testing.expectEqual(BidiClass.rlo, bidiClass(0x202E));
    try std.testing.expectEqual(BidiClass.lri, bidiClass(0x2066));
    try std.testing.expectEqual(BidiClass.rli, bidiClass(0x2067));
    try std.testing.expectEqual(BidiClass.fsi, bidiClass(0x2068));
    try std.testing.expectEqual(BidiClass.pdi, bidiClass(0x2069));
    // Default-ignorable format/join controls are BN.
    cp = 0x2060;
    while (cp <= 0x2064) : (cp += 1) try std.testing.expectEqual(BidiClass.bn, bidiClass(cp));
    try std.testing.expectEqual(BidiClass.bn, bidiClass(0xFEFF));
    try std.testing.expectEqual(BidiClass.bn, bidiClass(0x200C));
    try std.testing.expectEqual(BidiClass.bn, bidiClass(0x200D));
    try std.testing.expectEqual(BidiClass.bn, bidiClass(0x200B));
    // Halfwidth kana voiced marks stay letters despite being GCB Extend.
    try std.testing.expectEqual(BidiClass.l, bidiClass(0xFF9E));
    try std.testing.expectEqual(BidiClass.l, bidiClass(0xFF9F));
    // Bracket/isolate controls are ON/LRI/RLI/FSI/PDI respectively.
    try std.testing.expectEqual(BidiClass.on, bidiClass('('));
    try std.testing.expectEqual(BidiClass.on, bidiClass(')'));
    try std.testing.expectEqual(BidiClass.on, bidiClass('['));
    try std.testing.expectEqual(BidiClass.on, bidiClass(0x3008));
}

test "bidi: paragraph level and levels with LRM/RLM/ALM (UAX#9 P2/P3)" {
    const alloc = std.testing.allocator;
    // LRM is L: a paragraph starting with it is LTR even before Hebrew.
    {
        const text = "\xe2\x80\x8e\xd7\x90"; // U+200E + U+05D0
        try std.testing.expectEqual(LEVEL_LTR, paragraphLevel(text, .auto));
        const lv = try baseLevels(alloc, text, .auto);
        defer alloc.free(lv);
        try std.testing.expectEqual(LEVEL_LTR, lv[0]);
        try std.testing.expectEqual(LEVEL_LTR, lv[2]);
        try std.testing.expectEqual(@as(Level, 1), lv[3]);
        try std.testing.expectEqual(@as(Level, 1), lv[4]);
    }
    // RLM is R: the paragraph is RTL and the Latin run rises to level 2.
    {
        const text = "\xe2\x80\x8f" ++ "ab"; // U+200F + "ab"
        try std.testing.expectEqual(LEVEL_RTL, paragraphLevel(text, .auto));
        const lv = try baseLevels(alloc, text, .auto);
        defer alloc.free(lv);
        try std.testing.expectEqual(@as(Level, 1), lv[0]);
        try std.testing.expectEqual(@as(Level, 1), lv[2]);
        try std.testing.expectEqual(@as(Level, 2), lv[3]);
        try std.testing.expectEqual(@as(Level, 2), lv[4]);
    }
    // ALM is AL (W3 -> R): also RTL.
    {
        const text = "\xd8\x9c" ++ "a"; // U+061C + "a"
        try std.testing.expectEqual(LEVEL_RTL, paragraphLevel(text, .auto));
        const lv = try baseLevels(alloc, text, .auto);
        defer alloc.free(lv);
        try std.testing.expectEqual(@as(Level, 1), lv[0]);
        try std.testing.expectEqual(@as(Level, 1), lv[1]);
        try std.testing.expectEqual(@as(Level, 2), lv[2]);
    }
    // Isolates are skipped by P2 (content of RLI does not set the base).
    {
        // U+2067 RLI + Hebrew + U+2069 PDI + "a".
        const text = "\xe2\x81\xa7\xd7\x90\xe2\x81\xa9a";
        try std.testing.expectEqual(LEVEL_LTR, paragraphLevel(text, .auto));
    }
    // FSI content is skipped by P2 (its own direction only affects the
    // isolate, never the paragraph base): P3 default LTR wins.
    {
        // U+2068 FSI + Hebrew + U+2069 PDI.
        const text = "\xe2\x81\xa8\xd7\x90\xe2\x81\xa9";
        try std.testing.expectEqual(LEVEL_LTR, paragraphLevelForCodepoints(&[_]CodePoint{ 0x2068, 0x05D0, 0x2069 }, .auto));
        try std.testing.expectEqual(LEVEL_LTR, paragraphLevel(text, .auto));
    }
    // L4 mirroring uses the full BidiMirroring table now (not 8 ASCII pairs).
    try std.testing.expectEqual(@as(CodePoint, ')'), mirrorCodepoint('(', 1));
    try std.testing.expectEqual(@as(CodePoint, '('), mirrorCodepoint('(', 0));
    try std.testing.expectEqual(@as(CodePoint, 0x220B), mirrorCodepoint(0x2208, 1)); // ELEMENT OF
    try std.testing.expectEqual(@as(CodePoint, 0x2208), mirrorCodepoint(0x2208, 2));
    try std.testing.expectEqual(@as(CodePoint, 0x27E7), mirrorCodepoint(0x27E6, 1)); // MATHEMATICAL WHITE SQUARE BRACKET
}

test "grapheme: Indic/Thai/Hebrew marks and emoji modifiers (GB9/GB9a/GB9c)" {
    // Direct shard checks.
    try std.testing.expect(isGraphemeExtend(0x094D));
    try std.testing.expect(isGraphemeExtend(0x0E31));
    try std.testing.expect(isGraphemeExtend(0x1F3FB));
    try std.testing.expect(isGraphemeExtend(0x200C));
    try std.testing.expect(isGraphemeExtend(0xFF9E));
    try std.testing.expect(isSpacingMark(0x093E));
    try std.testing.expect(!isGraphemeExtend(0x093E));
    try std.testing.expect(isPrepend(0x0600));
    try std.testing.expectEqual(InCB.consonant, inCB(0x0915)); // DEVANAGARI KA
    try std.testing.expectEqual(InCB.linker, inCB(0x094D)); // VIRAMA
    // Indic consonant + vowel sign is one cluster.
    try std.testing.expectEqual(@as(usize, 1), countGraphemes("\xe0\xa4\x95\xe0\xa4\xbe")); // क + AA
    try std.testing.expectEqual(@as(usize, 1), countGraphemes("\xe0\xa6\x95\xe0\xa6\xbe")); // ক + AA
    try std.testing.expectEqual(@as(usize, 1), countGraphemes("\xe0\xae\x95\xe0\xae\xbe")); // க + AA
    try std.testing.expectEqual(@as(usize, 1), countGraphemes("\xe0\xb0\x95\xe0\xb0\xbe")); // Telugu KA + AA
    try std.testing.expectEqual(@as(usize, 1), countGraphemes("\xe0\xb2\x95\xe0\xb3\x86")); // Kannada KA + E
    try std.testing.expectEqual(@as(usize, 1), countGraphemes("\xe0\xb4\x95\xe0\xb4\xbe")); // Malayalam KA + AA
    // Devanagari conjunct (GB9c): KA + VIRAMA + SSA.
    try std.testing.expectEqual(@as(usize, 1), countGraphemes("\xe0\xa4\x95\xe0\xa5\x8d\xe0\xa4\xb7"));
    // Hebrew point and Arabic harakah attach.
    try std.testing.expectEqual(@as(usize, 1), countGraphemes("\xd7\x90\xd6\xb8")); // ALEF + QAMATS
    try std.testing.expectEqual(@as(usize, 1), countGraphemes("\xd8\xa7\xd9\x8e")); // ALEF + FATHA
    // Thai/Lao marks attach.
    try std.testing.expectEqual(@as(usize, 1), countGraphemes("\xe0\xb8\x81\xe0\xb8\xb1")); // KO KAI + MAI HAN-AKAT
    try std.testing.expectEqual(@as(usize, 1), countGraphemes("\xe0\xba\x81\xe0\xba\xb1")); // LAO KO + MAI KAN
    // Emoji modifier is Extend (skin tone).
    try std.testing.expectEqual(@as(usize, 1), countGraphemes("\xf0\x9f\x91\x8d\xf0\x9f\x8f\xbd")); // THUMBS UP + TONE-3
    // Extended_Pictographic includes sun/star; both join via ZWJ (GB11).
    try std.testing.expect(isExtendedPictographic(0x2600));
    try std.testing.expect(isExtendedPictographic(0x2B50));
    try std.testing.expectEqual(@as(usize, 1), countGraphemes("\xe2\x98\x80\xe2\x80\x8d\xe2\x98\x80")); // U+2600 ZWJ U+2600
    try std.testing.expectEqual(@as(usize, 1), countGraphemes("\xe2\xad\x90\xe2\x80\x8d\xe2\xad\x90")); // U+2B50 ZWJ U+2B50
}

test "word: Hebrew/Arabic/Georgian/Ethiopic/Indic/fullwidth ranges (UAX#29 shard)" {
    // Direct property rows for the covered scripts.
    try std.testing.expectEqual(WordProp.hebrew_letter, wordBreakProperty(0x05D0));
    try std.testing.expectEqual(WordProp.extend, wordBreakProperty(0x05B8));
    try std.testing.expectEqual(WordProp.numeric, wordBreakProperty(0x066B));
    try std.testing.expectEqual(WordProp.mid_num, wordBreakProperty(0x066C));
    try std.testing.expectEqual(WordProp.numeric, wordBreakProperty(0x06F0));
    try std.testing.expectEqual(WordProp.aletter, wordBreakProperty(0x10D0)); // Georgian
    try std.testing.expectEqual(WordProp.aletter, wordBreakProperty(0x1200)); // Ethiopic
    // Thai/Lao/Khmer/Myanmar are UAX#29 WB=Other (complex scripts rely on
    // dictionary segmentation, which is outside UAX#29); the old shard
    // approximated them as ALetter.
    try std.testing.expectEqual(WordProp.other, wordBreakProperty(0x0E01)); // Thai
    try std.testing.expectEqual(WordProp.aletter, wordBreakProperty(0x0D15)); // Malayalam
    try std.testing.expectEqual(WordProp.numeric, wordBreakProperty(0x0E50)); // Thai digit
    try std.testing.expectEqual(WordProp.extend, wordBreakProperty(0x0E31)); // Thai mark
    try std.testing.expectEqual(WordProp.katakana, wordBreakProperty(0x3031));
    try std.testing.expectEqual(WordProp.katakana, wordBreakProperty(0xFF66));
    try std.testing.expectEqual(WordProp.katakana, wordBreakProperty(0xFF70));
    try std.testing.expectEqual(WordProp.extend, wordBreakProperty(0xFF9E));
    try std.testing.expectEqual(WordProp.aletter, wordBreakProperty(0xFF21));
    try std.testing.expectEqual(WordProp.numeric, wordBreakProperty(0xFF10));
    const countWords = struct {
        fn f(text: []const u8) usize {
            var it = wordBounds(text);
            var n: usize = 0;
            while (it.next() != null) n += 1;
            return n;
        }
    }.f;
    // Hebrew letters (+ points as Extend) form one word.
    try std.testing.expectEqual(@as(usize, 1), countWords("\xd7\xa9\xd7\x9c\xd7\x95\xd7\x9d")); // שלום
    try std.testing.expectEqual(@as(usize, 1), countWords("\xd7\x90\xd6\xb8\xd7\x91")); // ALEF + QAMATS + BET
    // Arabic letters (+ harakat as Extend) form one word.
    try std.testing.expectEqual(@as(usize, 1), countWords("\xd9\x85\xd8\xb1\xd8\xad\xd8\xa8\xd8\xa7")); // مرحبا
    try std.testing.expectEqual(@as(usize, 1), countWords("\xd8\xa7\xd9\x8e\xd8\xa8")); // ALEF + FATHA + BEH
    // Arabic-Indic digits are Numeric (WB9 glues them to letters).
    try std.testing.expectEqual(@as(usize, 1), countWords("\xd9\xa1\xd9\xa2\xd9\xa3")); // ١٢٣
    try std.testing.expectEqual(@as(usize, 1), countWords("a\xd9\xa1"));
    // Georgian and Ethiopic letters.
    try std.testing.expectEqual(@as(usize, 1), countWords("\xe1\x83\xa5\xe1\x83\x90\xe1\x83\xa0")); // ქარ
    try std.testing.expectEqual(@as(usize, 1), countWords("\xe1\x88\xb0\xe1\x88\x8b\xe1\x88\x9d")); // ሰላም
    // Devanagari letters + virama + vowel sign stay one word.
    try std.testing.expectEqual(@as(usize, 1), countWords("\xe0\xa4\xa8\xe0\xa4\xae\xe0\xa4\xb8\xe0\xa5\x8d\xe0\xa4\xa4\xe0\xa5\x87")); // नमस्ते
    try std.testing.expectEqual(@as(usize, 1), countWords("\xe0\xa6\x95\xe0\xa6\xbe")); // কা
    try std.testing.expectEqual(@as(usize, 1), countWords("\xe0\xae\x95\xe0\xae\xbe")); // கா
    // Fullwidth Latin letters + digits (letters -> ALetter, digits -> Numeric).
    try std.testing.expectEqual(@as(usize, 1), countWords("\xef\xbc\xa1\xef\xbc\xa2\xef\xbc\x91\xef\xbc\x92")); // ＡＢ１２
    // Halfwidth katakana runs join (Katakana).
    try std.testing.expectEqual(@as(usize, 1), countWords("\xef\xbd\xb6\xef\xbd\xb7\xef\xbd\xb8")); // ｶｷｸ
}

test "line: class shard fixes (SY/IS/GL/HH/fullwidth) (UAX#14)" {
    try std.testing.expectEqual(LineClass.sy, lineBreakClass(0x002F)); // SOLIDUS
    try std.testing.expectEqual(LineClass.is, lineBreakClass(0x002C));
    try std.testing.expectEqual(LineClass.is, lineBreakClass(0x003B));
    try std.testing.expectEqual(LineClass.is, lineBreakClass(0x003A));
    try std.testing.expectEqual(LineClass.is, lineBreakClass(0x002E));
    // UCD 17: U+2010 is HH (unambiguous hyphen), not the old BA shard.
    try std.testing.expectEqual(LineClass.hh, lineBreakClass(0x2010));
    try std.testing.expectEqual(LineClass.gl, lineBreakClass(0x2011));
    try std.testing.expectEqual(LineClass.gl, lineBreakClass(0x00A0));
    try std.testing.expectEqual(LineClass.gl, lineBreakClass(0x2007));
    var cp: CodePoint = 0x2000;
    while (cp <= 0x2006) : (cp += 1) try std.testing.expectEqual(LineClass.ba, lineBreakClass(cp));
    cp = 0x2008;
    while (cp <= 0x200A) : (cp += 1) try std.testing.expectEqual(LineClass.ba, lineBreakClass(cp));
    try std.testing.expectEqual(LineClass.ba, lineBreakClass(0x205F));
    try std.testing.expectEqual(LineClass.ba, lineBreakClass(0x3000)); // UCD 17: BA
    // CJK/fullwidth break opportunities.
    try std.testing.expectEqual(LineClass.id, lineBreakClass(0x2E80));
    try std.testing.expectEqual(LineClass.id, lineBreakClass(0xF900));
    try std.testing.expectEqual(LineClass.id, lineBreakClass(0xFF21));
    try std.testing.expectEqual(LineClass.ex, lineBreakClass(0xFF01));
    try std.testing.expectEqual(LineClass.op, lineBreakClass(0xFF08));
    try std.testing.expectEqual(LineClass.cl, lineBreakClass(0xFF0C));
    // CJK punctuation / kana rows and fullwidth closers.
    try std.testing.expectEqual(LineClass.cl, lineBreakClass(0x3001));
    try std.testing.expectEqual(LineClass.op, lineBreakClass(0x3008));
    try std.testing.expectEqual(LineClass.cl, lineBreakClass(0x3009));
    try std.testing.expectEqual(LineClass.ns, lineBreakClass(0x301C));
    try std.testing.expectEqual(LineClass.ns, lineBreakClass(0x3005));
    try std.testing.expectEqual(LineClass.id, lineBreakClass(0x3031));
    try std.testing.expectEqual(LineClass.cm, lineBreakClass(0x3035));
    // U+30FC is raw Line_Break=CJ; UAX#14 LB1 resolves CJ -> NS inside the
    // algorithm (the old shard exposed the effective NS as the class).
    try std.testing.expectEqual(LineClass.cj, lineBreakClass(0x30FC));
    try std.testing.expectEqual(LineClass.cl, lineBreakClass(0xFF09));
    try std.testing.expectEqual(LineClass.cl, lineBreakClass(0xFF63));
    try std.testing.expectEqual(LineClass.ns, lineBreakClass(0xFF9E));
}

test "line: plus and backslash are PR, ++ splits (UAX#14)" {
    // UCD LineBreak.txt: 002B and 005C are PR, not SY.
    try std.testing.expectEqual(LineClass.pr, lineBreakClass(0x002B));
    try std.testing.expectEqual(LineClass.pr, lineBreakClass(0x005C));
    const alloc = std.testing.allocator;
    const breaks = try collectLineBreaks(alloc, "++");
    defer alloc.free(breaks);
    // PR PR is not prohibited, so the default LB31 opportunity applies.
    // The iterator also reports the end-of-text position.
    try std.testing.expect(breaks.len >= 1);
    try std.testing.expectEqual(@as(usize, 1), breaks[0]);
}

test "line: numeric separators, solidus and CJK radicals wrap (UAX#14)" {
    const alloc = std.testing.allocator;
    // LB25 numeric chain: IS glues "1,000" and "3.14".
    {
        const breaks = try collectLineBreaks(alloc, "1,000");
        defer alloc.free(breaks);
        try std.testing.expectEqual(@as(usize, 1), breaks.len);
        try std.testing.expectEqual(@as(usize, 5), breaks[0]);
    }
    {
        const breaks = try collectLineBreaks(alloc, "3.14");
        defer alloc.free(breaks);
        try std.testing.expectEqual(@as(usize, 1), breaks.len);
        try std.testing.expectEqual(@as(usize, 4), breaks[0]);
    }
    // "a/b": no break before '/', break after.
    {
        var has_before = false;
        var has_after = false;
        var it = lineBreakOpportunities("a/b");
        while (it.next()) |br| {
            if (br.offset == 1) has_before = true;
            if (br.offset == 2) has_after = true;
        }
        try std.testing.expect(!has_before);
        try std.testing.expect(has_after);
    }
    // U+3000 BA: no break before, break after.
    {
        var has_before = false;
        var has_after = false;
        var it = lineBreakOpportunities("a\xe3\x80\x80b");
        while (it.next()) |br| {
            if (br.offset == 1) has_before = true;
            if (br.offset == 4) has_after = true;
        }
        try std.testing.expect(!has_before);
        try std.testing.expect(has_after);
    }
    // CJK radicals and fullwidth letters are ID (breakable).
    {
        const breaks = try collectLineBreaks(alloc, "\xe2\xba\x80\xe2\xba\x81"); // U+2E80 U+2E81
        defer alloc.free(breaks);
        var has_mid = false;
        for (breaks) |b| {
            if (b == 3) has_mid = true;
        }
        try std.testing.expect(has_mid);
    }
    {
        const breaks = try collectLineBreaks(alloc, "\xef\xbc\xa1\xef\xbc\xa2"); // ＡＢ
        defer alloc.free(breaks);
        var has_mid = false;
        for (breaks) |b| {
            if (b == 3) has_mid = true;
        }
        try std.testing.expect(has_mid);
    }
}

test "delegation: properties equal ezi tables over representative ranges" {
    // Independent reverse maps so a wrong forward mapping cannot cancel out.
    const Ref = struct {
        fn bidi(c: BidiClass) ezi.properties.BidiClass {
            return switch (c) {
                .l => .left_to_right,
                .r => .right_to_left,
                .al => .arabic_letter,
                .en => .european_number,
                .es => .european_separator,
                .et => .european_terminator,
                .an => .arabic_number,
                .cs => .common_separator,
                .nsm => .non_spacing_mark,
                .bn => .boundary_neutral,
                .b => .paragraph_separator,
                .s => .segment_separator,
                .ws => .whitespace,
                .on => .other_neutral,
                .lre => .left_to_right_embedding,
                .lro => .left_to_right_override,
                .rle => .right_to_left_embedding,
                .rlo => .right_to_left_override,
                .pdf => .pop_directional_format,
                .lri => .left_to_right_isolate,
                .rli => .right_to_left_isolate,
                .fsi => .first_strong_isolate,
                .pdi => .pop_directional_isolate,
            };
        }

        fn script(s: Script) ?ezi.scripts.ScriptType {
            return switch (s) {
                .common => .common,
                .inherited => .inherited,
                .latin => .latin,
                .greek => .greek,
                .cyrillic => .cyrillic,
                .armenian => .armenian,
                .hebrew => .hebrew,
                .arabic => .arabic,
                .devanagari => .devanagari,
                .bengali => .bengali,
                .tamil => .tamil,
                .telugu => .telugu,
                .kannada => .kannada,
                .malayalam => .malayalam,
                .thai => .thai,
                .lao => .lao,
                .tibetan => .tibetan,
                .myanmar => .myanmar,
                .khmer => .khmer,
                .han => .han,
                .hiragana => .hiragana,
                .katakana => .katakana,
                .hangul => .hangul,
                .unknown => .unknown,
                .other => null,
            };
        }
    };

    // Latin, controls, Arabic, Hebrew, Indic, CJK, emoji, brackets/isolates.
    const ranges = [_][2]u21{
        .{ 0x0000, 0x02FF },   .{ 0x0370, 0x03FF },   .{ 0x0590, 0x06FF },
        .{ 0x0900, 0x0DFF },   .{ 0x0E00, 0x0EFF },   .{ 0x1000, 0x109F },
        .{ 0x1780, 0x17FF },   .{ 0x2000, 0x206F },   .{ 0x2600, 0x27BF },
        .{ 0x2E80, 0x2FFF },   .{ 0x3000, 0x30FF },   .{ 0x4E00, 0x4E80 },
        .{ 0xAC00, 0xAC20 },   .{ 0xF900, 0xFAFF },   .{ 0xFB1D, 0xFB4F },
        .{ 0xFE00, 0xFE0F },   .{ 0xFF00, 0xFFEF },   .{ 0x1F000, 0x1F6FF },
        .{ 0x1F900, 0x1FAFF }, .{ 0x20000, 0x20010 },
    };
    for (ranges) |range| {
        var cp: u21 = range[0];
        while (cp <= range[1]) : (cp += 1) {
            try std.testing.expectEqual(ezi.properties.isWhitespace(cp), isWhitespace(cp));
            // `isGraphemeExtend` is GB9 `Extend`, i.e. the GCB property (not
            // DerivedCoreProperties Grapheme_Extend, which excludes emoji
            // modifiers).
            try std.testing.expectEqual(ezi.segmentation.graphemeBreakProperty(cp) == .extend, isGraphemeExtend(cp));
            try std.testing.expectEqual(ezi.segmentation.graphemeBreakProperty(cp) == .spacing_mark, isSpacingMark(cp));
            try std.testing.expectEqual(ezi.segmentation.graphemeBreakProperty(cp) == .prepend, isPrepend(cp));
            try std.testing.expectEqual(ezi.segmentation.inCB(cp), inCB(cp));
            try std.testing.expectEqual(ezi.emoji.isExtendedPictographic(cp), isExtendedPictographic(cp));
            try std.testing.expectEqual(ezi.segmentation.lineBreak(cp), lineBreakClass(cp));
            try std.testing.expectEqual(ezi.segmentation.wordBreakProperty(cp), wordBreakProperty(cp));
            try std.testing.expectEqual(ezi.properties.bidiClass(cp), Ref.bidi(bidiClass(cp)));
            if (Ref.script(scriptOf(cp))) |expected| {
                try std.testing.expectEqual(expected, ezi.scripts.scriptType(cp));
            }
        }
    }
}

test "delegation: segmentation equals ezi over representative text" {
    const alloc = std.testing.allocator;
    const samples = [_][]const u8{
        "abc",
        "hello world",
        "don't stop",
        "a\xcc\x81",
        "\xf0\x9f\x91\xa8\xe2\x80\x8d\xf0\x9f\x91\xa9",
        "\xf0\x9f\x87\xba\xf0\x9f\x87\xb8\xf0\x9f\x87\xab\xf0\x9f\x87\xb7",
        "\xe6\x97\xa5\xe6\x9c\xac\xe8\xaa\x9e", // 日本語
        "\xed\x95\x9c\xea\xb5\xad\xec\x96\xb4", // 한국어
        "\xe3\x82\xab\xe3\x82\xbf\xe3\x82\xab\xe3\x83\x8a", // カタカナ
        "\xd9\x85\xd8\xb1\xd8\xad\xd8\xa8\xd8\xa7", // مرحبا
        "\xd7\xa9\xd7\x9c\xd7\x95\xd7\x9d", // שלום
        "\xe0\xa4\xa8\xe0\xa4\xae\xe0\xa4\xb8\xe0\xa5\x8d\xe0\xa4\xa4\xe0\xa5\x87", // नमस्ते
        "1,000.50",
        "hello\xc2\xa0world",
        "a\xe2\x80\x8db",
        "\r\nline\nbreak",
        "say (hi) [ok] {x}",
        "++\\",
        "a/b",
        "3.14",
        "  \t x",
        "a\xe2\x81\xa0b", // WORD JOINER
        "e\xcc\x81\xcc\xa7", // e + acute + cedilla
    };
    for (samples) |s| {
        // Grapheme clusters.
        try std.testing.expectEqual(ezi.segmentation.countGraphemes(s), countGraphemes(s));

        // Word segments.
        {
            var ours = wordBounds(s);
            var theirs = ezi.segmentation.wordIterator(s);
            var offset: usize = 0;
            while (true) {
                const o = ours.next();
                const t = theirs.next();
                if (o == null or t == null) {
                    try std.testing.expectEqual(o == null, t == null);
                    break;
                }
                try std.testing.expectEqualSlices(u8, s[offset .. offset + t.?.len], t.?);
                try std.testing.expectEqual(o.?.start, offset);
                try std.testing.expectEqual(o.?.end, offset + t.?.len);
                offset += t.?.len;
            }
            try std.testing.expectEqual(s.len, offset);
        }

        // Line-break opportunities.
        {
            var ours = lineBreakOpportunities(s);
            var theirs = ezi.segmentation.lineBreakIterator(s);
            var offset: usize = 0;
            while (true) {
                const o = ours.next();
                const t = theirs.next();
                if (o == null or t == null) {
                    try std.testing.expectEqual(o == null, t == null);
                    break;
                }
                offset += t.?.slice.len;
                try std.testing.expectEqual(o.?.offset, offset);
                try std.testing.expectEqual(o.?.kind, t.?.kind);
            }
            try std.testing.expectEqual(s.len, offset);
        }

        // Resolved BiDi levels (whole sample as one paragraph, all bases).
        inline for (.{ BaseDirection.ltr, BaseDirection.rtl, BaseDirection.auto }) |base| {
            const ours = try baseLevels(alloc, s, base);
            defer alloc.free(ours);
            const theirs = try RefBidi.levels(alloc, s, base);
            defer alloc.free(theirs);
            try std.testing.expectEqualSlices(Level, theirs, ours);
        }
    }
}

/// Test-only reference: ezi `resolveParagraph` + `lineLevels` expanded to
/// per-byte levels, the direct oracle for `baseLevels`.
const RefBidi = struct {
    fn levels(alloc: Allocator, text: []const u8, base: BaseDirection) ![]Level {
        var cps: std.ArrayList(CodePoint) = .empty;
        defer cps.deinit(alloc);
        var starts: std.ArrayList(usize) = .empty;
        defer starts.deinit(alloc);
        var lens: std.ArrayList(usize) = .empty;
        defer lens.deinit(alloc);
        var i: usize = 0;
        while (i < text.len) {
            const d = decodeOne(text, i);
            try cps.append(alloc, d.cp);
            try starts.append(alloc, i);
            try lens.append(alloc, d.len);
            i += d.len;
        }
        var para = try ezi.bidi.resolveParagraph(alloc, cps.items, switch (base) {
            .ltr => .ltr,
            .rtl => .rtl,
            .auto => .auto,
        });
        defer para.deinit();
        const line = try para.lineLevels(alloc, 0, cps.items.len);
        defer alloc.free(line);
        const out = try alloc.alloc(Level, text.len);
        for (starts.items, lens.items, line) |st, ln, lv| {
            var o: usize = 0;
            while (o < ln) : (o += 1) out[st + o] = lv;
        }
        return out;
    }
};

test "robustness: empty and malformed UTF-8 never panic" {
    const alloc = std.testing.allocator;
    const samples = [_][]const u8{
        "",
        "\xff",
        "\x80",
        "a\xffb",
        "\xc3",
        "\xe2\x28\xa1",
        "\xf0\x9f",
        "\xed\xa0\x80",
        "\xe2\x80",
    };
    for (samples) |s| {
        _ = countGraphemes(s);
        _ = isGraphemeBoundary(s, if (s.len == 0) 0 else 1);
        _ = prevGraphemeStart(s, s.len);
        _ = nextGraphemeEnd(s, 0);
        var words = wordBounds(s);
        while (words.next() != null) {}
        var lines = lineBreakOpportunities(s);
        while (lines.next() != null) {}
        _ = paragraphLevel(s, .auto);
        const lv = try baseLevels(alloc, s, .auto);
        defer alloc.free(lv);
        try std.testing.expectEqual(s.len, lv.len);

        var cps: std.ArrayList(CodePoint) = .empty;
        defer cps.deinit(alloc);
        var it = codepointIterator(s);
        while (it.next()) |c| try cps.append(alloc, c.value);
        try std.testing.expectEqual(s.len, cps.items.len);
    }
    try std.testing.expectEqual(@as(usize, 0), countGraphemes(""));
    var empty_lines = lineBreakOpportunities("");
    try std.testing.expect(empty_lines.next() == null);
    var empty_words = wordBounds("");
    try std.testing.expect(empty_words.next() == null);
    try std.testing.expectEqual(LEVEL_LTR, paragraphLevel("", .auto));
    var empty_paras = bidiParagraphs("", .auto);
    try std.testing.expect(empty_paras.next() == null);
}
