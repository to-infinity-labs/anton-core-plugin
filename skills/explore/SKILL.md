---
name: explore
description: Walks the relationship graph around one saved memory by id — everything linked to it and how. Use for 'what is connected to item ref-…', 'walk its neighbourhood' or 'what is related to this note'. Pairs with `expand`.
allowed-tools: Bash
---

## What it does

Walks the memory relationship graph outward from one seed item and returns every node and edge within a depth limit. It covers memory items only — notes, decisions, documents, tasks — and their edges (`relates_to`, `supersedes`, `part_of`, `resolves`, and the pipeline's own); code symbols live in each repo's graph store, which `callers`, `callees` and `impact` walk. The walk is undirected by default.

## When to use

- "what is connected to <id>", "what's related to <id>", "explore around <id>"
- "show the neighborhood of <id>", "walk its neighbourhood"
- After `recall` returns an id worth widening around

## How

Run the command that fits with Bash, then answer from what it prints. Never answer before it has run: what the store holds is unknown until it does.

```
anton memory explore --seed-id <id> [--depth N] [--rel-types T1,T2] [--direction {out,in,both}] [--include-content] [--include-suppressed]
anton graph level --view <slug> [--parent d:<dir>]
```

`--depth` defaults to 2 and is clamped to `tools.explore_depth_ceiling` (default 8). `--rel-types` matches the stored type exactly. Edges the operator suppressed with `unrelate` stay hidden unless `--include-suppressed`. For a directory's size and coupling map rather than one item's neighborhood, read a level of the repo's view with `graph level`; `anton graph views` lists the views.

## Output

`nodes` (each with its `hop_distance` from the seed) and `edges`; at most 500 nodes, and `truncated: true` means the walk stopped there, so narrow it. Only the seed's access count rises; walked nodes are not touched. A seed id that names no memory item is `entity_not_found`.

Contract: `memory-explore`, `graph-level` in the anton-core CLI contract.

## See also

- [`expand`](../expand/SKILL.md) — deepens one batch of ids into full bodies.
