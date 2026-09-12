//! Port of cosmic-text `edit/mod.rs` + `edit/editor.rs` (editable buffer).
//!
//! Connected to the canonical subsystem types (ownership map in
//! `types.zig`): `cursor.zig` (`Cursor`/`Affinity`/`Motion`/`Scroll`),
//! `line_ending.zig`, `attrs.zig` (`Attrs`/`AttrsList`), `layout.zig`,
//! `font_system.zig`, and `buffer.zig` (`Buffer`/`BufferLine`). This file owns
//! only `Editor`, `Selection`, `Change`, `ChangeItem`, `Action`, and
//! `BufferRef`.
//!
//! Grapheme correctness: Backspace/Delete, the Previous/Next (and Left/Right)
//! cursor motions, and hit testing all step UAX #29 grapheme clusters through
//! `unicode.zig` (`prevGraphemeStart`, `nextGraphemeEnd`, `graphemeIndices`,
//! `isGraphemeBoundary`). Word motions and word selection expansion use
//! `unicode.wordBounds` (UAX #29 WB), and indent/auto-indent whitespace uses
//! `unicode.isWhitespace`.
//!
//! Preserved exactly from the Rust original:
//!   * `delete_range` split/append ending preservation + undo-text assembly
//!     (removed line texts joined by their endings);
//!   * `insert_at` line ensuring, `after` split, `final_attrs` from span-1,
//!     first/middle/last distribution with `remaining_split_len` bookkeeping,
//!     and cursor landing (`len - after_len`);
//!   * `selection_bounds` for Normal/Line/Word (word expansion via UAX #29
//!     word starts/ends);
//!   * `action` dispatch: Insert control filtering (`\t`, `\n`, U+0092
//!     allowed), Enter auto-indent, Backspace/Delete grapheme joining,
//!     Indent/Unindent `tab_width` math, Click/DoubleClick/TripleClick/Drag
//!     selection modes, Scroll;
//!   * `shape_as_needed` `cursor_moved` branch, now calling the real
//!     `Buffer.shapeUntilCursor`/`shapeUntilScroll` with the real FontSystem;
//!   * `action` motions through `Buffer.cursorMotion` (real layout cursors,
//!     RTL mirroring, viewport-height paging) with `cursor_x_opt` preserved
//!     across vertical motion;
//!   * click/double/triple/drag through `Buffer.shapeUntilScroll` +
//!     `Buffer.hit`, double-click selecting the word and triple-click the
//!     line at the hit cursor;
//!   * `cursor_position` through `Buffer.cursorPosition`, so caret geometry
//!     matches `Editor.render`'s layout runs;
//!   * `Action::Scroll` through `Buffer.setScroll`, and `Action::Enter`
//!     laying out the affected line (`Buffer.lineLayout`).
//! TODO(vi/syntect): feature-gated editors.

const std = @import("std");

const Allocator = std.mem.Allocator;

const attrs = @import("attrs.zig");
const cursor_mod = @import("cursor.zig");
const line_ending = @import("line_ending.zig");
const layout = @import("layout.zig");
const render_mod = @import("render.zig");
const swash_cache_mod = @import("swash_cache.zig");
const font_system = @import("font_system.zig");
const font_mod = @import("font.zig");
const buffer_mod = @import("buffer.zig");
const buffer_line_mod = @import("buffer_line.zig");
const unicode = @import("unicode.zig");

/// Local error set: allocator failures plus the canonical buffer/shaper
/// errors this module can surface, plus editor-only errors (no panics).
pub const Error = buffer_mod.Error || error{
    InvalidData,
    ChangeInProgress,
};

// ---------------------------------------------------------------------------
// Canonical type aliases (no local stand-ins; see `types.zig`)
// ---------------------------------------------------------------------------

pub const LineEnding = line_ending.LineEnding;
pub const LineIter = line_ending.LineIter;
pub const Line = line_ending.Line;

pub const Affinity = cursor_mod.Affinity;
pub const Cursor = cursor_mod.Cursor;
pub const LayoutCursor = cursor_mod.LayoutCursor;
pub const Motion = cursor_mod.Motion;
pub const Scroll = cursor_mod.Scroll;

pub const Attrs = attrs.Attrs;
pub const AttrsList = attrs.AttrsList;

pub const FontSystem = font_system.FontSystem;

pub const Buffer = buffer_mod.Buffer;
/// Canonical owner of `BufferLine` is `buffer_line.zig` (re-exported here so
/// `edit` consumers use one import).
pub const BufferLine = buffer_line_mod.BufferLine;

/// Re-export the canonical laid-out line type (`layout.zig` owns it) so edit
/// consumers do not need a second import.
pub const LayoutLine = layout.LayoutLine;

/// A `Buffer` that the editor either owns or borrows, mirroring the Rust
/// `BufferRef`.
pub const BufferRef = union(enum) {
    /// The editor owns (and deinitializes) this buffer.
    owned: Buffer,
    /// The editor mutates a caller-owned buffer and must not deinit it.
    borrowed: *Buffer,

    /// Borrow the underlying buffer.
    pub fn get(self: *const BufferRef) *const Buffer {
        return switch (self.*) {
            .owned => &self.owned,
            .borrowed => self.borrowed,
        };
    }

    /// Mutably borrow the underlying buffer.
    pub fn getMut(self: *BufferRef) *Buffer {
        return switch (self.*) {
            .owned => &self.owned,
            .borrowed => self.borrowed,
        };
    }

    pub fn isOwned(self: *const BufferRef) bool {
        return self.* == .owned;
    }

    /// Deinitialize the buffer only when this ref owns it.
    pub fn deinit(self: *BufferRef) void {
        switch (self.*) {
            .owned => self.owned.deinit(),
            .borrowed => {},
        }
    }
};

// ---------------------------------------------------------------------------
// Selection, changes, actions
// ---------------------------------------------------------------------------

/// Selection mode, mirroring cosmic-text `Selection`.
pub const Selection = union(enum) {
    none: void,
    normal: Cursor,
    line: Cursor,
    word: Cursor,

    pub fn eql(a: Selection, b: Selection) bool {
        return std.meta.eql(a, b);
    }
};

/// One undoable change item, mirroring `ChangeItem`.
pub const ChangeItem = struct {
    start: Cursor,
    end: Cursor,
    text: std.ArrayList(u8),
    insert: bool,

    pub fn deinit(self: *ChangeItem, allocator: Allocator) void {
        self.text.deinit(allocator);
        self.* = undefined;
    }

    pub fn reverse(self: *ChangeItem) void {
        self.insert = !self.insert;
    }
};

/// A logical change grouping items, mirroring `Change`.
pub const Change = struct {
    items: std.ArrayList(ChangeItem),

    pub fn init(allocator: Allocator) Change {
        _ = allocator;
        return .{ .items = .empty };
    }

    pub fn deinit(self: *Change, allocator: Allocator) void {
        for (self.items.items) |*item| item.deinit(allocator);
        self.items.deinit(allocator);
        self.* = undefined;
    }

    pub fn reverse(self: *Change) void {
        std.mem.reverse(ChangeItem, self.items.items);
        for (self.items.items) |*item| item.reverse();
    }
};

/// An editing action, mirroring cosmic-text `Action`.
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
// Editor
// ---------------------------------------------------------------------------

/// RGBA color (canonical owner `attrs.Color`).
pub const Color = attrs.Color;

/// Renderer vtable used by [`Editor.render`]/[`Editor.draw`]. Canonical owner
/// is `render.zig`; re-exported here so `edit` consumers need one import.
pub const Renderer = render_mod.Renderer;

/// Width in pixels of the cursor rectangle (upstream `editor.rs:146` draws a
/// 1px caret; there is no configurable cursor width).
const CURSOR_WIDTH: u32 = 1;

