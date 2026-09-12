//! Root of the ported upstream test suites. `zig build test` runs this module
//! alongside the `cozmic` unit tests; each file mirrors an upstream Rust test
//! file under `.reference/cosmic-text/tests/`.

test {
    _ = @import("direction.zig");
    _ = @import("ellipsize_rendering.zig");
    _ = @import("richtext_layout.zig");
    _ = @import("shaping_and_rendering.zig");
    _ = @import("text_decorations.zig");
    _ = @import("variable_font_weight.zig");
    _ = @import("wrap_stability.zig");
    _ = @import("wrap_word_fallback.zig");
}
