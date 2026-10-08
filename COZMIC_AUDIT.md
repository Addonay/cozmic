# Cozmic vs cosmic-text: code, behavior, performance and safety audit

Audit date: 2026-10-03. Cozmic baseline: `b03e0c7342f2f8612385926f5f4d20a6e64e02b8`. Upstream reviewed: `f1a3461f3e8df67d2bbcfafb8bc61dc7aee5b2a6`, authored 2026-09-30, fetched from `origin/main` during this audit. Local environment: Linux x86-64, AMD Ryzen 5 5625U, Zig 0.17.0, Rust 1.98.1. This is an audit and evidence addition, not a production bug-fix change.

## Judgment

**Cozmic is a substantial, unusually broad Zig text engine, but I would not claim it is definitively the most versatile Zig engine or fully on par with cosmic-text yet.** Its connected Buffer/Editor pipeline covers real shaping, bidirectional layout, wrapping, ellipsization, styled text, hit testing, selection, editing and real glyph outlines. This is much more than a font-rendering demo. The source and tests justify describing it as a serious cosmic-text-derived implementation.

The stronger parity claim fails on eight reproducible defects found here, especially ignored OpenType settings, text-dependent fallback poisoning, color-glyph corruption and stale caches. Optional Vi and syntax surfaces also do not provide upstream functionality. Similar public method names and green existing tests are insufficient evidence of behavioral parity.

