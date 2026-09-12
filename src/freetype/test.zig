//! Test fixture loading for the vendored FreeType/HarfBuzz modules.
//!
//! The modules cannot `@embedFile` outside their own root, and an embedded
//! copy of a font would add a binary + license for no benefit. Tests read a
//! font from the vendored `tests/fonts` corpus at runtime instead; the test
//! steps run with the package root as cwd.

const std = @import("std");

/// Candidate paths to the shared fixture font, relative to the package root.
const CANDIDATES = [_][]const u8{
    "tests/fonts/Inter-Regular.ttf",
    "../tests/fonts/Inter-Regular.ttf",
    "src/../tests/fonts/Inter-Regular.ttf",
};

/// Read the fixture font. Caller owns the returned bytes. Returns
/// `error.SkipZigTest` only when the vendored corpus is absent.
pub fn loadTestFont(allocator: std.mem.Allocator) ![]u8 {
    var last_err: anyerror = error.FileNotFound;
    for (CANDIDATES) |path| {
        if (std.Io.Dir.cwd().readFileAlloc(std.testing.io, path, allocator, .limited(1 << 24))) |bytes| {
            return bytes;
        } else |err| {
            last_err = err;
        }
    }
    if (last_err == error.FileNotFound) return error.SkipZigTest;
    return last_err;
}
