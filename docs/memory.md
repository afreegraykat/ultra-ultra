# Memory budget

All numbers measured on a 256 GB M5 Ultra with the pinned checkpoints.

| component | footprint |
|---|---|
| main, Flash Next 6-bit, 262K context, 5.7 GiB prompt cache | ~184 GiB physical footprint after load (`/memory` on the main port) |
| worker, Nemotron 30B-A3B 4-bit, 8 x 131K, 8 GiB prompt cache | ~20-25 GiB |
| free+inactive with both loaded, idle | ~55 GiB |
| free+inactive with main + 8 workers all decoding | ~50 GiB |

## The 70% rule

TensorFold refuses to let one server hold more than 70% of RAM (179 GiB on 256 GB) unless you pass
`--prompt-cache-over-cap`. With the 6-bit main model (171.5 GiB loaded) that leaves 5.7 GiB for kept
prompt states. It is a safety rule: macOS wires model memory, and a Mac that wires most of its RAM
stalls until the watchdog reboots it. The recipe keeps the default.

If you raise `MAIN_PROMPT_CACHE_GIB` with `MAIN_EXTRA_ARGS="--prompt-cache-over-cap"`, the worker
and everything else on the machine come out of what is left. Keep `bin/guard.sh` running.

## Other M5 Ultra configurations

- **512 GB**: the 70% cap is ~358 GiB, so the main model gets ~150 GiB of prompt cache by default and
  the worker can go to 8-bit or more streams. Nothing in the recipe needs to change.
- **192 GB or less**: the 6-bit main model does not fit beside a worker. Options, untested here:
  `TensorFold/Qwen3.8-Flash-Next-MLX-oQ3-MTP` or `-oQ2-MTP` (1.0.10 serves mixed-width Flash Next
  checkpoints on Macs), or a smaller main model from TensorFold's qualified table.

## Contexts

`MAIN_CONTEXT` and `WORKER_CONTEXT` are prompt-plus-reply windows. Worker KV is per stream; 8 streams
at 131K is the measured default. Lower `WORKER_CONTEXT` before lowering `WORKER_PARALLEL`.
