# cozmic

Cozmic is a Zig text layout and editing library ported from
[COSMIC Text](https://github.com/pop-os/cosmic-text). It provides font selection
and fallback, shaping, bidirectional paragraph layout, wrapping, hit testing,
caret geometry, selection, editing, incremental layout, and optional glyph
rasterization.

The high-level engine is written in Zig with explicit allocators, ownership,
errors, cache lifetimes, and renderer-independent output. Shaping and
rasterization use HarfBuzz and FreeType, compiled from source into a trimmed
static build by default, so a cozmic binary depends on nothing but libc.

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
at `src/harfbuzz/LICENSE` and `src/freetype/LICENSE`). Bundled builds compile
HarfBuzz (MIT), FreeType (FTL), zlib (zlib) and libpng (libpng) from their
upstream release tarballs, pinned in `build.zig.zon`; the vendored test fonts
under `tests/fonts/` carry their own licenses (`*-LICENSE`), and the Unicode
tables/algorithms come from the pinned `ezi_code` dependency (MIT, fetched by
URL+hash). Keep these notices when moving the package into a larger
repository.

## Status

The public `Buffer`/`Editor` pipeline is connected to the real shaper and font
system. The full UCD comes from a pinned ezi-code dependency, fonts register
lazily from fontconfig or platform directories and are memory-mapped (shared,
read-only, one mapping per file for shaping and rasterization), and the
upstream suites (direction, wrap stability, ellipsize/decorations/shaping
images, variable weights) run in `zig build test`.

Beyond upstream: `edit.History` (bounded undo/redo for any `Editor`) and
`Buffer.measure` (laid-out width/height). Remaining gaps are listed below.

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
  `font_raster.Raster`; both share one refcounted `font_blob.Blob` per face.
- Upstream's monospace fallback phase (ranking monospace candidates by how many
  of the word's codepoints they cover) is approximated by "closest-weight
  monospaced face"; the resolver is not given the word.
- The run cache's eviction is a linear scan per eviction (correct and bounded,
  but not optimized for very large cold documents). See
  `ShapeRunCache.enforceBudget`.
- Only Linux is validated by CI. Windows/macOS branches exist but are untested.

## Building

Requires Zig 0.17.0 or newer. The first build fetches and compiles the bundled
C libraries (about a minute, cached afterwards).

```sh
zig build test           # all tests (module + ported upstream suites)
zig build check-bindings # verify generated runtime bindings are in date
zig build bench          # cozmic benchmarks (-- --quick for a smoke run)
zig build bench-matched  # like-for-like run against benches/upstream/matched_probe.rs
zig build bench-memory   # heap use per phase of the matched workload
zig build bench-compare  # cozmic vs cosmic-text criterion side-by-side
zig build run            # shape one line and print its metrics
```

Build options:

- `-Dsystem-libs` (default off): load the host's HarfBuzz/FreeType shared
  libraries at runtime instead of bundling them. `cozmic.backendVersion`
  then reports the loaded versions and why a load failed.
- `-Dcolor-bitmaps=false` (default on): leave out zlib + libpng, which FreeType
  needs only for PNG color bitmap glyphs (CBDT/sbix emoji such as Noto Color
  Emoji). COLR vector color glyphs work either way.
- `-Dvi`, `-Dsyntect` (default off): export the experimental `cozmic.vi` /
  `cozmic.syntect` surfaces; their `*_enabled` constants report readiness.

## Benchmarks

On matched cold-layout workloads with identical glyph output, cozmic takes
0.64x–0.87x of cosmic-text's time at the same peak RSS (5.3 MiB). A
ReleaseSmall demo binary is 1.55 MB stripped with no shared-library
dependencies besides libc. See [docs/BENCHMARKS.md](docs/BENCHMARKS.md) for
methodology, memory, run-cache semantics and size breakdown.
