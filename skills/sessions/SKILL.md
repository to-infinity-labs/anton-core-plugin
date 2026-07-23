---
name: sessions
description: Browse past Claude Code session stats, history, and applied improvements. Use for "session stats", "how did my sessions go", or "what skills did I use". Pairs with `improvements` (action queue).
allowed-tools: Bash
---

## What it does

Read-only browser over the session-intelligence sidecar populated by the `SessionEnd` hook. Surfaces a thirty-day stats roll-up, a paginated recent-session list, per-session detail, and the historical applied-improvement log so the operator can audit how recent sessions have spent tools, time, and tokens.

## When to use

- "session stats", "how did my sessions go", "session history"
- "what skills did I use", `/anton-core:sessions`
- Auditing recent session activity, flag counts, or tool-usage histograms

## How

```
anton session list [--since <epoch-ms>] [--limit N]
anton session get --session-id <session-id>
anton session stats [--days N]
anton session mark-reflected --session-id <session-id>
```

`--since` is an epoch-ms Int64 floor on `started_at`, not a date string. Default invocation shells `session stats --days 30` together with `session list --limit 10` and renders both blocks. `--improvements` switches to the applied-only counterpart via `anton improvement list --applied-only --limit 20`; pending review flows through the [improvements](../improvements/SKILL.md) skill.

## Output

Per-verb envelopes: `session list` returns `{"status":"ok","count":N,"sessions":[{"session_id":"...","headline":"...","started_at":<epoch-ms>,"duration_minutes":N,...}]}`, where each row carries `has_flags:1` only when the session raised flags — the field is omitted when it would be `0`; `session stats` returns `{"period_days":N,"sessions":N,"avg_duration_minutes":N,"avg_messages":N,"flagged_sessions":N,"top_tools":{...},"improvements":N,"token_total":N}` — `token_total` sums each session's main-transcript token buckets (input + output + cache read + cache creation; subagent spend lives in the token-usage ledger, surfaced by [usage](../usage/SKILL.md)); `session mark-reflected` stamps `reflected_at` on the matching row and returns the standard ADR-0010 success envelope. Contract: [docs/plugin-spec/05-cli-contract.md#session-list](../../docs/plugin-spec/05-cli-contract.md#session-list).

## See also

- [`improvements`](../improvements/SKILL.md) — action queue for the deep-analysis suggestions surfaced here; `sessions` is the read-only audit.
