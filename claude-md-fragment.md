---
fragment-version: 2.0.0
---

# Anton Core

Personal AI assistant for knowledge, tasks, and daily productivity. Layers skills + hooks + SQLite (FTS5 + vector + graph) on top of your coding harness, Claude Code or Codex.

## Use Anton Core — Not the Defaults

Anton Core replaces the harness's default memory and code search in this setup, so use it for both.

### Memory — Anton Core is your memory layer

- **Save durable notes with the `save` skill** — decisions, preferences,
  corrections, facts, session learnings. Setup turns the harness's
  native auto memory off; save here even where it was kept on.
- **Recall before you reconstruct.** Before non-trivial work, `recall` what
  is already known; widen with `expand` / `explore`.
- **Curate, don't accrete.** When a new note corrects a saved one, `update`
  or `remove` the old one rather than saving a second version.
- **Reconcile a stale memory in the turn you spot it.** Stale means *no
  longer accurate*, not old. When a memory disagrees with ground truth,
  `update` it, `remove` it, or complete the task in the same turn: the next
  session trusts what the store says.

### Code — the code graph is how you read code

- **Ask the graph skill for the question.** "Who calls X" is `callers`,
  "what does X call" `callees`, "what breaks if X changes" `impact`, "how does
  A reach B" `paths`, "any circular dependencies" `cycles`: invoke that skill
  with the name, and it resolves the symbol itself. `recall --code` answers
  "where is X defined". The graph resolves bindings, where grep matches
  strings.
- **grep / `rg` is the fallback for code**: non-code text (comments,
  strings, config, prose), repos not indexed, or when the graph returns
  nothing.

## Critical Rules

1. **Local scope only** — limit file searches to the current project unless explicitly told otherwise
<!-- harness:claude -->
2. **No shell on internal Claude Code paths** — don't `cp`/`mv`/`cat` paths containing `.claude/projects/`: it triggers an unbypassable sensitive-file prompt. Use Read + Write instead.
<!-- /harness -->

## Intent Routing

Each skill below is an anton-core skill: invoke it as `/anton-core:<name>` in Claude Code and `$anton-core:<name>` in Codex. Use it without being asked whenever the task matches its row.

| Intent | Skill |
|---|---|
| Save / store / "remember this" | `save` |
| Correct or edit a saved memory | `update` |
| Search / recall / "find" | `recall` |
| Expand on an id | `expand` |
| Walk neighborhood | `explore` |
| Extract action items / decisions | `extract` |
| Link or unlink two memory items / "that edge is wrong" | `relate` |
| Who calls a symbol | `callers` |
| What a symbol calls | `callees` |
| Blast radius of a change | `impact` |
| Path between two symbols | `paths` |
| Cycle detection | `cycles` |

## Data Layout

One data root, `~/.anton-core`, shared by every harness: `data/` (`core.db`, `events.db`, state, `knowledge/` source copies, `logs/`), `config/` (user overrides) and `graphs/` (per-repo code-graph stores). The plugin's own install dir is read-only.

## Conventions

- **IDs**: prefixed by type — e.g. `conv-*`, `ref-*`, `task-*`
- **Dates**: verify today's date from env before creating date-based filenames
- **Binary invocation**: run the CLI as `anton <noun> <verb>`. Claude Code puts the plugin's `bin/anton` launcher on the Bash tool's `PATH` while the plugin is enabled; Codex shells reach it as `~/.local/bin/anton`, which setup links.
