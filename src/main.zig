//! Minimal `cozmic` executable: shape and lay out one line and print the
//! resulting glyph metrics.
//!
//! This replaces the `zig init` template program. It exists to prove the
//! library works from an external crate-like entry point (real font
//! registration, real HarfBuzz shaping, real layout) and to give `zig build run`
//! something meaningful to do.
//!
//! Runtime requirements are the same as the library's: HarfBuzz and FreeType
//! must be loadable at runtime, and a font must be resolvable.

const std = @import("std");
const cozmic = @import("cozmic");

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;

    var out_buffer: [4096]u8 = undefined;
    var out_file: std.Io.File.Writer = .init(.stdout(), io, &out_buffer);
    const out = &out_file.interface;

    var fs = try cozmic.FontSystem.init(arena);
    defer fs.deinit();

    // Use the host's fonts when they are discoverable; otherwise the shape run
    // falls back to whatever `FontSystem` has and the report below shows the
    // resulting glyph count (possibly zero for unsupported characters).
    const stats = fs.loadSystemFonts(io);
    try out.print("fonts: {d} faces, {d} errors\n", .{
        stats.faces_added,
        stats.file_errors,
    });
    if (!fs.hasShaper()) {
        try out.print("no HarfBuzz backend available; nothing to shape\n", .{});
        try out.flush();
        return;
    }

    // Generic family: resolves through the host's configured sans-serif
    // default, so the demo does not depend on a specific family being
    // installed. Named families still work through `FontSystem.setSansFamily`
    // or `attrs.family = .{ .name = ... }`.
    var attrs = cozmic.Attrs.init(arena);
    attrs.family = .sans_serif;
    attrs.color_opt = cozmic.Color.rgb(0, 0, 0);

    var buffer = try cozmic.Buffer.initWithAllocator(arena, cozmic.Metrics.new(16, 20));
    buffer.setSize(400, null);
    try buffer.setText("The quick brown fox jumps over the lazy dog.", &attrs, .advanced, null);
    try buffer.shapeUntilScroll(&fs, false);

    var lines: usize = 0;
    var glyphs: usize = 0;
    var missing: usize = 0;
    var width: f32 = 0;
    var it = buffer.layoutRuns();
    while (it.next()) |run| {
        lines += 1;
        width = run.line_w;
        for (run.glyphs) |g| {
            if (g.glyph_id == 0) {
                missing += 1;
            } else {
                glyphs += 1;
            }
        }
    }

    try out.print(
        "shaped {d} line(s): {d} glyphs, {d} missing, last line width {d:.2}px\n",
        .{ lines, glyphs, missing, width },
    );
    try out.flush();
}
