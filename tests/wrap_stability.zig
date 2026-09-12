//! Port of upstream `tests/wrap_stability.rs` (`stable_wrap`, issue #134):
//! feeding the measured width back into `ShapeLine.layout` as the new width
//! limit must reproduce the exact same wrapping (same max width, same line
//! count and same per-line widths).
//!
//! The full upstream case matrix is ported verbatim: the six literal cases
//! chained with every `BidiParagraphs` paragraph of `tests/sample/hello.txt`,
//! each tried with 0, 4 and 12 trailing spaces, for all four `Wrap` modes,
//! the five upstream alignments and all seven start widths.

const std = @import("std");
const cozmic = @import("cozmic");
const fonts = @import("common/fonts.zig");
const shape = cozmic.shape;

/// Upstream `let font_size = 18.0;`.
const font_size: f32 = 18.0;

/// Candidate sample dirs, tried in order (mirrors `common/fonts.zig`'s font
/// dir candidates) so the suite works from the package root or a parent cwd.
const SAMPLE_DIRS = [_][]const u8{
    "tests/sample",
    "../tests/sample",
    "src/../tests/sample",
};

fn readHelloSample(alloc: std.mem.Allocator) ![]u8 {
    var last_err: anyerror = error.FileNotFound;
    for (SAMPLE_DIRS) |dir| {
        const path = try std.fs.path.join(alloc, &.{ dir, "hello.txt" });
        defer alloc.free(path);
        if (std.Io.Dir.cwd().readFileAlloc(std.testing.io, path, alloc, .limited(1 << 20))) |bytes| {
            return bytes;
        } else |err| {
            last_err = err;
        }
    }
    return last_err;
}

fn maxWidth(lines: []const cozmic.LayoutLine) f32 {
    var w: f32 = 0;
    for (lines) |l| w = @max(w, l.w);
    return w;
}

/// Print the failing case in the upstream assertion format.
fn failCase(
    text: []const u8,
    wrap: cozmic.Wrap,
    align_opt: ?cozmic.Align,
    start_width_opt: ?f32,
    comptime msg: []const u8,
    args: anytype,
) void {
    var width_buf: [32]u8 = undefined;
    const width_str = if (start_width_opt) |sw|
        std.fmt.bufPrint(&width_buf, "{d}", .{sw}) catch "?"
    else
        "unbounded";
    std.debug.print(
        "wrap stability: " ++ msg ++ " (wrap {s}, align {s}, start width {s}) with text: \"{s}\"\n",
        args ++ .{ @tagName(wrap), if (align_opt) |a| @tagName(a) else "default", width_str, text },
    );
}

/// Port of upstream `check_wrap`'s layout half (shaping is hoisted; see the
/// test body): lay out at `start_width_opt`, then re-lay out at
/// `min(start_width_opt, max_width)` and require bit-identical widths and line
/// counts, plus equal widths for every line after the first.
fn checkLayout(
    alloc: std.mem.Allocator,
    line: *const shape.ShapeLine,
    shape_buf: *shape.ShapeBuffer,
    text: []const u8,
    wrap: cozmic.Wrap,
    align_opt: ?cozmic.Align,
    start_width_opt: ?f32,
    checks_run: *usize,
) !void {
    checks_run.* += 1;
    var unbounded: std.ArrayList(cozmic.LayoutLine) = .empty;
    defer {
        for (unbounded.items) |*l| l.deinit();
        unbounded.deinit(alloc);
    }
    var bounded: std.ArrayList(cozmic.LayoutLine) = .empty;
    defer {
        for (bounded.items) |*l| l.deinit();
        bounded.deinit(alloc);
    }

    try line.layoutToBuffer(
        alloc,
        shape_buf,
        font_size,
        start_width_opt,
        wrap,
        .{ .none = {} },
        align_opt,
        &unbounded,
        null,
        .disabled,
    );
    const max_width = maxWidth(unbounded.items);
    const new_limit: f32 = if (start_width_opt) |start_width|
        @min(start_width, max_width)
    else
        max_width;

    try line.layoutToBuffer(
        alloc,
        shape_buf,
        font_size,
        new_limit,
        wrap,
        .{ .none = {} },
        align_opt,
        &bounded,
        null,
        .disabled,
    );
    const bounded_max_width = maxWidth(bounded.items);

    if (max_width != bounded_max_width or unbounded.items.len != bounded.items.len) {
        failCase(
            text,
            wrap,
            align_opt,
            start_width_opt,
            "max width / line count changed: {d} / {d} -> {d} / {d}",
            .{ max_width, unbounded.items.len, bounded_max_width, bounded.items.len },
        );
        return error.WrapUnstable;
    }

    for (unbounded.items[1..], bounded.items[1..]) |u, b| {
        if (u.w != b.w) {
            failCase(
                text,
                wrap,
                align_opt,
                start_width_opt,
                "line width changed: {d} -> {d}",
                .{ u.w, b.w },
            );
            return error.WrapUnstable;
        }
    }
}

