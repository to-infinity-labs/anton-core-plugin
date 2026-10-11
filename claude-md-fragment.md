---
fragment-version: 1.9.0
---

# Anton Core

Personal AI assistant for knowledge, tasks, and daily productivity. Layers skills + hooks + SQLite (FTS5 + vector + graph) on top of your coding harness, Claude Code or Codex.

## Use Anton Core — Not the Defaults

Anton Core replaces the harness's default memory and code search in this setup, so use it for both.

### Memory — Anton Core is your memory layer

- **Save durable notes with the `save` skill.** Decisions, preferences,
  corrections, facts and session learnings all go to Anton Core, the memory
  store here: setup turns the harness's native auto memory off and imports
  what it held. Where the operator kept native memory on, save to Anton Core
  all the same.
- **Recall before you reconstruct.** Before non-trivial work,
  `recall` what you already know, so you build on it rather than
  rebuilding it; widen with `expand` / `explore`.
- **Curate, don't accrete.** Before saving, `recall` related
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
  `recall --code`, then walk it with `callers`, `callees`,
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
4. **No shell on internal Claude Code paths** — In Claude Code, don't `cp`/`mv`/`cat` paths containing `.claude/projects/`: it triggers an unbypassable sensitive-file prompt. Use Read + Write instead.

## Your Toolset

The tools you reach for while working. Each is an anton-core skill, named bare below: invoke it as `/anton-core:<name>` in Claude Code and `$anton-core:<name>` in Codex. The command it runs uses noun-verb grammar (`anton <noun> <verb>`), shown below. The ⚙ rows under Intent Routing are the ones to use without being asked whenever a task matches the row; the rest run on request.

- **Memory** — save (`anton item save`), extract (`anton item extract`), bulk-import (`anton item bulk-import`), remove (`anton item delete`), recall (`anton memory recall`), expand (`anton item get`), explore (`anton memory explore`), relate (`anton item relate|unrelate`), share (prompt-only, no backing command)
- **Code Graph** — callers, callees, impact, paths, cycles — skills over the read-only `anton graph query <template>` surface (`--direction`, `--rel-types`); invoke them as the `callers` skill etc.
- **Activity** — tasks (`anton task add|list|due|groups|complete|update`), summary (`anton report summary`), sessions (`anton session list|get|stats|mark-reflected`), improvements (`anton improvement list|approve|dismiss`), usage (`anton usage stats|doctor|span`)
- **System** — health (`anton report health`), dashboard (`anton dashboard`). Setup and maintenance are operator-invoked: when one is needed, ask the operator to run the `setup` or `maintenance` skill

## Intent Routing

⚙ = use without being asked when the task matches the row.

| Intent | Skill | |
|---|---|---|
| Save / store / "remember this" | `save` | ⚙ |
| Search / recall / "find" | `recall` | ⚙ |
| Expand on an id | `expand` | ⚙ |
| Walk neighborhood | `explore` | ⚙ |
| Extract action items / decisions | `extract` | ⚙ |
| Link or unlink two memory items / "that edge is wrong" | `relate` | ⚙ |
| Who calls a symbol | `callers` | ⚙ |
| What a symbol calls | `callees` | ⚙ |
| Blast radius of a change | `impact` | ⚙ |
| Path between two symbols | `paths` | ⚙ |
| Cycle detection | `cycles` | ⚙ |
| Add task / reminder | `tasks add` | |
| Daily briefing | `summary` | |
| Token spend / "what did that cost" | `usage` | |
| Audit a session's token numbers | `usage --session-id <id>` | |
| Health / status | `health` | |
| Open the browser dashboard | `dashboard [surface]` | |

## Data Layout

One data root, `~/.anton-core`, shared by every harness:

- `~/.anton-core/data/` — `core.db`, `events.db`, state files, `knowledge/` source copies, `logs/`
- `~/.anton-core/config/` — user-edited overrides
- `~/.anton-core/graphs/` — per-repo code-graph stores

The plugin's own install dir is read-only source + templates.

## Conventions

- **IDs**: prefixed by type — e.g. `conv-*`, `ref-*`, `task-*`
- **Dates**: verify today's date from env before creating date-based filenames
- **Binary invocation**: run the CLI as `anton <noun> <verb>`. Claude Code puts the plugin's `bin/anton` launcher on the Bash tool's `PATH` (main-session and subagent shells alike) while the plugin is enabled; Codex shells reach it as `~/.local/bin/anton`, which setup links.
