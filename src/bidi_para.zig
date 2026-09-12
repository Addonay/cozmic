//! Port of cosmic-text `bidi_para.rs` (paragraph iterator).
//!
//! Self-contained: no dependency on `unicode-bidi` yet. Implements the ASCII
//! fast path from cosmic-text (no control characters except `\n`, `\r`,
//! `\t`) plus the full `BidiClass::B` paragraph-separator set for complex
//! text: LF (`\n`), CR (`\r`), VT (`0x0B`), FF (`0x0C`), NEL (U+0085,
//! UTF-8 `C2 85`), PS (U+2029, UTF-8 `E2 80 A9`).
//! `\r\n` and `\n\r` are consumed as single separators (matching Rust
//! `LineIter` two-byte preference); lone `\r` splits like `BidiInfo`.
//! TODO(bidi): port per-paragraph embedding levels (`BidiInfo` analysis) for
//! complex text; separators are done, levels still default to LTR.

const std = @import("std");

/// Unicode BiDi embedding level, `u8`; even = LTR, odd = RTL.
pub const Level = u8;

/// LTR (default) embedding level, matching `unicode_bidi::Level::ltr()`.
pub fn ltrLevel() Level {
    return 0;
}

pub fn levelIsLtr(level: Level) bool {
    return level % 2 == 0;
}

/// Returns true when `text` qualifies for the ASCII fast path: pure ASCII
/// with no control characters except `\n`, `\r`, and `\t`.
pub fn isAsciiSimple(text: []const u8) bool {
    for (text) |b| {
        if (b < 0x80) {
            const is_control = (b < 0x20 or b == 0x7f);
            if (is_control and b != '\n' and b != '\r' and b != '\t') {
                return false;
            }
        } else {
            return false;
        }
    }
    return true;
}

/// Strip one trailing paragraph separator from a paragraph slice.
///
/// Callers split and consume separators, so this is a safety net for the
/// `\r` left behind by legacy `\n`-only splits plus the Unicode separators
/// a full `BidiInfo` port also strips. Only one separator is removed,
/// matching cosmic-text's single-`char_indices().next_back()` strip that
/// checks `BidiClass::B`.
fn stripTrailingSeparator(paragraph: []const u8) []const u8 {
    if (paragraph.len == 0) return paragraph;
    // Trailing CR from a CRLF split.
    if (paragraph[paragraph.len - 1] == '\r') {
        return paragraph[0 .. paragraph.len - 1];
    }
    // VT (0x0B) and FF (0x0C) paragraph separators.
    if (paragraph[paragraph.len - 1] == 0x0B or paragraph[paragraph.len - 1] == 0x0C) {
        return paragraph[0 .. paragraph.len - 1];
    }
    // U+0085 NEXT LINE (UTF-8: C2 85).
    if (paragraph.len >= 2 and
        paragraph[paragraph.len - 2] == 0xC2 and
        paragraph[paragraph.len - 1] == 0x85)
    {
        return paragraph[0 .. paragraph.len - 2];
    }
    // U+2029 PARAGRAPH SEPARATOR (UTF-8: E2 80 A9).
    if (paragraph.len >= 3 and
        paragraph[paragraph.len - 3] == 0xE2 and
        paragraph[paragraph.len - 2] == 0x80 and
        paragraph[paragraph.len - 1] == 0xA9)
    {
        return paragraph[0 .. paragraph.len - 3];
    }
    return paragraph;
}