test "wrap stability: stable_wrap" {
    const alloc = std.testing.allocator;
    var fs = try fonts.fontSystem(alloc);
    defer fs.deinit();

    var defaults = cozmic.Attrs.init(alloc);
    defer defaults.deinit();
    // Upstream: `Attrs::new().family(Family::Name("FiraMono")).weight(MEDIUM)`.
    // The vendored face's typographic family (name table ID 16) is
    // "Fira Mono"; the port matches family names exactly.
    defaults.family = .{ .name = "Fira Mono" };
    defaults.weight = cozmic.Weight.medium;

    // The adapter borrows `fs`; it stays valid because `fs` is not mutated
    // after this point.
    const adapter = fs.shaper() orelse return error.SkipZigTest;

    var attrs = try cozmic.AttrsList.init(alloc, &defaults);
    defer attrs.deinit();

    const hello_sample = try readHelloSample(alloc);
    defer alloc.free(hello_sample);

    var cases: std.ArrayList([]const u8) = .empty;
    defer cases.deinit(alloc);
    try cases.appendSlice(alloc, &.{
        "(6)  SomewhatBoringDisplayTransform",
        "",
        " ",
        "  ",
        "   ",
        "       ",
    });
    // `.chain(BidiParagraphs::new(&hello_sample))`.
    var paragraphs = cozmic.bidi_para.BidiParagraphs.init(hello_sample);
    while (paragraphs.next()) |paragraph| try cases.append(alloc, paragraph);

    const wraps = [_]cozmic.Wrap{ .none, .glyph, .word, .word_or_glyph };
    // Upstream TODO: `Align::Justified` is intentionally absent.
    const aligns = [_]?cozmic.Align{ null, .left, .right, .center, .end };
    const start_widths = [_]?f32{
        null,
        std.math.floatMax(f32),
        80.0,
        198.2132,
        20.0,
        4.0,
        300.0,
    };

    const variants_per_case = 3; // text, text + 12 spaces, text + 4 spaces.
    const expected_checks =
        cases.items.len * variants_per_case * wraps.len * aligns.len * start_widths.len;
    var checks_run: usize = 0;

    for (cases.items) |text| {
        const with_spaces = try std.fmt.allocPrint(alloc, "{s}            ", .{text});
        defer alloc.free(with_spaces);
        const with_spaces_2 = try std.fmt.allocPrint(alloc, "{s}    ", .{text});
        defer alloc.free(with_spaces_2);

        for ([_][]const u8{ text, with_spaces, with_spaces_2 }) |variant| {
            // Upstream builds a fresh `ShapeLine` inside `check_wrap`; shaping
            // is deterministic and `layoutToBuffer` takes `*const ShapeLine`
            // (it never mutates the shaped spans), so one built line is reused
            // across the wrap/align/width matrix.
            //
            // Layout scratch is created per check: `layoutToBuffer` pools
            // internal scratch in the `ShapeBuffer`, and a fresh pool keeps
            // every wrap/align case independent of the previous one (the
            // pools are leak-clean under `std.testing.allocator`, so a shared
            // buffer would also be correct, just less isolated).
            var line = shape.ShapeLine{};
            defer line.deinit(alloc);
            {
                var build_buf = shape.ShapeBuffer.init();
                defer build_buf.deinit(alloc);
                try line.build(alloc, adapter, &build_buf, variant, &attrs, .advanced, 8, .auto);
            }

            for (wraps) |wrap| {
                for (aligns) |align_opt| {
                    for (start_widths) |start_width_opt| {
                        var shape_buf = shape.ShapeBuffer.init();
                        defer shape_buf.deinit(alloc);
                        try checkLayout(alloc, &line, &shape_buf, variant, wrap, align_opt, start_width_opt, &checks_run);
                    }
                }
            }
        }
    }

    // Guard against silently shrinking the matrix: every upstream
    // (text variant, wrap, align, start width) combination must run.
    try std.testing.expectEqual(expected_checks, checks_run);
}

test "wrap stability: extra line" {
    const alloc = std.testing.allocator;
    var fs = try fonts.fontSystem(alloc);
    defer fs.deinit();
    var attrs = fonts.attrsWithFamily(alloc, "Inter");
    defer attrs.deinit();

    var buffer = try cozmic.Buffer.initWithAllocator(alloc, cozmic.Metrics.new(14, 20));
    defer buffer.deinit();
    var borrowed = buffer.borrowWith(&fs);
    borrowed.setWrap(.word);
    borrowed.setSize(50, 1000);
    try borrowed.setText(
        "Lorem ipsum dolor sit amet, qui minim labore adipisicing\n\nweeewoooo minim sint cillum sint consectetur cupidatat.",
        &attrs,
        .advanced,
        null,
    );

    var empty_lines: usize = 0;
    var overflow_lines: usize = 0;
    var it = try borrowed.layoutRuns();
    while (it.next()) |run| {
        if (run.line_w == 0) empty_lines += 1;
        if (run.line_w > 50) overflow_lines += 1;
    }
    try std.testing.expectEqual(@as(usize, 1), empty_lines);
    try std.testing.expectEqual(@as(usize, 4), overflow_lines);
}
