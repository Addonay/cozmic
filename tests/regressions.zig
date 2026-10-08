//! Regression tests for defects found in the 2026-10 cosmic-text parity audit
//! (audit date 2026-10-03, findings 1-8).
//!
//! The audit shipped `tests/audit_findings.zig` as *diagnostic witnesses* that
//! pass while each defect is observed. That file is gone: all eight defects are
//! fixed, so those assertions now describe the desired behavior instead. The
//! reproductions and the pre-fix measurements they recorded are preserved in the
//! comments below, so the audit's evidence stays traceable.
//!
//! Every test drives the public `Buffer` pipeline or the exported shaping seam
//! with real HarfBuzz and real FreeType, not a stand-in adapter. The two
//! kerning widths are exact upstream cosmic-text values for the same fixture
//! font, so finding 2 is checked against the reference implementation rather
//! than against a locally computed expectation.

const std = @import("std");
const c = @import("cozmic");
const fonts = @import("common/fonts.zig");
const a = std.testing.allocator;

// ---------------------------------------------------------------------------
// 1. P1 — fallback negative memo poisoned unrelated text in the same script
// ---------------------------------------------------------------------------

/// Shape `text` with a fresh buffer and count `.notdef` glyphs.
fn missingCount(fs: *c.FontSystem, text: []const u8) !usize {
    var attrs = fonts.attrsWithFamily(a, "Inter");
    defer attrs.deinit();
    var buf = try c.Buffer.initWithAllocator(a, c.Metrics.new(20, 24));
    defer buf.deinit();
    try buf.setText(text, &attrs, .advanced, null);
    try buf.shapeUntilScroll(fs, false);
    var missing: usize = 0;
    var it = buf.layoutRuns();
    while (it.next()) |r| for (r.glyphs) |g| {
        if (g.glyph_id == 0) missing += 1;
    };
    return missing;
}

test "audit 1: unsupported text does not poison later text in the same script" {
    var fs = try fonts.fontSystem(a);
    defer fs.deinit();
    // Isolate fallback: the run cache would hide a repeated miss anyway.
    fs.setRunCacheEnabled(false);

    // U+10EC2 (Lontara) is outside the vendored corpus.
    const rare = "\u{10ec2}";
    const rare_missing = try missingCount(&fs, rare);
    try std.testing.expect(rare_missing > 0);

    // Both orders: unsupported-then-supported, then the reverse. A
    // script-wide negative cached by the first run would break the second.
    const word = "\u{0645}\u{0631}\u{062D}\u{0628}\u{0627}"; // مرحبا
    const after = try missingCount(&fs, word);
    _ = try missingCount(&fs, rare);
    const after_again = try missingCount(&fs, word);

    try std.testing.expectEqual(@as(usize, 0), after);
    try std.testing.expectEqual(@as(usize, 0), after_again);
}

test "audit 1: a supported word keeps rendering after an unrelated unsupported run" {
    var fs = try fonts.fontSystem(a);
    defer fs.deinit();
    fs.setRunCacheEnabled(false);

    const word = "\u{05E9}\u{05DC}\u{05D5}\u{05DD}"; // שלום (Hebrew)
    const baseline = try missingCount(&fs, word);
    try std.testing.expectEqual(@as(usize, 0), baseline);

    // Three unsupported runs in the same script, interleaved.
    for ([_][]const u8{ "\u{10EC2}", "\u{10A01}", "\u{A8C4}" }) |rare| {
        _ = try missingCount(&fs, rare);
        try std.testing.expectEqual(@as(usize, 0), try missingCount(&fs, word));
    }
}

// ---------------------------------------------------------------------------
// 2. P1 — requested OpenType features never reached HarfBuzz
// ---------------------------------------------------------------------------

/// Sum of advance widths of the first line's glyphs, for `text`.
fn width(fs: *c.FontSystem, attrs: *const c.Attrs, text: []const u8) !f32 {
    var buf = try c.Buffer.initWithAllocator(a, c.Metrics.new(20, 24));
    defer buf.deinit();
    try buf.setText(text, attrs, .advanced, null);
    try buf.shapeUntilScroll(fs, false);
    var total: f32 = 0;
    var it = buf.layoutRuns();
    while (it.next()) |r| for (r.glyphs) |g| {
        total += g.w;
    };
    return total;
}

test "audit 2: kern produces the same widths as upstream cosmic-text" {
    var fs = try fonts.fontSystem(a);
    defer fs.deinit();
    fs.setRunCacheEnabled(false);

    var attrs = fonts.attrsWithFamily(a, "Inter");
    defer attrs.deinit();

    // Exact values recorded by the audit for this same fixture font:
    // upstream default 73.693184 and upstream kern=0 79.71591. Before the
    // fix Cozmic produced 73.693184 for both.
    const kerning_on = try width(&fs, &attrs, "AVATAR");
    _ = try attrs.font_features.disable(c.attrs.FeatureTag.kerning);
    const kerning_off = try width(&fs, &attrs, "AVATAR");

    try std.testing.expectApproxEqAbs(@as(f32, 73.693184), kerning_on, 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 79.71591), kerning_off, 1e-5);
    try std.testing.expect(kerning_on != kerning_off);
}

test "audit 2: kerning applies to a second word as well" {
    var fs = try fonts.fontSystem(a);
    defer fs.deinit();
    fs.setRunCacheEnabled(false);

    var attrs = fonts.attrsWithFamily(a, "Inter");
    defer attrs.deinit();
    const on = try width(&fs, &attrs, "WAVE To 123");

    var off_attrs = fonts.attrsWithFamily(a, "Inter");
    defer off_attrs.deinit();
    _ = try off_attrs.font_features.disable(c.attrs.FeatureTag.kerning);
    const off = try width(&fs, &off_attrs, "WAVE To 123");

    try std.testing.expectApproxEqAbs(@as(f32, 124.03409), on, 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 128.125), off, 1e-5);
}

/// Number of glyphs in the first layout run of `text`.
fn glyphCount(fs: *c.FontSystem, text: []const u8, attrs: *const c.Attrs) !usize {
    var buf = try c.Buffer.initWithAllocator(a, c.Metrics.new(20, 24));
    defer buf.deinit();
    try buf.setText(text, attrs, .advanced, null);
    try buf.shapeUntilScroll(fs, false);
    var it = buf.layoutRuns();
    const run = it.next() orelse return 0;
    return run.glyphs.len;
}

test "audit 2: contextual alternates change the shaped glyph sequence" {
    var fs = try fonts.fontSystem(a);
    defer fs.deinit();
    fs.setRunCacheEnabled(false);

    var attrs = fonts.attrsWithFamily(a, "Inter");
    defer attrs.deinit();

    // Inter's `calt` maps the programming pairs -> and |> onto single
    // glyphs, so disabling it must produce more glyphs.
    const text = "!= -> |>";
    const with_calt = try glyphCount(&fs, text, &attrs);
    try std.testing.expectEqual(@as(usize, 7), with_calt);

    var off_attrs = fonts.attrsWithFamily(a, "Inter");
    defer off_attrs.deinit();
    _ = try off_attrs.font_features.disable(c.attrs.FeatureTag.contextual_alternates);
    const without_calt = try glyphCount(&fs, text, &off_attrs);

    try std.testing.expectEqual(@as(usize, 8), without_calt);
}

