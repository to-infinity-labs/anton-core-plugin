---
name: callees
description: Finds every function a symbol calls, direct or transitive. Use for tracing what a function depends on in an indexed repo instead of grepping, and gestures like 'what does X call' or 'downstream of X'. Pairs with `callers` for the upstream direction.
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

Resolve `<symbol>` first via the [recall](../recall/SKILL.md) skill unless the input already looks like a symbol-id. With `--paths-to <Y>`, reroute to `paths-between X Y` — the walker enumerates explicit call chains from the seed to the target. From a cwd outside any checkout of the repo, pass `--repo <slug>` to walk the registered repo's graph. A linked worktree has its own graph store: a walk inside one, or `--repo <parent-slug>` from inside it, answers for its branch.

## Output

A `transitive-walk` envelope — top-level `status`, `template` (the discriminator, here `"transitive-walk"`), `rows`, `nodes`, `row_count`, `limit_value`, `truncated`, and `truncated_reason`. One row per visited callee, sorted `hop ASC, id ASC`, each carrying `id`, `hop`, `path[]`, `edge_types[]`, `confidence_chain[]`, and `min_confidence`; `nodes` maps each id to its `{title, kind}`. External callees (third-party symbols stored as string metadata on `Module` nodes) never appear; the walk returns an empty set for them. One `query_log` row per invocation. `graph query` returns `{"status":"ok","template":"transitive-walk","rows":[{"id":"...","hop":N,"path":[...],"edge_types":[...],"confidence_chain":[...],"min_confidence":"..."}],"nodes":{"<id>":{"title":"...","kind":"..."}},"row_count":N,"limit_value":N,"truncated":false,"truncated_reason":null}`. Contract: `graph-query` in the anton-core CLI contract.

**Read `warnings` before reporting an empty result.** Readying the store can leave an advisory: `worktree_building` means a linked worktree's store is still being built in the background, so `rows` covers only what is indexed so far; `store_rebuilding` means the store sat at an older schema version and is being regenerated in the background, so `rows` is empty until it finishes; `reconcile_failed` means the store could not be brought up to date with the working tree, so `rows` may be stale. Say so and re-run shortly rather than reporting the empty or partial set as the answer. A store written by a *newer* binary is different: the verb exits **3** with `schema_skew`, and so would `graph index` or `repos sync`, which refuse to touch it. The remedy there is to restart the session so it runs the newer binary; do not suggest re-indexing.

## See also

- [`callers`](../callers/SKILL.md) — same template, opposite direction: backward walk up the symbol's incoming `CALLS` edges.
