---
name: summary
description: Builds the operator's daily or weekly briefing — open, overdue and due tasks, recent work, new knowledge, spend. Use for 'give me my daily briefing', 'what's on my plate', 'what's due' or 'weekly recap'.
allowed-tools: Bash
---

## What it does

One read-only rollup for a day or a week: the operator's open tasks across every group, the team's split, overdue and due-today slices, what was completed, recent saves, searches that found nothing, session counters and model-token spend.

## When to use

- "give me my daily briefing", "what's on my plate", "what's due today"
- "morning summary", "weekly recap", "upcoming tasks"

## How

Run the command that fits with Bash, then answer from what it prints. Never answer before it has run: what the store holds is unknown until it does.

```
anton report summary [--date <YYYY-MM-DD>] [--period daily|weekly]
```

`--date` defaults to today in local time; `--period weekly` widens the completed window to seven days. Render a briefing from the result, never the raw JSON.

## Output

Blocks `my_tasks`, `team_tasks`, `overdue`, `due_today`, `completed_recent`, `recent_items`, `search_misses` (recalls that returned nothing over 30 days — gaps worth filling), `session_intelligence` and `stats`, each with its items and count. `token_usage.estimated_usd` is an estimate; `null` means it could not be priced, never zero spend. `graph_growth` appears only on a day the knowledge graph grew.

Contract: `report-summary` in the anton-core CLI contract.
