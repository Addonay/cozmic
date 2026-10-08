//! cozmic root — re-exports the canonical type owners (see `types.zig`).
//! Unlike the oracle `lib.rs` (`pub use buffer::*` etc.), this port keeps
//! modules namespaced; the aliases below are the stable top-level API and all
//! point at the single canonical owner for each type.

const std = @import("std");
const Io = std.Io;

pub const layout = @import("layout.zig");
pub const render = @import("render.zig");
pub const bidi_para = @import("bidi_para.zig");
pub const cursor = @import("cursor.zig");
pub const line_ending = @import("line_ending.zig");
pub const cached = @import("cached.zig");
/// Float helpers for layout math. Stays `pub` for layout parity with the
/// oracle's `math` module (used by layout/shape code); not part of the
/// stable text API.
pub const math = @import("math.zig");
pub const attrs = @import("attrs.zig");
pub const font = @import("font.zig");
pub const font_system = @import("font_system.zig");
pub const fallback = @import("fallback.zig");
pub const glyph_cache = @import("glyph_cache.zig");
pub const shape = @import("shape.zig");
pub const shape_run_cache = @import("shape_run_cache.zig");
pub const swash_cache = @import("swash_cache.zig");
pub const font_raster = @import("font_raster.zig");
pub const raster_ft = @import("raster_ft.zig");
pub const shape_hb = @import("shape_hb.zig");
pub const buffer_line = @import("buffer_line.zig");
pub const buffer = @import("buffer.zig");
pub const edit = @import("edit.zig");
/// Feature-gated optional editors (build flags default off):
/// `-Dvi=true` / `-Dsyntect=true` decide whether the experimental surfaces are
/// exported at all — the default build exposes only a disabled stub, so
/// consumers cannot silently depend on the unfinished editors, and enabling a
/// flag is an explicit opt-in. The modules' own `vi_enabled` /
/// `syntect_enabled` constants keep reporting *editor readiness* (false while
/// their TODOs remain) and stay importable standalone (`zig test src/vi.zig`)
/// without build_options — the build flag is applied here, at the export
/// seam, which is what TODO(vi)/TODO(syntect) asked for. The test block below
/// imports the files directly, so their suites run regardless of the flag.
const DisabledVi = struct {
    pub const vi_enabled: bool = false;
};
const DisabledSyntect = struct {
    pub const syntect_enabled: bool = false;
};
const build_options = @import("build_options");
pub const vi = if (build_options.vi) @import("vi.zig") else DisabledVi;
pub const syntect = if (build_options.syntect) @import("syntect.zig") else DisabledSyntect;
pub const unicode = @import("unicode.zig");
/// Canonical type ownership contract for the integration pass.
pub const types = @import("types.zig");
/// Vendored C binding libraries (see build.zig; `c.zig` re-exports generated
/// dynamic bindings since Zig 0.17 removed @cImport and the system
/// HarfBuzz/FreeType libraries are loaded at runtime, not linked).
pub const harfbuzz = @import("harfbuzz");
pub const freetype = @import("freetype");

// Canonical top-level aliases (oracle `lib.rs` parity), one owner per type.
pub const Buffer = buffer.Buffer;
pub const BufferWithFontSystem = buffer.BufferWithFontSystem;
pub const BufferLine = buffer_line.BufferLine;
pub const Editor = edit.Editor;
pub const Selection = edit.Selection;
pub const Change = edit.Change;
pub const ChangeItem = edit.ChangeItem;
pub const Action = edit.Action;
pub const Attrs = attrs.Attrs;
pub const AttrsList = attrs.AttrsList;
pub const Metrics = attrs.Metrics;
pub const Color = attrs.Color;
pub const Weight = attrs.Weight;
pub const Stretch = attrs.Stretch;
pub const Style = attrs.Style;
pub const Family = attrs.Family;
pub const UnderlineStyle = attrs.UnderlineStyle;
pub const TextDecoration = attrs.TextDecoration;
pub const DecorationMetrics = attrs.DecorationMetrics;
pub const GlyphDecorationData = attrs.GlyphDecorationData;
pub const CacheKeyFlags = attrs.CacheKeyFlags;
pub const FontSystem = font_system.FontSystem;
pub const FontDb = font_system.FontDb;
pub const Cursor = cursor.Cursor;
pub const LayoutCursor = cursor.LayoutCursor;
pub const Motion = cursor.Motion;
pub const Scroll = cursor.Scroll;
pub const Affinity = cursor.Affinity;
pub const FontId = layout.FontId;
pub const CursorPosition = buffer.CursorPosition;
pub const SwashCache = swash_cache.SwashCache;
pub const Raster = font_raster.Raster;

/// Backend load diagnostics.
///
/// The native libraries are loaded through `dynload`, which caches its result
/// process-wide: a failure repeats the same bare error with no explanation.
/// These report the loaded version and, when loading failed, a message naming
/// what was wanted. Both return "not usable" rather than claiming success when
/// the version cannot be read.
pub const backendVersion = struct {
    /// HarfBuzz version string, `""` when the library cannot be loaded.
    pub const harfbuzz = shape_hb.version;
    /// Whether the loaded HarfBuzz satisfies `shape_hb.MINIMUM_VERSION`.
    pub const harfbuzzMeetsMinimum = shape_hb.meetsMinimumVersion;
    /// Message for a failed HarfBuzz load/bind, `null` when it loaded.
    pub const harfbuzzFailure = shape_hb.loadFailureDiagnostic;
    /// Whether the loaded FreeType satisfies `font_raster.MINIMUM_VERSION`.
    pub const freetypeMeetsMinimum = font_raster.meetsMinimumVersion;
    /// Message for a failed FreeType load/bind, `null` when it loaded.
    pub const freetypeFailure = font_raster.loadFailureDiagnostic;
};
pub const LineEnding = line_ending.LineEnding;
pub const LineIter = line_ending.LineIter;
pub const Wrap = layout.Wrap;
pub const Align = layout.Align;
pub const Ellipsize = layout.Ellipsize;
pub const Hinting = layout.Hinting;
pub const LayoutLine = layout.LayoutLine;
pub const LayoutGlyph = layout.LayoutGlyph;
pub const Direction = shape.Direction;
pub const Shaping = shape.Shaping;
pub const ShapingError = shape.ShapeError;

test {
    _ = @import("layout.zig");
    _ = @import("font_blob.zig");
    _ = @import("render.zig");
    _ = @import("bidi_para.zig");
    _ = @import("cursor.zig");
    _ = @import("line_ending.zig");
    _ = @import("cached.zig");
    _ = @import("math.zig");
    _ = @import("attrs.zig");
    _ = @import("font.zig");
    _ = @import("font_system.zig");
    _ = @import("fontconfig.zig");
    _ = @import("fallback.zig");
    _ = @import("glyph_cache.zig");
    _ = @import("shape.zig");
    _ = @import("shape_run_cache.zig");
    _ = @import("swash_cache.zig");
    _ = @import("buffer_line.zig");
    _ = @import("buffer.zig");
    _ = @import("edit.zig");
    _ = @import("vi.zig");
    _ = @import("syntect.zig");
    _ = @import("unicode.zig");
    _ = @import("e2e_test.zig");
    _ = @import("backend_probe.zig");
    _ = @import("raster_ft.zig");
    _ = @import("shape_hb.zig");
}

// The `zig init` template helpers (`printAnotherMessage`, `add`) and the
// template executable in `src/main.zig` were removed: the audit flagged them
// as boilerplate that reads like public API but exercises none of the engine.
// Examples for this library should drive `cozmic.Buffer` / `cozmic.FontSystem`.
