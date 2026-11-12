---
name: health
description: Checks whether Anton Core is working — memory store, code graph, search, extractor, infrastructure — and names the fix for anything broken. Use for 'run a health check', 'is anything broken', 'is it working' or after setup.
allowed-tools: Bash
---

## What it does

A read-only diagnostic over every subsystem. It rolls each check up into one severity (`healthy`, `warning`, `critical`) and records a row for the trend.

## When to use

- "run a health check", "is anything broken", "is it working", "system check"
- Verifying an install after `setup`, or before a long session

## How

Run the command that fits with Bash, then answer from what it prints. Never answer before it has run: what the store holds is unknown until it does.

```
anton report health [--full] [--trend]
anton report recall --days 30
```

Start with the bare form. When it is not healthy, rerun with `--full`: remediation hints, and the exact `fix` command for each broken check, appear only under `--full`. `--trend` adds whether each check is improving, stable or degrading. `report recall` compares how often recall hits are expanded against the window before it; present it as a trend, not a verdict.

## Output

`severity`, `checks` (one per subsystem, with its status) and a one-line `summary`. Under `--full`, quote each `fix` verbatim so the operator can run it, including those on `quarantined_files` entries, which carry a `fix` even when that check reads healthy. A check's `*_error` field means it could not read its store: say the check is unknown, never healthy.

Contract: `report-health`, `report-recall` in the anton-core CLI contract.
