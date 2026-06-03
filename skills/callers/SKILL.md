---
name: callers
description: Your tool for finding every function that calls a symbol, direct or transitive. Use for tracing call sites in an indexed repo instead of grepping, and gestures like 'what calls X' or 'who uses X'. Pairs with `callees` for the downstream direction.
allowed-tools: Bash
---

## What it does

Walks `CALLS` edges backward from a symbol-id to surface every caller — direct and transitive — up to a depth bound. Answers "who depends on this function?" without leaving the code-graph surface. The mirror of `callees`: same template family, opposite direction.

## When to use

- "what calls X", "who uses X", "find usages of X"
- "where is X called from", "/callers X"
- After landing on a symbol via `recall --code` and needing its upstream surface

## How

```
"${CLAUDE_PLUGIN_ROOT}/scripts/core" graph query transitive-walk --seed-id <id> --direction in --rel-types CALLS --depth N [--exclude-ambiguous]
```

Resolve `<symbol>` first via the [recall](../recall/SKILL.md) skill unless the input already looks like a symbol-id. With `--paths-to <Y>`, reroute to `paths-between Y X` instead — the walker enumerates explicit call chains rather than the caller fan-out.

## Output

Standard query envelope with `shape: node-set` — one row per visited symbol, sorted `hop ASC, id ASC`, each carrying its `hop`, `path[]`, `edge_types[]`, and `min_confidence` from the per-edge `relationships.confidence` column. One `query_log` row is written regardless of success, timeout, or truncation. Contract: [docs/plugin-spec/05-cli-contract.md#graph-query](../../docs/plugin-spec/05-cli-contract.md#graph-query).

## See also

- [`callees`](../callees/SKILL.md) — same template, opposite direction: forward walk down the symbol's outgoing `CALLS` edges.
