//! Port of cosmic-text `edit/syntect.rs` (syntax highlighting editor) without
//! the `syntect` crate.
//!
//! Self-contained by design: defines minimal local `Cursor`, `Selection`,
//! `Change`, `Action`/`Motion`, `Color`, and `Editor` instead of importing
//! sibling cozmic modules (not yet unified). Unify these with the real
//! `edit.zig` / `buffer.zig` types later; keep this file compiling standalone
//! until then.
//! TODO(unify): replace local `Editor`/`Cursor`/`Selection`/`Change` with
//! `edit.zig` imports once cross-file unification lands.
//!
//! Divergence from the oracle:
//!   * `syntect::SyntaxSet`/`ThemeSet`/`ParseState`/`ScopeStack`/
//!     `Highlighter` are stubbed (`SyntaxSystem`, `ParseState`,
//!     `ScopeStack`, `Highlighter`). Highlighting is a deterministic hash of
//!     (prev_state, line text, syntax) rather than real grammar parsing.
//!     This preserves the incremental invariants under test (metadata skip,
//!     reset-next-line cascade, theme/syntax invalidation) without the
//!     dependency.
//!   * `shape_as_needed` returns the highlighted line count for testability
//!     (the oracle returns `()` and only sets redraw).
//!   * File loading takes an explicit `std.Io` + `std.Io.Dir` (Zig 0.17 has no
//!     ambient cwd); the oracle takes `AsRef<Path>` with ambient fs.
//!
//! Tree-sitter replacement point: swap `SyntaxSystem` + `ParseState` for a
//! tree-sitter grammar set and per-line parse trees; keep the
//! `syntax_cache: ArrayList(CacheEntry)` + `metadata: ?usize` cascade shape
//! (only the `parseLine` hash needs replacing).
//!
//! Feature gating (resolved): the parent build wires `build_options.syntect`
//! and `root.zig` applies it — `cozmic.syntect` only exposes this file when
//! `-Dsyntect=true` (default off; the root otherwise exports a disabled
//! stub), so the unfinished syntax layer cannot be depended on by accident.
//! This file still compiles standalone via `zig test src/syntect.zig` without
//! that module, which is why `syntect_enabled` below stays a plain constant:
//! it reports *feature readiness* (false while the TODOs above remain), not
//! build exposure.

const std = @import("std");

const Allocator = std.mem.Allocator;

/// Compile-time feature flag placeholder (see module docs).
pub const syntect_enabled: bool = false;

pub const Error = Allocator.Error || error{
    InvalidCursor,
    InvalidByteIndex,
    ChangeInProgress,
    ThemeNotFound,
    FileTooLarge,
};

// ---------------------------------------------------------------------------
// Minimal local aliases (unify with edit.zig later)
// ---------------------------------------------------------------------------

pub const Color = u32;

pub fn rgb(r: u8, g: u8, b: u8) Color {
    return (@as(u32, 0xFF) << 24) | (@as(u32, r) << 16) | (@as(u32, g) << 8) | b;
}

pub fn rgba(r: u8, g: u8, b: u8, a: u8) Color {
    return (@as(u32, a) << 24) | (@as(u32, r) << 16) | (@as(u32, g) << 8) | b;
}

