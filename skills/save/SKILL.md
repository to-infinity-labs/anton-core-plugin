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
"${CLAUDE_PLUGIN_ROOT}/scripts/core" item save [--source-path <file> | --items-json <array> | --type T --title T --content C]
```

Three modes share one verb. `--source-path` runs the full intake pipeline against a file on disk. `--items-json` (or `--items-file`) writes a pre-parsed batch straight through reconcile and write. `--type` + `--title` + `--content` is the single-item shorthand for narrative the operator already has typed up.

## Output

Success envelope reports `pipeline`, `written` (id list), `noop`, `rejected`, `counts`, `dropped_by_owner_filter`, and `stub_documents_written`. Contract: [docs/plugin-spec/05-cli-contract.md#item-save](../../docs/plugin-spec/05-cli-contract.md#item-save).