A limited current landscape check found [tchayen/zig-text-rendering](https://github.com/tchayen/zig-text-rendering), which describes FreeType rendering with HarfBuzz shaping, and [zgui](https://github.com/zig-gamedev/zgui), which is a Zig package/binding for ImGui. Those are different scopes, and do not establish an exhaustive ranking. I did not build or audit every competing Zig library, native toolkit wrapper, unpublished engine or Mach text implementation. My defensible assessment is **one of the most comprehensive standalone Zig text-engine implementations I have inspected**, with a plausible breadth advantage over simple shaping/rendering libraries; an absolute “most comprehensive” remains unproven.

Performance is competitive in a small matched test. Neither globally faster, safer, smaller nor equally mature follows from that result. The safety trade is explicit Zig ownership plus native C backends versus Rust ownership plus the upstream Rust font stack.

## Revision control and scope

The first `git pull --ff-only` could not resolve GitHub inside the restricted environment. An authorized network retry fetched successfully but exposed a detached reference HEAD. `git pull --ff-only origin main` then fast-forwarded it to the revision above. Existing modifications in both Rust benchmark files were preserved, with a backup in [audit/upstream-bench-existing.patch](audit/upstream-bench-existing.patch).

`git diff daae9c7 HEAD -- src` is empty. The update changes policy/workflow files and advances `fontdb` from 0.23 to 0.24, rather than changing cosmic-text's own engine source. Tests and Rust measurements here use the updated dependency graph, not merely the old pinned binary. The immutable `tools/pin.env` pin remains unchanged; the live reference is now newer than that pin.

Coverage: public API exports, attribute ownership, Buffer/BufferLine caches and dirty flags, shaping and the HarfBuzz seam, fallback resolution and memoization, font matching/loading/parser paths, FreeType raster/outline adapters, image cache and legacy rendering, editing mutation paths, Unicode delegation, optional editors, build and benchmark tooling, and upstream equivalents. Focused execution covers the eight witnesses below and three matched layout workloads. This is a broad targeted review, **not an exhaustive proof over every line, platform, allocator failure or Unicode sequence**. I did not perform GUI integration, IME interaction, long-duration fuzzing, sanitizer analysis of C libraries, or Windows/macOS runtime testing.

A user-side change to `build.zig.zon` appeared during the audit (minimum Zig version changed to 0.17.0); it was preserved. No production engine source was changed.

## What differs from cosmic-text

| Area | Cozmic | Latest cosmic-text | Assessment |
|---|---|---|---|
| Language/ownership | Zig, explicit allocators, fallible allocation, manual deinit and borrowed slices | Rust lifetimes, borrowing, owned collections | Different safety guarantees, not cosmetic translation |
| Production shaping | Runtime-loaded HarfBuzz C library | `harfrust` 0.5 | Both real shapers; backend differences require output oracles |
| Raster and outlines | Runtime-loaded FreeType, owned image snapshots, real outline decomposition | Optional `swash` rendering/scaling | Real implementation, with verified callback packing bug |
| Font metadata/discovery | Local sfnt parser, runtime fontconfig or directory scanning, lazy sources | `fontdb` 0.24 plus `skrifa` | Cozmic owns more matching/parser/discovery maintenance |
| Unicode | Pinned ezi-code tables and algorithms behind `unicode.zig` | unicode-bidi, segmentation, script and linebreak crates | Unicode versions and malformed-input policy may differ |
| Run cache | Enabled by default; linear entry search; advertised capacity | Default-off feature; hash map; age trimming | Cozmic default changes correctness and cost; bound is defective |
| Main layout API | Canonical top-level types, allocator/error returns, renderer vtable | Rust exports and methods, borrowed wrapper | Broad conceptual parity, not drop-in compatibility |
| Editor | Real main Buffer integration, grapheme-aware operations and change recording | Main Editor plus integrated optional editors | Main editor substantial; error guarantees need hardening |
| Vi | Separate local editor/parser/undo model; `vi_enabled=false` | ViEditor wrapping SyntaxEditor with modit/undo dependencies | Not equivalent |
| Syntax highlighting | Hash/state simulation, separate local editor; `syntect_enabled=false` | Real syntect grammars/themes/highlighting | Not real highlighting parity |
| Deployment | Requires suitable native libraries for production rendering/shaping | Rust shaping/raster stack; fontconfig feature selectable | Runtime dependency packaging remains a Cozmic obligation |
| Platform breadth | Platform branches and source scans exist | no_std/wasm and other feature paths exposed upstream | This audit validates Linux only |

The old assessment that Cozmic had an empty public font system and only synthetic advances no longer describes this checkout. `BufferLine` reaches real shaping; the fixtures and end-to-end tests exercise HarfBuzz and FreeType. Some comments still describe disconnected “wiring points” and need updating.

## Reproducible defects, ordered by impact

All eight are captured in [tests/audit_findings.zig](tests/audit_findings.zig). Run `zig build audit`. These are **diagnostic witnesses that pass when the current defect is observed**, deliberately separate from conformance tests. Fixes should turn the observations into assertions of desired behavior.

### 1. P1 — fallback negative memo poisons unrelated text

Locations: `src/shape_hb.zig` (`FallbackMemoKey`, `memoMaybeMarkUncovered`, `memoFallbackFor`); `src/shape.zig` fallback loop.

The memo key includes family/style/weight/stretch/script, but not the actual characters that failed. Exhausting candidates for one unsupported character sets `uncovered` for that entire key. A later word in the same script is consequently treated as unsupported without scanning the fonts that would render it.

Reproduction: with the vendored fonts and family Inter, shape Arabic U+10EC2, then “مرحبا”, with the run cache disabled to isolate fallback. The later word has **five missing glyphs**. Clear `fallback_memo`, repeat the word: **zero missing glyphs**. This is observable through the public Buffer pipeline, not just a synthetic adapter.

Fix: remove script-wide negative coverage caching, or key negatives by exact run/codepoint coverage plus a font database generation. A script is not a coverage set. Positive preferred-font hints can remain advisory, with normal scans after a miss. Add an oracle regression for unsupported text followed by supported text in the same script and varied order.

### 2. P1 — requested OpenType features never reach HarfBuzz

Locations: `src/shape.zig:shapeFallback`, `src/shape_hb.zig:shapeRunImpl`; compare upstream `src/shape.rs:shape_fallback`.

Attributes own/compare feature settings and cache keys distinguish them. The real shape call is nevertheless `hb.shape(entry.font.?, self.buffer, null)`, so every request uses default features. The adapter interface also does not pass those feature settings. Claims that features “fold into the backend” are not implemented.

Reproduction: Inter at 20px, “AVATAR”, cache disabled. Cozmic default kerning and `kern=0` both produce width **73.693184**. Latest upstream produces **73.693184** and **79.71591** respectively, using the same fixture font. The unchanged Cozmic result is not a font lacking kerning.

Fix: extend the shaping request with effective run features, convert tags/values to HarfBuzz features and apply them with the correct run ranges. Split incompatible feature spans before shaping. Validate `kern`, ligature controls, contextual alternates and stylistic sets with real fonts. Include feature values in any actual shape-plan key.

### 3. P1 — color glyphs have wrong channel and alpha packing

Locations: `src/swash_cache.zig:rgba`, `.withPixels(.color)`; `src/render.zig:LegacyRenderer`; canonical `src/attrs.zig:Color`.

`attrs.Color` uses `0xAARRGGBB`. The local cache `rgba` packs `0xRRGGBBAA`; the legacy renderer wraps that u32 directly as canonical Color. Mask callbacks use the canonical alpha-high layout, so the callback ABI is internally inconsistent.

Reproduction: cached RGBA pixel `(10,20,30,255)` is emitted as `0x0a141eff`. The real consumer interprets it as **r=20, g=30, b=255, a=10**, rather than the opaque intended color. Existing local tests compare against the same faulty local helper and therefore pass.

Fix: use the canonical Color packing/conversion for both mask and color callbacks. Keep raw RGBA byte storage separate from packed callback color. Assert component values at the LegacyRenderer boundary, and vendor a color font fixture so the full real path is deterministic.

### 4. P1 — allocation failure leaves changed text with a valid old shape

Locations: `src/buffer_line.zig:append`, `setText`; related destructive mutation order in `src/edit.zig:insertAt/deleteRange`.

`append` writes text and ending before fallible attribute work, and invalidates shaping only at the end. If attribute allocation fails, it returns OutOfMemory after text has changed but with the old shape cache still marked used.

Reproduction with a FailingAllocator: shape line “a”, append differently styled “b”, fail the next attribute allocation after reserving text capacity. The call returns OutOfMemory, line text is **“ab”**, and `shapeOpt()!=null` still reports the old shape as valid. The normal suite did not expose this failure path.

Fix: prepare text and attribute changes before committing, or invalidate caches before the first destructive mutation and document a basic rather than transactional guarantee. Editor operations should reserve/prepare their new lines and undo records before removing text. Audit `setText` similarly: it clears/copies text before attributes and reset. Partial edits and missing undo records after failure are source-identified risks; not every editor failure point was executed here.

### 5. P1/P2 — replacing a font retains old shaped runs

Locations: `src/shape_hb.zig:insertEntry`, `src/font_system.zig:addFontData/addFontSource`, `src/shape.zig:shapeRunCached`.

Replacing a registered id clears fallback memoization but not the run cache. Cached glyph ids, metrics and advances belong to the previous font. The run cache key contains no font-registry generation.

Reproduction: shape “WWW” with Inter under id 1, replace id 1 with FiraMono. The old and cached first advance are **0.9488636 em**; a fresh shape is **0.6 em**. Consumers can therefore draw the new font with the old font's glyph ids and positions.

Fix: invalidate the run cache on every font-registry change, or version it. Invalidate dependent match/support caches on database mutation. Define whether existing Buffer shapes and raster caches must be explicitly refreshed or automatically see the generation. Test font addition too: it can make previously missing fallback coverage available.

### 6. P2 — changing raster backend retains stale outlines

Location: `src/swash_cache.zig:setRaster`.

Backend changes clear only `image_cache`; the outline cache is explicitly left unchanged despite also depending on the producer. This became more consequential when real outline production landed in the latest Cozmic commit.

Reproduction: cache the synthetic adapter's one-command outline, attach an empty real raster and ask for the same key. Cached outline is still the synthetic one; uncached outline is null. Real-to-real replacement and cached negative outlines have the same invalidation requirement.

Fix: clear both caches on producer changes. Add font/raster generation to cache ownership or keys for same-pointer registry updates. Provide explicit image/outline invalidation APIs with documented borrowed-slice lifetimes.

### 7. P2 — advertised 16,384-run capacity is not enforced

Locations: `src/shape.zig:run_cache_max/shapeRunCached`; `src/shape_run_cache.zig:trim/findIndex`.

`trim(8192)` interprets 8192 as an age window, not an entry target. During the first burst, all entries have age zero, so they all survive. Calling trim after each insertion beyond the threshold does not halve the working set. Frequently accessed entries can remain beyond the target. There is no byte budget; a single run can be arbitrarily large within the text API's practical limits.

Reproduction using the exact production insertion/trim policy: **17,000 distinct keys leave 17,000 entries**, contradicting the advertised bound. The “single-digit MB worst case” comment is not a supported bound.

Fix: enforce both count and byte budgets; use an indexed hash cache plus an explicit eviction policy. Age can be an eviction input, not a capacity substitute. Linear lookup/insertion plus ordered removal makes large-cache churn expensive, potentially quadratic over a document. Test >16k unique runs, long runs, repeated hits and churn; measure bytes and latency percentiles.

### 8. P2 — run cache ignores shaping direction

Locations: `src/shape.zig:shapeRunCached`, `src/shape_run_cache.zig:KeyRef`.

The function accepts `span_rtl`, but the key omits it. Reusing the same run/attrs with another direction returns the first direction's shaped output.

Reproduction at the exported shaping seam: cache “abc” LTR, request RTL, compare fresh RTL. Cached first cluster starts at **0**; fresh RTL starts at **2**. This proves the cache contract defect. It does not by itself demonstrate every high-level Buffer direction change failing: script-level bidi resolution can keep a Latin subrun LTR even in an RTL paragraph.

Upstream's optional `ShapeRunKey` also omits direction, so this is an inherited audit concern for that default-off feature, not a proven upstream default-path failure. Cozmic enables its analogous cache by default, widening exposure.

Fix: include direction and all other effective shaping inputs (font generation, variation state and explicit language/script if exposed). Keep upstream-shaped relative offsets, and add cache-on/cache-off differential tests for neutral and mixed-direction runs.

## Additional code-review concerns and feature gaps

**Fallback policy is simplified in the connected path.** `ShaperResolver.fallbackFor` discards `script` and enumerates the sorted global match list. The richer `fallback.zig:FontFallbackIter` and script/locale family policies are not wired into this resolver. Upstream uses its fallback iterator. Thus broad glyph coverage can work while choices differ, especially CJK locale preferences, monospace preservation and emoji ordering. Connect the intended policy rather than counting the existence of fallback tables as integrated parity.

**Native tab preprocessing is missing at the shaping seam.** Upstream substitutes spaces for tabs before shaping, preserving byte locations. `shapeFallback` passes the original run; `shapeRunImpl` passes it directly to HarfBuzz. The synthetic adapter maps tabs to spaces, so stand-in tab tests cannot establish the real behavior. Fix tab rewriting and test advanced, non-ASCII text with tabs against upstream; verify glyph id, space-based tab advance, cluster offsets and decoration ranges. This is a source-confirmed wiring gap; a dedicated real-tab differential case was not executed here.

**The explicit PlanCache is bookkeeping, not an actual HarfBuzz plan cache.** Entries record font/script/direction; the returned index is discarded and the backend calls `hb_shape`. HarfBuzz may cache plans internally, so this does not establish that every call recreates a plan. It does establish that the local six-entry FIFO does not implement the claimed plan-execution mechanism. Remove the redundant bookkeeping or connect actual plan handles with complete keys, justified by measurement.

**System variable fonts have less metadata than vendored ones.** The fontconfig registration path documents that it does not expose the variable-weight range. The parser-based path fills `fvar`; a passing InterVariable fixture does not prove production fontconfig matching at every requested weight. Read authoritative axis metadata lazily, refresh matching, and test a real discovery-to-shaping path. Named instances and axes besides `wght` need explicit scope and oracle tests.

**Metadata parser containment:** `nameData` validates records against the whole blob rather than the declared name-table slice. A malformed record can read another table's bytes as a name without being out of memory bounds. Preserve table-local limits. Several offset additions are usize arithmetic; 32-bit overflow behavior was not verified. Fuzz table boundaries, collections, truncated names and huge offsets. This review found no demonstrated arbitrary-memory-read exploit; do not confuse semantic parsing flaws with proven memory unsafety.

**Metrics input policy is incomplete.** Buffer construction checks zero line height; `setMetrics` checks zero sizes but not all negative/non-finite values. Define and validate finite positive metrics, finite optional dimensions and legal scroll input at public boundaries. Do not advertise total/no-panic behavior solely because most adapters return errors.

**Ownership and concurrency:** adapters borrow movable Backend/FontSystem addresses; layout runs borrow cache slices; FreeType faces borrow libraries/bytes; rendered bitmaps borrow mutable glyph slots. These contracts are documented but not enforced by the type system. One backend's shared buffer/weight/cache cannot be concurrently shaped. Lazy-read locks are separate in shaping and raster modules while both use `global_single_threaded.io()`: cross-subsystem concurrent reads merit a race test or one shared lock/injected Io. This is a potential race from source review, not a reproduced data race.

**Deployment portability:** dynamic loading removes a link-time development-package requirement, not the runtime HarfBuzz/FreeType requirement. Missing-symbol diagnostics are coarse, failure is process-cached, and ABI checks compare to generated declarations rather than executing on every target ABI. Add actual Windows/macOS and missing-library/minimum-version tests. no_std/wasm support is not established by this audit.

**Editor scale:** arrays of lines and contiguous strings have shifting/copy costs. Large-document/long-line typing, paste, deletion, undo and viewport scrolling need dedicated workloads; this audit's shaping timing does not measure typing latency. A rope/piece table should be added only if measured latency warrants its complexity.

**Full typography/GUI stack:** there is no established vertical-text engine, hyphenation service, font stretching/optical-size UI contract, rich paragraph style system, Pango-style strong/weak caret pair API or composition transaction model here. These are potential additions with product-specific value, not all defects or promises made by cosmic-text. OS IME, clipboard, accessibility and window/render-device handling belong in integration layers; the text engine should provide composition ranges, replacement transactions and reliable geometry, not own those OS services.

## Tests and evidence strength

| Run | Result | What it supports |
|---|---|---|
| Cozmic `zig build test` Debug | 414 passed / 417 total; 3 skipped | Current suite and allocation leak checks on exercised paths |
| Cozmic ReleaseSafe suite | Same 414/417, 3 skipped | Optimized execution retaining safety checks |
| Cozmic audit witnesses | 8/8 pass | Eight observed defects remain present |
| cosmic-text default `cargo test --lib --tests` | 42 pass, 0 failed | Current upstream default unit/integration suites |
| cosmic-text `--features vi` | 49 pass, 0 failed | Includes seven editor-modified-state tests gated by Vi |
| Binding drift check | HarfBuzz 46 required symbols; FreeType 26; up to date | Generator/source synchronization, not independent target ABI proof |

Detailed logs are in [audit/evidence](audit/evidence). Cozmic image suites compare ink proximity (typically radius one, with allowed strays) rather than exact FreeType-versus-swash pixel equality. Those are useful structural rendering checks, but weaker evidence for color, alpha, subpixel quality, every glyph position and cache-state parity. Existing tests comparing faulty helper against itself explain why the color bug escaped.

Three tests were skipped; the source includes host-dependent color-font coverage paths, and the current vendored corpus has no color font to make those paths reproducible on every machine. Test counts are not equivalent units across engines: Cozmic includes port tests, stand-ins, adapters, Unicode checks and independent experimental editor tests. More tests do not imply greater maturity. Pinned ezi-code's internal correctness is also not independently established by comparing Cozmic wrappers to that same dependency.

## Performance

### Existing benchmark harness: exploratory only

Fresh Cozmic run: 83 JSON rows, 10 iterations, 2 warmups, ReleaseFast. Fresh Rust Criterion layout and shaping runs: 1s measurement target, 0.2s warmup, normal sample settings. The joined table is [audit/benchmark-comparison.md](audit/benchmark-comparison.md).

Representative advanced Word rows:

| Workload | Cozmic mean | cosmic-text mean | Cozmic/upstream |
|---|---:|---:|---:|
| Hello world | 12.04 µs | 17.77 µs | 0.68 |
| Moby excerpt | 10.55 ms | 13.88 ms | 0.76 |
| Arabic corpus | 0.711 ms | 1.331 ms | 0.53 |
| Hebrew corpus | 0.597 ms | 0.694 ms | 0.86 |
| Emoji corpus | 320.25 ms | 365.64 ms | 0.88 |

These ratios **are not fair claims of overall speed advantage**. Zig times shaping plus run enumeration after setText on a fresh Buffer; Rust times clearing/setting text plus shaping on a reused Buffer. Allocator strategies differ. Rust's patched `new_with_fonts` still scans system fonts, while Zig uses only vendored faces. Missing-glyph/fallback and font order can differ. The emoji corpus does not have a matching vendored emoji font, so that row is not evidence of correct colored emoji rendering. Some collection overlapped compilation/tests, particularly Rust shaping measurements; treat those results as exploratory observations.

The very large apparent mixed-paragraph speedup is explained in part by different work: Rust's non-ASCII `BidiParagraphs` constructs full `BidiInfo`, while Zig's iterator directly detects separators. It does not mean Zig's full bidi layout is 80–100 times faster. `loadFontSystem` is also deliberately incomparable (host font scan versus fixture registration). The join script reads prior Criterion data even after failure and only returns the last Rust subprocess status; a first-bench failure could be hidden. Harden freshness/commit/features metadata and aggregate both statuses.

Warm Cozmic cache rows show useful repeat-content savings (e.g. Word Arabic about 0.145 ms vs 0.711 ms, Moby 5.52 ms vs 10.55 ms). They are a different mode from upstream default-off caching and run against a currently defective cache. Retain this optimization after correcting its key, invalidation and eviction semantics; do not discard it merely because bugs exist.

### Matched workload test

New companion programs are [audit/matched_bench.zig](audit/matched_bench.zig) and [audit/upstream_probe.rs](audit/upstream_probe.rs). Both use only the vendored font directory, explicit Inter family, 10px metrics, 80px width, Word wrapping, Advanced shaping, no shaped-run cache, a fresh buffer each iteration, text set before the timer, shaping plus glyph enumeration inside it, and buffer destruction after it. Five warmups and 100 measured samples. Glyph counts and advance sums are compared as a basic output equivalence check, not complete glyph/cluster/layout equivalence.

Three serial runs per engine (alternating engine order), each with the warmup/sample counts above. Table reports the median of each program's three per-run medians. Final Cozmic companion uses `std.heap.c_allocator` for FontSystem and Buffers; Rust uses its normal system allocator. No test/build processes were intentionally run concurrently with these final measurements.

| Workload | Cozmic median | cosmic-text median | Ratio | Glyphs | Sum of advances |
|---|---:|---:|---:|---:|---:|
| small | 12.61 µs | 16.79 µs | 0.751 | 13 | 58.536934 |
| latin | 3559.43 µs | 4310.65 µs | 0.826 | 4201 | 20876.428 |
| arabic | 1819.35 µs | 1841.89 µs | 0.988 | 1334 | 4934.8843 |

Cozmic took about 25% less time for the short Latin case, 17% less for the repeated Latin paragraph, and essentially the same time for this Arabic case. Equal glyph counts and advance sums support comparison on these particular workloads, but do not prove equal glyph ids, caret positions or every line boundary. Three samples of sample medians do not give a rigorous confidence interval; there is no basis here for a universal speed ranking.

Whole-process peak RSS from `/usr/bin/time -v`: Cozmic **9,044–9,468 KiB** (median 9,232), upstream **5,156–5,412 KiB** (median 5,412). This includes font loading, native libraries, allocator retention and both timed/untimed work; it is not live heap usage or a memory-leak diagnosis. An earlier identical Cozmic workload using `smp_allocator` instead peaked at **57,232 KiB** (saved separately), demonstrating how much allocator retention can change consumer footprint. An arena-backed FontSystem also retained temporary allocations; that exploratory configuration is excluded from the final figures.

Stripped companion executable sizes: Cozmic **1,261,632 bytes**, upstream **1,685,448 bytes**. These are specific shaping-only consumer programs, not matched complete render/editor distributions. Cozmic also loads external HarfBuzz (host file 1,311,280 bytes); a complete FreeType-backed renderer additionally needs FreeType (910,200 bytes) and their dependencies. These external bytes prevent interpreting the smaller Cozmic executable as a smaller total deployed text stack. Unstripped Zig executables include debug information and are much larger, so unstripped filesize is not a useful language comparison.

Measurements and all six logs are in [audit/evidence/matched-summary.json](audit/evidence/matched-summary.json). Build both companions, then run `python3 audit/run_matched.py` to repeat the serial collection.

## Smallness and safety

Source footprint, recursively counted before new audit helpers (comments, tests and generated bindings included):

| Set | Files | Lines | Bytes |
|---|---:|---:|---:|
| Cozmic `src/**/*.zig` | 57 | 54,475 | 2,512,566 |
| Cozmic top-level core files | 32 | 34,110 | 1,377,858 |
| cosmic-text `src/**/*.rs` | 27 | 12,379 | 443,340 |

The total source ratio is about 4.4× in lines and 5.7× in bytes. Cozmic owns generated bindings, extra adapters/parser/discovery code and many inline tests. Upstream delegates equivalent work to crates and has external integration tests. These numbers describe repository maintenance volume, **not deployed memory or binary cost**. Excluding Vi and syntax removes 4,002 top-level lines, but does not address most binding/adapter volume. Zig dead-code elimination means unused source does not all ship.

Rust's normal API statically prevents many alias/lifetime mistakes that Zig documents but leaves to the caller. Cozmic can return allocation errors explicitly and gives useful allocator control; those benefits require consistent recovery guarantees, which the failing-append witness disproves for one path. ReleaseSafe helps detect bounds/overflow mistakes. ReleaseFast removes many checks; successful ReleaseSafe tests are not a proof of arbitrary-input safety in ReleaseFast. Native libraries add their own parser/FFI attack surface and version obligations. Neither engine is established here as suitable for hostile-font sandboxing without isolation/fuzzing.

Both share upstream limitations: swash pixel callbacks ignore base alpha and skip SubpixelMask; Rust also retains panic-capable assertions/indexing and age-based optional caching. Cozmic should make deliberate compatibility decisions rather than copying every upstream TODO. For example, multiplying glyph coverage by requested alpha is a useful improvement, but changes upstream pixel behavior and should be versioned/documented.

## What to add, remove and keep

**Add first:** fallback text-order oracle tests; end-to-end OpenType feature tests; canonical callback color checks; font and raster generation invalidation; cache-on/off direction/fallback differentials; deterministic color font fixtures; allocator-failure tests over BufferLine and Editor with invariant checks; real-tab tests. These close observed failures, not speculative scope.

**Add next:** complete connected script/locale fallback policy; lazy variable-axis metadata; minimum backend/version diagnostics; per-cache byte telemetry and limits; Linux/Windows/macOS runtime CI; real Unicode conformance files independent of the implementation; randomized glyph/cluster/run/caret comparison to pinned upstream over a multilingual corpus. Extend the corpus to Indic, Thai, Khmer, CJK, combining marks, variation selectors and emoji ZWJ sequences. Shape/render these with matching fonts and compare glyph ids, cluster spans, positions, line counts, selection and cursor geometry separately from raster ink tolerances.

**Remove or move out of the supported engine:** template `add`, `printAnotherMessage`, template executable and ArrayList fuzz example (they do not fuzz the text engine); stale wiring-point comments; simulated syntax highlighter and duplicated Vi/syntax editor types from any production-parity claim. Keep experimental code in a clearly separate package/example if it remains useful, or replace it with real modules built on canonical Editor/Buffer. The root already feature-gates them and their readiness flags are false, which is good; the repository should be equally explicit about capability.

**Remove or redesign after verification:** the unused explicit shape-plan bookkeeping; redundant representations such as cache-local packed Color; public synthetic-renderer defaults that make a missing production backend look visually successful. Stand-ins remain valuable test doubles and should not be deleted from tests. Audit the placeholder `FontSystem.getFont` cache, which returns id/weight metadata rather than a real loaded font, before advertising upstream font-object equivalence.

**Keep:** canonical main type ownership, real HarfBuzz/FreeType adapter seams, source-registration/lazy loading, pinned Unicode dependency, vendored fonts, binding drift gates, error cleanup already present in image-cache insertion, grapheme-aware editing, independent renderer output, structural image oracles and run caching once corrected. Do not replace working shaping with a homegrown shaper merely to achieve “pure Zig.”

Suggested acceptance order: fix the eight defects and add real-tab/features/color oracles; integrate fallback policy and variable metadata; lock down allocator failure and platform contracts; then optimize caches/document editing using reproducible latency/memory measurements. Only after broad cache-on/off and upstream differential runs should the project advertise near-parity. “Fully on par” additionally needs an explicit supported-feature matrix, including an honest exclusion or implementation of Vi, syntax, deployment targets and optional upstream features.

## Review notes on upstream cosmic-text itself

Upstream is the stronger compatibility baseline, not an infallible oracle. These observations come from the current Rust checkout:

- `src/shape_run_cache.rs` also leaves direction out of the key. Add direction/font-generation coverage to the feature-enabled suite; the Cozmic witness establishes the general failure mode but is not a direct upstream reproduction.
- `src/bidi_para.rs` selects an ASCII fast path permitting carriage returns, but splits only on LF. Therefore `a\rb` is one paragraph there, while the non-ASCII full BidiInfo path treats CR as a paragraph boundary. Cozmic explicitly fixes this in its ASCII iterator. This is a source-confirmed input-dependent semantic inconsistency in upstream, and should get a small regression test before changing behavior.
- The same iterator computes full `BidiInfo` for non-ASCII even though its public output is only paragraph text. Separating paragraph detection from full embedding analysis can avoid repeated work; Cozmic shows a direct separator scan, but conformance on every B-class/control case needs checking before adopting it.
- `src/swash.rs:with_pixels` has explicit TODOs for base alpha and subpixel masks. A transparent text color can still emit coverage-alpha mask callbacks. Decide whether callbacks intentionally represent coverage independently of text opacity or should multiply alpha; document it and test translucent output. Cozmic inherits the mask-alpha behavior in addition to its independent color-packing defect.
- `src/shape.rs` has pending work concerning whitespace linebreakability, color participating in shaping, ellipsis styling and justified whitespace. These are worthwhile focused follow-ups; the TODOs alone do not prove failures for particular inputs. Keep linebreakability driven by Unicode break properties, separate layout/paint-only styling from expensive shaper keys when semantics permit, and validate ellipsis decorations/attributes on rich bidi text.
- The default suite does not exercise optional Vi modified-state tests unless Vi is enabled. This audit ran that feature and all seven additional tests passed. Similarly, the optional run cache deserves an explicit feature-enabled differential suite. Default-feature success should not be presented as coverage of every feature combination.
- Strong Rust ownership does not eliminate panics for invalid metrics or indexing assumptions, nor bound all cache memory. Document preconditions, fuzz font/text boundaries and measure cache footprint. Do not replace those qualifications with a blanket “Rust is safe” claim.

These are recommendations and review findings; no upstream submission or upstream production-source edits were made.
