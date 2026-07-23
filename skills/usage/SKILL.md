---
name: usage
description: Report model-token spend from the usage ledger — totals, dollar estimates, per-model/per-project splits, lane shares — and audit one session against its transcript. Use for "token usage", "how much did I spend", "usage stats", or "audit session tokens".
allowed-tools: Bash
---

## What it does

Read surface over the token-usage ledger the session-extract pass fills. `stats` aggregates the ledger over a window into token totals, estimated dollars, per-model / per-project splits, lane shares (main / subagent / aux), a cache-hit ratio, and — when telemetry-sourced rows exist — an attribution breakdown. `doctor` reproduces one session's transcript-lane accounting from the transcript itself and reports whether the ledger agrees; `--repair` rewrites the session's transcript-sourced rows from that recompute.

## When to use

- "token usage", "how much did I spend", "usage stats", "what did last week cost"
- "audit this session's tokens", "are these numbers real", `/anton-core:usage`
- Verifying the ledger after a backfill, or investigating a suspicious total

## How

```
anton usage stats [--window <Nd|duration>] [--project <slug>] [--format json|text]
anton usage doctor --session-id <session-id> [--repair] [--format json|text]
```

`--window` defaults to `30d`. Rows are windowed on SPEND time (the session's last transcript timestamp), so backfilled history lands in the period it was actually spent. Every dollar figure is an estimate priced from a bundled list-price table with the operator's `usage.pricing_overrides` config merged field-wise over it; an unpriced model reports `null` dollars, never 0, and is named in `unpriced_models`. `doctor --repair` acts on the `drift` and `missing_ledger_rows` verdicts only, and refuses the rewrite (`repair_refused: true`) when the recompute is missing whole buckets of tokens the ledger holds — lost evidence is never papered over. History is populated by `anton item extract --backfill` (add `--force` to re-extract sessions that already have rows).

## Output

`usage stats` returns `{"status":"ok","window":"30d","estimated":true,"totals":{...},"total_usd":<number|null>,"cache_hit_ratio":N,"per_model":[...],"per_project":[...],"lanes":{"main":N,"subagent":N,"aux":N},"unpriced_models":[...]}` plus an `attribution` section when the window holds telemetry-sourced rows. `usage doctor` returns `{"status":"ok","session_id":"...","result":"match|drift|missing_ledger_rows|missing_transcript","repaired":bool,"repair_refused":bool,"transcript":{"rows":N,"total":N},"ledger":{"rows":N,"total":N},"diff":[...]}`. Contract: [docs/plugin-spec/05-cli-contract.md#usage-stats](../../docs/plugin-spec/05-cli-contract.md#usage-stats).

## See also

- [`sessions`](../sessions/SKILL.md) — per-session facet view (main transcript only); this skill reads the cross-session ledger, subagent lanes included.
- [`summary`](../summary/SKILL.md) — folds a bundled-table-priced token line for the rollup window into the daily briefing.
