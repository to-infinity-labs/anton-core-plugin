---
name: recall
description: Your primary tool for finding anything saved — text, code symbols, prior sessions. Use for loading context before non-trivial work, finding a symbol with `--code` rather than grep, and lookups like 'find' or 'where is X defined'. Reach for it before grep.
allowed-tools: Bash
---

## What it does

Runs a fused search over the unified store — vector KNN, dual FTS across title/summary and content body, a graph walk, freshness modulation, and task-priority boosts — and returns the ranked pool. Default rendering is the wrapped JSON envelope; `--format text` opts in to a `<memory>` block that renders each hit title-first with an indented snippet of the matched passage and an `id · matched · score · age[ · source]` metadata line. Downstream skills like `expand` and `explore` chain on the per-hit ids (`items[].id` in JSON, or the id on each text hit's metadata line).

## When to use

- "find", "search", "look up", "what did I save about"
- "show recent", "what repo handles X", "where is X defined"
- `/anton-core:recall` with a query, type filter, or tag filter

## How

```
"${CLAUDE_PLUGIN_ROOT}/scripts/core" memory recall [--query <text>] [--code] [--include-tests] [--docs] [--all] [--on-error] [--include-types t1,t2] [--type T]... [--tag T]... [--recent] [--include-completed] [--limit N] [--explain] [--no-bump] [--session-id <sid>] [--format json|text]
```

At least one of `--query`, `--type`, or `--tag` is required. `--type` and `--tag` are repeatable; `--include-types` is comma-separated. `--code` is shorthand for `--include-types Symbol,Module`: a `--type`/`--include-types` list naming only code types routes to the per-repo code store (scoped to the named subset), while a list mixing knowledge and code types is rejected — use `--all` for a cross-store search. `--docs` targets the per-repo document store; `--all` fuses memory, repo docs, and repo code via weighted RRF; `--on-error` treats `--query` as error text and boosts RESOLVES-linked fixes to the top.

Code recall ranks symbols defined in test files below every production symbol, so `--code` surfaces the real definition first rather than a same-named test helper. The demotion only reorders — a symbol that exists only in test files is still returned. Pass `--include-tests` to lift the demotion for workflows that deliberately target test symbols (test and production then rank on match score alone); the flag is ignored outside the code store.

## Output

Default success envelope is `{"items":[...],"count":N}`; `--format text` emits the `<memory>` block (title-first hits, indented snippet, `id · matched · score · age[ · source]` metadata line). A code hit's `source` is `<slug>:<relpath>:<line>` (the line segment present when the symbol's starting line is known), giving a direct jump target. Every call writes one row to `events.access_log` capturing `result_signals` (the bump state). Contract: [docs/plugin-spec/05-cli-contract.md#memory-recall](../../docs/plugin-spec/05-cli-contract.md#memory-recall).

## Curation

A recalled memory reflects what was true when it was written — the `age` on each hit is the staleness signal. If a superseded or duplicate entry surfaces, reconcile it: `item update --id <id>` the current one and `remove` the obsolete, rather than leaving both to compete on future recalls. Best-effort; a missed cleanup is benign.
