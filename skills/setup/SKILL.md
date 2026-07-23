---
name: setup
description: State-aware concierge for the full anton-core install lifecycle. Use for "set up", "install anton-core", "initialize", "re-run setup", "configure anton-core", "update anton-core", "repair anton-core", "check anton-core status", or "uninstall anton-core".
allowed-tools: Read, Edit, Bash, AskUserQuestion
---

## What it does

State-aware installer and lifecycle surface for anton-core. On invocation it runs a **state probe** (`anton setup probe` — no install-state change; the skill records one classification line to the events log), classifies the install (fresh / healthy-current / update-available / partial), and either runs a clean first-time setup straight through or opens a guided menu (Health check · Reconfigure · Update or Repair · Uninstall). Mechanical plumbing — binary bootstrap, data-root persistence, the operator-shell launcher, the version-pin verify-back gate, the bootstrap-lock — runs silently behind four named progress stages. Supports `--check` (status, no install-state change), `--re-onboard`, and `--uninstall [--purge-data]`. Every binary call routes through the `anton` command — the plugin's `bin/`-on-PATH launcher into the plugin's own tree — which never fetches: on a missing binary it emits a `binary_missing_run_setup` precondition envelope and exits non-zero. The one exception is `anton bootstrap`, the launcher's single fetch intercept: the synchronous per-platform binary fetch runs ONLY here under setup, through that intercept (see [ADR-0037](../../docs/adr/0037-public-distribution.md) public distribution, and [ADR-0051](../../docs/adr/0051-hooks-answer-or-enqueue.md) hooks answer or enqueue). Two adjacent operator verbs sit outside this concierge flow and are invoked directly: `setup install-daemon` renders and installs the watch-daemon supervisor unit (launchd/systemd), and `setup uninstall-daemon` removes it.

## When to use

- "set up", "install anton-core", "initialize", "re-run setup", "configure anton-core"
- "update anton-core", "repair anton-core", "check status", `/anton-core:setup`
- "uninstall anton-core"
- After a plugin update that ships a newer `claude-md-fragment.md`

## Conventions (apply throughout)

- Every binary call routes through `anton <verb>` — the plugin's `bin/anton` launcher, on the Bash PATH whenever the plugin is enabled, exec'ing `scripts/core`. Never invoke a bare `core` from this body — that name is the operator-shell launcher, which bypasses the shim's pin gate.
- `anton fragment apply` is the only mutator for the `~/.claude/CLAUDE.md` *fragment*; the install/update/repair flow never edits it directly. Every step is a no-op when its precondition already holds.
- Operator prompts use `AskUserQuestion` (never stdin).
- Voice: neutral, warm, concise — no persona.

### Operator experience (apply throughout)

The person installing this may not be technical. Everything they see follows these rules — no exceptions, at every step of every flow in this skill:

- **Plain language only.** Never show the operator raw file paths, JSON envelopes, `reason=` tokens, exit codes, environment variables, or shell output. Those exist for you and for bug reports — not for narration. The numbered mechanics throughout this skill are **internal execution notes: never read them aloud**; the operator sees only stage banners, short progress phrases (a few words per step, e.g. "Downloading the assistant's engine… done"), and — on failure — the failure card below.
- **Every failure renders a three-part card**, nothing else:
  1. *What happened* — one plain sentence ("I couldn't download the assistant's engine.").
  2. *What I'm doing about it* — the retry, fallback, or skip you are taking ("I'll retry once" / "I'm skipping this optional step and continuing").
  3. *What you can do* — the single action left to the operator, which is usually "nothing". When the problem needs the developer, END the card with one copyable line — `report code: <reason token> — please send this to the developer` — and that line is the ONLY place a machine token may appear.
- **Setup never delegates plumbing to the operator.** Never ask them to set environment variables, edit files, run diagnostic commands, visit GitHub, or file issues. If setup cannot proceed, say so in one sentence, produce the report line yourself, and stop cleanly.
- **Optional means silent.** A failed optional step (shell access, telemetry lines, token lookup) gets at most one gentle sentence — or nothing — never a card.

