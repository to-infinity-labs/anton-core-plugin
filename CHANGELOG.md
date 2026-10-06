# Changelog

All notable user-facing changes to anton-core are documented here.
This file is the source of the notes published on each GitHub release.

## [Unreleased]

## [3.0.0] - 2026-10-06

### Breaking

- `anton item save` and `anton item update` take `--tag` once per tag, and a
  comma stays part of the tag; `--tags` is gone. `anton task add --tag` no
  longer splits a tag on commas either.

### Added

- `anton task list` returns each task's tags as a list (`tags`), so a tag
  containing a comma can be told apart from two tags.
- Setup now turns off Claude Code's own memory, so your notes live in one
  place, and first offers to bring the notes Claude Code saved on its own
  into the assistant's memory; that offer remembers a "no". Turning the
  memory off is the default: to keep it, run `anton config set --key
  setup.native_memory.declined --value true` and `anton setup native-memory
  --remove`. A setting you set to `true` yourself is left alone and
  reported. `anton setup
  native-memory` and `anton item import-native` run the two steps directly;
  uninstall turns Claude Code's memory back on if setup turned it off.
- The health report shows whether Claude Code's own memory is off and how
  many of its notes are not yet imported.
- `anton usage span` shows where the time went (the model, waiting, idle
  time and each kind of tool), how often and how far each session's context
  was compacted, and tokens per kind of helper agent, with general-purpose
  helpers listed by name.
- The code graph indexes markdown headings and the links that point at them,
  within a file or across files. Each existing graph is rebuilt once, in the
  background, the first time it is read.
- Your plan's usage limits are tracked: `anton setup statusline` adds
  `anton usage statusline` to Claude Code's status line, which records the
  5-hour and 7-day percentages it is sent. `anton usage stats` and the
  dashboard's `/usage` page show them with their reset times, and say so
  when the reading is old.
- `anton usage doctor --all` checks every session's token figures at once,
  and `--dry-run` shows what `--repair` would change without changing it.
- `anton maintenance purge --target token-usage --before <YYYY-MM>` deletes
  old months of token history; nothing else ever trims it, and the health
  report warns when it grows large.
- `anton report recall` shows how often recalls were followed by expands,
  against the period before.

### Changed

- Dollar amounts read `$2,904.01` everywhere: in `anton usage stats`, the
  dashboard and the health report.
- Setup's data-folder step no longer erases other settings in
  `~/.anton-core/config.json`.
- The skills, the CLAUDE.md fragment and the text the assistant injects at
  session start were reviewed against Anthropic's guidance and tightened.
- Background AI jobs (extraction, scanned-PDF reading, linking, dreaming and
  session summaries) run on Sonnet 5.5 instead of Haiku 4.5, and theme
  synthesis and deep analysis on Opus 5.5, all at low effort. Each job has an
  `*.effort` setting; a mistyped value is refused with an error naming it.
- Session start shows at most three distinct suggested improvements, with a
  count of the rest, and deep analysis no longer re-suggests what it already
  suggested.

### Fixed

- The dashboard's daily token chart is readable in dark mode; its title,
  legend and axis labels were drawn in black.
- Hook commands show their real options in `--help` even before a data
  folder is set up.
- `anton graph query dependents-by-complexity --help` shows one default for
  `--min-cyc` instead of two contradictory ones.
- When saving a note that already exists with `--relate`, the warning gives
  the full `anton item relate` command for each link you asked for.
- Saving a note with tags keeps the tags however the note is saved; tags
  given alongside a file or a batch of items were dropped.
- Scanned PDFs are read again: the file path now reaches the model. Token
  costs are priced correctly for Sonnet 5, Sonnet 5.5, Fable 5.1 and Mythos 5.1.
