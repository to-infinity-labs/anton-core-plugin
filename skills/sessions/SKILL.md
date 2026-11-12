---
name: sessions
description: Reviews how past coding sessions went — counts, durations, tools used, flags, tokens. Use for 'how did my coding sessions go this week', 'session stats', 'session history' or 'what tools did I use'.
allowed-tools: Bash
---

## What it does

Read-only view of what the session-end pass recorded about each session: a rollup over N days, a recent list, one session's detail, and the log of improvements already applied.

## When to use

- "how did my sessions go this week", "session stats", "session history"
- "what tools did I use", "which sessions were flagged", "show me session <id>"

## How

Run the command that fits with Bash, then answer from what it prints. Never answer before it has run: what the store holds is unknown until it does.

```
anton session stats [--days N] [--harness claude|codex]
anton session list [--since <epoch-ms>] [--limit N] [--harness claude|codex]
anton session get --session-id <session-id>
anton improvement list --applied-only [--limit N]
```

By default run `session stats --days 30` and `session list --limit 10` together; "this week" is `--days 7`. `--since` is epoch milliseconds, not a date.

## Output

`session stats` gives the session count, average duration and messages, flagged sessions, the top tools and `token_total` — main-transcript tokens only; subagent spend is in the [usage](../usage/SKILL.md) ledger. A list row carries `has_flags: 1` only when the session raised flags.

Contract: `session-stats`, `session-list`, `session-get`, `improvement-list` in the anton-core CLI contract.

## See also

- [`improvements`](../improvements/SKILL.md) — acts on the suggestions those sessions produced.
