cozmic vs cosmic-text — mean time per iteration (lower is better)

NOTE: both engines shape the same vendored faces (Inter, Noto
Sans Arabic/Hebrew, FiraMono) and the same sample texts; the
cosmic-text layout/shaping benches are patched under .reference/
to use them. That patch calls FontSystem::new_with_fonts, which
still scans host system fonts into the DB, and criterion reuses
its previous run unless re-run, so upstream numbers are
host-dependent while the zig rows are reproducible.
Harness spans differ: upstream times set_text + shape on a reused
Buffer; zig times shape + layoutRuns on a fresh Buffer per
iteration. Ratios are directional, not like-for-like.
loadFontSystem: zig builds an empty FontSystem and registers
tests/fonts only; upstream FontSystem::new() scans the host, so
that row is not directly comparable.

CONNECTED — 38 matched workloads

| cozmic bench                        | cozmic mean | upstream bench                                   | upstream mean | ratio | glyphs |
| ----------------------------------- | ----------- | ------------------------------------------------ | ------------- | ----- | ------ |
| layout/small/Wrap(none, simple)     | 4.34 µs     | Wrap(None, Simple) / small amount of text        | 5.96 µs       | 0.73x | 13     |
| layout/small/Wrap(none, advanced)   | 12.53 µs    | Wrap(None, Advanced) / small amount of text      | 17.34 µs      | 0.72x | 13     |
| layout/small/Wrap(glyph, simple)    | 4.04 µs     | Wrap(Glyph, Simple) / small amount of text       | 5.82 µs       | 0.69x | 13     |
| layout/small/Wrap(glyph, advanced)  | 12.04 µs    | Wrap(Glyph, Advanced) / small amount of text     | 17.58 µs      | 0.68x | 13     |
| layout/small/Wrap(word, simple)     | 4.01 µs     | Wrap(Word, Simple) / small amount of text        | 6.20 µs       | 0.65x | 13     |
| layout/small/Wrap(word, advanced)   | 12.04 µs    | Wrap(Word, Advanced) / small amount of text      | 17.77 µs      | 0.68x | 13     |
| layout/moby/Wrap(none, simple)      | 3.31 ms     | Wrap(None, Simple) / large amount of text        | 6.01 ms       | 0.55x | 12174  |
| layout/moby/Wrap(none, advanced)    | 10.45 ms    | Wrap(None, Advanced) / large amount of text      | 13.98 ms      | 0.75x | 12174  |
| layout/moby/Wrap(glyph, simple)     | 3.43 ms     | Wrap(Glyph, Simple) / large amount of text       | 6.08 ms       | 0.56x | 12174  |
| layout/moby/Wrap(glyph, advanced)   | 10.59 ms    | Wrap(Glyph, Advanced) / large amount of text     | 14.28 ms      | 0.74x | 12174  |
| layout/moby/Wrap(word, simple)      | 3.44 ms     | Wrap(Word, Simple) / large amount of text        | 6.23 ms       | 0.55x | 11440  |
| layout/moby/Wrap(word, advanced)    | 10.55 ms    | Wrap(Word, Advanced) / large amount of text      | 13.88 ms      | 0.76x | 11446  |
| layout/arabic/Wrap(none, simple)    | 176.26 µs   | Wrap(None, Simple) / arabic text                 | 238.74 µs     | 0.74x | 480    |
| layout/arabic/Wrap(none, advanced)  | 686.51 µs   | Wrap(None, Advanced) / arabic text               | 1.33 ms       | 0.52x | 476    |
| layout/arabic/Wrap(glyph, simple)   | 178.46 µs   | Wrap(Glyph, Simple) / arabic text                | 249.42 µs     | 0.72x | 480    |
| layout/arabic/Wrap(glyph, advanced) | 718.30 µs   | Wrap(Glyph, Advanced) / arabic text              | 1.36 ms       | 0.53x | 476    |
| layout/arabic/Wrap(word, simple)    | 178.82 µs   | Wrap(Word, Simple) / arabic text                 | 253.65 µs     | 0.70x | 422    |
| layout/arabic/Wrap(word, advanced)  | 710.56 µs   | Wrap(Word, Advanced) / arabic text               | 1.33 ms       | 0.53x | 451    |
| layout/hebrew/Wrap(none, simple)    | 169.94 µs   | Wrap(None, Simple) / hebrew text                 | 275.49 µs     | 0.62x | 567    |
| layout/hebrew/Wrap(none, advanced)  | 593.31 µs   | Wrap(None, Advanced) / hebrew text               | 677.56 µs     | 0.88x | 567    |
| layout/hebrew/Wrap(glyph, simple)   | 180.05 µs   | Wrap(Glyph, Simple) / hebrew text                | 291.47 µs     | 0.62x | 567    |
| layout/hebrew/Wrap(glyph, advanced) | 595.57 µs   | Wrap(Glyph, Advanced) / hebrew text              | 695.39 µs     | 0.86x | 567    |
| layout/hebrew/Wrap(word, simple)    | 178.29 µs   | Wrap(Word, Simple) / hebrew text                 | 286.23 µs     | 0.62x | 516    |
| layout/hebrew/Wrap(word, advanced)  | 596.54 µs   | Wrap(Word, Advanced) / hebrew text               | 693.58 µs     | 0.86x | 533    |
| layout/emoji/Wrap(none, simple)     | 108.56 ms   | Wrap(None, Simple) / emoji text                  | 125.35 ms     | 0.87x | 334088 |
| layout/emoji/Wrap(none, advanced)   | 304.87 ms   | Wrap(None, Advanced) / emoji text                | 340.18 ms     | 0.90x | 334088 |
| layout/emoji/Wrap(glyph, simple)    | 111.39 ms   | Wrap(Glyph, Simple) / emoji text                 | 139.67 ms     | 0.80x | 334088 |
| layout/emoji/Wrap(glyph, advanced)  | 319.84 ms   | Wrap(Glyph, Advanced) / emoji text               | 357.51 ms     | 0.89x | 334088 |
| layout/emoji/Wrap(word, simple)     | 110.98 ms   | Wrap(Word, Simple) / emoji text                  | 136.57 ms     | 0.81x | 318083 |
| layout/emoji/Wrap(word, advanced)   | 320.25 ms   | Wrap(Word, Advanced) / emoji text                | 365.64 ms     | 0.88x | 318549 |
| shaping/ascii-fast-path             | 1.89 ms     | ShapeLine_ASCII Fast Path                        | 6.28 ms       | 0.30x | 2800   |
| shaping/bidi-mixed                  | 2.96 ms     | ShapeLine_BiDi Processing                        | 7.96 ms       | 0.37x | 3510   |
| shaping/hello-mixed                 | 12.77 ms    | bench_lang_mixed / ShapeLine_Mixed-Language Text | 111.58 ms     | 0.11x | 11620  |
| shaping/layout-heavy                | 3.60 ms     | ShapeLine_Layout Heavy                           | 7.68 ms       | 0.47x | 4972   |
| shaping/combined-stress             | 20.76 ms    | ShapeLine_Combined Stress                        | 55.97 ms      | 0.37x | 27700  |
| shaping/bidi-paras-ascii            | 4.33 µs     | BidiParagraphs_ASCII                             | 14.85 µs      | 0.29x | 100    |
| shaping/bidi-paras-mixed            | 2.47 µs     | BidiParagraphs_Mixed                             | 218.77 µs     | 0.01x | 60     |
| loadFontSystem                      | 594.97 µs   | load FontSystem                                  | 25.00 ms      | 0.02x |        |

