//! Port of cosmic-text `edit/vi.rs` (vi modal editing) without `modit` /
//! `cosmic_undo_2` / `syntect` dependencies.
//!
//! Self-contained by design: defines minimal local `Cursor`, `Selection`,
//! `Change`/`ChangeItem`, `Action`/`Motion`, and `Editor` instead of importing
//! sibling cozmic modules (not yet unified). Unify these with the real
//! `edit.zig` / `buffer.zig` types later; keep this file compiling standalone
//! until then.
//! TODO(unify): replace local `Editor`/`Cursor`/`Selection`/`Change` with
//! `edit.zig` imports once cross-file unification lands.
//!
//! Divergence from the oracle:
//!   * `modit::ViParser` is reimplemented here (`ViParser`) with the same
//!     observable modes (`Normal`/`Insert`/`Visual`/`Replace`), operators
//!     (`Yank`/`Delete`/`Change`), counts, registers (`"` prefix), `f`/`t`
//!     find motions, `/`/`?` search input, and `i`/`a` text objects. Edge
//!     cases (counts on `f`/`t`, `r` single-replace, `.` repeat, `:` ex)
//!     are TODO.
//!   * `cosmic_undo_2::Commands<Change>` is reimplemented as `UndoStack`
//!     (two `ArrayList(Change)` past/future stacks) with identical
//!     `save_point` / `eval_changed` semantics.
//!   * The inner editor is a gap-less `ArrayList(Line)` buffer (UTF-8 lines
//!     split on `\n`); the oracle wraps `SyntaxEditor`/`Buffer`. Line endings
//!     beyond `\n` are not preserved (TODO).
//!   * `ScreenHigh`/`Middle`/`Low` use buffer first/middle/last lines (the
//!     oracle uses visible `layout_runs`; no scrolling here).
//!   * `Replace` currently inserts (no overstrike); `TODO(vi)`.
//!
//! Feature gating: the parent build wires `build_options.vi`. This file must
//! also compile via `zig test src/vi.zig` without that module, so it exposes
//! a plain constant instead of importing `build_options`.
//! TODO(vi): wire `build_options.vi` in the parent and gate `ViEditor` on it.
//! Until then `vi_enabled` is always `false`.

const std = @import("std");

const Allocator = std.mem.Allocator;

/// Compile-time feature flag placeholder (see module docs).
pub const vi_enabled: bool = false;

pub const Error = Allocator.Error || error{
    InvalidCursor,
    InvalidByteIndex,
    ChangeInProgress,
    InvalidData,
};

// ---------------------------------------------------------------------------
// Minimal local aliases (unify with edit.zig later)
// ---------------------------------------------------------------------------

pub const Affinity = enum { before, after };

pub const Cursor = struct {
    line: usize = 0,
    index: usize = 0,
    affinity: Affinity = .before,

    pub fn init(line: usize, index: usize) Cursor {
        return .{ .line = line, .index = index, .affinity = .before };
    }

    pub fn order(a: Cursor, b: Cursor) std.math.Order {
        if (a.line != b.line) return std.math.order(a.line, b.line);
        return std.math.order(a.index, b.index);
    }
};

pub const Selection = union(enum) {
    none: void,
    normal: Cursor,
    line: Cursor,
    word: Cursor,

    pub fn eql(a: Selection, b: Selection) bool {
        return std.meta.eql(a, b);
    }
};

pub const SelectionBounds = struct { start: Cursor, end: Cursor };

pub const ChangeItem = struct {
    start: Cursor,
    end: Cursor,
    text: std.ArrayList(u8),
    insert: bool,

    pub fn deinit(self: *ChangeItem, allocator: Allocator) void {
        self.text.deinit(allocator);
        self.* = undefined;
    }

    pub fn clone(self: *const ChangeItem, allocator: Allocator) Allocator.Error!ChangeItem {
        var text: std.ArrayList(u8) = .empty;
        errdefer text.deinit(allocator);
        try text.appendSlice(allocator, self.text.items);
        return .{ .start = self.start, .end = self.end, .text = text, .insert = self.insert };
    }

    pub fn reverse(self: *ChangeItem) void {
        self.insert = !self.insert;
    }
};

pub const Change = struct {
    items: std.ArrayList(ChangeItem),

    pub fn init() Change {
        return .{ .items = .empty };
    }

    pub fn deinit(self: *Change, allocator: Allocator) void {
        for (self.items.items) |*it| it.deinit(allocator);
        self.items.deinit(allocator);
        self.* = undefined;
    }

    pub fn clone(self: *const Change, allocator: Allocator) Allocator.Error!Change {
        var out: std.ArrayList(ChangeItem) = .empty;
        errdefer {
            for (out.items) |*it| it.deinit(allocator);
            out.deinit(allocator);
        }
        for (self.items.items) |*it| try out.append(allocator, try it.clone(allocator));
        return .{ .items = out };
    }

    pub fn reverse(self: *Change) void {
        std.mem.reverse(ChangeItem, self.items.items);
        for (self.items.items) |*it| it.reverse();
    }

    pub fn isEmpty(self: *const Change) bool {
        return self.items.items.len == 0;
    }
};

/// Motions supported by the local editor (subset of `edit.zig` Motion used
/// by vi: basic cursor motions plus `goto_line`).
pub const Motion = union(enum) {
    left,
    right,
    up,
    down,
    home,
    soft_home,
    end,
    page_up,
    page_down,
    goto_line: usize,
    buffer_start,
    buffer_end,
};

pub const MotionResult = struct { cursor: Cursor, x_opt: ?i32 };

pub const Action = union(enum) {
    motion: Motion,
    escape: void,
    insert: u21,
    enter: void,
    backspace: void,
    delete: void,
    indent: void,
    unindent: void,
    click: struct { x: i32, y: i32 },
    double_click: struct { x: i32, y: i32 },
    triple_click: struct { x: i32, y: i32 },
    drag: struct { x: i32, y: i32 },
    scroll: struct { pixels: f32 },
};

// ---------------------------------------------------------------------------
// UTF-8 / word helpers (codepoint-granular, mirrors edit.zig)
// ---------------------------------------------------------------------------

pub fn cpLen(first_byte: u8) usize {
    const l: u3 = std.unicode.utf8ByteSequenceLength(first_byte) catch return 1;
    return @as(usize, l);
}

pub fn isContinuation(b: u8) bool {
    return (b & 0xC0) == 0x80;
}

pub fn isBoundary(text: []const u8, index: usize) bool {
    if (index == 0 or index == text.len) return true;
    if (index > text.len) return false;
    return !isContinuation(text[index]);
}

pub fn prevCharStart(text: []const u8, index: usize) usize {
    var i = @min(index, text.len);
    if (i == 0) return 0;
    i -= 1;
    while (i > 0 and isContinuation(text[i])) : (i -= 1) {}
    return i;
}

pub fn nextCharEnd(text: []const u8, index: usize) usize {
    if (index >= text.len) return text.len;
    return @min(index + cpLen(text[index]), text.len);
}

fn decodeAt(text: []const u8, index: usize) ?u21 {
    if (index >= text.len) return null;
    const len = @min(cpLen(text[index]), text.len - index);
    return std.unicode.utf8Decode(text[index .. index + len]) catch null;
}

pub fn isWordChar(cp: u21) bool {
    if (cp < 0x80) {
        return (cp >= 'A' and cp <= 'Z') or (cp >= 'a' and cp <= 'z') or
            (cp >= '0' and cp <= '9') or cp == '_';
    }
    return true;
}

fn isBlankCp(cp: u21) bool {
    return cp == ' ' or cp == '\t' or cp == '\n' or cp == '\r';
}

fn charIsWord(text: []const u8, index: usize, big: bool) bool {
    const cp = decodeAt(text, index) orelse return false;
    if (big) return !isBlankCp(cp);
    return isWordChar(cp);
}

/// Word kinds: `small` (`w`/`b`/`e`, word chars + punctuation runs) vs `big`
/// (`W`/`B`/`E`, whitespace-delimited WORDS).
pub const WordKind = enum { small, big };

fn sameWordClass(text: []const u8, a: usize, b: usize, big: bool) bool {
    if (big) {
        const ca = decodeAt(text, a) orelse return false;
        const cb = decodeAt(text, b) orelse return false;
        return !isBlankCp(ca) == !isBlankCp(cb);
    }
    const wa = charIsWord(text, a, false);
    const wb = charIsWord(text, b, false);
    if (wa != wb) return false;
    // Both word chars: same class. Both non-word non-blank: same class
    // unless one is blank (blank always breaks).
    if (wa) return true;
    const ca = decodeAt(text, a) orelse return false;
    const cb = decodeAt(text, b) orelse return false;
    if (isBlankCp(ca) or isBlankCp(cb)) return false;
    return true;
}

fn skipBlankForward(text: []const u8, i: usize) usize {
    var j = i;
    while (j < text.len) {
        const cp = decodeAt(text, j) orelse break;
        if (!isBlankCp(cp)) break;
        j = nextCharEnd(text, j);
    }
    return j;
}

fn skipBlankBackward(text: []const u8, i: usize) usize {
    var j = i;
    while (j > 0) {
        const s = prevCharStart(text, j);
        const cp = decodeAt(text, s) orelse break;
        if (!isBlankCp(cp)) break;
        j = s;
    }
    return j;
}

/// Start of the next word after `index` (single line, saturates to len).
pub fn nextWordStartInLine(text: []const u8, index: usize, kind: WordKind) usize {
    const big = kind == .big;
    if (index >= text.len) return text.len;
    var i = index;
    // If inside a word, skip to its end first.
    if (i < text.len and charIsWord(text, i, big)) {
        while (i < text.len and charIsWord(text, i, big)) i = nextCharEnd(text, i);
        // For small words, punctuation runs count: skip same-class run.
        if (!big) {
            while (i < text.len) {
                const cp = decodeAt(text, i) orelse break;
                if (isBlankCp(cp) or isWordChar(cp)) break;
                // punctuation run: skip it as part of current word
                var j = i;
                while (j < text.len) {
                    const cj = decodeAt(text, j) orelse break;
                    if (isBlankCp(cj) or isWordChar(cj)) break;
                    j = nextCharEnd(text, j);
                }
                i = j;
                break;
            }
        }
    } else if (i < text.len and !big) {
        const cp = decodeAt(text, i) orelse return skipBlankForward(text, i);
        if (!isBlankCp(cp) and !isWordChar(cp)) {
            while (i < text.len) {
                const cj = decodeAt(text, i) orelse break;
                if (isBlankCp(cj) or isWordChar(cj)) break;
                i = nextCharEnd(text, i);
            }
        }
    }
    i = skipBlankForward(text, i);
    return i;
}

/// End (last byte offset, exclusive like reference `i + w.len` end) of the
/// next word ending after `index`.
pub fn nextWordEndInLine(text: []const u8, index: usize, kind: WordKind) usize {
    const big = kind == .big;
    var i = nextCharEnd(text, index);
    i = skipBlankForward(text, i);
    if (i >= text.len) return text.len;
    // Scan to end of this word run.
    if (big) {
        while (i < text.len and charIsWord(text, i, true)) i = nextCharEnd(text, i);
        return i;
    }
    if (isWordChar(decodeAt(text, i) orelse 0)) {
        while (i < text.len) {
            const cp = decodeAt(text, i) orelse break;
            if (!isWordChar(cp)) break;
            i = nextCharEnd(text, i);
        }
        return i;
    }
    const cp0 = decodeAt(text, i) orelse return text.len;
    if (isBlankCp(cp0)) return skipBlankForward(text, i);
    while (i < text.len) {
        const cp = decodeAt(text, i) orelse break;
        if (isBlankCp(cp) or isWordChar(cp)) break;
        i = nextCharEnd(text, i);
    }
    return i;
}

pub fn prevWordStartInLine(text: []const u8, index: usize, kind: WordKind) usize {
    const big = kind == .big;
    if (index == 0) return 0;
    var i = index;
    // Skip blanks backward first (but not past 0).
    i = skipBlankBackward(text, i);
    if (i == 0) return 0;
    // Step one char back into a word, then to its start.
    i = prevCharStart(text, i);
    if (big) {
        while (i > 0) {
            const p = prevCharStart(text, i);
            if (!charIsWord(text, p, true)) break;
            i = p;
        }
        return i;
    }
    const cp = decodeAt(text, i) orelse return 0;
    if (isWordChar(cp)) {
        while (i > 0) {
            const p = prevCharStart(text, i);
            const c = decodeAt(text, p) orelse break;
            if (!isWordChar(c)) break;
            i = p;
        }
        return i;
    }
    if (isBlankCp(cp)) return skipBlankBackward(text, i);
    while (i > 0) {
        const p = prevCharStart(text, i);
        const c = decodeAt(text, p) orelse break;
        if (isBlankCp(c) or isWordChar(c)) break;
        i = p;
    }
    return i;
}

