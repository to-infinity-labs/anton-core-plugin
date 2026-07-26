---
name: callees
description: Your tool for finding every function a symbol calls, direct or transitive. Use for tracing what a function depends on in an indexed repo instead of grepping, and gestures like 'what does X call' or 'downstream of X'. Pairs with `callers` for the upstream direction.
allowed-tools: Bash
---

## What it does

Walks `CALLS` edges forward from a symbol-id to surface every callee — direct and transitive — up to a depth bound. Mirror of `callers`: same template family, opposite direction. Answers "what does this function depend on?" across the indexed code-graph. Edges are sourced at the enclosing function or method, so seed on a function-level symbol-id — not its containing file — for full callee coverage.

## When to use

- "what does X call", "what does X depend on"
- "forward trace from X", "downstream of X", "/callees X"
- Tracing a function's own dependency surface after locating it via `recall --code`

## How

```
anton graph query transitive-walk --seed-id <id> --direction out --rel-types CALLS --depth N [--exclude-ambiguous] [--repo <slug>]
```

Resolve `<symbol>` first via the [recall](../recall/SKILL.md) skill unless the input already looks like a symbol-id. With `--paths-to <Y>`, reroute to `paths-between X Y` — the walker enumerates explicit call chains from the seed to the target. From a cwd that is not the registered checkout (a superset worktree), pass `--repo <slug>` to walk the registered repo's graph instead of the cwd's (empty) store. Inside a linked worktree this is mandatory, not optional: no store is minted there by design, the parent checkout serves the graph, and an unscoped walk fails with `precondition_missing` naming `--repo` as the remedy.

## Output

A `transitive-walk` envelope — top-level `status`, `template` (the discriminator, here `"transitive-walk"`), `rows`, `nodes`, `row_count`, `limit_value`, `truncated`, and `truncated_reason`. One row per visited callee, sorted `hop ASC, id ASC`, each carrying `id`, `hop`, `path[]`, `edge_types[]`, `confidence_chain[]`, and `min_confidence`; `nodes` maps each id to its `{title, kind}`. External callees (third-party symbols stored as string metadata on `Module` nodes) never appear; the walk returns an empty set for them. One `query_log` row per invocation. Contract: [docs/plugin-spec/05-cli-contract.md#graph-query](../../docs/plugin-spec/05-cli-contract.md#graph-query).

**Stale store — exit 3, not a tool failure.** When the repo's graph store sits at a different schema version than the running binary, the verb does not read it: it exits **3** with a `precondition_missing` envelope naming the remedy (a write verb — `anton graph index` or `anton repos sync` — migrates it). The store is left untouched, deliberately, so a read can never destroy one. This is the normal state on the first run after an upgrade; surface the remediation rather than reporting a generic tool failure.

## See also

- [`callers`](../callers/SKILL.md) — same template, opposite direction: backward walk up the symbol's incoming `CALLS` edges.
