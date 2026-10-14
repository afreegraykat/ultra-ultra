#!/usr/bin/env python3
"""Turn results/ into the README's measured tables (markdown on stdout)."""
import json, sys
from pathlib import Path

R = Path(sys.argv[1] if len(sys.argv) > 1 else "results")
rows = [json.loads(l) for l in (R / "bench.jsonl").read_text().splitlines() if l.strip()] if (R / "bench.jsonl").exists() else []
by = {r["tag"]: r for r in rows}

def g(tag, k, fmt="{:.1f}"):
    r = by.get(tag); v = r.get(k) if r else None
    return fmt.format(v) if isinstance(v, (int, float)) else "-"

print("### Decode, 7K-token prompts with 8 tool schemas, greedy\n")
print("| scenario | streams | per-stream tok/s | aggregate tok/s (end-to-end) | TTFT p50 s |")
print("|---|---|---|---|---|")
for tag, label in [("worker-c1-main-idle", "worker, main idle"), ("worker-c4-main-idle", "worker, main idle"), ("worker-c8-main-idle", "worker, main idle"),
                   ("main-solo-worker-idle", "main, worker idle"), ("main-WHILE-worker-c8", "main WHILE 8 workers run"), ("worker-c8-WHILE-main", "8 workers WHILE main runs")]:
    r = by.get(tag)
    if r: print(f"| {label} | {r['conc']} | {g(tag,'per_stream_decode_tps_mean')} | {g(tag,'aggregate_tps_e2e')} | {g(tag,'ttft_p50_s')} |")
mf = (R / "memory-floor.txt").read_text().strip() if (R / "memory-floor.txt").exists() else ""
if mf: print(f"\n{mf}\n")
print("### Hermes fan-out (one worker per file, sums scored against ground truth from each worker's own session)\n")
print("| tasks | workers correct | main's final correct | subagent sessions | cross-routed | wall s |")
print("|---|---|---|---|---|---|")
for n in (4, 8, 16):
    p = R / f"fanout-{n}.json"
    if p.exists():
        f = json.loads(p.read_text())
        print(f"| {n} | {f['workers_correct']}/{n} | {f['final_correct']}/{n} | {f['subagent_sessions']} | {f['cross_routed']} | {f['wall_s']} |")
for name in ("toolcall-main.txt", "toolcall-worker.txt"):
    if (R / name).exists(): print(f"\n```\n{(R / name).read_text().strip()}\n```")
