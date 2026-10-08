#!/usr/bin/env python3
"""Matched cozmic vs cosmic-text cold-layout benchmark.

Both companions shape the same texts with the same vendored Inter face,
word wrap at 80px, run cache off: 5 discarded warmups + 100 timed iterations,
reporting the median. Glyph counts and advance-width sums must be identical
across engines or the run fails, so the timings compare equal work.

Build first:
    zig build bench-matched            # builds + runs the Zig companion once
    cp benches/upstream/matched_probe.rs \
       .reference/cosmic-text/src/bin/cozmic-matched.rs
    (cd .reference/cosmic-text && cargo build --release --bin cozmic-matched)

Then run (serial, three trials each):
    python3 tools/bench_matched.py

Writes zig-out/bench-matched.json (per-trial medians, peak RSS, binary sizes).
"""
from pathlib import Path
import json, re, statistics, subprocess

ROOT = Path(__file__).resolve().parent.parent
TRIALS = 3
WORKLOADS = ['small', 'latin', 'arabic']


def main():
    zig = max((ROOT / '.zig-cache/o').glob('*/bench-matched'), key=lambda p: p.stat().st_mtime)
    rust = ROOT / '.reference/cosmic-text/target/release/cozmic-matched'
    if not rust.exists():
        raise SystemExit(f'missing {rust}; see the build steps in this file')
    rows = []
    for trial in range(TRIALS):
        for engine, binary, cwd in [('cozmic', zig, ROOT), ('cosmic-text', rust, rust.parents[2])]:
            run = subprocess.run(['/usr/bin/time', '-v', str(binary)], cwd=cwd, text=True,
                                 capture_output=True, check=True)
            body = run.stdout + run.stderr
            rss = int(re.search(r'Maximum resident set size \(kbytes\): (\d+)', body)[1])
            for name, ns, glyphs, width in re.findall(
                    r'MATCHED (\w+) median_ns=(\d+) glyphs=(\d+) width_sum=([\d.]+)', body):
                rows.append(dict(engine=engine, trial=trial, workload=name, median_ns=int(ns),
                                 glyphs=int(glyphs), width_sum=float(width), rss_kib=rss))
    summary = []
    for name in WORKLOADS:
        pair = {e: [r for r in rows if r['engine'] == e and r['workload'] == name]
                for e in ['cozmic', 'cosmic-text']}
        for e, got in pair.items():
            if len(got) != TRIALS:
                raise RuntimeError(f'{e}/{name}: missing results')
        for key in ['glyphs', 'width_sum']:
            if {r[key] for r in pair['cozmic']} != {r[key] for r in pair['cosmic-text']}:
                raise RuntimeError(f'{name}: {key} differs between engines')
        z = statistics.median(r['median_ns'] for r in pair['cozmic'])
        c = statistics.median(r['median_ns'] for r in pair['cosmic-text'])
        summary.append(dict(workload=name, cozmic_ns=z, cosmic_ns=c, ratio=round(z / c, 3),
                            glyphs=pair['cozmic'][0]['glyphs']))
    rss = {e: max(r['rss_kib'] for r in rows if r['engine'] == e) for e in ['cozmic', 'cosmic-text']}
    result = dict(summary=summary, peak_rss_kib=rss, rows=rows,
                  binaries={e: p.stat().st_size for e, p in [('cozmic', zig), ('cosmic-text', rust)]})
    out = ROOT / 'zig-out/bench-matched.json'
    out.parent.mkdir(exist_ok=True)
    out.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(dict(summary=summary, peak_rss_kib=rss), indent=2))


if __name__ == '__main__':
    main()