### Paste-input normalization (every operator-pasted string)

1. Strip leading/trailing whitespace (ASCII space, tab, `\r`, `\n`, `\v`, `\f`).
2. Convert CRLF and lone CR to `\n`.
3. Reject any paste containing non-printable bytes other than `\n` / `\t` — re-prompt once, then abort the step on a second occurrence.
4. For newline-separated pastes (repos), split AFTER normalization, trim each line, drop empties.

## Step 0 — Argument triage & flag validation

Parse the invocation args for `--check`, `--uninstall`, `--purge-data`, `--re-onboard`. Reject in prose before any work:

- `--purge-data` without `--uninstall` → "`--purge-data` is only valid with `--uninstall`."
- `--uninstall` with `--re-onboard` → "`--uninstall` and `--re-onboard` are mutually exclusive."
- `--check` with any of `--uninstall` / `--purge-data` / `--re-onboard` → "`--check` is mutually exclusive with the other flags."

Then route:

- `--uninstall` present → jump to **Uninstall**; do not run the probe-driven menu.
- `--check` present → run **Step 1 (State probe)**. Print the classification; when `data_root.db_present`, also print the health readout from `anton report health --full` (the health overlay already fetched it for a `healthy-current` box — reuse that result; for any other class, fetch it once here). On a fresh box there is no database to report on, so print "fresh — nothing installed yet". Run the `--check` shell-command preview from Step 1 when a symlink state is outside `{ours, absent}`. Then exit without changing install state. (`--check` makes no install-state change: on an installed box it may append a health-log row and one classification line to the events log — both append-only observations; on a fresh box it writes nothing at all, since the probe verb never opens a database and the telemetry line is gated on the database existing.)
- otherwise → run **Step 1 (State probe)**, then **Step 2 (Routing)**.

## Step 1 — State probe (no install-state change)

Run `anton setup probe --format json`. The verb does every file-stat, environment, and read-only-pin read the classifier needs and returns one envelope; **the skill computes nothing** except the single health overlay below. The probe never opens or creates a database — on a database-less box it makes no database call at all, so the probe is genuinely read-only on the fresh path.

**Missing-binary envelope.** When the launcher binary is not yet installed, the shim answers *every* invocation — the probe included — with a `binary_missing_run_setup` precondition envelope. Treat that envelope as classification **fresh** (a binaryless-but-installed box self-repairs through the idempotent install; onboarding stays gated on the probe re-run after install).

Parse from `data` (no recomputation — these are the routing inputs verbatim):

- `classification` — `fresh` / `partial` / `update-available` / `healthy-current` (the routing verdict).
- `provenance` — `truly-fresh` / `hook-bootstrapped` / `null` (refines a `fresh` verdict; `null` for every other class).
- `data_root.config_present`, `data_root.db_present`, `data_root.versions_current`.
- `fragment.status` (`absent` / `stale` / `current`), `fragment.shipped_version`, `fragment.dest_has_sentinels`.
- `onboarding_shown` (`null` when no database exists to record it).
- `symlinks.anton`, `symlinks.legacy_core` — each `ours` / `dangling` / `foreign` / `absent`.
- `path_on_path`.

**Health overlay (the one skill-side clause).** When `classification == "healthy-current"` and `data_root.db_present`, run `anton report health --full` and read `report.severity`; a `severity == "critical"` re-routes as **partial** (severity is a health-subsystem judgment the file-stat classifier cannot make). No other classification consults health here.

**Classification telemetry (append-only observation).** When `data_root.db_present`, record one line:

```
anton event log --source setup --severity info --type SETUP_CLASSIFIED --subject <classification> --detail "provenance=<provenance> fragment=<fragment.status> shipped=<fragment.shipped_version> link=<symlinks.anton>"
```

When the database is absent (a truly-fresh box, or the missing-binary envelope), DEFER this line to Stage 1 — recorded once after `anton db init` materializes the databases (see Step 3e). A failed `event log` is a one-line warning, never a block. This is the only thing the probe path writes, and it is an append-only observation — not an install-state change.

