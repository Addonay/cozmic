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
`zig build test`. Remaining gaps are listed below.

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

Requires Zig 0.17.0 or newer.

```sh
zig build test           # all tests (module + ported upstream suites)
zig build check-bindings # verify generated runtime bindings are in date
zig build bench          # cozmic benchmarks (-- --quick for a smoke run)
zig build bench-matched  # like-for-like run against benches/upstream/matched_probe.rs
zig build bench-compare  # cozmic vs cosmic-text criterion side-by-side
zig build run            # shape one line and print its metrics
```

Optional features: `-Dvi`, `-Dsyntect` (default off). These gate whether the
experimental `cozmic.vi` / `cozmic.syntect` surfaces are exported at all;
their `*_enabled` constants separately report editor readiness.

## Benchmarks

On matched cold-layout workloads with identical glyph output, cozmic runs
0.76x–1.02x of cosmic-text's time. See [docs/BENCHMARKS.md](docs/BENCHMARKS.md)
for methodology, the run-cache semantics, and binary-size figures.
