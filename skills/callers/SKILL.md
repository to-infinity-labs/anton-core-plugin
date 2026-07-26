---
name: callers
description: Your tool for finding every function that calls a symbol, direct or transitive. Use for tracing call sites in an indexed repo instead of grepping, and gestures like 'what calls X' or 'who uses X'. Pairs with `callees` for the downstream direction.
allowed-tools: Bash
---

## What it does

Walks `CALLS` edges backward from a symbol-id to surface every caller — direct and transitive — up to a depth bound. Answers "who depends on this function?" without leaving the code-graph surface. The mirror of `callees`: same template family, opposite direction. Edges are sourced at the enclosing function or method, so each caller returned is the calling function itself, not merely its containing file.

## When to use

- "what calls X", "who uses X", "find usages of X"
- "where is X called from", "/callers X"
- After landing on a symbol via `recall --code` and needing its upstream surface

## How

```
anton graph query transitive-walk --seed-id <id> --direction in --rel-types CALLS --depth N [--exclude-ambiguous] [--repo <slug>]
```

Resolve `<symbol>` first via the [recall](../recall/SKILL.md) skill unless the input already looks like a symbol-id. With `--paths-to <Y>`, reroute to `paths-between Y X` instead — the walker enumerates explicit call chains rather than the caller fan-out. When the session's working directory is not the registered checkout (a superset worktree, any foreign cwd), pass `--repo <slug>` to walk the registered repo's graph instead of the cwd's (empty) store. Inside a linked worktree this is mandatory, not optional: no store is minted there by design, the parent checkout serves the graph, and an unscoped walk fails with `precondition_missing` naming `--repo` as the remedy.

## Output

A `transitive-walk` envelope — top-level `status`, `template` (the discriminator, here `"transitive-walk"`), `rows`, `nodes`, `row_count`, `limit_value`, `truncated`, and `truncated_reason`. One row per visited symbol, sorted `hop ASC, id ASC`, each carrying its `id`, `hop`, `path[]`, `edge_types[]`, `confidence_chain[]`, and `min_confidence` from the per-edge `relationships.confidence` column; `nodes` maps each id to its `{title, kind}`. One `query_log` row is written regardless of success, timeout, or truncation. Contract: [docs/plugin-spec/05-cli-contract.md#graph-query](../../docs/plugin-spec/05-cli-contract.md#graph-query).

**Stale store — exit 3, not a tool failure.** When the repo's graph store sits at a different schema version than the running binary, the verb does not read it: it exits **3** with a `precondition_missing` envelope naming the remedy (a write verb — `anton graph index` or `anton repos sync` — migrates it). The store is left untouched, deliberately, so a read can never destroy one. This is the normal state on the first run after an upgrade; surface the remediation rather than reporting a generic tool failure.

## See also

- [`callees`](../callees/SKILL.md) — same template, opposite direction: forward walk down the symbol's outgoing `CALLS` edges.
