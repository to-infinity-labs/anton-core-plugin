---
name: setup
description: First-run installer that initializes the database, merges the routing block into the user-global CLAUDE config, registers repositories, optionally bulk-imports a knowledge directory, creates a shell-PATH symlink, and supports --uninstall removal. Use for "set up", "install anton-core", "initialize", "re-run setup", "configure anton-core", or "uninstall anton-core".
allowed-tools: Read, Edit, Bash, AskUserQuestion
---

## What it does

End-to-end first-run installer for the plugin. Initializes `core.db` + `events.db` (schema + DEFAULT_CONFIG seed), merges the plugin-shipped fragment into `~/.claude/CLAUDE.md`, optionally installs an operator-shell launcher (`~/.local/bin/core` → `${CLAUDE_PLUGIN_DATA}/data/bin/core`) that execs the live self-update binary so a bare-shell `core` never goes stale after a `/plugin update`, and pins the `fragment.version` so subsequent runs idempotently detect the no-op fast path. Every binary invocation routes through `${CLAUDE_PLUGIN_ROOT}/scripts/core`, which auto-fetches the per-platform artifact on first call (see [ADR-0032](../../docs/adr/0032-marketplace-binary-distribution.md)).

## When to use

- "set up", "install anton-core", "initialize", "re-run setup"
- "configure anton-core", `/anton-core:setup`
- After a plugin update that ships a newer `claude-md-fragment.md`

## How

### Step 0. Argument triage

If the operator's invocation arguments include the literal string `--uninstall`, jump to the **Uninstall** section below; do not run Steps 1–7. Also reject these combinations in prose before doing anything:

- `--purge-data` without `--uninstall` → "`--purge-data` is only valid with `--uninstall`".
- `--uninstall` with `--re-onboard` → "`--uninstall` and `--re-onboard` are mutually exclusive".
- `--check` with any of `--uninstall` / `--purge-data` / `--re-onboard` → "`--check` is mutually exclusive with the destructive flags".

The skill orchestrates these steps, using Claude Code tools for file IO and the `${CLAUDE_PLUGIN_ROOT}/scripts/core` shim for state writes:

### Paste-input normalization (applies to every operator-pasted string in this skill)

1. Strip leading/trailing whitespace (ASCII space, tab, `\r`, `\n`, `\v`, `\f`).
2. Convert CRLF and lone CR to `\n`.
3. Reject any paste containing non-printable bytes other than `\n` / `\t` — re-prompt once, then abort the step on a second occurrence.
4. For newline-separated pastes (repos), split AFTER normalization, trim each line, drop empties.

1. **Database init.** Run `"${CLAUDE_PLUGIN_ROOT}/scripts/core" db init`. The shim sources `lib/wrapper.sh`, which auto-fetches the per-platform binary into `${CLAUDE_PLUGIN_DATA}/data/bin/anton-core-v${VERSION}` on first call (the natural bootstrap trigger). `db init` materializes `core.db` + `events.db`, applies all migrations, and seeds DEFAULT_CONFIG rows via `INSERT OR IGNORE`. Idempotent on re-run. Surface any non-zero exit as a setup-blocked notice naming the `reason` field from the precondition envelope.

### Step 1a. Persist data-root

Run `"${CLAUDE_PLUGIN_ROOT}/scripts/core" setup persist-data-dir`. Records the resolved data root in `~/.anton-core/config.json` so operator-shell `core` invocations (which lack `CLAUDE_PLUGIN_DATA`) resolve to the same persistent root as hooks/skills. Idempotent overwrite. Non-fatal warning on failure — the data-root override is a convenience for shell use, not required for the hook/skill lifecycle.

### Step 1b. Token precondition

Run `"${CLAUDE_PLUGIN_ROOT}/scripts/core" setup get-token --format json`.

- **Exit 0:** read the raw token from stderr (a single line, no decoding) and prepend `ANTON_GITHUB_TOKEN=<token>` to every subsequent `"${CLAUDE_PLUGIN_ROOT}/scripts/core"` invocation in this skill run. The token never appears in operator-facing prose, summaries, or telemetry.
- **Exit 3 (no token):** proceed without a token — do **not** prompt for `gh auth login` and do **not** abort. The token is optional; it only raises GitHub API rate limits for the news poller. Continue setup with no `ANTON_GITHUB_TOKEN` exported. (Goal: unauthenticated first-run — see docs/adr/0037-public-distribution.md.)

The exported `ANTON_GITHUB_TOKEN` lives only for this skill run — subsequent setup runs re-resolve from the env / `gh` waterfall.

2. `Read` the plugin-shipped fragment at `${CLAUDE_PLUGIN_ROOT}/claude-md-fragment.md` (frontmatter carries `fragment-version`).

3. `Read` the operator's `~/.claude/CLAUDE.md` (treat absence as an empty file).

