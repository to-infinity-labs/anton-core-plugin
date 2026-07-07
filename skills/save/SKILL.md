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
"${CLAUDE_PLUGIN_ROOT}/scripts/core" item save [--source-path <file> | --items-json <array> | --items-file <file> | --type T --title T --content C [--summary S] [--tags a,b,c] [--importance F]]
```

Three modes share one verb. `--source-path` runs the full intake pipeline against a file on disk. `--items-json` (or `--items-file`) writes a pre-parsed batch straight through reconcile and write. `--type` + `--title` + `--content` is the single-item shorthand for narrative the operator already has typed up; it also accepts `--summary`, `--tags` (comma-separated — note this verb takes a CSV list, unlike the repeatable `--tag` on `task add`), and `--importance` (`[0.0, 1.0]`, default `1`). Give `--type` a canonical type — `document`, `reference`, `project`, `feedback`, `note`, `fact`, `decision`, or `question`; an unrecognized value is coerced to `note` (a known synonym folds to its target) and the original is preserved on a `raw_type:` tag, so a save never fails on an unexpected type.

## Output

Success envelope reports `status`, `written` (id list), `extracted`, `noop`, `rejected`, `type` (primary item type), `source_path`, `errors`, `warnings`, and `meta_used`, plus `saved_path` on a Mode 1 source copy. Contract: [docs/plugin-spec/05-cli-contract.md#item-save](../../docs/plugin-spec/05-cli-contract.md#item-save).

## Curation

Curate, don't accrete. Before saving, `recall` related memories; if the new note updates or corrects one that already exists, `item update --id <id>` (or `remove`) it in place rather than appending a second, divergent version — in-place update stays the first choice. When the corrected memory must be **kept** — an audit trail, or a historical fact worth preserving — don't leave the pair unlinked: save the correction, then relate it to the superseded note with a `supersedes` edge (new → old) so a later `recall` renders a `superseded-by` marker on the stale hit instead of the two competing unmarked. Supersession must be either in-place or explicitly linked — never two unmarked records competing. A reconcile you recognized but skipped is not benign: it ships a known-wrong record to every future session.
