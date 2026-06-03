---
fragment-version: 1.1.0
---

# Anton Core

Personal AI assistant for knowledge, tasks, and daily productivity. Layers skills + hooks + SQLite (FTS5 + vector + graph) on top of Claude Code.

## Use Anton Core — Not the Defaults

These OVERRIDE Claude Code's default memory and code-search behavior. Not suggestions.

### Memory — Anton Core is your memory layer

- **Persist through `/anton-core:save`. Every time.** Decisions, preferences,
  corrections, facts, session learnings — all durable notes go to Anton Core.
  Do NOT create or edit files under `~/.claude/projects/**/memory/` or
  `MEMORY.md`. That native store is superseded for writes; writing to it splits your
  memory in two.
- **Recall before you reconstruct.** Starting any non-trivial task, run
  `/anton-core:recall` to pull what you already know; widen with `expand` /
  `explore`. Don't rebuild from scratch what you've already saved.
- "Remember this" / "save that" / anything worth a future session →
  `/anton-core:save`.

### Code — the code graph is how you read code

- **Find and traverse symbols through the graph, not grep.** Resolve a symbol
  with `/anton-core:recall --code`, then walk it with `callers`, `callees`,
  `impact`, `paths`, `cycles`. The graph exists for exactly this — grepping
  code structure while it sits idle wastes it.
- **grep / `rg` is the fallback, never the default for code.** Use it only
  for: non-code text (comments, strings, config, prose), repos not
  registered/indexed with Anton Core, tier-2 languages, or when the graph
  returns nothing. "Who calls X", "what does X touch", "where's X defined"
  in an indexed repo → the graph answers, not grep.

## Critical Rules

1. **Local scope only** — limit file searches to the current project unless explicitly told otherwise
2. **Meeting tasks are owner-only** — when extracting action items from transcripts, only create tasks for the configured owner, never other attendees
3. **Batch bulk operations** — process multi-repo or large-scale work in batches of 10–15 with checkpoint files; never run 50+ items in one session
4. **No Bash on internal Claude paths** — NEVER `cp`/`mv`/`cat` paths containing `.claude/projects/` (triggers an unbypassable sensitive-file prompt). Use Read + Write instead.

## Your Toolset

The tools you reach for while working. Memory and Code Graph are agent-primary — use them by default, not on request.

- **Memory** — `save`, `extract`, `bulk-import`, `remove`, `recall`, `expand`, `explore`, `share`
- **Code Graph** — `callers`, `callees`, `impact`, `paths`, `cycles`
- **Activity** — `tasks`, `summary`, `sessions`, `improvements`, `news`
- **System** — `setup`, `health`, `maintenance`

## Intent Routing

⚙ = agent-primary tool; reach for it by default.

| Intent | Skill | |
|---|---|---|
| Save / store / "remember this" | `/anton-core:save` | ⚙ |
| Search / recall / "find" | `/anton-core:recall` | ⚙ |
| Expand on an id | `/anton-core:expand` | ⚙ |
| Walk neighborhood | `/anton-core:explore` | ⚙ |
| Extract action items / decisions | `/anton-core:extract` | ⚙ |
| Who calls a symbol | `/anton-core:callers` | ⚙ |
| What a symbol calls | `/anton-core:callees` | ⚙ |
| Blast radius of a change | `/anton-core:impact` | ⚙ |
| Path between two symbols | `/anton-core:paths` | ⚙ |
| Cycle detection | `/anton-core:cycles` | ⚙ |
| Add task / reminder | `/anton-core:tasks add` | |
| Daily briefing | `/anton-core:summary` | |
| Health / status | `/anton-core:health` | |

## Data Layout

- `~/.anton-core/data/` — content files (`knowledge/`, `inbox/`, `daily/`, `logs/`)
- `${CLAUDE_PLUGIN_DATA}/data/` — `core.db`, state files
- `${CLAUDE_PLUGIN_DATA}/config/` — user-edited overrides
- `${CLAUDE_PLUGIN_ROOT}/` — read-only plugin source + templates

## Conventions

- **IDs**: prefixed — `conv-*`, `ref-*`, `task-*`
- **Naming**: internal files use "core"; "Anton" only in CLAUDE.md
- **Dates**: verify today's date from env before creating date-based filenames
- **Binary invocation**: skill bodies invoke the binary as `"${CLAUDE_PLUGIN_ROOT}/scripts/core" <verb>` — the shim handles bootstrap, path resolution, and the data-dir env-var translation. Bare `core <verb>` in skill prose documents the operator-facing shell command, available via the optional `~/.local/bin/core` symlink that `/anton-core:setup` creates. Never invoke a bare `core` from a skill body — it isn't on `$PATH` in subagent contexts.
