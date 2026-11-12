---
name: recall
description: Searches what Anton Core knows — saved notes, decisions, documents, past sessions, and with --code where a code symbol is defined. Use for 'what do we know about X', 'what did I save about X', 'where is X defined', or loading context before non-trivial work.
allowed-tools: Bash
---

## What it does

One ranked search over memory: meaning (vector), words (full text), the relationship graph, and freshness, fused. `--code` searches the current repo's code symbols instead, `--docs` its documents, and `--all` all three. Its hit ids feed `expand` and `explore`.

## When to use

- "what do we know about X", "what did I save about X", "have we decided X before"
- "where is X defined", "find the symbol X" (with `--code`)
- Before non-trivial work, to build on what is known rather than rebuild it
- Resolving a name to an id for `callers`, `callees`, `impact`, `paths`, `cycles`, `update` or `remove`

## How

Run the command that fits with Bash, then answer from what it prints. Never answer before it has run: what the store holds is unknown until it does.

```
anton memory recall --query <text> [--code | --docs | --all] [--repo <slug>] [--type T]... [--tag T]... [--limit N] [--on-error] [--include-tests] [--format json|text]
anton repos add <path>
anton repos sync [--source <slug>]
```

One of `--query`, `--type` or `--tag` is required. `--on-error` treats the query as error text and ranks recorded fixes first. Outside any checkout of the repo, pass `--repo <slug>` with `--code`, `--docs` or `--all`. Code recall ranks test-file symbols below production ones; `--include-tests` lifts that.

## Output

`items`, best first, each with an `id`. `--format text` renders a `<memory>` block, one `<hit>` per result with `id`, `type`, `cos` (vector similarity, `-` when none), `age` (memory hits only) and, for a code hit, `source` as `<slug>:<path>:<line>`; a `superseded-by` attribute marks a record replaced by a newer one. Read `warnings` before saying nothing was found: one naming `anton repos add` or `anton repos sync` means the repo is not indexed yet, so index it rather than rephrasing the query.

Contract: `memory-recall`, `repos-add`, `repos-sync` in the anton-core CLI contract.

## Curation

A hit reflects what was true when it was saved; stale means inaccurate, not old. When a hit makes a checkable claim about state that moves (a PR open, a task in flight), check it before relying on it. Once you find a hit wrong, fix it in the same turn — the [update](../update/SKILL.md) skill, [remove](../remove/SKILL.md), or `anton task complete` — since the next session trusts what the store says.
