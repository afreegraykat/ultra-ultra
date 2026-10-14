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

MEASURED_TABLES

Numbers come from `tests/run-all.sh` on the machine in `results/host.txt`. Re-run it and the table
regenerates from `results/`.

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
| Hermes Agent | commit `8a1a0cd4b0` (2026-10-11) |
| macOS | 27.0.1 |
| checkpoints | revisions in `results/host.txt` (from `bin/pin-revisions.sh`) |

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
- Hermes needs its own install; this recipe does not install Hermes for you.

## Credits

TensorFold (ashhart), Qwen, NVIDIA Nemotron, Nous Research (Hermes Agent). Pattern and test design
after Cruz (@ViC305). Measurements, scripts and integration: Aubrey Freeman.

MIT.
