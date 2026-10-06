---
name: paths
description: Enumerates directed call-chain paths from one symbol to another. Use for tracing how A reaches B in an indexed repo instead of walking by hand, and gestures like 'path from A to B' or 'shortest call chain to X'. Use `callers` or `callees` for fan-out.
allowed-tools: Bash
---

## What it does

Enumerates every directed path from `A` to `B` across the code-graph up to a depth bound, capped at `K` paths. With `--shortest`, returns only the shortest path (sets `max-paths=1`). Walks `CALLS` by default; multi-rel via `--rel-types`.

## When to use

- "how does A reach B", "path from A to B"
- "shortest call chain to X", "/paths A B"
- Tracing an explicit chain between two known symbols rather than a fan-out

## How

```
anton graph query paths-between --from-id <A> --to-id <B> --rel-types CALLS --max-depth N --max-paths K [--shortest] [--exclude-ambiguous] [--repo <slug>]
```

Resolve `<A>` and `<B>` independently via the [recall](../recall/SKILL.md) skill unless each already looks like a symbol-id. `--rel-types` accepts a comma-separated list or a JSON array literal; malformed JSON surfaces as a parser error at the CLI rather than at the SQL layer. From a cwd outside any checkout of the repo, pass `--repo <slug>` to walk the registered repo's graph. A linked worktree has its own graph store: a walk inside one, or `--repo <parent-slug>` from inside it, answers for its branch.

## Output

A `paths-between` envelope — `template` is the discriminator, here `"paths-between"`. One row per enumerated path carrying `path[]`, `edge_types[]`, `confidence_chain[]`, `min_confidence`, and `path_length`. Alongside `rows` it includes `nodes: {id → {title, kind}}` for renderers, plus top-level `status`, `row_count`, `limit_value`, `truncated`, and `truncated_reason`. Rows are pre-sorted `path_length ASC, then path ASC`. Unreachable target returns `rows: []`. One `query_log` row per invocation. `graph query` returns `{"status":"ok","template":"paths-between","rows":[{"path":[...],"edge_types":[...],"confidence_chain":[...],"min_confidence":"...","path_length":N}],"nodes":{"<id>":{"title":"...","kind":"..."}},"row_count":N,"limit_value":N,"truncated":false,"truncated_reason":null}`. Contract: `graph-query` in the anton-core CLI contract.

**Read `warnings` before reporting an empty result.** Readying the store can leave an advisory: `worktree_building` means a linked worktree's store is still being built in the background, so `rows` covers only what is indexed so far; `store_rebuilding` means the store sat at an older schema version and is being regenerated in the background, so `rows` is empty until it finishes; `reconcile_failed` means the store could not be brought up to date with the working tree, so `rows` may be stale. Say so and re-run shortly rather than reporting the empty or partial set as the answer. A store written by a *newer* binary is different: the verb exits **3** with `schema_skew`, and so would `graph index` or `repos sync`, which refuse to touch it. The remedy there is to restart the session so it runs the newer binary; do not suggest re-indexing.
