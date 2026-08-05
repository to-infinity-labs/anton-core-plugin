---
name: maintenance
description: Foreground operator surface for maintenance jobs — daily cycle, dedup, purge, prune, retry, reset, status. Use for "run maintenance", "retry failed extractions", "dedupe tasks", "purge stale items", or "check maintenance status".
allowed-tools: Bash
---

## What it does

Foreground entry point to the same handlers the `session-end` hook backgrounds. Holds the maintenance lock at `${CLAUDE_PLUGIN_DATA}/data/.maintenance.lock` so foreground and background paths cannot race. Every verb delegates to an existing handler — the skill adds no new behavior, only a uniform invocation surface and a single standard result envelope per call.

## When to use

- "run maintenance", "retry failed extractions", "dedupe tasks"
- "purge stale items", "prune orphans", "reap orphaned graph stores", "reset access log", "re-judge refused pairs"
- "check maintenance status", `/anton-core:maintenance`

## How

```
anton maintenance run [--dry-run] [--force] [--continue-on-error]
anton maintenance consolidate [--dry-run] [--force] [--quiet]
anton maintenance dedup --target tasks
anton maintenance purge --target {stale|legacy-stubs}
anton maintenance prune --target {orphans|graph-stores} [--dry-run] [--include-populated --force] [--quiet]
anton maintenance retry --target extraction
anton maintenance reset --target {access-log|judged-refusals} [--dry-run]
anton maintenance reindex --target {knowledge|code}
anton maintenance repair --target fts [--dry-run]
anton maintenance status [--history Nd]
```

`run` dispatches eight pinned jobs in a fixed order — `fold_stray_types`, `fold_stray_rel_types`, `decay`, `backfill_task_sidecars`, `dedup_tasks`, `purge_legacy_stubs`, `repo_renamed_sweep`, `resolve_all_per_repo` — under one lock acquisition, the two folds first so the rest of the sweep sees canonical data. `fold_stray_rel_types` folds each off-vocabulary relationship verb in its own savepoint, preserving the original as a raw-type tag; a relationship it cannot fold is counted under a named cause and left on disk rather than aborting the sweep behind it, so `folded` may fall short of `scanned`.

`reset --target judged-refusals` deletes the consolidation judge's settled *refusals*, reopening those pairs for re-judging on the next consolidation pass — the escape hatch for a model revision that starts refusing a whole content class, which would otherwise be terminal. The `related` and `not_related` verdicts are permanent and nothing in this surface reverses them. `--dry-run` reports the would-delete count on either target and writes nothing; a real run that deleted at least one refusal emits one WARN `JUDGED_REFUSALS_RESET` event carrying the count.

`prune --target graph-stores` reaps per-repo code-graph store files whose repo is gone — unregistered AND absent from disk AND holding no indexed source files — and, in the same run but independent of any reap, sweeps stranded config rows registry-wide: ghost `repos.slug_registry.<slug>` rows, whose root is both absent from disk and absent from the operator's configured set (swept first, so a store the ghost row was pinning can fall through the gate and reap in the same run), and `repos.repo.<slug>.*` freshness rows whose slug is no longer registered. Both sweeps report through the one `config_rows_deleted` counter, so a run that reaps nothing can still return `deleted: 0` alongside a non-zero `config_rows_deleted`. `--include-populated` drops the third reap condition and so needs `--force` (live) or `--dry-run` (preview); bare `--force` is rejected even alongside `--dry-run`, because on its own it authorises nothing. Reach for `--include-populated --force` only when the operator has asked for it by name: it destroys a real index. `--quiet` suppresses the per-store progress written as each store is unlinked, never the result envelope. `--include-populated`, `--force`, and `--quiet` belong to this arm alone — `--target orphans` takes only `--dry-run` and rejects the other three with `bad_input`.

The nine write verbs (`run`, `consolidate`, `dedup`, `purge`, `prune`, `retry`, `reset`, `reindex`, `repair`) acquire the maintenance lock before doing work; the read-only `status` verb does not. One exception, by design: `prune --target orphans` is a single serialised DELETE that SQLite orders itself, so that arm takes no lock — `prune --target graph-stores`, which unlinks files, does. Lock contention surfaces (exit 4) as `{"error":{"kind":"concurrent_run","detail":"lock held: <path>","path":"<path>"}}`. An unknown `--target` value is rejected before the lock is taken: `{"error":{"kind":"bad_input","verb":"<verb>","offending_value":"<value>","accepted_set":[...],"detail":"bad input for verb <verb>: <value> (accepted: ...)"}}`. Both are wrapped under `error` — there is no top-level `status:"error"` form.

## Output

Each verb emits one standard result envelope carrying its own discriminator: `envelope.jobs_run` (the pinned slug list) for `run`; `envelope.target` for the seven `--target`-accepting verbs (`dedup`, `purge`, `prune`, `retry`, `reset`, `reindex`, `repair`); a composite `dream`/`link`/`run_all` block with matching `*_ran` flags for `consolidate`; an `envelope.report.last_run` block plus `events_recent_24h` counts for `status`. The envelopes are flat (no `report` wrapper) for the nine write verbs and wrapped for `status`. Contract: `maintenance-run` in the anton-core CLI contract.
