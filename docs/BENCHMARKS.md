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
zig build bench-compare              # cozmic vs cosmic-text criterion join
```

## Matched comparison (the like-for-like number)

`benches/matched.zig` and `benches/upstream/matched_probe.rs` do identical
work: a fresh `Buffer` per iteration, word wrap at 80px, the Inter face, run
cache off, 5 discarded warmups and 100 timed iterations. `tools/bench_matched.py`
runs both serially three times and **fails unless glyph counts and advance-width
sums are identical** across engines, so the ratios compare equal output.

Latest run — 2026-10-08, Linux x86-64, Ryzen 5 5625U, Zig 0.17.0,
cosmic-text `f1a3461` (0.19.0), median of three trials:

| Workload | Glyphs | cozmic | cosmic-text | Ratio |
|---|---:|---:|---:|---:|
| `Hello, world!` | 13 | 12.5 µs | 16.5 µs | 0.76x |
| Latin paragraph ×100 | 4,201 | 3.81 ms | 4.39 ms | 0.87x |
| Arabic phrase ×100 | 1,334 | 1.87 ms | 1.83 ms | 1.02x |

Peak RSS: cozmic 8.2 MiB, cosmic-text 5.3 MiB. Cozmic's figure includes the
dynamically loaded HarfBuzz and FreeType images.

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

`zig build -Doptimize=ReleaseSmall` produces a 756 KB `cozmic` demo executable
(full Buffer pipeline plus ezi-code Unicode tables; the largest single item is
the 160 KB derived-core-properties table). A stripped `ReleaseFast` build is
1.27 MB. The equivalent stripped cosmic-text release probe is 1.69 MB, but it
statically contains a pure-Rust shaper, while cozmic loads the system
`libharfbuzz` (~1.3 MB) and `libfreetype` (~0.9 MB) at runtime.