pub fn prevWordEndInLine(text: []const u8, index: usize, kind: WordKind) usize {
    if (index == 0) return 0;
    // Collect word runs and pick the last exclusive end strictly before
    // `index`; return its last-char start (vim `ge` lands on the char).
    var last_start: usize = 0;
    var found = false;
    var pos: usize = 0;
    while (pos < text.len) {
        pos = skipBlankForward(text, pos);
        if (pos >= text.len) break;
        const s = pos;
        var e: usize = s;
        if (kind == .big) {
            while (e < text.len and charIsWord(text, e, true)) e = nextCharEnd(text, e);
        } else {
            const cp = decodeAt(text, e) orelse break;
            if (isWordChar(cp)) {
                while (e < text.len) {
                    const c = decodeAt(text, e) orelse break;
                    if (!isWordChar(c)) break;
                    e = nextCharEnd(text, e);
                }
            } else if (!isBlankCp(cp)) {
                while (e < text.len) {
                    const c = decodeAt(text, e) orelse break;
                    if (isBlankCp(c) or isWordChar(c)) break;
                    e = nextCharEnd(text, e);
                }
            } else break;
        }
        if (e <= s) break;
        if (e < index) {
            last_start = prevCharStart(text, e);
            found = true;
        } else break;
        pos = e;
    }
    return if (found) last_start else 0;
}

/// Bounds of the word under `index` (single line). Null when out of range.
pub fn wordBoundsAt(text: []const u8, index: usize, kind: WordKind) ?struct { start: usize, end: usize } {
    if (text.len == 0) return null;
    const at = @min(index, text.len -| 1);
    if (at >= text.len) return null;
    const big = kind == .big;
    const cp = decodeAt(text, at) orelse return null;
    if (isBlankCp(cp)) return null;
    var s = at;
    var e = nextCharEnd(text, at);
    if (big) {
        while (s > 0 and charIsWord(text, prevCharStart(text, s), true)) s = prevCharStart(text, s);
        while (e < text.len and charIsWord(text, e, true)) e = nextCharEnd(text, e);
        return .{ .start = s, .end = e };
    }
    if (isWordChar(cp)) {
        while (s > 0) {
            const p = prevCharStart(text, s);
            const c = decodeAt(text, p) orelse break;
            if (!isWordChar(c)) break;
            s = p;
        }
        while (e < text.len) {
            const c = decodeAt(text, e) orelse break;
            if (!isWordChar(c)) break;
            e = nextCharEnd(text, e);
        }
        return .{ .start = s, .end = e };
    }
    while (s > 0) {
        const p = prevCharStart(text, s);
        const c = decodeAt(text, p) orelse break;
        if (isBlankCp(c) or isWordChar(c)) break;
        s = p;
    }
    while (e < text.len) {
        const c = decodeAt(text, e) orelse break;
        if (isBlankCp(c) or isWordChar(c)) break;
        e = nextCharEnd(text, e);
    }
    return .{ .start = s, .end = e };
}

pub fn firstNonWhitespace(text: []const u8) usize {
    var pos: usize = 0;
    while (pos < text.len) {
        const len = @min(cpLen(text[pos]), text.len - pos);
        const cp = std.unicode.utf8Decode(text[pos .. pos + len]) catch {
            pos += 1;
            continue;
        };
        const blank = switch (cp) {
            0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x20, 0x85, 0xA0 => true,
            else => false,
        };
        if (!blank) return pos;
        pos += len;
    }
    return 0;
}

// ---------------------------------------------------------------------------
// Local minimal editor (ArrayList lines; unify with edit.zig later)
// ---------------------------------------------------------------------------

pub const Line = struct {
    text: std.ArrayList(u8),

    pub fn deinit(self: *Line, allocator: Allocator) void {
        self.text.deinit(allocator);
        self.* = undefined;
    }

    pub fn slice(self: *const Line) []const u8 {
        return self.text.items;
    }
};

