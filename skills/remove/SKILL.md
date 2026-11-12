---
name: remove
description: Deletes one saved memory for good, found by id, title or keyword. Use for 'forget the note titled X', 'forget this', 'delete item ref-…' or 'remove that from memory'.
allowed-tools: Bash
---

## What it does

Deletes one memory item and everything hanging off it — its search entries, vectors, tags, edges and stored file. Irreversible, so it previews and confirms first.

## When to use

- "forget the note titled X", "forget this", "remove that from memory"
- "delete <id>", undoing a prior `save`

## How

Run the command that fits with Bash, then answer from what it prints. Never answer before it has run: what the store holds is unknown until it does.

```
anton memory recall --query <title or keyword> --limit 5
anton item delete --id <id> --dry-run
anton item delete --id <id>
```

1. **Resolve.** Given an id, use it. Given a title or keyword, run the recall and show the hits as a numbered list (id, type, title); take the operator's pick. With a single exact title match, still show it and confirm.
2. **Preview.** Run the `--dry-run` and tell the operator what will go.
3. **Delete** on their confirmation. To correct a record rather than lose it, use the [update](../update/SKILL.md) skill instead.

## Output

`deleted: true` once the item is gone; under `--dry-run` it is `false` with `dry_run: true`, and nothing was written. An id that names no item is `entity_not_found`. A `warnings` entry is a dependent file that could not be removed; relay it.

Contract: `memory-recall`, `item-delete` in the anton-core CLI contract.