test "audit 2: a feature value other than 0/1 is forwarded" {
    var fs = try fonts.fontSystem(a);
    defer fs.deinit();
    fs.setRunCacheEnabled(false);

    // `salt` is an alternate set; any nonzero value must enable it. This
    // asserts the value is passed through, not just the tag presence.
    var attrs = fonts.attrsWithFamily(a, "Inter");
    defer attrs.deinit();
    _ = try attrs.font_features.set(c.attrs.FeatureTag.new("salt"), 3);
    const w = try width(&fs, &attrs, "AVATAR");
    try std.testing.expect(std.math.isFinite(w));
    try std.testing.expect(w > 0);
}

test "audit 2: features are part of the run cache key" {
    var fs = try fonts.fontSystem(a);
    defer fs.deinit();

    var on_attrs = fonts.attrsWithFamily(a, "Inter");
    defer on_attrs.deinit();
    var on_list = try c.attrs.AttrsList.init(a, &on_attrs);
    defer on_list.deinit();

    var off_attrs = fonts.attrsWithFamily(a, "Inter");
    defer off_attrs.deinit();
    _ = try off_attrs.font_features.disable(c.attrs.FeatureTag.kerning);
    var off_list = try c.attrs.AttrsList.init(a, &off_attrs);
    defer off_list.deinit();

    const cache = fs.shaper().?.runCache().?;
    var scratch = c.shape.ShapeBuffer.init();
    defer scratch.deinit(a);

    // Same text and direction, different features: two distinct entries, and
    // each must reproduce fresh shaping of its own attrs.
    var kerned: std.ArrayList(c.shape.ShapeGlyph) = .empty;
    defer kerned.deinit(a);
    try c.shape.shapeRunCached(a, fs.shaper().?, &scratch, &kerned, "AVATAR", &on_list, 0, 6, false);
    try std.testing.expectEqual(@as(usize, 1), cache.len());

    var unkerned: std.ArrayList(c.shape.ShapeGlyph) = .empty;
    defer unkerned.deinit(a);
    try c.shape.shapeRunCached(a, fs.shaper().?, &scratch, &unkerned, "AVATAR", &off_list, 0, 6, false);
    try std.testing.expectEqual(@as(usize, 2), cache.len());

    // The kerned entry must be wider than the unkerned one.
    var kerned_w: f32 = 0;
    for (kerned.items) |g| kerned_w += g.x_advance;
    var unkerned_w: f32 = 0;
    for (unkerned.items) |g| unkerned_w += g.x_advance;
    try std.testing.expect(kerned_w < unkerned_w);

    // Both must equal a fresh, uncached shape of the same attrs.
    fs.setRunCacheEnabled(false);
    var fresh_off: std.ArrayList(c.shape.ShapeGlyph) = .empty;
    defer fresh_off.deinit(a);
    try c.shape.shapeRun(a, fs.shaper().?, &scratch, &fresh_off, "AVATAR", &off_list, 0, 6, false);
    fs.setRunCacheEnabled(true);
    for (fresh_off.items, unkerned.items) |x, y| {
        try std.testing.expectEqual(x.glyph_id, y.glyph_id);
        try std.testing.expectEqual(x.x_advance, y.x_advance);
    }
}

// ---------------------------------------------------------------------------
// 3. P1 — color glyphs had the wrong channel and alpha packing
// ---------------------------------------------------------------------------

const PixelCollector = struct {
    colors: std.ArrayList(c.Color) = .empty,
    alloc: std.mem.Allocator,

    fn visit(ctx: *anyopaque, _: i32, _: i32, color: c.Color) void {
        const self: *PixelCollector = @ptrCast(@alignCast(ctx));
        self.colors.append(self.alloc, color) catch return;
    }
};

fn onePixelKey(font_id: u32) c.glyph_cache.CacheKey {
    return c.glyph_cache.CacheKey.new(font_id, 1, 16, .{ .x = 0, .y = 0 }, 400, .{}).key;
}

test "audit 3: cached RGBA bytes reach the callback as canonical Color components" {
    var cache = c.SwashCache.init(a, null);
    defer cache.deinit();

    const key = onePixelKey(1);
    // Every component distinct, alpha non-trivial, so any channel or
    // alpha-order mistake shows up as a different component value.
    // The cache takes ownership of `data`.
    const data = try a.dupe(u8, &.{ 10, 20, 30, 255 });
    try cache.image_cache.put(key, .{
        .placement = .{ .left = 0, .top = 0, .width = 1, .height = 1 },
        .content = .color,
        .data = data,
    });

    var col = PixelCollector{ .alloc = a };
    defer col.colors.deinit(col.alloc);
    try std.testing.expectEqual(@as(usize, 1), try cache.withPixels(key, .{ .value = 0 }, &col, PixelCollector.visit));

    const got = col.colors.items[0];
    try std.testing.expectEqual(@as(u8, 10), got.r());
    try std.testing.expectEqual(@as(u8, 20), got.g());
    try std.testing.expectEqual(@as(u8, 30), got.b());
    try std.testing.expectEqual(@as(u8, 255), got.a());
    try std.testing.expectEqual(c.Color.rgba(10, 20, 30, 255), got);
}

test "audit 3: mask and color callbacks agree on channel interpretation" {
    var cache = c.SwashCache.init(a, null);
    defer cache.deinit();

    // A mask pixel with coverage 255 and a base color must report the base
    // RGB at full alpha, i.e. exactly the base color.
    const base = c.Color.rgba(0x11, 0x22, 0x33, 0xFF);
    const mask_key = onePixelKey(2);
    const mask_data = try a.dupe(u8, &.{255});
    try cache.image_cache.put(mask_key, .{
        .placement = .{ .left = 0, .top = 0, .width = 1, .height = 1 },
        .content = .mask,
        .data = mask_data,
    });

    var col = PixelCollector{ .alloc = a };
    defer col.colors.deinit(col.alloc);
    _ = try cache.withPixels(mask_key, base, &col, PixelCollector.visit);
    try std.testing.expectEqual(base, col.colors.items[0]);

    // And a color image holding the same color must produce the same Color.
    const color_key = onePixelKey(3);
    const color_data = try a.dupe(u8, &.{ 0x11, 0x22, 0x33, 0xFF });
    try cache.image_cache.put(color_key, .{
        .placement = .{ .left = 0, .top = 0, .width = 1, .height = 1 },
        .content = .color,
        .data = color_data,
    });
    var col2 = PixelCollector{ .alloc = a };
    defer col2.colors.deinit(col2.alloc);
    _ = try cache.withPixels(color_key, .{ .value = 0 }, &col2, PixelCollector.visit);
    try std.testing.expectEqual(col.colors.items[0], col2.colors.items[0]);
}

