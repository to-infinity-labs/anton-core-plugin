---
name: callers
description: Finds every function that calls a symbol, direct or transitive. Use for tracing call sites in an indexed repo instead of grepping, and gestures like 'what calls X' or 'who uses X'. Pairs with `callees` for the downstream direction.
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

Resolve `<symbol>` first via the [recall](../recall/SKILL.md) skill unless the input already looks like a symbol-id. With `--paths-to <Y>`, reroute to `paths-between Y X` instead — the walker enumerates explicit call chains rather than the caller fan-out. From a cwd outside any checkout of the repo, pass `--repo <slug>` to walk the registered repo's graph. A linked worktree has its own graph store: a walk inside one, or `--repo <parent-slug>` from inside it, answers for its branch.

## Output

A `transitive-walk` envelope — top-level `status`, `template` (the discriminator, here `"transitive-walk"`), `rows`, `nodes`, `row_count`, `limit_value`, `truncated`, and `truncated_reason`. One row per visited symbol, sorted `hop ASC, id ASC`, each carrying its `id`, `hop`, `path[]`, `edge_types[]`, `confidence_chain[]`, and `min_confidence` from the per-edge `relationships.confidence` column; `nodes` maps each id to its `{title, kind}`. One `query_log` row is written regardless of success, timeout, or truncation. `graph query` returns `{"status":"ok","template":"transitive-walk","rows":[{"id":"...","hop":N,"path":[...],"edge_types":[...],"confidence_chain":[...],"min_confidence":"..."}],"nodes":{"<id>":{"title":"...","kind":"..."}},"row_count":N,"limit_value":N,"truncated":false,"truncated_reason":null}`. Contract: `graph-query` in the anton-core CLI contract.

**Read `warnings` before reporting an empty result.** Readying the store can leave an advisory: `worktree_building` means a linked worktree's store is still being built in the background, so `rows` covers only what is indexed so far; `store_rebuilding` means the store sat at an older schema version and is being regenerated in the background, so `rows` is empty until it finishes; `reconcile_failed` means the store could not be brought up to date with the working tree, so `rows` may be stale. Say so and re-run shortly rather than reporting the empty or partial set as the answer. A store written by a *newer* binary is different: the verb exits **3** with `schema_skew`, and so would `graph index` or `repos sync`, which refuse to touch it. The remedy there is to restart the session so it runs the newer binary; do not suggest re-indexing.

## See also

- [`callees`](../callees/SKILL.md) — same template, opposite direction: forward walk down the symbol's outgoing `CALLS` edges.
