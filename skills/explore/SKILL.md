---
name: explore
description: Your tool for walking the relationship graph outward from one seed to every connected node. Use for mapping what surrounds a recall hit before acting, and gestures like 'what is related to X' or 'explore around X'. Pairs with `expand` to deepen a batch.
allowed-tools: Bash
---

## What it does

Walks the relationship graph outward from one seed item and returns every node and edge reachable within a depth limit. Read-side companion to `expand`: `expand` deepens one batch of ids; `explore` widens around a single id. The walk is undirected by default and respects an optional relationship-type filter, so the skill can be pointed at structural code edges (`CALLS`, `EXTENDS`) or narrative memory edges (`RELATES_TO`, `DEPENDS_ON`). Bumps the seed's `access_count` and writes one row to `events.access_log` per invocation — the memory-side write that the read-only `graph query` surface cannot fire.

## When to use

- "explore around <id>", "what's related to <id>"
- "show the neighborhood of <id>", "trace the graph from <id>"
- After `recall` returns an id worth widening around

## How

```
anton memory explore --seed-id <id> [--depth N] [--rel-types T1,T2] [--direction {out,in,both}] [--include-content]
```

## Output

Success envelope is a JSON object with `nodes` and `edges` arrays plus the `requested_depth` / `applied_depth` / `seed_bumped` echo fields. Each node carries `id`, `type`, `title`, `summary`, `kind`, `complexity`, and `hop_distance` (and `content` when `--include-content` was passed); each edge carries `source`, `target`, `rel_type`, and `weight`. Only the seed's `access_count` is bumped — walk traversal is not a touch. Contract: [docs/plugin-spec/05-cli-contract.md#memory-explore](../../docs/plugin-spec/05-cli-contract.md#memory-explore).

## See also

- [`expand`](../expand/SKILL.md) — deepens one batch of ids into full bodies; `explore` widens around a single id into its neighborhood.
