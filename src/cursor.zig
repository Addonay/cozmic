//! Cursor, affinity, motion, and scroll types.
//!
//! Port of cosmic-text `cursor.rs`. Self-contained; depends only on `std`.
//!
//! Naming note: Zig keeps enum tags and declarations in a single namespace,
//! so a tag named `before` cannot coexist with a method named `before()`.
//! Tags therefore use idiomatic lowercase (`before`/`after`, matching Rust's
//! `Before`/`After` modulo case) while the predicates are named
//! `isBefore`/`isAfter`. Capitalized `Before`/`After` aliases are provided
//! for readers coming from the Rust source.

const std = @import("std");

/// Whether a cursor placed at a boundary between runs associates with the
/// run before it or the run after it.
pub const Affinity = enum(u8) {
    before = 0,
    after = 1,

    /// Mirror of Rust's `Affinity::Before` spelling.
    pub const Before: @This() = .before;
    /// Mirror of Rust's `Affinity::After` spelling.
    pub const After: @This() = .after;

    /// Mirror of Rust's `#[default] Before`.
    pub const default: @This() = .before;

    /// Rust parity: `Affinity::before`.
    pub fn isBefore(self: Affinity) bool {
        return self == .before;
    }

    /// Rust parity: `Affinity::after`.
    pub fn isAfter(self: Affinity) bool {
        return self == .after;
    }

    /// Total order matching Rust's derived `Ord` (`Before` < `After`).
    pub fn order(self: Affinity, other: Affinity) std.math.Order {
        return std.math.order(@backingInt(self), @backingInt(other));
    }

    /// Rust parity: `Affinity::from_before`.
    pub fn fromBefore(before: bool) Affinity {
        return if (before) .before else .after;
    }

    /// Alias using Rust's snake_case spelling.
    pub fn from_before(before: bool) Affinity {
        return fromBefore(before);
    }

    /// Rust parity: `Affinity::from_after`.
    pub fn fromAfter(after: bool) Affinity {
        return if (after) .after else .before;
    }

    /// Alias using Rust's snake_case spelling.
    pub fn from_after(after: bool) Affinity {
        return fromAfter(after);
    }
};

/// Current cursor location: index of buffer line, byte index of the glyph
/// the cursor inserts in front of, and run affinity.
pub const Cursor = struct {
    line: usize = 0,
    index: usize = 0,
    affinity: Affinity = .before,

    /// Create a new cursor with `before` affinity.
    pub fn new(line: usize, index: usize) Cursor {
        return .{ .line = line, .index = index, .affinity = .before };
    }

    /// Create a new cursor, specifying the affinity.
    pub fn newWithAffinity(line: usize, index: usize, affinity: Affinity) Cursor {
        return .{ .line = line, .index = index, .affinity = affinity };
    }

    /// Alias using Rust's snake_case spelling.
    pub fn new_with_affinity(line: usize, index: usize, affinity: Affinity) Cursor {
        return newWithAffinity(line, index, affinity);
    }

    /// Total order matching Rust's derived `Ord`: line, then index, then
    /// affinity (`before` sorts before `after`).
    pub fn order(self: Cursor, other: Cursor) std.math.Order {
        if (self.line != other.line) return std.math.order(self.line, other.line);
        if (self.index != other.index) return std.math.order(self.index, other.index);
        return self.affinity.order(other.affinity);
    }

    pub fn eql(self: Cursor, other: Cursor) bool {
        return self.order(other) == .eq;
    }

    pub fn lessThan(self: Cursor, other: Cursor) bool {
        return self.order(other) == .lt;
    }
};

/// The position of a cursor within laid-out lines: buffer line, layout
/// line within it, and glyph within that.
pub const LayoutCursor = struct {
    line: usize = 0,
    layout: usize = 0,
    glyph: usize = 0,

    pub fn new(line: usize, layout: usize, glyph: usize) LayoutCursor {
        return .{ .line = line, .layout = layout, .glyph = glyph };
    }

    /// Total order matching Rust's derived `Ord`: line, layout, glyph.
    pub fn order(self: LayoutCursor, other: LayoutCursor) std.math.Order {
        if (self.line != other.line) return std.math.order(self.line, other.line);
        if (self.layout != other.layout) return std.math.order(self.layout, other.layout);
        return std.math.order(self.glyph, other.glyph);
    }

    pub fn eql(self: LayoutCursor, other: LayoutCursor) bool {
        return self.order(other) == .eq;
    }

    pub fn lessThan(self: LayoutCursor, other: LayoutCursor) bool {
        return self.order(other) == .lt;
    }
};

