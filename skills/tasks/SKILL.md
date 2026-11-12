---
name: tasks
description: Adds, lists, completes and updates the operator's own to-dos and reminders, kept in Anton Core across sessions. Use for 'remind me to … next Friday', 'add a task', 'I need to …', 'what tasks do I have open' or 'mark that done'. These are the operator's tasks, not this session's work list, and a reminder is a dated to-do, not a scheduled agent run.
allowed-tools: Bash
---

## What it does

The operator's task list: add, list, update and complete tasks, and pull the overdue, due-today and reminder slices. Tasks the transcript pipeline extracts land in the same store.

## When to use

- "remind me to X next Friday", "add a task", "todo", "I need to X"
- "what tasks do I have open", "what's overdue", "mark that done"
- After `extract` returns action items the operator owns

## How

Run the command that fits with Bash, then answer from what it prints. Never answer before it has run: what the store holds is unknown until it does.

```
anton task add --title "..." [--due <YYYY-MM-DD>] [--reminder <YYYY-MM-DD>] [--priority high|medium|low] [--tag <name> ...] [--owner <name>] [--group <name>] [--notes "..."]
anton task list [--status pending|in_progress|completed] [--group <name>[,<name>...] | --all] [--due-before <YYYY-MM-DD>] [--limit N]
anton task due [--mode overdue|today|soon|nudge-overdue|nudge-soon|reminders] [--limit N]
anton task complete --id <task-id>
anton task update --id <task-id> [--title ...] [--status ...] [--priority ...] [--due ...] [--reminder ...] [--owner ...] [--group <name>] [--notes ...]
anton task groups
```

Turn a spoken date ("next Friday", "in 3 days") into `YYYY-MM-DD` from today's date before calling; the verbs take ISO dates only. "Remind me to X on D" is `task add --title X --due D --reminder D`. `--tag` takes one tag per occurrence. Ids are `task-<16 hex>`: to complete or update a task named in words, find its id with `task list` first.

Groups are labels that exist once a task carries one. A bare `task list` shows the inbox (tasks with no group), `--group a,b` those groups, `--all` everything. An agent keeps its own workstream in a group so the operator's inbox stays clean; `task due` and the daily briefing cover every group.

## Output

`task add` returns the new task's `id`; a repeated `--source-ref` returns the existing id with `noop: true`. `task list` and `task due` return `tasks`, each with `owner` and `group` only when set; `task due` defaults to `--mode overdue` and three rows. `task update` needs at least one field and returns the full row.

Contract: `task-add`, `task-list`, `task-due`, `task-complete`, `task-update`, `task-groups` in the anton-core CLI contract.
