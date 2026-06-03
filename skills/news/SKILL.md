---
name: news
description: Poll configured news sources (Claude Code releases, Anthropic announcements) and surface new items as improvement proposals. Use for "news", "what's new", "claude code updates", or "any updates".
allowed-tools: Bash
---

## What it does

Polls operator-edited news sources (changelogs, GitHub releases, web pages), dedupes against the unified store, and emits feature-proposal stubs tagged `core-improvement,pending` for relevant new features. Per-source freshness cursors gate every fetch; stale pending proposals auto-re-tag to `dismissed-stale` before new proposals are emitted.

## When to use

- "news", "what's new", "claude code updates"
- "any updates", `/anton-core:news`
- Periodic check for upstream releases worth turning into improvement proposals

## How

```
"${CLAUDE_PLUGIN_ROOT}/scripts/core" news poll [--dry-run] [--source <source-id>] [--format json]
```

Default polls every enabled source in `${CLAUDE_PLUGIN_DATA}/config/news-sources.json` whose `last_news_check.<source-id>` is older than `check_interval_hours`. `--source` restricts to the given source id (repeatable). `--dry-run` fetches without writing, populating the envelope but skipping all DB mutations.

## Output

Default success envelope carries `sources_polled` (list), `sources_skipped` (list), `items_added` (int), `proposals_added` (int), `dismissed_stale` (int). `sources_errored` appears when any source hit an io_error; `dry_run: true` appears under `--dry-run`. New news entries land as `Document` items tagged `source:news-feed,<source-tags>`; new proposals land as `Fact` items tagged `core-improvement,pending,<source-id>`. Contract: [docs/plugin-spec/05-cli-contract.md#news-poll](../../docs/plugin-spec/05-cli-contract.md#news-poll).
