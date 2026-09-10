# Changelog

All notable user-facing changes to anton-core are documented here.
This file is the source of the notes published on each GitHub release.

## [Unreleased]

## [2.7.0] - 2026-09-10

### Changed

- Closing a session is cheaper and quieter. Anton used to build its knowledge
  graph as you closed a session, asking a separate model process about one pair
  of memories at a time — which is why the pass never finished and why a
  rate-limited account could leave it spawning processes for half an hour.
  Consolidation now runs once a day on its own, in the background, and closing a
  session just writes its summary. An import builds the graph only if you ask it
  to, with `--consolidate`.

- When the model says you have hit a limit, Anton believes it the first time,
  waits until the reset time the answer named, and spends nothing in between.

- The graph is built for a fraction of what it cost. Pairs the embedding
  similarity already answers never reach the model at all, and the questions
  that do go twenty-five to a call instead of one — roughly a fifteen-fold cut
  in tokens per answer.

### Added

- `anton maintenance calibrate --target link` reads the judge's own past answers
  against the similarity of the pairs it was asked about, and tells you where to
  set the two thresholds that gate it — with the reasoning, and with nothing at
  all when there is not enough evidence to say.

- `anton maintenance reset --target link-cursor --to <when>` rewinds the graph
  pass to an earlier date, so items a degraded pass skipped get looked at again.
  It previews the move first, and it refuses to move forward.

- `anton maintenance consolidate --dry-run` now tells you what tomorrow's pass
  would cost before it spends it, and `anton report health` shows how old the
  backlog is and how many tokens the last pass burned.

### Fixed

- Path-alias patterns in `tsconfig.json` are now matched the way TypeScript
  matches them, because the matcher is a port of TypeScript's own rather than an
  approximation of it. A single `*` may sit anywhere in a pattern, so mappings
  such as `"@app*"` or `"*.css"` resolve at all; exact patterns are tried before
  wildcard ones; and when two patterns match equally well the one written first
  in the file wins, which is TypeScript's rule and was not the previous one. A
  pattern that matches now yields only its own targets — it never falls back to
  a shorter pattern — and relative imports (`./x`, `..\x`) are still never
  routed through `paths`. A config that extends another and then declares
  `"paths": {}` — or `"paths": null` — now clears the inherited mappings
  instead of quietly keeping them, which is what `tsc` does with either, a
  mapping written twice keeps its last value, and a pattern matching with nothing in the
  `*` uses its target exactly as written. A mapping `tsc` itself rejects — more
  than one `*` in a pattern or in one of its targets — is now always reported in
  the resolver's log line and counters rather than passing unremarked. Two
  differences from `tsc` are deliberate: candidates are not probed on disk, and
  one resolving outside the repository is dropped, since nothing there can be
  indexed.

- TypeScript and JavaScript repositories were being indexed with a large share
  of their internal links missing, and nothing said so. Path aliases — the
  `@/...` style imports configured in `tsconfig.json` — were resolved against
  the wrong directory. The search started at the repository root rather than at
  the config governing the file doing the importing, so a workspace inside a
  monorepo never had its own config read, `extends` chains were never followed,
  and the common `"@/*": ["./*"]` mapping re-anchored on whichever file happened
  to be importing. Every link that depended on an alias was simply absent, and
  an absent link looks exactly like a repository that has none. Aliases now
  resolve the way TypeScript itself resolves them, including `extends` chains in
  both supported forms, configs written with comments in them, and mappings with
  several targets.

  One consequence is worth expecting: the code-graph resolution rate in
  `anton report health` may read *lower* than before on a TypeScript
  repository. The old figure excluded unresolved targets by naming convention,
  which hid the very links that were missing. The links were always missing;
  only the number is new.

- `anton graph reset --repo <slug>` reported success without clearing anything.
  Code and document items live in a per-repository store, and the reset was
  deleting rows from the main database instead — so its counts were
  structurally zero, and the fully-populated store was left on disk, where a
  later reindex reopened it and the orphan sweep declined to touch it. Reset now
  removes that store and reports what it removed, so a reindex after a reset
  starts clean. Resetting a repository whose slug contains an underscore also no
  longer disturbs a similarly-named sibling.

- Deleting a repository stopped under-reporting, and both delete commands
  stopped refusing to delete. `anton repos remove` counted the per-repository
  store only when `--prune` was passed, although the store is removed either
  way, so items that had genuinely gone were reported as zero; it now counts
  both stores whether or not the flag is used. Separately, a store written by an
  older release — one the running binary cannot read — used to abort both
  `anton graph reset` and `anton repos remove`, which left no way to clear the
  exact state reset exists for. Such a store is now torn down, with its item
  counts reported as unknown rather than as zero, since zero would claim an
  empty store that nothing actually read. Genuine corruption still refuses,
  unchanged.