pub const Cursor = struct {
    line: usize = 0,
    index: usize = 0,

    pub fn init(line: usize, index: usize) Cursor {
        return .{ .line = line, .index = index };
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
};

pub const Motion = union(enum) {
    left,
    right,
    up,
    down,
    home,
    end,
    goto_line: usize,
};

pub const Action = union(enum) {
    motion: Motion,
    escape: void,
    insert: u21,
    enter: void,
    backspace: void,
    delete: void,
};

// ---------------------------------------------------------------------------
// UTF-8 helpers
// ---------------------------------------------------------------------------

fn cpLen(first_byte: u8) usize {
    const l: u3 = std.unicode.utf8ByteSequenceLength(first_byte) catch return 1;
    return @as(usize, l);
}

fn isContinuation(b: u8) bool {
    return (b & 0xC0) == 0x80;
}

fn isBoundary(text: []const u8, index: usize) bool {
    if (index == 0 or index == text.len) return true;
    if (index > text.len) return false;
    return !isContinuation(text[index]);
}

fn prevCharStart(text: []const u8, index: usize) usize {
    var i = @min(index, text.len);
    if (i == 0) return 0;
    i -= 1;
    while (i > 0 and isContinuation(text[i])) : (i -= 1) {}
    return i;
}

fn nextCharEnd(text: []const u8, index: usize) usize {
    if (index >= text.len) return text.len;
    return @min(index + cpLen(text[index]), text.len);
}

// ---------------------------------------------------------------------------
// Local minimal editor (ArrayList lines with syntect metadata)
// ---------------------------------------------------------------------------

pub const Line = struct {
    text: std.ArrayList(u8),
    /// Cache index when highlighted, null when dirty. Mirrors
    /// `BufferLine::metadata` in the oracle.
    metadata: ?usize = null,
    /// Stub per-line foreground (reset on theme switch).
    fg: Color = 0xFFFFFFFF,

    pub fn deinit(self: *Line, allocator: Allocator) void {
        self.text.deinit(allocator);
        self.* = undefined;
    }

    pub fn slice(self: *const Line) []const u8 {
        return self.text.items;
    }

    /// Reset layout/highlight state (mirrors `BufferLine::reset`).
    pub fn reset(self: *Line) void {
        self.metadata = null;
    }
};

pub const Editor = struct {
    allocator: Allocator,
    lines: std.ArrayList(Line),
    cursor: Cursor,
    selection: Selection,
    change: ?Change,

    pub fn init(allocator: Allocator) Allocator.Error!Editor {
        var self = Editor{ .allocator = allocator, .lines = .empty, .cursor = .{}, .selection = .{ .none = {} }, .change = null };
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

    fn clampCursor(self: *const Editor, c: Cursor) Cursor {
        if (self.lines.items.len == 0) return Cursor.init(0, 0);
        const line = @min(c.line, self.lines.items.len - 1);
        return Cursor.init(line, @min(c.index, self.lines.items[line].slice().len));
    }

    /// Replace all text (clears highlight metadata; caller clears syntect
    /// cache when replacing wholesale).
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
        self.cursor = .{};
        self.selection = .{ .none = {} };
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
                return .{ .start = Cursor.init(s, 0), .end = Cursor.init(e, self.lines.items[e].slice().len) };
            },
            .word => |sel| {
                return switch (Cursor.order(sel, cur)) {
                    .gt => .{ .start = cur, .end = sel },
                    else => .{ .start = sel, .end = cur },
                };
            },
        }
    }

    /// Invalidate highlight metadata for `line` and all lines after it.
    /// Used by wholesale edits; single-line inserts/deletes below only clear
    /// the touched line so the cascade invariant is exercised by
    /// `shapeAsNeeded`.
    pub fn clearMetadataFrom(self: *Editor, line: usize) void {
        var i = line;
        while (i < self.lines.items.len) : (i += 1) {
            self.lines.items[i].reset();
        }
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

        var text: std.ArrayList(u8) = .empty;
        errdefer text.deinit(self.allocator);
        if (start.line == end.line) {
            const l = self.lines.items[start.line].slice();
            try text.appendSlice(self.allocator, l[start.index..end.index]);
            try self.lines.items[start.line].text.replaceRange(self.allocator, start.index, end.index - start.index, "");
            self.lines.items[start.line].reset();
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
            self.lines.items[start.line].text.shrinkRetainingCapacity(start.index);
            try self.lines.items[start.line].text.appendSlice(self.allocator, last[end.index..]);
            var k = end.line;
            while (k > start.line) : (k -= 1) {
                var removed = self.lines.orderedRemove(k);
                removed.deinit(self.allocator);
            }
            self.lines.items[start.line].reset();
        }
        if (self.change) |*c| {
            try c.items.append(self.allocator, .{ .start = start, .end = end, .text = text, .insert = false });
        } else {
            text.deinit(self.allocator);
        }
        self.cursor = start;
    }

    pub fn insertAt(self: *Editor, cursor_in: Cursor, data: []const u8) Error!Cursor {
        if (data.len == 0) return self.clampCursor(cursor_in);
        var cursor = self.clampCursor(cursor_in);
        if (!isBoundary(self.lines.items[cursor.line].slice(), cursor.index)) return error.InvalidByteIndex;
        const start = cursor;
        const tail = try self.allocator.dupe(u8, self.lines.items[cursor.line].slice()[cursor.index..]);
        defer self.allocator.free(tail);
        self.lines.items[cursor.line].text.shrinkRetainingCapacity(cursor.index);
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
        try self.lines.items[cursor.line].text.appendSlice(self.allocator, parts.items[0]);
        self.lines.items[cursor.line].reset();
        var li = cursor.line;
        var idx: usize = 1;
        while (idx < parts.items.len) : (idx += 1) {
            var nl = Line{ .text = .empty };
            errdefer nl.deinit(self.allocator);
            try nl.text.appendSlice(self.allocator, parts.items[idx]);
            try self.lines.insert(self.allocator, li + 1, nl);
            li += 1;
        }
        try self.lines.items[li].text.appendSlice(self.allocator, tail);
        // Newly inserted lines start dirty (metadata null by construction).
        cursor.line = li;
        cursor.index = self.lines.items[li].slice().len - tail.len;
        if (self.change) |*c| {
            var owned: std.ArrayList(u8) = .empty;
            errdefer owned.deinit(self.allocator);
            try owned.appendSlice(self.allocator, data);
            try c.items.append(self.allocator, .{ .start = start, .end = cursor, .text = owned, .insert = true });
        }
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

    pub fn action(self: *Editor, act: Action) Error!void {
        switch (act) {
            .motion => |m| {
                var cur = self.clampCursor(self.cursor);
                switch (m) {
                    .left => {
                        if (cur.index > 0) {
                            cur.index = prevCharStart(self.lineSlice(cur.line), cur.index);
                        } else if (cur.line > 0) {
                            cur.line -= 1;
                            cur.index = self.lineSlice(cur.line).len;
                        }
                    },
                    .right => {
                        const t = self.lineSlice(cur.line);
                        if (cur.index < t.len) {
                            cur.index = nextCharEnd(t, cur.index);
                        } else if (cur.line + 1 < self.lines.items.len) {
                            cur.line += 1;
                            cur.index = 0;
                        }
                    },
                    .up => {
                        if (cur.line > 0) {
                            cur.line -= 1;
                            cur.index = @min(cur.index, self.lineSlice(cur.line).len);
                        }
                    },
                    .down => {
                        if (cur.line + 1 < self.lines.items.len) {
                            cur.line += 1;
                            cur.index = @min(cur.index, self.lineSlice(cur.line).len);
                        }
                    },
                    .home => {
                        cur.index = 0;
                    },
                    .end => {
                        cur.index = self.lineSlice(cur.line).len;
                    },
                    .goto_line => |goal| {
                        cur.line = @min(goal, self.lines.items.len - 1);
                        cur.index = @min(cur.index, self.lineSlice(cur.line).len);
                    },
                }
                self.cursor = cur;
            },
            .escape => {
                self.selection = .{ .none = {} };
            },
            .insert => |cp| {
                if (cp == '\n') {
                    try self.action(.enter);
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
                        self.cursor.index = prevCharStart(self.lineSlice(self.cursor.line), self.cursor.index);
                    } else if (self.cursor.line > 0) {
                        self.cursor.line -= 1;
                        self.cursor.index = self.lineSlice(self.cursor.line).len;
                    }
                    if (!std.meta.eql(self.cursor, end)) try self.deleteRange(self.cursor, end);
                }
            },
            .delete => {
                if (!(try self.deleteSelection())) {
                    const start = self.cursor;
                    var end = self.cursor;
                    const t = self.lineSlice(start.line);
                    if (start.index < t.len) {
                        end.index = nextCharEnd(t, start.index);
                    } else if (start.line + 1 < self.lines.items.len) {
                        end.line += 1;
                        end.index = 0;
                    }
                    if (!std.meta.eql(start, end)) try self.deleteRange(start, end);
                }
            },
        }
    }
};

