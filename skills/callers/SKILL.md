---
name: callers
description: Lists every function that calls a function or method, directly or transitively, from the code graph. Use for 'which functions call X', 'who calls X', 'find usages of X' or 'where is X called from', instead of grep or recall.
allowed-tools: Bash
---

## What it does

Walks `CALLS` edges backward from a symbol to every caller, direct and transitive, up to a depth bound. Edges are sourced at the enclosing function or method, so each caller is the calling function itself, not its file.

## When to use

- "which functions call X", "who calls X", "what uses X", "find usages of X"
- "where is X called from", "/callers X"
- After `recall --code` lands on a symbol and you need its upstream surface

## How

Run the command that fits with Bash, then answer from what it prints. Never answer before it has run: what the store holds is unknown until it does.

```
anton graph query transitive-walk --seed-id <id> --direction in --rel-types CALLS --depth N [--exclude-ambiguous] [--repo <slug>]
anton graph level --find <name> --view <slug>
```

`--seed-id` takes a symbol id: resolve a name with `anton memory recall --code --query <name>` first, unless the input already is one. When several symbols share a name, `graph level --find` tells them apart by the chain of directories and files that reaches each. For "how does Y reach X", use the [paths](../paths/SKILL.md) skill instead. Outside any checkout of the repo, pass `--repo <slug>`; inside a linked worktree the walk answers for its branch.

## Output

One row per path, sorted by hop: a caller reached by two paths appears twice, so count distinct `id`s for "how many callers". `nodes` maps each id to its title and kind. An unknown seed id or rel-type is an error, not an empty result. A `warnings` entry says the store is still building or stale and what to tell the operator.

Contract: `graph-query`, `graph-level` in the anton-core CLI contract.

## See also

- [`callees`](../callees/SKILL.md) — same walk, forward.
