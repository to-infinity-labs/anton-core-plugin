---
name: impact
description: Shows the blast radius of changing a function, method or type — every caller, subclass and renderer depending on it — from the code graph. Use for 'if I change X, what breaks', 'impact of X' or before a refactor, instead of grep or recall.
allowed-tools: Bash
---

## What it does

Walks inbound dependents of a symbol across `CALLS`, `EXTENDS`, `IMPLEMENTS`, `REFERENCES` and `RENDERS` to depth N, in one result. Unlike `callers` (calls only), it counts inheritance and rendering too. `REFERENCES` is a markdown link to a document or heading: code that merely uses a type is not an edge, so a type's users show up only through calls, inheritance and renders.

## When to use

- "if I change X, what breaks", "what if I change X", "impact of changing X"
- "blast radius of X", "/impact X"
- Sizing a refactor where calls alone undercount the dependents

## How

Run the command that fits with Bash, then answer from what it prints. Never answer before it has run: what the store holds is unknown until it does.

```
anton graph query transitive-walk --seed-id <id> --direction in --rel-types CALLS,EXTENDS,IMPLEMENTS,REFERENCES,RENDERS --depth N [--exclude-ambiguous] [--repo <slug>]
anton graph query dependents-by-complexity --seed-id <id> --rel-types CALLS,EXTENDS,IMPLEMENTS,REFERENCES,RENDERS --depth N --min-cyc M --top-n K [--exclude-ambiguous] [--repo <slug>]
anton graph level --find <name> --view <slug>
```

`--seed-id` takes a symbol id: resolve a name with `anton memory recall --code --query <name>` first, unless the input already is one; `graph level --find` tells same-named symbols apart. For "which complex dependents will hurt most", rank with `dependents-by-complexity` (defaults `--depth 5 --min-cyc 5 --top-n 30`): symbols with no cyclomatic score drop out. Outside any checkout of the repo, pass `--repo <slug>`; inside a linked worktree the walk answers for its branch.

## Output

One row per path, sorted by hop: a dependent reached by several paths repeats, and repeats count against `--top-n`, so report distinct `id`s. Each row's `edge_types[]` says which relation entered it, so a chain can be labelled (`─CALLS─▶`, `─EXTENDS─▶`). An unknown seed id or rel-type is an error, not an empty result. A `warnings` entry says the store is still building or stale and what to tell the operator.

Contract: `graph-query`, `graph-level` in the anton-core CLI contract.