4. Scan for the sentinel pair `<!-- anton-core:start -->` and `<!-- anton-core:end -->`. **If present**, use `Edit` to replace the byte range between (and including) those markers with the new fragment body, keeping the sentinels intact. **If absent**, use `Edit` to append the fragment body bracketed by a fresh sentinel pair to EOF.

5. **Operator-shell launcher (optional).** Install the data-dir launcher and point the `~/.local/bin/core` PATH symlink at it, so a bare-shell `core <verb>` always execs the live self-update binary (`data/versions/current`) rather than the version-pinned plugin cache that `/plugin update` rotates. Three ordered sub-steps; the whole step is convenience, not a hard requirement.

   **5a. Materialize `current`.** Run `"${CLAUDE_PLUGIN_ROOT}/scripts/core" update status >/dev/null 2>&1`. This verb is read-only (no network) but constructs the update orchestrator, which runs the one-shot legacy→versioned migration: it moves the first-install binary from `data/bin/anton-core-v${VERSION}` into `data/versions/v${VERSION}/anton-core`, writes the `installed-version` pin, and creates the `data/versions/current` symlink the launcher execs. A non-zero exit is a non-fatal warning (the launcher guards a missing `current`). Then confirm `[ -L "${CLAUDE_PLUGIN_DATA}/data/versions/current" ]`; if absent, emit a one-line stderr warning and continue.

   **5b. Install the launcher.** `mkdir -p "${CLAUDE_PLUGIN_DATA}/data/bin"`. When `${CLAUDE_PLUGIN_DATA}/data/bin/core` is absent or differs (`! cmp -s "${CLAUDE_PLUGIN_ROOT}/scripts/core-shim.sh" "${CLAUDE_PLUGIN_DATA}/data/bin/core"`), copy the shipped `scripts/core-shim.sh` into place and `chmod +x` it. Idempotent — a byte-identical launcher is left untouched. On `mkdir`/`cp` failure emit a one-line stderr warning and skip the rest of Step 5.

   **5c. PATH symlink.** Create or refresh `${HOME}/.local/bin/core` → `${CLAUDE_PLUGIN_DATA}/data/bin/core`. `mkdir -p "$HOME/.local/bin"`; on mkdir failure emit a one-line stderr warning naming the directory and the errno, then skip (the symlink is convenience). At the symlink site:
   - Site absent → create the symlink.
   - Site is a symlink AND `readlink` matches `${CLAUDE_PLUGIN_DATA}/data/bin/core` byte-for-byte → no-op.
   - Site is any symlink to anything else (the legacy `${CLAUDE_PLUGIN_ROOT}/scripts/core` target from a pre-launcher install, a different path, a dangling target) → overwrite via `ln -sfn` — this auto-migrates an existing install onto the launcher.
   - Site exists but is NOT a symlink (regular file, dir, device) → refuse to clobber; emit a stderr warning naming the file; setup continues.

   If `$HOME/.local/bin` is not on `$PATH`, emit a one-line stderr notice with the shell-RC line to add (e.g., `export PATH="$HOME/.local/bin:$PATH"`). Do NOT modify the operator's shell-RC.

6. **Version pin (verify-back gate).** Compare the new `fragment-version` to the value returned by `"${CLAUDE_PLUGIN_ROOT}/scripts/core" config get --key fragment.version`; when the version advanced (or the row is absent), record the new pin via `"${CLAUDE_PLUGIN_ROOT}/scripts/core" config set --key fragment.version --value <X.Y.Z>`. Re-read the value; refuse to advance to Step 7 until the read-back returns the written value (defends against silent DB-locked / disk-full writes).

### Step 6b. Interactive onboarding (gated)

1. Inspect the operator's invocation for the literal string `--re-onboard`. Record it.
2. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/core" onboarding check`.
3. If `shown: true` AND `--re-onboard` was not present, skip directly to Step 7.
4. Otherwise run the three sub-steps:
   - **6b.a Repos.** Render an `AskUserQuestion` block: "Register repositories with anton-core? Paste absolute paths, one per line. Type \"skip\" to skip this step." Options: "Paste paths" (Other/free-text), "Skip for now". On paste: split (post-normalization), trim each line, drop empties, reject relative paths in prose. **Classify each path before registering it:** if the path itself contains a `.git` entry it is a single repo — register it with `"${CLAUDE_PLUGIN_ROOT}/scripts/core" repos add <path>`. If the path has no `.git` of its own but two or more of its immediate children do, the operator likely pasted a directory holding many repos; registering it as one repo would mint a single slug spanning every child, so do not do that silently. Warn and render a second `AskUserQuestion`: "<path> looks like a parent of multiple repositories, not a single repo. Register it as…" with options "Parent of many (Recommended)" and "A single repository". On "Parent of many" → `"${CLAUDE_PLUGIN_ROOT}/scripts/core" repos add <path> --type parent` (the binary expands a parent into one entry — and one slug — per child checkout); on "A single repository" → the plain `repos add <path>`. To instead scan a directory tree for unregistered checkouts, suggest `repos add --discover --base-dir <path>`. Render `✓ <path> (slug: ...)` on success, `✗ <path> — <reason>` on failure. Per-path failures do not abort.
   - **6b.b Bulk-import.** Render an `AskUserQuestion` block: "Bulk-import a knowledge directory now? Provide an absolute path or type \"skip\"." On a path: run `"${CLAUDE_PLUGIN_ROOT}/scripts/core" item bulk-import --path <dir> --recursive --dry-run --format summary`. On `file_count == 0`, report the count and continue. Otherwise render `file_count` + `by_type` + `dropped_by_owner_filter`, then render a second `AskUserQuestion` confirm. On confirm: re-run without `--dry-run`. Render `imported` / `tasks_created` / `errors`.
   - **6b.c Mark shown.** Run `"${CLAUDE_PLUGIN_ROOT}/scripts/core" onboarding mark-shown`. Failure is a warning, not fatal.

