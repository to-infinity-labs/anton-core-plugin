---
name: summary
description: Daily or weekly briefing of open tasks, overdue, due-today, completed-recent, and stats. Use for "summary", "what's due", "what's on my plate", "daily briefing", or "weekly recap".
allowed-tools: Bash
---

## What it does

Morning-briefing surface. Produces one owner-scoped overview of open tasks, the overdue and due-today slices, recently-completed work, knowledge gaps, session-intelligence counters, and a stats footer — composed from a single round-trip into the summary-rollup handler. (External news headlines are not part of this envelope; use `/anton-core:news` for that surface.)

## When to use

- "summary", "what's due", "what's on my plate"
- "daily briefing", "weekly recap", "upcoming tasks"
- `/anton-core:summary` for the morning standup view

## How

```
"${CLAUDE_PLUGIN_ROOT}/scripts/core" report summary [--date <YYYY-MM-DD>] [--period daily|weekly] [--format json|text]
```

Default anchors on today's UTC date with the `daily` period (one-day `completed_recent` window); `--period weekly` widens that window to seven days. The verb is read-only — rendering and any operator-facing markdown belong to downstream skills.

## Output

Single consolidated envelope carries `owner`, `period`, `ref_date`, plus `my_tasks`, `team_tasks`, `overdue`, `due_today`, `completed_recent`, `stats.counts`, `session_intelligence`, `search_misses`, and `recent_items` blocks — each with its own item list and count. All eleven queries run against one SQLite connection; the handler is read-only on the data path. Contract: [docs/plugin-spec/05-cli-contract.md#report-summary](../../docs/plugin-spec/05-cli-contract.md#report-summary).
