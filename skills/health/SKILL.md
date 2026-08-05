---
name: health
description: Diagnostic dashboard for anton-core's subsystems. Use for "health", "status", "is it working", or as a verification step after setup.
allowed-tools: Bash
---

## What it does

Read-only diagnostic surface. Composes per-subsystem panels (memory invariants, code-graph resolution, query-stats templates, retrieval intelligence, extractor and consolidation progress, infrastructure) into a single envelope, classifies overall severity, and writes one trend-tracking row to `events.health_log`. Non-healthy panels carry a remediation hint; when an automated repair exists the hint includes a `fix` — the exact command to run (e.g. `anton maintenance repair --target fts` for a corrupt full-text index) — which the readout surfaces verbatim so the operator can act without a second roundtrip.

## When to use

- "health", "status", "is it working"
- "system check", "diagnostics", `/anton-core:health`
- Verification step after `/anton-core:setup` or before a long session

## How

```
anton report health [--full] [--trend]
```

Default invocation returns the roll-up only: overall `severity`, the per-subsystem `checks` array (each carrying a remediation hint when not healthy), and a one-line `summary`. `--full` adds the `counts`, `memory`, `remediation`, and `system` breakdown panels; `--trend` adds the ten-row trend rollup from `events.health_log` classifying each panel as Improving / Stable / Degrading.

## Output

Single standard result envelope. The default form is `{"status":"ok","report":{"severity":...,"checks":[...],"summary":...}}` — only `severity`, `checks`, and `summary` are always present. `--full` extends `report` with the `counts`, `memory`, `remediation`, and `system` panels; each `remediation` hint may include a `fix` command (e.g. `anton maintenance repair --target fts`), which the readout surfaces verbatim so the operator can run the repair directly. Severity rolls up per-panel statuses: any `critical` → `critical`; any `warning` or `degraded` → `warning`; otherwise `healthy`. The `extractor` check carries four consolidation facts on every measured run — `consolidation_backlog_items` (items created since the link pass last advanced its cursor, the unscanned window rather than the pair backlog), `judged_pairs_total`, `judged_pairs_last_pass`, `judge_refusals_total` — and reports `warning` when the last three link passes all stopped on budget and all settled nothing new, with a remediation `fix` naming `link.max_budget_usd`. A read failure never manufactures a stall and never hides one: the four facts are withheld together and replaced by `consolidation_facts_error` (the last-consolidation banner by `last_consolidation_error`), so an unreadable store is distinguishable from a healthy one and from a check with no store wired, whose keys are simply absent. Contract: `report-health` in the anton-core CLI contract.