/// Editable buffer wrapper, mirroring cosmic-text `Editor` (the struct form
/// of `Editor<'buffer>` + the `Edit` trait methods).
pub const Editor = struct {
    allocator: Allocator,
    buffer_ref: BufferRef,
    cursor: Cursor,
    cursor_x_opt: ?i32,
    selection: Selection,
    cursor_moved: bool,
    auto_indent: bool,
    change: ?Change,

    /// Create an editor owning a fresh empty buffer.
    pub fn init(allocator: Allocator) Error!Editor {
        var buf = try Buffer.initWithAllocator(allocator, .{ .font_size = 14, .line_height = 20 });
        errdefer buf.deinit();
        try buf.lines.append(allocator, BufferLine.empty(allocator));
        // Mirror `Buffer::new`'s `set_text`: mark the fresh line dirty so the
        // first `shapeUntilScroll` lays it out. A line whose caches are still
        // `Cached.empty` is not `needsReshaping`, so without this a fresh
        // editor would render nothing.
        buf.dirty.text_set = true;
        return .{
            .allocator = allocator,
            .buffer_ref = .{ .owned = buf },
            .cursor = .{},
            .cursor_x_opt = null,
            .selection = .{ .none = {} },
            .cursor_moved = false,
            .auto_indent = false,
            .change = null,
        };
    }

    /// Create an editor editing a caller-owned buffer (the buffer outlives
    /// the editor; `deinit` leaves it intact).
    pub fn initWithBuffer(allocator: Allocator, buf: *Buffer) Editor {
        return .{
            .allocator = allocator,
            .buffer_ref = .{ .borrowed = buf },
            .cursor = .{},
            .cursor_x_opt = null,
            .selection = .{ .none = {} },
            .cursor_moved = false,
            .auto_indent = false,
            .change = null,
        };
    }

    pub fn deinit(self: *Editor) void {
        self.buffer_ref.deinit();
        if (self.change) |*c| c.deinit(self.allocator);
        self.* = undefined;
    }

    /// Borrow the underlying buffer.
    pub fn buffer(self: *const Editor) *const Buffer {
        return self.buffer_ref.get();
    }

    /// Mutably borrow the underlying buffer.
    pub fn bufferMut(self: *Editor) *Buffer {
        return self.buffer_ref.getMut();
    }

    pub fn getCursor(self: *const Editor) Cursor {
        return self.cursor;
    }

    pub fn setCursor(self: *Editor, cursor: Cursor) void {
        if (!std.meta.eql(self.cursor, cursor)) {
            self.cursor = cursor;
            self.cursor_moved = true;
            self.bufferMut().setRedraw(true);
        }
    }

    pub fn getSelection(self: *const Editor) Selection {
        return self.selection;
    }

    pub fn setSelection(self: *Editor, selection: Selection) void {
        if (!Selection.eql(self.selection, selection)) {
            self.selection = selection;
            self.bufferMut().setRedraw(true);
        }
    }

    pub fn getAutoIndent(self: *const Editor) bool {
        return self.auto_indent;
    }

    pub fn setAutoIndent(self: *Editor, auto_indent: bool) void {
        self.auto_indent = auto_indent;
    }

    pub fn getTabWidth(self: *const Editor) u16 {
        return self.buffer().getTabWidth();
    }

    pub fn setTabWidth(self: *Editor, tab_width: u16) void {
        self.bufferMut().setTabWidth(tab_width);
    }

    /// Ordered selection bounds, with Line/Word expansion.
    pub fn selectionBounds(self: *const Editor) ?SelectionBounds {
        const cur = self.cursor;
        const lines = self.buffer().lines.items;
        switch (self.selection) {
            .none => return null,
            .normal => |select| {
                return switch (select.order(cur)) {
                    .gt => .{ .start = cur, .end = select },
                    else => .{ .start = select, .end = cur },
                };
            },
            .line => |select| {
                const s = @min(select.line, cur.line);
                const e = @max(select.line, cur.line);
                if (e >= lines.len) return null;
                return .{
                    .start = Cursor.new(s, 0),
                    .end = Cursor.new(e, lines[e].textSlice().len),
                };
            },
            .word => |select| {
                var start: Cursor = undefined;
                var end: Cursor = undefined;
                switch (select.order(cur)) {
                    .gt => {
                        start = cur;
                        end = select;
                    },
                    else => {
                        start = select;
                        end = cur;
                    },
                }
                if (start.line >= lines.len) return null;
                if (end.line >= lines.len) return null;
                start.index = prevWordStart(lines[start.line].textSlice(), start.index);
                end.index = nextWordEnd(lines[end.line].textSlice(), end.index);
                return .{ .start = start, .end = end };
            },
        }
    }

    /// Shape the buffer with the real engine, mirroring `shape_as_needed`:
    /// shapes until the cursor when it moved, else until the scroll position,
    /// then clears `cursor_moved`. Errors propagate (never silently dropped).
    pub fn shapeAsNeeded(self: *Editor, font_system_: *FontSystem, prune: bool) Error!void {
        const buf = self.bufferMut();
        if (self.cursor_moved) {
            try buf.shapeUntilCursor(font_system_, self.cursor, prune);
            self.cursor_moved = false;
        } else {
            try buf.shapeUntilScroll(font_system_, prune);
        }
    }

    /// Delete `[start, end)`, preserving endings across joined lines and
    /// recording undo text (removed texts joined by their endings).
    pub fn deleteRange(self: *Editor, start_in: Cursor, end_in: Cursor) Error!void {
        var start = start_in;
        var end = end_in;
        if (start.order(end) == .gt) {
            const tmp = start;
            start = end;
            end = tmp;
        }
        const allocator = self.allocator;
        const buf = self.bufferMut();
        if (start.line >= buf.lines.items.len) return error.InvalidCursor;
        if (end.line >= buf.lines.items.len) return error.InvalidCursor;
        if (start.index > buf.lines.items[start.line].textSlice().len) {
            return error.InvalidCursor;
        }
        if (end.index > buf.lines.items[end.line].textSlice().len) {
            return error.InvalidCursor;
        }

        var change_lines: std.ArrayList(BufferLine) = .empty;
        defer {
            for (change_lines.items) |*l| l.deinit();
            change_lines.deinit(allocator);
        }

        var end_line_opt: ?BufferLine = null;
        defer if (end_line_opt) |*l| l.deinit();
        if (end.line > start.line) {
            var after = try buf.lines.items[end.line].splitOff(end.index);
            const removed = buf.lines.orderedRemove(end.line);
            change_lines.insert(allocator, 0, removed) catch |e| {
                var r = removed;
                r.deinit();
                after.deinit();
                return e;
            };
            end_line_opt = after;
        }

        var li = end.line;
        while (li > start.line + 1) {
            li -= 1;
            const removed = buf.lines.orderedRemove(li);
            change_lines.insert(allocator, 0, removed) catch |e| {
                var r = removed;
                r.deinit();
                return e;
            };
        }

        {
            const line = &buf.lines.items[start.line];
            var after_opt: ?BufferLine = null;
            defer if (after_opt) |*l| l.deinit();
            if (start.line == end.line) {
                after_opt = try line.splitOff(end.index);
            }
            const removed = try line.splitOff(start.index);
            change_lines.insert(allocator, 0, removed) catch |e| {
                var r = removed;
                r.deinit();
                return e;
            };
            if (after_opt) |after| {
                try line.append(&after);
            }
            if (end_line_opt) |*end_line| {
                if (end_line.ending == .none) {
                    _ = end_line.setEnding(line.ending);
                }
                try line.append(end_line);
            }
        }

        var text: std.ArrayList(u8) = .empty;
        errdefer text.deinit(allocator);
        var first = true;
        var last_ending: LineEnding = .none;
        for (change_lines.items) |*l| {
            if (!first) {
                try text.appendSlice(allocator, last_ending.asStr());
            }
            first = false;
            try text.appendSlice(allocator, l.textSlice());
            last_ending = l.ending;
        }

        if (self.change) |*c| {
            try c.items.append(allocator, .{
                .start = start,
                .end = end,
                .text = text,
                .insert = false,
            });
        } else {
            text.deinit(allocator);
        }
    }

    /// Insert `data` at `cursor`, splitting lines on `LineIter` boundaries.
    /// Returns the cursor just past the inserted text.
    /// Takes ownership of `attrs_list` when non-null (pass the list by value
    /// and do not deinit it afterwards).
    pub fn insertAt(
        self: *Editor,
        cursor_in: Cursor,
        data: []const u8,
        attrs_list: ?AttrsList,
    ) Error!Cursor {
        var cursor = cursor_in;
        if (data.len == 0) {
            if (attrs_list) |a| {
                var owned = a;
                owned.deinit();
            }
            return cursor;
        }
        const allocator = self.allocator;
        const buf = self.bufferMut();
        const start = cursor;

        // Ensure enough lines exist for this cursor.
        while (cursor.line >= buf.lines.items.len) {
            var last_ending: LineEnding = .none;
            if (buf.lines.items.len > 0) {
                const last = &buf.lines.items[buf.lines.items.len - 1];
                last_ending = last.ending;
                if (last_ending == .none) {
                    _ = last.setEnding(LineEnding.default);
                    last_ending = last.ending;
                }
            }
            var line = BufferLine.empty(allocator);
            errdefer line.deinit();
            if (attrs_list) |a| {
                var borrowed = try a.defaults(allocator);
                defer borrowed.deinit();
                const fresh = try AttrsList.init(allocator, &borrowed);
                line.attrs_list.deinit();
                line.attrs_list = fresh;
            } else if (buf.lines.items.len > 0) {
                const last = &buf.lines.items[buf.lines.items.len - 1];
                var borrowed = try last.attrs_list.defaults(allocator);
                defer borrowed.deinit();
                const fresh = try AttrsList.init(allocator, &borrowed);
                line.attrs_list.deinit();
                line.attrs_list = fresh;
            }
            line.ending = last_ending;
            try buf.lines.append(allocator, line);
        }

        if (cursor.index > buf.lines.items[cursor.line].textSlice().len) {
            return error.InvalidCursor;
        }
        // Collect the text after the insertion point; rejoined below.
        var after = try buf.lines.items[cursor.line].splitOff(cursor.index);
        defer after.deinit();
        const after_len = after.textSlice().len;

        // Attributes for the inserted text: explicit, else the previous
        // character's span (mirrors `get_span(index.saturating_sub(1))`).
        var final_attrs: AttrsList = if (attrs_list) |a| a else blk: {
            const span_attrs = buf.lines.items[cursor.line].attrs_list.get_span(cursor.index -| 1);
            break :blk AttrsList.init_owned(allocator, try span_attrs.clone_with(allocator));
        };
        defer final_attrs.deinit();

        // Split the data into lines; a trailing line with no ending always
        // exists (mirrors the `lines.push((default, None))` rule).
        var parts: std.ArrayList(Line) = .empty;
        defer parts.deinit(allocator);
        var diter = LineIter.init(data);
        while (diter.next()) |item| try parts.append(allocator, item);
        if (parts.items.len == 0 or parts.items[parts.items.len - 1].ending != .none) {
            try parts.append(allocator, .{ .start = 0, .end = 0, .ending = .none });
        }
        var remaining = data.len;
        var front: usize = 0;
        var back: usize = parts.items.len;
        const insert_line = cursor.line + 1;

        // First data line joins the current line. `splitOff` returns the
        // suffix, so swapping hands the prefix to the new line.
        {
            const item = parts.items[front];
            front += 1;
            const data_line = data[item.start..item.end];
            var piece = try final_attrs.split_off(data_line.len);
            std.mem.swap(AttrsList, &final_attrs, &piece);
            var tmp = BufferLine.initOwned(allocator, data_line, item.ending, piece, .advanced) catch |e| {
                var p = piece;
                p.deinit();
                return e;
            };
            errdefer tmp.deinit();
            remaining -= data_line.len + item.ending.asStr().len;
            try buf.lines.items[cursor.line].append(&tmp);
            tmp.deinit();
        }
        // Last data line joins `after` (skipped when only one part exists).
        if (back > front) {
            back -= 1;
            const item = parts.items[back];
            const data_line = data[item.start..item.end];
            remaining -= data_line.len + item.ending.asStr().len;
            var piece = try final_attrs.split_off(remaining);
            std.mem.swap(AttrsList, &final_attrs, &piece);
            // Scope the errdefer to the insert so later errors cannot
            // double-free the line now owned by `buf`.
            {
                var tmp = BufferLine.initOwned(allocator, data_line, item.ending, piece, .advanced) catch |e| {
                    var p = piece;
                    p.deinit();
                    return e;
                };
                errdefer tmp.deinit();
                try tmp.append(&after);
                try buf.lines.insert(allocator, insert_line, tmp);
            }
            cursor.line += 1;
            // Middle lines, newest first at `insert_line` (mirrors `rev()`).
            while (back > front) {
                back -= 1;
                const m = parts.items[back];
                const mline = data[m.start..m.end];
                remaining -= mline.len + m.ending.asStr().len;
                var mpiece = try final_attrs.split_off(remaining);
                std.mem.swap(AttrsList, &final_attrs, &mpiece);
                var mtmp = BufferLine.initOwned(allocator, mline, m.ending, mpiece, .advanced) catch |e| {
                    var p = mpiece;
                    p.deinit();
                    return e;
                };
                errdefer mtmp.deinit();
                try buf.lines.insert(allocator, insert_line, mtmp);
                cursor.line += 1;
            }
        } else {
            // Single-line insert: rejoin `after` onto the current line.
            try buf.lines.items[cursor.line].append(&after);
        }
        if (remaining != 0) return error.InvalidData;
        cursor.index = buf.lines.items[cursor.line].textSlice().len - after_len;

        if (self.change) |*c| {
            var owned: std.ArrayList(u8) = .empty;
            errdefer owned.deinit(allocator);
            try owned.appendSlice(allocator, data);
            try c.items.append(allocator, .{
                .start = start,
                .end = cursor,
                .text = owned,
                .insert = true,
            });
        }
        return cursor;
    }

    /// Copy the selection, joining lines with `\n`. Null when no selection.
    pub fn copySelection(self: *const Editor) Error!?std.ArrayList(u8) {
        const bounds = self.selectionBounds() orelse return null;
        const lines = self.buffer().lines.items;
        var out: std.ArrayList(u8) = .empty;
        errdefer out.deinit(self.allocator);
        const start = bounds.start;
        const end = bounds.end;
        if (start.line == end.line) {
            try out.appendSlice(self.allocator, lines[start.line].textSlice()[start.index..end.index]);
        } else {
            try out.appendSlice(self.allocator, lines[start.line].textSlice()[start.index..]);
            try out.append(self.allocator, '\n');
        }
        var li = start.line + 1;
        while (li < end.line) : (li += 1) {
            try out.appendSlice(self.allocator, lines[li].textSlice());
            try out.append(self.allocator, '\n');
        }
        if (end.line > start.line) {
            try out.appendSlice(self.allocator, lines[end.line].textSlice()[0..end.index]);
        }
        return out;
    }

    /// Delete the selection, resetting the cursor to its start.
    pub fn deleteSelection(self: *Editor) Error!bool {
        const bounds = self.selectionBounds() orelse return false;
        self.cursor = bounds.start;
        self.selection = .{ .none = {} };
        try self.deleteRange(bounds.start, bounds.end);
        return true;
    }

    /// Replace the selection (if any) with `data`, moving the cursor past it.
    pub fn insertString(self: *Editor, data: []const u8, attrs_list: ?AttrsList) Error!void {
        _ = try self.deleteSelection();
        const new_cursor = try self.insertAt(self.cursor, data, attrs_list);
        self.setCursor(new_cursor);
    }

    /// Apply a recorded change. Refused (false) while another change is open.
    pub fn applyChange(self: *Editor, change: *const Change) Error!bool {
        if (self.change) |pending| {
            if (pending.items.items.len > 0) {
                self.change = pending;
                return false;
            }
            // Empty pending change: drop it and proceed.
            var drop = pending;
            drop.deinit(self.allocator);
            self.change = null;
        }
        for (change.items.items) |*item| {
            if (item.insert) {
                self.cursor = try self.insertAt(item.start, item.text.items, null);
            } else {
                self.cursor = item.start;
                try self.deleteRange(item.start, item.end);
            }
        }
        return true;
    }

    pub fn startChange(self: *Editor) void {
        if (self.change == null) {
            self.change = Change.init(self.allocator);
        }
    }

    pub fn finishChange(self: *Editor) ?Change {
        if (self.change) |c| {
            self.change = null;
            return c;
        }
        return null;
    }

    /// Full buffer text with endings, for tests/debugging. Caller owns it.
    pub fn fullText(self: *const Editor) Allocator.Error!std.ArrayList(u8) {
        var out: std.ArrayList(u8) = .empty;
        errdefer out.deinit(self.allocator);
        for (self.buffer().lines.items) |*line| {
            try out.appendSlice(self.allocator, line.textSlice());
            try out.appendSlice(self.allocator, line.ending.asStr());
        }
        return out;
    }

    /// Hit test against the buffer's laid-out glyph boxes
    /// (`Buffer.hit`, upstream `Editor`'s `action` path). The caller must
    /// shape first (`shapeAsNeeded`/`Buffer.shapeUntilScroll`); unshaped
    /// layout yields null, mirroring [`render`]. Non-finite coordinates map
    /// to no cursor rather than a garbage position.
    pub fn hit(self: *const Editor, x: f32, y: f32) ?Cursor {
        if (!std.math.isFinite(x) or !std.math.isFinite(y)) return null;
        return self.buffer().hit(x, y);
    }

    /// Visual caret position from the buffer's real layout runs
    /// (`Buffer.cursorPosition`), the same geometry [`render`] draws. Null
    /// when the cursor's line is not laid out.
    pub fn cursorPosition(self: *const Editor) ?CursorPosition {
        return self.buffer().cursorPosition(&self.cursor);
    }

    /// Perform an `Action` on the editor (upstream `Edit::action`).
    pub fn action(self: *Editor, font_system_: *FontSystem, act: Action) Error!void {
        // Motions go through `Buffer.cursorMotion`, hit tests through
        // `Buffer.shapeUntilScroll` + `Buffer.hit`; the FontSystem is
        // threaded because both shape on demand.
        const old_cursor = self.cursor;
        switch (act) {
            .motion => |motion| {
                const cursor = self.cursor;
                const cursor_x_opt = self.cursor_x_opt;
                if (try self.bufferMut().cursorMotion(font_system_, cursor, cursor_x_opt, motion)) |r| {
                    self.cursor = r.cursor;
                    self.cursor_x_opt = r.x_opt;
                }
            },
            .escape => {
                switch (self.selection) {
                    .none => {},
                    else => self.bufferMut().setRedraw(true),
                }
                self.selection = .{ .none = {} };
            },
            .insert => |cp| {
                if (isControl(cp) and cp != '\t' and cp != '\n' and cp != 0x92) {
                    // Filter out control characters (use actions instead).
                } else if (cp == '\n') {
                    try self.action(font_system_, .{ .enter = {} });
                } else {
                    var buf: [4]u8 = undefined;
                    const len = std.unicode.utf8Encode(cp, &buf) catch return;
                    try self.insertString(buf[0..len], null);
                }
            },
            .enter => {
                if (self.auto_indent) {
                    var line_text: std.ArrayList(u8) = .empty;
                    defer line_text.deinit(self.allocator);
                    try line_text.append(self.allocator, '\n');
                    const text = self.buffer().lines.items[self.cursor.line].textSlice();
                    var it = unicode.codepointIterator(text);
                    while (it.next()) |cp| {
                        if (!unicode.isWhitespace(cp.value)) break;
                        var enc: [4]u8 = undefined;
                        const n = std.unicode.utf8Encode(cp.value, &enc) catch break;
                        try line_text.appendSlice(self.allocator, enc[0..n]);
                    }
                    try self.insertString(line_text.items, null);
                } else {
                    try self.insertString("\n", null);
                }
                // Ensure the affected line is laid out for potential
                // immediate commands (upstream `Action::Enter`).
                _ = try self.bufferMut().lineLayout(font_system_, self.cursor.line);
            },
            .backspace => {
                if (!(try self.deleteSelection())) {
                    const end = self.cursor;
                    if (self.cursor.index > 0) {
                        // Whole UAX #29 grapheme cluster before the cursor.
                        self.cursor.index = unicode.prevGraphemeStart(
                            self.buffer().lines.items[self.cursor.line].textSlice(),
                            self.cursor.index,
                        );
                    } else if (self.cursor.line > 0) {
                        self.cursor.line -= 1;
                        self.cursor.index = self.buffer().lines.items[self.cursor.line].textSlice().len;
                    }
                    if (!std.meta.eql(self.cursor, end)) {
                        try self.deleteRange(self.cursor, end);
                    }
                }
            },
            .delete => {
                if (!(try self.deleteSelection())) {
                    const start = self.cursor;
                    var end = self.cursor;
                    const text = self.buffer().lines.items[start.line].textSlice();
                    if (start.index < text.len) {
                        // Whole UAX #29 grapheme cluster at the cursor.
                        end.index = unicode.nextGraphemeEnd(text, start.index);
                    } else if (start.line + 1 < self.buffer().lines.items.len) {
                        end.line += 1;
                        end.index = 0;
                    }
                    if (!std.meta.eql(start, end)) {
                        self.cursor = start;
                        try self.deleteRange(start, end);
                    }
                }
            },
            .indent => {
                const bounds: SelectionBounds = self.selectionBounds() orelse
                    .{ .start = self.cursor, .end = self.cursor };
                const tab_width: usize = @intCast(self.getTabWidth());
                var line_i = bounds.start.line;
                while (line_i <= bounds.end.line) : (line_i += 1) {
                    var after_whitespace: usize = 0;
                    var required_indent: usize = 0;
                    const text = self.buffer().lines.items[line_i].textSlice();
                    if (self.selection == .none) {
                        // Count whitespace codepoints backwards from the
                        // cursor (`None` means the whole prefix is blank).
                        const whitespace_length = trailingWhitespaceCodepoints(
                            text,
                            self.cursor.index,
                        ) orelse self.cursor.index;
                        if (tab_width > 0) {
                            required_indent = tab_width - (whitespace_length % tab_width);
                        }
                        after_whitespace = @min(self.cursor.index, text.len);
                    } else {
                        var count: usize = 0;
                        var it = unicode.codepointIterator(text);
                        var found = false;
                        while (it.next()) |cp| {
                            if (!unicode.isWhitespace(cp.value)) {
                                after_whitespace = it.pos - cp.len;
                                if (tab_width > 0) {
                                    required_indent = tab_width - (count % tab_width);
                                }
                                found = true;
                                break;
                            }
                            count += 1;
                        }
                        if (!found) {
                            after_whitespace = 0;
                            required_indent = 0;
                        }
                    }
                    if (required_indent > 0) {
                        var spaces: std.ArrayList(u8) = .empty;
                        defer spaces.deinit(self.allocator);
                        var s: usize = 0;
                        while (s < required_indent) : (s += 1) {
                            try spaces.append(self.allocator, ' ');
                        }
                        const at = Cursor.new(line_i, after_whitespace);
                        _ = try self.insertAt(at, spaces.items, null);
                        if (self.cursor.line == line_i) {
                            if (self.cursor.index < after_whitespace) {
                                self.cursor.index = after_whitespace;
                            }
                            self.cursor.index += required_indent;
                        }
                        switch (self.selection) {
                            .none => {},
                            .normal => |*sel| {
                                if (sel.line == line_i and sel.index >= after_whitespace) {
                                    sel.index += required_indent;
                                }
                            },
                            .line => |*sel| {
                                if (sel.line == line_i and sel.index >= after_whitespace) {
                                    sel.index += required_indent;
                                }
                            },
                            .word => |*sel| {
                                if (sel.line == line_i and sel.index >= after_whitespace) {
                                    sel.index += required_indent;
                                }
                            },
                        }
                    }
                    self.bufferMut().setRedraw(true);
                }
            },
            .unindent => {
                const bounds: SelectionBounds = self.selectionBounds() orelse
                    .{ .start = self.cursor, .end = self.cursor };
                const tab_width: usize = @intCast(self.getTabWidth());
                var line_i = bounds.start.line;
                while (line_i <= bounds.end.line) : (line_i += 1) {
                    const text = self.buffer().lines.items[line_i].textSlice();
                    var last_indent: usize = 0;
                    var after_whitespace: usize = text.len;
                    var count: usize = 0;
                    var it = unicode.codepointIterator(text);
                    while (it.next()) |cp| {
                        const cp_start = it.pos - cp.len;
                        if (!unicode.isWhitespace(cp.value)) {
                            after_whitespace = cp_start;
                            break;
                        }
                        if (tab_width > 0 and count % tab_width == 0) {
                            last_indent = cp_start;
                        }
                        count += 1;
                    }
                    if (last_indent == after_whitespace) continue;
                    try self.deleteRange(
                        Cursor.new(line_i, last_indent),
                        Cursor.new(line_i, after_whitespace),
                    );
                    // Saturating adjust (upstream can underflow here).
                    if (self.cursor.line == line_i and self.cursor.index > last_indent) {
                        self.cursor.index = last_indent +
                            (self.cursor.index -| after_whitespace);
                    }
                    switch (self.selection) {
                        .none => {},
                        .normal => |*sel| {
                            if (sel.line == line_i and sel.index > last_indent) {
                                sel.index = last_indent + (sel.index -| after_whitespace);
                            }
                        },
                        .line => |*sel| {
                            if (sel.line == line_i and sel.index > last_indent) {
                                sel.index = last_indent + (sel.index -| after_whitespace);
                            }
                        },
                        .word => |*sel| {
                            if (sel.line == line_i and sel.index > last_indent) {
                                sel.index = last_indent + (sel.index -| after_whitespace);
                            }
                        },
                    }
                    self.bufferMut().setRedraw(true);
                }
            },
            .click => |pos| {
                self.setSelection(.{ .none = {} });
                const x: f32 = @floatFromInt(pos.x);
                const y: f32 = @floatFromInt(pos.y);
                const buf = self.bufferMut();
                try buf.shapeUntilScroll(font_system_, false);
                if (buf.hit(x, y)) |new_cursor| {
                    if (!std.meta.eql(new_cursor, self.cursor)) {
                        self.cursor = new_cursor;
                        self.bufferMut().setRedraw(true);
                    }
                }
            },
            .double_click => |pos| {
                self.setSelection(.{ .none = {} });
                const x: f32 = @floatFromInt(pos.x);
                const y: f32 = @floatFromInt(pos.y);
                const buf = self.bufferMut();
                try buf.shapeUntilScroll(font_system_, false);
                if (buf.hit(x, y)) |new_cursor| {
                    if (!std.meta.eql(new_cursor, self.cursor)) {
                        self.cursor = new_cursor;
                        self.bufferMut().setRedraw(true);
                    }
                    self.selection = .{ .word = self.cursor };
                    self.bufferMut().setRedraw(true);
                }
            },
            .triple_click => |pos| {
                self.setSelection(.{ .none = {} });
                const x: f32 = @floatFromInt(pos.x);
                const y: f32 = @floatFromInt(pos.y);
                const buf = self.bufferMut();
                try buf.shapeUntilScroll(font_system_, false);
                if (buf.hit(x, y)) |new_cursor| {
                    if (!std.meta.eql(new_cursor, self.cursor)) {
                        self.cursor = new_cursor;
                    }
                    self.selection = .{ .line = self.cursor };
                    self.bufferMut().setRedraw(true);
                }
            },
            .drag => |pos| {
                if (self.selection == .none) {
                    self.selection = .{ .normal = self.cursor };
                    self.bufferMut().setRedraw(true);
                }
                const x: f32 = @floatFromInt(pos.x);
                const y: f32 = @floatFromInt(pos.y);
                const buf = self.bufferMut();
                try buf.shapeUntilScroll(font_system_, false);
                if (buf.hit(x, y)) |new_cursor| {
                    if (!std.meta.eql(new_cursor, self.cursor)) {
                        self.cursor = new_cursor;
                        self.bufferMut().setRedraw(true);
                    }
                }
            },
            .scroll => |s| {
                var scroll = self.bufferMut().getScroll();
                scroll.vertical += s.pixels;
                self.bufferMut().setScroll(scroll);
            },
        }
        if (!std.meta.eql(old_cursor, self.cursor)) {
            self.cursor_moved = true;
            self.bufferMut().setRedraw(true);
        }
    }

    /// Render selection highlights, the cursor, text decorations, and glyphs
    /// from the buffer's laid-out runs through the canonical
    /// `render.Renderer` (upstream `Editor::render`, editor.rs:85-170).
    ///
    /// The caller must shape first (`shapeAsNeeded`, [`draw`], or
    /// `Buffer.shapeUntilScroll`), mirroring the upstream contract; unshaped
    /// runs draw nothing. Per run the order is: selection rectangles, cursor
    /// rectangle, decoration rectangles, glyphs. `Selection.none` draws no
    /// highlight and a cursor only appears on its own line.
    ///
    /// Upstream's `render` is infallible; the port's `LayoutRun.highlight`
    /// allocates the selection spans, so `error.OutOfMemory` propagates rather
    /// than silently dropping a run's highlight/cursor/decorations.
    pub fn render(
        self: *const Editor,
        renderer: Renderer,
        text_color: Color,
        cursor_color: Color,
        selection_color: Color,
        selected_text_color: Color,
    ) Error!void {
        const selection_bounds = self.selectionBounds();
        const buf = self.buffer();
        var runs = buf.layoutRuns();
        while (runs.next()) |run| {
            try renderLayoutRun(
                self.allocator,
                renderer,
                &run,
                &self.cursor,
                selection_bounds,
                buf.width_opt,
                text_color,
                cursor_color,
                selection_color,
                selected_text_color,
            );
        }
    }

    /// Draw the editor: resolve pending shape state (`shape_until_scroll`,
    /// exactly as upstream `Editor::draw` does), then rasterize glyph masks
    /// through `render.LegacyRenderer` while forwarding rectangles (selection,
    /// cursor, decorations, 1x1 glyph pixels) to `callback`.
    ///
    /// The callback must not re-enter `cache`.
    pub fn draw(
        self: *Editor,
        font_system_: *FontSystem,
        cache: *swash_cache_mod.SwashCache,
        text_color: Color,
        cursor_color: Color,
        selection_color: Color,
        selected_text_color: Color,
        callback: render_mod.Callback,
    ) Error!void {
        try self.bufferMut().shapeUntilScroll(font_system_, false);
        var legacy = render_mod.LegacyRenderer.init(cache, callback);
        try self.render(
            legacy.renderer(),
            text_color,
            cursor_color,
            selection_color,
            selected_text_color,
        );
    }
};