/// Iterator over paragraphs in the input text.
///
/// Equivalent to `core::str::Lines` but follows `unicode-bidi` behaviour:
/// yields `[]const u8` slices with the trailing paragraph separator stripped.
/// An empty input yields zero paragraphs; a trailing newline does not produce
/// an extra empty paragraph; consecutive newlines yield empty paragraphs.
pub const BidiParagraphs = struct {
    text: []const u8,
    pos: usize,
    /// True when the input qualified for the ASCII fast path. Wired to choose
    /// the ASCII splitter vs the full `BidiClass::B` splitter below.
    fast_path: bool,

    pub fn init(text: []const u8) BidiParagraphs {
        return .{
            .text = text,
            .pos = 0,
            // No trailing empty paragraph when text ends with '\n':
            // iteration simply ends when pos reaches text.len.
            .fast_path = isAsciiSimple(text),
        };
    }

    pub fn next(self: *BidiParagraphs) ?[]const u8 {
        // Explicit branch: ASCII fast path vs full paragraph-separator path.
        // Both currently strip one trailing separator; only the separator set
        // differs (fast: CR/LF; full: CR/LF/VT/FF/NEL/PS).
        if (self.fast_path) {
            return self.nextAscii();
        } else {
            return self.nextFull();
        }
    }

    fn nextAscii(self: *BidiParagraphs) ?[]const u8 {
        if (self.pos >= self.text.len) return null;
        // Split on `\r` and `\n`, preferring `\r\n` / `\n\r` as single
        // separators (Rust `LineIter` preference). Lone `\r` splits too,
        // matching `BidiInfo` (Rust's ASCII fast path only splits `\n`; we
        // intentionally split lone `\r` as well to match `BidiInfo`).
        var i = self.pos;
        while (i < self.text.len) {
            const b = self.text[i];
            if (b == '\r' or b == '\n') {
                const paragraph = self.text[self.pos..i];
                // Two-byte preference: consume both bytes as one separator.
                if (b == '\r' and i + 1 < self.text.len and self.text[i + 1] == '\n') {
                    self.pos = i + 2;
                } else if (b == '\n' and i + 1 < self.text.len and self.text[i + 1] == '\r') {
                    self.pos = i + 2;
                } else {
                    self.pos = i + 1;
                }
                return stripTrailingSeparator(paragraph);
            }
            i += 1;
        }
        const paragraph = self.text[self.pos..];
        self.pos = self.text.len;
        return stripTrailingSeparator(paragraph);
    }

    fn nextFull(self: *BidiParagraphs) ?[]const u8 {
        if (self.pos >= self.text.len) return null;
        // Full `BidiClass::B` set: LF, CR, VT, FF, NEL, PS.
        // `\r\n` / `\n\r` consume both bytes as one separator.
        // Byte scanning stays on UTF-8 boundaries: ASCII separators never
        // appear inside multibyte sequences, and NEL/PS are matched as full
        // UTF-8 sequences.
        var i = self.pos;
        while (i < self.text.len) {
            const b = self.text[i];
            if (b == '\r' or b == '\n') {
                const paragraph = self.text[self.pos..i];
                if (b == '\r' and i + 1 < self.text.len and self.text[i + 1] == '\n') {
                    self.pos = i + 2;
                } else if (b == '\n' and i + 1 < self.text.len and self.text[i + 1] == '\r') {
                    self.pos = i + 2;
                } else {
                    self.pos = i + 1;
                }
                return stripTrailingSeparator(paragraph);
            } else if (b == 0x0B or b == 0x0C) {
                const paragraph = self.text[self.pos..i];
                self.pos = i + 1;
                return stripTrailingSeparator(paragraph);
            } else if (b == 0xC2 and i + 1 < self.text.len and self.text[i + 1] == 0x85) {
                const paragraph = self.text[self.pos..i];
                self.pos = i + 2;
                return stripTrailingSeparator(paragraph);
            } else if (b == 0xE2 and i + 2 < self.text.len and self.text[i + 1] == 0x80 and self.text[i + 2] == 0xA9) {
                const paragraph = self.text[self.pos..i];
                self.pos = i + 3;
                return stripTrailingSeparator(paragraph);
            }
            i += 1;
        }
        const paragraph = self.text[self.pos..];
        self.pos = self.text.len;
        return stripTrailingSeparator(paragraph);
    }
};

fn collectForTest(text: []const u8, out: [][]const u8) usize {
    var it = BidiParagraphs.init(text);
    var n: usize = 0;
    while (it.next()) |p| {
        if (n >= out.len) break;
        out[n] = p;
        n += 1;
    }
    return n;
}

test "empty text yields no paragraphs" {
    var it = BidiParagraphs.init("");
    try std.testing.expect(it.next() == null);
}

test "single line without newline" {
    var it = BidiParagraphs.init("hello");
    const p = it.next();
    try std.testing.expect(p != null);
    try std.testing.expectEqualStrings("hello", p.?);
    try std.testing.expect(it.next() == null);
}

test "trailing newline produces no extra paragraph" {
    var it = BidiParagraphs.init("a\n");
    try std.testing.expectEqualStrings("a", it.next().?);
    try std.testing.expect(it.next() == null);
}

