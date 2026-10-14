#!/usr/bin/env python3
"""Long-context retrieval check: a needle buried in ~N tokens of filler, both servers loaded.
Usage: longctx.py URL MODEL TOKENS [--tag T]. Prints one JSON line: found, ttft, wall, prompt tokens."""
import json, sys, time, argparse, random, urllib.request

ap = argparse.ArgumentParser()
ap.add_argument("url"); ap.add_argument("model"); ap.add_argument("tokens", type=int)
ap.add_argument("--tag", default="longctx")
a = ap.parse_args()

random.seed(a.tokens)
words = "ledger invoice carrier shipment pallet dock manifest tariff lane depot broker customs freight".split()
needle_code = f"ZK-{random.randint(10000, 99999)}"
filler_words = int(a.tokens * 0.72)  # ~1.4 tokens/word for this vocabulary
body = []
pos = random.randint(int(filler_words * 0.35), int(filler_words * 0.65))
for i in range(filler_words):
    if i == pos:
        body.append(f"\nIMPORTANT: the override authorization code for lane 7 is {needle_code}.\n")
    body.append(random.choice(words))
doc = " ".join(body)
msgs = [{"role": "system", "content": "You answer questions about the attached document precisely. /no_think"},
        {"role": "user", "content": doc + "\n\nQuestion: What is the override authorization code for lane 7? Reply with the code only."}]
req = {"model": a.model, "messages": msgs, "max_tokens": 64, "temperature": 0, "stream": True,
       "chat_template_kwargs": {"enable_thinking": False}}
t0 = time.time(); ttft = None; out = ""; usage = None
r = urllib.request.urlopen(urllib.request.Request(a.url + "/chat/completions", data=json.dumps(req).encode(),
                           headers={"Content-Type": "application/json"}), timeout=3600)
for raw in r:
    line = raw.decode().strip()
    if not line.startswith("data:"): continue
    p = line[5:].strip()
    if p == "[DONE]": break
    j = json.loads(p)
    if j.get("usage"): usage = j["usage"]
    ch = j.get("choices") or []
    if ch:
        d = ch[0].get("delta") or {}
        tok = d.get("content") or d.get("reasoning_content")
        if tok:
            if ttft is None: ttft = time.time() - t0
            out += d.get("content") or ""
wall = time.time() - t0
print(json.dumps({"tag": a.tag, "model": a.model, "requested_tokens": a.tokens,
                  "prompt_tokens_srv": (usage or {}).get("prompt_tokens"),
                  "found": needle_code in out, "answer": out.strip()[:80],
                  "ttft_s": round(ttft, 1) if ttft else None, "wall_s": round(wall, 1)}))