/// Render one laid-out run in upstream order (editor.rs:95-168).
fn renderLayoutRun(
    allocator: Allocator,
    renderer: Renderer,
    run: *const buffer_mod.LayoutRun,
    cursor: *const Cursor,
    selection_bounds: ?SelectionBounds,
    width_opt: ?f32,
    text_color: Color,
    cursor_color: Color,
    selection_color: Color,
    selected_text_color: Color,
) Error!void {
    const line_i = run.line_i;
    const line_top = render_mod.floatToI32Saturating(run.line_top);
    const line_height = render_mod.floatToU32Saturating(run.line_height);
    const line_width = @max(render_mod.floatToI32Saturating(width_opt orelse 0), 0);

    // Highlight selection.
    if (selection_bounds) |bounds| {
        if (line_i >= bounds.start.line and line_i <= bounds.end.line) {
            var highlights = try run.highlight(allocator, bounds.start, bounds.end);
            defer highlights.deinit(allocator);

            if (highlights.items.len == 0 and run.glyphs.len == 0 and bounds.end.line > line_i) {
                // Highlight all of internal empty lines.
                renderer.rectangle(0, line_top, @intCast(line_width), line_height, selection_color);
            } else {
                const len = highlights.items.len;
                for (highlights.items, 0..) |h, idx| {
                    var min = render_mod.floatToI32Saturating(h.x);
                    var max = render_mod.floatToI32Saturating(h.x + h.width);

                    // Extend the last rect to the line edge for multi-line
                    // selections (RTL extends left, LTR extends right).
                    if (idx == len - 1 and bounds.end.line > line_i) {
                        if (run.rtl) {
                            min = 0;
                        } else {
                            max = line_width;
                        }
                    }

                    renderer.rectangle(min, line_top, i32DiffToU32(max, min), line_height, selection_color);
                }
            }
        }
    }

    // Draw cursor (upstream draws a 1px-wide caret spanning the line height).
    if (run.cursorPosition(cursor)) |x| {
        renderer.rectangle(
            render_mod.floatToI32Saturating(x),
            line_top,
            CURSOR_WIDTH,
            line_height,
            cursor_color,
        );
    }

    // Decorations after the cursor, before glyphs (editor.rs:149-150).
    render_mod.renderDecoration(renderer, renderRunView(run), text_color);

    for (run.glyphs) |glyph| {
        const physical_glyph = glyph.physical(0.0, run.line_y, 1.0);

        var glyph_color = glyph.color_opt orelse text_color;
        if (!text_color.eql(selected_text_color)) {
            if (selection_bounds) |bounds| {
                if (line_i >= bounds.start.line and line_i <= bounds.end.line and
                    (bounds.start.line != line_i or glyph.end > bounds.start.index) and
                    (bounds.end.line != line_i or glyph.start < bounds.end.index))
                {
                    glyph_color = selected_text_color;
                }
            }
        }

        renderer.glyph(physical_glyph, glyph_color);
    }
}

