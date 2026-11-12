---
name: usage
description: Reports model-token spend — totals, dollar estimates, per-model and per-project splits, plan headroom — and audits a session's numbers. Use for 'how much have I spent on tokens this week', 'what did that cost', 'token usage' or 'how much headroom is left'.
allowed-tools: Bash
---

## What it does

Reads the token-usage ledger that each session's end fills: totals, dollar estimates, per-model and per-project splits, main/subagent/aux lane shares, cache-hit ratio, and each harness's plan headroom. `doctor` recomputes a session from its transcript and says whether the ledger agrees; `span` measures a project straight from its live transcripts, so a running session counts before it reaches the ledger.

## When to use

- "how much have I spent this week", "what did last month cost", "token usage"
- "how much headroom is left", "when does my limit reset"
- "audit this session's tokens", "are these numbers right"

## How

Run the command that fits with Bash, then answer from what it prints. Never answer before it has run: what the store holds is unknown until it does.

```
anton usage stats [--window <Nd|duration>] [--project <slug>] [--harness claude|codex]
anton usage doctor --session-id <session-id> [--repair [--dry-run] [--accept-shrink]]
anton usage doctor --all [--repair [--dry-run]] [--quiet]
anton usage span --since <RFC3339> --project <transcript-dir> [--until <RFC3339>]
anton item extract --backfill [--force]
```

`--window` defaults to `30d`; "this week" is `7d`. Spend is dated by when it was spent, so backfilled history lands in its own period. `span --project` takes a transcript directory name — the launch path with every character outside `[A-Za-z0-9]` turned into `-` — not a path. An empty ledger is filled by `item extract --backfill`.

`doctor --repair` rewrites a session's ledger rows from the recompute when they drift, and refuses (`repair_refused: true`) when the recompute is missing tokens the ledger holds. `--accept-shrink` overrides that only once the operator has judged those tokens truly gone. `--dry-run` reports what a repair would do.

Headroom is recorded per harness. A harness that does not report it natively records it once `anton setup statusline` wires its status line. `anton usage statusline` is that hook's command, not one to run by hand.

## Output

Render, never dump the JSON. Dollars are estimates priced from a bundled list-price table plus the operator's `usage.pricing_overrides`: show them to the cent (`$2,904.01`), `<$0.01` below a cent, and a `null` figure as `n/a` with the `unpriced_models` beside it — never as zero. Headroom is one line per harness and window with its percentage and reset time; a reading older than 30 minutes is `stale`, a window past its reset prints `—`, and with no `headroom` key say it is unknown, never 0%. `doctor` gives a `result` of `match`, `drift`, `missing_ledger_rows` or `missing_transcript`.

Contract: `usage-stats`, `usage-doctor`, `usage-span`, `item-extract` in the anton-core CLI contract.

## See also

- [`sessions`](../sessions/SKILL.md) — per-session activity (main transcript only).
