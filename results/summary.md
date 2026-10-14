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
