---
name: setup
description: Manages the anton-core install lifecycle, probing state before it acts. Use when the operator wants to install, check, update, repair, reconfigure, or uninstall anton-core, or after a plugin update ships a newer routing fragment.
allowed-tools: Read, Edit, Bash
disable-model-invocation: true
---

## Contract

Installs, checks, updates, repairs, reconfigures or uninstalls anton-core. It runs a **state probe** (`anton setup probe`, no install-state change), classifies the install (fresh / healthy-current / update-available / partial), then runs a fresh install straight through or opens a guided menu (Health check · Reconfigure · Update or Repair · Uninstall). Flags: `--check` (status, no install-state change), `--re-onboard`, `--uninstall [--purge-data]`. An install, repair or update is done when the health check is not `critical` and the completion card is shown; `--check`, Health check, Reconfigure and Uninstall are done when their own section completes.

Every binary call goes through the `anton` launcher, which never fetches: a missing binary answers with a `binary_missing_run_setup` envelope. The one fetch is `anton bootstrap`, run only here. `setup install-daemon` and `setup uninstall-daemon` (the watch-daemon supervisor unit) are invoked directly, outside this flow.

## Conventions (apply throughout)

- **Locate `anton` once, first.** When `command -v anton` finds it, every binary call is `anton <verb>`. Otherwise — a harness that puts no plugin `bin/` on the shell PATH, before `setup link-shell` has ever run — take the path of this SKILL.md as shown to you, go two directories up to the plugin root, and use its `bin/anton` for `bin/anton bootstrap` and then `bin/anton setup link-shell`; from then on `anton` resolves. Never invoke a bare `core` from this body — setup retires that command, and whatever still answers to the name bypasses the shim's pin gate.
- `anton fragment apply` is the only mutator for the *fragment* in each harness's global instructions file; the install/update/repair flow never edits it directly. Every step is a no-op when its precondition already holds.
- Operator prompts use the harness's question tool when it has one, else a numbered question in a message — in this body, "ask the operator" (never stdin).
- Voice: neutral, warm, concise — no persona.

### Operator experience (apply throughout)

The person installing this may not be technical. Everything they see follows these rules:

- **Plain language only.** Never show the operator raw file paths, JSON envelopes, `reason=` tokens, exit codes, environment variables, or shell output. Those exist for you and for bug reports — not for narration. The exceptions are named where they occur: the native-memory conflict sentence and opt-out (Step 4d), the shell-RC line (Step 5), the `maintenance reindex` note (Onboarding) and the plugin-manager reminder (Uninstall). The numbered mechanics throughout this skill are **internal execution notes: never read them aloud**; the operator sees only stage banners, short progress phrases (a few words per step, e.g. "Downloading the assistant's engine… done"), and — on failure — the failure card below.
- **Every failure renders a three-part card**, nothing else:
  1. *What happened* — one plain sentence ("I couldn't download the assistant's engine.").
  2. *What I'm doing about it* — the retry, fallback, or skip you are taking ("I'll retry once" / "I'm skipping this optional step and continuing").
  3. *What you can do* — the single action left to the operator, which is usually "nothing". When the problem needs the developer, end the card with one copyable line — `report code: <reason token> — please send this to the developer` — the only place a machine token appears.
- **Setup never delegates plumbing to the operator.** Beyond the exceptions above, never ask them to set environment variables, edit files, run diagnostic commands, visit GitHub, or file issues. If setup cannot proceed, say so in one sentence, produce the report line yourself, and stop cleanly.
- **Optional means silent.** A failed optional step (shell access, telemetry lines, token lookup) gets at most one gentle sentence — or nothing — never a card.

### Paste-input normalization (every operator-pasted string)

1. Strip leading/trailing whitespace (ASCII space, tab, `\r`, `\n`, `\v`, `\f`).
2. Convert CRLF and lone CR to `\n`.
3. Reject any paste containing non-printable bytes other than `\n` / `\t` — re-prompt once, then abort the step on a second occurrence.
4. For newline-separated pastes (repos), split after normalization, trim each line, drop empties.

## Step 0 — Argument triage & flag validation

Parse the invocation args for `--check`, `--uninstall`, `--purge-data`, `--re-onboard`. Reject in prose before any work:

