---
name: bulk-import
description: Batch-import a directory of files into the knowledge base, resuming from a checkpoint on interruption. Use for "bulk import this folder", "import this directory", or "ingest this directory".
allowed-tools: Bash
---

## What it does

Walks a directory, classifies each file, and routes every file through the same intake pipeline as `save`. Updates a checkpoint after each success so an interrupted run resumes without redoing completed files. Two paths share one dispatcher: in-session orchestration with batched concurrency, and an out-of-session CLI executor for unattended runs.

## When to use

- "bulk import this folder", "import this directory", "ingest this directory"
- `/anton-core:bulk-import` against a known content tree
- Backfilling a fresh database from an existing knowledge folder

## How

```
"${CLAUDE_PLUGIN_ROOT}/scripts/core" item bulk-import --path <dir> [--recursive] [--dry-run] [--format json|jsonl|summary] [--concurrency N] [--quiet]
```

Use `--dry-run` first to preview the file count and classification before any write. Re-running against an unchanged, completed directory skips every file via its stored source hash (no extraction cost); the checkpoint only resumes an *interrupted* run. `--format` defaults to `jsonl` (streaming); `--concurrency` sets the per-batch concurrent save count (>= 1, default 3).

## Output

Success envelope reports `status`, `imported`, `skipped`, `by_type`, `noop_count`, `stub_documents_written`, `copies_written`, `copy_failures`, `meta_used`, and `errors` (plus `degraded_no_vector` and `halted` when non-zero / on a halt). Streaming mode emits one JSONL line per file plus a final `{"summary": true, ...}` line. Contract: [docs/plugin-spec/05-cli-contract.md#item-bulk-import](../../docs/plugin-spec/05-cli-contract.md#item-bulk-import).
