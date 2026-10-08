# cozmic

Cozmic is a Zig text layout and editing library ported from
[COSMIC Text](https://github.com/pop-os/cosmic-text). It provides font selection
and fallback, shaping, bidirectional paragraph layout, wrapping, hit testing,
caret geometry, selection, editing, incremental layout, and optional glyph
rasterization.

The high-level engine is written in Zig with explicit allocators, ownership,
errors, cache lifetimes, and renderer-independent output. HarfBuzz and FreeType
are the intended production backends behind narrow adapters.

COSMIC Text is the primary source and compatibility reference. Pango
contributes behavioral ideas and a secondary oracle for capabilities such as
strong/weak carets, logical attributes, selection geometry, tabs, and advanced
typography.

Cozmic is independent of ZUI. It does not own native windows, OS keycode
mapping, clipboard services, GPU devices, or a widget tree.

## License and attribution

This port is distributed under the same terms as upstream COSMIC Text:
MIT OR Apache-2.0 (see `LICENSE-MIT` and `LICENSE-APACHE`). COSMIC Text is
Copyright (c) 2022 System76. The `src/harfbuzz/` and `src/freetype/` binding
modules are adapted from the allyourcodebase Zig bindings (MIT; licenses kept
at `src/harfbuzz/LICENSE` and `src/freetype/LICENSE`); the vendored test fonts
under `tests/fonts/` carry their own licenses (`*-LICENSE`), and the Unicode
tables/algorithms come from the pinned `ezi_code` dependency (MIT, fetched by
URL+hash). Keep these notices when moving the package into a larger
repository.

## Status

The public `Buffer`/`Editor` pipeline is connected to the real shaper and font
system: HarfBuzz and FreeType are loaded at runtime (no build-time link), the
full UCD comes from a pinned ezi-code dependency, fonts register lazily from
fontconfig or platform directories, and the upstream suites (direction, wrap
stability, ellipsize/decorations/shaping images, variable weights) run in
`zig build test`. The remaining gaps and the "safe as the only text stack"
gates (ZUI element wiring, IME, packaging) are tracked in
[plan.md](plan.md).

The `.reference/` checkouts (`cosmic-text`, `ezi-code`, HarfBuzz/FreeType
sources) are only needed for regeneration/diffing; the library builds from
`build.zig.zon` (ezi-code URL+hash) without them.

### Known gaps

- The `cozmic.vi` and `cozmic.syntect` surfaces are experimental and off by
  default (`-Dvi` / `-Dsyntect`). They are local models, not ports of upstream's
  ViEditor/SyntaxEditor, so do not treat them as parity with cosmic-text's
  optional features. Their `*_enabled` constants report readiness honestly.
- System variable fonts registered through fontconfig have no `wght` axis range
  (the directory/byte parsing paths do parse `fvar`), so they only match at
  their nominal weight.
- `FontSystem.getFont` is an id/weight lookup, not a `fontdb`-equivalent font
  object. Shaping goes through `FontSystem.shaper()` and rasterization through
  `font_raster.Raster`; both resolve and own the face bytes themselves.
- The run cache's eviction is a linear scan per eviction (correct and bounded,
  but not optimized for very large cold documents). See
  `ShapeRunCache.enforceBudget`.
- Deployment still requires loadable HarfBuzz and FreeType shared libraries at
  runtime. `cozmic.backendVersion` reports the loaded versions and a
  human-readable reason when a load fails, instead of only a cached error.
- Only Linux is validated by CI. Windows/macOS branches exist but are untested.

## Building

```sh
zig build test           # all tests (module + ported upstream suites)
zig build audit          # the COZMIC_AUDIT.md regression assertions only
zig build check-bindings # verify generated runtime bindings are in date
zig build bench          # cozmic benchmarks (-- --quick for a smoke run)
zig build bench-compare  # cozmic vs cosmic-text criterion side-by-side
zig build run            # shape one line and print its metrics
```

Optional features: `-Dvi`, `-Dsyntect` (default off). These gate whether the
experimental `cozmic.vi` / `cozmic.syntect` surfaces are exported at all;
their `*_enabled` constants separately report editor readiness.

## Benchmarks

The benches under `benches/` load only the vendored corpus in `tests/fonts`
(Inter, Noto Sans Arabic, Noto Sans Hebrew, FiraMono) with explicit family
names; they never touch system fonts, so every row is reproducible. They are
compiled at `-Dbench-optimize` (default `ReleaseFast`) independently of
`-Doptimize`, which still controls the app and tests.

```sh
zig build bench                      # full run, human-readable
zig build bench -- --quick           # smoke run: iters=3 warmup=1
COZMIC_BENCH_QUICK=1 zig build bench # same via environment
zig build bench -- --format json     # one JSON row per line
zig build bench -- --iter 10 --warmup 2
```

`tools/bench_compare.py` joins the JSON rows with the cosmic-text criterion
results; see `zig build bench-compare -- --help` (`--quick`, `--no-rust`,
`--iters`, `--measurement-time`, `--zig-bin`). The `loadFontSystem` row
measures an empty `FontSystem` plus a `tests/fonts` directory load; upstream's
`FontSystem::new()` scans the host font set, so that row is not directly
comparable across hosts.

### Bench semantics: parity rows vs warm run-cache rows

Standard rows **disable** the shaped-run cache so they compare like-for-like
with cosmic-text, whose equivalent `shape-run-cache` feature is default-off.
Rows suffixed `(run-cache warm)` enable it: the warmup pass fills the cache
and the timed iterations measure steady state — what an editor or frame loop
pays after the first render. The cache is **enabled by default for library
consumers**: it lives on the shaper backend (as upstream's does on
`FontSystem`), persists across buffers and frames, and lets the advanced path
skip shaping whenever the same run recurs — hits reproduce every glyph field
(byte-for-byte equal to fresh shaping, enforced by the image/wrap suites).

A cache key covers the run text, the shaping direction, the default attrs and
every non-default span (which includes `font_features`, `color_opt` and
`letter_spacing_opt`), so different features or directions never share an
entry. The cache is bounded by **both** a 16,384-entry cap and a 64 MiB
retained-byte budget, enforced by LRU eviction after every insert; font
registration and raster-producer changes clear it, since cached glyph ids and
pixel data belong to the face that produced them.
`FontSystem.setRunCacheEnabled` / `clearRunCache` let tools flip semantics.

