---
name: save
description: Saves a durable fact, decision or correction to the knowledge base, in place of Claude Code's native auto memory. Use for capturing anything worth keeping across sessions, and gestures like 'save this' or 'remember this'.
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
anton item save [--source-path <file> | --items-json <array> | --items-file <file> | --type T --title T --content C [--summary S] [--importance F] [--relate <type>:<target-id> ...]] [--tag <name> ...]
```

Three modes share one verb. `--source-path` runs the full intake pipeline against a file on disk. `--items-json` (or `--items-file`) writes a pre-parsed batch straight through reconcile and write. `--type` + `--title` + `--content` is the single-item shorthand for narrative the operator already has typed up; it also accepts `--summary` and `--importance` (`[0.0, 1.0]`, default `1`). `--tag` (repeatable; one tag per occurrence) applies in every mode: each tag is merged into each item's tags and deduplicated. Give `--type` a canonical type — `document`, `reference`, `project`, `feedback`, `note`, `fact`, `decision`, or `question`; an unrecognized value is coerced to `note` (a known synonym folds to its target) and the original is preserved on a `raw_type:` tag, so a save never fails on an unexpected type.

## Batch shape

```json
[{"key": "ctx", "type": "note", "title": "Context", "content": "..."},
 {"type": "decision", "title": "Use X", "content": "...", "tags": ["arch"],
  "relations": [{"type": "supersedes", "target": "dec-1a2b3c4d"}, {"type": "relates_to", "target": "@ctx"}]}]
```

Every item needs `type`, `title` and `content`; `summary`, `tags`, `key` and `relations` are optional, and any other field rejects the batch. A relation's `type` is one of the `relate` verbs and its `target` is an existing id or `@<key>` naming another item in the batch. The whole batch is validated first and written in one transaction, so one bad item or missing target writes nothing. An item whose content already exists writes no row and no edges; a warning gives the `item relate` commands to assert them.

## Relate on save

Mode 3 also accepts `--relate <type>:<target-id>` (comma-separated or repeated) to assert an operator edge from the new item to an existing one at creation time, under the same closed rel-type vocabulary the `relate` skill uses (`relates_to`, `supersedes`, `part_of`, `resolves`; `updates` folds to `supersedes`). The new item is always the edge source. It is Mode-3 only — combining `--relate` with `--source-path`, `--items-json`, or `--items-file` fails `invalid_flag_combination`. Every target id and type is validated before the write, so a bad target or an unknown type rejects the whole save atomically: no item row, no edges. This is the create-and-link shortcut for the Curation flow below — save a correction and `supersedes`-link it over the stale note in one call.

## Output

Success envelope reports `status`, `written` (id list), `extracted`, `noop`, `rejected`, `type` (primary item type), `source_path`, `degraded_no_vector` (items a configured embedder left partly or wholly vectorless), `errors`, `warnings`, and `meta_used`, plus `saved_path` on a Mode 1 source copy, `relations_written` in Modes 2 and 3 (the count of manual edges written, `0` when none landed), and `keys` when a batch item carried one (each key's resolved id). `noop` is always an array: the id holding each item that wrote no row. `item save` returns `{"status":"ok","source_path":"...","type":"...","extracted":[...],"written":[...],"noop":[...],"rejected":N,"degraded_no_vector":N,"errors":[...],"warnings":[...],"meta_used":<true|false>}`. Contract: `item-save` in the anton-core CLI contract.

## Curation

Curate, don't accrete. Before saving, `memory recall` related memories; if the new note updates or corrects one that already exists, `item update --id <id>` (or `item delete`) it in place rather than appending a second, divergent version — in-place update stays the first choice. When the corrected memory must be **kept** — an audit trail, or a historical fact worth preserving — don't leave the pair unlinked: save the correction, then relate it to the superseded note with a `supersedes` edge (new → old) so a later `memory recall` renders a `superseded-by` marker on the stale hit instead of the two competing unmarked. Supersession must be either in-place or explicitly linked — never two unmarked records competing. A reconcile you recognized but skipped is not benign: it ships a known-wrong record to every future session.
