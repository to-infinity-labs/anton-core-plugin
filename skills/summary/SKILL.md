---
name: summary
description: Daily or weekly briefing of open tasks, overdue, due-today, completed-recent, and stats. Use for "summary", "what's due", "what's on my plate", "daily briefing", or "weekly recap".
allowed-tools: Bash
---

## What it does

Morning-briefing surface. Produces one overview of open tasks, the overdue and due-today slices, recently-completed work, knowledge gaps, session-intelligence counters, and a stats footer — composed from a single round-trip into the summary-rollup handler. `my_tasks` is the full open-task list (unscoped, agreeing with the tasks surface); `team_tasks` carries the operator-vs-team split.

## When to use

- "summary", "what's due", "what's on my plate"
- "daily briefing", "weekly recap", "upcoming tasks"
- `/anton-core:summary` for the morning standup view

## How

```
anton report summary [--date <YYYY-MM-DD>] [--period daily|weekly]
```

Default anchors on today's UTC date with the `daily` period (one-day `completed_recent` window); `--period weekly` widens that window to seven days. The verb is read-only — rendering and any operator-facing markdown belong to downstream skills.

## Output

Single consolidated envelope carries `owner`, `period`, `ref_date`, plus the `my_tasks`, `team_tasks`, `overdue`, `due_today`, `completed_recent`, `stats.counts`, `session_intelligence`, `search_misses`, and `recent_items` blocks — each with its own item list and count. It also always carries `compress_saved` (`{bytes_saved, tokens_saved_est}`), `token_usage` (`{total_tokens, estimated_usd}` — model-token spend over the window from the token-usage ledger's transcript-sourced rows, priced from the bundled table with the operator's `usage.pricing_overrides` applied, the same pricing `usage stats` uses; `estimated_usd` is `null` when the read degraded or a model is unpriced, `0` on a genuinely empty window), and `connections_opened` (fixed at `1` by the single-connection invariant). A `graph_growth` string (formatted `Knowledge graph: edges +N, themes +M since <ref_date>`) is present only when the window saw growth; it is omitted on an idle day or when the growth read degrades. All eleven queries run against one SQLite connection; the handler is read-only on the data path. Contract: [docs/plugin-spec/05-cli-contract.md#report-summary](../../docs/plugin-spec/05-cli-contract.md#report-summary).
