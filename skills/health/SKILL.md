---
name: health
description: Diagnostic dashboard for anton-core's subsystems. Use for "health", "status", "is it working", or as a verification step after setup.
allowed-tools: Bash
---

## What it does

Read-only diagnostic surface. Composes per-subsystem panels (memory invariants, code-graph resolution, query-stats templates, retrieval intelligence, infrastructure) into a single envelope, classifies overall severity, and writes one trend-tracking row to `events.health_log`. Non-healthy panels carry a remediation hint so the operator can act without a second roundtrip.

## When to use

- "health", "status", "is it working"
- "system check", "diagnostics", `/anton-core:health`
- Verification step after `/anton-core:setup` or before a long session

## How

```
"${CLAUDE_PLUGIN_ROOT}/scripts/core" report health [--full] [--trend]
```

Default invocation renders Sections A–E (status header, checks with remediations, knowledge base counts, code-graph block with empty-state suppression, infrastructure, retrieval intelligence). `--full` adds per-panel breakdowns; `--trend` adds the ten-row trend rollup from `events.health_log` classifying each panel as Improving / Stable / Degrading.

## Output

Single ADR-0010 envelope of the form `{"status":"ok","report":{"severity":...,"checks":[...],"summary":...,"counts":...,"memory":...,"remediation":[...]}}`. Severity rolls up per-panel statuses: any `critical` → `critical`; any `warning` or `degraded` → `warning`; otherwise `healthy`. Contract: [docs/plugin-spec/05-cli-contract.md#report-health](../../docs/plugin-spec/05-cli-contract.md#report-health).
