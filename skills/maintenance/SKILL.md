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
"${CLAUDE_PLUGIN_ROOT}/scripts/core" maintenance run [--dry-run] [--force] [--continue-on-error]
"${CLAUDE_PLUGIN_ROOT}/scripts/core" maintenance dedup --target tasks
"${CLAUDE_PLUGIN_ROOT}/scripts/core" maintenance purge --target {stale|legacy-stubs}
"${CLAUDE_PLUGIN_ROOT}/scripts/core" maintenance prune --target orphans
"${CLAUDE_PLUGIN_ROOT}/scripts/core" maintenance retry --target extraction
"${CLAUDE_PLUGIN_ROOT}/scripts/core" maintenance reset --target access-log
"${CLAUDE_PLUGIN_ROOT}/scripts/core" maintenance status
```

The six write verbs (`run`, `dedup`, `purge`, `prune`, `retry`, `reset`) acquire the maintenance lock before doing work; the read-only `status` verb does not. Lock contention surfaces as `{"status":"error","kind":"concurrent_run", ...}`. Unknown `--target` values surface as `{"status":"error","kind":"bad_input", ...}`.

## Output

Each verb emits one ADR-0010 envelope carrying its own discriminator: `envelope.jobs_run` (the pinned slug list) for `run`; `envelope.target` for the six `--target`-accepting verbs; an `envelope.report.last_run` block plus `events_recent_24h` counts for `status`. The envelopes are flat (no `report` wrapper) for the six write verbs and wrapped for `status` per [`docs/adr/0030-lock-primitive-and-closed-kind-extension.md`](../../docs/adr/0030-lock-primitive-and-closed-kind-extension.md). Contract: [docs/plugin-spec/05-cli-contract.md#maintenance-run](../../docs/plugin-spec/05-cli-contract.md#maintenance-run).