7. **Health verify.** Run `"${CLAUDE_PLUGIN_ROOT}/scripts/core" report health --full`. Surface the failing check names + their `detail` fields if `report.severity == "critical"`; setup exits successfully on `healthy` or `warning`/`degraded` with the warning list embedded in the operator-facing summary.

The skill never shells `sed` or `awk` — `Edit` is the only file mutator, and every step is a no-op when its precondition already holds.

## Behavior

After a successful run, `core.db` and `events.db` exist at `${CLAUDE_PLUGIN_DATA}/data/`, fully schema'd and seeded; `~/.claude/CLAUDE.md` contains the fragment body bracketed by the `<!-- anton-core:start -->`/`<!-- anton-core:end -->` sentinel pair; `~/.local/bin/core` (when creation succeeded) is a symlink to the operator-shell launcher at `${CLAUDE_PLUGIN_DATA}/data/bin/core`, which execs `data/versions/current`; `"${CLAUDE_PLUGIN_ROOT}/scripts/core" config get --key fragment.version` returns the fragment's frontmatter version. Re-running over an up-to-date install rewrites the same bytes and re-pins the same version — no diff, no surprise. Spec: [docs/plugin-spec/07-skills/setup.md](../../docs/plugin-spec/07-skills/setup.md).

## Uninstall

When `--uninstall` is present in the operator's args:

1. **Pre-flight.** Run `"${CLAUDE_PLUGIN_ROOT}/scripts/core" setup uninstall [--purge-data] --dry-run --format json`. Capture the envelope.

2. **Confirm.** Render a single `AskUserQuestion` block listing each `removed[*]` path with its `bytes` (humanized) and `kind`, plus three callouts:
   - the CLAUDE.md fragment between `<!-- anton-core:start -->` / `<!-- anton-core:end -->` will be wiped (sentinel region is plugin-managed; operator hand-edits inside the markers go with it);
   - the `~/.local/bin/core` symlink will be removed only when its target resolves to the launcher at `${CLAUDE_PLUGIN_DATA}/data/bin/core`;
   - when `--purge-data` is set, a destructive callout: "This permanently erases your operator content. There is no undo."
   Options: "Yes, uninstall" / "Cancel". Cancel exits cleanly with zero filesystem mutation.

3. **Execute (on Yes):**
   a. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/core" setup uninstall [--purge-data] --format json`. The verb acquires `<CLAUDE_PLUGIN_DATA>/data/bin/.bootstrap.lock` before the first removal — same derivation as `scripts/lib/wrapper.sh`, so a concurrent bash bootstrap cannot race the removal. Surface any non-zero envelope verbatim.
   b. `Read` `~/.claude/CLAUDE.md`. If sentinels are present, use `Edit` to delete the marker pair + body. No-op if sentinels are absent.
   c. Bash: `readlink ~/.local/bin/core 2>/dev/null`. If the resolved target equals `${CLAUDE_PLUGIN_DATA}/data/bin/core` (the launcher), `rm -f ~/.local/bin/core`. Otherwise emit a one-line stderr warning ("not the launcher symlink, leaving in place") and continue. (Step 3a's `setup uninstall` verb already wiped `${CLAUDE_PLUGIN_DATA}` wholesale — taking the launcher copy at `data/bin/core` with it — so this step removes only the home-dir symlink.)

4. **Summary.** Print the resolved paths removed, bytes freed (sum of `removed[*].bytes`), the reminder to run `/plugin uninstall anton-core` separately to complete plugin removal, and the explicit callout that per-project memory under `~/.claude/projects/.../memory/` is untouched. Also note: a subsequent fresh install will be treated as first-run (the welcome flag was in the now-wiped config table).
