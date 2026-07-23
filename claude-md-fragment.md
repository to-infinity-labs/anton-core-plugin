---
fragment-version: 1.6.0
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
- **Curate, don't accrete.** Before saving, `/anton-core:recall` related
  memories; if the new note updates or corrects one that already exists,
  `item update` (or `item delete`) it in place rather than appending a second
  version.
- **You own the store — reconcile stale memories in the turn you spot them.**
  Stale means *no longer accurate*, not old. The moment you determine a memory
  disagrees with ground truth — you verified the PR merged, the task shipped,
  the fact changed — or you catch yourself telling the operator a memory is
  "stale" or "outdated": updating that record is now part of the current task.
  `item update` it, `item delete` it, or complete the task **in the same turn,
  before moving on**. Flagging staleness without fixing it is leaving a known
  bug in your own memory — the next session will trust what you knew was wrong.

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

The tools you reach for while working. Memory and Code Graph are agent-primary — use them by default, not on request. Each is a `/anton-core:<name>` skill; the command it runs uses noun-verb grammar (`anton <noun> <verb>`), shown below so you invoke the real command, not a bare verb.

- **Memory** — save (`anton item save`), extract (`anton item extract`), bulk-import (`anton item bulk-import`), remove (`anton item delete`), recall (`anton memory recall`), expand (`anton item get`), explore (`anton memory explore`), share (prompt-only, no backing command)
- **Code Graph** — callers, callees, impact, paths, cycles — skills over the read-only `anton graph query <template>` surface (`--direction`, `--rel-types`); invoke as `/anton-core:callers` etc., never a bare command
- **Activity** — tasks (`anton task add|list|due|groups|complete|update`), summary (`anton report summary`), sessions (`anton session list|get|stats|mark-reflected`), improvements (`anton improvement list|approve|dismiss`), usage (`anton usage stats|doctor`)
- **System** — setup (`anton setup probe|link-shell|install-daemon|…`), health (`anton report health`), maintenance (`anton maintenance run|dedup|purge|prune|…`), dashboard (`anton dashboard`)

## Intent Routing

⚙ = agent-primary tool; reach for it by default.

| Intent | Skill | |
|---|---|---|
| Save / store / "remember this" | `/anton-core:save` | ⚙ |
| Search / recall / "find" | `/anton-core:recall` | ⚙ |
| Expand on an id | `/anton-core:expand` | ⚙ |
| Walk neighborhood | `/anton-core:explore` | ⚙ |
| Extract action items / decisions | `/anton-core:extract` | ⚙ |
| Relate / link / unrelate two memory items | `/anton-core:relate` | ⚙ |
| Unlink / "that edge is wrong" | `/anton-core:relate` | ⚙ |
| Who calls a symbol | `/anton-core:callers` | ⚙ |
| What a symbol calls | `/anton-core:callees` | ⚙ |
| Blast radius of a change | `/anton-core:impact` | ⚙ |
| Path between two symbols | `/anton-core:paths` | ⚙ |
| Cycle detection | `/anton-core:cycles` | ⚙ |
| Add task / reminder | `/anton-core:tasks add` | |
| Daily briefing | `/anton-core:summary` | |
| Token spend / "what did that cost" | `/anton-core:usage` | |
| Audit a session's token numbers | `/anton-core:usage --session-id <id>` | |
| Health / status | `/anton-core:health` | |
| Open the browser dashboard | `/anton-core:dashboard [surface]` | |

## Data Layout

- `~/.anton-core/data/` — content files (`knowledge/`, `inbox/`, `daily/`, `logs/`)
- `${CLAUDE_PLUGIN_DATA}/data/` — `core.db`, state files
- `${CLAUDE_PLUGIN_DATA}/config/` — user-edited overrides
- `${CLAUDE_PLUGIN_ROOT}/` — read-only plugin source + templates

## Conventions

- **IDs**: prefixed — `conv-*`, `ref-*`, `task-*`
- **Naming**: internal files use "core"; "Anton" only in CLAUDE.md — plus the one model-facing exception, the `anton` command
- **Dates**: verify today's date from env before creating date-based filenames
- **Binary invocation**: skill bodies invoke the binary as `anton <noun> <verb>` — the plugin's `bin/anton` launcher, which Claude Code puts on the Bash tool's `PATH` (in main-session and subagent shells alike) whenever the plugin is enabled, and which execs `scripts/core` so the shim keeps handling pin resolution, precondition envelopes, and the data-dir env-var translation. Bare `core <noun> <verb>` in skill prose documents the operator-facing shell command, available via the optional `~/.local/bin/core` symlink that `/anton-core:setup` creates. Never invoke a bare `core` from a skill body — it is the operator launcher and bypasses the shim's pin gate.
