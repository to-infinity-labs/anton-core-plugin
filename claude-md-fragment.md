---
fragment-version: 1.8.0
---

# Anton Core

Personal AI assistant for knowledge, tasks, and daily productivity. Layers skills + hooks + SQLite (FTS5 + vector + graph) on top of Claude Code.

## Use Anton Core — Not the Defaults

Anton Core replaces Claude Code's default memory and code search in this setup, so use it for both.

### Memory — Anton Core is your memory layer

- **Save durable notes with `/anton-core:save`.** Decisions, preferences,
  corrections, facts and session learnings all go to Anton Core, the memory
  store here: setup turns Claude Code's native auto memory off and imports
  what it held. Where the operator kept native memory on, save to Anton Core
  all the same.
- **Recall before you reconstruct.** Before non-trivial work,
  `/anton-core:recall` what you already know, so you build on it rather than
  rebuilding it; widen with `expand` / `explore`.
- **Curate, don't accrete.** Before saving, `/anton-core:recall` related
  memories; if the new note updates or corrects one that already exists,
  `item update` (or `item delete`) it in place rather than appending a second
  version.
- **Reconcile a stale memory in the turn you spot it.** Stale means *no
  longer accurate*, not old. When a memory disagrees with ground truth (the PR
  merged, the task shipped, the fact changed), or you find yourself calling a
  memory "stale" or "outdated", `item update` it, `item delete` it, or complete
  the task in the same turn. The next session trusts what the store says, so a
  known-wrong record left in place misleads it.

### Code — the code graph is how you read code

- **Find and traverse symbols through the graph.** Resolve a symbol with
  `/anton-core:recall --code`, then walk it with `callers`, `callees`,
  `impact`, `paths`, `cycles`. The graph resolves bindings, where grep matches
  strings.
- **grep / `rg` is the fallback for code.** Use it for non-code text
  (comments, strings, config, prose), repos not indexed with Anton Core, or
  when the graph returns nothing. "Who calls X", "what does X touch" and
  "where's X defined" in an indexed repo are the graph's questions.

## Critical Rules

1. **Local scope only** — limit file searches to the current project unless explicitly told otherwise
2. **Meeting tasks are owner-only** — when extracting action items from transcripts, only create tasks for the configured owner, never other attendees
3. **Batch bulk operations** — process multi-repo or large-scale work in batches of 10–15 with checkpoint files, and never run 50+ items in one session, so a long run stays within one session's context and an interrupted one resumes from its checkpoint
4. **No Bash on internal Claude paths** — Don't `cp`/`mv`/`cat` paths containing `.claude/projects/`: it triggers an unbypassable sensitive-file prompt. Use Read + Write instead.

## Your Toolset

The tools you reach for while working. Each is a `/anton-core:<name>` skill; the command it runs uses noun-verb grammar (`anton <noun> <verb>`), shown below. The ⚙ rows under Intent Routing are the ones to use without being asked whenever a task matches the row; the rest run on request.

- **Memory** — save (`anton item save`), extract (`anton item extract`), bulk-import (`anton item bulk-import`), remove (`anton item delete`), recall (`anton memory recall`), expand (`anton item get`), explore (`anton memory explore`), relate (`anton item relate|unrelate`), share (prompt-only, no backing command)
- **Code Graph** — callers, callees, impact, paths, cycles — skills over the read-only `anton graph query <template>` surface (`--direction`, `--rel-types`); invoke them as `/anton-core:callers` etc.
- **Activity** — tasks (`anton task add|list|due|groups|complete|update`), summary (`anton report summary`), sessions (`anton session list|get|stats|mark-reflected`), improvements (`anton improvement list|approve|dismiss`), usage (`anton usage stats|doctor|span`)
- **System** — health (`anton report health`), dashboard (`anton dashboard`). Setup and maintenance are operator-invoked: when one is needed, ask the operator to run `/anton-core:setup` or `/anton-core:maintenance`

## Intent Routing

⚙ = use without being asked when the task matches the row.

| Intent | Skill | |
|---|---|---|
| Save / store / "remember this" | `/anton-core:save` | ⚙ |
| Search / recall / "find" | `/anton-core:recall` | ⚙ |
| Expand on an id | `/anton-core:expand` | ⚙ |
| Walk neighborhood | `/anton-core:explore` | ⚙ |
| Extract action items / decisions | `/anton-core:extract` | ⚙ |
| Link or unlink two memory items / "that edge is wrong" | `/anton-core:relate` | ⚙ |
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

- `~/.anton-core/data/` — content files (`knowledge/`, `inbox/`, `daily/`, `logs/`, `skill-logs/`)
- `${CLAUDE_PLUGIN_DATA}/data/` — `core.db`, state files
- `${CLAUDE_PLUGIN_DATA}/config/` — user-edited overrides
- `${CLAUDE_PLUGIN_ROOT}/` — read-only plugin source + templates

## Conventions

- **IDs**: prefixed by type — e.g. `conv-*`, `ref-*`, `task-*`
- **Dates**: verify today's date from env before creating date-based filenames
- **Binary invocation**: run the CLI as `anton <noun> <verb>` — the plugin's `bin/anton` launcher, which Claude Code puts on the Bash tool's `PATH` (main-session and subagent shells alike) while the plugin is enabled.
