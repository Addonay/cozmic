# cozmic — cosmic-text port plan

Pinned upstream: `.reference/cosmic-text` (cosmic-text 0.19.0, ~12.4k LOC, 25 *.rs).
Vendored refs: `.reference/ezi-code` (UAX #9/#14/#24/#29, NFC/NFD, bidi, scripts),
`.reference/harfbuzz-ref` + `.reference/freetype-ref` (C wrap pattern).
Zig: 0.17.0-dev.2085+5e36170b5. Canonical type ownership: `src/types.zig`.

## Status vocabulary (owner review 2026-09-11)

"Landed" previously overstated several modules. Use these terms:
- **ported** — Rust logic transcribed, compiles, has unit tests.
- **isolated** — additionally compiles/tests standalone with local stand-in types.
- **connected** — uses canonical types and is reachable from the public API end to end.
- **verified** — output matches upstream on shared fixtures (differential test/image).

Current integration audit (owner probes):
1. Buffer did not use the real shaper: `FontSystem` empty struct, synthetic
   `0.6*size` advance, ellipsize ignored. Integration pass started 2026-09-11
   (shape/layout + buffer_line + buffer + edit rewire in flight).
2. `buffer.Attrs != attrs.Attrs`; Editor owned its own EditBuffer — unification in flight.
3. Delete at start of `e`+U+0301 left the accent — grapheme fix in flight.
4. `unicode.zig` used approximated table subsets and was not imported by
   shaping/editor — direct imports + full tables planned (ezi-code build dep).
5. Benchmarks compared different work (synthetic Zig vs real Rust) — harness
   kept, performance conclusions postponed until identical fonts/inputs.

## Module map (Rust -> Zig)

Status legend: ported / isolated / connected / verified / partial / stub.

| Rust | LOC | Zig | Status |
|------|-----|-----|--------|
| attrs.rs | 594 | src/attrs.zig | ported, connected (canonical owner) |
| cursor.rs | 156 | src/cursor.zig | ported, connected (canonical owner) |
| line_ending.rs | 98 | src/line_ending.zig | ported, connected (canonical owner) |
| cached.rs | 86 | src/cached.zig | ported |
| math.rs | 20 | src/math.zig | ported |
| layout.rs | 218 | src/layout.zig | ported, canonical owner; physical() -> CacheKey wire in flight |
| render.rs | 156 | src/render.zig | ported |
| bidi_para.rs | 74 | src/bidi_para.zig | ported (full UAX#9 levels pending) |
| font/mod.rs | 264 | src/font.zig | ported (sfnt sniff; HB/FT wiring point) |
| font/system.rs | 557 | src/font_system.zig | ported, canonical owner |
| font/fallback/* | 746 | src/fallback.zig | ported |
| font/cache.rs | 424 | src/font_system.zig (scan) | partial (CTFC disk cache TODO) |
| shape.rs | 3084 | src/shape.zig | ported; connecting to buffer in flight |
| shape_run_cache.rs | 49 | src/shape_run_cache.zig | ported |
| glyph_cache.rs | 170 | src/glyph_cache.zig | ported, connected (canonical owner) |
| swash.rs | 304 | src/swash_cache.zig | ported (raster stand-in until FT) |
| buffer_line.rs | 338 | src/buffer_line.zig | ported; connecting to shaper in flight |
| buffer.rs | 1830 | src/buffer.zig | ported; connecting to FontSystem/shape in flight |
| edit/mod.rs + editor.rs | 1259 | src/edit.zig | ported; connecting to Buffer + grapheme fix in flight |
| edit/vi.rs | 1181 | src/vi.zig | ported, isolated (no Buffer connection) |
| edit/syntect.rs | 494 | src/syntect.zig | stub (real highlighter pending) |
| lib.rs | 148 | src/root.zig | ported (public re-exports in flight) |
| rangemap | — | src/attrs.zig AttrsList | ported |
| unicode-bidi | — | src/bidi_para.zig + src/unicode.zig | partial (UAX#9 levels) |
| unicode-linebreak | — | src/unicode.zig | ported shards (full ezi-code dep pending) |
| unicode-segmentation | — | src/unicode.zig | ported shards (full ezi-code dep pending) |
| unicode-script | — | src/unicode.zig | ported shards (full ezi-code dep pending) |
| harfrust (HarfBuzz) | — | shape.zig ShapeAdapter seam | stub (real hb_shape pending) |
| skrifa + swash | — | src/font.zig + src/swash_cache.zig | stub (FreeType pending) |
| fontdb | — | src/font_system.zig FontDb | partial (fontconfig pending) |

## Integration order (agreed with owner)

1. One canonical type set (`src/types.zig`). — in flight
2. Connect FontSystem -> ShapeLine -> BufferLine -> Buffer -> Editor. — in flight
3. Replace synthetic font/shaping/raster adapters with one real backend
   (FreeType raster + HarfBuzz shaping behind the existing seams).
4. Connect complete Unicode data/algorithms (ezi-code dependency) to the pipeline.
5. Pass one end-to-end fixture: mixed Latin/Arabic, wrapping, click-to-caret,
   selection, insertion, grapheme deletion.
6. Expand differential coverage before Vi/syntax/optimization work.

## Test parity (image plan 2026-09-11)

Assets vendored: tests/fonts (7 ttf + 3 LICENSE), tests/images (24 png baselines),
tests/sample/hello.txt.
Suites: direction 7, wrap_stability 2, wrap_word_fallback 1, ellipsize 14 img,
richtext 1, shaping 6 img + 2 logic, decorations 4 img, variable 1, editor 7 (vi-gated).
Harness TODO: tests/common/draw.zig (isolated fontdb from tests/fonts, locale En-US,
margins 5, Pixmap blendSrcOver + fillRect, PNG writer via flate+Crc32, PNG read via
stb_image.h or minimal decoder, decoded-RGBA compare not byte compare, bless via
-Dgenerate-images or COZMIC_GENERATE_IMAGES).
Blockers: Buffer.draw/render missing, FontDb.loadFontsDir/loadFontData missing,
real HB/FT raster (solid-mask stand-in cannot match baselines).

## Gates

- `zig build test` green, `zig fmt --check` clean.
- Each module has unit tests mirroring Rust edge cases.
- End-to-end fixture (step 5 above) passes.
- Benches run under `zig build bench`; `bench-compare` emits dual tables.

## Reviews

- Leaf / font+shape / buffer+edit reviews DONE + fixes DONE 2026-09-11
  (render saturating, bidi B-set, flag bits, UAF, wrap branch, grapheme gaps).
  Verified suites green: render 17, layout 7, bidi 12, cached 5, cursor 8,
  attrs 13, math 4, swash 14, font_system 11, fallback 7, buffer 18,
  buffer_line 15, edit 18, root 183.

## Integration pass 2026-09-11 (owner review follow-up)

- `src/types.zig` landed: canonical type ownership contract; standalone-file
  constraint retired.
- layout/shape/shape_run_cache DONE: duplicates deleted, canonical imports,
  `LayoutGlyph.physical` builds a real `glyph_cache.CacheKey`, shape uses
  `unicode.zig` breaks/scripts/bidi. Tests: layout 27, shape 61, run cache 19.
- Owner fixes on top: `render.zig` canonical `attrs.Color`/`CacheKeyFlags`
  (37 tests); `unicode.zig` LB23/24/25/28/30 rules so words no longer split
  between letters (6 tests); `shape.zig` charmap RTL visual order fixes an
  end<start underflow (61 tests).
- edit.zig DONE: stand-ins deleted; `Editor` edits a real `Buffer` via
  `BufferRef`; grapheme-aware Delete/Backspace/motions/hit; `shapeAsNeeded`
  calls real `shapeUntilCursor/Scroll`; `e`+U+0301 Delete regression passes.
  Tests: edit 170 incl. real-font fixture.
- buffer_line.zig DONE: 97 tests, all stand-ins deleted, calls the real
  `ShapeLine.build`/`layoutToBuffer` (charmap seam) with the real FontSystem.
- buffer.zig DONE: 140 tests, real shaper path, ellipsize wired, `hit`/
  motions grapheme-correct via `unicode.zig`.
- Parent wiring: root.zig aliases repointed to canonical owners; benches load
  the vendored test fonts and use the canonical API; `e2e_test.zig` fixture
  added (mixed Latin/Arabic wrap + RTL levels, click-to-caret, selection,
  insertion, grapheme delete, ellipsize U+2026) and wired into `zig build test`.
- `unicode.zig` W3 fix: Arabic `AL -> R` before N/I passes (was level 0).
- `glyph_cache.CacheKeyFlags` unified onto `attrs.CacheKeyFlags`; `edit.Color`
  unified onto `attrs.Color`. Remaining: `attrs.Weight` (struct) vs
  glyph_cache/font_system `u16`; `FontId` placeholder in layout/glyph_cache.
- Build: `zig build test` -> 225/225 green; `zig build bench` and
  `zig build bench-compare` run through the integrated pipeline.

## Bench parity pass 2026-09-11

- Audited the 16 `UPSTREAM-ONLY` rows from `bench-compare`: none are missing
  cozmic features. 15 are upstream `Shaping::Basic` layout rows (cozmic has
  `Shaping.basic` via `shapeSkip` + tests); 1 is `load FontSystem`
  (`FontSystem.init` + `loadSystemFonts` exist).
- `benches/layout.zig`: full Wrap x Shaping(Simple/Advanced) matrix plus a
  `loadFontSystem` row; `tools/bench_compare.py` matches the shaping dimension
  and the font row. Result: 38 connected, 0 upstream-only.
- Fixed latent compile error in `FontSystem.loadSystemFonts` (`db.addFace`
  return value was ignored; `addScannedFile` was unreachable until the new
  bench exercised it).
- Corrected the compare tool's stale note: upstream has `Wrap::WordOrGlyph`;
  it simply has no bench row, so Zig-only coverage is expected.
- `build.zig`: bench run steps are serialized so JSON rows cannot interleave
  and the two benches stop contending for CPU.
- `zig build test` green; `zig fmt --check` clean.

Remaining for full cosmic-text parity, in priority order:
1. Real backend (IN PROGRESS 2026-09-11):
   - Vendored binding libraries: `.reference/harfbuzz-ref` -> `src/harfbuzz/`
     and `.reference/freetype-ref` -> `src/freetype/` (copies of the
     allyourcodebase Zig bindings, adapted to Zig 0.17). Their `c.zig` now
     re-exports `c_bindings.zig` generated with `zig translate-c` from the
     system headers (`@cImport` was removed in 0.17).
   - Registered as build modules `harfbuzz` and `freetype` in `build.zig`;
     system linkage (`linkSystemLibrary`) is declared there. Code uses
     `@import("harfbuzz")` / `@import("freetype")`.
   - Glue refactor: `src/shape_hb.zig` and `src/raster_ft.zig` both use the
     vendored modules; tests wired into root (245/245 green).
   - Engine bridge DONE: `FontSystem.addFontData(id, bytes, ...)` owns the
     HarfBuzz backend, `FontSystem.shaper()` returns the real `ShapeAdapter`,
     and `buffer_line.buildShapeLine` uses it whenever font data is
     registered (charmap remains only as the no-fonts fallback).
     `e2e_test.zig` and both benches register the vendored fonts, so mixed
     Latin/Arabic, ellipsize, click-to-caret, selection and insertion now run
     through HarfBuzz; a per-font-advance test proves shaping is real.
   - Raster bridge DONE: `src/font_raster.zig` bridges FontSystem font bytes to
     FreeType; `SwashCache.setRaster` prefers real `Rendered` bitmaps; e2e
     fixture renders a shaped 'A' through the cache (252/252 green).
   - `swash_cache.CacheKey` unified onto `glyph_cache.CacheKey`.
   - Next parity gates: `Buffer.draw` + image-test harness (tests/common),
     per-attrs font selection for fallback, fvar/wght, fontconfig discovery.
2. Unicode: replace approximated shards with the real ezi-code tables
   (build.zig.zon dependency).
3. Image-test harness (tests/common/draw.zig, decoded-RGBA compare) and the
   24 upstream baselines; run after (1).
4. `attrs.Weight`/`FontId` final unification; `syntect` real highlighter and
   `vi` reconnection to `Buffer`.
5. Bench fairness: deterministic fonts on both engines, then compare.

## Buffer/edit/layout notes

- BufferLine: owned text + ending + AttrsList, 2-level cache with Used->Unused
  reuse, reset_shaping > reset_layout hierarchy.
- DirtyFlags: RELAYOUT|TAB_SHAPE|TEXT_SET|SCROLL|DIRECTION, deferred resolve,
  shape_until_scroll/cursor preconditions.
- layout_runs culls by height, centers via (line_height-ascent-descent)/2,
  RTL-aware cursor/hit/highlight.
- Wrapping in shape.rs layout_to_buffer (~800 LOC): congruent/incongruent span
  walk, trailing-blank allowance, WordOrGlyph fallback, visual reorder, justify
  expansion, mono/hint rounding. Stability invariant: layout(unbounded)->w then
  layout(w) same wrap.
- Ellipsize: ellipsis U+2026, Start=backward+prepend, Middle=half-split +
  ellipsis_level_between (UAX#9 N1/N2), End=forward+append. Lines(0)->max(1),
  Height uses 2*lh lookahead.
- Editor: byte-index Cursor+Affinity, grapheme/word motions, hit per-grapheme
  half-split RTL-mirrored, delete_range/insert_at ending preservation +
  ChangeItem undo, selection Normal/Line/Word bounds.
- vi/syntect feature-gated; vi is isolated until Buffer connection.
- Test parity must include: stable_wrap matrix, wrap_word_fallback, ellipsize
  images, richtext empty-line metrics, BiDi seps no-panic, decorations,
  variable weights, editor_modified_state line endings.

## Parity pass 2026-09-12 (draw/render, fallback, variable weights, images)

- **HarfBuzz link fix**: `c_bindings.zig` carried a phantom
  `hb_font_set_funcs_using` (absent from the installed 8.3 headers); replaced
  with the stable `hb_ot_font_set_funcs` (`font.setOtFuncs`). The suite builds
  and links against system HarfBuzz again.
- **FreeType 2.14 test fixes**: unrecognized font bytes now surface as
  `FT_Err_Invalid_Stream_Operation`, mapped to `error.UnknownFileFormat` in
  `Face.initMemory`; raster advance expectation updated for the vendored
  Inter 4.0 fixture (UPM 2816, 'A' 1904 units -> 704/26.6 at 16px).
- **`Buffer.draw`/`render` + `BufferWithFontSystem.draw`/`render`** landed
  (`buffer.zig`), with `render.Callback`, `render.LegacyRenderer` (cache-backed
  1x1 pixel forwarding) and a `render.LayoutRun` view bridge. Decoration
  rendering now runs through the same callback path.
- **Per-attrs font selection + fallback**: `ShapeAdapter` gained
  `font_for`/`fallback_for` (with `shape.FontQuery`); `FontSystem.shaper()`
  installs a resolver over `getFontMatches`/`fontBytes`, so `Attrs.family`/
  `weight` select the right registered face and missing glyphs fall back
  across the database. `shapeRun` queries per run. e2e covers Inter ->
  Noto Sans Arabic fallback.
- **Variable fonts (`wght`)**: `ShapeAdapter.set_weight` + HarfBuzz
  `hb_font_set_variations` per query, FreeType `FT_Set_Var_Design_Coordinates`
  per rasterize (axes resolved via `FT_Get_MM_Var`), and
  `swash_cache` forwards `CacheKey.font_weight`; `FontDb` already parsed
  `fvar` ranges.
- **Font-provided decoration metrics**: `ShapingFontMetrics` carries
  underline/strikeout specs + upem/ascent; `shape.buildSpan` uses
  `decorationMetrics` instead of the hardcoded `-0.125/1/14` and `0.3/1/14`
  fallbacks. All four upstream decoration baselines now pass structural
  comparison.
- **Fractional raster offsets**: `font_raster.Raster.rasterize` takes the
  cache key's binned `x`/`y` offsets and applies them through
  `FT_Set_Transform` (26.6), matching swash's `Render::offset`; PIXEL_FONT
  rounding is preserved.
- **Font loaders**: `FontDb.addFaceFromBytes` / `loadFontFile` /
  `loadFontsDir` (real sfnt metadata incl. `fvar`) and
  `FontSystem.loadFontsDir` (database + HarfBuzz backend).
- **Image-test harness** (`tests/common/`): `png.zig` (encode/decode,
  RGB/RGBA/gray, all filters), `pixmap.zig` (source-over fill/FillRect),
  `draw.zig` (config, isolated fixture FontSystem, `Buffer.draw` into a
  pixmap, decoded comparison, non-destructive bless via
  `COZMIC_GENERATE_IMAGES=1 COZMIC_IMAGE_DIR=<dir>`). Comparison modes:
  pixel-exact or **structural** (every ink pixel within R px of the other
  image's ink), which absorbs FreeType-vs-swash AA differences (measured:
  0-4 stray pixels at R=1 on the text baselines, 0 at R=2).
- **Upstream suites ported** to `tests/` and wired into `zig build test` via
  a new `tests/all.zig` artifact: `direction` (7), `wrap_word_fallback` (1),
  `richtext_layout` (1), `wrap_stability` (114,240 strict comparisons),
  `shaping_and_rendering` (ligature segmentation, BiDi seps no-panic, 6 image
  cases), `ellipsize_rendering` (14 image cases), `text_decorations` (4 image
  cases), `variable_font_weight` (9 weights). 23/24 upstream image baselines
  pass structural comparison; `some_english_mixed_with_hebrew` is an explicit
  skip: the 390px wrap limit is missed by 0.56px (0.14%) versus upstream's
  shaper, moving one word to the next line (documented in the test).
- **Unicode shard corrections** (`unicode.zig`): LRM/RLM/ALM classes,
  Arabic-Indic digits, NBSP CS, control rows, Latin-1 punctuation; much wider
  word/grapheme/line shards (Hebrew, Arabic, Indic, Thai/Lao, Georgian,
  Ethiopic, CJK, kana, fullwidth); UCD-accurate `+`/`\` as PR (fixes `++`
  ligature segmentation), solidus/comma/SOL classes.
- **Scratch-pool leak**: `ShapeLine.layoutToBuffer` deinits cached
  `VisualLine.ranges` before clearing the pool; regression test reuses one
  `ShapeBuffer` across eight layouts under the testing allocator.
- **Error-path hardening (review follow-up)**: `layoutToBuffer` transfers
  `current` ownership safely (no double free on `reorder`/`emitLine`/append
  errors); `FontSystem.initWithDb`/`init` disarm pre-transfer errdefers and
  null out transferred optionals; `addFontData` publishes the HarfBuzz backend
  only after the first font registers; `SwashCache.getImage`/`getOutline`
  remove the inserted key when rendering fails (no undefined map values);
  `fontsInCollection` clamps a malformed TTC `numFonts` to the header's offset
  capacity; the reusable `glyph_sets` pool is deinited before clearing.
- **Review follow-up tests**: `wrap_extra_line` ported (1 empty + 4 overflow
  lines); direction helpers fail on empty layouts; harness fixtures fail
  loudly on parse errors/backends; `max_color_mass_diff_pct` catches colored
  decorations drawn in the wrong color; `setCharSize` renders fractional
  sizes and rejects only sub-1/64px; `FAKE_ITALIC` reaches FreeType; Basic
  shaping forwards the run weight; the real-backend Sans/Mono repatch is
  covered end to end; test runs are pinned to the package root cwd.
- Module tests: **282 green**; upstream suite 50 passed/1 skipped (`skip` is
  the documented 0.56px wrap-threshold case, with a self-checking probe);
  `zig fmt --check` clean. `zig build bench` compiled, but the benchmark run
  was OOM-killed in this sandbox; fixed on 2026-09-12 (iterations now use a
  resettable scratch arena, see the bench-determinism section below).

Remaining known gaps (unchanged priority order): full UAX#9 levels/explicit
codes, complete ezi-code property tables, CTFC disk cache/fontconfig
discovery, `attrs.Weight`/`FontId` type unification, Editor render borrowed
through `render.Renderer`, vi reconnection, syntect real highlighter.

## "Safe as the only text stack" plan (owner decision 2026-09-12)

Goal: the main ZUI app uses cozmic for every text path (measure, layout, wrap,
caret, selection, editing, fallback); no parallel shaping/measurement remains.
Platform scope decided by the owner: **Linux + Windows + macOS**, so cozmic
must not depend on hard-linked HarfBuzz/FreeType long term. Decisions:

1. **Boundary**: cozmic owns text semantics/layout/editing; ZUI's `fonts/`
   (fontconfig/FreeType/HarfBuzz via runtime `dlopen`) may remain as the
   font-resource layer during migration. "One stack" means one layout/editing
   engine, not necessarily one loader.
2. **Portable libraries (gate 4)**: replace the vendored `linkSystemLibrary`
   build with a runtime-loaded API table (one `std.DynLib` per library) that
   the vendored wrappers call through, mirroring the `dlopen` policy. ZUI can
   inject its already-loaded tables; cozmic keeps a self-contained fallback.

Gates and status:

| Gate | Acceptance | Status |
|---|---|---|
| 1. Lazy font sources | Registering N fonts retains no bytes; bytes load on first shaping/raster use; missing files degrade without panic | **DONE 2026-09-12** |
| 2. Scalable discovery | fontconfig (Linux), `%WINDIR%\\Fonts` + user dirs (Windows), `/System/Library/Fonts` + `/Library/Fonts` + `~/Library/Fonts` (macOS); fallback candidates per script | **DONE 2026-09-12** |
| 3. Unicode completeness | UCD/ezi-code tables for BiDi levels, UAX#14, UAX#29, scripts; the skipped upstream image case passes | **DONE 2026-09-12** |
| 4. Runtime library loading | No build-time `linkSystemLibrary`; `dlopen`/`LoadLibrary`/`dlopen` with clear errors; ZUI table injection path | **DONE 2026-09-12** |
| 5. ZUI bridge | cozmic drives element measure/paint; measured widths == painted widths; caret/selection/TextField consume the same layout; snapshot + headless tests | **DONE 2026-09-12** (default engine is now `cozmic`; `-Dtext-engine=legacy` is the escape hatch; bridge/parity/wiring tests in both modes) |
| 6. Emoji/color | Color outline/bitmap or an explicit documented limitation | **DONE 2026-09-12** (FT_LOAD_COLOR, BGRA→RGBA, fixed-strike selection; fixture tests skip without a host emoji font) |
| 7. Editing/IME | Editor render through shared `Renderer`; composition event model in ZUI | render + hit/motion/scroll/cursor DONE; TextField is still append-only with no selection/composition (IME model not started) |
| 8. Licensing/build | MIT/Apache-2.0 notices; `.ports/cozmic` in package paths; benches/deterministic fixtures | licensing + `check-bindings` + deterministic benches done (per-iteration arena OOM fixed; `--quick` mode); package move remains |

Evidence for gates 1-4 (fresh clone, no `.reference`, empty global cache):
`zig build test` → 9/9 steps, **351/351 tests** (module 298, exe 2, upstream 51
passed / 0 skipped). The mixed-Hebrew image baseline now matches after the
BiDi/line-break upgrade, so the documented `SkipZigTest` was removed. HB/FT are
resolved at runtime (generated dynamic bindings: **46 + 25 required symbols**;
`tools/gen_dyn_bindings.py --check` runs as `zig build check-bindings` in the
test graph). ezi-code is a URL+hash dependency pinned to `EZI_CODE_REV`, so no
reference checkout is needed to build.

Post-review hardening (2026-09-12, independent review of gates 1-4 and the
element wiring): failed lazy sources are skipped by the resolver instead of
poisoning shaping; only non-OOM failures are cached (Zig and FreeType OOM are
retryable in both the shaper and raster paths); mono metadata and platform-relative
scan dirs fixed; `hb_ft_*` are optional lazily resolved symbols so a HarfBuzz
without the FT bridge still shapes; loader errors are retained and no pointer
can outlive a closed library; a portable mutex guards first load; fontconfig
mapping helpers are total at `c_int` extremes and `FcFontSet` walks are bounded;
word motion/selection share the upstream alphanumeric rule; Editor
render/hit/motion/cursor all consume the real `Buffer` layout; packed fontconfig
named-instance indices are masked for HarfBuzz; a failed raster source is not
negatively cached so recovery is reachable; the ZUI engine decision is shared
per node (no measure/paint mix), `.w()` and caret semantics match legacy, and
synthetic bold is skipped when the shaped face already satisfies the weight.

Final default-engine evidence (2026-09-12): top-level `zig build test` (cozmic
default) → 13/13 steps, 290/290; `-Dtext-engine=legacy` → 13/13, 203/203;
`zig build selftest-todo` passes in both modes; cozmic package fresh-cache →
12/12 steps, 405/408 (3 fixture skips), `check-bindings` up to date, quick
bench runs.

Order of work: 1 → 2 → (3 and 4 can interleave) → 5 → 6/7 → 8.

## Bench determinism + quick mode (2026-09-12)

- **OOM root cause**: both benches allocated every timed iteration's `Buffer`
  and its layout state in the process-lifetime arena (`init.arena`). Arena
  `free` is a no-op, so a full layout run accumulated >3 GB/min; it reached
  ~6 GB RSS in ~80 s and would have been OOM-killed (it was stopped manually
  to protect the host). Iterations now use a dedicated `ArenaAllocator` over
  `page_allocator`, reset between iterations with
  `retain_with_limit(64 MiB)` (16 MiB for the load bench): RSS stays bounded
  and hot pages are reused inside the timed region.
- **Vendored fonts only**: `initFontSystem` registers the four vendored faces
  (Inter, Noto Sans Arabic, Noto Sans Hebrew, FiraMono) from `tests/fonts`
  with explicit family names and never calls `loadSystemFonts`. Run steps use
  `setCwd(package root)` so `tests/fonts` resolves regardless of the
  invocation cwd, and stay serialized so JSON rows cannot interleave.
- **`loadFontSystem` row**: now an empty `FontSystem` plus
  `FontSystem.loadFontsDir("tests/fonts")` (7 faces: walk + sfnt metadata
  parse + lazy shaper-source registration). Upstream's row still scans the
  host font set, so it is order-comparable only; documented in the bench and
  in `bench_compare.py`.
- **Optimize default**: benches build at `-Dbench-optimize` (default
  `ReleaseFast`) through a private second instantiation of the library graph
  (`createCozmicGraph`); `-Doptimize` is unchanged for the app and tests.
- **Quick mode**: `zig build bench -- --quick` (or `COZMIC_BENCH_QUICK=1`)
  uses 3 timed iterations / 1 warmup and still emits every row; explicit
  `--iter`/`--warmup` override it. `tools/bench_compare.py --quick` passes it
  through and uses a 1 s criterion measurement time.
- **Compare tool**: `--zig-bin` (passed automatically from
  `b.graph.zig_exe`) removes the PATH dependency on `zig`; stale
  system-font assumptions were replaced with the actual residual caveats.
- **Residual fairness caveats (documented, not papered over)**: upstream
  `new_with_fonts` still scans system fonts into its DB (so emoji rows can
  shape a host emoji font while zig has none), criterion reuses its last run
  unless re-run, and the timed spans differ (upstream times
  `set_text + shape_until_scroll` on a reused `Buffer`; zig times
  `shapeUntilScroll + layoutRuns` on a fresh `Buffer` per iteration).
- Measured on this host (4 vCPU, shared with concurrent test/compile jobs):
  full `zig build bench` completes in **214.9 s** with **~990 MiB peak tree
  RSS** (0.5 GB peak in the largest single process); a fully cached
  `zig build bench -- --quick` takes **15.5 s** at **147 MiB** peak RSS, and
  `zig build test` remains green (exit 0). `bench-compare -- --quick
  --no-rust` joins 38 connected / 19 cozmic-only / 0 upstream-only rows.
