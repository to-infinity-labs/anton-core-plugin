---
name: extract
description: Your tool for pulling action items, decisions, key points, and open questions out of unstructured content. Use for turning a transcript or notes into structured items, and gestures like 'extract tasks' or 'what did we decide'. Reach for it before reading raw text.
allowed-tools: Bash
---

## What it does

Analyses content — pasted text, file path, or content already saved by another skill — and emits a structured envelope of action items, decisions, key points, and open questions. Operates in two modes: a standalone interactive surface, and a silent pipeline stage chained from `save`.

## When to use

- "extract tasks from this", "what action items are here", "pull out facts"
- "what did we decide", "what are the key points"
- Standalone review of a transcript, meeting notes, or pasted document

## How

```
"${CLAUDE_PLUGIN_ROOT}/scripts/core" item extract [--source-path <file>] [--source-ref <ref>] [--operator <name>] [--tasks-only] [--pipeline] [--metadata-only] [--output json|yaml]
```

Standalone mode reads from `--source-path` (or stdin) and emits the structured envelope. Pipeline mode (`--pipeline`) emits the relationships array so downstream stages of an intake chain can consume them silently. `--operator` overrides the configured owner for the action-item filter.

## Output

Success envelope carries `sourceRef`, `actionItems`, `decisions`, `keyPoints`, `openQuestions`, and (under `--pipeline`) `relationships`. The owner filter marks each action item with `createTask: true` or `false` based on assignee. Contract: [docs/plugin-spec/05-cli-contract.md#item-extract](../../docs/plugin-spec/05-cli-contract.md#item-extract).