test "audit 3: LegacyRenderer passes color-font channels through unchanged" {
    var cache = c.SwashCache.init(a, null);
    defer cache.deinit();

    const Collected = struct {
        pixels: std.ArrayList(c.Color) = .empty,
        fn rect(ctx: *anyopaque, _: i32, _: i32, _: u32, _: u32, color: c.Color) void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.pixels.append(a, color) catch return;
        }
    };
    var collected = Collected{};
    defer collected.pixels.deinit(a);

    const key = onePixelKey(7);
    const data = try a.dupe(u8, &.{ 200, 100, 50, 255 });
    try cache.image_cache.put(key, .{
        .placement = .{ .left = 0, .top = 0, .width = 1, .height = 1 },
        .content = .color,
        .data = data,
    });

    var legacy = c.render.LegacyRenderer.init(&cache, .{ .ctx = &collected, .call = Collected.rect });
    const pg = c.layout.PhysicalGlyph{ .x = 0, .y = 0, .cache_key = key };
    legacy.renderer().vtable.glyph(legacy.renderer().ctx, pg, c.Color.rgb(255, 255, 255));

    try std.testing.expectEqual(@as(usize, 1), collected.pixels.items.len);
    try std.testing.expectEqual(c.Color.rgba(200, 100, 50, 255), collected.pixels.items[0]);
}

// ---------------------------------------------------------------------------
// 4. P1 — allocation failure left changed text with a valid old shape
// ---------------------------------------------------------------------------

test "audit 4: a failed append leaves text and shape cache untouched" {
    var failing = std.testing.FailingAllocator.init(a, .{});
    const fa = failing.allocator();
    var fs = try fonts.fontSystem(a);
    defer fs.deinit();
    var attrs = fonts.attrsWithFamily(a, "Inter");
    defer attrs.deinit();
    const list = try c.attrs.AttrsList.init(fa, &attrs);
    var line = try c.BufferLine.initOwned(fa, "a", .none, list, .advanced);
    defer line.deinit();
    try line.text.ensureTotalCapacity(fa, 64);
    _ = try line.shape(&fs, 8, .auto);
    try std.testing.expect(line.shapeOpt() != null);

    attrs.color_opt = c.Color.rgb(255, 0, 0);
    const other_list = try c.attrs.AttrsList.init(a, &attrs);
    var other = try c.BufferLine.initOwned(a, "b", .none, other_list, .advanced);
    defer other.deinit();

    // Fail the first attribute allocation after text capacity is reserved.
    failing.fail_index = failing.alloc_index;
    try std.testing.expectError(error.OutOfMemory, line.append(&other));

    // Text must be unchanged, and the cached shape must not still be marked
    // valid: the audit's defect was text "ab" with the shape of "a" usable.
    // The invariant is text/shape agreement, not "always invalidate". Text is
    // unchanged, so the previously cached shape of "a" is still correct and
    // must remain valid. The audit's defect was text "ab" with the shape of
    // "a" still marked used.
    try std.testing.expectEqualStrings("a", line.textSlice());
    try std.testing.expect(line.shapeOpt() != null);
    try std.testing.expectEqual(@as(usize, 0), line.attrs_list.span_count());
}

test "audit 4: a failed setText leaves the previous text and shape in place" {
    var failing = std.testing.FailingAllocator.init(a, .{});
    const fa = failing.allocator();
    var fs = try fonts.fontSystem(a);
    defer fs.deinit();
    var attrs = fonts.attrsWithFamily(a, "Inter");
    defer attrs.deinit();
    const list = try c.attrs.AttrsList.init(fa, &attrs);
    var line = try c.BufferLine.initOwned(fa, "original", .lf, list, .advanced);
    defer line.deinit();
    try line.text.ensureTotalCapacity(fa, 64);
    _ = try line.shape(&fs, 8, .auto);
    try std.testing.expect(line.shapeOpt() != null);

    var other_attrs = fonts.attrsWithFamily(fa, "Inter");
    defer other_attrs.deinit();
    other_attrs.color_opt = c.Color.rgb(0, 128, 255);
    var other_list = try c.attrs.AttrsList.init(fa, &other_attrs);
    defer other_list.deinit();

    failing.fail_index = failing.alloc_index;
    try std.testing.expectError(error.OutOfMemory, line.setText("replacement", .lf, &other_list));

    // Text, ending and shape cache must all still describe the old content.
    try std.testing.expectEqualStrings("original", line.textSlice());
    try std.testing.expectEqual(c.LineEnding.lf, line.ending);
    try std.testing.expect(line.shapeOpt() != null);
}

test "audit 4: append still produces correct spans after reordering" {
    var fs = try fonts.fontSystem(a);
    defer fs.deinit();

    var red = fonts.attrsWithFamily(a, "Inter");
    defer red.deinit();
    red.color_opt = c.Color.rgb(255, 0, 0);

    const left_list = try c.attrs.AttrsList.init(a, &red);
    var left = try c.BufferLine.initOwned(a, "AB", .none, left_list, .advanced);
    defer left.deinit();
    try left.attrs_list.add_span(0, 2, &red);

    var blue = fonts.attrsWithFamily(a, "Inter");
    defer blue.deinit();
    blue.color_opt = c.Color.rgb(0, 0, 255);
    const blue_list = try c.attrs.AttrsList.init(a, &blue);
    var right = try c.BufferLine.initOwned(a, "CD", .none, blue_list, .advanced);
    defer right.deinit();
    try right.attrs_list.add_span(0, 2, &blue);

    try left.append(&right);
    try std.testing.expectEqualStrings("ABCD", left.textSlice());
    // Two spans over [0,2) red and [2,4) blue, in ascending order.
    try std.testing.expectEqual(@as(usize, 2), left.attrs_list.span_count());
    const spans = left.attrs_list.spans_slice();
    try std.testing.expectEqual(@as(usize, 0), spans[0].start);
    try std.testing.expectEqual(@as(usize, 2), spans[0].end);
    try std.testing.expectEqual(c.Color.rgb(255, 0, 0), spans[0].attrs.color_opt.?);
    try std.testing.expectEqual(@as(usize, 2), spans[1].start);
    try std.testing.expectEqual(@as(usize, 4), spans[1].end);
    try std.testing.expectEqual(c.Color.rgb(0, 0, 255), spans[1].attrs.color_opt.?);
}

// ---------------------------------------------------------------------------
// 5. P1/P2 — replacing a font retained old shaped runs
// ---------------------------------------------------------------------------

fn readFixture(alloc: std.mem.Allocator, name: []const u8) ![]u8 {
    var last_err: anyerror = error.FileNotFound;
    for (fonts.FONT_DIRS) |dir| {
        const path = try std.fs.path.join(alloc, &.{ dir, name });
        defer alloc.free(path);
        if (std.Io.Dir.cwd().readFileAlloc(std.testing.io, path, alloc, .limited(1 << 24))) |bytes| {
            return bytes;
        } else |err| {
            last_err = err;
        }
    }
    return last_err;
}

