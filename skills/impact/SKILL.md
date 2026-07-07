---
name: impact
description: Your blast-radius tool — every dependent of a symbol across calls, inheritance, references, and renders. Use for sizing impact before changing a symbol, and gestures like 'what if I change X'. Has a top-N ranking mode for the most-complex dependents.
allowed-tools: Bash
---

## What it does

Surfaces the blast radius of changing a symbol by walking inbound dependents across the full code-graph relationship vocabulary — `CALLS`, `EXTENDS`, `IMPLEMENTS`, `REFERENCES`, `RENDERS` — to depth N. Unlike `callers` (which walks `CALLS` only), `impact` returns the union of dependents across all five rel-types in a single result envelope.

## When to use

- "what if I change X", "impact of changing X"
- "blast radius of X", "/impact X"
- Pre-refactor sanity checks where `CALLS` alone undercounts the dependency surface

## How

```
"${CLAUDE_PLUGIN_ROOT}/scripts/core" graph query transitive-walk --seed-id <id> --direction in --rel-types CALLS,EXTENDS,IMPLEMENTS,REFERENCES,RENDERS --depth N [--exclude-ambiguous] [--repo <slug>]
```

Resolve `<symbol>` first via the [recall](../recall/SKILL.md) skill unless the input already looks like a symbol-id. With `--paths-to <Y>`, dispatch `paths-between X Y` with the same five-rel filter so the path walk does not silently drop non-`CALLS` chains. From a cwd that is not the registered checkout (a superset worktree), pass `--repo <slug>` to walk the registered repo's graph instead of the cwd's (empty) store.

### Ranking by complexity

When the goal is "which complex callers will hurt most if X changes", rank instead of enumerate via the `dependents-by-complexity` template — same backward multi-rel walk, but filters `cyclomatic >= M` and sorts `cyclomatic DESC`:

```
"${CLAUDE_PLUGIN_ROOT}/scripts/core" graph query dependents-by-complexity --seed-id <id> \
  --rel-types CALLS,EXTENDS,IMPLEMENTS,REFERENCES,RENDERS \
  --depth N --min-cyc M --top-n K [--exclude-ambiguous] [--repo <slug>]
```

Defaults live under the `code_graph.dbc_*` config namespace (`dbc_default_depth=5`, `dbc_default_min_cyc=5`, `dbc_default_top_n=30`). Nodes with `cyclomatic IS NULL` (non-function kinds, tier-2 languages without complexity infrastructure) drop out by construction; use the default `impact` shape for a complexity-agnostic enumeration. See [`docs/plugin-spec/07-skills/impact.md`](../../docs/plugin-spec/07-skills/impact.md) for the ranking-mode contract.

## Output

A `transitive-walk` envelope — top-level `status`, `template` (the discriminator, here `"transitive-walk"`), `rows`, `nodes`, `row_count`, `limit_value`, `truncated`, and `truncated_reason`. One row per visited dependent, sorted `hop ASC, id ASC`, each carrying `id`, `hop`, `path[]`, `edge_types[]`, `confidence_chain[]`, and `min_confidence`; `nodes` maps each id to its `{title, kind}`. Per-row `edge_types[]` records which relation type entered the row, so heterogeneous chains can be labelled (e.g. `─CALLS─▶`, `─EXTENDS─▶`, `─REFERENCES─▶`). One `query_log` row per invocation. Contract: [docs/plugin-spec/05-cli-contract.md#graph-query](../../docs/plugin-spec/05-cli-contract.md#graph-query).