/// `max(max - min, 0)` as `u32` without the i32 overflow of upstream's
/// `cmp::max(0, max - min) as u32` when both bounds saturate.
fn i32DiffToU32(max: i32, min: i32) u32 {
    const diff: i64 = @as(i64, max) - @as(i64, min);
    if (diff <= 0) return 0;
    return @intCast(@min(diff, std.math.maxInt(u32)));
}

/// Convert the buffer `LayoutRun` into `render.zig`'s view. Kept local so
/// `render.zig` stays independent of `buffer.zig` (mirrors `buffer.zig`'s
/// private `renderRunView`).
fn renderRunView(run: *const buffer_mod.LayoutRun) render_mod.LayoutRun {
    return .{
        .glyphs = run.glyphs,
        .decorations = run.decorations,
        .line_y = run.line_y,
        .line_top = run.line_top,
        .line_i = run.line_i,
        .rtl = run.rtl,
        .line_height = run.line_height,
        .line_w = run.line_w,
    };
}

/// Ordered selection bounds.
pub const SelectionBounds = struct {
    start: Cursor,
    end: Cursor,
};

/// Caret position in layout pixels (canonical owner `Buffer.CursorPosition`).
pub const CursorPosition = buffer_mod.CursorPosition;

// ---------------------------------------------------------------------------
// UTF-8 / word / whitespace helpers (canonical UAX #29 via `unicode.zig`)
// ---------------------------------------------------------------------------

pub fn isControl(cp: u21) bool {
    return (cp < 0x20 or (cp >= 0x7F and cp <= 0x9F));
}

/// Whether a UAX #29 word segment counts as a "word" for word motion and
/// `Selection::Word`. Delegates to the single canonical rule: a segment is a
/// word iff it contains an `Alphabetic` or `General_Category=N*` codepoint,
/// exactly like `unicode-segmentation`'s `unicode_word_indices` filter.
fn wordSegmentIsWord(text: []const u8, r: unicode.WordRange) bool {
    return unicode.isWordRange(text, r);
}

/// Start of the previous UAX #29 word before `index` (0 when none).
pub fn prevWordStart(text: []const u8, index: usize) usize {
    var found: usize = 0;
    var it = unicode.wordBounds(text);
    while (it.next()) |r| {
        if (r.start >= index) break;
        if (wordSegmentIsWord(text, r)) found = r.start;
    }
    return found;
}

/// End of the next UAX #29 word after `index` (`text.len` when none).
pub fn nextWordEnd(text: []const u8, index: usize) usize {
    var it = unicode.wordBounds(text);
    while (it.next()) |r| {
        if (!wordSegmentIsWord(text, r)) continue;
        if (r.end > index) return r.end;
    }
    return text.len;
}

pub fn firstNonWhitespace(text: []const u8) usize {
    // Codepoint loop so multi-byte spaces (NBSP, EM SPACE, …) count.
    // Empty or all-whitespace lines return 0 (`unwrap_or(0)` in the oracle).
    var it = unicode.codepointIterator(text);
    while (it.next()) |cp| {
        if (!unicode.isWhitespace(cp.value)) return it.pos - cp.len;
    }
    return 0;
}

/// Number of trailing whitespace codepoints at the end of `text[0..end]`,
/// or null when the whole prefix is whitespace (or empty). Mirrors
/// `text.chars().rev().position(|c| !c.is_whitespace())`.
fn trailingWhitespaceCodepoints(text: []const u8, end: usize) ?usize {
    const limit = @min(end, text.len);
    var count: usize = 0;
    var saw_non_ws = false;
    var it = unicode.codepointIterator(text[0..limit]);
    while (it.next()) |cp| {
        if (unicode.isWhitespace(cp.value)) {
            count += 1;
        } else {
            count = 0;
            saw_non_ws = true;
        }
    }
    return if (saw_non_ws) count else null;
}

fn isRtlCp(cp: u21) bool {
    return (cp >= 0x0590 and cp <= 0x08FF) or
        (cp >= 0xFB1D and cp <= 0xFDFF) or
        (cp >= 0xFE70 and cp <= 0xFEFF);
}

