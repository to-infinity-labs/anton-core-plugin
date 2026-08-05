# Changelog

All notable user-facing changes to anton-core are documented here.
This file is the source of the notes published on each GitHub release.

## [Unreleased]

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

[Unreleased]: https://github.com/to-infinity-labs/anton-core-plugin/compare/v2.6.0...HEAD
[2.6.0]: https://github.com/to-infinity-labs/anton-core-plugin/compare/v2.5.0...v2.6.0
[2.5.0]: https://github.com/to-infinity-labs/anton-core-plugin/compare/v2.4.0...v2.5.0
[2.4.0]: https://github.com/to-infinity-labs/anton-core-plugin/compare/v2.3.0...v2.4.0