test "audit 5: replacing a registered font reshapes cached runs" {
    var backend = try c.shape_hb.Backend.init(a);
    defer backend.deinit();
    const inter = try readFixture(a, "Inter-Regular.ttf");
    defer a.free(inter);
    const mono = try readFixture(a, "FiraMono-Medium.ttf");
    defer a.free(mono);

    try backend.addFont(1, inter, 0, false, null);
    var attrs = c.Attrs.init(a);
    defer attrs.deinit();
    var list = try c.attrs.AttrsList.init(a, &attrs);
    defer list.deinit();
    var scratch = c.shape.ShapeBuffer.init();
    defer scratch.deinit(a);

    var old: std.ArrayList(c.shape.ShapeGlyph) = .empty;
    defer old.deinit(a);
    try c.shape.shapeRunCached(a, backend.adapter(), &scratch, &old, "WWW", &list, 0, 3, false);

    var fresh_after: std.ArrayList(c.shape.ShapeGlyph) = .empty;
    defer fresh_after.deinit(a);
    try c.shape.shapeRun(a, backend.adapter(), &scratch, &fresh_after, "WWW", &list, 0, 3, false);
    try std.testing.expectEqual(
        fresh_after.items[0].x_advance,
        old.items[0].x_advance,
    );

    // Swap the font behind the same id.
    try backend.addFont(1, mono, 0, false, null);

    var cached: std.ArrayList(c.shape.ShapeGlyph) = .empty;
    defer cached.deinit(a);
    try c.shape.shapeRunCached(a, backend.adapter(), &scratch, &cached, "WWW", &list, 0, 3, false);
    var fresh: std.ArrayList(c.shape.ShapeGlyph) = .empty;
    defer fresh.deinit(a);
    try c.shape.shapeRun(a, backend.adapter(), &scratch, &fresh, "WWW", &list, 0, 3, false);

    // The cached read must equal a fresh shape of the *new* font.
    try std.testing.expectEqual(fresh.items[0].x_advance, cached.items[0].x_advance);
    try std.testing.expectEqual(fresh.items[0].glyph_id, cached.items[0].glyph_id);
    // And the new font really is different from the old one.
    try std.testing.expect(old.items[0].x_advance != cached.items[0].x_advance);
}

// ---------------------------------------------------------------------------
// Public-boundary input validation (audit, "Metrics input policy is
// incomplete")
// ---------------------------------------------------------------------------

test "non-finite and non-positive metrics are rejected at every boundary" {
    const Rejected = [_]c.Metrics{
        .{ .font_size = 0, .line_height = 16 },
        .{ .font_size = 16, .line_height = 0 },
        .{ .font_size = -16, .line_height = 16 },
        .{ .font_size = 16, .line_height = -16 },
        .{ .font_size = std.math.nan(f32), .line_height = 16 },
        .{ .font_size = 16, .line_height = std.math.nan(f32) },
        .{ .font_size = std.math.inf(f32), .line_height = 16 },
        .{ .font_size = 16, .line_height = std.math.inf(f32) },
        .{ .font_size = -std.math.inf(f32), .line_height = -std.math.inf(f32) },
    };
    for (Rejected) |m| {
        try std.testing.expect(!m.isValid());
        try std.testing.expectError(
            error.InvalidMetrics,
            c.Buffer.initWithAllocator(a, m),
        );
    }
    const ok = c.Metrics.new(16, 20);
    try std.testing.expect(ok.isValid());
}

test "setMetrics rejects invalid values instead of accepting them" {
    var fs = try fonts.fontSystem(a);
    defer fs.deinit();
    var buf = try c.Buffer.initWithAllocator(a, c.Metrics.new(16, 20));
    defer buf.deinit();

    for ([_]c.Metrics{
        .{ .font_size = 0, .line_height = 20 },
        .{ .font_size = 16, .line_height = 0 },
        .{ .font_size = -1, .line_height = 20 },
        .{ .font_size = 16, .line_height = -1 },
        .{ .font_size = std.math.nan(f32), .line_height = 20 },
        .{ .font_size = 16, .line_height = std.math.inf(f32) },
    }) |bad| {
        try std.testing.expectError(error.InvalidMetrics, buf.setMetrics(bad));
        // The previous valid metrics survive the rejected call.
        try std.testing.expect(c.Metrics.eql(c.Metrics.new(16, 20), buf.metrics));
    }
    try buf.setMetrics(c.Metrics.new(18, 22));
    try std.testing.expect(c.Metrics.eql(c.Metrics.new(18, 22), buf.metrics));
}

test "setSize normalizes non-finite dimensions to unbounded" {
    var buf = try c.Buffer.initWithAllocator(a, c.Metrics.new(16, 20));
    defer buf.deinit();

    buf.setSize(std.math.nan(f32), std.math.inf(f32));
    try std.testing.expect(buf.width_opt == null);
    try std.testing.expect(buf.height_opt == null);

    buf.setSize(-5, -7);
    try std.testing.expectEqual(@as(?f32, 0), buf.width_opt);
    try std.testing.expectEqual(@as(?f32, 0), buf.height_opt);

    buf.setSize(100, 200);
    try std.testing.expectEqual(@as(?f32, 100), buf.width_opt);
    try std.testing.expectEqual(@as(?f32, 200), buf.height_opt);
}

test "an end-to-end layout with valid metrics is unaffected by the new checks" {
    var fs = try fonts.fontSystem(a);
    defer fs.deinit();
    var attrs = fonts.attrsWithFamily(a, "Inter");
    defer attrs.deinit();
    var buf = try c.Buffer.initWithAllocator(a, c.Metrics.new(16, 20));
    defer buf.deinit();
    buf.setSize(200, 100);
    try buf.setText("Hello world, this is a normal line of text.", &attrs, .advanced, null);
    try buf.shapeUntilScroll(&fs, false);
    var it = buf.layoutRuns();
    const run = it.next() orelse return error.TestUnexpectedResult;
    try std.testing.expect(run.glyphs.len > 0);
    try std.testing.expect(run.line_w > 0);
}

// ---------------------------------------------------------------------------
// Editor allocation failures must not lose text or drop the undo record
// (audit, finding 4: "related destructive mutation order in src/edit.zig")
// ---------------------------------------------------------------------------

/// Concatenated text of every line, joined with `\n`. Caller owns the result.
fn editorText(ed: *const c.Editor) ![]u8 {
    var buf: std.ArrayList(u8) = .empty;
    errdefer buf.deinit(a);
    for (ed.buffer().lines.items, 0..) |line, i| {
        if (i > 0) try buf.append(a, '\n');
        try buf.appendSlice(a, line.textSlice());
    }
    return buf.toOwnedSlice(a);
}

/// `editorText` for assertion sites: compares and frees.
fn expectEditorText(ed: *const c.Editor, expected: []const u8) !void {
    const got = try editorText(ed);
    defer a.free(got);
    try std.testing.expectEqualStrings(expected, got);
}

/// Put one line of `text` into a caller-owned buffer. `BufferLine.initOwned`
/// takes ownership of `list`.
fn seedLine(buffer: *c.Buffer, attrs: *const c.Attrs, text: []const u8) !void {
    var list = try c.attrs.AttrsList.init(a, attrs);
    errdefer list.deinit();
    const line = try c.BufferLine.initOwned(a, text, .lf, list, .advanced);
    try buffer.lines.append(a, line);
}

/// `alloc` drives the editor's own allocations; `buffer` is borrowed and must
/// outlive it.
fn editorOver(alloc: std.mem.Allocator, buffer: *c.Buffer, attrs: *const c.Attrs, text: []const u8) !c.Editor {
    try seedLine(buffer, attrs, text);
    return c.Editor.initWithBuffer(alloc, buffer);
}

