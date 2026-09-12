//! Line ending detection and line iteration.
//!
//! Port of cosmic-text `line_ending.rs`. Self-contained; depends only on
//! `std`. All splitting happens on ASCII `\r`/`\n`, so byte indices stay on
//! UTF-8 boundaries.

const std = @import("std");

/// Line ending style. Tags use Zig snake_case; capitalized aliases mirror
/// the Rust `LineEnding::Variant` spelling.
pub const LineEnding = enum {
    lf,
    cr_lf,
    cr,
    lf_cr,
    none,

    /// Mirror of Rust's `LineEnding::Lf` spelling.
    pub const Lf: @This() = .lf;
    /// Mirror of Rust's `LineEnding::CrLf` spelling.
    pub const CrLf: @This() = .cr_lf;
    /// Mirror of Rust's `LineEnding::Cr` spelling.
    pub const Cr: @This() = .cr;
    /// Mirror of Rust's `LineEnding::LfCr` spelling.
    pub const LfCr: @This() = .lf_cr;
    /// Mirror of Rust's `LineEnding::None` spelling.
    pub const None: @This() = .none;

    /// Mirror of Rust's `#[default] Lf`.
    pub const default: @This() = .lf;

    /// The line ending as a string, matching Rust's `as_str`.
    pub fn asStr(self: LineEnding) []const u8 {
        return switch (self) {
            .lf => "\n",
            .cr_lf => "\r\n",
            .cr => "\r",
            .lf_cr => "\n\r",
            .none => "",
        };
    }

    /// Alias using Rust's snake_case spelling.
    pub fn as_str(self: LineEnding) []const u8 {
        return self.asStr();
    }
};

/// One iterated line: byte range of the content plus its terminator.
pub const Line = struct {
    start: usize,
    end: usize,
    ending: LineEnding,
};

/// Iterator over the lines of a string slice, splitting on `\r` and `\n`.
///
/// Two-byte sequences are preferred: `\r\n` yields a single `cr_lf` and
/// `\n\r` yields a single `lf_cr`. The final segment without a terminator
/// yields `none`. An empty string and a string ending in a terminator yield
/// no trailing empty line, matching the Rust `LineIter`.
pub const LineIter = struct {
    string: []const u8,
    pos: usize,

    /// Create an iterator over the lines of `string`.
    pub fn init(string: []const u8) LineIter {
        return .{ .string = string, .pos = 0 };
    }

    /// Return the next line, or `null` when exhausted.
    pub fn next(self: *LineIter) ?Line {
        const text = self.string;
        const start = self.pos;
        if (start >= text.len) return null;

        const rest = text[start..];
        const rel = std.mem.indexOfAny(u8, rest, "\r\n") orelse {
            self.pos = text.len;
            return .{ .start = start, .end = text.len, .ending = .none };
        };

        const end = start + rel;
        const after = text[end..];
        const ending: LineEnding = if (std.mem.startsWith(u8, after, "\r\n"))
            .cr_lf
        else if (std.mem.startsWith(u8, after, "\n\r"))
            .lf_cr
        else if (after[0] == '\n')
            .lf
        else
            .cr;
        self.pos = end + ending.asStr().len;
        return .{ .start = start, .end = end, .ending = ending };
    }
};

/// Collect up to `out.len` lines; fails the test on overflow instead of
/// silently dropping lines.
fn collectAll(text: []const u8, out: []Line) !usize {
    var it = LineIter.init(text);
    var n: usize = 0;
    while (it.next()) |line| {
        try std.testing.expect(n < out.len);
        out[n] = line;
        n += 1;
    }
    return n;
}

test "line ending strings" {
    const testing = std.testing;

    try testing.expectEqualStrings("\n", LineEnding.lf.asStr());
    try testing.expectEqualStrings("\r\n", LineEnding.cr_lf.asStr());
    try testing.expectEqualStrings("\r", LineEnding.cr.asStr());
    try testing.expectEqualStrings("\n\r", LineEnding.lf_cr.asStr());
    try testing.expectEqualStrings("", LineEnding.none.asStr());

    // Snake_case alias matches.
    try testing.expectEqualStrings(LineEnding.lf.asStr(), LineEnding.lf.as_str());
    try testing.expectEqualStrings(LineEnding.cr_lf.asStr(), LineEnding.cr_lf.as_str());

    // Capitalized aliases mirror the Rust spelling.
    try testing.expect(LineEnding.Lf == .lf);
    try testing.expect(LineEnding.CrLf == .cr_lf);
    try testing.expect(LineEnding.Cr == .cr);
    try testing.expect(LineEnding.LfCr == .lf_cr);
    try testing.expect(LineEnding.None == .none);
    try testing.expect(LineEnding.default == .lf);
}

test "line iter reference case" {
    const testing = std.testing;

    // Mirrors the Rust `test_line_iter`.
    var buf: [8]Line = undefined;
    const n = try collectAll("LF\nCRLF\r\nCR\rLFCR\n\rNONE", &buf);
    try testing.expectEqual(@as(usize, 5), n);

    try testing.expectEqual(@as(usize, 0), buf[0].start);
    try testing.expectEqual(@as(usize, 2), buf[0].end);
    try testing.expect(buf[0].ending == .lf);

    try testing.expectEqual(@as(usize, 3), buf[1].start);
    try testing.expectEqual(@as(usize, 7), buf[1].end);
    try testing.expect(buf[1].ending == .cr_lf);

    try testing.expectEqual(@as(usize, 9), buf[2].start);
    try testing.expectEqual(@as(usize, 11), buf[2].end);
    try testing.expect(buf[2].ending == .cr);

    try testing.expectEqual(@as(usize, 12), buf[3].start);
    try testing.expectEqual(@as(usize, 16), buf[3].end);
    try testing.expect(buf[3].ending == .lf_cr);

    try testing.expectEqual(@as(usize, 18), buf[4].start);
    try testing.expectEqual(@as(usize, 22), buf[4].end);
    try testing.expect(buf[4].ending == .none);
}

