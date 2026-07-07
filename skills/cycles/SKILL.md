---
name: cycles
description: Your tool for finding circular dependencies in the code graph. Use for checking a package or module for dependency cycles in an indexed repo, and gestures like 'are there cycles in X'. Reach for it instead of manual tracing.
allowed-tools: Bash
---

## What it does

Finds simple directed cycles in the code-graph. Each cycle is reported once (rotation-canonicalised by the engine) with its edge-type chain and per-hop confidence. With `--containing X`, the seed set is exactly `X`; without it, the seed set is every `function | method | component` item up to `code_graph.cycles_max_seeds=200`.

## When to use

- "are there cycles in X", "circular dependency", "recursive loops"
- "/cycles" or "/cycles --containing X"
- Prefer `--containing X` for non-trivial graphs; all-mode is capped at 200 anchor seeds and may time out on dense graphs

## How

```
anton graph query cycle-detect [--containing <X>] --rel-types CALLS --max-cycles K --max-cycle-len N [--exclude-ambiguous] [--repo <slug>]
```

When `--containing <X>` is supplied, resolve `X` via the [recall](../recall/SKILL.md) skill first. All-mode seeds only `function | method | component` items; for `EXTENDS`/`IMPLEMENTS` cycles, pass `--containing <Class>` plus `--rel-types EXTENDS,IMPLEMENTS`. From a cwd that is not the registered checkout (a superset worktree), pass `--repo <slug>` to detect cycles in the registered repo's graph instead of the cwd's (empty) store.

## Output

A `cycle-detect` envelope — `template` is the discriminator, here `"cycle-detect"`. One row per cycle carrying `seed_id`, `path[]` (closing on the seed), `edge_types[]`, `confidence_chain[]`, `min_confidence`, and `cycle_length`. Alongside `rows` the envelope carries `nodes: {id → {title, kind}}`, top-level `status`, `row_count`, `limit_value`, `truncated`, `truncated_reason`, and — only in all-mode (no `--containing`) — a `deduplicated_rotations` counter for rotation duplicates collapsed by the engine. Rows arrive sorted `cycle_length ASC, then path ASC`. One `query_log` row per invocation. Contract: [docs/plugin-spec/05-cli-contract.md#graph-query](../../docs/plugin-spec/05-cli-contract.md#graph-query).