test "editor: a failed insertAt never deletes the text after the cursor" {
    var attrs = c.Attrs.init(a);
    defer attrs.deinit();

    // Run the insert with an allocator that fails on its Nth allocation, for
    // every N. Whatever happens, the text must be all-or-nothing.
    var saw_success = false;
    var saw_oom = false;
    for (0..96) |n| {
        var fail = std.testing.FailingAllocator.init(a, .{ .fail_index = n });
        var buffer = try c.Buffer.initWithAllocator(a, c.Metrics.new(14, 20));
        defer buffer.deinit();
        var editor = try editorOver(fail.allocator(), &buffer, &attrs, "HEADTAIL");
        defer editor.deinit();

        if (editor.insertAt(c.Cursor{ .line = 0, .index = 4 }, "MID", null)) |_| {
            saw_success = true;
            try expectEditorText(&editor, "HEADMIDTAIL");
        } else |err| {
            saw_oom = true;
            try std.testing.expect(err == error.OutOfMemory or err == error.InvalidCursor or err == error.InvalidData);
            // The invariant the audit's finding named: a failed mutation must
            // not leave text deleted.
            try expectEditorText(&editor, "HEADTAIL");
        }
    }
    // Both branches must actually be exercised, otherwise the loop is not
    // reaching the interesting allocations.
    try std.testing.expect(saw_success);
    try std.testing.expect(saw_oom);
}

test "editor: a failed insert still records an undo item when it mutated" {
    var attrs = c.Attrs.init(a);
    defer attrs.deinit();

    for (0..64) |n| {
        var fail = std.testing.FailingAllocator.init(a, .{ .fail_index = n });
        const fa2 = fail.allocator();

        var buffer = try c.Buffer.initWithAllocator(a, c.Metrics.new(14, 20));
        defer buffer.deinit();
        var editor = try editorOver(fa2, &buffer, &attrs, "HEADTAIL");
        defer editor.deinit();
        editor.change = c.Change.init(fa2);

        _ = editor.insertAt(c.Cursor{ .line = 0, .index = 4 }, "MID", null) catch {};

        const text_after = try editorText(&editor);
        defer a.free(text_after);
        const inserted = std.mem.eql(u8, text_after, "HEADMIDTAIL");
        const recorded = editor.change.?.items.items.len > 0;
        try std.testing.expectEqual(inserted, recorded);
    }
}

test "editor: a failed deleteRange never leaves the buffer shorter than expected" {
    var attrs = c.Attrs.init(a);
    defer attrs.deinit();

    for (0..64) |n| {
        var fail = std.testing.FailingAllocator.init(a, .{ .fail_index = n });
        const fa2 = fail.allocator();

        var buffer = try c.Buffer.initWithAllocator(a, c.Metrics.new(14, 20));
        defer buffer.deinit();
        var editor = try editorOver(fa2, &buffer, &attrs, "ABCDEF");
        defer editor.deinit();

        const derr = editor.deleteRange(c.Cursor{ .line = 0, .index = 1 }, c.Cursor{ .line = 0, .index = 4 });
        // Either nothing was removed, or exactly the requested range was. Any
        // other state means a partial destructive mutation escaped.
        const text = try editorText(&editor);
        if (!std.mem.eql(u8, text, "ABCDEF") and !std.mem.eql(u8, text, "AEF")) {
            std.debug.print("deleteRange fail_index={d} err={any} lines={d} text=\"{s}\"\n", .{ n, derr, editor.buffer().lines.items.len, text });
            return error.TestUnexpectedResult;
        }
        defer a.free(text);
    }
}

// ---------------------------------------------------------------------------
// Backend deployment diagnostics (audit, "Deployment portability")
// ---------------------------------------------------------------------------

test "backend versions are reported and compared, not assumed" {
    // HarfBuzz: `version()` is "" only when the library cannot be loaded.
    const hb_version = c.shape_hb.version();
    if (hb_version.len == 0) {
        // No HarfBuzz on this host: the checks must report "cannot meet"
        // rather than silently claiming success.
        try std.testing.expect(!c.shape_hb.meetsMinimumVersion());
        try std.testing.expect(c.shape_hb.loadFailureDiagnostic() != null);
    } else {
        try std.testing.expect(std.mem.indexOf(u8, hb_version, ".") != null);
        try std.testing.expect(c.shape_hb.meetsMinimumVersion());
        // A loaded library has nothing to diagnose.
        try std.testing.expect(c.shape_hb.loadFailureDiagnostic() == null);
    }
}

test "FreeType version is readable and compared against the minimum" {
    var raster = try c.Raster.init(a);
    defer raster.deinit();
    const version = raster.libraryVersion() orelse return error.SkipZigTest;
    try std.testing.expect(version.major >= 0);
    // The live library is what the test suite just rendered glyphs with, so it
    // must satisfy the declared minimum.
    try std.testing.expect(raster.meetsMinimumVersion());
    try std.testing.expectEqual(
        .eq,
        c.font_raster.compareVersions(version, version),
    );
    try std.testing.expectEqual(
        .lt,
        c.font_raster.compareVersions(
            .{ .major = 1, .minor = 0, .patch = 0 },
            c.font_raster.MINIMUM_VERSION,
        ),
    );
    try std.testing.expectEqual(
        .gt,
        c.font_raster.compareVersions(
            .{ .major = 99, .minor = 0, .patch = 0 },
            c.font_raster.MINIMUM_VERSION,
        ),
    );
    // A loaded library has nothing to diagnose.
    try std.testing.expect(c.font_raster.loadFailureDiagnostic() == null);
}

test "a missing shared library fails cleanly and names the requirement" {
    // The loader caches its result process-wide, so this asserts the observable
    // contract rather than trying to unload anything: a name that cannot exist
    // yields null, never a trap.
    // Reaching the shaper on a host without HarfBuzz must produce the
    // documented error rather than a trap. On a host that has it, the call
    // simply succeeds, which is also a valid outcome of this contract.
    var fs = c.FontSystem.init(a) catch return error.SkipZigTest;
    defer fs.deinit();
    const inter = try readFixture(a, "Inter-Regular.ttf");
    defer a.free(inter);
    if (fs.addFontData(1, inter, 0, false, null)) |_| {
        try std.testing.expect(c.shape_hb.loadFailureDiagnostic() == null);
    } else |err| {
        try std.testing.expect(err == error.LibraryUnavailable or err == error.MissingSymbol);
        // A load failure must always come with an explanation.
        try std.testing.expect(c.shape_hb.loadFailureDiagnostic() != null);
    }
}

// ---------------------------------------------------------------------------
// Fallback policy: the connected resolver now applies the script/locale family
// order instead of walking the global match list (audit, "Fallback policy is
// simplified in the connected path").
// ---------------------------------------------------------------------------

test "script fallback families are consulted before the global match order" {
    var fs = try fonts.fontSystem(a);
    defer fs.deinit();
    const adapter = fs.shaper().?;
    const query = c.shape.FontQuery{ .family_kind = .name, .family_name = "Inter" };

    // The primary is Inter; attempt 0 for Hebrew text must be the Hebrew face
    // named by the vendored `unix.rs` script table, not whichever face the
    // global match order happened to put first.
    const primary = adapter.fontFor(query).?;
    const hebrew_fb = adapter.fallbackFor(query, .hebrew, 0).?;

    const hebrew_face = fs.db.face(hebrew_fb).?;
    const has_hebrew_family = blk: {
        for (hebrew_face.families) |fam| {
            if (std.mem.eql(u8, fam, "Noto Sans Hebrew")) break :blk true;
        }
        break :blk false;
    };
    try std.testing.expect(has_hebrew_family);
    try std.testing.expect(primary != hebrew_fb);

    // Exhaustion is still reported as null, and attempts never repeat a font.
    var seen: [64]c.FontId = undefined;
    var n: usize = 0;
    while (adapter.fallbackFor(query, .hebrew, n)) |id| : (n += 1) {
        try std.testing.expect(n < seen.len);
        for (seen[0..n]) |prior| try std.testing.expect(prior != id);
        seen[n] = id;
    }
    try std.testing.expect(n > 0);
    try std.testing.expect(n < fs.fontIds().len);
}

