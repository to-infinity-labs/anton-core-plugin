---
name: paths
description: Your tool for enumerating directed call-chain paths from one symbol to another. Use for tracing how A reaches B in an indexed repo instead of walking by hand, and gestures like 'path from A to B' or 'shortest call chain to X'. Use `callers` or `callees` for fan-out.
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

Resolve `<A>` and `<B>` independently via the [recall](../recall/SKILL.md) skill unless each already looks like a symbol-id. `--rel-types` accepts a comma-separated list or a JSON array literal; malformed JSON surfaces as a parser error at the CLI rather than at the SQL layer. From a cwd that is not the registered checkout (a superset worktree), pass `--repo <slug>` to walk the registered repo's graph instead of the cwd's (empty) store. Inside a linked worktree this is mandatory, not optional: no store is minted there by design, the parent checkout serves the graph, and an unscoped walk fails with `precondition_missing` naming `--repo` as the remedy.

## Output

A `paths-between` envelope — `template` is the discriminator, here `"paths-between"`. One row per enumerated path carrying `path[]`, `edge_types[]`, `confidence_chain[]`, `min_confidence`, and `path_length`. Alongside `rows` it includes `nodes: {id → {title, kind}}` for renderers, plus top-level `status`, `row_count`, `limit_value`, `truncated`, and `truncated_reason`. Rows are pre-sorted `path_length ASC, then path ASC`. Unreachable target returns `rows: []`. One `query_log` row per invocation. Contract: [docs/plugin-spec/05-cli-contract.md#graph-query](../../docs/plugin-spec/05-cli-contract.md#graph-query).

**Stale store — exit 3, not a tool failure.** When the repo's graph store sits at a different schema version than the running binary, the verb does not read it: it exits **3** with a `precondition_missing` envelope naming the remedy (a write verb — `anton graph index` or `anton repos sync` — migrates it). The store is left untouched, deliberately, so a read can never destroy one. This is the normal state on the first run after an upgrade; surface the remediation rather than reporting a generic tool failure.
