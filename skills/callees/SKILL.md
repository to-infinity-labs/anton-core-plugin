---
name: callees
description: Lists every function a function or method calls, directly or transitively, from the code graph. Use for 'what does X call', 'what does X call all the way down', 'what does X depend on' or 'downstream of X', instead of grep or recall.
allowed-tools: Bash
---

## What it does

Walks `CALLS` edges forward from a symbol to every callee, direct and transitive, up to a depth bound. Edges are sourced at the enclosing function or method, so seed on the function, not its file.

## When to use

- "what does X call", "what does X depend on", "what does X call all the way down"
- "trace X downstream", "/callees X"
- After `recall --code` lands on a function and you need what it depends on

## How

Run the command that fits with Bash, then answer from what it prints. Never answer before it has run: what the store holds is unknown until it does.

```
anton graph query transitive-walk --seed-id <id> --direction out --rel-types CALLS --depth N [--exclude-ambiguous] [--repo <slug>]
```

`--seed-id` takes a symbol id: resolve a name with `anton memory recall --code --query <name>` first, unless the input already is one. For "how does X reach Y", use the [paths](../paths/SKILL.md) skill instead. Outside any checkout of the repo, pass `--repo <slug>`; inside a linked worktree the walk answers for its branch.

## Output

One row per path, sorted by hop: a callee reached by two paths appears twice, so count distinct `id`s. `nodes` maps each id to its title and kind. Third-party callees are not in the graph, so a walk into a library stops there. An unknown seed id or rel-type is an error, not an empty result. A `warnings` entry says the store is still building or stale and what to tell the operator.

Contract: `graph-query` in the anton-core CLI contract.

## See also

- [`callers`](../callers/SKILL.md) — same walk, backward.
