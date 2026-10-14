# overlay/ — one operator's production wiring (not part of the recipe)

The recipe in `bin/` and `hermes/` assumes a quiet Mac. This directory is how one Studio runs it
as an always-on lane: a LaunchDaemon that restarts the stack, a hold file for maintenance, the memory
guard, and port/name mapping that keeps existing clients (which expect the main model as `flashnext`
on `11504`) working unchanged.

Files:

- `studio-ultra.env.sh` — `bin/env.local.sh` for this machine: ports, names, memory floors.
- `studio-ultra-lane.sh` — supervisor loop the daemon runs: honors `~/llm/lane/ultra.hold`, runs
  `bin/up.sh`, starts `bin/guard.sh`, waits on the main PID, restarts after exit.
- `com.aubrey.studio-ultra.plist` — the LaunchDaemon (runs as the login user, KeepAlive).
- `install-lane.sh` — `sudo bash overlay/install-lane.sh` on the Studio: installs the plist, boots out
  the old `com.aubrey.studio-ds4-tensorfold` daemon (its plist is kept, disabled, for rollback).
- `rollback-lane.sh` — the reverse: stop the ultra daemon, re-bootstrap the ds4 one.

Nothing here is needed to use the recipe.