pub fn detectRtlLine(text: []const u8) bool {
    var it = unicode.codepointIterator(text);
    while (it.next()) |cp| {
        if (isRtlCp(cp.value)) return true;
        if ((cp.value >= 'A' and cp.value <= 'Z') or (cp.value >= 'a' and cp.value <= 'z')) {
            return false;
        }
    }
    return false;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

fn testColor(value: u32) Color {
    return .{ .value = value };
}

const EventKind = enum { rect, glyph };

const TestEvent = struct {
    kind: EventKind,
    x: i32,
    y: i32,
    w: u32 = 0,
    h: u32 = 0,
    color: Color,
    physical: ?layout.PhysicalGlyph = null,
};

/// Mock canvas implementing the canonical `render.Renderer` vtable: records
/// rectangles and glyphs (with their physical position and color) in call
/// order, so tests can assert upstream's emit order.
const TestRenderer = struct {
    allocator: Allocator,
    events: std.ArrayList(TestEvent),
    append_failed: bool = false,

    fn init(allocator: Allocator) TestRenderer {
        return .{ .allocator = allocator, .events = .empty };
    }

    fn deinit(self: *TestRenderer) void {
        self.events.deinit(self.allocator);
    }

    fn renderer(self: *TestRenderer) Renderer {
        return .{ .ctx = self, .vtable = &vtable };
    }

    /// Callback view for `Editor.draw` (rectangles; `LegacyRenderer` lowers
    /// glyph mask pixels to 1x1 rectangles through the same callback).
    fn callback(self: *TestRenderer) render_mod.Callback {
        return .{ .ctx = self, .call = rectCb };
    }

    const vtable: Renderer.VTable = .{
        .rectangle = rectCb,
        .glyph = glyphCb,
    };

    fn rectCb(ctx: *anyopaque, x: i32, y: i32, w: u32, h: u32, color: Color) void {
        const self: *TestRenderer = @ptrCast(@alignCast(ctx));
        self.events.append(self.allocator, .{
            .kind = .rect,
            .x = x,
            .y = y,
            .w = w,
            .h = h,
            .color = color,
        }) catch {
            self.append_failed = true;
        };
    }

    fn glyphCb(ctx: *anyopaque, physical: layout.PhysicalGlyph, color: Color) void {
        const self: *TestRenderer = @ptrCast(@alignCast(ctx));
        self.events.append(self.allocator, .{
            .kind = .glyph,
            .x = physical.x,
            .y = physical.y,
            .color = color,
            .physical = physical,
        }) catch {
            self.append_failed = true;
        };
    }
};

fn hasRect(events: []const TestEvent, color: Color) bool {
    for (events) |ev| {
        if (ev.kind == .rect and ev.color.eql(color)) return true;
    }
    return false;
}

/// Real font fixtures: the shared TTF corpus lives in `tests/fonts` next to
/// `src/`. `@src().file` is only the basename in this Zig version, so probe
/// the common working directories (`zig test src/edit.zig` runs from the
/// package root; `zig build test` also resolves `tests/fonts`).
const FONT_FIXTURE_DIRS = [_][]const u8{
    "tests/fonts",
    "../tests/fonts",
    "src/../tests/fonts",
};

/// Read a checked-in TTF by file name; fails (never skips) when the corpus
/// is missing.
fn readFontFixtureNamed(allocator: Allocator, name: []const u8) ![]u8 {
    var last_err: anyerror = error.FileNotFound;
    for (FONT_FIXTURE_DIRS) |dir| {
        const path = try std.fs.path.join(allocator, &.{ dir, name });
        defer allocator.free(path);
        if (std.Io.Dir.cwd().readFileAlloc(std.testing.io, path, allocator, .limited(1 << 24))) |bytes| {
            return bytes;
        } else |e| {
            last_err = e;
        }
    }
    return last_err;
}

fn readFontFixture(allocator: Allocator) ![]u8 {
    return readFontFixtureNamed(allocator, "Inter-Regular.ttf");
}

/// Font system with the vendored faces the buffer/edit tests use, registered
/// eagerly (`addFontData`) so shaping needs no host fonts.
const TestFontSystem = struct {
    font_system: FontSystem,

    const FontSpec = struct {
        file: []const u8,
        family: []const u8,
        mono: bool,
    };
    const fonts = [_]FontSpec{
        .{ .file = "Inter-Regular.ttf", .family = "Inter", .mono = false },
        .{ .file = "NotoSansHebrew.ttf", .family = "Noto Sans Hebrew", .mono = false },
    };

    fn init(allocator: Allocator) !TestFontSystem {
        var fsys = try FontSystem.init(allocator);
        errdefer fsys.deinit();
        for (fonts) |spec| {
            const bytes = try readFontFixtureNamed(allocator, spec.file);
            defer allocator.free(bytes);
            const id = try fsys.dbMut().addFace(
                spec.file,
                0,
                &.{spec.family},
                spec.family,
                font_system.WEIGHT_NORMAL,
                .normal,
                .normal,
                spec.mono,
            );
            try fsys.addFontData(id, bytes, 0, false, null);
        }
        return .{ .font_system = fsys };
    }

    fn deinit(self: *TestFontSystem) void {
        self.font_system.deinit();
        self.* = undefined;
    }
};

/// Shape every line through the real engine (upstream `shape_until_scroll`),
/// the precondition `Editor.render` documents.
fn shapeEditor(ed: *Editor, fsys: *FontSystem) !void {
    try ed.bufferMut().shapeUntilScroll(fsys, false);
}

fn firstRun(ed: *const Editor) buffer_mod.LayoutRun {
    var runs = ed.buffer().layoutRuns();
    return runs.next().?;
}

test "insert and delete round-trip with endings" {
    const alloc = std.testing.allocator;
    var ed = try Editor.init(alloc);
    defer ed.deinit();

    ed.startChange();
    const end = try ed.insertAt(Cursor.new(0, 0), "LF\nCRLF\r\nCR\rLFCR\n\rNONE", null);
    var ch0 = ed.finishChange().?;
    defer ch0.deinit(alloc);
    var t = try ed.fullText();
    defer t.deinit(alloc);
    try std.testing.expectEqualStrings("LF\nCRLF\r\nCR\rLFCR\n\rNONE", t.items);

    // Undo text round-trips through applyChange(reverse).
    ed.startChange();
    try ed.deleteRange(Cursor.new(0, 0), end);
    var ch = ed.finishChange().?;
    defer ch.deinit(alloc);
    var t2 = try ed.fullText();
    defer t2.deinit(alloc);
    try std.testing.expectEqualStrings("", t2.items);

    ch.reverse();
    try std.testing.expect(try ed.applyChange(&ch));
    var t3 = try ed.fullText();
    defer t3.deinit(alloc);
    try std.testing.expectEqualStrings("LF\nCRLF\r\nCR\rLFCR\n\rNONE", t3.items);
}

test "delete_range joins lines preserving endings" {
    const alloc = std.testing.allocator;
    var ed = try Editor.init(alloc);
    defer ed.deinit();
    _ = try ed.insertAt(Cursor.new(0, 0), "hello\nworld\n", null);
    // Lines: "hello"(lf) "world"(lf) ""(none).
    try std.testing.expect(ed.buffer().lines.items.len == 3);
    ed.startChange();
    try ed.deleteRange(Cursor.new(0, 2), Cursor.new(1, 3));
    var ch = ed.finishChange().?;
    defer ch.deinit(alloc);
    // "he" + "ld" joined; undo text is "llo\nwor".
    var t = try ed.fullText();
    defer t.deinit(alloc);
    try std.testing.expectEqualStrings("held\n", t.items);
    try std.testing.expect(ch.items.items.len == 1);
    try std.testing.expectEqualStrings("llo\nwor", ch.items.items[0].text.items);
    try std.testing.expect(!ch.items.items[0].insert);
}

test "insert_at splits lines and lands cursor" {
    const alloc = std.testing.allocator;
    var ed = try Editor.init(alloc);
    defer ed.deinit();
    _ = try ed.insertAt(Cursor.new(0, 0), "ab", null);
    const cur = try ed.insertAt(Cursor.new(0, 1), "X\nY", null);
    try std.testing.expect(cur.line == 1 and cur.index == 1);
    var t = try ed.fullText();
    defer t.deinit(alloc);
    try std.testing.expectEqualStrings("aX\nYb", t.items);
    // Trailing newline creates an empty final line.
    _ = try ed.insertAt(Cursor.new(1, 2), "\n", null);
    try std.testing.expect(ed.buffer().lines.items.len == 3);
}

test "selection bounds normal/line/word" {
    const alloc = std.testing.allocator;
    var ed = try Editor.init(alloc);
    defer ed.deinit();
    _ = try ed.insertAt(Cursor.new(0, 0), "hello world\nsecond line", null);

    ed.cursor = Cursor.new(0, 8);
    ed.selection = .{ .normal = Cursor.new(0, 2) };
    const n = ed.selectionBounds().?;
    try std.testing.expect(n.start.index == 2 and n.end.index == 8);

    // Reversed anchor order normalizes.
    ed.selection = .{ .normal = Cursor.new(1, 4) };
    ed.cursor = Cursor.new(0, 1);
    const n2 = ed.selectionBounds().?;
    try std.testing.expect(n2.start.line == 0 and n2.end.line == 1);

    // Line mode spans whole lines.
    ed.selection = .{ .line = Cursor.new(1, 2) };
    ed.cursor = Cursor.new(0, 0);
    const l = ed.selectionBounds().?;
    try std.testing.expect(l.start.line == 0 and l.start.index == 0);
    try std.testing.expect(l.end.line == 1 and l.end.index == 11);

    // Word mode expands to UAX #29 word boundaries ("world" is 6..11).
    ed.selection = .{ .word = Cursor.new(0, 0) };
    ed.cursor = Cursor.new(0, 8);
    const w = ed.selectionBounds().?;
    try std.testing.expect(w.start.index == 0 and w.end.index == 11);

    ed.selection = .{ .none = {} };
    try std.testing.expect(ed.selectionBounds() == null);
}

test "word motions use UAX #29 word bounds across punctuation" {
    const s = "hello, world";
    try std.testing.expect(prevWordStart(s, s.len) == 7);
    try std.testing.expect(nextWordEnd(s, 5) == 12);
    try std.testing.expect(nextWordEnd(s, 0) == 5);
    try std.testing.expect(prevWordStart(s, 3) == 0);
    // Word selection bounds split on the comma, not the alnum run only.
    const alloc = std.testing.allocator;
    var ed = try Editor.init(alloc);
    defer ed.deinit();
    _ = try ed.insertAt(Cursor.new(0, 0), s, null);
    ed.selection = .{ .word = Cursor.new(0, 8) };
    ed.cursor = Cursor.new(0, 8);
    const b = ed.selectionBounds().?;
    try std.testing.expect(b.start.index == 7 and b.end.index == 12);
}

test "word selection bounds and buffer word motions agree" {
    // The upstream word selection path (`Selection::Word` ->
    // `unicode_word_indices`) and `Buffer::cursor_motion` share the same
    // alphanumeric filter; prove it at every byte index.
    const alloc = std.testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    const fsys = &tfs.font_system;
    const cases = [_][]const u8{
        "one, two",
        "one,two",
        "a, b",
        "foo-bar",
        "don't",
        "abc123",
        "32.3",
        "  leading  trailing  ",
        ",,,   ",
        "Ⅻ ²",
        "漢字abc",
        "中文，测试",
        "こんにちは カタカナ",
        "abc مرحبا def",
        "שלום world",
    };
    for (cases) |s| {
        var ed = try Editor.init(alloc);
        defer ed.deinit();
        _ = try ed.insertAt(Cursor.new(0, 0), s, null);
        var idx: usize = 0;
        while (idx <= s.len) : (idx += 1) {
            const at = Cursor.new(0, idx);
            // `.word` selection around a single cursor expands to
            // prevWordStart..nextWordEnd.
            ed.selection = .{ .word = at };
            ed.cursor = at;
            const bounds = ed.selectionBounds().?;
            // Buffer primitives for the same position (single line).
            const prev = (try ed.bufferMut().cursorMotion(fsys, at, null, .previous_word)) orelse
                return error.UnexpectedNull;
            const next = (try ed.bufferMut().cursorMotion(fsys, at, null, .next_word)) orelse
                return error.UnexpectedNull;
            try std.testing.expectEqual(prev.cursor.index, bounds.start.index);
            try std.testing.expectEqual(next.cursor.index, bounds.end.index);
        }
    }
}

test "copy and delete selection" {
    const alloc = std.testing.allocator;
    var ed = try Editor.init(alloc);
    defer ed.deinit();
    _ = try ed.insertAt(Cursor.new(0, 0), "foo\nbar\nbaz", null);
    ed.cursor = Cursor.new(1, 1);
    ed.selection = .{ .normal = Cursor.new(0, 1) };
    var copied = (try ed.copySelection()).?;
    defer copied.deinit(alloc);
    try std.testing.expectEqualStrings("oo\nb", copied.items);
    try std.testing.expect(try ed.deleteSelection());
    var t = try ed.fullText();
    defer t.deinit(alloc);
    try std.testing.expectEqualStrings("far\nbaz", t.items);
    try std.testing.expect(ed.cursor.line == 0 and ed.cursor.index == 1);
    try std.testing.expect(!try ed.deleteSelection());
}

test "action insert/enter/backspace/delete" {
    const alloc = std.testing.allocator;
    var fsys = try FontSystem.init(alloc);
    defer fsys.deinit();
    var ed = try Editor.init(alloc);
    defer ed.deinit();

    // Control characters are filtered (except tab/newline).
    try ed.action(&fsys, .{ .insert = 0x01 });
    var t0 = try ed.fullText();
    defer t0.deinit(alloc);
    try std.testing.expectEqualStrings("", t0.items);

    try ed.action(&fsys, .{ .insert = 'a' });
    try ed.action(&fsys, .{ .insert = 'b' });
    // '\n' routes to Enter.
    try ed.action(&fsys, .{ .insert = '\n' });
    try ed.action(&fsys, .{ .insert = 'c' });
    var t = try ed.fullText();
    defer t.deinit(alloc);
    try std.testing.expectEqualStrings("ab\nc", t.items);

    // Backspace joins lines at column 0.
    try ed.action(&fsys, .{ .motion = .home });
    try ed.action(&fsys, .backspace);
    var t2 = try ed.fullText();
    defer t2.deinit(alloc);
    try std.testing.expectEqualStrings("abc", t2.items);

    // Delete removes the grapheme under the cursor.
    try ed.action(&fsys, .{ .motion = .home });
    try ed.action(&fsys, .delete);
    var t3 = try ed.fullText();
    defer t3.deinit(alloc);
    try std.testing.expectEqualStrings("bc", t3.items);
}

test "regression: delete at start removes e + combining acute" {
    const alloc = std.testing.allocator;
    var fsys = try FontSystem.init(alloc);
    defer fsys.deinit();
    var ed = try Editor.init(alloc);
    defer ed.deinit();

    // Type "e" + U+0301 (combining acute) = one grapheme cluster.
    try ed.action(&fsys, .{ .insert = 'e' });
    try ed.action(&fsys, .{ .insert = 0x0301 });
    var typed = try ed.fullText();
    defer typed.deinit(alloc);
    try std.testing.expectEqualStrings("e\xcc\x81", typed.items);
    try std.testing.expect(ed.cursor.index == 3);

    try ed.action(&fsys, .{ .motion = .home });
    try std.testing.expect(ed.cursor.index == 0);
    try ed.action(&fsys, .delete);

    var t = try ed.fullText();
    defer t.deinit(alloc);
    // Both codepoints of the cluster are gone (pre-fix left U+0301 behind).
    try std.testing.expectEqualStrings("", t.items);
}

test "regression: backspace removes the whole trailing grapheme cluster" {
    const alloc = std.testing.allocator;
    var fsys = try FontSystem.init(alloc);
    defer fsys.deinit();
    var ed = try Editor.init(alloc);
    defer ed.deinit();
    try ed.action(&fsys, .{ .insert = 'e' });
    try ed.action(&fsys, .{ .insert = 0x0301 });
    try ed.action(&fsys, .backspace);
    var t = try ed.fullText();
    defer t.deinit(alloc);
    try std.testing.expectEqualStrings("", t.items);
}

test "regression: previous/next motions and hit stay on grapheme boundaries" {
    const alloc = std.testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    const fsys = &tfs.font_system;
    var ed = try Editor.init(alloc);
    defer ed.deinit();
    try ed.action(fsys, .{ .insert = 'e' });
    try ed.action(fsys, .{ .insert = 0x0301 });
    try std.testing.expect(ed.cursor.index == 3);

    // Previous steps the whole cluster, Next steps it back.
    try ed.action(fsys, .{ .motion = .previous });
    try std.testing.expect(ed.cursor.index == 0);
    try ed.action(fsys, .{ .motion = .next });
    try std.testing.expect(ed.cursor.index == 3);

    // Hit testing never lands inside the cluster: the real layout maps the
    // left half of the cluster glyph to 0 and the right half to 3 (never 1
    // or 2).
    try shapeEditor(&ed, fsys);
    const run = firstRun(&ed);
    try std.testing.expect(run.glyphs.len >= 1);
    const glyph = run.glyphs[0];
    const y = run.line_top + run.line_height / 2.0;
    const left = ed.hit(glyph.x + glyph.w * 0.25, y).?;
    try std.testing.expect(left.index == 0);
    const right = ed.hit(glyph.x + glyph.w * 0.75, y).?;
    try std.testing.expect(right.index == 3);
}

test "action enter respects auto-indent" {
    const alloc = std.testing.allocator;
    var fsys = try FontSystem.init(alloc);
    defer fsys.deinit();
    var ed = try Editor.init(alloc);
    defer ed.deinit();
    ed.setAutoIndent(true);
    try ed.insertString("    code", null);
    try ed.action(&fsys, .{ .motion = .end });
    try ed.action(&fsys, .enter);
    var t = try ed.fullText();
    defer t.deinit(alloc);
    try std.testing.expectEqualStrings("    code\n    ", t.items);
}

test "action edge: backspace rejoins lines and delete splits them" {
    const alloc = std.testing.allocator;
    var fsys = try FontSystem.init(alloc);
    defer fsys.deinit();
    var ed = try Editor.init(alloc);
    defer ed.deinit();
    try ed.insertString("ab\ncd", null);
    try ed.action(&fsys, .{ .motion = .buffer_start });
    try ed.action(&fsys, .delete);
    var t = try ed.fullText();
    defer t.deinit(alloc);
    try std.testing.expectEqualStrings("b\ncd", t.items);
    try ed.action(&fsys, .{ .motion = .buffer_end });
    try ed.action(&fsys, .backspace);
    ed.selection = .{ .none = {} };
    var t2 = try ed.fullText();
    defer t2.deinit(alloc);
    try std.testing.expectEqualStrings("b\nc", t2.items);
}

test "action indent and unindent" {
    const alloc = std.testing.allocator;
    var fsys = try FontSystem.init(alloc);
    defer fsys.deinit();
    var ed = try Editor.init(alloc);
    defer ed.deinit();
    try ed.insertString("x", null);
    // No selection: indent to the next multiple of tab width (8). The
    // cursor sits after 'x', so 8 spaces land there and it moves past them.
    try ed.action(&fsys, .indent);
    var t = try ed.fullText();
    defer t.deinit(alloc);
    try std.testing.expectEqualStrings("x        ", t.items);
    try std.testing.expect(ed.cursor.index == 9);
    // Unindent with no leading whitespace is a no-op (trailing spaces are
    // not leading whitespace).
    try ed.action(&fsys, .unindent);
    var t2 = try ed.fullText();
    defer t2.deinit(alloc);
    try std.testing.expectEqualStrings("x        ", t2.items);

    // Leading whitespace unindents by one tab stop.
    var ed2 = try Editor.init(alloc);
    defer ed2.deinit();
    try ed2.insertString("    x", null);
    try ed2.action(&fsys, .unindent);
    var t2b = try ed2.fullText();
    defer t2b.deinit(alloc);
    try std.testing.expectEqualStrings("x", t2b.items);
    try std.testing.expect(ed2.cursor.index == 1);

    // Multi-line selection indents every line.
    try ed.insertString("\ny", null);
    ed.cursor = Cursor.new(1, 1);
    ed.selection = .{ .line = Cursor.new(0, 0) };
    try ed.action(&fsys, .indent);
    var t3 = try ed.fullText();
    defer t3.deinit(alloc);
    try std.testing.expectEqualStrings("        x        \n        y", t3.items);
}

test "action click drag selection and escape" {
    const alloc = std.testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    const fsys = &tfs.font_system;
    var ed = try Editor.init(alloc);
    defer ed.deinit();
    try ed.insertString("hello", null);
    try shapeEditor(&ed, fsys);

    // Click the first glyph's left half -> cursor before it.
    const run = firstRun(&ed);
    try std.testing.expect(run.glyphs.len == 5);
    const y: i32 = @intFromFloat(run.line_top + run.line_height / 2.0);
    const first = run.glyphs[0];
    const click_x: i32 = @intFromFloat(first.x + first.w * 0.25);
    try ed.action(fsys, .{ .click = .{ .x = click_x, .y = y } });
    try std.testing.expect(ed.cursor.index == 0);

    // Drag to the right half of the last glyph -> selection 0..5.
    const last = run.glyphs[4];
    const drag_x: i32 = @intFromFloat(last.x + last.w * 0.75);
    try ed.action(fsys, .{ .drag = .{ .x = drag_x, .y = y } });
    try std.testing.expect(ed.selection != .none);
    const b = ed.selectionBounds().?;
    try std.testing.expect(b.start.index == 0 and b.end.index == 5);

    try ed.action(fsys, .escape);
    try std.testing.expect(ed.selection == .none);

    const mid = run.glyphs[2];
    const mid_x: i32 = @intFromFloat(mid.x + mid.w * 0.25);
    try ed.action(fsys, .{ .double_click = .{ .x = mid_x, .y = y } });
    try std.testing.expect(ed.selection == .word);
    try ed.action(fsys, .{ .triple_click = .{ .x = mid_x, .y = y } });
    try std.testing.expect(ed.selection == .line);
}

test "change tracking start/finish/apply" {
    const alloc = std.testing.allocator;
    var ed = try Editor.init(alloc);
    defer ed.deinit();
    try std.testing.expect(ed.finishChange() == null);
    ed.startChange();
    _ = try ed.insertAt(Cursor.new(0, 0), "ab", null);
    var ch = ed.finishChange().?;
    defer ch.deinit(alloc);
    try std.testing.expect(ch.items.items.len == 1);
    try std.testing.expect(ch.items.items[0].insert);

    // Applying while a change is open is refused.
    ed.startChange();
    _ = try ed.insertAt(Cursor.new(0, 2), "z", null);
    try std.testing.expect(!try ed.applyChange(&ch));
    var open = ed.finishChange().?;
    defer open.deinit(alloc);

    ch.reverse();
    try std.testing.expect(try ed.applyChange(&ch));
    var t = try ed.fullText();
    defer t.deinit(alloc);
    try std.testing.expectEqualStrings("z", t.items);
}

test "shape_as_needed consumes cursor_moved" {
    const alloc = std.testing.allocator;
    var fsys = try FontSystem.init(alloc);
    defer fsys.deinit();
    var ed = try Editor.init(alloc);
    defer ed.deinit();
    try ed.insertString("hi", null);
    try std.testing.expect(ed.cursor_moved);
    try ed.shapeAsNeeded(&fsys, false);
    try std.testing.expect(!ed.cursor_moved);
    // Second call takes the scroll branch and stays clear.
    try ed.shapeAsNeeded(&fsys, true);
    try std.testing.expect(!ed.cursor_moved);
}

fn truncI32(v: f32) i32 {
    return @intFromFloat(@trunc(v));
}

fn truncU32(v: f32) u32 {
    return @intFromFloat(@trunc(v));
}

test "render highlights selection and cursor" {
    const alloc = std.testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    var ed = try Editor.init(alloc);
    defer ed.deinit();
    ed.bufferMut().width_opt = 200;

    // Underlined text so the decoration pass also sits between cursor and
    // glyphs in the order assertion.
    var attrs0 = Attrs.init(alloc);
    defer attrs0.deinit();
    _ = attrs0.with_underline(.single);
    const list = try AttrsList.init(alloc, &attrs0);
    // insertAt takes ownership of the attrs list (mirrors Rust move).
    _ = try ed.insertAt(Cursor.new(0, 0), "ab", list);

    ed.cursor = Cursor.new(0, 1);
    ed.selection = .{ .normal = Cursor.new(0, 0) };
    try shapeEditor(&ed, &tfs.font_system);

    const run = firstRun(&ed);
    try std.testing.expect(run.glyphs.len >= 2);
    try std.testing.expect(run.decorations.len >= 1);

    // Expected geometry from the same public layout API the renderer uses.
    var spans = try run.highlight(alloc, Cursor.new(0, 0), Cursor.new(0, 1));
    defer spans.deinit(alloc);
    try std.testing.expect(spans.items.len >= 1);
    const cursor_x = run.cursorPosition(&ed.cursor).?;

    var tr = TestRenderer.init(alloc);
    defer tr.deinit();
    try ed.render(tr.renderer(), testColor(1), testColor(2), testColor(3), testColor(4));
    try std.testing.expect(!tr.append_failed);

    // Upstream order: selection rect(s), cursor rect, decoration rect(s),
    // then one glyph per laid-out glyph.
    var idx: usize = 0;
    for (spans.items) |h| {
        const ev = tr.events.items[idx];
        idx += 1;
        try std.testing.expectEqual(EventKind.rect, ev.kind);
        try std.testing.expect(ev.color.eql(testColor(3)));
        try std.testing.expectEqual(truncI32(h.x), ev.x);
        try std.testing.expectEqual(truncI32(run.line_top), ev.y);
        try std.testing.expectEqual(truncU32(h.width), ev.w);
        try std.testing.expectEqual(truncU32(run.line_height), ev.h);
    }
    {
        const ev = tr.events.items[idx];
        idx += 1;
        try std.testing.expectEqual(EventKind.rect, ev.kind);
        try std.testing.expect(ev.color.eql(testColor(2)));
        try std.testing.expectEqual(truncI32(cursor_x), ev.x);
        try std.testing.expectEqual(truncI32(run.line_top), ev.y);
        try std.testing.expectEqual(@as(u32, 1), ev.w);
        try std.testing.expectEqual(truncU32(run.line_height), ev.h);
    }
    // Decorations come after the cursor, before any glyph, in text color.
    var deco_count: usize = 0;
    while (idx < tr.events.items.len and tr.events.items[idx].kind == .rect) : (idx += 1) {
        try std.testing.expect(tr.events.items[idx].color.eql(testColor(1)));
        deco_count += 1;
    }
    try std.testing.expect(deco_count >= 1);

    // Glyphs: selected clusters use `selected_text_color`, others keep the
    // glyph color or fall back to `text_color`, at `physical((0,line_y),1)`.
    try std.testing.expectEqual(run.glyphs.len, tr.events.items.len - idx);
    for (run.glyphs) |glyph| {
        const ev = tr.events.items[idx];
        idx += 1;
        try std.testing.expectEqual(EventKind.glyph, ev.kind);
        const physical = glyph.physical(0.0, run.line_y, 1.0);
        try std.testing.expectEqual(physical.x, ev.x);
        try std.testing.expectEqual(physical.y, ev.y);
        // Selection is (0,0)..(0,1), so only the glyph starting at 0 is
        // selected; the rest keep the fallback text color.
        const expected = if (glyph.start < 1) testColor(4) else testColor(1);
        try std.testing.expect(ev.color.eql(expected));
    }
    try std.testing.expectEqual(tr.events.items.len, idx);
}

test "render empty interior line highlights full width" {
    const alloc = std.testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    var ed = try Editor.init(alloc);
    defer ed.deinit();
    ed.bufferMut().width_opt = 200;
    _ = try ed.insertAt(Cursor.new(0, 0), "a\n\nb", null);
    ed.cursor = Cursor.new(2, 1);
    ed.selection = .{ .normal = Cursor.new(0, 0) };
    try shapeEditor(&ed, &tfs.font_system);

    // Locate the middle (empty) run.
    var middle_top: ?i32 = null;
    var middle_height: u32 = 0;
    {
        var runs = ed.buffer().layoutRuns();
        while (runs.next()) |run| {
            if (run.line_i == 1) {
                middle_top = truncI32(run.line_top);
                middle_height = truncU32(run.line_height);
            }
        }
    }
    try std.testing.expect(middle_top != null);

    var tr = TestRenderer.init(alloc);
    defer tr.deinit();
    try ed.render(tr.renderer(), testColor(1), testColor(2), testColor(3), testColor(4));

    var saw_full = false;
    for (tr.events.items) |ev| {
        // The empty internal line gets a full-width selection rect.
        if (ev.kind == .rect and ev.color.eql(testColor(3)) and ev.y == middle_top.?) {
            try std.testing.expectEqual(@as(i32, 0), ev.x);
            try std.testing.expectEqual(@as(u32, 200), ev.w);
            try std.testing.expectEqual(middle_height, ev.h);
            saw_full = true;
        }
    }
    try std.testing.expect(saw_full);
}

test "render decorations emit rects" {
    const alloc = std.testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    var ed = try Editor.init(alloc);
    defer ed.deinit();
    ed.bufferMut().width_opt = 200;
    var default_attrs = Attrs.init(alloc);
    defer default_attrs.deinit();
    _ = default_attrs.with_underline(.single);
    const list = try AttrsList.init(alloc, &default_attrs);
    _ = try ed.insertAt(Cursor.new(0, 0), "ab", list);
    ed.cursor = Cursor.new(0, 0);
    try shapeEditor(&ed, &tfs.font_system);

    var tr = TestRenderer.init(alloc);
    defer tr.deinit();
    try ed.render(tr.renderer(), testColor(9), testColor(2), testColor(3), testColor(4));
    try std.testing.expect(!tr.append_failed);

    // Underline decoration uses the default text color and precedes glyphs.
    var saw_deco = false;
    var saw_glyph = false;
    for (tr.events.items) |ev| {
        if (ev.kind == .glyph) saw_glyph = true;
        if (ev.kind == .rect and ev.color.eql(testColor(9)) and !saw_glyph) saw_deco = true;
    }
    try std.testing.expect(saw_deco);
    try std.testing.expect(saw_glyph);
    // No selection: nothing is drawn in the selection color.
    try std.testing.expect(!hasRect(tr.events.items, testColor(3)));
}

test "render RTL cursor and selection mirror without underflow" {
    const alloc = std.testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    var ed = try Editor.init(alloc);
    defer ed.deinit();
    ed.bufferMut().width_opt = 200;

    var attrs_he = Attrs.init(alloc);
    defer attrs_he.deinit();
    attrs_he.family = .{ .name = "Noto Sans Hebrew" };
    const list = try AttrsList.init(alloc, &attrs_he);
    _ = try ed.insertAt(Cursor.new(0, 0), "\u{05D0}\u{05D1}\n\u{05D2}\u{05D3}", list);

    ed.cursor = Cursor.new(0, 0);
    ed.selection = .{ .normal = Cursor.new(1, 1) }; // multi-line, RTL runs
    try shapeEditor(&ed, &tfs.font_system);

    var runs = ed.buffer().layoutRuns();
    const run0 = runs.next().?;
    try std.testing.expect(run0.line_i == 0);
    try std.testing.expect(run0.rtl);
    try std.testing.expect(run0.glyphs.len >= 2);

    // Mirrored placement: the logical start of a pure RTL run sits at the
    // visual right, the logical end at the visual left.
    const text_len = ed.buffer().lines.items[0].textSlice().len;
    const x_start = run0.cursorPosition(&Cursor.new(0, 0)).?;
    const x_end = run0.cursorPosition(&Cursor.new(0, text_len)).?;
    try std.testing.expect(x_start > x_end);

    var tr = TestRenderer.init(alloc);
    defer tr.deinit();
    try ed.render(tr.renderer(), testColor(1), testColor(2), testColor(3), testColor(4));
    try std.testing.expect(!tr.append_failed);

    // Cursor rect at the mirrored x on line 0 (height = run line height).
    const line_top = truncI32(run0.line_top);
    const line_height = truncU32(run0.line_height);
    var saw_cursor = false;
    for (tr.events.items) |ev| {
        if (ev.kind == .rect and ev.color.eql(testColor(2)) and ev.y == line_top) {
            try std.testing.expectEqual(truncI32(x_start), ev.x);
            try std.testing.expectEqual(@as(u32, 1), ev.w);
            try std.testing.expectEqual(line_height, ev.h);
            saw_cursor = true;
        }
    }
    try std.testing.expect(saw_cursor);

    // Selection rects on line 0 match `run.highlight`; the multi-line RTL
    // extension pins the last span to x=0 and widths never underflow.
    var spans = try run0.highlight(alloc, Cursor.new(0, 0), Cursor.new(1, 1));
    defer spans.deinit(alloc);
    try std.testing.expect(spans.items.len >= 1);
    var sel_count: usize = 0;
    for (tr.events.items) |ev| {
        if (ev.kind != .rect or !ev.color.eql(testColor(3)) or ev.y != line_top) continue;
        if (sel_count < spans.items.len) {
            const h = spans.items[sel_count];
            const min: i32 = if (sel_count == spans.items.len - 1) 0 else truncI32(h.x);
            const max = truncI32(h.x + h.width);
            try std.testing.expectEqual(min, ev.x);
            try std.testing.expectEqual(@as(u32, @intCast(@max(max - min, 0))), ev.w);
            try std.testing.expect(ev.w <= 1000); // no u32 underflow wrap
        }
        sel_count += 1;
    }
    try std.testing.expectEqual(spans.items.len, sel_count);
}

test "render without selection or cursor draws only text and decorations" {
    const alloc = std.testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    var ed = try Editor.init(alloc);
    defer ed.deinit();
    ed.bufferMut().width_opt = 200;
    _ = try ed.insertAt(Cursor.new(0, 0), "ab\n", null);
    var attrs_u = Attrs.init(alloc);
    defer attrs_u.deinit();
    _ = attrs_u.with_underline(.single);
    const list = try AttrsList.init(alloc, &attrs_u);
    _ = try ed.insertAt(Cursor.new(1, 0), "cd", list);
    ed.cursor = Cursor.new(0, 0);
    ed.selection = .{ .none = {} };
    try shapeEditor(&ed, &tfs.font_system);

    var runs = ed.buffer().layoutRuns();
    const run0 = runs.next().?;
    const run1 = runs.next().?;
    try std.testing.expect(run0.glyphs.len > 0 and run1.glyphs.len > 0);

    var tr = TestRenderer.init(alloc);
    defer tr.deinit();
    try ed.render(tr.renderer(), testColor(9), testColor(2), testColor(3), testColor(4));
    try std.testing.expect(!tr.append_failed);

    // No selection anywhere, exactly one cursor rect (line 0).
    try std.testing.expect(!hasRect(tr.events.items, testColor(3)));
    var cursor_rects: usize = 0;
    var deco_rects: usize = 0;
    var glyphs0: usize = 0;
    var glyphs1: usize = 0;
    for (tr.events.items) |ev| {
        switch (ev.kind) {
            .glyph => {
                try std.testing.expect(ev.color.eql(testColor(9)));
                if (ev.y == truncI32(run0.line_y)) glyphs0 += 1;
                if (ev.y == truncI32(run1.line_y)) glyphs1 += 1;
            },
            .rect => {
                if (ev.color.eql(testColor(2))) cursor_rects += 1;
                if (ev.color.eql(testColor(9))) deco_rects += 1;
            },
        }
    }
    try std.testing.expectEqual(@as(usize, 1), cursor_rects);
    try std.testing.expect(deco_rects >= 1);
    try std.testing.expectEqual(run0.glyphs.len, glyphs0);
    try std.testing.expectEqual(run1.glyphs.len, glyphs1);
}

test "render empty editor draws nothing" {
    const alloc = std.testing.allocator;
    var ed = try Editor.init(alloc);
    defer ed.deinit();
    var tr = TestRenderer.init(alloc);
    defer tr.deinit();

    // Unshaped: `layoutRuns` yields nothing, so neither does render.
    try ed.render(tr.renderer(), testColor(1), testColor(2), testColor(3), testColor(4));
    try std.testing.expectEqual(@as(usize, 0), tr.events.items.len);

    // A shaped empty line is a real run; upstream's `cursor_glyph` returns
    // (0, 0) for an empty glyph list, so only the 1px caret is drawn.
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    try shapeEditor(&ed, &tfs.font_system);
    try ed.render(tr.renderer(), testColor(1), testColor(2), testColor(3), testColor(4));
    try std.testing.expectEqual(@as(usize, 1), tr.events.items.len);
    const ev = tr.events.items[0];
    try std.testing.expectEqual(EventKind.rect, ev.kind);
    try std.testing.expect(ev.color.eql(testColor(2)));
    try std.testing.expectEqual(@as(i32, 0), ev.x);
    try std.testing.expectEqual(@as(u32, 1), ev.w);
}

test "draw forwards render rectangles through LegacyRenderer" {
    const alloc = std.testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    var ed = try Editor.init(alloc);
    defer ed.deinit();
    ed.bufferMut().width_opt = 200;
    _ = try ed.insertAt(Cursor.new(0, 0), "ab", null);
    ed.cursor = Cursor.new(0, 1);
    ed.selection = .{ .normal = Cursor.new(0, 0) };

    // Direct `render` output (after shaping) for comparison.
    try shapeEditor(&ed, &tfs.font_system);
    var direct = TestRenderer.init(alloc);
    defer direct.deinit();
    try ed.render(direct.renderer(), testColor(1), testColor(2), testColor(3), testColor(4));
    var direct_rects: usize = 0;
    for (direct.events.items) |ev| {
        if (ev.kind == .rect) direct_rects += 1;
    }
    try std.testing.expect(direct_rects >= 2); // selection + cursor

    // `draw` shapes itself and lowers glyph masks to 1x1 rectangles; the
    // rectangle prefix must be identical to `render`'s.
    var raster = swash_cache_mod.FallbackRaster{};
    var cache = swash_cache_mod.SwashCache.init(alloc, raster.adapter());
    defer cache.deinit();
    var drawn = TestRenderer.init(alloc);
    defer drawn.deinit();
    try ed.draw(
        &tfs.font_system,
        &cache,
        testColor(1),
        testColor(2),
        testColor(3),
        testColor(4),
        drawn.callback(),
    );
    try std.testing.expect(!drawn.append_failed);
    try std.testing.expect(drawn.events.items.len >= direct_rects);

    var di: usize = 0;
    while (di < direct_rects) : (di += 1) {
        const want = direct.events.items[di];
        const got = drawn.events.items[di];
        try std.testing.expectEqual(EventKind.rect, want.kind);
        try std.testing.expectEqual(EventKind.rect, got.kind);
        try std.testing.expectEqual(want.x, got.x);
        try std.testing.expectEqual(want.y, got.y);
        try std.testing.expectEqual(want.w, got.w);
        try std.testing.expectEqual(want.h, got.h);
        try std.testing.expect(want.color.eql(got.color));
    }
}

test "hit rejects NaN/inf and saturates huge y" {
    const alloc = std.testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    var ed = try Editor.init(alloc);
    defer ed.deinit();

    // Unshaped/empty buffer: no runs, so hit and cursorPosition are null
    // (never a panic) until the caller shapes.
    try std.testing.expect(ed.hit(5, 5) == null);
    try std.testing.expect(ed.cursorPosition() == null);

    _ = try ed.insertAt(Cursor.new(0, 0), "a\nb", null);
    try shapeEditor(&ed, &tfs.font_system);

    // Non-finite coordinates map to no cursor.
    try std.testing.expect(ed.hit(5, std.math.nan(f32)) == null);
    try std.testing.expect(ed.hit(5, std.math.inf(f32)) == null);
    try std.testing.expect(ed.hit(5, -std.math.inf(f32)) == null);
    try std.testing.expect(ed.hit(std.math.nan(f32), 5) == null);
    // Huge finite y saturates to the last line instead of trapping.
    const huge = ed.hit(5, 1e30).?;
    try std.testing.expect(huge.line == ed.buffer().lines.items.len - 1);
    try std.testing.expect(huge.index == ed.buffer().lines.items[huge.line].textSlice().len);
    // Negative y clamps to the start of the buffer.
    const neg = ed.hit(5, -5).?;
    try std.testing.expect(neg.line == 0 and neg.index == 0);
    // Cursors past the end of the buffer are rejected, not trapped.
    ed.cursor = Cursor.new(99, 99);
    try std.testing.expect(ed.cursorPosition() == null);
}

test "word motions handle more than 64 tokens" {
    const alloc = std.testing.allocator;
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(alloc);
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        try text.appendSlice(alloc, "a ");
    }
    const s = text.items;
    // UAX #29 word starts are 0, 2, 4, …; ends 1, 3, 5, ….
    try std.testing.expect(nextWordEnd(s, 0) == 1);
    try std.testing.expect(prevWordStart(s, s.len) == 198);
    try std.testing.expect(prevWordStart(s, 100) == 98);
    try std.testing.expect(nextWordEnd(s, 100) == 101);
    try std.testing.expect(prevWordStart(s, 150) == 148);
    try std.testing.expect(nextWordEnd(s, 148) == 149);
}

