---
name: save
description: Saves a durable fact, decision, preference or correction to Anton Core's memory, in place of native auto memory. Use for 'remember that…', 'remember this', 'save this', 'note that we decided…' or 'store this'.
allowed-tools: Bash
---

## What it does

The one way content enters memory. Pasted text, a file or a pre-parsed batch goes through intake, is deduplicated against what is already stored, and is written with its relationships.

## When to use

- "remember that we decided X", "remember this", "save this", "store this", "add to kb"
- A decision, preference, correction or fact worth keeping across sessions
- After `extract` surfaces decisions worth persisting

## How

Run the command that fits with Bash, then answer from what it prints. Never answer before it has run: what the store holds is unknown until it does.

```
anton item save --type <type> --title <title> --content <text> [--summary S] [--importance F] [--relate <type>:<target-id> ...] [--tag <name> ...]
anton item save --source-path <file> [--tag <name> ...]
anton item save --items-json <array> | --items-file <file> [--tag <name> ...]
```

For a typed note, the first form. `--type` is one of `document`, `reference`, `project`, `feedback`, `note`, `fact`, `decision`, `question`; anything else is stored as `note` with the original kept on a `raw_type:` tag. `--importance` is `[0.0, 1.0]`, default 1. `--tag` takes one tag per occurrence. `--relate supersedes:<old-id>` links the new item over an existing one in the same write (first form only).

`--source-path` runs the full intake pipeline over a file. A batch is a JSON array of `{type, title, content}` objects with optional `summary`, `tags`, `key` and `relations` (`[{"type":"supersedes","target":"<id or @key>"}]`); any other field rejects it, and the whole batch is validated and written in one transaction.

## Output

`written` lists the new ids; `noop` lists the existing id for each item whose content was already stored, which wrote nothing. A `warnings` entry naming an item as unembedded means it is saved but not yet searchable by meaning. A failed pipeline save names in `error.written` the ids already committed, so report those rather than nothing.

Contract: `item-save` in the anton-core CLI contract.

## Curation

Before saving, `anton memory recall` what is already stored on the subject. If the new note corrects one, change that one in place with the [update](../update/SKILL.md) skill rather than adding a competing version. When the old record must be kept, save the correction with `--relate supersedes:<old-id>`, so recall marks the old hit superseded. Never leave two unmarked records disagreeing.