test "line iter edge cases" {
    const testing = std.testing;
    var buf: [8]Line = undefined;

    // Empty string yields nothing.
    try testing.expectEqual(@as(usize, 0), try collectAll("", &buf));

    // No terminator: single unterminated line.
    {
        const n = try collectAll("abc", &buf);
        try testing.expectEqual(@as(usize, 1), n);
        try testing.expectEqual(@as(usize, 0), buf[0].start);
        try testing.expectEqual(@as(usize, 3), buf[0].end);
        try testing.expect(buf[0].ending == .none);
    }

    // Trailing terminator leaves no empty tail.
    {
        const n = try collectAll("a\n", &buf);
        try testing.expectEqual(@as(usize, 1), n);
        try testing.expectEqual(@as(usize, 0), buf[0].start);
        try testing.expectEqual(@as(usize, 1), buf[0].end);
        try testing.expect(buf[0].ending == .lf);
    }

    // Lone terminators still report an (empty) line.
    {
        const n = try collectAll("\n", &buf);
        try testing.expectEqual(@as(usize, 1), n);
        try testing.expectEqual(@as(usize, 0), buf[0].start);
        try testing.expectEqual(@as(usize, 0), buf[0].end);
        try testing.expect(buf[0].ending == .lf);
    }
    {
        const n = try collectAll("\r\n", &buf);
        try testing.expectEqual(@as(usize, 1), n);
        try testing.expectEqual(@as(usize, 0), buf[0].start);
        try testing.expectEqual(@as(usize, 0), buf[0].end);
        try testing.expect(buf[0].ending == .cr_lf);
    }

    // Consecutive terminators produce empty lines but no trailing None.
    {
        const n = try collectAll("\n\n", &buf);
        try testing.expectEqual(@as(usize, 2), n);
        try testing.expect(buf[0].ending == .lf);
        try testing.expectEqual(buf[0].start, buf[0].end);
        try testing.expect(buf[1].ending == .lf);
        try testing.expectEqual(buf[1].start, buf[1].end);
    }
    {
        const n = try collectAll("a\n\nb", &buf);
        try testing.expectEqual(@as(usize, 3), n);
        try testing.expectEqual(@as(usize, 2), buf[1].start);
        try testing.expectEqual(@as(usize, 2), buf[1].end);
        try testing.expect(buf[1].ending == .lf);
        try testing.expectEqual(@as(usize, 3), buf[2].start);
        try testing.expectEqual(@as(usize, 4), buf[2].end);
        try testing.expect(buf[2].ending == .none);
    }

    // Mixed \r\n / \n\r runs prefer two-byte endings.
    {
        const n = try collectAll("\r\n\n\r", &buf);
        try testing.expectEqual(@as(usize, 2), n);
        try testing.expect(buf[0].ending == .cr_lf);
        try testing.expectEqual(@as(usize, 0), buf[0].end);
        try testing.expect(buf[1].ending == .lf_cr);
        try testing.expectEqual(@as(usize, 2), buf[1].start);
        try testing.expectEqual(@as(usize, 2), buf[1].end);
    }
    {
        // \r followed by \r\n: lone Cr, then CrLf (not Cr + Lf split).
        const n = try collectAll("\r\r\n", &buf);
        try testing.expectEqual(@as(usize, 2), n);
        try testing.expect(buf[0].ending == .cr);
        try testing.expectEqual(@as(usize, 0), buf[0].end);
        try testing.expect(buf[1].ending == .cr_lf);
        try testing.expectEqual(@as(usize, 1), buf[1].start);
        try testing.expectEqual(@as(usize, 1), buf[1].end);
    }
    {
        // \n followed by \n\r: lone Lf, then LfCr.
        const n = try collectAll("\n\n\r", &buf);
        try testing.expectEqual(@as(usize, 2), n);
        try testing.expect(buf[0].ending == .lf);
        try testing.expect(buf[1].ending == .lf_cr);
        try testing.expectEqual(@as(usize, 1), buf[1].start);
    }

    // Unterminated tail after a two-byte ending.
    {
        const n = try collectAll("a\r\nb", &buf);
        try testing.expectEqual(@as(usize, 2), n);
        try testing.expect(buf[0].ending == .cr_lf);
        try testing.expectEqual(@as(usize, 1), buf[0].end);
        try testing.expect(buf[1].ending == .none);
        try testing.expectEqualStrings("b", "a\r\nb"[buf[1].start..buf[1].end]);
    }
}

test "line iter multibyte content" {
    const testing = std.testing;
    var buf: [4]Line = undefined;

    const text = "héllo\nwörld";
    const n = try collectAll(text, &buf);
    try testing.expectEqual(@as(usize, 2), n);
    try testing.expectEqualStrings("héllo", text[buf[0].start..buf[0].end]);
    try testing.expect(buf[0].ending == .lf);
    try testing.expectEqualStrings("wörld", text[buf[1].start..buf[1].end]);
    try testing.expect(buf[1].ending == .none);
}

test "line iter exhaustion sticks" {
    const testing = std.testing;

    var it = LineIter.init("x");
    try testing.expect(it.next() != null);
    try testing.expect(it.next() == null);
    try testing.expect(it.next() == null);

    var empty = LineIter.init("");
    try testing.expect(empty.next() == null);
}
