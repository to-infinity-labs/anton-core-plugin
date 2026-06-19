# anton-core

A personal AI assistant for Claude Code that remembers what matters, understands
your codebase, and keeps your tasks and days in order — entirely on your own machine.

## What it does

anton-core gives Claude Code a lasting memory and a working knowledge of your
projects, so it stops starting from zero every session.

- **Remembers across sessions** — facts, decisions, and preferences persist, so you
  stop re-explaining context every time you open Claude Code.
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

No account. No cloud. No login. Everything stays on your machine.

## Requirements

- **Claude Code** — anton-core runs inside it as a plugin.
- **macOS or Linux**, on Intel (`amd64`) or Apple/ARM (`arm64`). Windows is not supported.

The correct binary for your platform is fetched and verified automatically the first
time you run setup — there's nothing to download by hand.

## Install

Three steps, about a minute. Run the first two inside Claude Code.

**1 — Add the marketplace and install the plugin**

```
/plugin marketplace add xlightxyearx/anton-core-plugin
/plugin install anton-core@anton-core
```

**2 — Run setup**

```
/anton-core:setup
```

Setup fetches the signed binary for your platform, wires anton-core into Claude Code,
and offers to register your repositories and import a knowledge folder. It runs start
to finish **without any login, token, or account**. (A GitHub token is optional and
only raises rate limits for the news poller.)

**3 — Confirm it's working**

```
/anton-core:setup --check
```

You should see a healthy status and a summary of what's installed. If anything looks
off, re-running `/anton-core:setup` repairs it in place.

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
| Pull action items out of notes or a transcript | `/anton-core:extract` |
| Add a task or reminder | `/anton-core:tasks` |
| Get a daily or weekly briefing | `/anton-core:summary` |
| See who calls a function | `/anton-core:callers` |
| See the blast radius of a change | `/anton-core:impact` |
| Open the browser dashboard | `/anton-core:dashboard` |
| Check status / diagnose | `/anton-core:health` |

## Staying current

- **The engine** keeps itself up to date automatically — nothing to do.
- **Commands and behavior** update with the plugin: `/plugin update anton-core`.

## Private by design — and verifiable

anton-core keeps everything local. Your memory, tasks, and indexed code stay in files
on your machine — there's no server to send them to and no account to create.

The binary ships as a signed release artifact, and setup verifies it before it ever runs:

- **Checksums, always.** Every binary is published with a `checksums.txt` and checked
  on download.
- **Signatures, when available.** With [cosign](https://github.com/sigstore/cosign)
  installed, setup additionally verifies a keyless Sigstore signature.

Prefer to verify it yourself? Every [release](https://github.com/xlightxyearx/anton-core-plugin/releases)
publishes the per-platform binaries, a `checksums.txt`, and a `.sigstore.json` signature
bundle per binary. To check a download by hand (macOS shown; use `sha256sum` on Linux):

```
shasum -a 256 anton-core-v<version>-darwin-arm64
grep darwin-arm64 checksums.txt        # the two hashes should match
```

## License

See [LICENSE](/LICENSE).
