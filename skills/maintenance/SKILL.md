---
name: maintenance
description: Foreground operator surface for maintenance jobs — daily cycle, dedup, purge, prune, retry, reset, status. Use for "run maintenance", "retry failed extractions", "dedupe tasks", "purge stale items", or "check maintenance status".
allowed-tools: Bash
---

## What it does

Foreground entry point to the same handlers the `session-end` hook backgrounds. Holds the maintenance lock at `${CLAUDE_PLUGIN_DATA}/data/.maintenance.lock` so foreground and background paths cannot race. Every verb delegates to an existing handler — the skill adds no new behavior, only a uniform invocation surface and a single ADR-0010 envelope per call.

## When to use

- "run maintenance", "retry failed extractions", "dedupe tasks"
- "purge stale items", "prune orphans", "reset access log"
- "check maintenance status", `/anton-core:maintenance`

## How

```
anton maintenance run [--dry-run] [--force] [--continue-on-error]
anton maintenance consolidate [--dry-run] [--force] [--quiet]
anton maintenance dedup --target tasks
anton maintenance purge --target {stale|legacy-stubs}
anton maintenance prune --target orphans
anton maintenance retry --target extraction
anton maintenance reset --target access-log
anton maintenance reindex --target {knowledge|code}
anton maintenance repair --target fts [--dry-run]
anton maintenance status [--history Nd]
```

The nine write verbs (`run`, `consolidate`, `dedup`, `purge`, `prune`, `retry`, `reset`, `reindex`, `repair`) acquire the maintenance lock before doing work; the read-only `status` verb does not. Lock contention surfaces (exit 4) as `{"error":{"kind":"concurrent_run","detail":"lock held: <path>","path":"<path>"}}`. An unknown `--target` value is rejected before the lock is taken: `{"error":{"kind":"bad_input","verb":"<verb>","offending_value":"<value>","accepted_set":[...],"detail":"bad input for verb <verb>: <value> (accepted: ...)"}}`. Both are wrapped under `error` — there is no top-level `status:"error"` form.

## Output

Each verb emits one ADR-0010 envelope carrying its own discriminator: `envelope.jobs_run` (the pinned slug list) for `run`; `envelope.target` for the seven `--target`-accepting verbs (`dedup`, `purge`, `prune`, `retry`, `reset`, `reindex`, `repair`); a composite `dream`/`link`/`run_all` block with matching `*_ran` flags for `consolidate`; an `envelope.report.last_run` block plus `events_recent_24h` counts for `status`. The envelopes are flat (no `report` wrapper) for the nine write verbs and wrapped for `status` per [`docs/adr/0030-lock-primitive-and-closed-kind-extension.md`](../../docs/adr/0030-lock-primitive-and-closed-kind-extension.md). Contract: [docs/plugin-spec/05-cli-contract.md#maintenance-run](../../docs/plugin-spec/05-cli-contract.md#maintenance-run).