### Added

- Alias targets that point outside a repository, and `extends` chains that reach
  above it, are now named in the log and counted instead of being dropped in
  silence. Both are legitimate in a monorepo layout, so neither is an error —
  but they mean the alias table depends on files sitting outside the checkout,
  and identical repository contents can then index differently on two machines.
  That is worth being able to see.

## [2.6.0] - 2026-08-05

### Fixed

- A rare update fault could leave Claude Code unable to accept a prompt or an
  edit, and `anton report health` would call the machine healthy while it
  happened. If the recorded version pointed at a copy of anton-core that was no
  longer on disk, every hook refused to run — which is the correct refusal, but
  nothing said so. Housekeeping could also delete that copy itself. Housekeeping
  now keeps whatever version is in use, health reports the fault as critical and
  names the version, and the report tells you to run `anton update rollback` to
  get back to a working session.
- Consolidation stopped paying to re-decide the same pairs every night. It kept
  no record of a "not related" verdict, so once a run hit its budget the next
  run started over on the same leading candidates — spending a full budget to
  add roughly one link, night after night, while `anton report health` reported
  everything healthy. Settled verdicts are now remembered, so each run works on
  candidates it has not seen. If your graph has been static for weeks with a
  large backlog, this is why.
- The daily maintenance cycle could wedge partway through and stay wedged. The
  job that cleans up stray relationship labels aborted on a single row written
  by an older release — exactly the rows it exists to clean — and because the
  cycle stops at the first failing job, everything scheduled after it (decay,
  backfill, dedup, purge, and both repository sweeps) never ran again, with
  nothing left in the cycle able to clear the row that caused it. Each row is
  now handled on its own, and anything unfixable is named rather than fatal.
- A model refusing to answer no longer looks like an empty success. Refusals
  during import and during consolidation are recorded, counted against the
  budget they used to bypass, and are visible after the fact instead of costing
  one log line per process.

### Added

- `anton report health` can now say a consolidation pipeline is stuck — three
  runs in a row that all stopped on budget and settled nothing — and reports
  that it cannot tell, rather than reading green, when its own checks fail.
- `anton maintenance reset --target judged-refusals` reopens pairs a model
  previously refused, for the case where a model revision starts refusing a
  whole class of content.
- The consolidation configuration keys are documented, including the budget
  ceiling per run that the health panel's own advice tells you to raise.

### Changed

- Release notes are now written for you rather than lifted from the
  engineering changelog. Each release page describes what changed in the
  plugin you install, and the same notes ship inside the package as
  `CHANGELOG.md`.
- Release pages for versions published before this change now point at that
  changelog instead of carrying the old engineering notes.

## [2.5.0] - 2026-07-26

### Added

- Reclaim disk from code-graph stores whose repository no longer exists:
  `anton maintenance prune --target graph-stores`. Preview with `--dry-run`. A
  store is removed only when its repository is provably gone — anything
  uncertain is kept.
- `anton report health` reports on those stores, and the dashboard's repos tab
  shows a matching card.
- Clearer results when a command succeeds but did nothing useful. Adding a
  repository that indexed no files, or indexing a directory that will never be
  refreshed, now says so instead of reporting a silent success.
- Go type declarations are indexed, so a call that resolves to a named type
  (a conversion such as `identity.UserID(x)`) now links to its definition.

## [2.4.0] - 2026-07-24

### Added

- Held updates repair themselves. An update blocked by a damaged search index
  is now repaired automatically — proven on a throwaway copy before anything is
  written to your real data — instead of staying held until you intervene.
- Stores stranded on an older release heal on the first open after upgrading.
- `anton update status` shows when a held update repaired itself, and the
  session start-up message names the command that will actually clear a held
  update rather than one that cannot.

[Unreleased]: https://github.com/to-infinity-labs/anton-core-plugin/compare/v2.7.0...HEAD
[2.7.0]: https://github.com/to-infinity-labs/anton-core-plugin/compare/v2.6.0...v2.7.0
[2.6.0]: https://github.com/to-infinity-labs/anton-core-plugin/compare/v2.5.0...v2.6.0
[2.5.0]: https://github.com/to-infinity-labs/anton-core-plugin/compare/v2.4.0...v2.5.0
[2.4.0]: https://github.com/to-infinity-labs/anton-core-plugin/compare/v2.3.0...v2.4.0
