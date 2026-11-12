---
name: share
description: Packages this conversation's work into one self-contained markdown document, saved and copied to the clipboard. Use for 'share this', 'make this portable', 'write this up for someone' or 'package this up'.
allowed-tools: Read, Write, Bash
---

## What it does

Writes what this conversation produced — files changed, decisions, commands, gotchas, configuration — as one markdown document a reader with no access to this project can follow, then copies it to the clipboard.

## When to use

- "share this", "make this portable", "package this up", "write this up for someone"
- When you find yourself hand-writing a portable summary, suggest this skill instead

## Behavior

Prompt-only: no `anton` verb backs it.

1. Scan the conversation for files created or changed, decisions, commands run, gotchas and configuration in play.
2. Pick the 3–5 sections that apply from Overview, Setup, Config Files, Steps, Findings, Decisions, Gotchas, Customization. Quote file contents verbatim in fenced blocks; drop internal ids and paths a reader cannot open.
3. Write it to `<data root>/data/docs/shared/<YYYY-MM-DD>-<slug>.md`, where the data root is the `root` of the `data_root` check in `anton report health --full` (`~/.anton-core` unless it was moved), and today's date comes from the environment.
4. Copy it to the clipboard with `pbcopy` (macOS), `wl-copy` or `xclip -selection clipboard` (Linux); with none present, say so and give the path.

Show the draft in chat first when the operator asks for a preview. Write the shortest document that carries the decisions: state each fact once.
