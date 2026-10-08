#!/usr/bin/env python3
"""Run already-built companions serially; record medians, RSS and sizes."""
from pathlib import Path
import json, re, statistics, subprocess
ROOT = Path(__file__).resolve().parent.parent
zig = max((ROOT / '.zig-cache/o').glob('*/audit-matched'), key=lambda p:p.stat().st_mtime)
rust = ROOT / '.reference/cosmic-text/target/release/cozmic-audit'
rows=[]
for trial in range(3):
    for engine,binary,cwd in [('cozmic',zig,ROOT),('cosmic-text',rust,rust.parents[2])]:
        run=subprocess.run(['/usr/bin/time','-v',str(binary)],cwd=cwd,text=True,capture_output=True,check=True)
        body=run.stdout+run.stderr
        (ROOT/f'audit/evidence/matched-{engine}-{trial}.log').write_text(body)
        rss=int(re.search(r'Maximum resident set size \(kbytes\): (\d+)',body)[1])
        for name,ns,glyphs,width in re.findall(r'MATCHED (\w+) median_ns=(\d+) glyphs=(\d+) width_sum=([\d.]+)',body):
            rows.append(dict(engine=engine,trial=trial,workload=name,median_ns=int(ns),glyphs=int(glyphs),width_sum=float(width),rss_kib=rss))
summary=[]
for name in ['small','latin','arabic']:
    pair={engine:[r for r in rows if r['engine']==engine and r['workload']==name] for engine in ['cozmic','cosmic-text']}
    for engine in pair:
        if len(pair[engine])!=3: raise RuntimeError('Missing results')
    if {r['glyphs'] for r in pair['cozmic']}!={r['glyphs'] for r in pair['cosmic-text']}: raise RuntimeError('Glyph mismatch')
    if {r['width_sum'] for r in pair['cozmic']}!={r['width_sum'] for r in pair['cosmic-text']}: raise RuntimeError('Width mismatch')
    z=statistics.median(r['median_ns'] for r in pair['cozmic']); r=statistics.median(r['median_ns'] for r in pair['cosmic-text'])
    summary.append(dict(workload=name,cozmic_ns=z,cosmic_ns=r,ratio=z/r,glyphs=pair['cozmic'][0]['glyphs'],width_sum=pair['cozmic'][0]['width_sum']))
result=dict(rows=rows,summary=summary,binaries={e:dict(path=str(p.relative_to(ROOT)),bytes=p.stat().st_size) for e,p in [('cozmic',zig),('cosmic-text',rust)]})
(ROOT/'audit/evidence/matched-summary.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(summary,indent=2))
