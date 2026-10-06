---
name: maintenance
description: Runs maintenance jobs in the foreground — daily cycle, consolidate, calibrate, dedup, purge, prune, retry, reset, status. Use for "run maintenance", "retry failed extractions", "dedupe tasks", "purge stale items", or "check maintenance status".
allowed-tools: Bash
disable-model-invocation: true
---

## What it does

Foreground entry point to the same handlers the `session-end` hook backgrounds. Holds the maintenance lock at `${CLAUDE_PLUGIN_DATA}/data/.maintenance.lock` so foreground and background paths cannot race. Every verb delegates to an existing handler — the skill adds no new behavior, only a uniform invocation surface and a single standard result envelope per call.

## When to use

- "run maintenance", "retry failed extractions", "dedupe tasks"
- "purge stale items", "prune orphans", "reap orphaned graph stores", "reset access log", "re-judge refused pairs"
- "calibrate the judge thresholds", "rewind the link cursor", "consolidate now"
- "check maintenance status", `/anton-core:maintenance`

## How

```
anton maintenance run [--dry-run] [--force] [--continue-on-error]
anton maintenance consolidate [--dry-run] [--force] [--quiet]
anton maintenance dedup --target tasks [--dry-run]
anton maintenance purge --target {stale|legacy-stubs} [--dry-run]
anton maintenance purge --target token-usage --before <YYYY-MM> [--dry-run]
anton maintenance prune --target {orphans|graph-stores} [--dry-run] [--include-populated --force] [--quiet]
anton maintenance retry --target extraction [--limit N] [--dry-run]
anton maintenance calibrate --target link [--dry-run]
anton maintenance reset --target {access-log|judged-refusals|judged-unjudgeable|link-cursor --to <unix-ms|RFC3339>} [--dry-run]
anton maintenance reindex --target {knowledge|code} [--dry-run]
anton maintenance repair --target fts [--dry-run]
anton maintenance status [--history Nd]
```

`run` dispatches ten pinned jobs in a fixed order — `fts_heal`, `fold_stray_types`, `fold_stray_rel_types`, `decay`, `backfill_task_sidecars`, `dedup_tasks`, `purge_legacy_stubs`, `repo_renamed_sweep`, `resolve_all_per_repo`, `reap_recall_sentinels` — under one lock acquisition. `fts_heal` runs first so no later job reads a desynced full-text index: it rebuilds only an index that fails its integrity check, recording `FTS_REBUILT`. A non-empty `fts_heal.fts_still_failing` means the content table behind that index is itself damaged and a rebuild cannot fix it; report it to the operator rather than retrying. The two folds follow, so the rest of the sweep sees canonical data. `fold_stray_rel_types` folds each off-vocabulary relationship verb in its own savepoint, preserving the original as a raw-type tag; a relationship it cannot fold is counted under a named cause and left on disk rather than aborting the sweep behind it, so `folded` may fall short of `scanned`.

`reset --target judged-refusals` deletes the consolidation judge's settled *refusals*, reopening those pairs for re-judging on the next consolidation pass — the escape hatch for a model revision that starts refusing a whole content class, which would otherwise be terminal. The `related` and `not_related` verdicts are permanent and nothing in this surface reverses them. `--dry-run` reports the would-delete count and writes nothing; a real run that deleted at least one refusal emits one WARN `JUDGED_REFUSALS_RESET` event carrying the count.

`reset --target judged-unjudgeable` reopens every consolidation pair the retry ledger retired as unjudgeable — a pair the judge gave no verdict for, which failed alone at `link.judge_max_attempts` / `dream.judge_max_attempts`. It reopens rather than deletes (the retirement clears and the attempt count returns to 0), so the next pass re-offers each pair ahead of its window; `reopened` in the envelope carries the count, `deleted` is 0, and a real run that reopened at least one pair emits one WARN `JUDGED_UNJUDGEABLE_RESET` event. A pair retired without a ledger entry is not covered; `reset --target link-cursor --to <instant>` re-walks it, and settled pairs are still skipped, so only pairs that never got a verdict cost a call.

`purge --target token-usage --before <YYYY-MM>` is the only way rows leave the token-usage ledger, which is never trimmed on its own. It deletes the rows whose spend month falls strictly before `--before`, month by month, and **refuses** any month holding a session whose transcript is still on disk — that session's spend is still auditable, and deleting it would make a later `usage doctor` report drift against the purge. Refused months are listed with their live-session count and keep every row. `--before` is required with this target and rejected with any other (`invalid_argument`), as is a value that is not a `YYYY-MM` month. `--dry-run` reports the per-month counts it would delete and refuse and writes nothing; a real run that deleted at least one row emits one WARN `TOKEN_LEDGER_PURGED` event carrying the deleted rows and the deleted and refused month counts.

`consolidate` is the manual path only — SessionStart dispatches one detached pass a day on its own, so reach for this verb when you want the graph built now rather than tomorrow. A pass the engine turned away with a rate limit records the reset instant and every later pass reports `stop_reason: cooldown` and spends nothing until it passes; `--force` overrides that as well as the dream and daily cooldowns.

`calibrate --target link` tabulates the judge's settled verdicts against the cosine each pair was measured at — backfilling that cosine onto verdicts settled before it was recorded — and suggests the two thresholds that gate the Link pass, `link.auto_relate_min` and `link.min_similarity`. Either suggestion is null when no cosine band held enough verdicts to support one; a threshold with no evidence behind it is worse than none. Run it after a model change or a re-embed, then set the keys yourself — the verb suggests, it never writes a threshold.