- `--purge-data` without `--uninstall` → "`--purge-data` is only valid with `--uninstall`."
- `--uninstall` with `--re-onboard` → "`--uninstall` and `--re-onboard` are mutually exclusive."
- `--check` with any of `--uninstall` / `--purge-data` / `--re-onboard` → "`--check` is mutually exclusive with the other flags."

Then route:

- `--uninstall` present → jump to **Uninstall**; do not run the probe-driven menu.
- `--check` present → run **Step 1 (State probe)**. Print the classification; when `data_root.db_present`, also print the `anton report health --full` readout (reuse the overlay's result on a `healthy-current` box; fetch it once otherwise). On a fresh box print "fresh — nothing installed yet". Run Step 1's shell-command preview when a symlink state is outside `{ours, absent}`. Then exit. `--check` changes no install state: an installed box may append a health-log row and one classification line (append-only observations); a fresh box writes nothing.
- otherwise → run **Step 1 (State probe)**, then **Step 2 (Routing)**.

## Step 1 — State probe

Unless `--check`, first run `anton setup relocate-data-root --format json`: it moves a store kept outside `~/.anton-core` into it and leaves the old root as a link (`origin: none` when there is nothing to move). When it answers with the missing-binary envelope, run it again right after Step 3a's bootstrap. A refusal (`data_root_conflict`, `data_root_cross_device`, `swap_unsupported`, `lock_contested`) is a one-line warning naming the envelope's `detail`; continue.

Then run `anton setup probe --format json`. The verb does every file-stat, environment, and read-only-pin read the classifier needs and returns one envelope; **the skill computes nothing** except the single health overlay below. The probe never opens or creates a database — on a database-less box it makes no database call at all, so the probe is genuinely read-only on the fresh path.

**Missing-binary envelope.** When the launcher binary is not yet installed, the shim answers *every* invocation — the probe included — with a `binary_missing_run_setup` precondition envelope. Treat that envelope as classification **fresh** (a binaryless-but-installed box self-repairs through the idempotent install; onboarding stays gated on the probe re-run after install).

Parse from `data` (no recomputation — these are the routing inputs verbatim):

- `classification` — `fresh` / `partial` / `update-available` / `healthy-current` (the routing verdict).
- `provenance` — `truly-fresh` / `hook-bootstrapped` / `null` (refines a `fresh` verdict; `null` for every other class).
- `data_root.config_present`, `data_root.db_present`, `data_root.versions_current`.
- `fragment.status` (`absent` / `stale` / `current`), `fragment.shipped_version`, `fragment.dest_has_sentinels`.
- `onboarding_shown` (`null` when no database exists to record it).
- `symlinks.anton`, `symlinks.legacy_core` — each `ours` / `dangling` / `foreign` / `absent`.
- `path_on_path`.
- `statusline.installed` — whether the `claude` harness's status line already pipes through anton (Step 4e).
- `harnesses[]` — one entry per harness anton-core knows: `id`, `installed`, `version`, `plugin`, `config_dir`, `instructions_target`, `skill_invocation_prefix`, `wiring_state`. Step 4 iterates the entries with `installed: true`; the completion card uses the current harness's `skill_invocation_prefix`.

**Health overlay (the one skill-side clause).** When `classification == "healthy-current"` and `data_root.db_present`, run `anton report health --full` and read `report.severity`; a `severity == "critical"` re-routes as **partial** (severity is a health-subsystem judgment the file-stat classifier cannot make). No other classification consults health here.

**Classification telemetry (append-only observation).** When `data_root.db_present`, record one line:

```
anton event log --source setup --severity info --type SETUP_CLASSIFIED --subject <classification> --detail "provenance=<provenance> fragment=<fragment.status> shipped=<fragment.shipped_version> link=<symlinks.anton>"
```

When the database is absent (a truly-fresh box, or the missing-binary envelope), defer this line to Stage 1 — recorded once after `anton db init` materializes the databases (see Step 3d). A failed `event log` is a one-line warning, never a block. This is the only thing the probe path writes, and it is an append-only observation — not an install-state change.

**`--check` shell-command preview.** In `--check` mode, when either `symlinks.anton` or `symlinks.legacy_core` is outside `{ours, absent}`, additionally run `anton setup link-shell --dry-run --format json` and render one plain sentence naming what a repair would do (e.g. "The `anton` shell command needs repointing — Repair will fix it."). The dry run makes no install-state change, so `--check`'s no-change contract holds.

## Step 2 — Routing

Match in order (first match wins):

- **fresh** → run **Install** (Steps 3–7) straight through; no menu. `--re-onboard` does not short-circuit here: Install runs onboarding un-gated anyway, and a fresh box has no database for `repos add` / `item bulk-import` until it does.
- **`--re-onboard`** (non-fresh, no menu) → **Onboarding** directly (un-gated).
- **non-fresh** → ask the operator, as a menu that names the detected state, with options ordered by class:
  - healthy-current → Health check (recommended) · Reconfigure · Update or Repair · Uninstall
  - update-available → Update (recommended) · Health check · Reconfigure · Uninstall
  - partial → Repair (recommended) · Health check · Reconfigure · Uninstall

  Route the choice: Health check → **Health verify**; Reconfigure → **Onboarding**; Update → **Update**; Repair → **Repair**; Uninstall → **Uninstall**.

## Install (Steps 3–7)

### Step 3 — Stage 1: Foundation

Print `Step 1 of 4 — Foundation (getting the assistant's engine in place)`. The sub-steps below are internal execution notes (Operator experience contract applies). The `anton` launcher's shim resolves the data root itself; no command in this skill carries an environment prefix. Run, in order:

a. **Binary install (fresh box only).** When the probe classified **fresh** (or returned the missing-binary envelope), fetch and rotate the binary in:
   1. `anton bootstrap` — the setup-only synchronous fetch, and the launcher's single bootstrap intercept: it downloads + checksum/cosign-verifies the per-platform release binary, stages it in the versioned self-update slot, and writes the prefetch record. When the harness's sandbox denies the download (no network), ask the operator to approve running this one step outside the sandbox, then re-run it. On any other non-zero exit render the **failure card** (Operator experience contract): "I couldn't download the assistant's engine" / what you're doing about it / the `report code:` line carrying the machine-parseable `reason=<…>` from stderr — then stop (nothing downstream can run without a binary).
   2. `anton update apply-if-staged` — rotates the just-staged slot to the live-binary pointer and writes the first pin (the only pin writer). A non-zero exit renders the failure card ("I couldn't finish installing the engine") and stops.

   **Idempotent:** skip both when the probe classified anything other than fresh (a re-run, repair, or hook-bootstrapped box already has a resolvable binary). This step is a no-op on every non-fresh install.
b. `anton db init` — materializes `core.db` + `events.db`, applies migrations, seeds DEFAULT_CONFIG (`INSERT OR IGNORE`). Idempotent. A non-zero exit renders the failure card ("I couldn't set up the assistant's memory") with the precondition `reason` on the report-code line, and stops.
c. `anton setup get-token --format json`. **Exit 0:** read the token from stderr (single line, no decoding) and prepend `ANTON_GITHUB_TOKEN=<token>` to every subsequent `anton` call in this run; never print it. **Exit 3:** proceed without a token — do not prompt for `gh auth login`, do not abort (the token only raises GitHub API rate limits).
d. **Deferred classification telemetry (fresh only).** When the probe classified **fresh** (so the databases did not exist at Step 1), record the now-deferrable line — `anton event log --source setup --severity info --type SETUP_CLASSIFIED --subject fresh --detail "provenance=<provenance>"` — using the `provenance` (`truly-fresh` or `hook-bootstrapped`) the probe returned. A failed `event log` is a one-line warning.

### Step 4 — Stage 2: Connect

Print `Step 2 of 4 — Connect (wiring the assistant into your coding assistants)`. Steps a, c and d run once per `harnesses[]` entry with `installed: true`, passing its `id`.

a. **Wire the harness.** `anton setup wire-harness --harness <id> --format json` — trusts the plugin's hooks, turns the harness's hook feature on, lets its sandbox write the data root and links the shell command, as that harness needs (a harness needing none of it answers `ok` with nothing done). A non-zero exit renders the failure card ("I couldn't connect the assistant to <harness>") with the `reason` on the report-code line, then continue with the next harness.
b. `anton fragment apply` — applies the shipped routing fragment into every installed harness's global instructions file between the `<!-- anton-core:start -->` / `<!-- anton-core:end -->` sentinels (replace-in-place when present, append when absent), writing a file two harnesses share once, then pins `fragment.version` with a read-back verify gate (all inside the verb). The envelope's `targets[]` lists each file written. A non-zero exit renders the failure card ("I couldn't connect the assistant to your instructions") with the `io_error` detail on the report-code line, and stops; on success print one friendly line naming how many instruction files carry it (the envelope's `old_version → new_version` is internal).
c. **Import native memory.** Unless `anton config get --key setup.native_memory.import_declined` reads `true`, run `anton item import-native --harness <id> --dry-run --format json`, which returns `{"status":"ok","dry_run":true,"scanned":2,"imported":0,"skipped_existing":1,"unparseable":[],"items":[{"path":"…","source":"<project-dir>/<file>","id":"","type":"feedback","action":"would_import"}],"degraded_no_vector":0,"warnings":[]}`. When `items` is non-empty (files not yet imported), show the counts by `items[].type` and ask the operator once ("Bring the notes <harness> saved on its own into the assistant's memory?"). On yes, run `anton item import-native --harness <id> --format json` and render `imported`, `skipped_existing` and `unparseable` in one line. On no, `anton config set --key setup.native_memory.import_declined --value true`. A failure is one gentle sentence, then continue.
d. **Turn native memory off.** Unless `anton config get --key setup.native_memory.declined` reads `true`, run `anton setup native-memory --harness <id> --format json`, which returns `{"status":"ok","installed":true,"action":"written","path":"/…/settings.json","env_disabled":false}`. On `action: written`, print one line ("<harness>'s own memory is now off — the assistant keeps your notes."). On `action: conflict`, write one sentence naming the explicit setting that keeps the harness's own memory on (`autoMemoryEnabled: true` for `claude`), which setup leaves as it is. On `already_disabled`, say nothing. When the operator asks to keep a harness's own memory, give them the opt-out: `anton config set --key setup.native_memory.declined --value true`, then `anton setup native-memory --harness <id> --remove`. This skill never writes `declined`. A failure renders the failure card with the `io_error` detail on the report-code line, then continue.
e. **Plan headroom (optional).** Only when the `claude` entry is installed and the probe's `statusline.installed` is `false`; otherwise skip. Ask the operator once: "Capture plan headroom from the status line?" — how much of the 5-hour and 7-day plan windows is used and when each resets, which only the `claude` harness's status line carries. On yes, run `anton setup statusline --format json`, which returns `{"status":"ok","action":"installed","path":"/…/.claude/settings.json","command":"/…/data/versions/current usage statusline | { ~/.claude/scripts/context-bar.sh\n}"}`. The verb puts `<data-root>/data/versions/current usage statusline` at the head of a pipe in front of the operator's existing `statusLine.command`, grouped as `{ <cmd> }` so every part of a compound command reads the input: it passes the status-line JSON through byte-for-byte, closes its output before recording anything, and never blanks the line on a capture fault. With no status line configured, it installs the compact `usage statusline --line` readout (`5h 26% · 7d 44%`) instead. On `installed`, print one line ("Plan headroom will show in the `usage` skill once the status line next draws."); on `already_installed`, say nothing. `anton setup statusline --remove` strips exactly what it added (`removed`, or `not_installed` when the pipe is absent) and Uninstall runs it. On no, write nothing; the operator can run `anton setup statusline` later. A failure — `precondition_missing` when the live binary is not in place — is one gentle sentence, then continue.

### Step 5 — Stage 3: Shell access (optional)

Print `Step 3 of 4 — Shell access (optional: the "anton" command for your terminal)`. The whole stage is convenience; per the Operator experience contract, any failure here gets at most one gentle sentence, then continue.

a. `anton update status >/dev/null 2>&1` — makes sure the live-binary pointer exists (read-only). On a fresh install Step 3a's `apply-if-staged` already wrote it, so this is a no-op; on a host still carrying the legacy `data/bin/anton-core-v<version>` layout, it runs the one-shot migration that writes it. The next call gates on that pointer but never creates it, so this call comes first.
b. `anton setup link-shell --format json` — installs the operator-shell launcher and points the `anton` command at it (the four-branch site decision), retiring the legacy `core` command site. Render from the envelope, then continue no matter what:
   - `symlink.branch == "refused"` → one gentle sentence naming the conflict ("Something else already owns the `anton` command name — leaving it untouched."), then continue.
   - `legacy_core == "removed"` → one line: "Retired the old `core` shell command — it's `anton` everywhere now."
   - `path_on_path == false` → print the shell-RC line to add (`export PATH="$HOME/.local/bin:$PATH"`); the operator adds it, and setup leaves the shell-RC file untouched.
   - a `current_unresolved` or `io_error` refusal (exit 3 / exit 5) → one gentle optional-stage sentence, then continue (the stage is convenience; nothing downstream depends on it).

### Step 6 — Stage 4: Your content (onboarding)

Print `Step 4 of 4 — Your content (repositories and knowledge, all optional)`. Run `anton onboarding check`; if `shown: true` and `--re-onboard` was not present, skip to Step 7. Otherwise run **Onboarding**.

### Step 7 — Health verify + completion card

`anton report health --full`. On `report.severity == "critical"`, surface the failing check names + their `detail` fields and stop before the card. On healthy/warning/degraded, print the **Completion card**.

## Onboarding (sub-flow)

Ask the operator one panel of questions collecting the steps below (the follow-up questions under **Execute** come after it); **omit any step whose `onboarding.<step>.declined` reads `true`** unless `--re-onboard` is set:

- **Repos:** "Register repositories with anton-core? Paste absolute paths, one per line, or Skip."
- **Knowledge:** "Bulk-import a knowledge directory? Absolute path, or Skip."
- **Shell access:** (only if not already linked) "Add `anton` to your shell PATH? Yes / Skip."

**Plan-recap:** summarize the chosen actions in one line (e.g. "register 3 repos · import ~120 files · add `anton` to PATH") and confirm before any write.

**Execute:**

- **Repos:** normalize the paste; for each path, classify before registering. If the path holds a `.git`, it is a single repo → `anton repos add <path>`. If it has no `.git` but two or more immediate children do, warn and ask the operator: "<path> looks like a parent of multiple repositories. Register it as…" with "Parent of many (Recommended)" → `repos add <path> --type parent`, or "A single repository" → `repos add <path>`. Render `✓ <path> (slug: …)` / `✗ <path> — <reason>`. Per-path failures do not abort.
- **Import:** `anton item bulk-import --path <dir> --recursive --dry-run --format summary`. On `file_count == 0`, report and continue. Otherwise render `file_count` + `by_type`, confirm with the operator, then re-run without `--dry-run` and render `imported` / `skipped` / `errors`; when `degraded_no_vector` > 0, add a one-line note ("N file(s) imported without a vector — a tokenizer issue; searchable by text, re-runnable via `maintenance reindex`").
- **Shell access:** if "Yes" and not already linked, run `anton setup link-shell --format json` (the same verb Stage 3 runs) and render from its envelope as in Step 5.

**Persist declines:** for each Skipped step, `anton config set --key onboarding.<step>.declined --value true`. For each completed step, clear it with `anton config set --key onboarding.<step>.declined --value ""`.

`anton onboarding mark-shown` (failure is a warning).

## Repair (sub-flow)

Re-run Steps 3–6 gated on their preconditions, except Step 4e, which only install runs (repair never re-asks the plan-headroom question), narrating only what was out of sync (e.g. "Symlink was dangling — repointed."). Steps already in order stay silent. The fragment step runs `fragment apply`; narrate "Routing fragment restored." only when the verb reports `applied: true`. Read `old_version`/`new_version` from the envelope for the narration line. Steps 4c and 4d narrate only a change: an `imported` count above zero, or `action: written`. End with Step 7.

## Update (sub-flow)

Run `fragment apply` (fragment refresh + re-pin), Steps 4c and 4d, and Stage 3 (launcher refresh); skip onboarding. Read `old_version`/`new_version` from the verb envelope and report "Routing updated v<old_version> → v<new_version>." Steps 4c and 4d narrate only a change, as in Repair. End with Step 7.

## Health verify (menu action)

`anton report health --full`; print the severity and any failing checks with their `detail`. Writes nothing.

## Completion card

```
✓ anton-core — ready to use.

Try this next:
  <skill_invocation_prefix>save     "remember <a fact worth keeping>"
  <skill_invocation_prefix>recall    --code <symbol>
  <skill_invocation_prefix>summary   your daily briefing
```

`<skill_invocation_prefix>` is the current harness's entry in the probe's `harnesses[]`. When a repository was registered, name one in the `recall --code` line; when nothing was onboarded, collapse to `save` + `summary`. Never list a command that is not an installed skill.

## Uninstall

When `--uninstall` is present (or chosen from the menu):

1. **Pre-flight.** `anton setup uninstall [--purge-data] --dry-run --format json`. Capture `removed[*]` paths + `bytes`.
2. **Scope (skip when `--purge-data` already given).** Ask the operator: "Remove anton-core, keep my data" (default) vs "Remove everything, erase my data" (⚠ also deletes `~/.anton-core/data` — saved knowledge, tasks, logs; no undo). The erase choice sets `--purge-data`.
3. **Confirm.** Keep-data → a plain confirm listing each `removed[*]` path with humanized `bytes` and `kind`, the instructions-file fragment-wipe callout (sentinel region is plugin-managed; hand-edits inside go with it), and the symlink-removal note. Erase-everything → require **typed confirmation**: "Type `erase` to confirm." Any other input cancels with zero mutation.
4. **Breadcrumb before removal (keep-data only).** Append one line — `<ISO-8601 timestamp>\t<resolved paths>\t<total bytes>\t<scope>` — to `~/.anton-core/data/logs/uninstall.log`. Best-effort: a write failure is a warning, never a block. Under `--purge-data` that log goes with the root, so the summary card lists the removed paths instead.
5. **Execute.** `anton setup uninstall [--purge-data] --format json` (acquires the bootstrap lock; the verb also reaps the operator-shell command sites itself and reports each under `symlinks[*]`, reverts the `claude` settings setup wrote under `claude_settings`, and tears down every other installed harness's wiring — the fragment in its instructions file included — under `harness_settings.<id>`). The verb leaves the `claude` fragment alone: `Read` the `claude` entry's `instructions_target` from Step 1 — `$CLAUDE_CONFIG_DIR/CLAUDE.md`, or `~/.claude/CLAUDE.md` when that is unset — and if sentinels are present, `Edit` to delete the marker pair + body.
6. **Summary card.** Resolved paths removed, bytes freed (sum of `removed[*].bytes`), one line per operator-shell command site the verb reaped (from `symlinks[*]`: an `action: removed` site named as cleaned up, an `action: left_foreign` site named as left in place), one line per `claude_settings` value other than `absent`/`skipped` (`auto_memory: reverted` → the `claude` harness's own memory is back on; `left` → the operator's own setting stays; `profiler_env: removed` → the token-profiler setting is removed; `statusline: removed` → the status line no longer pipes through anton; `error` → one gentle sentence naming the setting not reverted), one line per `harness_settings.<id>` (its `changed[]` count as wiring removed; `native_memory: restored` → that harness's own memory is back as it was; `telemetry: restored` → its telemetry settings are back; `error` → one gentle sentence naming the harness not reverted), the callout that each harness's native memory files stay on disk and its setting reverts only if setup wrote it, the callout that a keep-data uninstall leaves `~/.anton-core` in place so a reinstall under either harness resumes on the same memory (after `--purge-data`, a reinstall is first-run), and the reminder to remove the anton-core plugin through each harness's plugin manager to complete removal.

## Behavior

After a successful install, `core.db` + `events.db` exist under the data root, schema'd and seeded; each installed harness is wired (`setup wire-harness`) and its global instructions file (`instructions_target`) carries the fragment between the sentinel pair, written once when two harnesses share the file; `~/.local/bin/anton` (when creation succeeded) points at the operator-shell launcher and the legacy `~/.local/bin/core` site is retired; `anton config get --key fragment.version` returns the shipped version; each harness's own memory is off unless the operator opted out or turned it on explicitly themselves. Re-running is idempotent: the probe and menu change no install state, and every execution step is a no-op when its precondition holds.
