---
name: relate
description: Assert or suppress a manual relationship edge between two memory items by id. Use when linking a note to what it supersedes, resolves, or is part of, or unlinking a wrong edge. Storage is directed; traversal reads it both ways.
allowed-tools: Bash
---

## What it does

Asserts — or suppresses — one operator relationship edge between two existing items by id. `relate` writes the edge; `unrelate` tombstones it. Every manual edge carries the top-of-rank `ASSERTED` confidence, so an operator link outranks any later machine inference of the same pair. Use it to turn a cross-reference that would otherwise live as prose into a real graph edge, or to overrule one the pipeline got wrong.

## When to use

- "link these two", "this supersedes that", "this resolves that error", "this is part of that project"
- `/anton-core:relate` on two ids you already have — the same skill runs both the relate and unrelate verbs
- Curation: after saving a correction you want to keep both sides of, `relate` the new note over the old one with `supersedes`
- Overruling the graph: `unrelate` a wrong pipeline-inferred edge — the "no" sticks against re-inference

## Vocabulary

The rel-type is a closed set. An unknown or reserved verb is rejected, never coerced to a default — a wrong edge verb is a wrong fact:

| Type | Meaning (`--from` → `--to`) |
|---|---|
| `relates_to` | a soft, non-committal association |
| `supersedes` | the source replaces / corrects the target |
| `part_of` | the source is a component of the target |
| `resolves` | the source answers / closes the target |

`updates` folds to `supersedes` as a synonym. Input is canonicalized case- and separator-insensitively, so `RELATES_TO` and `relates-to` both resolve to `relates_to`. The reserved pipeline, provenance, and synthetic verbs (`mentioned_in`, `follows`, `derived_from`, `synthesizes`, `co_accessed`) and the uppercase code-graph verbs (`CALLS`, `RENDERS`, …) are rejected by name.

## Direction

The arrow is the fact: `--from` supersedes / resolves / is-part-of `--to`. Point `--from` at the newer, resolving, or component item and `--to` at the older, resolved, or container item. Storage stays directed, but traversal walks the edge both ways with equal weight — a superseded note reached from either end sees the link — so you never assert a reverse edge yourself.

## Suppression

`unrelate` is a "no" that sticks. It sets a suppressed tombstone rather than deleting the row, and writes one even for a pair that never had an edge, so it also blocks the linker/dream jobs from re-inferring that pair. A later `relate` of the same triple clears the tombstone — an explicit "yes" outranks the earlier "no". Traversal surfaces (recall's walk, `explore`) hide suppressed edges; inspection surfaces (`item get`, `explore --include-suppressed`) show them, marked `suppressed: true`.

## How

```
anton item relate   --from ID --to ID[,ID…] --type T
anton item unrelate --from ID --to ID[,ID…] --type T
```

All three flags are required; `--to` takes one id or a comma-separated batch. `--from` and every target must resolve to a live item, and `--from` must not appear in `--to`. A bad id, a self-edge, or a duplicate target rejects the whole call in one transaction — no partial writes. Invoke through the plugin `anton` launcher (`bin/anton`); never a bare operator `core`, which bypasses the shim's pin gate.

## Output

Success envelope reports `status`, `source_id` (echoes `--from`), `target_ids` (echoes `--to`, in input order), `rel_type` (the canonical type), and `noop` — targets already in the desired state (already `ASSERTED`-and-unsuppressed for `relate`, already suppressed for `unrelate`), recorded and skipped with no row written; always an array. Error kinds: `invalid_argument` (unknown or reserved type, self-edge, duplicate target), `entity_not_found` (a missing id — whole batch rejected), `db_locked`, `db_corrupt`, `internal`. Contract: [docs/plugin-spec/05-cli-contract.md#item-relate](../../docs/plugin-spec/05-cli-contract.md#item-relate).