test "firstNonWhitespace handles unicode spaces" {
    const s = " \t\xc2\xa0\xe2\x80\x83hi";
    try std.testing.expect(firstNonWhitespace(s) == 7);
    try std.testing.expect(firstNonWhitespace("") == 0);
    try std.testing.expect(firstNonWhitespace("   ") == 0);
    try std.testing.expect(unicode.isWhitespace(0xA0));
    try std.testing.expect(unicode.isWhitespace(0x2003));
    try std.testing.expect(!unicode.isWhitespace('a'));
}

test "empty line hit and cursor sit at horizontal zero" {
    const alloc = std.testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    var ed = try Editor.init(alloc);
    defer ed.deinit();
    try ed.insertString("a\n\nb", null);
    try shapeEditor(&ed, &tfs.font_system);

    // Locate the middle (empty) run through the public layout API.
    var middle_opt: ?buffer_mod.LayoutRun = null;
    var runs = ed.buffer().layoutRuns();
    while (runs.next()) |run| {
        if (run.line_i == 1) middle_opt = run;
    }
    const middle = middle_opt.?;
    try std.testing.expect(middle.glyphs.len == 0);

    // Hit maps to the empty line's start and the cursor sits at x=0 on the
    // same line top the renderer uses.
    const hit = ed.hit(50, middle.line_top + middle.line_height / 2.0).?;
    try std.testing.expect(hit.line == 1 and hit.index == 0);
    ed.cursor = Cursor.new(1, 0);
    const pos = ed.cursorPosition().?;
    try std.testing.expect(pos.x == 0);
    try std.testing.expectEqual(middle.line_top, pos.y);
}

