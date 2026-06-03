---
name: paths
description: Your tool for enumerating directed call-chain paths from one symbol to another. Use for tracing how A reaches B in an indexed repo instead of walking by hand, and gestures like 'path from A to B' or 'shortest call chain to X'. Use `callers` or `callees` for fan-out.
allowed-tools: Bash
---

## What it does

Enumerates every directed path from `A` to `B` across the code-graph up to a depth bound, capped at `K` paths. With `--shortest`, restricts the result to paths whose length equals the minimum length found across the walk. Walks `CALLS` by default; multi-rel via `--rel-types`.

## When to use

- "how does A reach B", "path from A to B"
- "shortest call chain to X", "/paths A B"
- Tracing an explicit chain between two known symbols rather than a fan-out

## How

```
"${CLAUDE_PLUGIN_ROOT}/scripts/core" graph query paths-between --from-id <A> --to-id <B> --rel-types CALLS --depth N --max-paths K [--shortest] [--exclude-ambiguous]
```

Resolve `<A>` and `<B>` independently via the [recall](../recall/SKILL.md) skill unless each already looks like a symbol-id. `--rel-types` accepts a comma-separated list or a JSON array literal; malformed JSON surfaces as a parser error at the CLI rather than at the SQL layer.

## Output

Standard query envelope with `shape: paths` — one row per enumerated path carrying `path[]`, `edge_types[]`, `confidence_chain[]`, `min_confidence`, and `path_length`. The result also includes a `nodes: {id → {title, kind}}` map for renderers. Rows are pre-sorted `hop ASC, min_confidence DESC`. Unreachable target returns `rows: []`. One `query_log` row per invocation. Contract: [docs/plugin-spec/05-cli-contract.md#graph-query](../../docs/plugin-spec/05-cli-contract.md#graph-query).
