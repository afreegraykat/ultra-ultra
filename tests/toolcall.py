#!/usr/bin/env python3
"""Tool-calling contract check for one server: non-streaming and streaming requests with a tool must
return a well-formed tool_calls object with finish_reason=tool_calls.
Usage: tests/toolcall.py URL MODEL
"""
import json, sys, urllib.request

TOOL = [{"type": "function", "function": {"name": "list_dir", "description": "List a directory",
         "parameters": {"type": "object", "properties": {"path": {"type": "string"}}, "required": ["path"]}}}]

def req(url, body, stream):
    r = urllib.request.Request(url + "/chat/completions", data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(r, timeout=600) as resp:
        if not stream:
            return json.load(resp)
        name = args = ""; finish = None
        for line in resp:
            if not line.startswith(b"data: "): continue
            d = line[6:].strip()
            if d == b"[DONE]": break
            j = json.loads(d); ch = j.get("choices") or []
            if not ch: continue
            finish = ch[0].get("finish_reason") or finish
            for tc in (ch[0].get("delta") or {}).get("tool_calls") or []:
                f = tc.get("function") or {}; name = name or f.get("name") or ""; args += f.get("arguments") or ""
        return {"choices": [{"finish_reason": finish, "message": {"tool_calls": [{"function": {"name": name, "arguments": args}}] if name else None}}]}

def check(url, model, stream):
    body = {"model": model, "messages": [{"role": "user", "content": "List /tmp using the tool."}], "tools": TOOL, "max_tokens": 800, "stream": stream, "temperature": 0}
    j = req(url, body, stream); c = j["choices"][0]; tcs = c["message"].get("tool_calls") or []
    ok = c["finish_reason"] == "tool_calls" and tcs and tcs[0]["function"]["name"] == "list_dir" and json.loads(tcs[0]["function"]["arguments"]).get("path") == "/tmp"
    print(f"{'stream' if stream else 'whole ':6s} {model:8s} finish={c['finish_reason']} call={tcs[0]['function'] if tcs else None} -> {'ok' if ok else 'FAIL'}")
    return bool(ok)

if __name__ == "__main__":
    url, model = sys.argv[1], sys.argv[2]
    sys.exit(0 if all([check(url, model, False), check(url, model, True)]) else 1)
