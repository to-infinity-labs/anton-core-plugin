---
fragment-version: 3.0.0
---

# Anton Core

Anton Core is this setup's memory and code search, shared by every session and harness. Its skills load on demand: `/anton-core:<name>` in Claude Code, `$anton-core:<name>` in Codex. Setup turns the harness's native auto memory off; save here.

## What memory is for

A memory is a bet that something will matter again: what a later session could not recover from the repo, a transcript or the operator. Say how it was known (a command run, a file read, the operator's words, or an inference) and the trap it guards. Don't store what the environment already shows.

- `recall` before non-trivial work. When a memory disagrees with ground truth, `update` or `remove` it in that turn.
- Code questions (who calls, what breaks, where defined) go to the code-graph skills; grep is for text.

## Rules

1. Local scope only: search the current project unless told otherwise.
<!-- harness:claude -->
2. No shell on internal Claude Code paths (`.claude/projects/`): use Read + Write.
<!-- /harness -->