// ---------------------------------------------------------------------------
// Syntax stub (syntect parity, dependency-free)
// ---------------------------------------------------------------------------

/// Stub syntax definition (extension → name). The oracle resolves real
/// grammars via `SyntaxSet`; this keeps static names for the fallback and a
/// few common extensions.
/// TODO(tree-sitter): replace with tree-sitter language packs.
pub const Syntax = struct {
    name: []const u8,
    extensions: []const []const u8,

    pub fn matchesExtension(self: *const Syntax, ext: []const u8) bool {
        for (self.extensions) |e| {
            if (std.ascii.eqlIgnoreCase(e, ext)) return true;
        }
        return false;
    }
};

/// Stub theme (subset of `syntect::highlighting::Theme` settings used for
/// editor colors).
pub const Theme = struct {
    name: []const u8,
    background: Color,
    foreground: Color,
    caret: Color,
    selection: Color,
};

const builtin_syntaxes: []const Syntax = &.{
    .{ .name = "Plain Text", .extensions = &.{ "txt", "text" } },
    .{ .name = "Rust", .extensions = &.{"rs"} },
    .{ .name = "Zig", .extensions = &.{"zig"} },
    .{ .name = "Python", .extensions = &.{"py"} },
    .{ .name = "Markdown", .extensions = &.{ "md", "markdown" } },
};

