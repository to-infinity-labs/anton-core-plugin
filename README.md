# anton-core

A personal AI assistant for Claude Code and Codex that remembers what matters, understands
your codebase, and keeps your tasks and days in order, with its memory kept on your own machine.

## What it does

anton-core gives Claude Code and the Codex CLI a lasting memory and a working
knowledge of your projects, so they stop starting from zero every session. Use one or
both: they share the same memory, whichever you install first.

- **Remembers across sessions** — facts, decisions, and preferences persist, so you
  stop re-explaining context every time you open a session.
- **Recalls instead of reconstructing** — ask what you know about something and get
  it back in seconds, past sessions included.
- **Understands your codebase** — trace who calls a function, the blast radius of a
  change, and the path between two pieces of code, without grepping by hand.
- **Keeps your tasks straight** — capture todos and reminders, then get a daily
  briefing of what's due and what's on your plate.
- **Turns notes into action** — pull the action items, decisions, and open questions
  out of a meeting transcript or a wall of notes.
- **Shows you everything** — a local browser dashboard for your memory, tasks, and
  code, plus health and session stats on demand.

No account and no login. Your memory lives in files on your machine; the few things
that do go over the network are listed under [What leaves your machine](#what-leaves-your-machine),
each with its off switch.

## Requirements

- **Claude Code** or the **Codex CLI** (or both) — anton-core runs inside each as a plugin.
- **macOS, or Linux with glibc** (Debian, Ubuntu, Fedora and the like), on Intel (`amd64`)
  or Apple/ARM (`arm64`). musl-based Linux such as Alpine, and Windows, are not supported.
- **`bash`, `git` and `curl`** on your `PATH`. Setup checks for all three first and names
  any that are missing.

The correct binary for your platform is fetched and verified automatically the first
time you run setup — there's nothing to download by hand.

## Install

Three steps, about a minute. Below is Claude Code; Codex is [further down](#install-in-codex).
Run the first two inside Claude Code.

**1 — Add the marketplace and install the plugin**

```
/plugin marketplace add to-infinity-labs/anton-core-plugin
/plugin install anton-core@anton-core
```

**2 — Run setup**

```
/anton-core:setup
```

Setup fetches the signed binary for your platform, wires anton-core into Claude Code,
and offers to register your repositories and import a knowledge folder. It runs start
to finish **without any login, token, or account**. (A GitHub token is optional and
only raises GitHub API rate limits.)

**3 — Confirm it's working**

```
/anton-core:setup --check
```

You should see a healthy status and a summary of what's installed. If anything looks
off, re-running `/anton-core:setup` repairs it in place.

### Install in Codex

From a terminal, add the marketplace and the plugin:

```
codex plugin marketplace add to-infinity-labs/anton-core-plugin
codex plugin add anton-core@anton-core
```

Then, in a Codex session, run the setup skill:

```
$anton-core:setup
```

Setup trusts anton-core's hooks in your Codex config, lets Codex's sandbox write the
memory store, and links the `anton` command into `~/.local/bin`. Downloading the
binary needs network, which Codex's sandbox blocks, so approve that one step when
setup asks. If Claude Code already has anton-core, Codex finds the same memory.

In Codex every command below is written with `$` instead of `/` — `$anton-core:save`,
`$anton-core:recall` and so on.

## Your first two minutes

Save something, then ask for it back:

```
/anton-core:save     remember that the staging DB resets every Sunday at 02:00 UTC
/anton-core:recall   staging database reset
```

The second command returns what you just saved — proof the memory layer is live.
From there:

```
/anton-core:summary           your daily briefing — what's due, what's on your plate
/anton-core:recall --code     find a symbol by name instead of grepping
/anton-core:impact            see everything a change to a function would touch
```

## Everyday commands

| You want to… | Command |
| --- | --- |
| Save a fact, decision, or preference | `/anton-core:save` |
| Find anything you've saved | `/anton-core:recall` |
| Correct something you saved | `/anton-core:update` |
| Pull action items out of notes or a transcript | `/anton-core:extract` |
| Add a task or reminder | `/anton-core:tasks` |
| Get a daily or weekly briefing | `/anton-core:summary` |
| See who calls a function | `/anton-core:callers` |
| See the blast radius of a change | `/anton-core:impact` |
| Open the browser dashboard | `/anton-core:dashboard` |
| Check status / diagnose | `/anton-core:health` |

## Staying current

- **The engine** keeps itself up to date automatically — nothing to do.
- **Commands and behavior** update with the plugin, through each harness's plugin
  manager — in Claude Code, `/plugin update anton-core`.
- **In Codex 0.166 and later**, a plugin update asks you to review anton-core's
  hooks the next time Codex starts: choose "Trust all", or run
  `anton setup wire-harness --harness codex`. If you only run headless
  `codex exec`, run that command after updating; until then Codex skips the
  hooks, and `$anton-core:health` says so.

## What leaves your machine

Your memory, tasks, and indexed code stay in files under `~/.anton-core` — kept even if
you uninstall, unless you ask setup to erase them. There is no anton-core server, and no
telemetry is sent anywhere. These are the network calls it does make, and how to turn
each off (a config key is set with `anton config set --key <key> --value false`):

- **The embedding model**, fetched once from huggingface.co, and **the llama.cpp
  executable** that runs it, fetched once from llama.cpp's GitHub releases. Both run
  locally afterwards; your text is embedded on your machine. Off: `embedder.enabled`,
  which leaves search on words and links alone.
- **The anton-core binary**, from this project's releases on github.com, at setup and
  when a plugin update ships a newer engine. Nothing checks for updates in between. Off:
  don't update the plugin — in Claude Code, leave auto-update off for this marketplace
  in `/plugin`; in Codex, skip `codex plugin` updates.
- **Session transcripts and saved memories, sent to the model through your own `claude`
  or `codex` CLI**, on your existing account and its terms: summarising a session,
  extracting its action items and decisions, deep analysis, and judging which memories
  are related. Off: `headless.enabled`, which stubs these passes out. Each pass stops at
  a dollar cap:
  - `summarize.max_budget_usd` (default $1.00) per session summary
  - `session_intelligence.deep_analysis_max_budget_usd` (default $2.00) per deep analysis
  - `link.max_budget_usd` (default $5.00) per linking pass
  - `dream.max_budget_usd` (default $5.0) per theme pass
  - `vision.max_budget_usd` (default $0.25) per scanned PDF read

## Verifying a release

The binary ships as a signed release artifact, and setup verifies it before it ever runs:

- **Checksums, always.** Every binary is published with a `checksums.txt` and checked
  on download.
- **Signatures, when available.** With [cosign](https://github.com/sigstore/cosign)
  installed, setup additionally verifies a keyless Sigstore signature.

Prefer to verify it yourself? Every [release](https://github.com/to-infinity-labs/anton-core-plugin/releases)
publishes the per-platform binaries, a `checksums.txt`, and a `.sigstore.json` signature
bundle per binary. To check a download by hand (macOS shown; use `sha256sum` on Linux):

```
shasum -a 256 anton-core-v<version>-darwin-arm64
grep darwin-arm64 checksums.txt        # the two hashes should match
```

## Support

Questions, bugs and feature requests go to
[GitHub Issues](https://github.com/to-infinity-labs/anton-core-plugin/issues). Report a
security vulnerability privately instead, through
[GitHub private vulnerability reporting](https://github.com/to-infinity-labs/anton-core-plugin/security/advisories/new);
`SECURITY.md` in the plugin says more.

## License

See [LICENSE](/LICENSE).
