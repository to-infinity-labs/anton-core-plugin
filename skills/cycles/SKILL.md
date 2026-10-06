---
name: cycles
description: Finds circular dependencies in the code graph. Use for checking a package or module for dependency cycles in an indexed repo instead of manual tracing, and gestures like 'are there cycles in X'.
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

When `--containing <X>` is supplied, resolve `X` via the [recall](../recall/SKILL.md) skill first. All-mode seeds only `function | method | component` items; for `EXTENDS`/`IMPLEMENTS` cycles, pass `--containing <Class>` plus `--rel-types EXTENDS,IMPLEMENTS`. From a cwd outside any checkout of the repo, pass `--repo <slug>` to detect cycles in the registered repo's graph. A linked worktree has its own graph store: a detection inside one, or `--repo <parent-slug>` from inside it, answers for its branch.

## Output

A `cycle-detect` envelope — `template` is the discriminator, here `"cycle-detect"`. One row per cycle carrying `seed_id`, `path[]` (closing on the seed), `edge_types[]`, `confidence_chain[]`, `min_confidence`, and `cycle_length`. Alongside `rows` the envelope carries `nodes: {id → {title, kind}}`, top-level `status`, `row_count`, `limit_value`, `truncated`, `truncated_reason`, and — only in all-mode (no `--containing`) — a `deduplicated_rotations` counter for rotation duplicates collapsed by the engine. Rows arrive sorted `cycle_length ASC, then path ASC`. One `query_log` row per invocation. `graph query` returns `{"status":"ok","template":"cycle-detect","rows":[{"seed_id":"...","path":[...],"edge_types":[...],"confidence_chain":[...],"min_confidence":"...","cycle_length":N}],"nodes":{"<id>":{"title":"...","kind":"..."}},"row_count":N,"limit_value":N,"truncated":false,"truncated_reason":null,"deduplicated_rotations":N}`. Contract: `graph-query` in the anton-core CLI contract.

**Read `warnings` before reporting an empty result.** Readying the store can leave an advisory: `worktree_building` means a linked worktree's store is still being built in the background, so `rows` covers only what is indexed so far; `store_rebuilding` means the store sat at an older schema version and is being regenerated in the background, so `rows` is empty until it finishes; `reconcile_failed` means the store could not be brought up to date with the working tree, so `rows` may be stale. Say so and re-run shortly rather than reporting the empty or partial set as the answer. A store written by a *newer* binary is different: the verb exits **3** with `schema_skew`, and so would `graph index` or `repos sync`, which refuse to touch it. The remedy there is to restart the session so it runs the newer binary; do not suggest re-indexing.