/// A motion to perform on a `Cursor`. Variants use Zig snake_case; the doc
/// comment on each gives the Rust `Motion::Variant` spelling.
pub const Motion = union(enum) {
    /// `Motion::LayoutCursor`
    layout_cursor: LayoutCursor,
    /// `Motion::Previous`
    previous,
    /// `Motion::Next`
    next,
    /// `Motion::Left`
    left,
    /// `Motion::Right`
    right,
    /// `Motion::Up`
    up,
    /// `Motion::Down`
    down,
    /// `Motion::Home`
    home,
    /// `Motion::SoftHome`
    soft_home,
    /// `Motion::End`
    end,
    /// `Motion::ParagraphStart`
    paragraph_start,
    /// `Motion::ParagraphEnd`
    paragraph_end,
    /// `Motion::PageUp`
    page_up,
    /// `Motion::PageDown`
    page_down,
    /// `Motion::Vertical`
    vertical: i32,
    /// `Motion::PreviousWord`
    previous_word,
    /// `Motion::NextWord`
    next_word,
    /// `Motion::LeftWord`
    left_word,
    /// `Motion::RightWord`
    right_word,
    /// `Motion::BufferStart`
    buffer_start,
    /// `Motion::BufferEnd`
    buffer_end,
    /// `Motion::GotoLine`
    goto_line: usize,

    /// Equality matching Rust's derived `PartialEq`: same variant with
    /// equal payloads.
    pub fn eql(self: Motion, other: Motion) bool {
        return std.meta.eql(self, other);
    }
};

/// Scroll position in a buffer: buffer line plus pixel offsets from the
/// start of that line.
pub const Scroll = struct {
    line: usize = 0,
    vertical: f32 = 0,
    horizontal: f32 = 0,

    pub fn new(line: usize, vertical: f32, horizontal: f32) Scroll {
        return .{ .line = line, .vertical = vertical, .horizontal = horizontal };
    }

    /// Equality matching Rust's derived `PartialEq` (exact float equality).
    /// Note: `NaN != NaN`, so a `Scroll` containing `NaN` never equals itself,
    /// matching Rust.
    pub fn eql(self: Scroll, other: Scroll) bool {
        return std.meta.eql(self, other);
    }

    /// Partial order matching Rust's derived `PartialOrd`: `line`, then
    /// `vertical`, then `horizontal` via tuple comparison with float order.
    ///
    /// Returns `null` when any float comparison is unordered (i.e. either
    /// side is `NaN`), matching Rust `PartialOrd` where `NaN` yields `None`.
    /// Otherwise returns the lexicographic order. `eql` (exact equality) and
    /// `order` agree for non-`NaN` values; `NaN` is never equal (even to
    /// itself) and never ordered.
    pub fn order(self: Scroll, other: Scroll) ?std.math.Order {
        if (self.line != other.line) return std.math.order(self.line, other.line);
        const v = partialF32Order(self.vertical, other.vertical) orelse return null;
        if (v != .eq) return v;
        return partialF32Order(self.horizontal, other.horizontal);
    }
};

fn partialF32Order(a: f32, b: f32) ?std.math.Order {
    if (a < b) return .lt;
    if (a > b) return .gt;
    if (a == b) return .eq;
    // Unordered: NaN involved (all comparisons false).
    return null;
}

fn cursorLessThan(_: void, a: Cursor, b: Cursor) bool {
    return a.lessThan(b);
}

test "affinity predicates and constructors" {
    const testing = std.testing;

    try testing.expect(Affinity.before.isBefore());
    try testing.expect(!Affinity.before.isAfter());
    try testing.expect(Affinity.after.isAfter());
    try testing.expect(!Affinity.after.isBefore());

    // Capitalized aliases mirror the Rust spelling.
    try testing.expect(Affinity.Before == .before);
    try testing.expect(Affinity.After == .after);
    try testing.expect(Affinity.default == .before);

    try testing.expect(Affinity.fromBefore(true) == .before);
    try testing.expect(Affinity.fromBefore(false) == .after);
    try testing.expect(Affinity.fromAfter(true) == .after);
    try testing.expect(Affinity.fromAfter(false) == .before);

    // Snake_case aliases behave identically.
    try testing.expect(Affinity.from_before(true) == .before);
    try testing.expect(Affinity.from_before(false) == .after);
    try testing.expect(Affinity.from_after(true) == .after);
    try testing.expect(Affinity.from_after(false) == .before);

    // Round-trip: before()/after() predicates agree with constructors.
    var i: u8 = 0;
    while (i < 4) : (i += 1) {
        const b: bool = (i & 1) != 0;
        try testing.expect(Affinity.fromBefore(b).isBefore() == b);
        try testing.expect(Affinity.fromAfter(b).isAfter() == b);
    }
}

