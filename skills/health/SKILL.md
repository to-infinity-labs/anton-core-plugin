---
name: health
description: Diagnostic dashboard for anton-core's subsystems. Use for "health", "status", "is it working", or as a verification step after setup.
allowed-tools: Bash
---

## What it does

Read-only diagnostic surface. Composes per-subsystem panels (memory invariants, code-graph resolution, query-stats templates, retrieval intelligence, infrastructure) into a single envelope, classifies overall severity, and writes one trend-tracking row to `events.health_log`. Non-healthy panels carry a remediation hint; when an automated repair exists the hint includes a `fix` — the exact command to run (e.g. `anton maintenance repair --target fts` for a corrupt full-text index) — which the readout surfaces verbatim so the operator can act without a second roundtrip.

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

Single ADR-0010 envelope. The default form is `{"status":"ok","report":{"severity":...,"checks":[...],"summary":...}}` — only `severity`, `checks`, and `summary` are always present. `--full` extends `report` with the `counts`, `memory`, `remediation`, and `system` panels; each `remediation` hint may include a `fix` command (e.g. `anton maintenance repair --target fts`), which the readout surfaces verbatim so the operator can run the repair directly. Severity rolls up per-panel statuses: any `critical` → `critical`; any `warning` or `degraded` → `warning`; otherwise `healthy`. Contract: [docs/plugin-spec/05-cli-contract.md#report-health](../../docs/plugin-spec/05-cli-contract.md#report-health).