`reset --target link-cursor --to <when>` rewinds the Link pass's cursor, reopening every item created after that instant for re-judging. It is the recovery path for a window a degraded pass retired without judging. `--to` is required here and refused elsewhere, and a `--to` ahead of the current cursor is rejected: moving the cursor forward retires items unjudged, silently and permanently. Already-settled pairs are still skipped on the re-pass, so the re-spend covers only what was never settled.

`prune --target graph-stores` reaps per-repo code-graph store files whose repo is gone — unregistered, absent from disk and holding no indexed source files, all three — and, in the same run but independent of any reap, sweeps stranded config rows registry-wide: ghost `repos.slug_registry.<slug>` rows, whose root is both absent from disk and absent from the operator's configured set (swept first, so a store the ghost row was pinning can fall through the gate and reap in the same run), and `repos.repo.<slug>.*` freshness rows whose slug is no longer registered. Both sweeps report through the one `config_rows_deleted` counter, so a run that reaps nothing can still return `deleted: 0` alongside a non-zero `config_rows_deleted`. `--include-populated` drops the third reap condition and so needs `--force` (live) or `--dry-run` (preview); bare `--force` is rejected even alongside `--dry-run`, because on its own it authorises nothing. Reach for `--include-populated --force` only when the operator has asked for it by name: it destroys a real index. `--quiet` suppresses the per-store progress written as each store is unlinked, never the result envelope. `--include-populated`, `--force`, and `--quiet` belong to this arm alone — `--target orphans` takes only `--dry-run` and rejects the other three with `bad_input`.

The write verbs (`run`, `consolidate`, `calibrate`, `dedup`, `purge`, `prune`, `retry`, `reset`, `reindex`, `repair`) acquire the maintenance lock before doing work; the read-only `status` verb does not. One exception, by design: `prune --target orphans` is a single serialised DELETE that SQLite orders itself, so that arm takes no lock — `prune --target graph-stores`, which unlinks files, does. Lock contention surfaces (exit 4) as `{"error":{"kind":"concurrent_run","detail":"lock held: <path>","path":"<path>"}}`. An unknown `--target` value is rejected before the lock is taken: `{"error":{"kind":"bad_input","verb":"<verb>","offending_value":"<value>","accepted_set":[...],"detail":"bad input for verb <verb>: <value> (accepted: ...)"}}`. Both are wrapped under `error` — there is no top-level `status:"error"` form.

## Output

Each verb emits one standard result envelope carrying its own discriminator: `envelope.jobs_run` (the pinned slug list) for `run`; `envelope.target` for the eight `--target`-accepting verbs (`calibrate`, `dedup`, `purge`, `prune`, `retry`, `reset`, `reindex`, `repair`); a composite `dream`/`link`/`run_all` block with matching `*_ran` flags for `consolidate`; an `envelope.report.last_run` block plus `events_recent_24h` counts for `status`. The envelopes are flat (no `report` wrapper) for the write verbs and wrapped for `status`:

- `maintenance run` returns `{"status":"ok","started_at":N,"ended_at":N,"jobs_run":[...],"fts_heal":{...}}`, plus one result object per job that ran, keyed by job name.
- `maintenance consolidate` returns `{"status":"ok","link_ran":<true|false>,"dream_ran":<true|false>,"run_all_ran":<true|false>,"link":{...},"dream":{...},"run_all":{...}}`.
- `maintenance calibrate` returns `{"status":"ok","target":"link","buckets":[...],"rule":"...","suggested_auto_relate_min":<N|null>,"suggested_min_similarity":<N|null>,"backfilled":N,"missing_cosine":N,"dry_run":<true|false>}`.
- `maintenance dedup` returns `{"status":"ok","target":"tasks","scanned":N,"deduped":N,"kept":N,"dry_run":<true|false>}`.
- `maintenance purge` returns `{"status":"ok","target":"stale","access_log_deleted":N,"health_log_deleted":N,"step_log_deleted":N,"compress_log_deleted":N,"events_log_deleted":N,"recall_on_error_log_deleted":N,"expand_log_deleted":N,"query_log_deleted":N,"blast_radius_log_deleted":N,"plan_headroom_log_deleted":N,"dry_run":<true|false>}` for `stale`, and `{"status":"ok","target":"token-usage","before":"2026-09","deleted_rows":N,"months":[{"month":"2026-07","rows":N}],"refused":[{"month":"2026-08","rows":N,"live_sessions":N}],"dry_run":<true|false>}` for `token-usage`.
- `maintenance prune` returns `{"status":"ok","target":"graph-stores","scanned":N,"deleted":N,"reaped_bytes":N,"config_rows_deleted":N,"stores":[...],"dry_run":<true|false>}`.
- `maintenance retry` returns `{"status":"ok","target":"extraction","retried":N,"succeeded":N,"failed":N,"dry_run":<true|false>}`.
- `maintenance reset` returns `{"status":"ok","target":"<access-log|judged-refusals|judged-unjudgeable|link-cursor>","deleted":N,"dry_run":<true|false>}`, plus `reopened` for `judged-unjudgeable` and `cursor_from`, `cursor_to`, `items_reopened` and `estimated_pairs` for `link-cursor`.
- `maintenance reindex` returns `{"status":"ok","target":"<knowledge|code>","candidates":N,"embedded":N,"cap_hit":N,"skipped_reasons":{...},"dry_run":<true|false>}`.
- `maintenance repair` returns `{"status":"ok","target":"fts","before_failing":[...],"rebuilt":[...],"still_failing":[...]}`.
- `maintenance status` returns `{"status":"ok","report":{"last_run":{...},"events_recent_24h":{...},"link_last_run":N,"dream_last_run":N,"dream_cursor_item_id":"...","last_pass_spend_usd":N}}`.

Contract: `maintenance-run` in the anton-core CLI contract.
