# Benchmarks

All benches load only the vendored corpus in `tests/fonts` (Inter, Noto Sans
Arabic, Noto Sans Hebrew, FiraMono) with explicit family names; they never
touch system fonts, so every row is reproducible. They are compiled at
`-Dbench-optimize` (default `ReleaseFast`) independently of `-Doptimize`,
which still controls the app and tests.

## Running

```sh
zig build bench                      # full run, human-readable
zig build bench -- --quick           # smoke run: iters=3 warmup=1
COZMIC_BENCH_QUICK=1 zig build bench # same via environment
zig build bench -- --format json     # one JSON row per line
zig build bench -- --iter 10 --warmup 2
zig build bench-matched              # Zig half of the matched comparison
zig build bench-memory               # heap use per phase
zig build bench-compare              # cozmic vs cosmic-text criterion join
```

## Matched comparison (the like-for-like number)

`benches/matched.zig` and `benches/upstream/matched_probe.rs` do identical
work: a fresh `Buffer` per iteration, word wrap at 80px, the Inter face, run
cache off, 5 discarded warmups and 100 timed iterations. `tools/bench_matched.py`
runs both serially three times and **fails unless glyph counts and advance-width
sums are identical** across engines, so the ratios compare equal output.

Latest run: 2026-10-08, Linux x86-64, Ryzen 5 5625U, Zig 0.17.0, bundled
HarfBuzz 14.1.0 / FreeType 2.14.3, cosmic-text `f1a3461` (0.19.0), median of
three trials:

| Workload | Glyphs | cozmic | cosmic-text | Ratio |
|---|---:|---:|---:|---:|
| `Hello, world!` | 13 | 10.7 µs | 16.8 µs | 0.64x |
| Latin paragraph ×100 | 4,201 | 3.06 ms | 4.40 ms | 0.70x |
| Arabic phrase ×100 | 1,334 | 1.59 ms | 1.83 ms | 0.87x |

## Memory

Peak process RSS on the matched run: cozmic 5.3 MiB, cosmic-text 5.3 MiB.
Of cozmic's, 1.3 MiB is heap; cosmic-text's heap is 1.7 MiB.

What keeps it small:

- **Bundled, trimmed C libraries.** A system HarfBuzz/FreeType drags in glib,
  pcre2, graphite2, brotli, libpng and zlib images (about 4.5 MiB of mappings
  in the old runtime-loaded build, 8.3 MiB peak RSS). The bundled build links
  only the HarfBuzz/FreeType code cozmic calls.
- **Memory-mapped fonts, shared.** Font files are mapped read-only and not
  prefaulted (`src/font_blob.zig`): only touched tables become resident,
  pages are shared with other processes and reclaimable. The shaper and the
  rasterizer hold the same refcounted blob instead of a heap copy each.
- **Metadata scanning maps instead of reading.** Registering a directory
  parses each file's header tables through a temporary mapping, so peak heap
  during registration is 5 KiB instead of the largest font file.

`zig build bench-memory` reports cozmic's own heap (counting allocator) on
the matched workload:

| Phase | Live | Peak |
|---|---:|---:|
| `tests/fonts` registered (7 faces, lazy) | 3 KiB | 5 KiB |
| Latin ×100 shaped + laid out | 942 KiB | 942 KiB |
| Arabic ×100 shaped + laid out | 414 KiB | 942 KiB |

The laid-out heap is dominated by per-glyph records (88-byte shaped glyph +
80-byte layout glyph), which match upstream's Rust structs field for field.

To reproduce, see the build steps at the top of `tools/bench_matched.py`.

## Criterion join (`bench-compare`)

`tools/bench_compare.py` joins `zig build bench -- --format json` rows with
cosmic-text's criterion results. Apply `benches/upstream/fairness.patch` to the
`.reference/cosmic-text` checkout first so its benches use the same vendored
faces. Harness spans differ (upstream times `set_text` + shape on a reused
`Buffer`; cozmic times shape + `layoutRuns` on a fresh one), and upstream's
`FontSystem::new_with_fonts` still scans host fonts, so treat those ratios as
directional. The `loadFontSystem` row is not comparable across hosts at all.

## Parity rows vs warm run-cache rows

Standard rows **disable** the shaped-run cache so they compare like-for-like
with cosmic-text, whose `shape-run-cache` feature is default-off. Rows
suffixed `(run-cache warm)` enable it: the warmup pass fills the cache and the
timed iterations measure steady state — what an editor or frame loop pays
after the first render (typically 2–4x faster than cold).

The cache is **enabled by default for library consumers**. It lives on the
shaper backend, persists across buffers and frames, and lets the advanced path
skip shaping whenever the same run recurs; hits reproduce every glyph field
byte-for-byte (enforced by the image/wrap suites). The key covers run text,
direction, default attrs and every non-default span (including
`font_features`, `color_opt`, `letter_spacing_opt`). It is bounded by both a
16,384-entry cap and a 64 MiB retained-byte budget with LRU eviction; font
registration and raster-producer changes clear it.
`FontSystem.setRunCacheEnabled` / `clearRunCache` let tools flip semantics.

## Binary size

`zig build -Doptimize=ReleaseSmall` produces a 1.55 MB stripped `cozmic` demo
(the full Buffer pipeline, ezi-code Unicode tables and bundled HarfBuzz) whose
only shared-library dependency is libc. HarfBuzz accounts for about 0.78 MB of
it; libc++ for 8 KB, since only headers are used. The equivalent stripped
cosmic-text release probe is 1.69 MB.

A program that also rasterizes links FreeType: at most 0.40 MB (the
ReleaseSmall archive's total code), plus at most 0.14 MB for zlib + libpng
unless built with `-Dcolor-bitmaps=false`. A `-Dsystem-libs`
build is smaller on disk but loads about 2.2 MB of HarfBuzz/FreeType plus their
transitive dependencies at runtime.
