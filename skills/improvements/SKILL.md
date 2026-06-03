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
"${CLAUDE_PLUGIN_ROOT}/scripts/core" improvement list [--pending-only] [--applied-only] [--limit N]
"${CLAUDE_PLUGIN_ROOT}/scripts/core" improvement approve --id <imp-id>
"${CLAUDE_PLUGIN_ROOT}/scripts/core" improvement dismiss --id <imp-id>
```

Default `list` mode filters to pending entries; `--all` drops the filter and includes already-applied rows. `approve` flips `applied` from `0` to `1` and may optionally offer to execute the `action_taken` description — execution always requires explicit operator confirmation. `dismiss` deletes the sidecar row outright; the parent `items` row is preserved.

## Output

Per-verb envelopes: `improvement list --pending-only` returns `{"improvements":[{"item_id":"imp-NNN","category":"...","target":"...","action_taken":"...","applied":0,"date":<epoch-ms>}],"count":N}`; `improvement approve` returns `{"status":"approved","item_id":"imp-NNN"}`; `improvement dismiss` returns `{"status":"dismissed","item_id":"imp-NNN"}`. Missing ids hard-error with `{"error":{"kind":"entity_not_found","detail":"Improvement not found: <id>","entity_id":"<id>"}}`. Contract: [docs/plugin-spec/05-cli-contract.md#improvement-list](../../docs/plugin-spec/05-cli-contract.md#improvement-list).

## See also

- [`sessions`](../sessions/SKILL.md) — read-only audit of the session activity that produced these suggestions; `improvements` is the action queue.