test "click maps to the glyph under x" {
    const alloc = std.testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    const fsys = &tfs.font_system;
    var ed = try Editor.init(alloc);
    defer ed.deinit();
    try ed.insertString("hello", null);
    try shapeEditor(&ed, fsys);

    const run = firstRun(&ed);
    try std.testing.expect(run.glyphs.len == 5);
    const y = run.line_top + run.line_height / 2.0;

    // Left half of a glyph -> index at its start; right half -> its end.
    for (run.glyphs) |glyph| {
        const left = ed.hit(glyph.x + glyph.w * 0.25, y).?;
        try std.testing.expectEqual(glyph.start, left.index);
        const right = ed.hit(glyph.x + glyph.w * 0.75, y).?;
        try std.testing.expectEqual(glyph.end, right.index);
    }

    // Past the last glyph -> end of line.
    const last = run.glyphs[run.glyphs.len - 1];
    const after = ed.hit(last.x + last.w + 100.0, y).?;
    try std.testing.expectEqual(@as(usize, 5), after.index);

    // The click action resolves to the same cursor from the same geometry.
    const third = run.glyphs[2];
    const click_x: i32 = @intFromFloat(third.x + third.w * 0.25);
    const click_y: i32 = @intFromFloat(y);
    try ed.action(fsys, .{ .click = .{ .x = click_x, .y = click_y } });
    try std.testing.expectEqual(third.start, ed.cursor.index);
    try std.testing.expect(ed.cursor.line == 0);
}

test "left/right motion across an RTL run mirrors" {
    const alloc = std.testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    const fsys = &tfs.font_system;
    var ed = try Editor.init(alloc);
    defer ed.deinit();
    ed.bufferMut().width_opt = 200;

    var attrs_he = Attrs.init(alloc);
    defer attrs_he.deinit();
    attrs_he.family = .{ .name = "Noto Sans Hebrew" };
    const list = try AttrsList.init(alloc, &attrs_he);
    // "אב" (two 2-byte Hebrew letters) shapes as one pure RTL run.
    _ = try ed.insertAt(Cursor.new(0, 0), "\u{05D0}\u{05D1}", list);
    try shapeEditor(&ed, fsys);
    try std.testing.expect(ed.buffer().isRtl(0).?);

    // In an RTL run Left advances the logical index (visually left) and Right
    // steps it back, both clamped at the ends.
    ed.cursor = Cursor.new(0, 0);
    ed.cursor_x_opt = null;
    try ed.action(fsys, .{ .motion = .left });
    try std.testing.expectEqual(@as(usize, 2), ed.cursor.index);
    try ed.action(fsys, .{ .motion = .left });
    try std.testing.expectEqual(@as(usize, 4), ed.cursor.index);
    try ed.action(fsys, .{ .motion = .left });
    try std.testing.expectEqual(@as(usize, 4), ed.cursor.index);
    try ed.action(fsys, .{ .motion = .right });
    try std.testing.expectEqual(@as(usize, 2), ed.cursor.index);
    try ed.action(fsys, .{ .motion = .right });
    try std.testing.expectEqual(@as(usize, 0), ed.cursor.index);
    try ed.action(fsys, .{ .motion = .right });
    try std.testing.expectEqual(@as(usize, 0), ed.cursor.index);

    // LTR keeps the logical direction: Left steps back, Right steps forward.
    var ltr = try Editor.init(alloc);
    defer ltr.deinit();
    try ltr.insertString("ab", null);
    try shapeEditor(&ltr, fsys);
    ltr.cursor = Cursor.new(0, 2);
    try ltr.action(fsys, .{ .motion = .left });
    try std.testing.expectEqual(@as(usize, 1), ltr.cursor.index);
    try ltr.action(fsys, .{ .motion = .right });
    try std.testing.expectEqual(@as(usize, 2), ltr.cursor.index);
}