const builtin_themes: []const Theme = &.{
    .{ .name = "base16-eighties.dark", .background = rgb(0x2D, 0x2D, 0x2D), .foreground = rgb(0xF2, 0xF0, 0xEC), .caret = rgb(0xF2, 0xF0, 0xEC), .selection = rgba(0xF2, 0xF0, 0xEC, 0x33) },
    .{ .name = "InspiredGitHub", .background = rgb(0xFF, 0xFF, 0xFF), .foreground = rgb(0x33, 0x33, 0x33), .caret = rgb(0x33, 0x33, 0x33), .selection = rgba(0x33, 0x33, 0x33, 0x33) },
    .{ .name = "Solarized (dark)", .background = rgb(0x00, 0x2B, 0x36), .foreground = rgb(0x83, 0x94, 0x96), .caret = rgb(0x83, 0x94, 0x96), .selection = rgba(0x83, 0x94, 0x96, 0x33) },
};

pub const SyntaxSystem = struct {
    allocator: Allocator,
    syntaxes: std.ArrayList(Syntax),
    themes: std.ArrayList(Theme),

    pub fn init(allocator: Allocator) SyntaxSystem {
        return .{ .allocator = allocator, .syntaxes = .empty, .themes = .empty };
    }

    pub fn deinit(self: *SyntaxSystem) void {
        self.syntaxes.deinit(self.allocator);
        self.themes.deinit(self.allocator);
        self.* = undefined;
    }

    /// Load the stub defaults (plain + a few languages, three themes).
    /// Mirrors `SyntaxSet::load_defaults_nonewlines` +
    /// `ThemeSet::load_defaults` for the names tests rely on.
    pub fn loadDefaults(self: *SyntaxSystem) Allocator.Error!void {
        self.syntaxes.clearRetainingCapacity();
        self.themes.clearRetainingCapacity();
        try self.syntaxes.appendSlice(self.allocator, builtin_syntaxes);
        try self.themes.appendSlice(self.allocator, builtin_themes);
    }

    pub fn findSyntaxPlainText(self: *const SyntaxSystem) *const Syntax {
        // Plain text is always first after loadDefaults; fall back to the
        // builtin static when the system is empty (tests may skip loading).
        if (self.syntaxes.items.len > 0) return &self.syntaxes.items[0];
        return &builtin_syntaxes[0];
    }

    pub fn findSyntaxByExtension(self: *const SyntaxSystem, ext: []const u8) ?*const Syntax {
        for (self.syntaxes.items) |*s| {
            if (s.matchesExtension(ext)) return s;
        }
        for (builtin_syntaxes) |*s| {
            if (s.matchesExtension(ext)) return s;
        }
        return null;
    }

    pub fn findSyntaxForFile(self: *const SyntaxSystem, path: []const u8) *const Syntax {
        const ext = std.fs.path.extension(path);
        const trimmed = if (ext.len > 0 and ext[0] == '.') ext[1..] else ext;
        if (trimmed.len > 0) {
            if (self.findSyntaxByExtension(trimmed)) |s| return s;
        }
        return self.findSyntaxPlainText();
    }

    pub fn themeByName(self: *const SyntaxSystem, name: []const u8) ?*const Theme {
        for (self.themes.items) |*t| {
            if (std.mem.eql(u8, t.name, name)) return t;
        }
        for (builtin_themes) |*t| {
            if (std.mem.eql(u8, t.name, name)) return t;
        }
        return null;
    }

    pub fn themeNames(self: *const SyntaxSystem) []const Theme {
        if (self.themes.items.len > 0) return self.themes.items;
        return builtin_themes;
    }
};

