---
name: dashboard
description: Opens, reuses or stops the read-only browser dashboard. Use for 'open the dashboard', 'dashboard', 'show me the graph/memory/tasks in the browser' or 'stop the dashboard'.
allowed-tools: Bash, Read
---

## What it does

Serves the read-only browser dashboard on `http://127.0.0.1:7777` without tying up a terminal. `anton dashboard --background` binds the port, hands it to a detached server stamped with the current session, and returns at once; the session-end hook stops that server when the session that started it ends. If a dashboard is already listening, the skill reuses it instead of starting a second one.

## When to use

- "dashboard", "open the dashboard", "show me the dashboard"
- "show me the graph / memory / tasks / sessions in the browser"
- "stop the dashboard", "kill the dashboard"
- `dashboard [surface]`

Surfaces and their paths: `overview` is `/`; `memory`, `repos`, `tasks`, `sessions`, `usage`, `improvements`, `health` and `graph` are `/<surface>`.

## How

Default port is 7777. Honour an explicit operator port ("on port 8080") everywhere `$PORT` appears below; never pick a different port silently.

**Listener check** (shared by every path below): `curl -sS -m 2 -D - -o /dev/null http://127.0.0.1:$PORT/healthz`. A dashboard answers `200` with an `X-Anton-Dashboard-Pid: <pid>` header naming its own process; any other answer, or none, is not a dashboard. The check needs only `curl`, so it works on images without a process lister.

1. **Probe**: run the listener check.
   - The header is present → a dashboard is already running (this or another session). Open `http://127.0.0.1:$PORT<path>` (`open` on macOS; otherwise print the URL) and stop here.
   - Something answers without the header → a foreign app owns the port. Report it and suggest an explicit alternative port; never reuse it, never kill it.
2. **Start** (nothing answered):

   ```
   anton dashboard --background --port $PORT <surface>
   ```

   It prints `Dashboard: <url>  (running in the background; log: <path>)`, opens the browser itself and exits 0 once the server is spawned. If the shell sandbox denies the bind or the spawn, ask the operator to approve running it outside the sandbox, then rerun it unchanged.
3. **Confirm**: re-run the listener check up to 5 times, 1s apart. On success report the URL. On exhaustion, read the tail of the `log:` path the start line printed and relay its typed error verbatim — a missing data dir surfaces a precondition error, fixed by `setup`. A busy-port error while nothing answers the check means a process holds the port without serving it: report the port as held by an unresponsive process and suggest another port. If the log carries no typed error (e.g. a slow cold start), relay its tail and say the server is not answering yet.

**Stopping** ("stop the dashboard"): run the listener check and `kill <pid>` the pid its header names — plain SIGTERM; the server drains in-flight requests for up to 3 seconds. With no header, kill nothing: report a foreign listener, or that no dashboard is running. Then verify: re-run the check after ~4s — report stopped when nothing answers, or that the port is still bound when it does. Works even when an earlier session started the server.

## Output

- One line — `Dashboard: http://127.0.0.1:$PORT<path>` — plus whether the server was started fresh or an existing one was reused.
- Lifecycle: the server lives until the session that started it ends (the session-end hook reaps that session's dashboards), until an update to a different version, or until the stop gesture. One started from a crashed session is reaped at the next session end of any session: once the harness process that launched it is gone, where the harness exports that process's pid, and otherwise once the session's transcript has gone unwritten for 24 hours.
- The skill itself records nothing. The dashboard shows data without editing it; its one write is opening a node on the graph page, which raises that item's access count and logs the access, like a recall hit.
