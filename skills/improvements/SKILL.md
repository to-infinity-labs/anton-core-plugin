---
name: improvements
description: Reviews deep analysis's improvement suggestions — lists, approves or dismisses them. Use for 'what did deep analysis suggest I improve', 'pending improvements' or 'review improvements'.
allowed-tools: Bash
---

## What it does

The review queue for deep analysis's suggestions. Approving records a suggestion as adopted; dismissing keeps it on record, hides it, and stops it being suggested again. Deep analysis never edits a file itself.

## When to use

- "what did deep analysis suggest", "pending improvements", "review improvements"
- "approve that one", "dismiss that suggestion"

## How

Run the command that fits with Bash, then answer from what it prints. Never answer before it has run: what the store holds is unknown until it does.

```
anton improvement list [--pending-only | --applied-only] [--limit N] [--since <epoch-ms|ISO-8601>]
anton improvement approve --id <id>
anton improvement dismiss --id <id>
```

A bare `improvement list` returns both pending and applied rows; pass `--pending-only` for the queue. Approving may come with an offer to carry out the suggestion's described action, which needs the operator's explicit go.

## Output

`improvements`, newest first, each with its `item_id` (`impr-<16 hex>`), `category`, `target` and `state`. Report the remaining pending count after each approve or dismiss. An unknown id is `entity_not_found`.

Contract: `improvement-list`, `improvement-approve`, `improvement-dismiss` in the anton-core CLI contract.

## See also

- [`sessions`](../sessions/SKILL.md) — the session record the suggestions came from.
