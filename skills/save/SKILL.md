---
name: save
description: Your tool for persisting durable knowledge — the write-side memory layer that supersedes native memory files. Use for capturing a fact, decision, or correction worth keeping, and gestures like 'save this' or 'remember this'. Write here, not to memory files.
allowed-tools: Bash
---

## What it does

Single entry point for content entering the knowledge base. Auto-categorises pasted text, file paths, and pre-parsed batches; routes through the matching pipeline; and reports what was written, deduplicated, or rejected.

## When to use

- "save this", "remember this", "store this", "add to kb"
- `/anton-core:save` or any user gesture handing over content to preserve
- After extracting facts or decisions worth persisting

## How

```
anton item save [--source-path <file> | --items-json <array> | --items-file <file> | --type T --title T --content C [--summary S] [--tags a,b,c] [--importance F]]
```

Three modes share one verb. `--source-path` runs the full intake pipeline against a file on disk. `--items-json` (or `--items-file`) writes a pre-parsed batch straight through reconcile and write. `--type` + `--title` + `--content` is the single-item shorthand for narrative the operator already has typed up; it also accepts `--summary`, `--tags` (comma-separated — note this verb takes a CSV list, unlike the repeatable `--tag` on `task add`), and `--importance` (`[0.0, 1.0]`, default `1`). Give `--type` a canonical type — `document`, `reference`, `project`, `feedback`, `note`, `fact`, `decision`, or `question`; an unrecognized value is coerced to `note` (a known synonym folds to its target) and the original is preserved on a `raw_type:` tag, so a save never fails on an unexpected type.

## Relate on save

Mode 3 also accepts `--relate <type>:<target-id>` (comma-separated or repeated) to assert an operator edge from the new item to an existing one at creation time, under the same closed rel-type vocabulary the `relate` skill uses (`relates_to`, `supersedes`, `part_of`, `resolves`; `updates` folds to `supersedes`). The new item is always the edge source. It is Mode-3 only — combining `--relate` with `--source-path`, `--items-json`, or `--items-file` fails `invalid_flag_combination`. Every target id and type is validated before the write, so a bad target or an unknown type rejects the whole save atomically: no item row, no edges. This is the create-and-link shortcut for the Curation flow below — save a correction and `supersedes`-link it over the stale note in one call.

## Output

Success envelope reports `status`, `written` (id list), `extracted`, `noop`, `rejected`, `type` (primary item type), `source_path`, `errors`, `warnings`, and `meta_used`, plus `saved_path` on a Mode 1 source copy and `relations_written` when `--relate` was supplied (the count of edges written with the item — the full set on a fresh item, `0` when the item deduped onto an existing row so no source landed for the edges to attach to). Contract: [docs/plugin-spec/05-cli-contract.md#item-save](../../docs/plugin-spec/05-cli-contract.md#item-save).

## Curation

Curate, don't accrete. Before saving, `memory recall` related memories; if the new note updates or corrects one that already exists, `item update --id <id>` (or `item delete`) it in place rather than appending a second, divergent version — in-place update stays the first choice. When the corrected memory must be **kept** — an audit trail, or a historical fact worth preserving — don't leave the pair unlinked: save the correction, then relate it to the superseded note with a `supersedes` edge (new → old) so a later `memory recall` renders a `superseded-by` marker on the stale hit instead of the two competing unmarked. Supersession must be either in-place or explicitly linked — never two unmarked records competing. A reconcile you recognized but skipped is not benign: it ships a known-wrong record to every future session.