**`--check` shell-command preview.** In `--check` mode, when either `symlinks.anton` or `symlinks.legacy_core` is outside `{ours, absent}`, additionally run `anton setup link-shell --dry-run --format json` and render one plain sentence naming what a repair would do (e.g. "The `anton` shell command needs repointing — Repair will fix it."). The dry run makes no install-state change, so `--check`'s no-change contract holds.

## Step 2 — Routing

Match in order (first match wins):

- **fresh** → run **Install** (Steps 3–7) straight through; no menu. `--re-onboard` does **not** short-circuit here: a fresh box has no seeded database for `repos add` / `item bulk-import` to write to, and Install runs onboarding un-gated as its Step 6 anyway, so an explicit `--re-onboard` on a fresh box is subsumed by the full install.
- **`--re-onboard`** (non-fresh, no menu) → **Onboarding** directly (un-gated).
- **non-fresh** → render an `AskUserQuestion` menu that names the detected state, with options ordered by class:
  - healthy-current → Health check (recommended) · Reconfigure · Update or Repair · Uninstall
  - update-available → Update (recommended) · Health check · Reconfigure · Uninstall
  - partial → Repair (recommended) · Health check · Reconfigure · Uninstall

  Route the choice: Health check → **Health verify**; Reconfigure → **Onboarding**; Update → **Update**; Repair → **Repair**; Uninstall → **Uninstall**.

## Install (Steps 3–7)

### Step 3 — Stage 1: Foundation

Print `Step 1 of 4 — Foundation (getting the assistant's engine in place)`. The sub-steps below are internal execution notes (Operator experience contract applies). The `anton` launcher's shim resolves the data root itself; no command in this skill carries an environment prefix. Run, in order:

a. **Binary install (fresh box only).** When the probe classified **fresh** (or returned the missing-binary envelope), fetch and rotate the binary in:
   1. `anton bootstrap` — the setup-only synchronous fetch, and the launcher's single bootstrap intercept: it downloads + checksum/cosign-verifies the per-platform release binary, stages it in the versioned self-update slot, writes the prefetch record, and on a fresh box seeds the operator config with the data root. On a non-zero exit render the **failure card** (Operator experience contract): "I couldn't download the assistant's engine" / what you're doing about it / the `report code:` line carrying the machine-parseable `reason=<…>` from stderr — then stop (nothing downstream can run without a binary).
   2. `anton update apply-if-staged` — rotates the just-staged slot to the live-binary pointer and writes the first pin (the ONLY pin writer). A non-zero exit renders the failure card ("I couldn't finish installing the engine") and stops.

   **Idempotent:** skip both when the probe classified anything other than fresh (a re-run, repair, or hook-bootstrapped box already has a resolvable binary). This step is a no-op on every non-fresh install.
b. `anton db init` — materializes `core.db` + `events.db`, applies migrations, seeds DEFAULT_CONFIG (`INSERT OR IGNORE`). Idempotent. A non-zero exit renders the failure card ("I couldn't set up the assistant's memory") with the precondition `reason` on the report-code line, and stops.
c. `anton setup persist-data-dir` — records the resolved data root in the operator config (a no-op when the bootstrap fetch already seeded it). Non-fatal: a failure is a one-line warning.
d. `anton setup get-token --format json`. **Exit 0:** read the token from stderr (single line, no decoding) and prepend `ANTON_GITHUB_TOKEN=<token>` to every subsequent `anton` call in this run; never print it. **Exit 3:** proceed without a token — do not prompt for `gh auth login`, do not abort (the token only raises GitHub API rate limits).
e. **Deferred classification telemetry (fresh only).** When the probe classified **fresh** (so the databases did not exist at Step 1), record the now-deferrable line — `anton event log --source setup --severity info --type SETUP_CLASSIFIED --subject fresh --detail "provenance=<provenance>"` — using the `provenance` (`truly-fresh` or `hook-bootstrapped`) the probe returned. A failed `event log` is a one-line warning.