/// Stub parse state (replacement point for `syntect::parsing::ParseState`).
/// `state` chains the previous line's state with the current line hash so an
/// edit on line N changes line N's entry and cascades to N+1…
pub const ParseState = struct {
    syntax_id: usize,
    state: u64,

    pub fn eql(a: ParseState, b: ParseState) bool {
        return a.syntax_id == b.syntax_id and a.state == b.state;
    }
};

/// Stub scope stack (replacement point for `ScopeStack`; depth only).
pub const ScopeStack = struct {
    depth: usize,

    pub fn eql(a: ScopeStack, b: ScopeStack) bool {
        return a.depth == b.depth;
    }
};

pub const CacheEntry = struct {
    parse_state: ParseState,
    scopes: ScopeStack,

    pub fn eql(a: CacheEntry, b: CacheEntry) bool {
        return a.parse_state.eql(b.parse_state) and a.scopes.eql(b.scopes);
    }
};

/// Stub highlighter (replacement point for `syntect::highlighting::Highlighter`).
pub const Highlighter = struct {
    theme: Theme,
};

fn hashLine(prev: u64, syntax_id: usize, text: []const u8) u64 {
    var h = std.hash.Wyhash.init(prev ^ @as(u64, syntax_id) * 0x9E3779B97F4A7C15);
    h.update(text);
    h.update(&.{0xFF});
    return h.final();
}

fn syntaxId(system: *const SyntaxSystem, syntax: *const Syntax) usize {
    for (system.syntaxes.items, 0..) |*s, i| {
        if (s.name.ptr == syntax.name.ptr and s.name.len == syntax.name.len) return i;
    }
    for (builtin_syntaxes, 0..) |*s, i| {
        if (std.mem.eql(u8, s.name, syntax.name)) return 1000 + i;
    }
    return 0;
}

// ---------------------------------------------------------------------------
// SyntaxEditor (delegates Edit to the inner editor)
// ---------------------------------------------------------------------------

