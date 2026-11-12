---
name: update
description: Corrects a saved memory in place by id — title, summary, content or tags. Use for 'that note is wrong, fix it', 'update the memory about X', 'correct item ref-…', 'retag it', or a stale recall hit, instead of saving a second version.
allowed-tools: Bash
---

## What it does

Rewrites fields of one existing memory item, keeping its id and its edges. Changed content is re-embedded, so recall finds the item by its new meaning.

## When to use

- "that note is wrong, fix it", "update the memory about X", "correct <id>"
- "retag <id>", "rename <id>"
- A recall hit you have verified is stale: reconcile it in the same turn

## How

Run the command that fits with Bash, then answer from what it prints. Never answer before it has run: what the store holds is unknown until it does.

```
anton item update --id <id> [--title <title>] [--summary <summary>] [--content <text>] [--tag <name> ...]
```

Without an id, find it first with `anton memory recall --query <subject>`. Pass at least one field. `--tag` replaces the whole tag set: to add a tag, read the current tags with `anton item get --ids <id>` and pass every one you keep plus the new one.

## Output

The item's fields after the update; `changed: false` means the values already matched and nothing was written. A `warnings` entry means the patch committed but the re-embed did not, so the item is not yet searchable by its new meaning. An id that names no item is `entity_not_found`.

Contract: `item-update` in the anton-core CLI contract.

## See also

- [`remove`](../remove/SKILL.md) — retires a record rather than correcting it.
- [`save`](../save/SKILL.md) — `--relate supersedes:<id>` keeps the old record and marks it replaced.