test "up/down motion keeps the visual column" {
    const alloc = std.testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    const fsys = &tfs.font_system;
    var ed = try Editor.init(alloc);
    defer ed.deinit();
    try ed.insertString("aaaa\nbb\ncccc", null);
    try shapeEditor(&ed, fsys);

    ed.cursor = Cursor.new(0, 3);
    ed.cursor_x_opt = null;
    // Short middle line clamps to its end, but the visual column is kept.
    try ed.action(fsys, .{ .motion = .down });
    try std.testing.expectEqual(@as(usize, 1), ed.cursor.line);
    try std.testing.expectEqual(@as(usize, 2), ed.cursor.index);
    try ed.action(fsys, .{ .motion = .down });
    try std.testing.expectEqual(@as(usize, 2), ed.cursor.line);
    try std.testing.expectEqual(@as(usize, 3), ed.cursor.index);
    try ed.action(fsys, .{ .motion = .up });
    try std.testing.expectEqual(@as(usize, 1), ed.cursor.line);
    try std.testing.expectEqual(@as(usize, 2), ed.cursor.index);
    try ed.action(fsys, .{ .motion = .up });
    try std.testing.expectEqual(@as(usize, 0), ed.cursor.line);
    try std.testing.expectEqual(@as(usize, 3), ed.cursor.index);

    // A plain Left clears the hint, so Down re-derives the column.
    try ed.action(fsys, .{ .motion = .left });
    try std.testing.expect(ed.cursor_x_opt == null);
    try ed.action(fsys, .{ .motion = .down });
    try std.testing.expectEqual(@as(usize, 1), ed.cursor.line);
    try std.testing.expectEqual(@as(usize, 2), ed.cursor.index);
}

test "layout_cursor motion maps through the real layout cursor" {
    const alloc = std.testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    const fsys = &tfs.font_system;
    var ed = try Editor.init(alloc);
    defer ed.deinit();
    try ed.insertString("hello", null);
    try shapeEditor(&ed, fsys);

    // Glyph 3 -> byte start of the fourth glyph, `after` affinity.
    ed.cursor = Cursor.new(0, 0);
    try ed.action(fsys, .{ .motion = .{ .layout_cursor = LayoutCursor.new(0, 0, 3) } });
    try std.testing.expectEqual(@as(usize, 3), ed.cursor.index);
    try std.testing.expectEqual(Affinity.after, ed.cursor.affinity);

    // Past the last glyph -> run end with `before` affinity (never a panic).
    try ed.action(fsys, .{ .motion = .{ .layout_cursor = LayoutCursor.new(0, 0, 99) } });
    try std.testing.expectEqual(@as(usize, 5), ed.cursor.index);
    try std.testing.expectEqual(Affinity.before, ed.cursor.affinity);
}

test "word, home, end and buffer motions route through the buffer" {
    const alloc = std.testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    const fsys = &tfs.font_system;
    var ed = try Editor.init(alloc);
    defer ed.deinit();
    try ed.insertString("hello world\nsecond", null);
    try shapeEditor(&ed, fsys);

    ed.cursor = Cursor.new(0, 0);
    ed.cursor_x_opt = null;
    try ed.action(fsys, .{ .motion = .next_word });
    try std.testing.expectEqual(@as(usize, 5), ed.cursor.index);
    try ed.action(fsys, .{ .motion = .next_word });
    try std.testing.expectEqual(@as(usize, 11), ed.cursor.index);
    try ed.action(fsys, .{ .motion = .previous_word });
    try std.testing.expectEqual(@as(usize, 6), ed.cursor.index);
    try ed.action(fsys, .{ .motion = .left_word });
    try std.testing.expectEqual(@as(usize, 0), ed.cursor.index);
    try ed.action(fsys, .{ .motion = .right_word });
    try std.testing.expectEqual(@as(usize, 5), ed.cursor.index);

    try ed.action(fsys, .{ .motion = .end });
    try std.testing.expectEqual(@as(usize, 11), ed.cursor.index);
    try ed.action(fsys, .{ .motion = .home });
    try std.testing.expectEqual(@as(usize, 0), ed.cursor.index);
    try ed.action(fsys, .{ .motion = .buffer_end });
    try std.testing.expectEqual(@as(usize, 1), ed.cursor.line);
    try std.testing.expectEqual(@as(usize, 6), ed.cursor.index);
    try ed.action(fsys, .{ .motion = .buffer_start });
    try std.testing.expectEqual(@as(usize, 0), ed.cursor.line);
    try std.testing.expectEqual(@as(usize, 0), ed.cursor.index);
}

test "double click selects word and punctuation runs via layout hit" {
    const alloc = std.testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    const fsys = &tfs.font_system;
    var ed = try Editor.init(alloc);
    defer ed.deinit();
    try ed.insertString("hello, world", null);
    try shapeEditor(&ed, fsys);

    const run = firstRun(&ed);
    try std.testing.expect(run.glyphs.len == 12);
    const y: i32 = @intFromFloat(run.line_top + run.line_height / 2.0);

    // Double-click inside "world": the word run is bytes 7..12.
    const o = run.glyphs[8];
    const wx: i32 = @intFromFloat(o.x + o.w * 0.25);
    try ed.action(fsys, .{ .double_click = .{ .x = wx, .y = y } });
    try std.testing.expect(ed.selection == .word);
    var bounds = ed.selectionBounds().?;
    try std.testing.expect(bounds.start.index == 7 and bounds.end.index == 12);

    // Double-click on the comma: UAX #29 word runs skip punctuation, so the
    // selection spans the surrounding words ("hello, world").
    const comma = run.glyphs[5];
    const cx: i32 = @intFromFloat(comma.x + comma.w * 0.25);
    try ed.action(fsys, .{ .double_click = .{ .x = cx, .y = y } });
    bounds = ed.selectionBounds().?;
    try std.testing.expect(bounds.start.index == 0 and bounds.end.index == 12);

    // Triple-click on the same glyph selects the whole line.
    try ed.action(fsys, .{ .triple_click = .{ .x = cx, .y = y } });
    try std.testing.expect(ed.selection == .line);
    bounds = ed.selectionBounds().?;
    try std.testing.expect(bounds.start.index == 0 and bounds.end.index == 12);
}

test "page up/down moves by the viewport height" {
    const alloc = std.testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    const fsys = &tfs.font_system;
    var ed = try Editor.init(alloc);
    defer ed.deinit();
    try ed.insertString("a\nb\nc\nd\ne", null);
    try shapeEditor(&ed, fsys);
    // Two 20px lines fit in the viewport -> PageUp/Down move two lines.
    ed.bufferMut().height_opt = 40;

    ed.cursor = Cursor.new(4, 1);
    ed.cursor_x_opt = null;
    try ed.action(fsys, .{ .motion = .page_up });
    try std.testing.expectEqual(@as(usize, 2), ed.cursor.line);
    try std.testing.expectEqual(@as(usize, 1), ed.cursor.index);

    ed.cursor = Cursor.new(0, 1);
    ed.cursor_x_opt = null;
    try ed.action(fsys, .{ .motion = .page_down });
    try std.testing.expectEqual(@as(usize, 2), ed.cursor.line);
    try std.testing.expectEqual(@as(usize, 1), ed.cursor.index);

    // No viewport height: the motion is a no-op (upstream `height_opt`).
    ed.bufferMut().height_opt = null;
    ed.cursor = Cursor.new(4, 1);
    ed.cursor_x_opt = null;
    try ed.action(fsys, .{ .motion = .page_up });
    try std.testing.expectEqual(@as(usize, 4), ed.cursor.line);
}

test "scroll action routes through Buffer.setScroll" {
    const alloc = std.testing.allocator;
    var tfs = try TestFontSystem.init(alloc);
    defer tfs.deinit();
    const fsys = &tfs.font_system;
    var ed = try Editor.init(alloc);
    defer ed.deinit();
    try ed.insertString("a\nb\nc\nd\ne", null);
    ed.bufferMut().height_opt = 40;
    try shapeEditor(&ed, fsys);

    try ed.action(fsys, .{ .scroll = .{ .pixels = 25 } });
    try std.testing.expectEqual(@as(f32, 25), ed.buffer().getScroll().vertical);
    try std.testing.expect(ed.buffer().dirty.scroll);
    try std.testing.expect(ed.buffer().getRedraw());

    // Shaping consumes the dirty flag and normalizes 25px into a line plus
    // pixel remainder (20px line height).
    try ed.bufferMut().shapeUntilScroll(fsys, false);
    try std.testing.expect(!ed.buffer().dirty.scroll);
    try std.testing.expectEqual(@as(usize, 1), ed.buffer().getScroll().line);
    try std.testing.expectEqual(@as(f32, 5), ed.buffer().getScroll().vertical);

    // Scrolling above the first line clamps back to the top.
    try ed.action(fsys, .{ .scroll = .{ .pixels = -100 } });
    try ed.bufferMut().shapeUntilScroll(fsys, false);
    try std.testing.expectEqual(@as(usize, 0), ed.buffer().getScroll().line);
    try std.testing.expectEqual(@as(f32, 0), ed.buffer().getScroll().vertical);
}

test "motions and cursor queries on an empty buffer do not panic" {
    const alloc = std.testing.allocator;
    var fsys = try FontSystem.init(alloc);
    defer fsys.deinit();
    var ed = try Editor.init(alloc);
    defer ed.deinit();

    // Unshaped empty buffer: hit/cursorPosition return null instead of
    // indexing into missing layout.
    try std.testing.expect(ed.hit(0, 0) == null);
    try std.testing.expect(ed.cursorPosition() == null);

    // Cursors past the end: line-bound motions no-op, `home` only resets the
    // index (upstream semantics), and nothing traps.
    ed.cursor = Cursor.new(99, 99);
    try ed.action(&fsys, .{ .motion = .left });
    try std.testing.expectEqual(@as(usize, 99), ed.cursor.line);
    try ed.action(&fsys, .{ .motion = .up });
    try ed.action(&fsys, .{ .motion = .down });
    try ed.action(&fsys, .{ .motion = .end });
    try std.testing.expectEqual(@as(usize, 99), ed.cursor.line);
    try ed.action(&fsys, .{ .motion = .home });
    try std.testing.expectEqual(@as(usize, 0), ed.cursor.index);
    try ed.action(&fsys, .{ .motion = .buffer_end });
    try std.testing.expectEqual(@as(usize, 0), ed.cursor.line);
    try std.testing.expectEqual(@as(usize, 0), ed.cursor.index);
}

test "edit with borrowed buffer leaves it intact on deinit" {
    const alloc = std.testing.allocator;
    var buf = try Buffer.initWithAllocator(alloc, .{ .font_size = 14, .line_height = 20 });
    defer buf.deinit();
    try buf.lines.append(alloc, BufferLine.empty(alloc));
    {
        var ed = Editor.initWithBuffer(alloc, &buf);
        try ed.insertString("borrowed", null);
        var t = try ed.fullText();
        defer t.deinit(alloc);
        try std.testing.expectEqualStrings("borrowed", t.items);
        ed.deinit();
    }
    try std.testing.expect(buf.lines.items.len == 1);
    try std.testing.expectEqualStrings("borrowed", buf.lines.items[0].textSlice());
}

test "e2e: type e+U+0301cole, Delete at 0 leaves \"cole\" (real font fixture)" {
    const alloc = std.testing.allocator;
    var fsys = try FontSystem.init(alloc);
    defer fsys.deinit();

    // Real font from the checked-in corpus (`../tests/fonts` from `src/`).
    const font_bytes = try readFontFixture(alloc);
    defer alloc.free(font_bytes);
    var real_font = try font_mod.Font.init(alloc, 0, font_bytes, false, null);
    defer real_font.deinit();
    try std.testing.expect(real_font.metrics().units_per_em > 0);

    // Register the face so the real buffer shaping path resolves it.
    _ = try fsys.dbMut().addFace(
        "tests/fonts/Inter-Regular.ttf",
        0,
        &.{"Inter"},
        "Inter-Regular",
        font_system.WEIGHT_NORMAL,
        .normal,
        .normal,
        false,
    );

    var ed = try Editor.init(alloc);
    defer ed.deinit();

    // Type "e" + U+0301 (combining acute) + "cole".
    try ed.action(&fsys, .{ .insert = 'e' });
    try ed.action(&fsys, .{ .insert = 0x0301 });
    try ed.action(&fsys, .{ .insert = 'c' });
    try ed.action(&fsys, .{ .insert = 'o' });
    try ed.action(&fsys, .{ .insert = 'l' });
    try ed.action(&fsys, .{ .insert = 'e' });

    // Shape through the real Buffer/FontSystem path (not the old no-op).
    try ed.shapeAsNeeded(&fsys, false);

    // Delete at index 0 must remove both codepoints of the cluster.
    try ed.action(&fsys, .{ .motion = .home });
    try ed.action(&fsys, .delete);

    var t = try ed.fullText();
    defer t.deinit(alloc);
    try std.testing.expectEqualStrings("cole", t.items);
}
