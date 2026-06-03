---
name: recall
description: Your primary tool for finding anything saved — text, code symbols, prior sessions. Use for loading context before non-trivial work, finding a symbol with `--code` rather than grep, and lookups like 'find' or 'where is X defined'. Reach for it before grep.
allowed-tools: Bash
---

## What it does

Runs a fused search over the unified store — vector KNN, dual FTS across title/summary and content body, a graph walk, freshness modulation, task-priority boosts, and an optional cross-encoder reranker — and returns the ranked pool. Default rendering is the wrapped JSON envelope; `--format text` opts in to a `<memory>` block plus a machine-parseable `<memory-ids>` trailer that downstream skills like `expand` and `explore` chain on.

## When to use

- "find", "search", "look up", "what did I save about"
- "show recent", "what repo handles X", "where is X defined"
- `/anton-core:recall` with a query, type filter, or tag filter

## How

```
"${CLAUDE_PLUGIN_ROOT}/scripts/core" memory recall [--query <text>] [--code] [--include-types t1,t2] [--type T]... [--tag T]... [--recent] [--include-completed] [--limit N] [--cot] [--no-rerank] [--explain] [--no-bump] [--session-id <sid>] [--format json|text]
```

At least one of `--query`, `--type`, or `--tag` is required. `--type` and `--tag` are repeatable; `--include-types` is comma-separated. `--code` is shorthand for `--include-types Symbol,Module`.

## Output

Default success envelope is `{"items":[...],"count":N}`; `--format text` emits the `<memory>` block followed by the `<memory-ids>` trailer. Every call writes one row to `events.access_log` capturing `result_signals` for the CoT and rerank state. Contract: [docs/plugin-spec/05-cli-contract.md#memory-recall](../../docs/plugin-spec/05-cli-contract.md#memory-recall).
