---
name: share
description: Package the current conversation work into a self-contained markdown document, saved to disk and copied to clipboard. Use for "share this", "make this portable", or "package this up".
allowed-tools: Read, Write, Bash
---

## What it does

Packages whatever the operator and assistant have been working on in the current conversation into a single self-contained markdown document — readable by anyone without access to this project, this database, or any prior context. Writes the file under the operator's shared-docs directory and copies the contents to the system clipboard.

## When to use

- "share this", "make this portable", "package this up"
- `/anton-core:share <description>` with a 2-4 word slug of what to package
- When the assistant notices itself hand-crafting a portable document — stripping internal references, copying file contents verbatim, writing a self-contained intro — proactively suggest this skill rather than continue ad-hoc

## Behavior

This skill is **prompt-only** — no `core` CLI verb backs it. The handler is the assistant following the steps below; `How` / `Output` sections are omitted by design (see acceptance `A-plugin-4`).

The skill scans the live conversation for files created or modified, decisions made, commands run, gotchas surfaced, and configuration in play; picks 3–5 sections from a fixed pool (Overview, Setup Prompt, Config Files, Process / Steps, Findings, Decisions, Gotchas, Customization) by relevance; writes a self-contained markdown document under `~/.anton-core/data/docs/shared/<YYYY-MM-DD>-<slug>.md` with file contents verbatim in fenced code blocks; and copies the file to the system clipboard via the platform-specific adapter (`pbcopy` / `clip.exe` / `xclip`). `--dry-run` previews in chat first; `--no-clipboard` skips the clipboard copy.