COZMIC-ONLY — 45 benches without an upstream counterpart

| cozmic bench                                                     | mean      | glyphs | note                                                      |
| ---------------------------------------------------------------- | --------- | ------ | --------------------------------------------------------- |
| layout/small/Wrap(none, advanced, run-cache warm)                | 3.24 µs   | 13     | no upstream bench at this width                           |
| layout/small/Wrap(glyph, advanced, run-cache warm)               | 3.08 µs   | 13     | no upstream bench at this width                           |
| layout/small/Wrap(word, advanced, run-cache warm)                | 3.10 µs   | 13     | no upstream bench at this width                           |
| layout/small/Wrap(word_or_glyph, advanced, run-cache warm)       | 3.16 µs   | 13     | no upstream bench row (Wrap::WordOrGlyph exists upstream) |
| layout/small/Wrap(word_or_glyph, simple)                         | 4.01 µs   | 13     | no upstream bench row (Wrap::WordOrGlyph exists upstream) |
| layout/small/Wrap(word_or_glyph, advanced)                       | 12.05 µs  | 13     | no upstream bench row (Wrap::WordOrGlyph exists upstream) |
| layout/moby/Wrap(none, advanced, run-cache warm)                 | 5.39 ms   | 12174  | no upstream bench at this width                           |
| layout/moby/Wrap(glyph, advanced, run-cache warm)                | 5.57 ms   | 12174  | no upstream bench at this width                           |
| layout/moby/Wrap(word, advanced, run-cache warm)                 | 5.52 ms   | 11446  | no upstream bench at this width                           |
| layout/moby/Wrap(word_or_glyph, advanced, run-cache warm)        | 5.52 ms   | 11449  | no upstream bench row (Wrap::WordOrGlyph exists upstream) |
| layout/moby/Wrap(word_or_glyph, simple)                          | 3.41 ms   | 11443  | no upstream bench row (Wrap::WordOrGlyph exists upstream) |
| layout/moby/Wrap(word_or_glyph, advanced)                        | 10.66 ms  | 11449  | no upstream bench row (Wrap::WordOrGlyph exists upstream) |
| layout/arabic/Wrap(none, advanced, run-cache warm)               | 139.39 µs | 476    | no upstream bench at this width                           |
| layout/arabic/Wrap(glyph, advanced, run-cache warm)              | 144.89 µs | 476    | no upstream bench at this width                           |
| layout/arabic/Wrap(word, advanced, run-cache warm)               | 144.67 µs | 451    | no upstream bench at this width                           |
| layout/arabic/Wrap(word_or_glyph, advanced, run-cache warm)      | 144.23 µs | 451    | no upstream bench row (Wrap::WordOrGlyph exists upstream) |
| layout/arabic/Wrap(word_or_glyph, simple)                        | 178.80 µs | 427    | no upstream bench row (Wrap::WordOrGlyph exists upstream) |
| layout/arabic/Wrap(word_or_glyph, advanced)                      | 696.66 µs | 451    | no upstream bench row (Wrap::WordOrGlyph exists upstream) |
| layout/hebrew/Wrap(none, advanced, run-cache warm)               | 145.48 µs | 567    | no upstream bench at this width                           |
| layout/hebrew/Wrap(glyph, advanced, run-cache warm)              | 154.02 µs | 567    | no upstream bench at this width                           |
| layout/hebrew/Wrap(word, advanced, run-cache warm)               | 151.49 µs | 533    | no upstream bench at this width                           |
| layout/hebrew/Wrap(word_or_glyph, advanced, run-cache warm)      | 151.59 µs | 533    | no upstream bench row (Wrap::WordOrGlyph exists upstream) |
| layout/hebrew/Wrap(word_or_glyph, simple)                        | 179.50 µs | 523    | no upstream bench row (Wrap::WordOrGlyph exists upstream) |
| layout/hebrew/Wrap(word_or_glyph, advanced)                      | 591.28 µs | 533    | no upstream bench row (Wrap::WordOrGlyph exists upstream) |
| layout/emoji/Wrap(word_or_glyph, simple)                         | 118.05 ms | 321903 | no upstream bench row (Wrap::WordOrGlyph exists upstream) |
| layout/emoji/Wrap(word_or_glyph, advanced)                       | 324.27 ms | 322314 | no upstream bench row (Wrap::WordOrGlyph exists upstream) |
| layout/hello_mixed/Wrap(none, advanced, run-cache warm)          | 7.12 ms   | 11682  | upstream hello.txt bench is shaping-only                  |
| layout/hello_mixed/Wrap(none, simple)                            | 3.63 ms   | 11697  | upstream hello.txt bench is shaping-only                  |
| layout/hello_mixed/Wrap(none, advanced)                          | 13.18 ms  | 11682  | upstream hello.txt bench is shaping-only                  |
| layout/hello_mixed/Wrap(glyph, advanced, run-cache warm)         | 9.64 ms   | 11682  | upstream hello.txt bench is shaping-only                  |
| layout/hello_mixed/Wrap(glyph, simple)                           | 3.83 ms   | 11697  | upstream hello.txt bench is shaping-only                  |
| layout/hello_mixed/Wrap(glyph, advanced)                         | 15.01 ms  | 11682  | upstream hello.txt bench is shaping-only                  |
| layout/hello_mixed/Wrap(word, advanced, run-cache warm)          | 7.24 ms   | 11012  | upstream hello.txt bench is shaping-only                  |
| layout/hello_mixed/Wrap(word, simple)                            | 3.82 ms   | 11017  | upstream hello.txt bench is shaping-only                  |
| layout/hello_mixed/Wrap(word, advanced)                          | 13.48 ms  | 11012  | upstream hello.txt bench is shaping-only                  |
| layout/hello_mixed/Wrap(word_or_glyph, advanced, run-cache warm) | 7.06 ms   | 11019  | no upstream bench row (Wrap::WordOrGlyph exists upstream) |
| layout/hello_mixed/Wrap(word_or_glyph, simple)                   | 3.81 ms   | 11010  | no upstream bench row (Wrap::WordOrGlyph exists upstream) |
| layout/hello_mixed/Wrap(word_or_glyph, advanced)                 | 13.07 ms  | 11019  | no upstream bench row (Wrap::WordOrGlyph exists upstream) |
| shaping/arabic                                                   | 775.87 µs | 471    | nearest upstream row is the layout bench                  |
| shaping/arabic (run-cache warm)                                  | 146.48 µs | 471    | no upstream bench at this width                           |
| shaping/ascii-fast-path (run-cache warm)                         | 457.80 µs | 2800   | no upstream bench at this width                           |
| shaping/bidi-mixed (run-cache warm)                              | 657.51 µs | 3510   | no upstream bench at this width                           |
| shaping/combined-stress (run-cache warm)                         | 4.47 ms   | 27700  | no upstream bench at this width                           |
| shaping/hello-mixed (run-cache warm)                             | 7.96 ms   | 11620  | no upstream bench at this width                           |
| shaping/layout-heavy (run-cache warm)                            | 740.49 µs | 4972   | no upstream bench at this width                           |

UPSTREAM-ONLY — 0 benches not covered by cozmic yet

(none)