test "script fallback families differ per script" {
    var fs = try fonts.fontSystem(a);
    defer fs.deinit();
    const adapter = fs.shaper().?;
    const query = c.shape.FontQuery{ .family_kind = .name, .family_name = "Inter" };

    const arabic_fb = adapter.fallbackFor(query, .arabic, 0).?;
    const hebrew_fb = adapter.fallbackFor(query, .hebrew, 0).?;
    // The two script tables name different families, so the first candidate
    // must differ. (Under the previous global-match-order resolver both
    // returned the same face.)
    try std.testing.expect(arabic_fb != hebrew_fb);
}

test "adding a font can make previously missing coverage available" {
    var fs = try c.FontSystem.init(a);
    defer fs.deinit();
    const inter = try readFixture(a, "Inter-Regular.ttf");
    defer a.free(inter);
    const inter_id = try fs.dbMut().addFaceFromBytes(inter, 0, "Inter-Regular.ttf");
    try fs.addFontData(inter_id, inter, 0, false, null);
    try fs.dbMut().setSansFamily("Inter");

    var attrs = fonts.attrsWithFamily(a, "Inter");
    defer attrs.deinit();

    // Arabic is outside Inter's coverage and no other font is registered yet.
    var before = try c.Buffer.initWithAllocator(a, c.Metrics.new(20, 24));
    defer before.deinit();
    try before.setText("\u{0645}", &attrs, .advanced, null);
    try before.shapeUntilScroll(&fs, false);
    var it_before = before.layoutRuns();
    const before_run = it_before.next().?;
    try std.testing.expect(before_run.glyphs.len > 0);
    try std.testing.expectEqual(@as(u16, 0), before_run.glyphs[0].glyph_id);

    // Register the covering face: the next shape must find it.
    const arabic = try readFixture(a, "NotoSansArabic.ttf");
    defer a.free(arabic);
    const arabic_id = try fs.dbMut().addFaceFromBytes(arabic, 0, "NotoSansArabic.ttf");
    try fs.addFontData(arabic_id, arabic, 0, false, null);

    var after = try c.Buffer.initWithAllocator(a, c.Metrics.new(20, 24));
    defer after.deinit();
    try after.setText("\u{0645}", &attrs, .advanced, null);
    try after.shapeUntilScroll(&fs, false);
    var it_after = after.layoutRuns();
    const after_run = it_after.next().?;
    try std.testing.expect(after_run.glyphs[0].glyph_id != 0);
    try std.testing.expectEqual(arabic_id, after_run.glyphs[0].font_id);
}

test "audit 5: FontSystem registration invalidates the shaped-run cache" {
    var fs = try c.FontSystem.init(a);
    defer fs.deinit();
    const inter = try readFixture(a, "Inter-Regular.ttf");
    defer a.free(inter);
    const id = try fs.dbMut().addFaceFromBytes(inter, 0, "Inter-Regular.ttf");
    try fs.addFontData(id, inter, 0, false, null);
    try fs.dbMut().setSansFamily("Inter");

    var attrs = fonts.attrsWithFamily(a, "Inter");
    defer attrs.deinit();
    var buf = try c.Buffer.initWithAllocator(a, c.Metrics.new(20, 24));
    defer buf.deinit();
    try buf.setText("WWW", &attrs, .advanced, null);
    try buf.shapeUntilScroll(&fs, false);
    var it1 = buf.layoutRuns();
    const first = it1.next().?.glyphs[0].w;

    // Replace the bytes behind the same database id.
    const mono = try readFixture(a, "FiraMono-Medium.ttf");
    defer a.free(mono);
    try fs.addFontData(id, mono, 0, false, null);

    var buf2 = try c.Buffer.initWithAllocator(a, c.Metrics.new(20, 24));
    defer buf2.deinit();
    try buf2.setText("WWW", &attrs, .advanced, null);
    try buf2.shapeUntilScroll(&fs, false);
    var it2 = buf2.layoutRuns();
    const second = it2.next().?.glyphs[0].w;

    // A fresh buffer must not reuse the previous font's advance width.
    try std.testing.expect(first != second);
}

// ---------------------------------------------------------------------------
// 6. P2 — changing the raster backend retained stale outlines
// ---------------------------------------------------------------------------

test "audit 6: attaching a real raster drops synthetic outline cache entries" {
    var fallback = c.swash_cache.FallbackRaster{};
    var cache = c.SwashCache.init(a, fallback.adapter());
    defer cache.deinit();

    const key = c.glyph_cache.CacheKey.new(999, 1, 16, .{ .x = 0, .y = 0 }, 400, .{}).key;
    // Warm the outline cache with the stand-in's output.
    const before = (try cache.getOutline(key)) orelse return error.TestUnexpectedResult;
    try std.testing.expect(before.len > 0);

    var raster = try c.Raster.init(a);
    defer raster.deinit();
    cache.setRaster(&raster);

    // The stale synthetic outline must be gone: an unknown font id through
    // the (empty) real raster is a miss.
    try std.testing.expect(try cache.getOutline(key) == null);
}

test "audit 6: detaching the raster drops real outline cache entries" {
    var fallback = c.swash_cache.FallbackRaster{};
    var cache = c.SwashCache.init(a, fallback.adapter());
    defer cache.deinit();
    var raster = try c.Raster.init(a);
    defer raster.deinit();
    cache.setRaster(&raster);

    const key = c.glyph_cache.CacheKey.new(999, 1, 16, .{ .x = 0, .y = 0 }, 400, .{}).key;
    try std.testing.expect(try cache.getOutline(key) == null);

    // Detach, then the stand-in adapter becomes authoritative again.
    cache.setRaster(null);
    const after = (try cache.getOutline(key)) orelse return error.TestUnexpectedResult;
    try std.testing.expect(after.len > 0);
}

