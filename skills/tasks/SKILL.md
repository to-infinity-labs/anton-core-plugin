---
name: tasks
description: Add, list, complete, and update tasks in the operator's todo store. Use for "add task", "todo", "remind me to", "I need to", or "what tasks do I have".
allowed-tools: Bash
---

## What it does

Single operator surface for `Task`-typed items — list pending work, add new todos, update fields, complete entries, and surface due/overdue slices. The same store backs both manually-typed todos and action items extracted by the transcript pipeline, so every task surfaces through one query path.

## When to use

- "add task", "todo", "remind me to", "I need to"
- "what tasks do I have", `/anton-core:tasks`
- After `/anton-core:extract` surfaces action items worth persisting

## How

```
"${CLAUDE_PLUGIN_ROOT}/scripts/core" task add --title "..." [--priority high|medium|low] [--due <YYYY-MM-DD>] [--reminder <ts>] [--tag <name> ...] [--owner <name>] [--source-ref <id>] [--notes "..."]
"${CLAUDE_PLUGIN_ROOT}/scripts/core" task list [--status pending|in_progress|completed] [--owner <name>] [--due-before <date>] [--due-on <date>]
"${CLAUDE_PLUGIN_ROOT}/scripts/core" task due
"${CLAUDE_PLUGIN_ROOT}/scripts/core" task complete --id <task-id>
"${CLAUDE_PLUGIN_ROOT}/scripts/core" task update --id <task-id> [--title ...] [--status ...] [--priority ...] [--due ...] [--reminder ...] [--owner ...] [--notes ...]
```

The skill resolves natural-language dates ("tomorrow", "next monday", "in 3 days") before invoking the CLI; the handlers accept only ISO 8601 date strings. Default owner is read from `config.owner` via `"${CLAUDE_PLUGIN_ROOT}/scripts/core" config get --key owner`.

## Output

Per-verb envelopes: `task list` returns `{"tasks":[...],"count":N}`; `task add` returns `{"status":"ok","id":"task-NNN","title":"...","owner":"...","tags":[...]}` (with `noop:true` on idempotent re-add); `task complete` returns `{"status":"ok","id":"task-NNN","completed":<epoch-ms>}`; `task update` returns `{"status":"ok","task":{...}}` or `{"status":"ok","id":"task-NNN","message":"No changes"}` for a no-op. Errors surface as typed envelopes `{"error":{"kind":"...","detail":"..."}}`. Contract: [docs/plugin-spec/05-cli-contract.md#task-list](../../docs/plugin-spec/05-cli-contract.md#task-list).
