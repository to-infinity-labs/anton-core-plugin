---
name: extract
description: Pulls action items, decisions, key points and open questions out of meeting notes, a transcript or a document. Use for 'pull the action items out of these notes', 'what did we decide' or 'extract tasks from this'.
allowed-tools: Bash
---

## What it does

Reads unstructured content and returns its action items, decisions, key points and open questions. Each action item is marked for whether it belongs to the operator.

## When to use

- "pull the action items out of these notes", "extract tasks from this"
- "what did we decide", "what are the key points", "what are my to-dos from this meeting"
- A transcript, meeting notes or a pasted document to turn into structured items

## How

Run the command that fits with Bash, then answer from what it prints. Never answer before it has run: what the store holds is unknown until it does.

```
anton item extract [--source-path <file>] [--operator <name>] [--tasks-only]
```

Pasted content goes on stdin (`printf '%s' "<text>" | anton item extract`); a file goes in `--source-path`. `--operator` overrides the configured owner; `--tasks-only` returns the action items alone.

Meeting tasks are owner-only: create a task (the [tasks](../tasks/SKILL.md) skill) only for an action item marked `createTask: true`, which is the operator's own. Never create one for another attendee's item; list those for the operator instead. Decisions worth keeping go through [save](../save/SKILL.md).

## Output

`actionItems` (each with `description` and `createTask`), `decisions`, `keyPoints` and `openQuestions`. `extraction: "unavailable"` with a `reason` means the extractor did not run: report that, never that the content held no items.

Contract: `item-extract` in the anton-core CLI contract.
