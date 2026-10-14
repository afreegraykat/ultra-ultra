# Studio cutover: ds4 lane (TensorFold 0.6.0) -> ultra lane (1.0.11 native, main + worker)

Staged 2026-10-14. Everything below is reversible with `overlay/rollback-lane.sh`.

## Already in place (no behavior change yet)
- `~/ultra-ultra` on the Studio, synced from the repo; `bin/env.local.sh` carries the pinned revisions.
- `~/.hermes-ultra` on the Studio (recipe's own Hermes; unused by production).
- mac-mini-llm tunnel LaunchAgent `com.openclaw.studio-ds4-tunnel` now forwards both
  18010 -> studio:11504 (main, name `flashnext`) and 18012 -> studio:11505 (worker).
- Gerard `config.yaml`: provider `studio-worker` (18012) added; `studio-flashnext` unchanged except its label.
- cron `tf105-studio-window-launch` / `-report` paused (superseded).

## The flip (Studio, ~2 min of main-model downtime)
    sudo bash /Users/aubrey/ultra-ultra/overlay/install-lane.sh
It: writes env.local.sh from overlay/studio-ultra.env.sh (ports 11504/11505, name flashnext), installs
`com.aubrey.studio-ultra`, holds + boots out `com.aubrey.studio-ds4-tensorfold` (plist kept as .disabled),
and waits for both /v1/models. Then from mac-mini-llm:
    curl -s http://127.0.0.1:18010/v1/models   # flashnext
    curl -s http://127.0.0.1:18012/v1/models   # worker
    hermes chat -q "Reply PONG."               # Gerard default provider still works

## What changes for clients
- Same host:port, same model name `flashnext`, same 262K context, same 6-bit checkpoint.
- Engine is 1.0.11 native: ~20% faster decode, greedy only. A request with temperature != 0 gets HTTP 400.
  Hermes omits temperature on its main path (verified on the wire 2026-10-14) and auto-omits after one 400 on
  auxiliary paths. Non-Hermes clients must send temperature 0 or none.
- Hold file moves: `~/llm/lane/ultra.hold` (was `ds4.hold`). `bin/status.sh` in ~/ultra-ultra shows both servers.

## After a day of clean operation
- Point Vega/Wren/Sloane/Coach/Grants `delegation` at `studio-worker` (currently GN100 27B on 18009).
- Decide whether Gerard's own subagents move off gpt-6-sol. Not before Nemotron has a track record on real tasks.

## Rollback (Studio)
    sudo bash /Users/aubrey/ultra-ultra/overlay/rollback-lane.sh
Restores the 0.6.0 ds4 daemon verbatim; the 18012 tunnel just sits unconnected.
