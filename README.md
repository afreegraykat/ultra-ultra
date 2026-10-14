# ultra-ultra: two models, one M5 Ultra

One frontier-class main agent and a pool of eight concurrent worker subagents, both resident on a
single Mac Studio M5 Ultra, served by one TensorFold 1.0.x native binary, orchestrated by Hermes Agent.

| role | model | checkpoint | context | concurrency |
|---|---|---|---|---|
| main agent | Qwen3.8 Flash Next | `TensorFold/Qwen3.8-Flash-Next-MLX-6bit-MTP` (6-bit, g32, MTP drafts) | 262,144 | 1 active reply |
| worker pool | Nemotron 3.5 Lightning 30B-A3B | `TensorFold/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-MLX-4bit` | 131,072 per stream | 8 shared-round streams |

Both stay loaded. No swapping, no cloud endpoint, no second machine. Hermes routes every
`delegate_task` child to the worker server and keeps the conversation on the main one.

This is the Apple-silicon counterpart of [Cruz's "Two models, one Spark"](https://github.com/vcruz305/TWOMODELS-ONESPARK-Qwen3.8-Flash-Next-and-MiniCPM-V-4.7-EXL3)
recipe for the DGX Spark. Same shape, different engine, twice the memory: 256 GB lets the main model
run at 6-bit instead of 3 bpw, and nothing has to stream from disk.

## Measured

Run on Apple M5 Ultra, 256 GB, macOS 27.0.1, 2026-10-14, by `tests/run-all.sh` after a cold `bin/up.sh` on a machine running nothing else. Raw data in `results/`. Free RAM never dropped below 40 GiB in any test, including 64K prompts on both servers at once.

```
host: Apple M5 Ultra, 256 GB, macOS 27.0.1
tensorfold: tensorfold-native 1.0.11
hermes: Hermes Agent v0.22.0+119.g0e427d7
main: TensorFold/Qwen3.8-Flash-Next-MLX-6bit-MTP @ 45032a19  ctx=262144
worker: TensorFold/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-MLX-4bit @ d9d758fb  ctx=131072 parallel=8
date: 2026-10-14T13:54:47Z
```

### Decode, 7K-token prompts with 8 tool schemas, greedy

| scenario | streams | per-stream tok/s | aggregate tok/s (end-to-end) | TTFT p50 s |
|---|---|---|---|---|
| worker, main idle | 1 | 388.2 | 191.8 | 0.8 |
| worker, main idle | 4 | 102.0 | 231.9 | 2.2 |
| worker, main idle | 8 | 54.3 | 246.4 | 3.8 |
| main, worker idle | 1 | 122.2 | 56.7 | 3.8 |
| main WHILE 8 workers run | 1 | 66.3 | 48.1 | 2.3 |
| 8 workers WHILE main runs | 8 | 52.6 | 179.8 | 7.1 |

free RAM after both-busy: 44 GiB

### Long context (needle retrieval, greedy, thinking off)

| scenario | prompt tokens | found | TTFT s |
|---|---|---|---|
| worker-128k-main-idle | 128582 | yes | 26.8 |
| main-128k-worker-idle | 104472 | yes | 43.2 |
| main-64k-WHILE-worker-64k | 51913 | yes | 18.7 |
| worker-64k-WHILE-main-64k | 63909 | yes | 23.0 |

### Hermes fan-out (one worker per file, sums scored against ground truth from each worker's own session)

| tasks | workers correct | main's final correct | subagent sessions | cross-routed | wall s |
|---|---|---|---|---|---|
| 4 | 4/4 | 4/4 | 4 | 0 | 70.3 |
| 8 | 8/8 | 8/8 | 8 | 0 | 68.9 |
| 16 | 16/16 | 16/16 | 16 | 0 | 304.4 |

```
whole  main     finish=tool_calls call={'name': 'list_dir', 'arguments': '{"path":"/tmp"}'} -> ok
stream main     finish=tool_calls call={'name': 'list_dir', 'arguments': '{"path":"/tmp"}'} -> ok
```

```
whole  worker   finish=tool_calls call={'name': 'list_dir', 'arguments': '{"path":"/tmp"}'} -> ok
stream worker   finish=tool_calls call={'name': 'list_dir', 'arguments': '{"path":"/tmp"}'} -> ok
```

## Hardware

Measured on: Mac Studio M5 Ultra, 256 GB unified memory, macOS 27.0.1. The main model alone needs
~150 GiB resident; `bin/up.sh` reads the machine's RAM and refuses a load that would not leave
`MIN_FREE_GIB` free. See `docs/memory.md` for the memory budget and what to change on other configs.

## Install

```sh
git clone https://github.com/afreegraykat/ultra-ultra && cd ultra-ultra
bin/setup.sh        # TensorFold 1.0.11 native, sha256-verified, into ~/.local/share/tensorfold
bin/download.sh     # both checkpoints, ~165 GB, resumable
bin/up.sh           # worker then main, memory-gated; bin/status.sh shows both
hermes/install.sh   # self-contained Hermes profile in ~/.hermes-ultra (needs `hermes` on PATH)
```

Then:

```sh
export HERMES_HOME=~/.hermes-ultra
hermes chat -q "Delegate three workers to each compute 17*23 with a tool and reply RESULT: <n>."
```

`bin/down.sh` stops both. `bin/guard.sh &` watches free memory and stops the stack before macOS
starves. Every knob is in `bin/env.sh`; put overrides in `bin/env.local.sh` (gitignored).

## Verify

```sh
tests/run-all.sh    # tool-calling contract, solo/concurrent decode, both-busy, Hermes fan-out 4/8/16
```

The fan-out test writes N ledger files with known sums, asks the main agent to delegate one worker
per file, and scores each worker's own answer from its session in `state.db`, not from the main's
summary. It also audits routing: every subagent session must be on the worker model, every parent on
the main model, zero cross-routed.

## Pinned versions

| component | version |
|---|---|
| TensorFold | 1.0.11 native (macOS arm64 release archive) |
| Hermes Agent | upstream main commit `0e427d788d` (2026-10-14) |
| macOS | 27.0.1 |
| main checkpoint | `TensorFold/Qwen3.8-Flash-Next-MLX-6bit-MTP` @ `45032a193a5d4126ba8534822cbaf8fb30b3e368` |
| worker checkpoint | `TensorFold/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-MLX-4bit` @ `d9d758fb83953437f7263256b0d96157e2a348b8` |

## Why these choices

- **TensorFold 1.0.x native, not the Python 0.6.x engine.** One binary, no venv, `brew install`
  or a 4 MB archive. 1.0.11 qualifies Flash Next on M5 Ultra specifically and gives Nemotron
  shared-round concurrency with per-stream drafts. The Python engine is frozen at 0.6.6.
- **Nemotron as the worker, not Qwen3.6 or MiniCPM-V.** Qwen3.6 is still being ported to 1.0.x,
  and MiniCPM-V 4.7 has no Mac engine. Nemotron is the 1.0.x model with the most concurrency work
  behind it. The Qwen3.6-35B-A3B worker on the 0.6.6 Python engine is the measured fallback in
  `docs/fallback-0.6.6.md`.
- **Greedy on the main model.** 1.0.x Flash Next refuses a request with a non-zero temperature
  (HTTP 400); the Hermes profile sets temperature 0 for that provider.
- **One active reply on the main server.** 1.0.11 serves Flash Next one request at a time; a second
  concurrent request queues. Fine for a single conversation, which is what the main agent is for.
  Shared rounds for Flash Next are on TensorFold's 1.0.x roadmap.

## Known limits

- Main-model prompt cache is capped by TensorFold's 70%-of-RAM rule: 5.7 GiB on 256 GB with the
  6-bit checkpoint. `MAIN_PROMPT_CACHE_GIB` plus `--prompt-cache-over-cap` in `MAIN_EXTRA_ARGS` lifts
  it; read `docs/memory.md` before you do.
- Workers are text-only. Vision workers wait on a Mac engine for a vision model.
- Hermes needs its own install; this recipe does not install Hermes for you. The install used here:
  `curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --hermes-home ~/.hermes-ultra --commit 0e427d788d --non-interactive --skip-browser --skip-computer-use`
  then `HERMES_HOME=~/.hermes-ultra hermes pm repair` if it reports no committed dependency environment.
- The 16-task run is slower per task than 8 because Hermes caps concurrent children at 8
  (`delegation.max_concurrent_children`); the second eight queue. Memory, not the cap, is the real limit: raise it in
  `hermes/config.yaml` and `WORKER_PARALLEL` together.

## Running it as a lane

`overlay/` is one operator's production wiring: a LaunchDaemon, a hold file, the memory guard, and a
port/name mapping that keeps existing clients unchanged. Not needed to use the recipe; there as an example.

## Credits

TensorFold (ashhart), Qwen, NVIDIA Nemotron, Nous Research (Hermes Agent). Pattern and test design
after Cruz (@ViC305). Measurements, scripts and integration: Aubrey Freeman.

MIT.
