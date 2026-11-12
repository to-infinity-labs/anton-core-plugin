---
name: expand
description: Shows the full content of saved memories by id. Use for 'show me the full content of item ref-…', 'expand that id', 'tell me more about it', or reading a recall hit before quoting it. Pairs with `explore`.
allowed-tools: Bash
---

## What it does

Fetches the full body of one or more memory items by id. Fetching two or more together records that they were read together, which teaches retrieval what belongs with what. Natural follow-up to `recall`: its hit ids are the input.

## When to use

- "show me the full content of <id>", "expand on <id>", "tell me more about <id>"
- "give me the body of these ids"
- After `recall`, to read a hit in full rather than its snippet

## How

Run the command that fits with Bash, then answer from what it prints. Never answer before it has run: what the store holds is unknown until it does.

```
anton item get --ids <id1>,<id2>[,...] [--session-id <sid>] [--include-relationships] [--no-bump]
```

The verb reads the first 10 ids and drops the rest without naming them, so split a longer list across calls. `--include-relationships` adds each item's inbound and outbound edges, suppressed ones marked.

## Output

`items` is in input order, each with its full `content`; `missing_ids` lists ids that resolved to nothing. Quote from `content`, not from the recall snippet.

Contract: `item-get` in the anton-core CLI contract.

## See also

- [`explore`](../explore/SKILL.md) — widens around one id into its neighborhood.