pub const SyntaxEditor = struct {
    allocator: Allocator,
    editor: Editor,
    system: *const SyntaxSystem,
    syntax: *const Syntax,
    theme: Theme,
    highlighter: Highlighter,
    syntax_cache: std.ArrayList(CacheEntry),

    /// Create with `theme_name` (a good default is "base16-eighties.dark").
    /// Returns `error.ThemeNotFound` when the theme is missing (the oracle
    /// returns `None`).
    pub fn init(allocator: Allocator, system: *const SyntaxSystem, theme_name: []const u8) (Allocator.Error || Error)!SyntaxEditor {
        const theme = system.themeByName(theme_name) orelse return error.ThemeNotFound;
        var self = SyntaxEditor{
            .allocator = allocator,
            .editor = try Editor.init(allocator),
            .system = system,
            .syntax = system.findSyntaxPlainText(),
            .theme = theme.*,
            .highlighter = .{ .theme = theme.* },
            .syntax_cache = .empty,
        };
        errdefer self.deinit();
        self.applyThemeToLines();
        return self;
    }

    pub fn deinit(self: *SyntaxEditor) void {
        self.syntax_cache.deinit(self.allocator);
        self.editor.deinit();
        self.* = undefined;
    }

    fn applyThemeToLines(self: *SyntaxEditor) void {
        for (self.editor.lines.items) |*l| l.fg = self.theme.foreground;
    }

    pub fn syntaxName(self: *const SyntaxEditor) []const u8 {
        return self.syntax.name;
    }

    pub fn themeName(self: *const SyntaxEditor) []const u8 {
        return self.theme.name;
    }

    pub fn cacheLen(self: *const SyntaxEditor) usize {
        return self.syntax_cache.items.len;
    }

    /// Switch theme; false when missing (no state changed). Clears the cache
    /// and resets line attrs/metadata on success (oracle parity).
    pub fn updateTheme(self: *SyntaxEditor, theme_name: []const u8) bool {
        const found = self.system.themeByName(theme_name) orelse return false;
        if (std.mem.eql(u8, found.name, self.theme.name)) return true;
        self.theme = found.*;
        self.highlighter = .{ .theme = found.* };
        self.syntax_cache.clearRetainingCapacity();
        for (self.editor.lines.items) |*l| {
            l.reset();
            l.fg = self.theme.foreground;
        }
        return true;
    }

    /// Select syntax by extension; unknown extensions fall back to plain
    /// text (oracle logs a warning). Clears the cache.
    pub fn syntaxByExtension(self: *SyntaxEditor, ext: []const u8) void {
        if (self.system.findSyntaxByExtension(ext)) |s| {
            self.syntax = s;
        } else {
            self.syntax = self.system.findSyntaxPlainText();
        }
        self.syntax_cache.clearRetainingCapacity();
    }

    /// Replace all text and clear the cache (wholesale `set_text` parity).
    pub fn setText(self: *SyntaxEditor, text: []const u8) Allocator.Error!void {
        try self.editor.setText(text);
        self.syntax_cache.clearRetainingCapacity();
        self.applyThemeToLines();
    }

    pub fn fullText(self: *const SyntaxEditor) Allocator.Error!std.ArrayList(u8) {
        return self.editor.fullText();
    }

    /// Load text from `dir`/`path`, selecting syntax by file name (fallback
    /// plain). Clears the buffer first so a missing file leaves an empty
    /// buffer (oracle parity), then returns the IO error.
    pub fn loadText(self: *SyntaxEditor, io: std.Io, dir: std.Io.Dir, path: []const u8) (Allocator.Error || Error || std.Io.Dir.ReadFileAllocError)!void {
        try self.editor.setText("");
        self.syntax = self.system.findSyntaxForFile(path);
        self.syntax_cache.clearRetainingCapacity();
        const bytes = try dir.readFileAlloc(io, path, self.allocator, .limited(16 * 1024 * 1024));
        defer self.allocator.free(bytes);
        try self.editor.setText(bytes);
        self.applyThemeToLines();
    }

    // -- Edit delegation (oracle `impl Edit for SyntaxEditor`) -------------

    pub fn cursor(self: *const SyntaxEditor) Cursor {
        return self.editor.cursor;
    }

    pub fn setCursor(self: *SyntaxEditor, c: Cursor) void {
        self.editor.cursor = self.editor.clampCursor(c);
    }

    pub fn selection(self: *const SyntaxEditor) Selection {
        return self.editor.selection;
    }

    pub fn setSelection(self: *SyntaxEditor, s: Selection) void {
        self.editor.selection = s;
    }

    pub fn selectionBounds(self: *const SyntaxEditor) ?SelectionBounds {
        return self.editor.selectionBounds();
    }

    pub fn deleteRange(self: *SyntaxEditor, start: Cursor, end: Cursor) Error!void {
        try self.editor.deleteRange(start, end);
    }

    pub fn insertAt(self: *SyntaxEditor, at: Cursor, data: []const u8) Error!Cursor {
        return self.editor.insertAt(at, data);
    }

    pub fn copySelection(self: *const SyntaxEditor) Error!?std.ArrayList(u8) {
        return self.editor.copySelection();
    }

    pub fn deleteSelection(self: *SyntaxEditor) Error!bool {
        return self.editor.deleteSelection();
    }

    pub fn insertString(self: *SyntaxEditor, data: []const u8) Error!void {
        try self.editor.insertString(data);
    }

    pub fn applyChange(self: *SyntaxEditor, change: *const Change) Error!bool {
        return self.editor.applyChange(change);
    }

    pub fn startChange(self: *SyntaxEditor) void {
        self.editor.startChange();
    }

    pub fn finishChange(self: *SyntaxEditor) ?Change {
        return self.editor.finishChange();
    }

    pub fn action(self: *SyntaxEditor, act: Action) Error!void {
        try self.editor.action(act);
    }

    // -- Colors (oracle theme accessors) ------------------------------------

    pub fn backgroundColor(self: *const SyntaxEditor) Color {
        return self.theme.background;
    }

    pub fn foregroundColor(self: *const SyntaxEditor) Color {
        return self.theme.foreground;
    }

    pub fn cursorColor(self: *const SyntaxEditor) Color {
        return self.theme.caret;
    }

    pub fn selectionColor(self: *const SyntaxEditor) Color {
        return self.theme.selection;
    }

    // -- Incremental highlighting --------------------------------------------

    /// Highlight lines as needed, preserving the oracle's cascade invariant:
    /// lines with `metadata != null` and `line_i < cache.len()` are skipped;
    /// otherwise the line is (re)parsed from the previous cache entry, and
    /// when the new entry differs the next line is `reset()` so it
    /// re-highlights on this same pass.
    ///
    /// Returns the highlighted line count (oracle returns `()`).
    pub fn shapeAsNeeded(self: *SyntaxEditor) Allocator.Error!usize {
        const sid = syntaxId(self.system, self.syntax);
        var highlighted: usize = 0;
        var line_i: usize = 0;
        while (line_i < self.editor.lines.items.len) : (line_i += 1) {
            const line = &self.editor.lines.items[line_i];
            if (line.metadata != null and line_i < self.syntax_cache.items.len) {
                continue;
            }
            highlighted += 1;

            const prev_state: u64 = if (line_i > 0 and line_i - 1 < self.syntax_cache.items.len)
                self.syntax_cache.items[line_i - 1].parse_state.state
            else
                0;
            const new_state = hashLine(prev_state, sid, line.slice());
            // Depth placeholder: nesting level from bracket balance.
            var depth: usize = 0;
            for (line.slice()) |b| {
                if (b == '{' or b == '(' or b == '[') depth += 1;
            }
            const entry = CacheEntry{
                .parse_state = .{ .syntax_id = sid, .state = new_state },
                .scopes = .{ .depth = depth },
            };

            // Stub attr update: tint foreground by hash (tests only check the
            // cache/metadata invariant, not colors).
            line.fg = self.theme.foreground ^ @as(u32, @truncate(new_state));

            if (line_i < self.syntax_cache.items.len) {
                if (!self.syntax_cache.items[line_i].eql(entry)) {
                    self.syntax_cache.items[line_i] = entry;
                    if (line_i + 1 < self.editor.lines.items.len) {
                        self.editor.lines.items[line_i + 1].reset();
                    }
                }
                // Mark clean so shaping is idempotent. The oracle leaves
                // reset-then-reparsed lines dirty (`metadata == None`), which
                // re-highlights every pass; we re-mark to preserve the
                // skip-fast-path invariant under test.
                line.metadata = line_i;
            } else {
                line.metadata = self.syntax_cache.items.len;
                try self.syntax_cache.append(self.allocator, entry);
            }
        }
        return highlighted;
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "syntect cache invalidation cascade" {
    const alloc = std.testing.allocator;
    var system = SyntaxSystem.init(alloc);
    defer system.deinit();
    try system.loadDefaults();

    var ed = try SyntaxEditor.init(alloc, &system, "base16-eighties.dark");
    defer ed.deinit();
    try ed.setText("fn a() {\nfoo();\n}");
    const first = try ed.shapeAsNeeded();
    try std.testing.expectEqual(@as(usize, 3), first);
    try std.testing.expectEqual(@as(usize, 3), ed.cacheLen());
    const snap0 = try alloc.dupe(CacheEntry, ed.syntax_cache.items);
    defer alloc.free(snap0);

    // Re-shape with no edits: everything skipped.
    const second = try ed.shapeAsNeeded();
    try std.testing.expectEqual(@as(usize, 0), second);

    // Edit line 0: its entry must change and lines 1.. must cascade.
    _ = try ed.editor.insertAt(Cursor.init(0, 0), "// ");
    const third = try ed.shapeAsNeeded();
    try std.testing.expect(third >= 2);
    try std.testing.expect(!ed.syntax_cache.items[0].eql(snap0[0]));
    // Cascade: line 1 re-parsed because line 0 changed (prev-state chained).
    try std.testing.expect(!ed.syntax_cache.items[1].eql(snap0[1]));
    try std.testing.expect(!ed.syntax_cache.items[2].eql(snap0[2]));
    // All lines carry metadata after shaping.
    for (ed.editor.lines.items) |*l| {
        try std.testing.expect(l.metadata != null);
    }
}

test "syntect theme switch clears" {
    const alloc = std.testing.allocator;
    var system = SyntaxSystem.init(alloc);
    defer system.deinit();
    try system.loadDefaults();

    var ed = try SyntaxEditor.init(alloc, &system, "base16-eighties.dark");
    defer ed.deinit();
    try ed.setText("hello\nworld");
    _ = try ed.shapeAsNeeded();
    try std.testing.expectEqual(@as(usize, 2), ed.cacheLen());
    try std.testing.expect(ed.updateTheme("InspiredGitHub"));
    try std.testing.expectEqual(@as(usize, 0), ed.cacheLen());
    for (ed.editor.lines.items) |*l| {
        try std.testing.expect(l.metadata == null);
    }
    const n = try ed.shapeAsNeeded();
    try std.testing.expectEqual(@as(usize, 2), n);
    // Same theme: no clear.
    try std.testing.expect(ed.updateTheme("InspiredGitHub"));
    try std.testing.expectEqual(@as(usize, 2), ed.cacheLen());
    // Missing theme: false, state unchanged.
    try std.testing.expect(!ed.updateTheme("no-such-theme"));
    try std.testing.expectEqual(@as(usize, 2), ed.cacheLen());
}

test "syntect load_text fallback plain" {
    const alloc = std.testing.allocator;
    const io = std.testing.io;
    var system = SyntaxSystem.init(alloc);
    defer system.deinit();
    try system.loadDefaults();

    var ed = try SyntaxEditor.init(alloc, &system, "base16-eighties.dark");
    defer ed.deinit();

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{ .sub_path = "note.unknownext", .data = "hello\nworld" });
    try ed.loadText(io, tmp.dir, "note.unknownext");
    try std.testing.expectEqualStrings("Plain Text", ed.syntaxName());
    var t = try ed.fullText();
    defer t.deinit(alloc);
    try std.testing.expectEqualStrings("hello\nworld", t.items);
    const n = try ed.shapeAsNeeded();
    try std.testing.expectEqual(@as(usize, 2), n);

    // Known extension selects that syntax.
    try tmp.dir.writeFile(io, .{ .sub_path = "main.rs", .data = "fn main() {}" });
    try ed.loadText(io, tmp.dir, "main.rs");
    try std.testing.expectEqualStrings("Rust", ed.syntaxName());

    // Missing file: buffer cleared, error returned.
    const res = ed.loadText(io, tmp.dir, "missing.rs");
    try std.testing.expectError(error.FileNotFound, res);
    var t2 = try ed.fullText();
    defer t2.deinit(alloc);
    try std.testing.expectEqualStrings("", t2.items);
}

test "syntect delegates edit to inner editor" {
    const alloc = std.testing.allocator;
    var system = SyntaxSystem.init(alloc);
    defer system.deinit();
    try system.loadDefaults();

    var ed = try SyntaxEditor.init(alloc, &system, "base16-eighties.dark");
    defer ed.deinit();
    try ed.setText("ab");
    ed.setCursor(Cursor.init(0, 1));
    try ed.action(.{ .insert = 'X' });
    var t = try ed.fullText();
    defer t.deinit(alloc);
    try std.testing.expectEqualStrings("aXb", t.items);
    try std.testing.expectEqualStrings("base16-eighties.dark", ed.themeName());
    try std.testing.expect(ed.backgroundColor() != 0);
}