test "cursor construction and defaults" {
    const testing = std.testing;

    const c = Cursor.new(3, 7);
    try testing.expectEqual(@as(usize, 3), c.line);
    try testing.expectEqual(@as(usize, 7), c.index);
    try testing.expect(c.affinity == .before);

    const ca = Cursor.newWithAffinity(1, 2, .after);
    try testing.expectEqual(@as(usize, 1), ca.line);
    try testing.expectEqual(@as(usize, 2), ca.index);
    try testing.expect(ca.affinity == .after);

    const cs = Cursor.new_with_affinity(1, 2, .after);
    try testing.expect(cs.eql(ca));

    // Zero value matches Rust's Default (line 0, index 0, Before).
    const z: Cursor = .{};
    try testing.expect(z.eql(Cursor.new(0, 0)));
}

test "cursor ordering" {
    const testing = std.testing;

    // Line dominates.
    try testing.expect(Cursor.new(0, 100).lessThan(Cursor.new(1, 0)));
    try testing.expect(Cursor.new(1, 0).order(Cursor.new(0, 100)) == .gt);

    // Index breaks line ties.
    try testing.expect(Cursor.new(2, 3).lessThan(Cursor.new(2, 4)));
    try testing.expect(Cursor.new(2, 4).order(Cursor.new(2, 3)) == .gt);

    // Affinity breaks full ties: before < after.
    const before = Cursor.newWithAffinity(2, 4, .before);
    const after = Cursor.newWithAffinity(2, 4, .after);
    try testing.expect(before.lessThan(after));
    try testing.expect(before.order(after) == .lt);
    try testing.expect(after.order(before) == .gt);
    try testing.expect(!after.lessThan(before));

    // Reflexivity and equality.
    try testing.expect(before.order(before) == .eq);
    try testing.expect(before.eql(Cursor.newWithAffinity(2, 4, .before)));
    try testing.expect(!before.eql(after));
    try testing.expect(!before.eql(Cursor.new(2, 5)));

    // Usable as a sort key.
    var items = [_]Cursor{
        Cursor.new(1, 0),
        Cursor.newWithAffinity(0, 5, .after),
        Cursor.new(0, 5),
        Cursor.newWithAffinity(0, 5, .before),
        Cursor.new(0, 4),
    };
    std.mem.sort(Cursor, &items, {}, cursorLessThan);
    try testing.expect(items[0].eql(Cursor.new(0, 4)));
    try testing.expect(items[1].eql(Cursor.newWithAffinity(0, 5, .before)));
    try testing.expect(items[2].eql(Cursor.new(0, 5)));
    try testing.expect(items[3].eql(Cursor.newWithAffinity(0, 5, .after)));
    try testing.expect(items[4].eql(Cursor.new(1, 0)));
}

test "layout cursor construction and ordering" {
    const testing = std.testing;

    const lc = LayoutCursor.new(1, 2, 3);
    try testing.expectEqual(@as(usize, 1), lc.line);
    try testing.expectEqual(@as(usize, 2), lc.layout);
    try testing.expectEqual(@as(usize, 3), lc.glyph);

    const z: LayoutCursor = .{};
    try testing.expect(z.eql(LayoutCursor.new(0, 0, 0)));

    try testing.expect(LayoutCursor.new(0, 0, 1).lessThan(LayoutCursor.new(0, 0, 2)));
    try testing.expect(LayoutCursor.new(0, 1, 0).lessThan(LayoutCursor.new(0, 2, 0)));
    try testing.expect(LayoutCursor.new(1, 0, 0).lessThan(LayoutCursor.new(2, 0, 0)));
    // Earlier fields dominate later ones.
    try testing.expect(LayoutCursor.new(0, 9, 9).lessThan(LayoutCursor.new(1, 0, 0)));
    try testing.expect(LayoutCursor.new(0, 0, 9).lessThan(LayoutCursor.new(0, 1, 0)));
    try testing.expect(LayoutCursor.new(1, 2, 3).order(LayoutCursor.new(1, 2, 3)) == .eq);
    try testing.expect(!LayoutCursor.new(1, 2, 3).eql(LayoutCursor.new(1, 2, 4)));
}

