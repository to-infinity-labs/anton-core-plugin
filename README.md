# anton-core

Personal AI assistant for knowledge, tasks, and daily productivity — skills,
hooks, and a local SQLite store (FTS5 + vector + graph) layered on Claude Code.

## Install (no authentication required)

```
/plugin marketplace add xlightxyearx/anton-core-plugin
/plugin install anton-core@anton-core
```

On first use, the plugin fetches its signed binary for your platform over HTTPS
from this repo's [Releases](https://github.com/xlightxyearx/anton-core-plugin/releases)
and verifies it (`checksums.txt` always; cosign signature when `cosign` is
installed). Then run setup:

```
/anton-core:setup
```

Setup runs **without any token or login**. (A GitHub token is optional and only
raises API rate limits for the news poller.)

## Updating

- **Binary:** self-updates automatically on its own cadence — no action needed.
- **Static surface (skills/hooks):** `/plugin update anton-core` re-pulls this repo.

## What's here

This repository is a **generated distribution artifact** — the plaintext static
surface (skills, hooks, runtime scripts) plus per-platform signed binaries in
Releases. It is regenerated from the upstream source on every release and is
never hand-edited. Pull requests against it will not be merged; file issues
upstream.

## License

See [LICENSE](/LICENSE).
