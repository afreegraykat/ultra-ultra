#!/usr/bin/env python3
"""Hermes fan-out test (the proof of the recipe).

Generates N data files with known sums, asks the MAIN agent (via `hermes chat -q` against
$ULTRA_HERMES_HOME) to delegate one worker per file, then scores:
  - each worker's own answer, read from the subagent session in state.db (not the main's summary);
  - the main's assembled answer;
  - routing: which server every session actually used (sessions.model + model_config), expecting
    main sessions on MAIN_NAME and every subagent session on WORKER_NAME, zero cross-routed.

Usage: tests/fanout.py N [--out results/fanout-N.json]
"""
import argparse, json, os, random, sqlite3, subprocess, sys, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def env():
    out = subprocess.run(["bash", "-c", f". {ROOT}/bin/env.sh; set | grep -E '^[A-Z_]+='"], capture_output=True, text=True).stdout
    return {k: v.strip("'") for k, v in (l.split("=", 1) for l in out.splitlines() if "=" in l)}

def make_files(n, d):
    d.mkdir(parents=True, exist_ok=True)
    truth = {}
    for i in range(n):
        vals = [random.randint(100, 9999) for _ in range(random.randint(40, 80))]
        p = d / f"ledger-{i:02d}.txt"
        p.write_text("\n".join(f"item{j:03d},{v}" for j, v in enumerate(vals)) + "\n")
        truth[str(p)] = sum(vals)
    return truth

def prompt(truth):
    lines = "\n".join(f"- {p}" for p in truth)
    return (f"There are {len(truth)} ledger files. Delegate ONE worker per file, all in a single delegate_task call "
            f"so they run in parallel. Each worker must: read its file with a tool, sum the second column of every "
            f"line with a tool (python), and reply with exactly one line `RESULT: <path> = <sum>`. Do not compute "
            f"anything yourself. When all workers return, output a final block with one line per file in the form "
            f"`FINAL: <path> = <sum>` and nothing else after it.\n\nFiles:\n{lines}")

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("n", type=int); ap.add_argument("--out"); ap.add_argument("--seed", type=int, default=7)
    a = ap.parse_args(); random.seed(a.seed)
    e = env(); H = Path(e["ULTRA_HERMES_HOME"]); main_name, worker_name = e["MAIN_NAME"], e["WORKER_NAME"]
    db = H / "state.db"
    work = ROOT / ".state" / f"fanout-{a.n}"; truth = make_files(a.n, work)
    before = set()
    if db.exists():
        before = {r[0] for r in sqlite3.connect(db).execute("select id from sessions")}
    t0 = time.time()
    r = subprocess.run(["hermes", "chat", "-q", prompt(truth)], env={**os.environ, "HERMES_HOME": str(H)},
                       capture_output=True, text=True, timeout=3600)
    wall = time.time() - t0
    text = r.stdout
    # main's assembled answer
    final = {}
    for line in text.splitlines():
        if "FINAL:" in line and "=" in line:
            k, v = line.split("FINAL:", 1)[1].split("=", 1)
            k = k.strip().strip("*`").strip(); v = v.strip().strip("*`").strip().replace(",", "")
            try: final[k] = int(v)
            except ValueError: pass
    # sessions created by this run
    con = sqlite3.connect(db)
    rows = con.execute("select id, source, model, parent_session_id, tool_call_count, message_count from sessions").fetchall()
    new = [x for x in rows if x[0] not in before]
    parents = [x for x in new if x[1] != "subagent"]; kids = [x for x in new if x[1] == "subagent"]
    # each worker's own answer from its last assistant message
    kid_results = {}
    for sid, *_ in kids:
        m = con.execute("select content from messages where session_id=? and role='assistant' and content like '%RESULT:%' order by id desc limit 1", (sid,)).fetchone()
        if m:
            for line in m[0].splitlines():
                if "RESULT:" in line and "=" in line:
                    k, v = line.split("RESULT:", 1)[1].split("=", 1)
                    k = k.strip().strip("*`").strip(); v = v.strip().strip("*`").strip().replace(",", "")
                    try: kid_results[k] = int(v)
                    except ValueError: pass
    kid_correct = sum(1 for p, s in truth.items() if kid_results.get(p) == s)
    final_correct = sum(1 for p, s in truth.items() if final.get(p) == s)
    cross = [x for x in kids if x[2] and main_name in x[2] and worker_name not in x[2]] + \
            [x for x in parents if x[2] and worker_name in x[2]]
    res = {"n": a.n, "wall_s": round(wall, 1), "exit": r.returncode,
           "workers_correct": kid_correct, "final_correct": final_correct,
           "parent_sessions": len(parents), "subagent_sessions": len(kids),
           "parent_models": sorted({x[2] for x in parents if x[2]}), "subagent_models": sorted({x[2] for x in kids if x[2]}),
           "cross_routed": len(cross), "worker_tool_calls": sum(x[4] or 0 for x in kids),
           "stderr_tail": r.stderr[-600:] if r.returncode else ""}
    print(json.dumps(res, indent=1))
    if a.out:
        Path(a.out).parent.mkdir(parents=True, exist_ok=True); Path(a.out).write_text(json.dumps(res, indent=1) + "\n")
    sys.exit(0 if (kid_correct == a.n and final_correct == a.n and not cross) else 1)

if __name__ == "__main__":
    main()