pub const Editor = struct {
    allocator: Allocator,
    lines: std.ArrayList(Line),
    cursor: Cursor,
    cursor_x_opt: ?i32,
    selection: Selection,
    change: ?Change,

    pub fn init(allocator: Allocator) Allocator.Error!Editor {
        var self = Editor{
            .allocator = allocator,
            .lines = .empty,
            .cursor = .{},
            .cursor_x_opt = null,
            .selection = .{ .none = {} },
            .change = null,
        };
        errdefer self.deinit();
        try self.lines.append(allocator, .{ .text = .empty });
        return self;
    }

    pub fn deinit(self: *Editor) void {
        for (self.lines.items) |*l| l.deinit(self.allocator);
        self.lines.deinit(self.allocator);
        if (self.change) |*c| c.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn lineCount(self: *const Editor) usize {
        return self.lines.items.len;
    }

    pub fn lineSlice(self: *const Editor, line: usize) []const u8 {
        if (line >= self.lines.items.len) return "";
        return self.lines.items[line].slice();
    }

    pub fn setText(self: *Editor, text: []const u8) Allocator.Error!void {
        for (self.lines.items) |*l| l.deinit(self.allocator);
        self.lines.clearRetainingCapacity();
        var start: usize = 0;
        for (text, 0..) |b, i| {
            if (b == '\n') {
                var l = Line{ .text = .empty };
                errdefer l.deinit(self.allocator);
                try l.text.appendSlice(self.allocator, text[start..i]);
                try self.lines.append(self.allocator, l);
                start = i + 1;
            }
        }
        var last = Line{ .text = .empty };
        errdefer last.deinit(self.allocator);
        try last.text.appendSlice(self.allocator, text[start..]);
        try self.lines.append(self.allocator, last);
        if (self.lines.items.len == 0) try self.lines.append(self.allocator, .{ .text = .empty });
        self.cursor = .{};
        self.selection = .{ .none = {} };
        self.cursor_x_opt = null;
        if (self.change) |*c| {
            c.deinit(self.allocator);
            self.change = null;
        }
    }

    pub fn fullText(self: *const Editor) Allocator.Error!std.ArrayList(u8) {
        var out: std.ArrayList(u8) = .empty;
        errdefer out.deinit(self.allocator);
        for (self.lines.items, 0..) |*l, i| {
            if (i > 0) try out.append(self.allocator, '\n');
            try out.appendSlice(self.allocator, l.slice());
        }
        return out;
    }

    pub fn selectionBounds(self: *const Editor) ?SelectionBounds {
        const cur = self.cursor;
        switch (self.selection) {
            .none => return null,
            .normal => |sel| {
                return switch (Cursor.order(sel, cur)) {
                    .gt => .{ .start = cur, .end = sel },
                    else => .{ .start = sel, .end = cur },
                };
            },
            .line => |sel| {
                const s = @min(sel.line, cur.line);
                const e = @max(sel.line, cur.line);
                if (e >= self.lines.items.len) return null;
                return .{
                    .start = Cursor.init(s, 0),
                    .end = Cursor.init(e, self.lines.items[e].slice().len),
                };
            },
            .word => |sel| {
                var start: Cursor = undefined;
                var end: Cursor = undefined;
                switch (Cursor.order(sel, cur)) {
                    .gt => {
                        start = cur;
                        end = sel;
                    },
                    else => {
                        start = sel;
                        end = cur;
                    },
                }
                if (start.line >= self.lines.items.len) return null;
                if (end.line >= self.lines.items.len) return null;
                // Expand to word boundaries (small words).
                const stext = self.lines.items[start.line].slice();
                const etext = self.lines.items[end.line].slice();
                start.index = prevWordStartInLine(stext, start.index, .small);
                end.index = nextWordEndInLine(etext, end.index, .small);
                return .{ .start = start, .end = end };
            },
        }
    }

    fn recordDelete(self: *Editor, start: Cursor, end: Cursor, text: std.ArrayList(u8)) Allocator.Error!void {
        if (self.change) |*c| {
            try c.items.append(self.allocator, .{ .start = start, .end = end, .text = text, .insert = false });
        } else {
            var owned = text;
            owned.deinit(self.allocator);
        }
    }

    fn recordInsert(self: *Editor, start: Cursor, end: Cursor, data: []const u8) Allocator.Error!void {
        if (self.change) |*c| {
            var owned: std.ArrayList(u8) = .empty;
            errdefer owned.deinit(self.allocator);
            try owned.appendSlice(self.allocator, data);
            try c.items.append(self.allocator, .{ .start = start, .end = end, .text = owned, .insert = true });
        }
    }

    fn clampCursor(self: *const Editor, c: Cursor) Cursor {
        if (self.lines.items.len == 0) return Cursor.init(0, 0);
        const line = @min(c.line, self.lines.items.len - 1);
        const len = self.lines.items[line].slice().len;
        return Cursor.init(line, @min(c.index, len));
    }

    pub fn deleteRange(self: *Editor, start_in: Cursor, end_in: Cursor) Error!void {
        var start = start_in;
        var end = end_in;
        if (Cursor.order(start, end) == .gt) {
            const t = start;
            start = end;
            end = t;
        }
        if (start.line >= self.lines.items.len) return error.InvalidCursor;
        if (end.line >= self.lines.items.len) return error.InvalidCursor;
        if (start.index > self.lines.items[start.line].slice().len) return error.InvalidCursor;
        if (end.index > self.lines.items[end.line].slice().len) return error.InvalidCursor;
        if (!isBoundary(self.lines.items[start.line].slice(), start.index)) return error.InvalidByteIndex;
        if (!isBoundary(self.lines.items[end.line].slice(), end.index)) return error.InvalidByteIndex;

        // Assemble undo text (removed texts joined by \n).
        var text: std.ArrayList(u8) = .empty;
        errdefer text.deinit(self.allocator);
        if (start.line == end.line) {
            const l = self.lines.items[start.line].slice();
            try text.appendSlice(self.allocator, l[start.index..end.index]);
            try self.lines.items[start.line].text.replaceRange(self.allocator, start.index, end.index - start.index, "");
        } else {
            const first = self.lines.items[start.line].slice();
            const last = self.lines.items[end.line].slice();
            try text.appendSlice(self.allocator, first[start.index..]);
            var li = start.line + 1;
            while (li < end.line) : (li += 1) {
                try text.append(self.allocator, '\n');
                try text.appendSlice(self.allocator, self.lines.items[li].slice());
            }
            try text.append(self.allocator, '\n');
            try text.appendSlice(self.allocator, last[0..end.index]);
            // Join: truncate start line, append tail of end line, remove middle+end.
            self.lines.items[start.line].text.shrinkRetainingCapacity(start.index);
            try self.lines.items[start.line].text.appendSlice(self.allocator, last[end.index..]);
            var k = end.line;
            while (k > start.line) : (k -= 1) {
                var removed = self.lines.orderedRemove(k);
                removed.deinit(self.allocator);
            }
        }
        try self.recordDelete(start, end, text);
        self.cursor = start;
        self.cursor_x_opt = null;
    }

    pub fn insertAt(self: *Editor, cursor_in: Cursor, data: []const u8) Error!Cursor {
        if (data.len == 0) return self.clampCursor(cursor_in);
        var cursor = self.clampCursor(cursor_in);
        if (!isBoundary(self.lines.items[cursor.line].slice(), cursor.index)) return error.InvalidByteIndex;
        const start = cursor;
        // Split current line tail.
        const tail = try self.allocator.dupe(u8, self.lines.items[cursor.line].slice()[cursor.index..]);
        defer self.allocator.free(tail);
        self.lines.items[cursor.line].text.shrinkRetainingCapacity(cursor.index);
        // Split data on \n.
        var parts: std.ArrayList([]const u8) = .empty;
        defer parts.deinit(self.allocator);
        var s: usize = 0;
        for (data, 0..) |b, i| {
            if (b == '\n') {
                try parts.append(self.allocator, data[s..i]);
                s = i + 1;
            }
        }
        try parts.append(self.allocator, data[s..]);
        // First part joins current line.
        try self.lines.items[cursor.line].text.appendSlice(self.allocator, parts.items[0]);
        // Middle/last parts insert new lines.
        var li = cursor.line;
        var idx: usize = 1;
        while (idx < parts.items.len) : (idx += 1) {
            var nl = Line{ .text = .empty };
            errdefer nl.deinit(self.allocator);
            try nl.text.appendSlice(self.allocator, parts.items[idx]);
            try self.lines.insert(self.allocator, li + 1, nl);
            li += 1;
        }
        // Rejoin tail onto last inserted line.
        try self.lines.items[li].text.appendSlice(self.allocator, tail);
        cursor.line = li;
        cursor.index = self.lines.items[li].slice().len - tail.len;
        try self.recordInsert(start, cursor, data);
        return cursor;
    }

    pub fn copySelection(self: *const Editor) Error!?std.ArrayList(u8) {
        const b = self.selectionBounds() orelse return null;
        var out: std.ArrayList(u8) = .empty;
        errdefer out.deinit(self.allocator);
        if (b.start.line == b.end.line) {
            try out.appendSlice(self.allocator, self.lines.items[b.start.line].slice()[b.start.index..b.end.index]);
        } else {
            try out.appendSlice(self.allocator, self.lines.items[b.start.line].slice()[b.start.index..]);
            try out.append(self.allocator, '\n');
            var li = b.start.line + 1;
            while (li < b.end.line) : (li += 1) {
                try out.appendSlice(self.allocator, self.lines.items[li].slice());
                try out.append(self.allocator, '\n');
            }
            try out.appendSlice(self.allocator, self.lines.items[b.end.line].slice()[0..b.end.index]);
        }
        return out;
    }

    pub fn deleteSelection(self: *Editor) Error!bool {
        const b = self.selectionBounds() orelse return false;
        self.cursor = b.start;
        self.selection = .{ .none = {} };
        try self.deleteRange(b.start, b.end);
        return true;
    }

    pub fn insertString(self: *Editor, data: []const u8) Error!void {
        _ = try self.deleteSelection();
        self.cursor = try self.insertAt(self.cursor, data);
    }

    pub fn applyChange(self: *Editor, change: *const Change) Error!bool {
        if (self.change) |pending| {
            if (pending.items.items.len > 0) return false;
            var drop = pending;
            drop.deinit(self.allocator);
            self.change = null;
        }
        for (change.items.items) |*it| {
            if (it.insert) {
                self.cursor = try self.insertAt(it.start, it.text.items);
            } else {
                self.cursor = it.start;
                try self.deleteRange(it.start, it.end);
            }
        }
        return true;
    }

    pub fn startChange(self: *Editor) void {
        if (self.change == null) self.change = Change.init();
    }

    pub fn finishChange(self: *Editor) ?Change {
        if (self.change) |c| {
            self.change = null;
            return c;
        }
        return null;
    }

    pub fn motionCursor(self: *const Editor, cursor: Cursor, x_opt: ?i32, motion: Motion) ?MotionResult {
        if (self.lines.items.len == 0) return null;
        var cur = self.clampCursor(cursor);
        var x = x_opt;
        switch (motion) {
            .left => {
                const t = self.lines.items[cur.line].slice();
                if (cur.index > 0) {
                    cur.index = prevCharStart(t, cur.index);
                } else if (cur.line > 0) {
                    cur.line -= 1;
                    cur.index = self.lines.items[cur.line].slice().len;
                }
                x = null;
            },
            .right => {
                const t = self.lines.items[cur.line].slice();
                if (cur.index < t.len) {
                    cur.index = nextCharEnd(t, cur.index);
                } else if (cur.line + 1 < self.lines.items.len) {
                    cur.line += 1;
                    cur.index = 0;
                }
                x = null;
            },
            .up => {
                if (x == null) x = @intCast(@min(cur.index, std.math.maxInt(i32)));
                if (cur.line > 0) {
                    cur.line -= 1;
                    cur.index = @min(@as(usize, @intCast(@max(x.?, 0))), self.lines.items[cur.line].slice().len);
                    while (!isBoundary(self.lines.items[cur.line].slice(), cur.index) and cur.index > 0) cur.index -= 1;
                }
            },
            .down => {
                if (x == null) x = @intCast(@min(cur.index, std.math.maxInt(i32)));
                if (cur.line + 1 < self.lines.items.len) {
                    cur.line += 1;
                    cur.index = @min(@as(usize, @intCast(@max(x.?, 0))), self.lines.items[cur.line].slice().len);
                    while (!isBoundary(self.lines.items[cur.line].slice(), cur.index) and cur.index > 0) cur.index -= 1;
                }
            },
            .home => {
                cur.index = 0;
                x = null;
            },
            .soft_home => {
                cur.index = firstNonWhitespace(self.lines.items[cur.line].slice());
                x = null;
            },
            .end => {
                cur.index = self.lines.items[cur.line].slice().len;
                x = null;
            },
            .page_up => {
                if (x == null) x = @intCast(@min(cur.index, std.math.maxInt(i32)));
                const want: usize = @intCast(@max(x.?, 0));
                cur.line -|= @min(cur.line, 10);
                cur.index = @min(want, self.lines.items[cur.line].slice().len);
            },
            .page_down => {
                if (x == null) x = @intCast(@min(cur.index, std.math.maxInt(i32)));
                const want: usize = @intCast(@max(x.?, 0));
                cur.line = @min(cur.line + 10, self.lines.items.len - 1);
                cur.index = @min(want, self.lines.items[cur.line].slice().len);
            },
            .goto_line => |goal| {
                cur.line = @min(goal, self.lines.items.len - 1);
                cur.index = @min(cur.index, self.lines.items[cur.line].slice().len);
            },
            .buffer_start => {
                cur.line = 0;
                cur.index = 0;
                x = null;
            },
            .buffer_end => {
                cur.line = self.lines.items.len - 1;
                cur.index = self.lines.items[cur.line].slice().len;
                x = null;
            },
        }
        return .{ .cursor = cur, .x_opt = x };
    }

    fn isControl(cp: u21) bool {
        return cp < 0x20 or (cp >= 0x7F and cp <= 0x9F);
    }

    pub fn action(self: *Editor, act: Action) Error!void {
        switch (act) {
            .motion => |m| {
                if (self.motionCursor(self.cursor, self.cursor_x_opt, m)) |r| {
                    self.cursor = r.cursor;
                    self.cursor_x_opt = r.x_opt;
                }
            },
            .escape => {
                self.selection = .{ .none = {} };
            },
            .insert => |cp| {
                if (isControl(cp) and cp != '\t' and cp != '\n') return;
                if (cp == '\n') {
                    try self.action(.{ .enter = {} });
                    return;
                }
                var buf: [4]u8 = undefined;
                const len = std.unicode.utf8Encode(cp, &buf) catch return;
                try self.insertString(buf[0..len]);
            },
            .enter => {
                try self.insertString("\n");
            },
            .backspace => {
                if (!(try self.deleteSelection())) {
                    const end = self.cursor;
                    if (self.cursor.index > 0) {
                        self.cursor.index = prevCharStart(self.lines.items[self.cursor.line].slice(), self.cursor.index);
                    } else if (self.cursor.line > 0) {
                        self.cursor.line -= 1;
                        self.cursor.index = self.lines.items[self.cursor.line].slice().len;
                    }
                    if (!std.meta.eql(self.cursor, end)) try self.deleteRange(self.cursor, end);
                }
            },
            .delete => {
                if (!(try self.deleteSelection())) {
                    const start = self.cursor;
                    var end = self.cursor;
                    const t = self.lines.items[start.line].slice();
                    if (start.index < t.len) {
                        end.index = nextCharEnd(t, start.index);
                    } else if (start.line + 1 < self.lines.items.len) {
                        end.line += 1;
                        end.index = 0;
                    }
                    if (!std.meta.eql(start, end)) try self.deleteRange(start, end);
                }
            },
            .indent => {
                const at = Cursor.init(self.cursor.line, 0);
                _ = try self.insertAt(at, "    ");
                self.cursor.index += 4;
            },
            .unindent => {
                const t = self.lines.items[self.cursor.line].slice();
                var n: usize = 0;
                while (n < t.len and n < 4 and t[n] == ' ') : (n += 1) {}
                if (n > 0) try self.deleteRange(Cursor.init(self.cursor.line, 0), Cursor.init(self.cursor.line, n));
            },
            .click, .double_click, .triple_click, .drag => {},
            .scroll => {},
        }
    }
};

// ---------------------------------------------------------------------------
// Undo stack (cosmic_undo_2 Commands<Change> parity)
// ---------------------------------------------------------------------------

/// Evaluate `changed` from the current command index vs the save pivot,
/// matching `vi.rs::eval_changed`.
pub fn evalChanged(current: ?usize, pivot: ?usize) bool {
    if (current != null and pivot != null) return current.? != pivot.?;
    if (current == null and pivot == null) return false;
    return true;
}

pub const UndoStack = struct {
    allocator: Allocator,
    past: std.ArrayList(Change),
    future: std.ArrayList(Change),

    pub fn init(allocator: Allocator) UndoStack {
        return .{ .allocator = allocator, .past = .empty, .future = .empty };
    }

    pub fn deinit(self: *UndoStack) void {
        for (self.past.items) |*c| c.deinit(self.allocator);
        self.past.deinit(self.allocator);
        for (self.future.items) |*c| c.deinit(self.allocator);
        self.future.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn currentCommandIndex(self: *const UndoStack) ?usize {
        if (self.past.items.len == 0 and self.future.items.len == 0) return null;
        return self.past.items.len;
    }

    pub fn push(self: *UndoStack, change: *const Change) Allocator.Error!void {
        if (change.isEmpty()) return;
        for (self.future.items) |*c| c.deinit(self.allocator);
        self.future.clearRetainingCapacity();
        try self.past.append(self.allocator, try change.clone(self.allocator));
    }

    /// Pop one undo step: moves `past` top to `future`, returns reversed
    /// change for application (caller owns it).
    pub fn popUndo(self: *UndoStack) Allocator.Error!?Change {
        if (self.past.items.len == 0) return null;
        var owned = self.past.pop() orelse return null;
        errdefer owned.deinit(self.allocator);
        try self.future.append(self.allocator, try owned.clone(self.allocator));
        owned.reverse();
        return owned;
    }

    /// Pop one redo step: moves `future` top to `past`, returns it for
    /// application (caller owns a clone; original stays in `past`).
    pub fn popRedo(self: *UndoStack) Allocator.Error!?Change {
        if (self.future.items.len == 0) return null;
        var owned = self.future.pop() orelse return null;
        errdefer owned.deinit(self.allocator);
        try self.past.append(self.allocator, try owned.clone(self.allocator));
        return owned;
    }
};

// ---------------------------------------------------------------------------
// Vi modal layer (modit parity, dependency-free)
// ---------------------------------------------------------------------------

pub const ViMode = enum { normal, insert, visual, replace };

pub const Operator = enum { yank, delete, change };

pub const Key = union(enum) {
    backspace,
    delete,
    down,
    end,
    enter,
    escape,
    home,
    tab,
    backtab,
    char: u21,
    left,
    page_down,
    page_up,
    right,
    up,
};

const FindKind = enum { next_char, next_till, prev_char, prev_till };

const ObjectPrefix = enum { inside, around };

/// Motions the parser can emit (superset of `Motion` with vi specifics).
pub const ViMotion = union(enum) {
    down,
    end,
    goto_line: usize,
    goto_eof,
    home,
    left,
    left_in_line,
    right,
    right_in_line,
    next_char: u21,
    next_char_till: u21,
    previous_char: u21,
    previous_char_till: u21,
    next_word_start: WordKind,
    next_word_end: WordKind,
    previous_word_start: WordKind,
    previous_word_end: WordKind,
    next_search,
    previous_search,
    screen_high,
    screen_middle,
    screen_low,
    soft_home,
    up,
    page_down,
    page_up,
};

/// Text objects for `i`/`a` + object.
pub const TextObject = union(enum) {
    angle,
    curly,
    double,
    paren,
    single,
    square,
    ticks,
    search: bool, // forwards
    word: WordKind,
};

/// Parser events consumed by `ViEditor` (mirrors `modit::Event`).
pub const Event = union(enum) {
    backspace,
    backspace_in_line,
    change_start,
    change_finish,
    delete,
    delete_lines,
    delete_in_line,
    escape,
    insert: u21,
    new_line,
    put: struct { register: u8, after: bool },
    redraw,
    select_clear,
    select_start,
    select_line_start,
    select_text_object: struct { object: TextObject, include: bool },
    set_search: struct { value: []const u8, forwards: bool },
    shift_left,
    shift_right,
    undo,
    yank: struct { register: u8 },
    motion: ViMotion,
};

pub const ViParser = struct {
    allocator: Allocator,
    mode: ViMode,
    count: usize,
    pending_register: ?u8,
    register_pending: bool,
    operator: ?Operator,
    pending_g: bool,
    pending_find: ?FindKind,
    pending_object: ?ObjectPrefix,
    searching: bool,
    search_forwards: bool,
    search_buf: std.ArrayList(u8),

    pub fn init(allocator: Allocator) ViParser {
        return .{
            .allocator = allocator,
            .mode = .normal,
            .count = 0,
            .pending_register = null,
            .register_pending = false,
            .operator = null,
            .pending_g = false,
            .pending_find = null,
            .pending_object = null,
            .searching = false,
            .search_forwards = true,
            .search_buf = .empty,
        };
    }

    pub fn deinit(self: *ViParser) void {
        self.search_buf.deinit(self.allocator);
        self.* = undefined;
    }

    fn takeCount(self: *ViParser, fallback: usize) usize {
        if (self.count == 0) return fallback;
        const n = self.count;
        self.count = 0;
        return n;
    }

    fn activeRegister(self: *const ViParser) u8 {
        return self.pending_register orelse '"';
    }

    fn clearPending(self: *ViParser) void {
        self.operator = null;
        self.pending_register = null;
        self.register_pending = false;
        self.pending_g = false;
        self.pending_find = null;
        self.pending_object = null;
        self.count = 0;
    }

    /// Feed one key; may synchronously invoke `editor.handleEvent` zero or
    /// more times. Direct port of the `modit` state machine shape used by
    /// `vi.rs` (`parse(key, has_selection, cb)`), without the closure.
    pub fn feed(self: *ViParser, key: Key, editor: *ViEditor) Error!void {
        // Search input capture.
        if (self.searching) {
            switch (key) {
                .enter => {
                    try editor.handleEvent(.{ .set_search = .{ .value = self.search_buf.items, .forwards = self.search_forwards } });
                    self.searching = false;
                    self.search_buf.clearRetainingCapacity();
                    self.count = 0;
                },
                .escape => {
                    self.searching = false;
                    self.search_buf.clearRetainingCapacity();
                    try editor.handleEvent(.select_clear);
                },
                .backspace => {
                    if (self.search_buf.items.len > 0) {
                        // Pop one UTF-8 char.
                        var i = self.search_buf.items.len;
                        i = prevCharStart(self.search_buf.items, i);
                        self.search_buf.shrinkRetainingCapacity(i);
                    } else {
                        self.searching = false;
                    }
                },
                .char => |c| {
                    var buf: [4]u8 = undefined;
                    const len = std.unicode.utf8Encode(c, &buf) catch return;
                    try self.search_buf.appendSlice(self.allocator, buf[0..len]);
                },
                else => {},
            }
            return;
        }

        // Pending f/t/F/T target char.
        if (self.pending_find) |kind| {
            if (key == .escape) {
                self.pending_find = null;
                return;
            }
            if (key == .char) {
                const c = key.char;
                const m: ViMotion = switch (kind) {
                    .next_char => .{ .next_char = c },
                    .next_till => .{ .next_char_till = c },
                    .prev_char => .{ .previous_char = c },
                    .prev_till => .{ .previous_char_till = c },
                };
                self.pending_find = null;
                try self.doMotionOrOperator(editor, m);
                return;
            }
            self.pending_find = null;
            return;
        }

        // Pending register after `"`.
        if (self.register_pending) {
            self.register_pending = false;
            if (key == .escape) {
                self.pending_register = null;
                return;
            }
            if (key == .char and key.char < 256) {
                self.pending_register = @intCast(key.char);
                return;
            }
            self.pending_register = null;
            // Fall through to handle this key normally.
        }

        // Pending i/a text-object prefix after an operator (or bare).
        if (self.pending_object) |prefix| {
            if (key == .escape) {
                self.pending_object = null;
                return;
            }
            if (key == .char) {
                const c = key.char;
                if (charToTextObject(c, prefix)) |obj| {
                    self.pending_object = null;
                    try self.doTextObject(editor, obj.object, obj.include);
                    return;
                }
            }
            self.pending_object = null;
            return;
        }

        // Pending `g` (gg / ge).
        if (self.pending_g) {
            self.pending_g = false;
            if (key == .char) {
                if (key.char == 'g') {
                    const line: usize = if (self.count == 0) 0 else self.count -| 1;
                    self.count = 0;
                    try self.doMotionOrOperator(editor, .{ .goto_line = line });
                    return;
                }
                if (key.char == 'e') {
                    try self.doMotionOrOperator(editor, .{ .previous_word_end = .small });
                    return;
                }
                if (key.char == 'E') {
                    try self.doMotionOrOperator(editor, .{ .previous_word_end = .big });
                    return;
                }
                if (key.char == 'n') {
                    // `gn`: select next search match.
                    try self.doTextObject(editor, .{ .search = true }, true);
                    return;
                }
                if (key.char == 'N') {
                    try self.doTextObject(editor, .{ .search = false }, true);
                    return;
                }
            }
            // Otherwise fall through with pending_g cleared.
        }

        switch (self.mode) {
            .insert, .replace => try self.feedInsert(key, editor),
            .normal, .visual => try self.feedNormal(key, editor),
        }
    }

    fn feedInsert(self: *ViParser, key: Key, editor: *ViEditor) Error!void {
        switch (key) {
            .escape => {
                self.mode = .normal;
                self.clearPending();
                try editor.handleEvent(.escape);
                // Finish the insert change started on entering Insert.
                try editor.handleEvent(.change_finish);
            },
            .backspace => try editor.handleEvent(.backspace),
            .delete => try editor.handleEvent(.delete),
            .enter => try editor.handleEvent(.new_line),
            .tab => try editor.handleEvent(.shift_right),
            .backtab => try editor.handleEvent(.shift_left),
            .left => try editor.handleEvent(.{ .motion = .left }),
            .right => try editor.handleEvent(.{ .motion = .right }),
            .up => try editor.handleEvent(.{ .motion = .up }),
            .down => try editor.handleEvent(.{ .motion = .down }),
            .home => try editor.handleEvent(.{ .motion = .home }),
            .end => try editor.handleEvent(.{ .motion = .end }),
            .page_up => try editor.handleEvent(.{ .motion = .page_up }),
            .page_down => try editor.handleEvent(.{ .motion = .page_down }),
            .char => |c| try editor.handleEvent(.{ .insert = c }),
        }
    }

    fn feedNormal(self: *ViParser, key: Key, editor: *ViEditor) Error!void {
        switch (key) {
            .escape => {
                self.clearPending();
                if (self.mode == .visual) self.mode = .normal;
                try editor.handleEvent(.escape);
                try editor.handleEvent(.select_clear);
            },
            .enter => try self.doMotionOrOperator(editor, .down),
            .backspace => try self.doMotionOrOperator(editor, .left_in_line),
            .delete => try editor.handleEvent(.delete_in_line),
            .left => try self.doMotionOrOperator(editor, .left),
            .right => try self.doMotionOrOperator(editor, .right),
            .up => try self.doMotionOrOperator(editor, .up),
            .down => try self.doMotionOrOperator(editor, .down),
            .home => try self.doMotionOrOperator(editor, .home),
            .end => try self.doMotionOrOperator(editor, .end),
            .page_up => try self.doMotionOrOperator(editor, .page_up),
            .page_down => try self.doMotionOrOperator(editor, .page_down),
            .tab => try editor.handleEvent(.shift_right),
            .backtab => try editor.handleEvent(.shift_left),
            .char => |c| try self.feedNormalChar(c, editor),
        }
    }

    fn feedNormalChar(self: *ViParser, c: u21, editor: *ViEditor) Error!void {
        // Counts (0 is Home when no count yet).
        if (c >= '1' and c <= '9') {
            self.count = self.count * 10 + (c - '0');
            return;
        }
        if (c == '0' and self.count > 0) {
            self.count = self.count * 10;
            return;
        }
        switch (c) {
            '"' => {
                self.register_pending = true;
            },
            'g' => {
                self.pending_g = true;
            },
            'f' => {
                self.pending_find = .next_char;
            },
            't' => {
                self.pending_find = .next_till;
            },
            'F' => {
                self.pending_find = .prev_char;
            },
            'T' => {
                self.pending_find = .prev_till;
            },
            '/' => {
                self.searching = true;
                self.search_forwards = true;
                self.search_buf.clearRetainingCapacity();
            },
            '?' => {
                self.searching = true;
                self.search_forwards = false;
                self.search_buf.clearRetainingCapacity();
            },
            'n' => {
                if (self.operator != null) {
                    try self.doTextObject(editor, .{ .search = true }, true);
                } else {
                    try self.doMotionOrOperator(editor, .next_search);
                }
            },
            'N' => {
                if (self.operator != null) {
                    try self.doTextObject(editor, .{ .search = false }, true);
                } else {
                    try self.doMotionOrOperator(editor, .previous_search);
                }
            },
            'h' => try self.doMotionOrOperator(editor, .left_in_line),
            'j' => try self.doMotionOrOperator(editor, .down),
            'k' => try self.doMotionOrOperator(editor, .up),
            'l' => try self.doMotionOrOperator(editor, .right_in_line),
            '0' => try self.doMotionOrOperator(editor, .home),
            '^' => try self.doMotionOrOperator(editor, .soft_home),
            '$' => try self.doMotionOrOperator(editor, .end),
            'w' => try self.doMotionOrOperator(editor, .{ .next_word_start = .small }),
            'W' => try self.doMotionOrOperator(editor, .{ .next_word_start = .big }),
            'b' => try self.doMotionOrOperator(editor, .{ .previous_word_start = .small }),
            'B' => try self.doMotionOrOperator(editor, .{ .previous_word_start = .big }),
            'e' => try self.doMotionOrOperator(editor, .{ .next_word_end = .small }),
            'E' => try self.doMotionOrOperator(editor, .{ .next_word_end = .big }),
            'H' => try self.doMotionOrOperator(editor, .screen_high),
            'M' => try self.doMotionOrOperator(editor, .screen_middle),
            'L' => try self.doMotionOrOperator(editor, .screen_low),
            'G' => {
                if (self.operator != null) {
                    // Operator + G: to last line.
                    try self.doMotionOrOperator(editor, .goto_eof);
                } else if (self.count > 0) {
                    const line = self.count -| 1;
                    self.count = 0;
                    try self.doMotionOrOperator(editor, .{ .goto_line = line });
                } else {
                    try self.doMotionOrOperator(editor, .goto_eof);
                }
            },
            'y', 'd', 'c' => {
                const op: Operator = if (c == 'y') .yank else if (c == 'd') .delete else .change;
                if (self.operator != null and self.operator.? == op) {
                    // Line-wise double operator (dd/yy/cc).
                    const reg = self.activeRegister();
                    const n = self.takeCount(1);
                    self.operator = null;
                    self.pending_register = null;
                    try editor.handleEvent(.change_start);
                    try editor.handleEvent(.select_line_start);
                    // Extend line selection n-1 lines down.
                    var i: usize = 1;
                    while (i < n) : (i += 1) {
                        try editor.handleEvent(.{ .motion = .down });
                    }
                    switch (op) {
                        .yank => {
                            try editor.handleEvent(.{ .yank = .{ .register = reg } });
                            try editor.handleEvent(.change_finish);
                            try editor.handleEvent(.select_clear);
                        },
                        .delete => {
                            // `dd` removes whole lines (vim parity).
                            try editor.handleEvent(.delete_lines);
                            try editor.handleEvent(.change_finish);
                        },
                        .change => {
                            // `cc` keeps an empty line for typing; the change
                            // stays open so typing joins the same undo step.
                            try editor.handleEvent(.delete);
                            self.mode = .insert;
                        },
                    }
                    if (self.mode == .visual) self.mode = .normal;
                } else {
                    self.operator = op;
                    try editor.handleEvent(.change_start);
                    if (self.mode == .normal) {
                        try editor.handleEvent(.select_start);
                    }
                    // Visual operators wait for the next key only when the
                    // key itself is the operator (vd → delete selection).
                    if (self.mode == .visual) {
                        const reg = self.activeRegister();
                        const o = self.operator.?;
                        self.operator = null;
                        self.pending_register = null;
                        self.count = 0;
                        const linewise = editor.editor.selection == .line;
                        switch (o) {
                            .yank => {
                                try editor.handleEvent(.{ .yank = .{ .register = reg } });
                                try editor.handleEvent(.change_finish);
                                try editor.handleEvent(.select_clear);
                            },
                            .delete => {
                                if (linewise) {
                                    try editor.handleEvent(.delete_lines);
                                } else {
                                    try editor.handleEvent(.delete);
                                }
                                try editor.handleEvent(.change_finish);
                            },
                            .change => {
                                // Keep the change open for typing.
                                try editor.handleEvent(.delete);
                                self.mode = .insert;
                            },
                        }
                        if (self.mode == .visual) self.mode = .normal;
                    }
                }
            },
            'i' => {
                if (self.operator != null) {
                    self.pending_object = .inside;
                } else if (self.mode == .visual) {
                    // `vi` prefix inside visual: expect object next.
                    self.pending_object = .inside;
                } else {
                    try editor.handleEvent(.change_start);
                    self.mode = .insert;
                    self.count = 0;
                }
            },
            'a' => {
                if (self.operator != null) {
                    self.pending_object = .around;
                } else if (self.mode == .visual) {
                    self.pending_object = .around;
                } else {
                    // Append after cursor.
                    const cur = editor.editor.cursor;
                    const t = editor.editor.lineSlice(cur.line);
                    if (cur.index < t.len) {
                        if (editor.editor.motionCursor(cur, editor.editor.cursor_x_opt, .right)) |r| {
                            editor.editor.cursor = r.cursor;
                            editor.editor.cursor_x_opt = r.x_opt;
                        }
                    }
                    try editor.handleEvent(.change_start);
                    self.mode = .insert;
                    self.count = 0;
                }
            },
            'I' => {
                if (self.operator == null) {
                    try self.doMotionOrOperator(editor, .soft_home);
                    try editor.handleEvent(.change_start);
                    self.mode = .insert;
                    self.count = 0;
                }
            },
            'A' => {
                if (self.operator == null) {
                    try self.doMotionOrOperator(editor, .end);
                    try editor.handleEvent(.change_start);
                    self.mode = .insert;
                    self.count = 0;
                }
            },
            'o' => {
                if (self.operator == null and self.mode == .normal) {
                    // Open line below; keep the change open so `o` + typing
                    // + Escape is a single undo step.
                    try editor.handleEvent(.change_start);
                    var cur = editor.editor.cursor;
                    cur.index = editor.editor.lineSlice(cur.line).len;
                    editor.editor.cursor = cur;
                    try editor.handleEvent(.new_line);
                    self.mode = .insert;
                    self.count = 0;
                }
            },
            'O' => {
                if (self.operator == null and self.mode == .normal) {
                    try editor.handleEvent(.change_start);
                    var cur = editor.editor.cursor;
                    cur.index = 0;
                    editor.editor.cursor = cur;
                    // Insert newline before: insert "\n" at line start then move up.
                    const at = editor.editor.cursor;
                    _ = try editor.editor.insertAt(at, "\n");
                    editor.editor.cursor = at;
                    self.mode = .insert;
                    self.count = 0;
                }
            },
            'v' => {
                self.operator = null;
                self.pending_register = null;
                self.mode = .visual;
                try editor.handleEvent(.select_start);
            },
            'V' => {
                self.operator = null;
                self.pending_register = null;
                self.mode = .visual;
                try editor.handleEvent(.select_line_start);
            },
            'R' => {
                if (self.operator == null and self.mode == .normal) {
                    try editor.handleEvent(.change_start);
                    self.mode = .replace;
                }
            },
            'p' => {
                const reg = self.activeRegister();
                self.pending_register = null;
                self.count = 0;
                try editor.handleEvent(.{ .put = .{ .register = reg, .after = true } });
            },
            'P' => {
                const reg = self.activeRegister();
                self.pending_register = null;
                self.count = 0;
                try editor.handleEvent(.{ .put = .{ .register = reg, .after = false } });
            },
            'u' => {
                self.clearPending();
                try editor.handleEvent(.undo);
            },
            'x' => {
                if (self.operator == null) {
                    try editor.handleEvent(.change_start);
                    if (self.mode == .normal) try editor.handleEvent(.select_start);
                    const n = self.takeCount(1);
                    var i: usize = 0;
                    while (i < n) : (i += 1) {
                        try editor.handleEvent(.{ .motion = .right_in_line });
                    }
                    try editor.handleEvent(.delete);
                    try editor.handleEvent(.change_finish);
                    if (self.mode == .visual) self.mode = .normal;
                }
            },
            'X' => {
                if (self.operator == null) {
                    try editor.handleEvent(.change_start);
                    if (self.mode == .normal) try editor.handleEvent(.select_start);
                    const n = self.takeCount(1);
                    var i: usize = 0;
                    while (i < n) : (i += 1) {
                        try editor.handleEvent(.{ .motion = .left_in_line });
                    }
                    // Selection is backwards (cursor moved left from anchor);
                    // Delete removes it.
                    try editor.handleEvent(.delete);
                    try editor.handleEvent(.change_finish);
                    if (self.mode == .visual) self.mode = .normal;
                }
            },
            'D' => {
                if (self.operator == null and self.mode != .visual) {
                    self.operator = .delete;
                    try editor.handleEvent(.change_start);
                    try editor.handleEvent(.select_start);
                    try editor.handleEvent(.{ .motion = .end });
                    // Include newline join? `D` deletes to end (no join).
                    try editor.handleEvent(.delete);
                    try editor.handleEvent(.change_finish);
                    self.operator = null;
                    self.pending_register = null;
                    self.count = 0;
                }
            },
            'Y' => {
                if (self.operator == null) {
                    const reg = self.activeRegister();
                    self.pending_register = null;
                    try editor.handleEvent(.select_line_start);
                    try editor.handleEvent(.{ .yank = .{ .register = reg } });
                    try editor.handleEvent(.select_clear);
                }
            },
            'C' => {
                if (self.operator == null and self.mode != .visual) {
                    self.operator = null;
                    try editor.handleEvent(.change_start);
                    try editor.handleEvent(.select_start);
                    try editor.handleEvent(.{ .motion = .end });
                    try editor.handleEvent(.delete);
                    self.mode = .insert;
                }
            },
            's' => {
                if (self.operator == null) {
                    // `s`: delete char and insert (like `cl`); keep the
                    // change open so typing joins the same undo step.
                    try editor.handleEvent(.change_start);
                    try editor.handleEvent(.select_start);
                    try editor.handleEvent(.{ .motion = .right_in_line });
                    try editor.handleEvent(.delete);
                    self.mode = .insert;
                }
            },
            else => {},
        }
    }

    fn doMotionOrOperator(self: *ViParser, editor: *ViEditor, motion: ViMotion) Error!void {
        if (self.operator) |op| {
            const reg = self.activeRegister();
            // Vim parity: `cw` behaves like `ce` (to end of word, not to the
            // next word start) so the trailing space is preserved.
            if (op == .change) {
                if (motion == .next_word_start) {
                    const kind = motion.next_word_start;
                    const cur = editor.editor.cursor;
                    const text = editor.editor.lineSlice(cur.line);
                    const e = nextWordEndInLine(text, cur.index, kind);
                    var moved = cur;
                    moved.index = e;
                    editor.editor.cursor = moved;
                    editor.editor.cursor_x_opt = null;
                    try editor.handleEvent(.delete);
                    // Keep the change open for typing.
                    self.operator = null;
                    self.pending_register = null;
                    self.count = 0;
                    self.mode = .insert;
                    if (self.mode == .visual) self.mode = .normal;
                    return;
                }
            }
            // Goto motions with counts: `3G` handled by caller; here repeat.
            const repeat: usize = switch (motion) {
                .goto_line, .goto_eof, .screen_high, .screen_middle, .screen_low => 1,
                else => self.takeCount(1),
            };
            // ChangeStart was already emitted when the operator was typed
            // (or for Visual, same). If in Normal without prior ChangeStart
            // (e.g. operator set programmatically), ensure one.
            // Our callers always emitted ChangeStart on operator key, so just
            // apply motions + finish.
            var i: usize = 0;
            while (i < repeat) : (i += 1) {
                try editor.handleEvent(.{ .motion = motion });
            }
            switch (op) {
                .yank => {
                    try editor.handleEvent(.{ .yank = .{ .register = reg } });
                    try editor.handleEvent(.change_finish);
                    try editor.handleEvent(.select_clear);
                },
                .delete => {
                    // Line selections from double operators are handled by
                    // the caller; here the selection is char-wise.
                    if (editor.editor.selection == .line) {
                        try editor.handleEvent(.delete_lines);
                    } else {
                        try editor.handleEvent(.delete);
                    }
                    try editor.handleEvent(.change_finish);
                },
                .change => {
                    try editor.handleEvent(.delete);
                    // Keep the change open so typing joins the same undo step.
                    self.mode = .insert;
                },
            }
            self.operator = null;
            self.pending_register = null;
            self.count = 0;
            if (self.mode == .visual) self.mode = .normal;
        } else {
            switch (motion) {
                .goto_line => |line| {
                    self.count = 0;
                    try editor.handleEvent(.{ .motion = .{ .goto_line = line } });
                },
                .goto_eof => {
                    self.count = 0;
                    try editor.handleEvent(.{ .motion = .goto_eof });
                },
                .screen_high, .screen_middle, .screen_low => {
                    self.count = 0;
                    try editor.handleEvent(.{ .motion = motion });
                },
                else => {
                    const n = self.takeCount(1);
                    var i: usize = 0;
                    while (i < n) : (i += 1) {
                        try editor.handleEvent(.{ .motion = motion });
                    }
                },
            }
        }
    }

    fn doTextObject(self: *ViParser, editor: *ViEditor, object: TextObject, include: bool) Error!void {
        if (self.operator) |op| {
            const reg = self.activeRegister();
            const n = self.takeCount(1);
            var i: usize = 0;
            while (i < n) : (i += 1) {
                try editor.handleEvent(.{ .select_text_object = .{ .object = object, .include = include } });
            }
            switch (op) {
                .yank => {
                    try editor.handleEvent(.{ .yank = .{ .register = reg } });
                    try editor.handleEvent(.change_finish);
                    try editor.handleEvent(.select_clear);
                },
                .delete => {
                    if (editor.editor.selection == .line) {
                        try editor.handleEvent(.delete_lines);
                    } else {
                        try editor.handleEvent(.delete);
                    }
                    try editor.handleEvent(.change_finish);
                },
                .change => {
                    try editor.handleEvent(.delete);
                    // Keep the change open for typing.
                    self.mode = .insert;
                },
            }
            self.operator = null;
            self.pending_register = null;
            self.count = 0;
            if (self.mode == .visual) self.mode = .normal;
        } else {
            // Bare text object: enter visual and select.
            if (self.mode == .normal) {
                self.mode = .visual;
                try editor.handleEvent(.select_start);
            }
            self.count = 0;
            try editor.handleEvent(.{ .select_text_object = .{ .object = object, .include = include } });
        }
    }
};

fn charToTextObject(c: u21, prefix: ObjectPrefix) ?struct { object: TextObject, include: bool } {
    const include = prefix == .around;
    switch (c) {
        '<', '>' => return .{ .object = .angle, .include = include },
        '{', '}' => return .{ .object = .curly, .include = include },
        '"' => return .{ .object = .double, .include = include },
        '(', ')' => return .{ .object = .paren, .include = include },
        '\'',
        => return .{ .object = .single, .include = include },
        '[', ']' => return .{ .object = .square, .include = include },
        '`' => return .{ .object = .ticks, .include = include },
        'w' => return .{ .object = .{ .word = .small }, .include = include },
        'W' => return .{ .object = .{ .word = .big }, .include = include },
        'n' => return .{ .object = .{ .search = true }, .include = true },
        'N' => return .{ .object = .{ .search = false }, .include = true },
        '/' => return .{ .object = .{ .search = true }, .include = true },
        '?' => return .{ .object = .{ .search = false }, .include = true },
        else => return null,
    }
}

// ---------------------------------------------------------------------------
// ViEditor
// ---------------------------------------------------------------------------

pub const RegisterEntry = struct {
    selection: Selection,
    text: []u8, // owned

    pub fn deinit(self: *RegisterEntry, allocator: Allocator) void {
        allocator.free(self.text);
        self.* = undefined;
    }
};

/// Block cursor probing for tests/render.
pub const CursorShape = enum { block, bar };

pub const ViEditor = struct {
    allocator: Allocator,
    editor: Editor,
    parser: ViParser,
    passthrough: bool,
    registers: std.AutoHashMap(u8, RegisterEntry),
    search_value: ?[]u8,
    search_forwards: bool,
    commands: UndoStack,
    changed: bool,
    save_pivot: ?usize,

    pub fn init(allocator: Allocator) Allocator.Error!ViEditor {
        var self = ViEditor{
            .allocator = allocator,
            .editor = try Editor.init(allocator),
            .parser = ViParser.init(allocator),
            .passthrough = false,
            .registers = std.AutoHashMap(u8, RegisterEntry).init(allocator),
            .search_value = null,
            .search_forwards = true,
            .commands = UndoStack.init(allocator),
            .changed = false,
            .save_pivot = null,
        };
        errdefer self.deinit();
        return self;
    }

    pub fn deinit(self: *ViEditor) void {
        if (self.search_value) |v| self.allocator.free(v);
        var it = self.registers.iterator();
        while (it.next()) |e| {
            self.allocator.free(e.value_ptr.text);
        }
        self.registers.deinit();
        self.commands.deinit();
        self.parser.deinit();
        self.editor.deinit();
        self.* = undefined;
    }

    pub fn setText(self: *ViEditor, text: []const u8) Allocator.Error!void {
        try self.editor.setText(text);
        // Fresh buffer clears undo history (matches a new file load).
        for (self.commands.past.items) |*c| c.deinit(self.allocator);
        self.commands.past.clearRetainingCapacity();
        for (self.commands.future.items) |*c| c.deinit(self.allocator);
        self.commands.future.clearRetainingCapacity();
        self.save_pivot = null;
        self.changed = false;
    }

    pub fn fullText(self: *const ViEditor) Allocator.Error!std.ArrayList(u8) {
        return self.editor.fullText();
    }

    pub fn cursor(self: *const ViEditor) Cursor {
        return self.editor.cursor;
    }

    pub fn setCursor(self: *ViEditor, c: Cursor) void {
        self.editor.cursor = self.editor.clampCursor(c);
    }

    pub fn selection(self: *const ViEditor) Selection {
        return self.editor.selection;
    }

    pub fn changedFlag(self: *const ViEditor) bool {
        return self.changed;
    }

    pub fn setChanged(self: *ViEditor, v: bool) void {
        self.changed = v;
    }

    pub fn savePoint(self: *ViEditor) void {
        self.save_pivot = self.commands.currentCommandIndex() orelse 0;
        // Wrap in Some (reference uses unwrap_or_default then Some).
        // currentCommandIndex already returns null only for a fresh stack;
        // mapping null -> 0 then Some matches `Some(unwrap_or_default())`.
        self.changed = false;
    }

    pub fn setPassthrough(self: *ViEditor, v: bool) void {
        self.passthrough = v;
    }

    pub fn isBlockCursor(self: *const ViEditor) bool {
        if (self.passthrough) return false;
        return switch (self.parser.mode) {
            .insert, .replace => false,
            else => true,
        };
    }

    pub fn cursorShape(self: *const ViEditor) CursorShape {
        return if (self.isBlockCursor()) .block else .bar;
    }

    pub fn mode(self: *const ViEditor) ViMode {
        return self.parser.mode;
    }

    /// Feed a vi `Key` through the parser (mode-aware).
    pub fn feedKey(self: *ViEditor, key: Key) Error!void {
        try self.parser.feed(key, self);
    }

    /// Feed ASCII text as `Key.char` presses (helper for tests).
    pub fn feedString(self: *ViEditor, s: []const u8) Error!void {
        var i: usize = 0;
        while (i < s.len) {
            const len = @min(cpLen(s[i]), s.len - i);
            const cp = std.unicode.utf8Decode(s[i .. i + len]) catch {
                i += 1;
                continue;
            };
            // Map control bytes to keys.
            if (cp == '\x1b') {
                try self.feedKey(.escape);
            } else if (cp == '\n' or cp == '\r') {
                try self.feedKey(.enter);
            } else {
                try self.feedKey(.{ .char = cp });
            }
            i += len;
        }
    }

    /// Direct `Action` entry point (mirrors `Edit::action` in `vi.rs`):
    /// passthrough forwards to the inner editor with change grouping,
    /// otherwise translates to `Key` and runs the parser.
    pub fn action(self: *ViEditor, act: Action) Error!void {
        self.editor.startChange();
        if (self.passthrough) {
            try self.editor.action(act);
            try self.finishChange();
            return;
        }
        const key: ?Key = switch (act) {
            .backspace => Key.backspace,
            .delete => Key.delete,
            .motion => |m| switch (m) {
                .down => Key.down,
                .end => Key.end,
                .home => Key.home,
                .left => Key.left,
                .right => Key.right,
                .up => Key.up,
                .page_down => Key.page_down,
                .page_up => Key.page_up,
                .goto_line, .buffer_start, .buffer_end, .soft_home => null,
            },
            .enter => Key.enter,
            .escape => Key.escape,
            .insert => |c| Key{ .char = c },
            .indent => Key.tab,
            .unindent => Key.backtab,
            else => null,
        };
        if (key) |k| {
            // Parser drives editor events which manage their own Change
            // grouping; drop the pre-started empty change first.
            if (self.editor.change) |pending| {
                if (pending.items.items.len == 0) {
                    var drop = pending;
                    drop.deinit(self.allocator);
                    self.editor.change = null;
                }
            }
            const has_selection = self.editor.selection != .none;
            _ = has_selection;
            try self.parser.feed(k, self);
            // Parser-managed changes already pushed via ChangeFinish. If the
            // parser left an empty pending change (e.g. plain motion), drop it.
            if (self.editor.change) |pending| {
                if (pending.items.items.len == 0) {
                    var drop = pending;
                    drop.deinit(self.allocator);
                    self.editor.change = null;
                } else {
                    try self.finishChange();
                }
            }
            return;
        }
        // Untranslatable actions (click/drag/scroll/soft motions) pass through.
        try self.editor.action(act);
        try self.finishChange();
    }

    fn finishChange(self: *ViEditor) Error!void {
        if (try self.finishChangeInner()) |_| {}
    }

    fn finishChangeInner(self: *ViEditor) Error!?Change {
        if (self.editor.finishChange()) |ch| {
            var owned = ch;
            errdefer owned.deinit(self.allocator);
            if (!owned.isEmpty()) {
                try self.commands.push(&owned);
                self.changed = evalChanged(self.commands.currentCommandIndex(), self.save_pivot);
            }
            owned.deinit(self.allocator);
            return null;
        }
        return null;
    }

    pub fn undo(self: *ViEditor) Error!void {
        if (self.editor.change) |pending| {
            if (pending.items.items.len > 0) return error.ChangeInProgress;
        }
        if (try self.commands.popUndo()) |rev| {
            var owned = rev;
            defer owned.deinit(self.allocator);
            _ = try self.editor.applyChange(&owned);
        }
        self.changed = evalChanged(self.commands.currentCommandIndex(), self.save_pivot);
    }

    pub fn redo(self: *ViEditor) Error!void {
        if (self.editor.change) |pending| {
            if (pending.items.items.len > 0) return error.ChangeInProgress;
        }
        if (try self.commands.popRedo()) |fwd| {
            var owned = fwd;
            defer owned.deinit(self.allocator);
            _ = try self.editor.applyChange(&owned);
        }
        self.changed = evalChanged(self.commands.currentCommandIndex(), self.save_pivot);
    }

    /// Search forward/backward for `value` from the cursor (exclusive on the
    /// start line, mirroring `vi.rs::search` match_indices filtering).
    pub fn search(self: *ViEditor, value: []const u8, forwards: bool) bool {
        if (value.len == 0) return false;
        var cur = self.editor.cursor;
        const start_line = cur.line;
        const n = self.editor.lineCount();
        if (forwards) {
            while (cur.line < n) {
                const text = self.editor.lineSlice(cur.line);
                var i: usize = 0;
                var found: ?usize = null;
                while (std.mem.indexOf(u8, text[i..], value)) |rel| {
                    const at = i + rel;
                    if (cur.line != start_line or at > self.editor.cursor.index) {
                        found = at;
                        break;
                    }
                    i = at + 1;
                    if (i >= text.len) break;
                }
                if (found) |at| {
                    cur.index = at;
                    self.editor.cursor = cur;
                    return true;
                }
                cur.line += 1;
            }
        } else {
            // Mirror oracle: start from line+1 and walk down, rmatch within.
            var line = cur.line + 1;
            while (line > 0) {
                line -= 1;
                const text = self.editor.lineSlice(line);
                var last: ?usize = null;
                var i: usize = 0;
                while (std.mem.indexOf(u8, text[i..], value)) |rel| {
                    const at = i + rel;
                    if (line != start_line or at < self.editor.cursor.index) {
                        last = at;
                    } else break;
                    i = at + 1;
                    if (i >= text.len) break;
                }
                if (last) |at| {
                    cur.line = line;
                    cur.index = at;
                    self.editor.cursor = cur;
                    return true;
                }
                if (line == 0) break;
            }
        }
        return false;
    }

    /// Delete whole lines covered by the current `Line` selection (vim `dd`
    /// parity: removes lines including newlines so no blank remains).
    fn deleteSelectedLines(self: *ViEditor) Error!void {
        const b = self.editor.selectionBounds() orelse {
            // No line selection: fall back to char-wise delete.
            try self.editor.action(.delete);
            return;
        };
        // Only line selections remove whole lines; other selections use the
        // generic char-wise path.
        const is_line = switch (self.editor.selection) {
            .line => true,
            else => false,
        };
        if (!is_line) {
            try self.editor.action(.delete);
            return;
        }
        const s = @min(b.start.line, b.end.line);
        const e = @max(b.start.line, b.end.line);
        const n = self.editor.lineCount();
        self.editor.selection = .{ .none = {} };
        if (n == 0) return;
        if (n == 1) {
            // Single-line buffer: clear it.
            const len = self.editor.lineSlice(0).len;
            if (len > 0) try self.editor.deleteRange(Cursor.init(0, 0), Cursor.init(0, len));
            self.editor.cursor = Cursor.init(0, 0);
            return;
        }
        if (e + 1 < n) {
            try self.editor.deleteRange(Cursor.init(s, 0), Cursor.init(e + 1, 0));
            self.editor.cursor = Cursor.init(@min(s, self.editor.lineCount() - 1), 0);
        } else if (s > 0) {
            const prev_len = self.editor.lineSlice(s - 1).len;
            try self.editor.deleteRange(Cursor.init(s - 1, prev_len), Cursor.init(e, self.editor.lineSlice(e).len));
            self.editor.cursor = Cursor.init(s - 1, prev_len);
            // Clamp to line length (join leaves cursor at end of prev).
            self.editor.cursor = self.editor.clampCursor(self.editor.cursor);
        } else {
            // Deleting all lines: clear to a single empty line.
            try self.editor.deleteRange(Cursor.init(0, 0), Cursor.init(e, self.editor.lineSlice(e).len));
            // Remove leftover empty lines beyond the first.
            while (self.editor.lineCount() > 1) {
                var removed = self.editor.lines.orderedRemove(1);
                removed.deinit(self.editor.allocator);
            }
            self.editor.cursor = Cursor.init(0, 0);
        }
    }

    fn selectIn(self: *ViEditor, start_c: u21, end_c: u21, include: bool) Error!void {
        const cur = self.editor.cursor;
        // Forward scan for isolated end char.
        var end = cur;
        var starts: usize = 0;
        var ends: usize = 0;
        find_end: while (true) {
            const text = self.editor.lineSlice(end.line);
            var off = end.index;
            while (off < text.len) {
                const len = @min(cpLen(text[off]), text.len - off);
                const cp = std.unicode.utf8Decode(text[off .. off + len]) catch {
                    off += 1;
                    continue;
                };
                if (cp == end_c) ends += 1 else if (cp == start_c) starts += 1;
                if (ends > starts) {
                    end.index = off + (if (include) len else 0);
                    break :find_end;
                }
                off += len;
            }
            if (end.line + 1 < self.editor.lineCount()) {
                end.line += 1;
                end.index = 0;
            } else break :find_end;
        }
        // Backward scan to resolve start.
        var start = cur;
        find_start: while (true) {
            const text = self.editor.lineSlice(start.line);
            var off = start.index;
            while (off > 0) {
                const s = prevCharStart(text, off);
                const len = off - s;
                const cp = std.unicode.utf8Decode(text[s .. s + len]) catch {
                    off = s;
                    continue;
                };
                if (cp == start_c) starts += 1 else if (cp == end_c) ends += 1;
                if (starts >= ends) {
                    start.index = s + (if (include) 0 else len);
                    break :find_start;
                }
                off = s;
            }
            if (start.line > 0) {
                start.line -= 1;
                start.index = self.editor.lineSlice(start.line).len;
            } else break :find_start;
        }
        self.editor.selection = .{ .normal = start };
        self.editor.cursor = end;
    }

    /// Handle one parser `Event` (mirrors the `vi.rs` closure body).
    pub fn handleEvent(self: *ViEditor, ev: Event) Error!void {
        switch (ev) {
            .backspace => try self.editor.action(.backspace),
            .backspace_in_line => {
                if (self.editor.cursor.index > 0) try self.editor.action(.backspace);
            },
            .change_start => {
                self.editor.startChange();
            },
            .change_finish => {
                try self.finishChange();
            },
            .delete => try self.editor.action(.delete),
            .delete_lines => try self.deleteSelectedLines(),
            .delete_in_line => {
                const t = self.editor.lineSlice(self.editor.cursor.line);
                if (self.editor.cursor.index < t.len) try self.editor.action(.delete);
            },
            .escape => try self.editor.action(.escape),
            .insert => |c| try self.editor.action(.{ .insert = c }),
            .new_line => try self.editor.action(.enter),
            .put => |p| {
                const entry = self.registers.get(p.register) orelse return;
                self.editor.startChange();
                if (try self.editor.deleteSelection()) {
                    try self.editor.insertString(entry.text);
                } else {
                    switch (entry.selection) {
                        .none, .normal, .word => {
                            var cur = self.editor.cursor;
                            if (p.after) {
                                const t = self.editor.lineSlice(cur.line);
                                if (cur.index < t.len) cur.index = nextCharEnd(t, cur.index);
                                self.editor.cursor = cur;
                            }
                            _ = try self.editor.insertAt(cur, entry.text);
                            self.editor.cursor = self.editor.clampCursor(cur);
                            // Leave cursor at start of inserted text (vim `p`
                            // lands on last char; keep start for testability).
                            // Advance past inserted text for Normal put parity:
                            const inserted = entry.text;
                            var adv = self.editor.cursor;
                            var k: usize = 0;
                            while (k < inserted.len) {
                                if (inserted[k] == '\n') {
                                    adv.line += 1;
                                    adv.index = 0;
                                } else {
                                    adv.index += 1;
                                }
                                k += 1;
                            }
                            self.editor.cursor = self.editor.clampCursor(adv);
                        },
                        .line => {
                            var cur = self.editor.cursor;
                            if (p.after) {
                                cur.line += 1;
                            } else {
                                cur.line += 1;
                                self.editor.cursor = cur;
                                cur.line -= 1;
                            }
                            cur.index = 0;
                            // Ensure the line exists (append trailing line).
                            while (cur.line > self.editor.lineCount()) {
                                _ = try self.editor.insertAt(Cursor.init(self.editor.lineCount() - 1, self.editor.lineSlice(self.editor.lineCount() - 1).len), "\n");
                            }
                            if (cur.line == self.editor.lineCount()) {
                                // Append at end: join via newline.
                                const last = self.editor.lineCount() - 1;
                                const at = Cursor.init(last, self.editor.lineSlice(last).len);
                                _ = try self.editor.insertAt(at, "\n");
                            }
                            _ = try self.editor.insertAt(cur, "\n");
                            _ = try self.editor.insertAt(cur, entry.text);
                            // Move to inserted line preserving x.
                            if (p.after) {
                                if (self.editor.motionCursor(self.editor.cursor, self.editor.cursor_x_opt, .down)) |r| {
                                    self.editor.cursor = r.cursor;
                                    self.editor.cursor_x_opt = r.x_opt;
                                } else {
                                    self.editor.cursor = Cursor.init(@min(cur.line + 1, self.editor.lineCount() - 1), 0);
                                }
                            } else {
                                if (self.editor.motionCursor(self.editor.cursor, self.editor.cursor_x_opt, .up)) |r| {
                                    self.editor.cursor = r.cursor;
                                    self.editor.cursor_x_opt = r.x_opt;
                                } else {
                                    self.editor.cursor = cur;
                                }
                            }
                        },
                    }
                }
                try self.finishChange();
            },
            .redraw => {},
            .select_clear => {
                self.editor.selection = .{ .none = {} };
            },
            .select_start => {
                self.editor.selection = .{ .normal = self.editor.cursor };
            },
            .select_line_start => {
                self.editor.selection = .{ .line = self.editor.cursor };
            },
            .select_text_object => |o| {
                switch (o.object) {
                    .angle => try self.selectIn('<', '>', o.include),
                    .curly => try self.selectIn('{', '}', o.include),
                    .double => try self.selectIn('"', '"', o.include),
                    .paren => try self.selectIn('(', ')', o.include),
                    .single => try self.selectIn('\'', '\'', o.include),
                    .square => try self.selectIn('[', ']', o.include),
                    .ticks => try self.selectIn('`', '`', o.include),
                    .search => |forwards| {
                        if (self.search_value) |val| {
                            if (self.search(val, forwards)) {
                                var cur = self.editor.cursor;
                                self.editor.selection = .{ .normal = cur };
                                cur.index = @min(cur.index + val.len, self.editor.lineSlice(cur.line).len);
                                self.editor.cursor = cur;
                            }
                        }
                    },
                    .word => |kind| {
                        var cur = self.editor.cursor;
                        const text = self.editor.lineSlice(cur.line);
                        if (wordBoundsAt(text, cur.index, kind)) |b| {
                            const s = Cursor.init(cur.line, b.start);
                            cur.index = b.end;
                            self.editor.selection = .{ .normal = s };
                            self.editor.cursor = cur;
                        }
                    },
                }
            },
            .set_search => |s| {
                if (self.search_value) |old| self.allocator.free(old);
                self.search_value = try self.allocator.dupe(u8, s.value);
                self.search_forwards = s.forwards;
                // Vim lands on the first match after typing `/foo<Enter>`.
                _ = self.search(s.value, s.forwards);
            },
            .shift_left => try self.editor.action(.unindent),
            .shift_right => try self.editor.action(.indent),
            .undo => try self.undo(),
            .yank => |y| {
                if (try self.editor.copySelection()) |data| {
                    var owned = data;
                    errdefer owned.deinit(self.allocator);
                    const text = try owned.toOwnedSlice(self.allocator);
                    errdefer self.allocator.free(text);
                    if (self.registers.getPtr(y.register)) |slot| {
                        self.allocator.free(slot.text);
                        slot.selection = self.editor.selection;
                        slot.text = text;
                    } else {
                        try self.registers.put(y.register, .{ .selection = self.editor.selection, .text = text });
                    }
                    owned = .empty;
                }
            },
            .motion => |m| try self.applyViMotion(m),
        }
    }

    fn applyViMotion(self: *ViEditor, m: ViMotion) Error!void {
        switch (m) {
            .down => try self.editor.action(.{ .motion = .down }),
            .end => try self.editor.action(.{ .motion = .end }),
            .home => try self.editor.action(.{ .motion = .home }),
            .left => try self.editor.action(.{ .motion = .left }),
            .right => try self.editor.action(.{ .motion = .right }),
            .up => try self.editor.action(.{ .motion = .up }),
            .page_down => try self.editor.action(.{ .motion = .page_down }),
            .page_up => try self.editor.action(.{ .motion = .page_up }),
            .soft_home => try self.editor.action(.{ .motion = .soft_home }),
            .goto_line => |line| try self.editor.action(.{ .motion = .{ .goto_line = line } }),
            .goto_eof => {
                const last = if (self.editor.lineCount() == 0) 0 else self.editor.lineCount() - 1;
                try self.editor.action(.{ .motion = .{ .goto_line = last } });
            },
            .screen_high => try self.editor.action(.{ .motion = .{ .goto_line = 0 } }),
            .screen_middle => {
                const mid = self.editor.lineCount() / 2;
                try self.editor.action(.{ .motion = .{ .goto_line = mid } });
            },
            .screen_low => {
                const last = if (self.editor.lineCount() == 0) 0 else self.editor.lineCount() - 1;
                try self.editor.action(.{ .motion = .{ .goto_line = last } });
            },
            .left_in_line => {
                const cur = self.editor.cursor;
                if (cur.index > 0) try self.editor.action(.{ .motion = .left });
            },
            .right_in_line => {
                const t = self.editor.lineSlice(self.editor.cursor.line);
                if (self.editor.cursor.index < t.len) try self.editor.action(.{ .motion = .right });
            },
            .next_char => |find_c| {
                var cur = self.editor.cursor;
                const text = self.editor.lineSlice(cur.line);
                if (cur.index < text.len) {
                    var off = nextCharEnd(text, cur.index);
                    while (off < text.len) {
                        const len = @min(cpLen(text[off]), text.len - off);
                        const cp = std.unicode.utf8Decode(text[off .. off + len]) catch {
                            off += 1;
                            continue;
                        };
                        if (cp == find_c) {
                            cur.index = off;
                            break;
                        }
                        off += len;
                    }
                    // Only land when found (mirror oracle: no move otherwise).
                    if (off < text.len) self.editor.cursor = cur;
                    // Re-check: find first i>0 with c==find_c.
                    // Implemented above as scan from next char.
                }
            },
            .next_char_till => |find_c| {
                var cur = self.editor.cursor;
                const text = self.editor.lineSlice(cur.line);
                if (cur.index < text.len) {
                    var prev = cur.index;
                    var p = nextCharEnd(text, cur.index);
                    while (p < text.len) {
                        const len = @min(cpLen(text[p]), text.len - p);
                        const cp = std.unicode.utf8Decode(text[p .. p + len]) catch {
                            prev = p;
                            p += 1;
                            continue;
                        };
                        if (cp == find_c) {
                            cur.index = prev;
                            self.editor.cursor = cur;
                            break;
                        }
                        prev = p;
                        p += len;
                    }
                }
            },
            .previous_char => |find_c| {
                var cur = self.editor.cursor;
                const text = self.editor.lineSlice(cur.line);
                if (cur.index > 0) {
                    var off = cur.index;
                    var found: ?usize = null;
                    while (off > 0) {
                        const s = prevCharStart(text, off);
                        const cp = std.unicode.utf8Decode(text[s..off]) catch {
                            off = s;
                            continue;
                        };
                        if (cp == find_c) {
                            found = s;
                            break;
                        }
                        off = s;
                    }
                    if (found) |at| {
                        cur.index = at;
                        self.editor.cursor = cur;
                    }
                }
            },
            .previous_char_till => |find_c| {
                var cur = self.editor.cursor;
                const text = self.editor.lineSlice(cur.line);
                if (cur.index > 0) {
                    // Nearest match whose end is strictly before the cursor.
                    var best: ?usize = null;
                    var p: usize = 0;
                    while (p < cur.index) {
                        const len = @min(cpLen(text[p]), text.len - p);
                        const cp = std.unicode.utf8Decode(text[p .. p + len]) catch {
                            p += 1;
                            continue;
                        };
                        if (cp == find_c and p + len < cur.index) best = p + len;
                        p += len;
                        if (p >= cur.index) break;
                    }
                    if (best) |at| {
                        cur.index = at;
                        self.editor.cursor = cur;
                    }
                }
            },
            .next_search => {
                if (self.search_value) |v| _ = self.search(v, self.search_forwards);
            },
            .previous_search => {
                if (self.search_value) |v| _ = self.search(v, !self.search_forwards);
            },
            .next_word_start => |kind| {
                var cur = self.editor.cursor;
                while (true) {
                    const text = self.editor.lineSlice(cur.line);
                    if (cur.index < text.len) {
                        const next = nextWordStartInLine(text, cur.index, kind);
                        if (next < text.len) {
                            cur.index = next;
                            break;
                        }
                        // At/after last word: fall through to next line.
                    }
                    if (cur.line + 1 >= self.editor.lineCount()) {
                        cur.index = text.len;
                        break;
                    }
                    cur.line += 1;
                    const nt = self.editor.lineSlice(cur.line);
                    if (nt.len == 0) continue;
                    const first = skipBlankForward(nt, 0);
                    if (first >= nt.len) continue;
                    cur.index = first;
                    break;
                }
                self.editor.cursor = cur;
                self.editor.cursor_x_opt = null;
            },
            .next_word_end => |kind| {
                var cur = self.editor.cursor;
                while (true) {
                    const text = self.editor.lineSlice(cur.line);
                    if (cur.index < text.len) {
                        const e = nextWordEndInLine(text, cur.index, kind);
                        if (e > cur.index and e < text.len) {
                            cur.index = prevCharStart(text, e);
                            break;
                        }
                        if (e > cur.index and e == text.len) {
                            // Word ends at EOL: land on last char.
                            cur.index = prevCharStart(text, e);
                            break;
                        }
                        // No further word end on this line: next line.
                    }
                    if (cur.line + 1 >= self.editor.lineCount()) {
                        cur.index = text.len;
                        break;
                    }
                    cur.line += 1;
                    const nt = self.editor.lineSlice(cur.line);
                    if (nt.len == 0) continue;
                    const first_end = nextWordEndInLine(nt, 0, kind);
                    // nextWordEndInLine(0) skips to first word end; when the
                    // line starts inside a word it returns that word's end.
                    // For an empty/blank start it still works; land on last
                    // char of the first word.
                    if (first_end == 0) continue;
                    if (first_end >= nt.len) {
                        cur.index = if (nt.len == 0) 0 else prevCharStart(nt, nt.len);
                    } else {
                        cur.index = prevCharStart(nt, first_end);
                    }
                    break;
                }
                self.editor.cursor = cur;
                self.editor.cursor_x_opt = null;
            },
            .previous_word_start => |kind| {
                var cur = self.editor.cursor;
                while (true) {
                    if (cur.index > 0) {
                        const text = self.editor.lineSlice(cur.line);
                        cur.index = prevWordStartInLine(text, cur.index, kind);
                        break;
                    }
                    if (cur.line == 0) break;
                    cur.line -= 1;
                    const pt = self.editor.lineSlice(cur.line);
                    if (pt.len == 0) continue;
                    // Land on the last word start of the previous line.
                    // prevWordStartInLine(len) gives it directly.
                    cur.index = prevWordStartInLine(pt, pt.len, kind);
                    // If the previous line is all blanks, keep scanning.
                    if (cur.index == 0) {
                        const first = skipBlankForward(pt, 0);
                        if (first >= pt.len) continue;
                    }
                    break;
                }
                self.editor.cursor = cur;
                self.editor.cursor_x_opt = null;
            },
            .previous_word_end => |kind| {
                var cur = self.editor.cursor;
                while (true) {
                    if (cur.index > 0) {
                        const text = self.editor.lineSlice(cur.line);
                        cur.index = prevWordEndExclusive(text, cur.index, kind);
                        break;
                    }
                    if (cur.line == 0) break;
                    cur.line -= 1;
                    const pt = self.editor.lineSlice(cur.line);
                    if (pt.len == 0) continue;
                    // Land on the last word end of the previous line.
                    var best: ?usize = null;
                    var p: usize = 0;
                    while (p < pt.len) {
                        const e = nextWordEndInLine(pt, p, kind);
                        if (e <= p) break;
                        best = prevCharStart(pt, e);
                        if (e >= pt.len) break;
                        p = nextWordStartInLine(pt, e, kind);
                        if (p <= e) p = nextCharEnd(pt, e);
                        if (p >= pt.len) break;
                    }
                    if (best) |at| {
                        cur.index = at;
                        break;
                    }
                    continue;
                }
                self.editor.cursor = cur;
                self.editor.cursor_x_opt = null;
            },
        }
    }
};

/// Exclusive word-end strictly before `index` (single line helper for
/// `PreviousWordEnd`; returns 0 when none).
fn prevWordEndExclusive(text: []const u8, index: usize, kind: WordKind) usize {
    var best: usize = 0;
    var found = false;
    // Collect ends by scanning words from 0.
    var ends: [256]usize = undefined;
    var n: usize = 0;
    var pos: usize = 0;
    while (pos < text.len and n < ends.len) {
        pos = skipBlankForward(text, pos);
        if (pos >= text.len) break;
        const s = pos;
        var e: usize = s;
        if (kind == .big) {
            while (e < text.len and charIsWord(text, e, true)) e = nextCharEnd(text, e);
        } else {
            const cp = decodeAt(text, e) orelse break;
            if (isWordChar(cp)) {
                while (e < text.len) {
                    const c = decodeAt(text, e) orelse break;
                    if (!isWordChar(c)) break;
                    e = nextCharEnd(text, e);
                }
            } else if (!isBlankCp(cp)) {
                while (e < text.len) {
                    const c = decodeAt(text, e) orelse break;
                    if (isBlankCp(c) or isWordChar(c)) break;
                    e = nextCharEnd(text, e);
                }
            } else break;
        }
        if (e <= s) break;
        ends[n] = e;
        n += 1;
        pos = e;
        if (pos == 0) break;
    }
    for (ends[0..n]) |e| {
        if (e < index) {
            best = prevCharStart(text, e);
            found = true;
        }
    }
    return if (found) best else 0;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

fn expectText(ved: *const ViEditor, want: []const u8) !void {
    var t = try ved.fullText();
    defer t.deinit(ved.allocator);
    try std.testing.expectEqualStrings(want, t.items);
}

test "vi motions across lines" {
    const alloc = std.testing.allocator;
    var ved = try ViEditor.init(alloc);
    defer ved.deinit();
    try ved.setText("hello world\nfoo bar\nbaz");

    // w across words + line crossing.
    ved.setCursor(Cursor.init(0, 0));
    try ved.feedString("w");
    try std.testing.expectEqual(Cursor.init(0, 6), ved.cursor());
    try ved.feedString("w");
    try std.testing.expectEqual(Cursor.init(1, 0), ved.cursor());
    // b back across lines.
    try ved.feedString("b");
    try std.testing.expectEqual(Cursor.init(0, 6), ved.cursor());
    // e word end.
    ved.setCursor(Cursor.init(0, 0));
    try ved.feedString("e");
    // lands on last char of "hello" (index 4).
    try std.testing.expectEqual(Cursor.init(0, 4), ved.cursor());
    // j/k line crossing preserves column clamp.
    try ved.feedString("j");
    try std.testing.expectEqual(Cursor.init(1, 4), ved.cursor());
    try ved.feedString("k");
    try std.testing.expectEqual(Cursor.init(0, 4), ved.cursor());
    // $ and 0.
    try ved.feedString("$");
    try std.testing.expectEqual(Cursor.init(0, 11), ved.cursor());
    try ved.feedString("0");
    try std.testing.expectEqual(Cursor.init(0, 0), ved.cursor());
    // G / gg / H / M / L.
    try ved.feedString("G");
    try std.testing.expectEqual(@as(usize, 2), ved.cursor().line);
    try ved.feedString("gg");
    try std.testing.expectEqual(@as(usize, 0), ved.cursor().line);
    try ved.feedString("L");
    try std.testing.expectEqual(@as(usize, 2), ved.cursor().line);
    try ved.feedString("H");
    try std.testing.expectEqual(@as(usize, 0), ved.cursor().line);
    try ved.feedString("M");
    try std.testing.expectEqual(@as(usize, 1), ved.cursor().line);
    // f/t motions stay in line.
    ved.setCursor(Cursor.init(0, 0));
    try ved.feedString("fo");
    try std.testing.expectEqual(Cursor.init(0, 4), ved.cursor());
    ved.setCursor(Cursor.init(0, 0));
    try ved.feedString("to");
    // `to` lands one before `o` (index 3).
    try std.testing.expectEqual(Cursor.init(0, 3), ved.cursor());
}

test "vi yank put line vs normal" {
    const alloc = std.testing.allocator;
    var ved = try ViEditor.init(alloc);
    defer ved.deinit();
    try ved.setText("one\ntwo\nthree");
    // Line yank + put after.
    ved.setCursor(Cursor.init(0, 0));
    try ved.feedString("yy");
    ved.setCursor(Cursor.init(1, 0));
    try ved.feedString("p");
    try expectText(&ved, "one\ntwo\none\nthree");
    // Normal yank (yw) + put.
    try ved.setText("hello world");
    ved.setCursor(Cursor.init(0, 0));
    try ved.feedString("yw");
    ved.setCursor(Cursor.init(0, 6));
    try ved.feedString("P");
    try expectText(&ved, "hello hello world");
    // registers distinguish Line vs Normal selection kind.
    {
        const entry = ved.registers.get('"') orelse return error.TestUnexpectedResult;
        try std.testing.expect(entry.text.len > 0);
    }
    // dd deletes a whole line.
    try ved.setText("a\nb\nc");
    ved.setCursor(Cursor.init(1, 0));
    try ved.feedString("dd");
    try expectText(&ved, "a\nc");
    // dw deletes to next word start (vim parity: eats the space).
    try ved.setText("hello world");
    ved.setCursor(Cursor.init(0, 0));
    try ved.feedString("dw");
    try expectText(&ved, "world");
}

test "vi undo redo pivot to save_point" {
    const alloc = std.testing.allocator;
    var ved = try ViEditor.init(alloc);
    defer ved.deinit();
    try ved.setText("a");
    ved.savePoint();
    try std.testing.expect(!ved.changedFlag());
    // Insert b via insert mode.
    try ved.feedString("A");
    try ved.feedString("b");
    try ved.feedKey(.escape);
    try std.testing.expect(ved.changedFlag());
    try expectText(&ved, "ab");
    try ved.undo();
    try expectText(&ved, "a");
    // Back at save pivot → unchanged.
    try std.testing.expect(!ved.changedFlag());
    try ved.redo();
    try expectText(&ved, "ab");
    try std.testing.expect(ved.changedFlag());
    // New save point at ab.
    ved.savePoint();
    try std.testing.expect(!ved.changedFlag());
    // Delete word then undo past pivot marks changed.
    ved.setCursor(Cursor.init(0, 0));
    try ved.feedString("x");
    try expectText(&ved, "b");
    try std.testing.expect(ved.changedFlag());
    try ved.undo();
    try expectText(&ved, "ab");
    try std.testing.expect(!ved.changedFlag());
}

test "vi search forward backward" {
    const alloc = std.testing.allocator;
    var ved = try ViEditor.init(alloc);
    defer ved.deinit();
    try ved.setText("foo bar foo\nbaz foo");
    ved.setCursor(Cursor.init(0, 0));
    // Type /foo<Enter> (lands on next match after cursor).
    try ved.feedString("/foo");
    try ved.feedKey(.enter);
    try std.testing.expectEqual(Cursor.init(0, 8), ved.cursor());
    try ved.feedString("n");
    try std.testing.expectEqual(Cursor.init(1, 4), ved.cursor());
    try ved.feedString("N");
    try std.testing.expectEqual(Cursor.init(0, 8), ved.cursor());
    // Backward search ?bar lands before.
    ved.setCursor(Cursor.init(1, 4));
    try ved.feedString("?bar");
    try ved.feedKey(.enter);
    try std.testing.expectEqual(Cursor.init(0, 4), ved.cursor());
}

test "vi block cursor shape" {
    const alloc = std.testing.allocator;
    var ved = try ViEditor.init(alloc);
    defer ved.deinit();
    try std.testing.expect(ved.isBlockCursor());
    try std.testing.expectEqual(CursorShape.block, ved.cursorShape());
    try ved.feedString("i");
    try std.testing.expect(!ved.isBlockCursor());
    try std.testing.expectEqual(CursorShape.bar, ved.cursorShape());
    try ved.feedKey(.escape);
    try std.testing.expect(ved.isBlockCursor());
    ved.setPassthrough(true);
    try std.testing.expect(!ved.isBlockCursor());
    ved.setPassthrough(false);
    try ved.feedString("R");
    try std.testing.expect(!ved.isBlockCursor());
    try ved.feedKey(.escape);
    try ved.feedString("v");
    try std.testing.expect(ved.isBlockCursor());
    try ved.feedKey(.escape);
}

test "vi change operator enters insert" {
    const alloc = std.testing.allocator;
    var ved = try ViEditor.init(alloc);
    defer ved.deinit();
    try ved.setText("hello world");
    ved.setCursor(Cursor.init(0, 0));
    try ved.feedString("cw");
    try std.testing.expectEqual(ViMode.insert, ved.mode());
    try ved.feedString("XY");
    try ved.feedKey(.escape);
    try expectText(&ved, "XY world");
}

test "vi text objects paren and word" {
    const alloc = std.testing.allocator;
    var ved = try ViEditor.init(alloc);
    defer ved.deinit();
    try ved.setText("(hello world)");
    ved.setCursor(Cursor.init(0, 3));
    try ved.feedString("di(");
    try expectText(&ved, "()");
    try ved.setText("hello world");
    ved.setCursor(Cursor.init(0, 1));
    try ved.feedString("diw");
    try expectText(&ved, " world");
}