- Daily maintenance now cleans up memory links whose type is not a real link
  type even when that type contains a capital letter. Links written before
  2.6.0 sometimes stored a whole sentence as their type ("Both address
  CI-gating concerns…") or an uppercase `RESOLVES`. Maintenance skipped these
  without reporting them, so `--rel-types` filters missed them. They are now
  retyped to `relates_to` (or `resolves`), and the original text is kept on
  the link.
- Saving a long note no longer warns that its text was truncated. Decisions,
  key points and action items pulled from a saved document can be found by
  meaning straight away, without waiting for a reindex. A note whose meaning
  search could only partly be built is now picked up and finished by
  `anton maintenance reindex`.

### Removed

- The `maintenance.unspecified_rel_threshold` setting. Nothing read it, and
  the warning it described never existed. Upgrading deletes the stored value.

## [2.11.0] - 2026-09-30

### Added

- `anton report health` warns about tasks whose due date or reminder is not a
  `YYYY-MM-DD` date, since no date filter can match them. It only reports;
  `anton task update --due` fixes a row.

### Fixed

- Updating no longer lets a still-running older Anton undo the new version's
  graph stores: the update stops older background work first. Background
  indexing now really runs at low priority and uses at most three cores by
  default; 2.10.0's note promised this but applied it to only one kind of
  background build.
- Task dates must be real `YYYY-MM-DD` dates. `--due today` or
  `--due 2026-13-45` on `task add` and `task update` (and the same for
  `--reminder`, `--due-before` and `--due-on`) is refused with an error naming
  the flag, instead of being stored where no query would ever find it.
- When a setup command refuses to run, it reports the error once, on stderr.
  It used to print it on stdout and then print a second, emptier error.
- Database errors keep SQLite's own message, e.g.
  `no such column: last_accessed`, instead of ending in a bare `internal`.
- A stray word after a command is reported as an unknown command instead of an
  internal error, or instead of being silently ignored — `task add bogus
  --title x` no longer creates a task.
- `system warm` and `maintenance` commands run without `--target` now say
  `--target is required`.

## [2.10.0] - 2026-09-28

### Added

- Code search follows class hierarchies in every language it indexes. It
  records which classes extend or implement which, and a method call that is
  not found on a class is looked up on its parents.

- In TypeScript, `new Widget(x)` now counts as a call to `Widget`, so asking
  who calls a class shows where it is created.

- Ruby and PHP files now have call links, not just their definitions.

- Code search now works inside git worktrees. Each worktree gets its own code
  graph, copied from the main checkout's graph the first time you ask and then
  caught up on that branch's commits and your uncommitted edits. If catching up
  takes longer than about five seconds, the rest finishes in the background at
  low priority and the answer says it is still indexing.

- Every code search checks for changed files first, so a branch switch, a pull
  or an edit you haven't committed shows up without running `anton repos sync`.

- Indexing is lighter on your machine: two workers, a 1.5 GiB soft memory
  limit, and low priority in the background. `code_graph.index_workers` and
  `code_graph.index_memory_limit_mb` change the limits.

- Anton now backs up its databases before upgrading them. When a new version
  first opens your data and has schema changes to apply, it copies each store
  into `data/snapshots/pre-migrate/` first. If an upgrade step fails partway,
  the store is put back as it was and the error is reported, so it is never
  left half-upgraded. The two most recent backups per store are kept. If the
  backup itself cannot be written, the upgrade still runs and
  `anton report health` warns that it ran without one.

- The daily maintenance pass now checks the full-text search index and
  rebuilds it only when it has drifted out of sync with your notes. Before,
  that repair ran only when a release was staged.

- `anton maintenance reset --target judged-unjudgeable` reopens note pairs
  that consolidation gave up on, so the next pass asks about them again.
  `anton report health` now shows how many pairs are waiting for a retry and
  how many were given up on.

### Changed

- Every skill now shows the exact response of each command it runs, checked
  against the CLI contract.

### Fixed

- Code search no longer guesses call links. When it cannot tell what type a
  method is called on, it leaves the call unresolved instead of linking it to
  whichever function of that name it happens to know. It works the type out
  from the file itself, one step through a called function's declared return
  type, and the class hierarchy. The resolved-call share in
  `anton report health` moves as a result: calls into standard libraries and
  other packages are counted as external, and links that were guesses are
  gone. Each code index rebuilds itself once, in the background, after the
  upgrade.

- A fresh code index and one kept up to date file by file now agree on every
  call link.

- C# methods are listed under their own names rather than their return type,
  and Rust functions with the same name in different modules or types are
  kept apart.

- C# type names are linked the way the C# compiler finds them — through the
  surrounding namespaces, the file's `using` lines and the project's
  `global using` lines — so a class's base types and the classes it creates
  are linked across files. When two places could supply the same name, the
  link is left out rather than guessed.

- Recursive Go functions no longer fill the events log with warnings.

- A file that crashes the code parser no longer stops the whole index. It is
  skipped until it changes, and `anton report health` lists it.

- Updating the index after an edit no longer loses the links from other files
  that call into the edited one.

- An index that was interrupted part-way is no longer reported as up to date.
  The next sync picks up where it stopped.

- Minified `*.min.js` / `*.min.css` files and `vendor/` folders are no longer
  indexed, and a repo that itself lives under a folder named `vendor`, `build`,
  `bin` or `dist` is no longer skipped entirely.

- Consolidation no longer silently drops a pair of notes when the model
  doesn't answer about it. A pair the model skipped, or whose question hit an
  error, used to be passed over for good. It is now retried first on the next
  pass, and it is given up on only after failing on its own three times
  (`link.judge_max_attempts` and `dream.judge_max_attempts` set the limit).
  If the `claude` command is missing, the pass stops without using up any
  retries. Pairs lost this way before this release can be found again by
  rewinding the link cursor:
  `anton maintenance reset --target link-cursor --to <date>`.

- Consolidation no longer skips an hour of work because a note it was judging
  happened to talk about rate limits. Only a real usage-limit message from
  Claude pauses it now.

- An older Anton session no longer writes into data a newer version has
  upgraded in a way it cannot safely handle. It opens that data read-only:
  searches and reads keep working, writes fail with a `schema_skew` error
  (exit code 3), and the session start briefing says so once. Restarting the
  session on the newer version clears it.

- An older session no longer deletes a code graph built by a newer version,
  which forced a full re-index every time the two alternated. It now opens the
  newer graph read-only and asks you to restart instead.

- Searching code or docs with `recall --code` or `--docs` no longer comes back
  silently empty when the repo hasn't been indexed yet, or its index is empty.
  You now get a warning that says so and names the fix: `anton repos sync`, or
  `anton repos add <path>` if the repo was never registered. A repo registered
  through a symlinked folder is recognised correctly.

- `recall --all` now marks memory results with how many links they have and,
  when one has been replaced by a newer note, which note replaced it. Only the
  plain `recall` did this before. When two notes replaced the same one at the
  same moment, the same one is now reported every time.

- Task nudges reach Claude again. Every half hour or so, when you have overdue
  or soon-due tasks, Anton is meant to slip a short `[Task nudge]` reminder into
  Claude's context so it can mention them in passing. The reminder was being
  built but never delivered, so Claude never saw it. It now arrives the same
  way the session-start briefing does.

- `anton hook validate` now checks all seven of the plugin's hooks. It checked
  only four, so a broken or missing tool-use hook passed validation.

- The `anton` shortcut that setup installs in `~/.local/bin` no longer breaks
  Anton inside Claude Code. It sat ahead of the plugin's own launcher, so
  commands such as `anton setup probe` failed with `plugin_data_unset`. Inside
  a session it now hands off to the plugin launcher. In a plain terminal,
  `setup probe`, `setup link-shell` and `setup uninstall` find your data folder
  from `~/.anton-core/config.json` instead of refusing to run.

## [2.9.0] - 2026-09-23

### Added

- `usage span` shows what a project has spent over any stretch of time, read
  straight from its Claude Code transcripts. The usage ledger is only written
  when a session ends, so until now there was no way to ask what the last hour
  of a session still running had cost. Give it a start time and the project's
  transcript folder; it reports input, output and cache tokens, split between
  the main session and its subagents.

- Sessions on Claude Opus 5 and Opus 5.5 are now priced. Opus 5 had no price
  on file, so its sessions showed token counts but no cost.

### Fixed

- Subagent output is no longer undercounted. Claude Code writes a streamed
  reply as several transcript lines, and a subagent's early lines carry only a
  partial output count; Anton was keeping the first line, so subagent output
  was reported at roughly a fifth of its real size. Each reply now counts at its
  final line. Main-session figures were already right and are unchanged.
  Sessions recorded before this release keep their old figures until
  re-extracted — `anton usage doctor --session-id <id> --repair` does one
  session.

- Notes containing a long unbroken string — a base64 image, a JWT, a run of
  concatenated hashes — were saved but could never be found by meaning. Anton
  measures how large a note is before deciding how to index it, and any stretch
  of more than a hundred letters or digits with no break was being measured as
  though it were a single short word. A 3,000-character blob looked smaller than
  a sentence, so nothing was split up, nothing was trimmed, and the part that
  does the indexing rejected it. The note stayed in your store and answered
  keyword searches, but searching by meaning would never return it. Such notes
  are now measured correctly and indexed in full.

- Saving or updating a note now tells you when it was stored without a
  searchable index. Before, the save reported plain success — the note was
  there, it just could not be found by meaning, and nothing said so. Both
  `item save` and `item update` now report it, and `report health` has a new
  check showing how much of your store is in that state and how to fix it.

- One unindexable note no longer stops the repair job. `maintenance reindex`
  used to abort the entire run the moment it hit a note it could not process,
  so every other note still waiting was left waiting — including the ones the
  run was started to fix. It now records that note and carries on, and says
  which ones it skipped and why.

- Saving a note with a large embedded blob is no longer slow. A 40KB attachment
  took around twelve seconds to index, and paid it again on every edit.


## [2.8.0] - 2026-09-22

### Fixed

- When Anton cannot open its store, it now tells you why. Every failure used to
  come back as "set CORE_DATA_DIR" — advice about a setting that was usually
  correct — whether the store was locked by another process, corrupt on disk, or
  sitting somewhere unreadable. Each of those now says so, and "set
  CORE_DATA_DIR" means only what it says: no data directory was found at all.

- A damaged store no longer breaks new sessions. Starting a session against a
  store Anton could not open ended in a crash report, and because the
  session-start hook is allowed to block, that crash blocked the session itself.
  The hooks now start quietly with safe defaults and let you get on with your
  work, which also leaves the store readable enough to diagnose.

- Several commands crashed instead of explaining themselves when no data
  directory was configured — `task`, `patterns` and `improvement` among them.
  They now return the same clear message the others always did.

- A busy store is reported as busy. A write that waited out the lock and gave up
  used to be reported as an internal error, sending you looking for a bug
  instead of for whatever else was writing at the time.

- Daily maintenance clears the cooldown files the error-recall reflex leaves
  behind. One was kept per session per distinct error and nothing ever removed
  them; a long-running store had accumulated over two thousand, the oldest three
  months old. Anything maintenance cannot read or delete is now counted and
  reported rather than passed over in silence.


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

[Unreleased]: https://github.com/to-infinity-labs/anton-core-plugin/compare/v3.0.0...HEAD
[3.0.0]: https://github.com/to-infinity-labs/anton-core-plugin/compare/v2.11.0...v3.0.0
[2.11.0]: https://github.com/to-infinity-labs/anton-core-plugin/compare/v2.10.0...v2.11.0
[2.10.0]: https://github.com/to-infinity-labs/anton-core-plugin/compare/v2.9.0...v2.10.0
[2.9.0]: https://github.com/to-infinity-labs/anton-core-plugin/compare/v2.8.0...v2.9.0
[2.8.0]: https://github.com/to-infinity-labs/anton-core-plugin/compare/v2.7.0...v2.8.0
[2.7.0]: https://github.com/to-infinity-labs/anton-core-plugin/compare/v2.6.0...v2.7.0
[2.6.0]: https://github.com/to-infinity-labs/anton-core-plugin/compare/v2.5.0...v2.6.0
[2.5.0]: https://github.com/to-infinity-labs/anton-core-plugin/compare/v2.4.0...v2.5.0
[2.4.0]: https://github.com/to-infinity-labs/anton-core-plugin/compare/v2.3.0...v2.4.0
