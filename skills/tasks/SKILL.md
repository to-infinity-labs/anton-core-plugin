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
anton task add --title "..." [--priority high|medium|low] [--due <YYYY-MM-DD>] [--reminder <ts>] [--tag <name> ...] [--owner <name>] [--group <name>] [--source-ref <id>] [--notes "..."]
anton task list [--status pending|in_progress|completed] [--owner <name>] [--group <name>[,<name>...] | --all] [--due-before <date>] [--due-on <date>] [--limit N] [--ids-only]
anton task due [--mode overdue|today|soon|nudge-overdue|nudge-soon|reminders] [--owner <name>] [--group <name>] [--limit N]
anton task groups
anton task complete --id <task-id>
anton task update --id <task-id> [--title ...] [--status ...] [--priority ...] [--due ...] [--reminder ...] [--owner ...] [--group <name>] [--notes ...]
```

The skill resolves natural-language dates ("tomorrow", "next monday", "in 3 days") before invoking the CLI; the handlers accept only ISO 8601 date strings. Default owner is read from `config.owner` via `anton config get --key owner`.

**Group idiom.** Groups are a bare partition label — there is no create step; a group springs into existence the first time a task carries it. An agent writes its workstream slice with `anton task add --group <workstream>` and queries it back the same way (`anton task list --group <workstream>`), spanning two workstreams in one call with `--group a,b`; `anton task groups` enumerates what exists. A task with no group belongs to the inbox, so the operator's bare `anton task list` returns only the inbox and stays clean of agent workstream residue. Alarms (`task due`) and the daily summary stay global across every group by design.

## Output

Per-verb envelopes:

- `task list` returns `{"status":"ok","count":N,"tasks":[...]}`. A bare call returns the inbox (tasks with no group); `--group NAME[,NAME...]` slices to the named group(s), and `--all` returns every group — the two are mutually exclusive (combining them errors `invalid_flag_combination`). `--limit` (default 50) caps the row count; `--ids-only` swaps the body for `{"status":"ok","ids":[...]}` with no `tasks`/`count` siblings. Each task row carries `owner` and `group` only when set — the field is omitted, not blank, when unset.
- `task due` returns `{"status":"ok","mode":"<mode>","owner":"<filter>","count":N,"tasks":[...]}`. `mode` and `owner` echo the request (`owner` is `""` when unfiltered); `--mode` defaults to `overdue`, `--limit` to 3; `tasks` is `null` when nothing matches. Alarms stay global across every group by default; `--group NAME` narrows to one group, and each row carries `group` when the task has one.
- `task groups` returns `{"status":"ok","groups":[{"name":"...","open_count":N,"overdue_count":N,"total_count":N}],"inbox_open_count":N,"count":N}` — one row per live group, name-ascending, plus the open-task count of the inbox. It takes no flags; a completed-only group stays listed (with `open_count` 0) until its last task is purged.
- `task add` returns `{"status":"ok","id":"task-NNN","title":"...","tags":[...]}`, adding `"owner":"..."` only when `--owner` is supplied — owner values are title-cased (`bob` → `Bob`) — and `"group":"..."` only when `--group` is supplied. Group names are folded on write (lowercased, trimmed, spaces/underscores to hyphens); the reserved name `inbox` is rejected. A repeat `--source-ref` dedups to the existing id and sets `"noop":true`.
- `task complete` returns `{"status":"ok","task":{"id":"task-NNN","completed":<epoch-ms>}}`.
- `task update` returns `{"status":"ok","task":{...}}` — the full updated row, even when the new value equals the old one (there is no no-op short-circuit). `--group NAME` moves the task (folded, `inbox` reserved) and `--group ""` clears the group — the task returns to the inbox; either counts toward the at-least-one-field requirement. An update naming no fields errors `{"error":{"kind":"invalid_argument","detail":"invalid argument: at least one of --title, --status, --priority, --due, --reminder, --notes, --owner, --group must be supplied"}}`.

Errors surface as typed envelopes `{"error":{"kind":"...","detail":"..."}}`. Contract: [docs/plugin-spec/05-cli-contract.md#task-list](../../docs/plugin-spec/05-cli-contract.md#task-list).
