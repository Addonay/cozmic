# Cozmic audit evidence — 2026-10-03

Read [COZMIC_AUDIT.md](../COZMIC_AUDIT.md) for conclusions and limitations.

- `zig build audit`: eight diagnostic witnesses which assert the **current defects**, not desired behavior. A passing witness confirms the reported defect. These are deliberately separate from `zig build test`.
- `zig build audit-bench`: matched layout workloads, cache disabled, optimized build, five discarded warmups and 100 measured iterations.
- Rust companion: copy `upstream_probe.rs` to `.reference/cosmic-text/src/bin/cozmic-audit.rs`, then run `cargo run --offline --release --bin cozmic-audit` from that checkout. The companion loads `../../tests/fonts` and therefore expects this checkout location.
- `evidence/`: logs from the actual runs, including original benchmark JSON. `matched-summary.json` and six `matched-*-N.log` files contain the final serial timings and process RSS. `python3 audit/run_matched.py` recollects them after building both companions.
- `upstream-bench-existing.patch`: benchmark modifications already present before the audit. They survived the upstream fast-forward.
- `benchmark-comparison.md`: existing harness join, with unequal work boundaries; exploratory results only. Read the limitations in the report before interpreting ratios.

This audit updated the reference from `daae9c75d52322f8fb3af6168d76561540914e1f` to `f1a3461f3e8df67d2bbcfafb8bc61dc7aee5b2a6`. The immutable pin in `tools/pin.env` is intentionally unchanged: the reference-fetch script still targets the original revision. Restore/re-pin deliberately if using that script later.

Reviewed source entry points:

| Finding | Source |
|---|---|
| Fallback poisoning | [memoization](../src/shape_hb.zig), [fallback loop](../src/shape.zig) |
| OpenType feature gap | [native shaper](../src/shape_hb.zig), [run attributes](../src/shape.zig) |
| Color packing | [raster callbacks](../src/swash_cache.zig), [canonical Color](../src/attrs.zig), [legacy renderer](../src/render.zig) |
| Allocation recovery | [BufferLine mutations](../src/buffer_line.zig), [editor mutations](../src/edit.zig) |
| Font replacement | [backend registry](../src/shape_hb.zig), [FontSystem](../src/font_system.zig) |
| Outline invalidation | [SwashCache](../src/swash_cache.zig) |
| Cache bounds/direction | [run call](../src/shape.zig), [cache key/storage](../src/shape_run_cache.zig) |
| Metadata containment | [sfnt metadata parser](../src/font_parse.zig) |
| Experimental editors | [Vi](../src/vi.zig), [syntax simulation](../src/syntect.zig) |