test "consecutive newlines yield empty paragraphs" {
    var it = BidiParagraphs.init("a\n\nb");
    try std.testing.expectEqualStrings("a", it.next().?);
    try std.testing.expectEqualStrings("", it.next().?);
    try std.testing.expectEqualStrings("b", it.next().?);
    try std.testing.expect(it.next() == null);
}

test "CRLF strips trailing CR" {
    var it = BidiParagraphs.init("a\r\nb\r\n");
    try std.testing.expectEqualStrings("a", it.next().?);
    try std.testing.expectEqualStrings("b", it.next().?);
    try std.testing.expect(it.next() == null);
}

test "ascii fast path detection" {
    try std.testing.expect(BidiParagraphs.init("plain\ttabs\r\n").fast_path);
    try std.testing.expect(!BidiParagraphs.init("héllo").fast_path);
    try std.testing.expect(!BidiParagraphs.init("a\x01b").fast_path);
}

test "ltr level concept" {
    try std.testing.expectEqual(@as(Level, 0), ltrLevel());
    try std.testing.expect(levelIsLtr(0));
    try std.testing.expect(!levelIsLtr(1));
    try std.testing.expect(levelIsLtr(2));
}

test "lone CR splits paragraphs" {
    // ASCII fast path (contains only allowed controls) splits lone `\r`.
    var it = BidiParagraphs.init("a\rb\rc");
    try std.testing.expect(it.fast_path);
    try std.testing.expectEqualStrings("a", it.next().?);
    try std.testing.expectEqualStrings("b", it.next().?);
    try std.testing.expectEqualStrings("c", it.next().?);
    try std.testing.expect(it.next() == null);

    // Trailing lone CR produces no extra paragraph.
    var it2 = BidiParagraphs.init("a\r");
    try std.testing.expectEqualStrings("a", it2.next().?);
    try std.testing.expect(it2.next() == null);
}

test "CRLF and LFCR are single separators" {
    var buf: [8][]const u8 = undefined;
    // `\r\n` is one separator, not two.
    {
        var it = BidiParagraphs.init("a\r\nb");
        try std.testing.expectEqualStrings("a", it.next().?);
        try std.testing.expectEqualStrings("b", it.next().?);
        try std.testing.expect(it.next() == null);
    }
    // `\n\r` is one separator (LineIter preference).
    {
        var it = BidiParagraphs.init("a\n\rb");
        try std.testing.expectEqualStrings("a", it.next().?);
        try std.testing.expectEqualStrings("b", it.next().?);
        try std.testing.expect(it.next() == null);
    }
    _ = collectForTest("", &buf);
}

test "VT and FF split paragraphs (full path)" {
    // VT/FF are disallowed in the ASCII fast path, so these take `nextFull`.
    var it = BidiParagraphs.init("a\x0Bb\x0Cc");
    try std.testing.expect(!it.fast_path);
    try std.testing.expectEqualStrings("a", it.next().?);
    try std.testing.expectEqualStrings("b", it.next().?);
    try std.testing.expectEqualStrings("c", it.next().?);
    try std.testing.expect(it.next() == null);
}

test "NEL and PS split paragraphs (full path)" {
    // NEL U+0085 (C2 85), PS U+2029 (E2 80 A9).
    var it = BidiParagraphs.init("a\xc2\x85b\xe2\x80\xa9c");
    try std.testing.expect(!it.fast_path);
    try std.testing.expectEqualStrings("a", it.next().?);
    try std.testing.expectEqualStrings("b", it.next().?);
    try std.testing.expectEqualStrings("c", it.next().?);
    try std.testing.expect(it.next() == null);

    // Trailing NEL/PS produce no extra paragraph.
    var it2 = BidiParagraphs.init("a\xc2\x85");
    try std.testing.expectEqualStrings("a", it2.next().?);
    try std.testing.expect(it2.next() == null);
}

test "fast_path branches explicitly" {
    // Both paths produce the same result for plain `\n` text, but the branch
    // is explicit (`next` dispatches on `fast_path`).
    var ascii = BidiParagraphs.init("a\nb");
    try std.testing.expect(ascii.fast_path);
    try std.testing.expectEqualStrings("a", ascii.next().?);
    try std.testing.expectEqualStrings("b", ascii.next().?);

    var complex = BidiParagraphs.init("a\nb\xc3\xa9");
    try std.testing.expect(!complex.fast_path);
    try std.testing.expectEqualStrings("a", complex.next().?);
    try std.testing.expectEqualStrings("b\xc3\xa9", complex.next().?);
}
