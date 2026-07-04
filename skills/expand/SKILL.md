---
name: expand
description: Your tool for pulling the full body of memory ids that recall returned. Use for reading an id in full before quoting or editing it, and gestures like 'tell me more about X' or 'show full content'. Pairs with `explore` to widen to neighbors.
allowed-tools: Bash
---

## What it does

Fetches full content for one or more memory items by id. Multi-id calls also upsert pairwise co-access rows into `co_access_pairs` between the touched items — the system's primary engagement signal — so the retrieval graph learns which rows the operator looked at together. Natural follow-up to `recall`: recall's per-hit ids (`items[].id`) are the input.

## When to use

- "tell me more about <id>", "expand on <id>"
- "show full content of <id>" or "give me the body of these ids"
- Chaining after `recall` to drop the summary in favour of the full body

## How

```
"${CLAUDE_PLUGIN_ROOT}/scripts/core" item get --ids <id1>,<id2>[,...] [--session-id <sid>] [--include-relationships] [--no-bump]
```

The skill's user-facing surface is `expand`; the underlying cobra verb is `get`. An operator typing the verb directly should use `get`. The skill itself routes through `get` transparently and applies the batch cap from `tools.expand_batch_cap`.

## Output

Success envelope carries `items` (input-order array of `{id, type, title, summary, content}` rows — each also carrying `tags`, `created`, and `last_accessed` when the row has them), `count` (number of resolved rows), `co_access_pairs_added` (pairwise co-access rows upserted on this call), `missing_ids` (any ids that didn't resolve), and — under `--include-relationships` — `relationships` (outbound edges per resolved id). With two or more resolved ids, one row per unordered pair is upserted into `co_access_pairs`. Contract: [docs/plugin-spec/05-cli-contract.md#item-get](../../docs/plugin-spec/05-cli-contract.md#item-get).

## See also

- [`explore`](../explore/SKILL.md) — widens around a single id into its graph neighborhood; `expand` deepens one batch of ids into full bodies.
