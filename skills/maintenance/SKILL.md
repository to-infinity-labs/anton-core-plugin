---
name: maintenance
description: Runs maintenance jobs in the foreground — daily cycle, consolidate, calibrate, dedup, purge, prune, retry, reset, status. Use for "run maintenance", "retry failed extractions", "dedupe tasks", "purge stale items", or "check maintenance status".
allowed-tools: Bash
disable-model-invocation: true
---

## What it does

Runs by hand the jobs the session hooks run in the background, under the same maintenance lock, so the two never race.

## When to use

- "run maintenance", "retry failed extractions", "dedupe tasks"
- "purge stale items", "reap orphaned graph stores", "reset access log", "re-judge refused pairs"
- "calibrate the judge thresholds", "rewind the link cursor", "consolidate now"
- "check maintenance status", `maintenance`

## How

Run the command that fits with Bash, then answer from what it prints. Never answer before it has run: what the store holds is unknown until it does.

```
anton maintenance run [--dry-run] [--force] [--continue-on-error]
anton maintenance consolidate [--dry-run] [--force] [--quiet]
anton maintenance dedup --target tasks [--dry-run]
anton maintenance purge --target {stale|legacy-stubs} [--dry-run]
anton maintenance purge --target token-usage --before <YYYY-MM> [--dry-run]
anton maintenance prune --target graph-stores [--dry-run] [--include-populated --force] [--quiet]
anton maintenance retry --target extraction [--limit N] [--dry-run]
anton maintenance calibrate --target link [--dry-run]
anton maintenance reset --target {access-log|judged-refusals|judged-unjudgeable|link-cursor --to <unix-ms|RFC3339>} [--dry-run]
anton maintenance reindex --target knowledge [--dry-run]
anton maintenance repair --target {fts|invariants} [--dry-run]
anton maintenance status [--history Nd]
```

Every write verb takes `--dry-run`: run it first and show the operator what would change.

- **`run`** is the daily cycle: eight jobs in a fixed order, starting with `fts_heal`, which rebuilds any full-text index that fails its integrity check. It runs once a day: a second `run` inside 24 hours of the last full success returns `jobs_run: []` and does nothing, unless `--force`. A non-empty `fts_heal.fts_still_failing` means the table behind that index is damaged; report it rather than retrying.
- **`consolidate`** builds the knowledge graph now; SessionStart runs one pass a day by itself. After the engine hits a rate limit, passes report `stop_reason: cooldown` and spend nothing until the reset; `--force` overrides that and the daily cooldowns.
- **`calibrate --target link`** suggests values for `link.auto_relate_min` and `link.min_similarity` from the judge's settled verdicts. It never writes them, and a `null` suggestion means too little evidence. Run it after a model change or re-embed.
- **`reset --target judged-refusals`** reopens pairs the judge refused, for a model revision that refuses a whole class; `related` and `not_related` verdicts are permanent. **`judged-unjudgeable`** reopens pairs retired after failing at the attempt cap. **`link-cursor --to <when>`** rewinds the link pass to re-judge items created after that instant, and refuses a move forward, which would retire items unjudged. Settled pairs are skipped on the re-pass.
- **`purge --target token-usage`** is the only way rows leave the token ledger: it deletes the months strictly earlier than the one given, and refuses any month holding a session whose transcript is still on disk, since that spend is still auditable.
- **`prune --target graph-stores`** deletes code-graph stores whose repo is unregistered, gone from disk and holding no indexed files, and sweeps config rows left for unregistered repos. Every run, a `--dry-run` included, records one `GRAPH_STORES_PRUNED` event. `--include-populated --force` also deletes stores that still hold an index: use it only when the operator asks for it by name.

## Output

Each verb returns one result: `jobs_run` and a result per job for `run`; `target` and its counts, plus `dry_run`, for the targeted verbs; `link`, `dream` and `run_all` blocks for `consolidate`; `report.last_run` and the last day's event counts for `status`. A held lock is `concurrent_run` (exit 4): another maintenance run is in progress, so wait rather than retry at once. An unknown `--target` is `bad_input`, naming the accepted values.

Contract: `maintenance-run`, `maintenance-consolidate`, `maintenance-dedup`, `maintenance-purge`, `maintenance-prune`, `maintenance-retry`, `maintenance-calibrate`, `maintenance-reset`, `maintenance-reindex`, `maintenance-repair`, `maintenance-status` in the anton-core CLI contract.