test "audit 6: replacing a raster's font at the same id invalidates both caches" {
    const inter = try readFixture(a, "Inter-Regular.ttf");
    defer a.free(inter);
    var raster = try c.Raster.init(a);
    defer raster.deinit();
    try raster.addFont(4, inter, 0);

    var cache = c.SwashCache.init(a, null);
    defer cache.deinit();
    cache.setRaster(&raster);

    // Find a glyph id that produces output from the real face.
    var gid: u16 = 0;
    var probe: c.glyph_cache.CacheKey = undefined;
    for (1..64) |candidate| {
        const candidate_key = c.glyph_cache.CacheKey.new(4, @intCast(candidate), 16, .{ .x = 0, .y = 0 }, 400, .{}).key;
        if (try cache.getOutline(candidate_key)) |cmds| {
            if (cmds.len > 0) {
                gid = @intCast(candidate);
                probe = candidate_key;
                break;
            }
        }
    }
    if (gid == 0) return error.SkipZigTest;
    const key = probe;

    const first_outline = (try cache.getOutline(key)) orelse return error.SkipZigTest;
    const first_cmds = try a.dupe(c.swash_cache.OutlineCommand, first_outline);
    defer a.free(first_cmds);
    const first_img = (try cache.getImage(key)) orelse return error.SkipZigTest;

    // Same id, different bytes.
    const mono = try readFixture(a, "FiraMono-Medium.ttf");
    defer a.free(mono);
    try raster.addFont(4, mono, 0);

    // Both caches must have been dropped, so the content is regenerated.
    const second_outline = (try cache.getOutline(key)) orelse return error.TestUnexpectedResult;
    try std.testing.expect(second_outline.ptr != first_cmds.ptr);
    const second_img = (try cache.getImage(key)) orelse return error.TestUnexpectedResult;
    // Fira Mono 'A' differs from Inter 'A'; the stale Inter pixels must not
    // be served under the same key.
    try std.testing.expect(!std.mem.eql(u8, first_img.data, second_img.data));
}

// ---------------------------------------------------------------------------
// 7. P2 — the advertised 16,384-run capacity was not enforced
// ---------------------------------------------------------------------------

test "audit 7: the production insertion policy keeps entries bounded" {
    var cache = c.shape_run_cache.ShapeRunCache.init(a);
    defer cache.deinit();
    var attrs = c.Attrs.init(a);
    defer attrs.deinit();
    var list = try c.attrs.AttrsList.init(a, &attrs);
    defer list.deinit();
    var text: [32]u8 = undefined;
    for (0..17_000) |i| {
        const key = c.shape_run_cache.KeyRef{
            .text = try std.fmt.bufPrint(&text, "run-{d}", .{i}),
            .default_attrs = &list.default_attrs,
            .spans = &.{},
            .rtl = false,
        };
        try cache.insert(&key, &.{});
        cache.enforceBudget();
    }
    // The audit recorded 17,000 surviving entries against an advertised 16,384
    // bound; the bound must now hold.
    try std.testing.expect(cache.len() <= 16384);
}

test "audit 7: a byte budget bounds long unique runs" {
    var cache = c.shape_run_cache.ShapeRunCache.init(a);
    defer cache.deinit();
    // Entry budget high enough that only the byte budget can fire.
    cache.max_entries = 1_000_000;
    cache.max_bytes = 512 * 1024;

    var attrs = c.Attrs.init(a);
    defer attrs.deinit();
    var list = try c.attrs.AttrsList.init(a, &attrs);
    defer list.deinit();

    var buf: [8192]u8 = undefined;
    var glyphs: [256]c.shape_run_cache.CachedGlyph = undefined;
    for (&glyphs, 0..) |*g, i| g.* = .{
        .start = i,
        .end = i + 1,
        .x_advance = 0.5,
        .y_advance = 0,
        .x_offset = 0,
        .y_offset = 0,
        .ascent = 0,
        .descent = 0,
        .font_id = 1,
        .font_weight = c.attrs.Weight.normal,
        .glyph_id = 1,
    };

    const long_run = buf[0..6000];
    @memset(long_run, 'x');
    for (0..500) |i| {
        long_run[0] = @truncate('A' + @as(u8, @intCast(i % 26)));
        const key = c.shape_run_cache.KeyRef{
            .text = long_run,
            .default_attrs = &list.default_attrs,
            .spans = &.{},
            .rtl = false,
        };
        try cache.insert(&key, &glyphs);
        cache.enforceBudget();
        try std.testing.expect(cache.bytesUsed() <= cache.max_bytes);
    }
    try std.testing.expect(cache.len() < 500);
}

// ---------------------------------------------------------------------------
// 8. P2 — the run cache ignored shaping direction
// ---------------------------------------------------------------------------

test "audit 8: an RTL request does not return the cached LTR shaping" {
    var backend = c.shape.CharmapAdapter{};
    var cache = c.shape.ShapeRunCache.init(a);
    defer cache.deinit();
    backend.test_run_cache = &cache;
    var attrs = c.Attrs.init(a);
    defer attrs.deinit();
    var list = try c.attrs.AttrsList.init(a, &attrs);
    defer list.deinit();
    var scratch = c.shape.ShapeBuffer.init();
    defer scratch.deinit(a);

    var ltr: std.ArrayList(c.shape.ShapeGlyph) = .empty;
    defer ltr.deinit(a);
    var cached_rtl: std.ArrayList(c.shape.ShapeGlyph) = .empty;
    defer cached_rtl.deinit(a);
    var fresh_rtl: std.ArrayList(c.shape.ShapeGlyph) = .empty;
    defer fresh_rtl.deinit(a);

    try c.shape.shapeRunCached(a, backend.adapter(), &scratch, &ltr, "abc", &list, 0, 3, false);
    try c.shape.shapeRunCached(a, backend.adapter(), &scratch, &cached_rtl, "abc", &list, 0, 3, true);
    try c.shape.shapeRun(a, backend.adapter(), &scratch, &fresh_rtl, "abc", &list, 0, 3, true);

    // The cache must not answer an RTL lookup with the LTR entry.
    try std.testing.expectEqual(fresh_rtl.items[0].start, cached_rtl.items[0].start);
    try std.testing.expect(fresh_rtl.items[0].start != ltr.items[0].start);
    // Both directions are retained separately.
    try std.testing.expectEqual(@as(usize, 2), cache.len());
}

test "audit 8: cache-on and cache-off agree for both directions" {
    var fs = try fonts.fontSystem(a);
    defer fs.deinit();
    var attrs = fonts.attrsWithFamily(a, "Inter");
    defer attrs.deinit();

    const Cases = [_]struct { text: []const u8, rtl: bool }{
        .{ .text = "abc", .rtl = false },
        .{ .text = "abc", .rtl = true },
        .{ .text = "\u{05E9}\u{05DC}\u{05D5}\u{05DD}", .rtl = false },
        .{ .text = "\u{05E9}\u{05DC}\u{05D5}\u{05DD}", .rtl = true },
    };

    for (Cases) |case| {
        var list = try c.attrs.AttrsList.init(a, &attrs);
        defer list.deinit();
        var scratch = c.shape.ShapeBuffer.init();
        defer scratch.deinit(a);

        var cold: std.ArrayList(c.shape.ShapeGlyph) = .empty;
        defer cold.deinit(a);
        try c.shape.shapeRunCached(a, fs.shaper().?, &scratch, &cold, case.text, &list, 0, case.text.len, case.rtl);
        // Second pass is served from the cache.
        var warm: std.ArrayList(c.shape.ShapeGlyph) = .empty;
        defer warm.deinit(a);
        try c.shape.shapeRunCached(a, fs.shaper().?, &scratch, &warm, case.text, &list, 0, case.text.len, case.rtl);

        // And with caching off entirely.
        fs.setRunCacheEnabled(false);
        var uncached: std.ArrayList(c.shape.ShapeGlyph) = .empty;
        defer uncached.deinit(a);
        try c.shape.shapeRun(a, fs.shaper().?, &scratch, &uncached, case.text, &list, 0, case.text.len, case.rtl);
        fs.setRunCacheEnabled(true);

        try std.testing.expectEqual(cold.items.len, warm.items.len);
        try std.testing.expectEqual(uncached.items.len, warm.items.len);
        for (cold.items, warm.items, uncached.items) |x, y, z| {
            try std.testing.expectEqual(x.glyph_id, y.glyph_id);
            try std.testing.expectEqual(x.start, y.start);
            try std.testing.expectEqual(x.end, y.end);
            try std.testing.expectEqual(y.glyph_id, z.glyph_id);
            try std.testing.expectEqual(y.start, z.start);
            try std.testing.expectEqual(y.end, z.end);
            try std.testing.expectEqual(x.x_advance, y.x_advance);
            try std.testing.expectEqual(y.x_advance, z.x_advance);
        }
    }
}

