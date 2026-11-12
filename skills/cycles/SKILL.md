---
name: cycles
description: Finds circular dependencies and recursive call loops in the code graph, for a package or the whole repo. Use for 'are there circular dependencies in X', 'dependency cycles', 'import cycle' or 'does X call itself'.
allowed-tools: Bash
---

## What it does

Finds simple directed cycles, each reported once with its edge types and per-hop confidence. With `--containing X`, every simple cycle through `X`; without it, every strongly connected component holding a function, method or component yields its shortest cycle, over the whole graph.

## When to use

- "are there cycles in X", "circular dependency", "recursive loops"
- "/cycles" or "/cycles --containing X"
- Checking a package before splitting it

## How

Run the command that fits with Bash, then answer from what it prints. Never answer before it has run: what the store holds is unknown until it does.

```
anton graph query cycle-detect [--containing <X>] --rel-types CALLS --max-cycles K --max-cycle-len N [--exclude-ambiguous] [--repo <slug>]
```

`--containing` takes a symbol id: resolve a name with `anton memory recall --code --query <name>` first. For a package, run all-mode and keep the cycles whose nodes sit under its path. For inheritance cycles, pass `--containing <Class> --rel-types EXTENDS,IMPLEMENTS`. Outside any checkout of the repo, pass `--repo <slug>`; inside a linked worktree the walk answers for its branch.

## Output

One row per cycle, shortest first, its `path[]` closing on its first node; `nodes` maps ids to titles and paths. `truncated` means `--max-cycles` cut the list. A `warnings` entry says the store is still building or stale and what to tell the operator.

Contract: `graph-query` in the anton-core CLI contract.
