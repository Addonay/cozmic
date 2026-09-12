//! Port of upstream `tests/variable_font_weight.rs`: a variable font must be
//! matched at every weight inside its `wght` axis range, not just the nominal
//! registered weight.

const std = @import("std");
const cozmic = @import("cozmic");
const fonts = @import("common/fonts.zig");

fn readFixture(alloc: std.mem.Allocator, name: []const u8) ![]u8 {
    var last_err: anyerror = error.FileNotFound;
    for (fonts.FONT_DIRS) |dir| {
        const path = try std.fs.path.join(alloc, &.{ dir, name });
        defer alloc.free(path);
        if (std.Io.Dir.cwd().readFileAlloc(std.testing.io, path, alloc, .limited(1 << 26))) |bytes| {
            return bytes;
        } else |err| {
            last_err = err;
        }
    }
    return last_err;
}

test "variable font: all weights match Inter Variable" {
    const alloc = std.testing.allocator;

    // Only InterVariable is registered, so every weight must resolve to it.
    var fs = try cozmic.FontSystem.init(alloc);
    defer fs.deinit();

    const bytes = try readFixture(alloc, "InterVariable.ttf");
    defer alloc.free(bytes);
    const id = try fs.dbMut().addFaceFromBytes(bytes, 0, "InterVariable.ttf");
    try fs.addFontData(id, bytes, 0, false, null);
    try std.testing.expect(fs.hasShaper());

    // The fvar `wght` range must be populated for variable matching.
    const face = fs.db.face(id) orelse return error.TestUnexpectedResult;
    try std.testing.expect(face.variable_wght_min != null);
    try std.testing.expect(face.variable_wght_max != null);

    for ([_]u16{ 100, 200, 300, 400, 500, 600, 700, 800, 900 }) |w| {
        var buffer = try cozmic.Buffer.initWithAllocator(alloc, cozmic.Metrics.new(16, 20));
        defer buffer.deinit();
        var borrowed = buffer.borrowWith(&fs);
        var attrs = fonts.attrsWithFamily(alloc, "Inter Variable");
        defer attrs.deinit();
        attrs.weight = .{ .value = w };
        borrowed.setSize(300, 100);
        try borrowed.setText("Hello world", &attrs, .advanced, null);
        try borrowed.shapeUntilScroll(true);

        var glyphs: usize = 0;
        var it = try borrowed.layoutRuns();
        while (it.next()) |run| {
            for (run.glyphs) |g| {
                if (g.glyph_id == 0) continue;
                glyphs += 1;
                const gface = fs.db.face(g.font_id) orelse return error.TestUnexpectedResult;
                try std.testing.expect(gface.id == id);
            }
        }
        try std.testing.expect(glyphs > 0);
    }
}
