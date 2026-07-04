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
"${CLAUDE_PLUGIN_ROOT}/scripts/core" task list [--status pending|in_progress|completed] [--owner <name>] [--due-before <date>] [--due-on <date>] [--limit N] [--ids-only]
"${CLAUDE_PLUGIN_ROOT}/scripts/core" task due [--mode overdue|today|soon|nudge-overdue|nudge-soon|reminders] [--owner <name>] [--limit N]
"${CLAUDE_PLUGIN_ROOT}/scripts/core" task complete --id <task-id>
"${CLAUDE_PLUGIN_ROOT}/scripts/core" task update --id <task-id> [--title ...] [--status ...] [--priority ...] [--due ...] [--reminder ...] [--owner ...] [--notes ...]
```

The skill resolves natural-language dates ("tomorrow", "next monday", "in 3 days") before invoking the CLI; the handlers accept only ISO 8601 date strings. Default owner is read from `config.owner` via `"${CLAUDE_PLUGIN_ROOT}/scripts/core" config get --key owner`.

## Output

Per-verb envelopes:

- `task list` returns `{"status":"ok","count":N,"tasks":[...]}`. `--limit` (default 50) caps the row count; `--ids-only` swaps the body for `{"status":"ok","ids":[...]}` with no `tasks`/`count` siblings. Each task row carries `owner` only when one is set — the field is omitted, not blank, when unset.
- `task due` returns `{"status":"ok","mode":"<mode>","owner":"<filter>","count":N,"tasks":[...]}`. `mode` and `owner` echo the request (`owner` is `""` when unfiltered); `--mode` defaults to `overdue`, `--limit` to 3; `tasks` is `null` when nothing matches.
- `task add` returns `{"status":"ok","id":"task-NNN","title":"...","tags":[...]}`, adding `"owner":"..."` only when `--owner` is supplied — owner values are title-cased (`bob` → `Bob`). A repeat `--source-ref` dedups to the existing id and sets `"noop":true`.
- `task complete` returns `{"status":"ok","task":{"id":"task-NNN","completed":<epoch-ms>}}`.
- `task update` returns `{"status":"ok","task":{...}}` — the full updated row, even when the new value equals the old one (there is no no-op short-circuit). An update naming no fields errors `{"error":{"kind":"invalid_argument","detail":"invalid argument: at least one of --title, --status, --priority, --due, --reminder, --notes, --owner must be supplied"}}`.

Errors surface as typed envelopes `{"error":{"kind":"...","detail":"..."}}`. Contract: [docs/plugin-spec/05-cli-contract.md#task-list](../../docs/plugin-spec/05-cli-contract.md#task-list).
