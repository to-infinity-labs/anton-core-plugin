---
name: improvements
description: Review queue for deep-analysis improvement suggestions — list pending, approve, or dismiss. Use for "review improvements", "pending improvements", "apply improvement", or "what did deep analysis find". Pairs with `sessions` (read-only audit).
allowed-tools: Bash
---

## What it does

Operator-facing review queue for improvement suggestions emitted by the deep-analysis pass. Lists pending entries, lets the operator approve (record as adopted) or dismiss (delete the row), and re-prints the remaining count after each action. Deep analysis itself never edits files — this skill is the only path that flips improvement status.

## When to use

- "review improvements", "pending improvements", "apply improvement"
- "what did deep analysis find", `/anton-core:improvements`
- After session-end surfaces a fresh batch of suggestions for review

## How

```
"${CLAUDE_PLUGIN_ROOT}/scripts/core" improvement list [--pending-only] [--applied-only] [--limit N] [--since <epoch-ms|ISO-8601>]
"${CLAUDE_PLUGIN_ROOT}/scripts/core" improvement approve --id <imp-id>
"${CLAUDE_PLUGIN_ROOT}/scripts/core" improvement dismiss --id <imp-id>
```

The review queue defaults to pending entries (`--pending-only`); `--applied-only` surfaces the adopted set, and bare `improvement list` (no filter) returns both. `--since` restricts the list to rows created at or after a timestamp (epoch-ms or ISO 8601). `approve` flips `applied` from `0` to `1` and may optionally offer to execute the `action_taken` description — execution always requires explicit operator confirmation. `dismiss` deletes the sidecar row outright; the parent `items` row is preserved.

## Output

Per-verb envelopes (the `list`/`approve`/`dismiss` success shapes below are derived from `--json-schema` — the fixture holds no pending rows to exercise them live; the error shape is a live run): `improvement list --pending-only` returns `{"status":"ok","improvements":[{"item_id":"imp-NNN","category":"...","target":"...","applied":0,"date":<epoch-ms>}],"count":N}` — each row also carries `action_taken`, but only once an action is recorded; the field is omitted while a row is still pending. `improvement approve` returns `{"status":"approved","improvement":{"item_id":"imp-NNN"}}`; `improvement dismiss` returns `{"status":"dismissed","improvement":{"item_id":"imp-NNN"}}`. A missing id hard-errors with `{"error":{"kind":"entity_not_found","detail":"improvement \"<id>\" not found","entity_kind":"improvement","id":"<id>"}}`. Contract: [docs/plugin-spec/05-cli-contract.md#improvement-list](../../docs/plugin-spec/05-cli-contract.md#improvement-list).

## See also

- [`sessions`](../sessions/SKILL.md) — read-only audit of the session activity that produced these suggestions; `improvements` is the action queue.
