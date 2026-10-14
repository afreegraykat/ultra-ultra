#!/usr/bin/env python3
"""ultra-ultra smoke bench: solo + concurrent decode against OpenAI-compatible servers.
Usage: bench.py URL MODEL CONC [--prompt-tokens N] [--max-tokens N] [--tag T]
Prints one JSON line with per-stream and aggregate tok/s, TTFT, wall.
"""
import argparse, json, sys, time, threading, urllib.request

TOOLS = [{"type": "function", "function": {"name": n, "description": "d" * 60,
          "parameters": {"type": "object", "properties": {"path": {"type": "string"}, "pattern": {"type": "string"},
                         "limit": {"type": "integer"}}, "required": ["path"]}}}
         for n in ("read_file", "search_files", "terminal", "write_file", "patch", "web_search", "web_extract", "todo")]

def filler(n_tokens):
    # ~1 token per 4 chars of varied prose
    base = ("The quick brown fox jumps over the lazy dog while the engineer reviews the module boundaries, "
            "error wrapping, retry classification and the queue visibility timeout. ")
    return (base * (n_tokens * 4 // len(base) + 1))[: n_tokens * 4]

def one(url, model, prompt, max_tokens, tools, out, i):
    body = {"model": model, "messages": [
        {"role": "system", "content": f"Session {i}-{int(time.time())}: You are a careful coding assistant. " + prompt},
        {"role": "user", "content": f"Stream #{i}: Write a Python function that parses ISO-8601 durations and explain it in detail."}],
        "max_tokens": max_tokens, "stream": True, "temperature": 0}
    if tools:
        body["tools"] = TOOLS
    req = urllib.request.Request(url + "/chat/completions", data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json"})
    t0 = time.time(); ttft = None; n = 0; usage = None
    with urllib.request.urlopen(req, timeout=1800) as r:
        for line in r:
            if not line.startswith(b"data: "):
                continue
            d = line[6:].strip()
            if d == b"[DONE]":
                break
            j = json.loads(d)
            if j.get("usage"):
                usage = j["usage"]
            ch = j.get("choices") or []
            if ch and ((ch[0].get("delta") or {}).get("content") or (ch[0].get("delta") or {}).get("reasoning_content") or (ch[0].get("delta") or {}).get("reasoning")):
                if ttft is None:
                    ttft = time.time() - t0
                n += 1
    wall = time.time() - t0
    ctok = (usage or {}).get("completion_tokens") or n
    out[i] = {"ttft": ttft, "wall": wall, "completion_tokens": ctok,
              "decode_tps": ctok / (wall - (ttft or 0)) if wall > (ttft or 0) else None,
              "prompt_tokens": (usage or {}).get("prompt_tokens")}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("url"); ap.add_argument("model"); ap.add_argument("conc", type=int)
    ap.add_argument("--prompt-tokens", type=int, default=7000)
    ap.add_argument("--max-tokens", type=int, default=300)
    ap.add_argument("--no-tools", action="store_true")
    ap.add_argument("--tag", default="")
    a = ap.parse_args()
    prompt = filler(a.prompt_tokens)
    out = {}
    th = [threading.Thread(target=one, args=(a.url, a.model, prompt + f" seed{i}", a.max_tokens, not a.no_tools, out, i)) for i in range(a.conc)]
    t0 = time.time()
    for t in th: t.start()
    for t in th: t.join()
    wall = time.time() - t0
    tot = sum(v["completion_tokens"] for v in out.values())
    per = [v["decode_tps"] for v in out.values() if v["decode_tps"]]
    ttfts = sorted(v["ttft"] for v in out.values() if v["ttft"] is not None)
    res = {"tag": a.tag, "url": a.url, "model": a.model, "conc": a.conc, "prompt_tokens_req": a.prompt_tokens,
           "prompt_tokens_srv": out[0].get("prompt_tokens"), "max_tokens": a.max_tokens, "tools": not a.no_tools,
           "wall_s": round(wall, 1), "total_completion_tokens": tot,
           "aggregate_tps_e2e": round(tot / wall, 1),
           "per_stream_decode_tps_mean": round(sum(per) / len(per), 1) if per else None,
           "ttft_p50_s": round(ttfts[len(ttfts) // 2], 1) if ttfts else None,
           "ttft_max_s": round(ttfts[-1], 1) if ttfts else None}
    print(json.dumps(res))

if __name__ == "__main__":
    main()
