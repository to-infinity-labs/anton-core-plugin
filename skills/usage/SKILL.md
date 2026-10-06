---
name: usage
description: Reports model-token spend from the usage ledger — totals, dollar estimates, per-model/per-project splits, lane shares — and audits one session against its transcript. Use for "token usage", "how much did I spend", "usage stats", or "audit session tokens".
allowed-tools: Bash
---

## What it does

Read surface over the token-usage ledger the session-extract pass fills. `stats` aggregates the ledger over a window into token totals, estimated dollars, per-model / per-project splits, lane shares (main / subagent / aux), a cache-hit ratio, the plan headroom last captured from Claude Code's status line, and — when telemetry-sourced rows exist — an attribution breakdown. `doctor` reproduces one session's transcript-lane accounting from the transcript itself and reports whether the ledger agrees; `--repair` rewrites the session's transcript-sourced rows from that recompute; `--all` audits every extracted session in one run. Span mode (`span`) sums one project's usage over a time window straight from its live transcripts, so a session still running is measurable before its spend reaches the ledger.

## When to use

- "token usage", "how much did I spend", "usage stats", "what did last week cost"
- "audit this session's tokens", "are these numbers real", `/anton-core:usage`
- Verifying the ledger after a backfill, or investigating a suspicious total

## How

```
anton usage stats [--window <Nd|duration>] [--project <slug>] [--format json|text]
anton usage doctor --session-id <session-id> [--repair [--dry-run] [--accept-shrink]] [--format json|text]
anton usage doctor --all [--repair [--dry-run]] [--quiet] [--format json|text]
anton usage statusline [--line]
anton usage span --since <RFC3339> --project <transcript-dir> [--until <RFC3339>] [--format json|text]
anton item extract --backfill [--force]
```

`--window` defaults to `30d`. `span --project` takes one directory name under Claude Code's `projects/` dir — the launch path with every character outside `[A-Za-z0-9]` turned into `-` — never a path (rejected) or a `stats` slug; a name matching no directory returns a zero report, not an error. Rows are windowed on SPEND time (the session's last transcript timestamp), so backfilled history lands in the period it was actually spent. Every dollar figure is an estimate priced from a bundled list-price table with the operator's `usage.pricing_overrides` config merged field-wise over it; an unpriced model reports `null` dollars, never 0, and is named in `unpriced_models`. `doctor --repair` acts on the `drift` and `missing_ledger_rows` verdicts only, and refuses the rewrite (`repair_refused: true`) when the recompute is missing whole buckets of tokens the ledger holds — lost evidence is never papered over. `--accept-shrink` (with `--session-id` and `--repair` only) applies such a recompute anyway, once the operator has judged the missing buckets genuinely gone; it records one `TOKEN_LEDGER_SHRINK_ACCEPTED` event. `--dry-run` (with `--repair` only) writes nothing and reports `would_repair`. `--all` audits every session with a recorded transcript — exactly one of `--all` and `--session-id` is required — lists only the sessions that are not `match`, records a per-session read failure as that row's `error` and carries on, and prints progress to stderr every 50 sessions unless `--quiet`.

Plan headroom — how much of the 5-hour, 7-day and (behind a gateway) spend window is used, and when each resets — comes only from Claude Code's status-line input. `usage statusline` is not run by hand: `anton setup statusline` puts it at the head of the operator's status-line command, `<data-root>/data/versions/current usage statusline | { <their command> }`, where it passes the input through byte-for-byte, closes its output, then records the readings; a capture fault is logged and never blanks the status line. `--line` prints a compact readout (`5h 26% · 7d 44%`) for an operator with no status line of their own. `stats` reports the newest reading per window with its age: `stale` past 30 minutes, a window past its reset as `reset_passed` with a `null` percentage, and no `headroom` key at all (text: `headroom: unknown`) before the first capture — never 0%. History is populated by `anton item extract --backfill` (add `--force` to re-extract sessions that already have rows).

Render for the operator, never the raw JSON: dollars as estimates to the cent (`$2,904.01`), `<$0.01` for a figure under a cent, and a `null` dollar figure as `n/a` with the unpriced models named beside it. For headroom, one line per window with its percentage and reset time, marked stale past 30 minutes; a `reset_passed` window prints `—`; with no `headroom` key, say headroom is unknown and that `anton setup statusline` starts capturing it — never 0%.

## Output

`usage stats` returns `{"status":"ok","window":"30d","estimated":true,"totals":{...},"total_usd":<number|null>,"cache_hit_ratio":N,"per_model":[...],"per_project":[...],"lanes":{"main":N,"subagent":N,"aux":N},"unpriced_models":[...]}` plus an `attribution` section when the window holds telemetry-sourced rows and a `headroom` section once a reading exists: `{"headroom":{"observed_at":N,"age_seconds":N,"stale":false,"windows":[{"window":"five_hour","used_percentage":26,"resets_at":N,"reset_passed":false}]}}`. `usage doctor --session-id` returns `{"status":"ok","session_id":"...","result":"match|drift|missing_ledger_rows|missing_transcript","repaired":bool,"repair_refused":bool,"dry_run":bool,"would_repair":bool,"shrink_accepted":bool,"transcript":{"rows":N,"total":N},"ledger":{"rows":N,"total":N},"diff":[...]}`. `usage doctor --all` returns `{"status":"ok","mode":"all","dry_run":bool,"repair":bool,"counts":{"sessions":N,"match":N,"drift":N,"missing_ledger_rows":N,"missing_transcript":N,"repaired":N,"would_repair":N,"refused":N,"errors":N},"sessions":[{"session_id":"...","result":"drift","repaired":bool,"would_repair":bool,"repair_refused":bool}]}`. `usage statusline` emits no envelope: stdout is its stdin, byte for byte (or the `--line` readout), at exit 0. `usage span` returns `{"status":"ok","project":"...","since":"...","until":"...","totals":{...},"lanes":{"main":N,"subagent":N,"aux":0},"context":{"peak_prefix":N,"over_200k_sessions":N,"over_200k_tokens":N,"compactions":N},"transcripts":N,"skipped_lines":N,"time_split":{"main":{...},"subagent":{...}},"active_min":N,"compactions":[...],"agents":[...],"attribution_missing":N}`. `item extract --backfill` returns `{"status":"ok","mode":"backfill","sessions_seen":N,"sessions_extracted":N,"sessions_skipped":N}`. Contract: `usage-stats`, `usage-doctor`, `usage-span` and the `usage statusline` section in the anton-core CLI contract.

## See also

- [`sessions`](../sessions/SKILL.md) — per-session facet view (main transcript only); this skill reads the cross-session ledger, subagent lanes included.
- [`summary`](../summary/SKILL.md) — folds a bundled-table-priced token line for the rollup window into the daily briefing.
