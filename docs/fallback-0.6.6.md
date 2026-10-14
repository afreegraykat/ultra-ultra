# Fallback: Python engine 0.6.6 with a Qwen3.6 worker

Before 1.0.x qualified enough models, this pair was measured on the same machine. Kept here because
it is a working, slower alternative if you need a Qwen-family worker today.

| role | model | engine |
|---|---|---|
| main | `TensorFold/Qwen3.8-Flash-Next-MLX-oQ6-MTP` (262K, thinking on) | TensorFold 0.6.0 Python |
| worker | `TensorFold/Qwen3.6-35B-A3B-MLX-4bit-MTP` (8 x 131K, `--parallel 8`) | TensorFold 0.6.6 Python |

Install the engine from the tag: `pip install "tensorfold @ git+https://github.com/ashhart/TensorFold.git@v0.6.6"`
in a Python 3.12 venv. `--kv-dtype` is CUDA-only on the Python engine; MLX keeps bf16 KV.

Measured, 7K-token prompts with 8 tool schemas, greedy, worker without its MTP head:

| scenario | streams | per-stream tok/s | aggregate tok/s | TTFT p50 s |
|---|---|---|---|---|
| worker, main idle | 1 | 140 | 93 | 1.1 |
| worker, main idle | 4 | 77 | 256 | 0.7 |
| worker, main idle | 8 | 52 | 353 | 0.6 |
| main (0.6.0), worker idle | 1 | 105 | 55 | 3.4 |
| main WHILE 8 workers | 1 | 70 | 36 | 5.5 |
| 8 workers WHILE main | 8 | 43 | 140 | 10.9 |

Free+inactive at the heaviest point: 54.5 GiB. The 1.0.11 native main measured 135 tok/s solo against
this engine's 105 on the same checkpoint family and prompt.
