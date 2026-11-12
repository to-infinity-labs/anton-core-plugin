---
name: paths
description: Shows the call chain from one function to another — how A reaches B — from the code graph. Use for 'how does A reach B', 'show me the call chain from A to B' or 'path from main to X'.
allowed-tools: Bash
---

## What it does

Enumerates directed paths from `A` to `B` up to a depth bound, capped at `K` paths, walking `CALLS` unless `--rel-types` says otherwise. `--shortest` returns the shortest one.

## When to use

- "how does A reach B", "path from A to B", "show me the call chain"
- "shortest call chain to X", "/paths A B"
- Tracing one explicit chain between two known symbols

## How

Run the command that fits with Bash, then answer from what it prints. Never answer before it has run: what the store holds is unknown until it does.

```
anton graph query paths-between --from-id <A> --to-id <B> --rel-types CALLS --max-depth N --max-paths K [--shortest] [--exclude-ambiguous] [--repo <slug>]
```

Both ends take symbol ids: resolve each name with `anton memory recall --code --query <name>` first, unless it already is one. `--rel-types` is a comma-separated list or a JSON array; an unknown type or malformed JSON is refused with `invalid_argument`. Outside any checkout of the repo, pass `--repo <slug>`; inside a linked worktree the walk answers for its branch.

## Output

One row per path, shortest first, each with its `edge_types[]` and per-hop confidence; `nodes` maps ids to titles. An unreachable target is `rows: []`; an unknown id is an error. A `warnings` entry says the store is still building or stale and what to tell the operator.

Contract: `graph-query` in the anton-core CLI contract.
