//! Shared test fixtures: an isolated `FontSystem` over the vendored
//! `tests/fonts` corpus with real HarfBuzz shaping and FreeType raster bytes.
//!
//! Mirrors upstream `tests/common/mod.rs`'s isolated font database (upstream
//! builds `fontdb::Database::new()` + `load_fonts_dir("fonts")`; the vendored
//! fonts live in `tests/fonts` here).

const std = @import("std");
const cozmic = @import("cozmic");

/// Candidate fixture directories, tried in order so the suites work both from
/// the package root and from a parent/sibling cwd.
pub const FONT_DIRS = [_][]const u8{ "tests/fonts", "../tests/fonts", "src/../tests/fonts" };

/// Build a FontSystem containing only the vendored test fonts. Returns
/// `error.FontFixtureDirMissing` when none of the candidate dirs exist, and
/// `error.FontFixtureLoadFailed` when the corpus exists but is not fully
/// usable (parse errors, or no real shaper) — a broken fixture must fail, not
/// silently degrade to the charmap stand-in.
pub fn fontSystem(alloc: std.mem.Allocator) !cozmic.FontSystem {
    var fs = try cozmic.FontSystem.init(alloc);
    errdefer fs.deinit();
    for (FONT_DIRS) |dir| {
        const stats = fs.loadFontsDir(std.testing.io, dir);
        if (stats.faces_added > 0) {
            if (stats.file_errors > 0 or !fs.hasShaper()) return error.FontFixtureLoadFailed;
            return fs;
        }
    }
    return error.FontFixtureDirMissing;
}

/// `Attrs` with a named family (`"Inter"`, `"Noto Sans Arabic"`, ...).
pub fn attrsWithFamily(alloc: std.mem.Allocator, family: []const u8) cozmic.Attrs {
    var attrs = cozmic.Attrs.init(alloc);
    attrs.family = .{ .name = family };
    return attrs;
}