test "motion variants and payloads" {
    const testing = std.testing;

    // Unit variants compare by tag.
    const left: Motion = .left;
    const right: Motion = .right;
    try testing.expect(left == .left);
    try testing.expect(!left.eql(right));
    try testing.expect((Motion.previous == .previous));
    try testing.expect((Motion.next == .next));
    try testing.expect((Motion.up == .up));
    try testing.expect((Motion.down == .down));
    try testing.expect((Motion.home == .home));
    try testing.expect((Motion.soft_home == .soft_home));
    try testing.expect((Motion.end == .end));
    try testing.expect((Motion.paragraph_start == .paragraph_start));
    try testing.expect((Motion.paragraph_end == .paragraph_end));
    try testing.expect((Motion.page_up == .page_up));
    try testing.expect((Motion.page_down == .page_down));
    try testing.expect((Motion.previous_word == .previous_word));
    try testing.expect((Motion.next_word == .next_word));
    try testing.expect((Motion.left_word == .left_word));
    try testing.expect((Motion.right_word == .right_word));
    try testing.expect((Motion.buffer_start == .buffer_start));
    try testing.expect((Motion.buffer_end == .buffer_end));

    // Payload variants carry their values.
    const v: Motion = .{ .vertical = -12 };
    try testing.expect(v.eql(.{ .vertical = -12 }));
    try testing.expect(!v.eql(.{ .vertical = 12 }));
    try testing.expect(v.vertical == -12);

    const g: Motion = .{ .goto_line = 42 };
    try testing.expect(g.goto_line == 42);
    try testing.expect(!g.eql(.{ .goto_line = 43 }));

    const lc: Motion = .{ .layout_cursor = LayoutCursor.new(4, 5, 6) };
    try testing.expect(lc.layout_cursor.eql(LayoutCursor.new(4, 5, 6)));

    // Same tag, different payload is not equal; different tags never equal.
    try testing.expect(!(Motion{ .vertical = 1 }).eql(Motion.left));
    try testing.expect(std.meta.activeTag(v) == .vertical);
    try testing.expect(std.meta.activeTag(g) == .goto_line);
}

test "scroll construction" {
    const testing = std.testing;

    const s = Scroll.new(7, 1.5, -2.25);
    try testing.expectEqual(@as(usize, 7), s.line);
    try testing.expectEqual(@as(f32, 1.5), s.vertical);
    try testing.expectEqual(@as(f32, -2.25), s.horizontal);

    const z: Scroll = .{};
    try testing.expectEqual(@as(usize, 0), z.line);
    try testing.expectEqual(@as(f32, 0), z.vertical);
    try testing.expectEqual(@as(f32, 0), z.horizontal);

    try testing.expect(!s.eql(z));
    try testing.expect(s.eql(Scroll.new(7, 1.5, -2.25)));
}

test "affinity explicit u8 order" {
    const testing = std.testing;

    // Tag type is explicitly `u8` with `before < after`.
    try testing.expectEqual(@as(u8, 0), @backingInt(Affinity.before));
    try testing.expectEqual(@as(u8, 1), @backingInt(Affinity.after));
    try testing.expect(Affinity.before.order(Affinity.after) == .lt);
    try testing.expect(Affinity.after.order(Affinity.before) == .gt);
    try testing.expect(Affinity.before.order(Affinity.before) == .eq);
}

test "scroll partial order with NaN semantics" {
    const testing = std.testing;

    // Line dominates.
    try testing.expect(Scroll.new(0, 100, 0).order(Scroll.new(1, 0, 0)).? == .lt);
    try testing.expect(Scroll.new(1, 0, 0).order(Scroll.new(0, 100, 0)).? == .gt);
    // Vertical breaks line ties; horizontal breaks vertical ties.
    try testing.expect(Scroll.new(0, 1, 9).order(Scroll.new(0, 2, 0)).? == .lt);
    try testing.expect(Scroll.new(0, 1, 1).order(Scroll.new(0, 1, 2)).? == .lt);
    try testing.expect(Scroll.new(1, 2, 3).order(Scroll.new(1, 2, 3)).? == .eq);
    // NaN is unordered (null), matching Rust `PartialOrd::None`.
    const nan = std.math.nan(f32);
    try testing.expect(Scroll.new(0, nan, 0).order(Scroll.new(0, nan, 0)) == null);
    try testing.expect(Scroll.new(0, 1, nan).order(Scroll.new(0, 1, 1)) == null);
    // NaN never equals, even itself (Rust `PartialEq`).
    try testing.expect(!Scroll.new(0, nan, 0).eql(Scroll.new(0, nan, 0)));
}
