---
name: bulk-import
description: Imports a whole directory of files into Anton Core's memory, resuming an interrupted run. Use for 'import every markdown file in a folder', 'bulk import this folder' or 'ingest this directory'. For one file, use `save`.
allowed-tools: Bash
---

## What it does

Walks a directory and sends each file through the same intake as `save`, in concurrent batches. Each imported file is tagged with its content hash, so a re-run skips what is already in and an interrupted run picks up where it stopped.

## When to use

- "import every markdown file in <dir>", "bulk import this folder", "ingest this directory"
- Backfilling memory from an existing knowledge folder

## How

Run the command that fits with Bash, then answer from what it prints. Never answer before it has run: what the store holds is unknown until it does.

```
anton item bulk-import --path <dir> [--recursive] [--dry-run] [--format json|jsonl|summary] [--concurrency N] [--consolidate]
```

Preview with `--dry-run` first and tell the operator the file count. `--recursive` walks subdirectories; `--format summary` gives one closing summary instead of a line per file. `--consolidate` builds the graph over the import straight after a clean run; without it, that happens in the daily pass.

Batch large work: when the import spans many directories or repos, run them 10–15 per batch with a checkpoint file recording which are done, and never more than 50 in one session, so a long run fits in one session's context and an interrupted one resumes from its checkpoint.

## Output

`imported`, `skipped` (already imported) and `errors`. `halted` with a `halt_reason` means the run stopped early, for example after repeated extractor failures; a re-run resumes it. A non-zero `degraded_no_vector` counts items saved without a vector, not yet searchable by meaning.

Contract: `item-bulk-import` in the anton-core CLI contract.
