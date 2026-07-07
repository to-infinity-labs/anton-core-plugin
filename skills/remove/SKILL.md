---
name: remove
description: Remove one item from the knowledge base by id, title, or fuzzy keyword. Use for "remove from kb", "delete this id", "forget this", or undoing a prior save.
allowed-tools: Bash
---

## What it does

Removes one item from the knowledge base, cleaning every dependent row across the unified store (items, sidecars, FTS, vector index, tags, relationships, co-access pairs) and deleting the on-disk content file. Resolves an identifier — id, exact title, or fuzzy keyword — into one row, previews what will go, then cascades the delete on confirmation.

## When to use

- "remove from kb", "delete this id", "forget this"
- `/anton-core:remove <identifier>` with an id or fuzzy keyword
- Undoing a prior `save` for a single row

## How

```
anton item delete --id <id> [--dry-run]
```

The skill's user-facing surface is `remove`; the underlying cobra verb is `delete`. An operator typing the verb directly should use `delete`. The skill itself routes through `delete` transparently after resolving the identifier (via `recall` for fuzzy matches).

## Output

Success envelope reports `status`, `id`, and `deleted` (boolean). A real delete of an existing row returns `deleted:true`. Deleting a nonexistent id is not a `deleted:false` success — it hard-errors with `{"error":{"kind":"entity_not_found","detail":"entity not found: item \"<id>\" not found"}}`. `deleted:false` appears only under `--dry-run`, where the envelope also carries `dry_run:true` and reports what the delete would remove without writing. A `warnings` array of non-fatal cascade notes (e.g. a source file under the knowledge dir that could not be resolved or unlinked) is present only when the delete produced at least one. Contract: [docs/plugin-spec/05-cli-contract.md#item-delete](../../docs/plugin-spec/05-cli-contract.md#item-delete).