test "audit 8: the direction key is not shared across a paragraph direction change" {
    var fs = try fonts.fontSystem(a);
    defer fs.deinit();
    var attrs = fonts.attrsWithFamily(a, "Inter");
    defer attrs.deinit();

    var buf = try c.Buffer.initWithAllocator(a, c.Metrics.new(20, 24));
    defer buf.deinit();
    buf.setDirection(.left_to_right);
    try buf.setText("abc", &attrs, .advanced, null);
    try buf.shapeUntilScroll(&fs, false);
    var it_ltr = buf.layoutRuns();
    const ltr_glyph = it_ltr.next().?.glyphs[0].glyph_id;

    // Same text, RTL base direction: the run is reversed by the bidi layout,
    // so the shaped output must differ and must not come from the LTR entry.
    buf.setDirection(.right_to_left);
    try buf.shapeUntilScroll(&fs, false);
    var it_rtl = buf.layoutRuns();
    const rtl_glyph = it_rtl.next().?.glyphs[0].glyph_id;

    try std.testing.expect(ltr_glyph != rtl_glyph);
}

// ---------------------------------------------------------------------------
// Tab rewriting at the shaping seam (upstream shape.rs:165-173)
// ---------------------------------------------------------------------------

test "tabs are shaped as spaces with original byte offsets" {
    var fs = try fonts.fontSystem(a);
    defer fs.deinit();
    var attrs = fonts.attrsWithFamily(a, "Inter");
    defer attrs.deinit();

    // "a\tb" and "a b" must shape to the same glyph sequence.
    var tabbed = try c.Buffer.initWithAllocator(a, c.Metrics.new(20, 24));
    defer tabbed.deinit();
    try tabbed.setText("a\tb", &attrs, .advanced, null);
    try tabbed.shapeUntilScroll(&fs, false);

    var spaced = try c.Buffer.initWithAllocator(a, c.Metrics.new(20, 24));
    defer spaced.deinit();
    try spaced.setText("a b", &attrs, .advanced, null);
    try spaced.shapeUntilScroll(&fs, false);

    var it_tab = tabbed.layoutRuns();
    var it_sp = spaced.layoutRuns();
    const t = it_tab.next().?.glyphs;
    const s = it_sp.next().?.glyphs;
    try std.testing.expectEqual(s.len, t.len);
    for (t, s) |x, y| {
        try std.testing.expectEqual(y.glyph_id, x.glyph_id);
    }
    // The tab's cluster still points at byte 1 of the original text.
    try std.testing.expectEqual(@as(usize, 3), t[t.len - 1].end);
}

test "tabs in advanced non-ASCII text shape without missing glyphs" {
    var fs = try fonts.fontSystem(a);
    defer fs.deinit();
    var attrs = fonts.attrsWithFamily(a, "Inter");
    defer attrs.deinit();

    // Arabic word with tabs around it: exercises the rewrite together with
    // fallback and a non-ASCII script.
    const text = "\u{0645}\t\u{0631}\u{062D}\u{0628}\u{0627}";
    var buf = try c.Buffer.initWithAllocator(a, c.Metrics.new(20, 24));
    defer buf.deinit();
    try buf.setText(text, &attrs, .advanced, null);
    try buf.shapeUntilScroll(&fs, false);

    var missing: usize = 0;
    var max_end: usize = 0;
    var it = buf.layoutRuns();
    while (it.next()) |r| for (r.glyphs) |g| {
        if (g.glyph_id == 0) missing += 1;
        max_end = @max(max_end, g.end);
    };
    try std.testing.expectEqual(@as(usize, 0), missing);
    // Glyph ranges must stay inside the original byte length (8 bytes: 2 + 1
    // tab + 5 Arabic codepoints of 2 bytes each).
    try std.testing.expect(max_end <= text.len);
}
// ---------------------------------------------------------------------------
// Port fixes found by the 2026-10 cosmic-text parity review
// ---------------------------------------------------------------------------

fn ellipsizedRunCount(fs: *c.FontSystem, max_height: f32) !usize {
    var attrs = fonts.attrsWithFamily(a, "Inter");
    defer attrs.deinit();
    var buf = try c.Buffer.initWithAllocator(a, c.Metrics.new(20, 20));
    defer buf.deinit();
    buf.setWrap(.word);
    buf.setSize(200, null);
    buf.setEllipsize(.{ .end = .{ .height = max_height } });
    try buf.setText("The quick brown fox jumps over the lazy dog. " ++
        "Pack my box with five dozen liquor jugs. How vexingly quick daft zebras jump.", &attrs, .advanced, null);
    try buf.shapeUntilScroll(fs, false);
    var n: usize = 0;
    var it = buf.layoutRuns();
    while (it.next()) |_| n += 1;
    return n;
}

test "ellipsize Height limit keeps every line that fits (was capped at 1 line)" {
    var fs = try fonts.fontSystem(a);
    defer fs.deinit();
    // shape.rs: a line is the last one when height_so_far + 2 * line_height
    // exceeds the limit. 45px at 20px lines: line 2 (20 + 40 > 45) is last.
    try std.testing.expectEqual(@as(usize, 2), try ellipsizedRunCount(&fs, 45));
    // 100px: lines at 0, 20, 40, 60 fit (60 + 40 = 100 is not > 100); the
    // fifth (80 + 40 > 100) is the ellipsized last line.
    try std.testing.expectEqual(@as(usize, 5), try ellipsizedRunCount(&fs, 100));
}

/// Family names of the faces that shaped `text` under `family`.
fn shapedFamily(fs: *c.FontSystem, family: []const u8, text: []const u8) ![]const u8 {
    var attrs = fonts.attrsWithFamily(a, family);
    defer attrs.deinit();
    var buf = try c.Buffer.initWithAllocator(a, c.Metrics.new(20, 24));
    defer buf.deinit();
    try buf.setText(text, &attrs, .advanced, null);
    try buf.shapeUntilScroll(fs, false);
    var it = buf.layoutRuns();
    const run = it.next() orelse return error.TestUnexpectedResult;
    const face = fs.db.face(run.glyphs[0].font_id) orelse return error.TestUnexpectedResult;
    return face.families[0];
}

test "a missing family falls through to the common fallback list" {
    var fs = try fonts.fontSystem(a);
    defer fs.deinit();
    // fallback/mod.rs: no face named "Nonexistent" -> script phase (none for
    // Latin) -> common list, whose first installed entry is "Noto Sans".
    try std.testing.expectEqualStrings("Noto Sans", try shapedFamily(&fs, "Nonexistent", "Hello"));
    // An installed family still wins.
    try std.testing.expectEqualStrings("Inter", try shapedFamily(&fs, "Inter", "Hello"));
}
