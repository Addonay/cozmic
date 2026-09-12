//! Backend load probe: verifies the vendored `harfbuzz` and `freetype`
//! binding libraries resolve their C libraries at runtime and expose working
//! entry points. Kept as a permanent smoke test so a broken dynamic load
//! fails loudly instead of silently disabling the real backend.

const std = @import("std");
const hb = @import("harfbuzz");
const ft = @import("freetype");

test "harfbuzz module loads and reports a version" {
    try hb.dyn.ensureLoaded();
    const version = hb.versionString();
    try std.testing.expect(version.len > 0);
}

test "freetype module loads and initializes a library" {
    try ft.dyn.ensureLoaded();
    var lib = try ft.Library.init();
    defer lib.deinit();
    const v = lib.version();
    try std.testing.expect(v.major > 0);
}