### Step 4 — Stage 2: Connect to Claude

Print `Step 2 of 4 — Connect to Claude (wiring the assistant into your instructions)`.

a. `anton fragment apply` — applies the shipped routing fragment into `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/CLAUDE.md` between the `<!-- anton-core:start -->` / `<!-- anton-core:end -->` sentinels (replace-in-place when present, append when absent), then pins `fragment.version` with a read-back verify gate (all inside the verb). A non-zero exit renders the failure card ("I couldn't connect the assistant to your Claude instructions") with the `io_error` detail on the report-code line, and stops; on success print one friendly line (the envelope's `old_version → new_version` is internal).

### Step 5 — Stage 3: Shell access (optional)

Print `Step 3 of 4 — Shell access (optional: the "anton" command for your terminal)`. The whole stage is convenience; per the Operator experience contract, any failure here gets at most one gentle sentence, then continue.

a. `anton update status >/dev/null 2>&1` — materializes the live-binary pointer (read-only; runs the one-shot legacy→versioned migration). The next call gates on that pointer but never creates it, so this call comes first.
b. `anton setup link-shell --format json` — installs the operator-shell launcher and points the `anton` command at it (the four-branch site decision), retiring the legacy `core` command site. Render from the envelope, then continue no matter what:
   - `symlink.branch == "refused"` → one gentle sentence naming the conflict ("Something else already owns the `anton` command name — leaving it untouched."), then continue.
   - `legacy_core == "removed"` → one line: "Retired the old `core` shell command — it's `anton` everywhere now."
   - `path_on_path == false` → print the shell-RC line to add (`export PATH="$HOME/.local/bin:$PATH"`) — do NOT edit the shell-RC.
   - a `current_unresolved` or `io_error` refusal (exit 3 / exit 5) → one gentle optional-stage sentence, then continue (the stage is convenience; nothing downstream depends on it).

### Step 6 — Stage 4: Your content (onboarding)

Print `Step 4 of 4 — Your content (repositories and knowledge, all optional)`. Run `anton onboarding check`; if `shown: true` and `--re-onboard` was not present, skip to Step 7. Otherwise run **Onboarding**.

### Step 7 — Health verify + completion card

`anton report health --full`. On `report.severity == "critical"`, surface the failing check names + their `detail` fields and stop before the card. On healthy/warning/degraded, print the **Completion card**.

## Onboarding (sub-flow)

Render ONE `AskUserQuestion` panel collecting the steps below; **omit any step whose `onboarding.<step>.declined` reads `true`** unless `--re-onboard` is set:

- **Repos:** "Register repositories with anton-core? Paste absolute paths, one per line, or Skip."
- **Knowledge:** "Bulk-import a knowledge directory? Absolute path, or Skip."
- **Shell access:** (only if not already linked) "Add `anton` to your shell PATH? Yes / Skip."

**Plan-recap:** summarize the chosen actions in one line (e.g. "register 3 repos · import ~120 files · add `anton` to PATH") and confirm before any write.

**Execute:**

- **Repos:** normalize the paste; for each path, classify before registering. If the path holds a `.git`, it is a single repo → `anton repos add <path>`. If it has no `.git` but two or more immediate children do, warn and render a second `AskUserQuestion`: "<path> looks like a parent of multiple repositories. Register it as…" with "Parent of many (Recommended)" → `repos add <path> --type parent`, or "A single repository" → `repos add <path>`. Render `✓ <path> (slug: …)` / `✗ <path> — <reason>`. Per-path failures do not abort.
- **Import:** `anton item bulk-import --path <dir> --recursive --dry-run --format summary`. On `file_count == 0`, report and continue. Otherwise render `file_count` + `by_type`, confirm via a second `AskUserQuestion`, then re-run without `--dry-run` and render `imported` / `skipped` / `errors`; when `degraded_no_vector` > 0, add a one-line note ("N file(s) imported without a vector — a tokenizer issue; searchable by text, re-runnable via `maintenance reindex`").
- **Shell access:** if "Yes" and not already linked, run `anton setup link-shell --format json` (the same verb Stage 3 runs) and render from its envelope as in Step 5.

**Persist declines:** for each Skipped step, `config set --key onboarding.<step>.declined --value true`. For each completed step, clear it with `config set --key onboarding.<step>.declined --value ""`.

`anton onboarding mark-shown` (failure is a warning).

## Repair (sub-flow)

Re-run Steps 3–6 gated on their preconditions, narrating ONLY what was out of sync (e.g. "Symlink was dangling — repointed."). Steps already in order stay silent. The fragment step runs `fragment apply`; narrate "Routing fragment restored." only when the verb reports `applied: true`. Read `old_version`/`new_version` from the envelope for the narration line. End with Step 7.

## Update (sub-flow)

Run `fragment apply` (fragment refresh + re-pin) and Stage 3 (launcher refresh); SKIP onboarding. Read `old_version`/`new_version` from the verb envelope and report "Routing updated v<old_version> → v<new_version>." End with Step 7.

## Health verify (menu action)

`anton report health --full`; print the severity and any failing checks with their `detail`. Writes nothing.

## Completion card

```
✓ anton-core — ready to use.

Try this next:
  /anton-core:save     "remember <a fact worth keeping>"
  /anton-core:recall    --code <symbol>
  /anton-core:summary   your daily briefing
```

When a repository was registered, name one in the `recall --code` line; when nothing was onboarded, collapse to `save` + `summary`. Never list a command that is not an installed skill.

## Uninstall

When `--uninstall` is present (or chosen from the menu):

1. **Pre-flight.** `anton setup uninstall [--purge-data] --dry-run --format json`. Capture `removed[*]` paths + `bytes`.
2. **Scope (skip when `--purge-data` already given).** `AskUserQuestion`: "Remove anton-core, keep my data" (default) vs "Remove everything, erase my data" (⚠ also deletes `~/.anton-core/data` — saved knowledge, tasks, logs; no undo). The erase choice sets `--purge-data`.
3. **Confirm.** Keep-data → a plain confirm listing each `removed[*]` path with humanized `bytes` and `kind`, the CLAUDE.md fragment-wipe callout (sentinel region is plugin-managed; hand-edits inside go with it), and the symlink-removal note. Erase-everything → require **typed confirmation**: "Type `erase` to confirm." Any other input cancels with zero mutation.
4. **Breadcrumb before removal.** Append one line — `<ISO-8601 timestamp>\t<resolved paths>\t<total bytes>\t<scope>` — to `~/.anton-core/data/logs/uninstall.log`. Best-effort: a write failure is a warning, never a block.
5. **Execute.** `anton setup uninstall [--purge-data] --format json` (acquires the bootstrap lock; the verb also reaps the operator-shell command sites itself and reports each under `symlinks[*]`). Then `Read` `~/.claude/CLAUDE.md`; if sentinels present, `Edit` to delete the marker pair + body.
6. **Summary card.** Resolved paths removed, bytes freed (sum of `removed[*].bytes`), one line per operator-shell command site the verb reaped (from `symlinks[*]`: an `action: removed` site named as cleaned up, an `action: left_foreign` site named as left in place), the callout that per-project memory under `~/.claude/projects/.../memory/` is untouched, the callout that a subsequent install is treated as first-run, and the reminder to run `/plugin uninstall anton-core` to complete removal.

## Behavior

After a successful install, `core.db` + `events.db` exist under the data root, schema'd and seeded; `~/.claude/CLAUDE.md` carries the fragment between the sentinel pair; `~/.local/bin/anton` (when creation succeeded) points at the operator-shell launcher and the legacy `~/.local/bin/core` command site is retired; `anton config get --key fragment.version` returns the shipped version. Re-running is idempotent — the probe + menu make no install-state change (they may append observation logs only) and every execution step is a no-op when its precondition holds. Spec: [docs/plugin-spec/07-skills/setup.md](../../docs/plugin-spec/07-skills/setup.md).
