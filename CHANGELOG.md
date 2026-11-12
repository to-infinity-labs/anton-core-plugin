# Changelog

All notable user-facing changes to anton-core are documented here.
This file is the source of the notes published on each GitHub release.

## [Unreleased]

## [5.0.1] - 2026-11-12

5.0.1 upgrades from 4.0.0 or later only. A store from 3.x or earlier is
refused with `store_too_old` (exit 3) and left untouched; every hook still
exits 0, and the session-start briefing says what to do. From 3.x, upgrade in
two steps: run `anton bootstrap --version v4.1.2`, start one session so the
store migrates, then update to 5.0.1. An updater from 2.0.0 to 3.1.0 holds the
update and keeps its binary.

### Changed

- The dashboard carries the anton-core mark in its favicon and sidebar
  header, on a dark tile, and its accent, focus ring and chart colours are
  cyan.
- The Go module path is `github.com/to-infinity-labs/anton-core-go`.
- The routing fragment (2.0.0) is shorter, sends code questions straight to
  the graph skills, and adds the Claude-only path rule only to Claude Code's
  instructions file.
- Every skill's description and Output section was rewritten against the real
  CLI, and each skill tells the agent to run its command and answer from the
  output.
- Code-graph store advisories now tell the agent what to say to the operator.
- Error and help text names `anton`, not the retired `core`, and
  `report summary --date` help says it defaults to today in local time.
- `--json-schema` for `report health`, `report summary`, `maintenance run`,
  `maintenance consolidate`, `hook session-start` and `hook pre-compact` now
  declares every field those commands emit, and a health check object is
  closed (`additionalProperties: false`).
- Whether a file's parse stops no longer depends on how busy your machine
  is. Each parse is now limited by how much work it does
  (`code_graph.parse_work_per_byte`, default 30 per byte), not by a clock,
  so a large file that timed out under load now indexes. The limit matches
  the parser's own, so nothing that indexed before stops now.
- `code_graph.parse_timeout_ms` is now a safety net for all of one file's
  parsing together, default 120 seconds. An install still on the old
  10-second default moves to 120 seconds on upgrade; a value you set is
  kept.
- Every file that was quarantined or partly indexed is parsed once more on
  the next index after upgrading.
- `summarize.max_budget_usd` now defaults to $1.00, and it also sets how much
  of a session's transcript is sent. A long session is cut to fit the cap, and
  the summariser is told so.
- The raw output is saved to disk only when compression actually rewrites
  it, and the note under the compressed output gives that file's full path.
- The dashboard symbol page reads only the code-graph store that owns the
  symbol, so it opens faster.
- A full-pipeline save commits its extracted items in one transaction.
- `memory recall` answers questions: when no item holds every word, it
  retries on half of the question's content words.
- `memory recall` finds Chinese, Japanese and other unspaced text by word,
  through a new trigram index (migration 0045). Existing items are indexed
  on the first start after upgrading.
- `memory recall --docs`/`--all` snippets show the matching passage of a
  long document instead of its opening.
- An item saved with importance 0 ranks below others instead of being
  treated as importance 1.
- Co-access links built by `item get` are capped and fade over 30 days, so
  an often-fetched unrelated item no longer outranks an exact match.
- `memory recall` leaves out the `error` and `pattern` items recall-on-error
  mines, unless `--type`/`--include-types` names them; `--on-error` still
  uses them.
- recall-on-error searches only the first 4 KiB of a failed command's
  stderr.
- `recall-on-error doctor` reports a recall failure as an error rather than
  "no candidate", and decides exactly as the hook does.
- `memory recall` and `item get` still answer when their access bookkeeping
  cannot be written, with a `bookkeeping_failed` warning; `item get` then
  reports `co_access_pairs_added: 0`.
- `memory explore` returns at most 500 nodes and reports `truncated`.
  `seed_bumped` is false when the bump was skipped.
- `update apply-if-staged` refuses a staged version older than or equal to
  the installed one (`refused: not_newer`) unless `--force` is given or the
  version came from `anton bootstrap --version`.
- A version staged by bootstrap-fetch is signature-checked and rehearsed
  before it is applied, and `update status` reports it `staged_validated:
  false` until then.
- A release tag that is not semver stages nothing.
- `--wrapper-check` prints its envelope without jq.
- A job's Codex model and effort keys, and the efforts the effort key
  accepts, come from the harness table rather than a copy in config.
- The release pipeline runs as verify, build, sign, exec-matrix,
  harness-smoke and publish jobs, with a signed-tag guard, a per-target exec
  matrix (darwin/amd64 under Rosetta) and a pull-request rehearsal of verify
  and build.
- Claude Code's hooks pass `--harness claude`, which decides whose payload it
  is, so a Claude Code payload carrying a turn id is no longer read as
  Codex's. Codex's hooks are unchanged.
- `report health` reports each fact in one check: `graph_worktrees` is gone
  (`repos status` lists each repo's worktrees), `code_graph.query_stats`,
  `retrieval_intelligence` and `retrieval_fusion` run only under `--full`,
  and `harness_wiring` leaves native memory to the `native_memory` check.
- `report health --trend` compares this run with the 9 logged runs before
  it.
- `db check` also checks the memory invariants `report health` reads, and
  fails with `db_corrupt` naming each critical one that is violated.
- `improvement dismiss` keeps the suggestion, with state `dismissed`, so deep
  analysis never offers it again. `improvement list` rows carry `state`,
  newest first, with dismissed ones left out. Suggestions live in a table of
  their own rather than the item store (migration 0044).
- Deep analysis shows the model each flagged session's headline and facets
  and every suggestion already made, dismissed ones included. After a failed
  run it waits 1 hour, then 6, then 24 before trying again.
- `usage span` sorts commands into generic classes (`tests`, `build`, `git`,
  `search`, `agent`, `operator`, `other`); `gates` and `bb_wait` are gone,
  and `usage.span_sdlc_patterns` adds classes of your own.
- `usage stats` gives each harness's headroom its own age, so a fresh Claude
  Code reading no longer hides a stale Codex one.
- `repos remove --prune` changes nothing: the repo's store is removed either
  way, and `pruned` counts what that store held.
- `item get --include-relationships` reports each edge's `origin`
  (`judge:<pass>-<run>`, `explicit-ref`, `extracted` or `manual`); edges
  written before this release carry none.
- `repos add` records `SLUG_COLLISION` when it mints a suffixed slug.
  `BOOTSTRAP_TAKEOVER`, `BOOTSTRAP_PEER_DONE`, `MODULE_PATH_SWEEP_FAILED` and
  `CONFIGS_IMPORT_FAILED` leave the event vocabulary.

### Added

- An `update` skill corrects a saved memory in place.
- The dashboard's `/healthz` sends `X-Anton-Dashboard-Pid`, so the dashboard
  skill finds and stops its server with `curl` alone, without `lsof` or `ps`.
- Setup checks for macOS or glibc Linux plus `bash`, `git` and `curl` first,
  and names whatever is missing.
- The README lists what leaves your machine and how to turn each off, plus a
  Support section; `SECURITY.md` ships, pointing to GitHub private
  vulnerability reporting.
- `anton bootstrap --from <dir>` installs from release files you downloaded
  yourself, for a machine that cannot reach GitHub. It checks them exactly as
  a download is checked.
- A file that needs more parsing work than the limit allows is reported as
  class `work_limit`, a warning, with its fix in `anton report health`.
  Raise `code_graph.parse_work_per_byte` to index it.
- `anton graph parse-reduce --work-per-byte N` sets the limit for a
  reduction.
- `update rollback` refuses to cross a breaking migration (`schema_skew`);
  `--restore-snapshot` restores the pre-migrate snapshot (writes since it
  are lost) and lists it under `restored`.
- Releases ship a CycloneDX SBOM per binary, and the plugin tree ships
  `SBOM.cyclonedx.json`.
- The plugin tree ships `licenses/` with `THIRD_PARTY_LICENSES.md`, the
  licence and notice files of every Go module and vendored asset in the
  binary.
- `maintenance repair --target invariants` deletes tags and relationships
  naming a missing item and vectors nothing maps to an item. Migration 0049
  does the same once on upgrade, and an update's rehearsal repairs its
  sandbox before judging it, so a store holding them no longer stalls an
  update.
- `report health` checks `headless_model` (a job whose engine refused its
  model, with the `config set` that fixes it), `token_ledger_failures` (fixed
  by `anton usage doctor --all --repair`), `watch` (degraded once the inotify
  watch limit is reached) and `vector_identity` (a store whose vectors another
  embedder made). `data_root` warns when the data folder is on a network or
  FUSE filesystem.
- `watch status` reports `degraded`, with the reason.
- Config keys `vision.max_budget_usd` (default $0.25, the spend cap for one
  OCR call), `usage.span_sdlc_patterns` (default none) and
  `code_graph.worktree_store_cap` (default 20). `config list` files the
  `onboarding.{repos,knowledge,shell}.declined` keys under `onboarding`.
- `setup probe` reports provenance `uninstalled` for a store `setup
  uninstall` left behind.
- `setup probe` reports each harness's own version in `harnesses[].version`,
  read from its `--version`; it is null only when the harness's command is
  not on your PATH or prints no version.

### Removed

- These verbs now answer `unknown_command`: `graph retag`, `graph slug`,
  `item log-access`, `hook validate`, `memory eval`, `trace replay`,
  `usage profile`, `setup profiler-env`, `db stats`, `db schema` and
  `setup get-token`. Hook validation, the recall eval and trace replay are
  developer tools in the source tree (`go run ./cmd/hook-validate --harness
  claude|codex`, `./cmd/memory-eval`, `./cmd/trace-replay`). The updater
  reads the GitHub token itself (`ANTON_GITHUB_TOKEN`, then `gh auth token`),
  so it is never handed to the model.
- `graph query` templates `cte`, `subclasses-of` and `renders-tree`, and the
  `raw_cte_rejected` error kind. `transitive-walk --rel-types` walks the
  inheritance and render relations.
- `maintenance prune --target orphans` and `maintenance reindex --target
  code` are refused (`bad_input`); `graph index` reindexes a repo's code.
- `config set --if-equals`, and with it the `cas_mismatch` error kind; the
  `conformance_failed` and `eval_failed` kinds went with `hook validate` and
  `memory eval`.
- The `--format` flag of `session get|list|stats|mark-reflected` and
  `improvement list|approve|dismiss`, which every one of them ignored. Output
  is always JSON, whatever the global `--format` says.
- `graph query cycle-detect --max-seeds`: every strongly connected component
  is reported.
- Envelope fields nothing read: `fold_stray_types` and `repo_renamed_sweep` in
  `maintenance run|consolidate|status`, `docs_cleaned` in `repos sync`,
  `reflect_landed`, `pipeline_stages_skipped` and
  `deep_analysis_dispatch_recommended` in `hook session-start`, the
  `attribution` section of `usage stats`, `task_mult`/`tm=` in `memory recall
  --explain`, and `legacy_core`, `skipped:windows` and the
  `hook-bootstrapped` provenance, which no install could reach, in `setup
  probe`.
- Config keys nothing read: `maintenance.enabled`,
  `maintenance.last_weekly`, `retrieval.contextTokenBudget`,
  `session_intelligence.enabled`,
  `session_intelligence.extract_failure_threshold`,
  `task.priority_{high,medium,low}_mult`, `task.due_overdue_mult`,
  `task.due_soon_mult`, `task.hide_completed`,
  `freshness.{stable,moderate,volatile}_tier`, `co_accessed.expand_weight`,
  `tools.expand_batch_cap`, `code_graph.dbc_*`, `code_graph.cycles_max_seeds`,
  `ttl.step_log_days` and 35 unused `code_graph.*` keys. `config set` refuses
  them; a value already stored is ignored with one warning.
- The OTLP profiler and its settings.
- Windows builds. anton-core runs on macOS and glibc Linux.
- The `ANTON_UPDATE_API_BASE`, `ANTON_UPDATE_DOWNLOAD_BASE`,
  `ANTON_COSIGN_IDENTITY_REGEXP` and `ANTON_COSIGN_ISSUER` overrides in release
  binaries: an update always comes from GitHub and is verified against the
  release identity.
- Support for stores older than 4.0.0 (above), and the code that moved them
  forward. The schema migrations up to 4.0.0 are one baseline per store.
- The bulk-import checkpoint file. A re-run resumes through each file's
  `source_sha256:` tag.
- `compress exec` answers `unknown_command`, and Codex wrap mode is gone with
  it. On Codex 0.167 the PreToolUse rewrite either skipped Codex's approval
  prompt (beside `permissionDecision: allow`) or was ignored (without it), so
  Codex output is no longer compressed. `compress doctor` drops `match.mode`;
  `compress stats` still reports a stored `wrap` row as such. The smaller
  Codex hook set moves recall-on-error's trust key, so a Codex install's
  update to this release is held at rehearsal until `anton setup wire-harness
  --harness codex` re-trusts it and `anton update prefetch --force` retries.


### Fixed

- `anton fragment apply` and `fragment status` from a Codex shell find the
  installed plugin's fragment in Codex's plugin cache instead of failing with
  `io_error` (the setup skill's Step 4b failed for every Codex user). With no
  plugin root, as in a bare terminal, they and `system supply-chain` answer
  `precondition_missing` and never read a file from the working directory; an
  unreadable Codex `config.toml` is `io_error` naming it.
- `anton fragment apply` no longer downgrades the routing fragment: a plugin
  whose fragment is older than the pinned version, as one harness's stale
  cache, leaves every instructions file and the pin as they are.
- `repos remove` and `graph reset` count a store's code items: `code_items`
  was always 0.
- `graph query --repo`, `graph symbols --repo`, `watch`, `watch status` and
  `dashboard` report `store_too_old` (or whatever stopped the store opening)
  instead of asking for `CORE_DATA_DIR`. `graph query` and `graph symbols`
  run outside a git checkout fail `precondition_missing` (exit 3) and point to
  `--repo`, not `internal` (exit 5).
- Items saved before the trigram index existed are indexed even when the
  first upgrade's backfill failed or was interrupted: every later open retries
  it until it completes.
- `db check` and the health panel's `vec_orphan` count agree with
  `maintenance repair --target invariants`.
- When one item's chunk write fails during a save or bulk import, the other
  items, derived decisions and action items included, are still written,
  linked and embedded; the failure is reported and logged, and
  `maintenance reindex` fills in the missing vectors.
- `recall-on-error` reports a failed pattern read as a recall error, not "no
  pattern". `repos doctor` fails when it cannot read the slug registry or
  freshness rows, instead of reporting every repo inconsistent under `ok`.
- `update rollback --restore-snapshot` refuses with `concurrent_modification`
  (`quiesce_incomplete`) when it cannot read the run registry or a process
  outlives SIGKILL; an unreadable snapshot directory is `internal`, not "no
  snapshot".
- The link and dream passes stop on a failed config read; a failed read of
  `headless.enabled` no longer falls back to judging.
- Setup no longer takes over a bootstrap lock whose pid file is still empty,
  and bootstrap writes its pid atomically.
- A pin naming a missing binary slot names `anton bootstrap --version` only
  for a release this plugin pins a checksum for, and a bare `anton bootstrap`
  otherwise.
- A failed `session finalize` stage now keeps the session's marker for three
  attempts instead of clearing it, writes a `FINALIZE_STAGE_FAILED` event, and
  is listed by stage in the `finalize-backlog` health panel. A marker that
  cannot be read is set aside into `pending-finalize/bad/` rather than
  stopping the session-start sweep, and a marker's owner is checked by process
  start time as well as pid, so a reused pid no longer passes for it.
- A task due today no longer shows as overdue in the evening. `report summary`,
  `task due`, `task groups`, the dashboard's tasks page and the session-start
  briefing now read "today" from your local calendar, not UTC's, so west of
  UTC a task due today stays due today until your own midnight.
- `memory recall --limit` accepts 1 to 10000 on every route. A negative limit
  crashed and `0` returned nothing; both are now clear errors, including
  `--code --limit 0`, which used to return 20 results.
- Recall returns the same results in the same order for the same inputs, a
  repeated or padded `--tag` works, and a very large result pool no longer fails.
- `update rollback` sticks: the version you left stays held until a newer
  release ships or you run `update prefetch --force`.
- A failed `item save`, `item import-native` or `item extract --backfill` names
  the items it had already saved, in `error.written`. `item bulk-import` does the
  same in each file's error.
- A file that fails to index is retried on the next sync instead of being lost,
  and a moved directory's files leave the index.
- Indexing a large repository no longer blocks other writers for the whole
  resolve. A run that follows a file edit on a repository with derived edges
  still does, so that readers never see those edges missing.
- A slow embedder download no longer stalls embedding.
- `anton report health` no longer says a partly indexed file stays out of
  the graph. The fix now says only the lines it left out stay out, or, when
  nothing was left out, that the file stays indexed in segments.
- A partly indexed file's fix in `anton report health` now reads "line 7",
  not "lines 7", when a single line was left out.
- The session summariser no longer pays again for a session it cannot
  summarise. A call that trips the budget, or answers with no summary, is
  recorded and never retried; a timeout or other passing failure still is.
  `anton session summarize --force` tries again, and a failed attempt keeps any
  summary you already have. Sessions that tripped before this change get one
  more try, with the fitted transcript, the next time they finalize.
- `anton session summarize` reports a failed call as an error (for example
  `error:timeout`) rather than `skipped:not-wired`, which now means the engine
  is absent.
- Two simultaneous writes to the same file in one anton-core process no longer
  fail with `file exists`.
- A malformed compressed Codex session file can no longer crash anton-core
  while it is read (GO-2026-6865, `klauspost/compress` v1.20.2).
- Output compression leaves piped, chained, redirected and substituted
  commands untouched, instead of compressing them as their first command.
- A `go test` run with any `FAIL` line reaches the model in full.
- `git log -p`, `--stat` and other flags outside the supported set pass
  through instead of losing their patches and stats.
- `git diff` summaries handle quoted non-ASCII paths, count content lines
  starting with `---`/`+++`, and pass through on a header they cannot read,
  such as `diff --cc`.
- A line over 1 MiB makes compression pass the output through instead of
  silently cutting it short.
- `rg` searching a single path passes through, so no match is dropped.
- A foreground dashboard exits when its launching session dies under a
  subreaper, not only when it is handed to init.
- Stopping the dashboard while a browser holds a preconnected socket exits
  cleanly instead of failing with `context deadline exceeded`.
- The task, session, improvement, memory-search and symbol-search lists say
  "N of M" when there are more rows than shown, instead of presenting the
  cap as the total.
- A saved task shows in `task list` immediately.
- Identical items in one extraction are written once.
- A PDF import has a 60 s deadline and a 2,000-page cap, and refuses
  page-tree cycles.
- An Office import caps inflated bytes at 32 MiB per part and 64 MiB in
  total.
- One file's OCR failure no longer halts `item bulk-import`.
- `item extract --backfill` refuses content-mode flags and reports failed
  sessions (`sessions_failed`, `failures`).
- Inline-extract failures and rejections become save warnings.
- A cancelled `item bulk-import` in json or summary format emits its summary
  with `interrupted` and `remaining`.
- Import truncation is reported (`truncated`, `original_bytes`) and never
  splits a character.
- Two concurrent saves of one body write one item, and re-saving a known
  body keeps the new title and tags.
- `config set retrieval.freshnessExponent` refuses NaN, infinite and
  negative values. A bad stored freshness, hop-decay or resolve-bonus value
  falls back to its default with a warning instead of breaking recall.
- `item list --limit` accepts 1 to 10000 and refuses anything else.
- Code recall's search arms are bounded, so a common word no longer scans
  the whole symbol table.
- `cycles` all-mode finds every cycle, with no seed cap; `--max-seeds` and
  `code_graph.cycles_max_seeds` are removed.
- `graph query`: an unknown seed id is `entity_not_found`, an unknown rel
  type is `invalid_argument`, and a JSON-array `--rel-types` is accepted.
- `graph index` reports `attached` when another run held the lease, and
  lists the files it newly quarantined.
- Code-graph extraction honours the file's parse deadline and stops on
  SIGINT or SIGTERM.
- The stamped catch-up baseline is the HEAD read before listing files, so a
  commit landing mid-run is not lost.
- The index lease is refreshed on a timer, the closing stamp is fenced on
  the lease, and a live run's in-flight markers are never consumed by
  another run.
- Crash quarantine backs off: a retry after 1 h, then after 1 d, and
  permanent after the third consecutive death. The graph store schema moves
  to v15, a rebuild from source.
- Parses are admitted against a `code_graph.index_memory_limit_mb` memory
  budget.
- With `git` missing, a checkout is refused with `precondition_missing`; a
  plain directory is indexed with a `not_a_git_repo` warning.
- A worktree seed keeps the parent's dirty set, leaked `.seed.<pid>` temps
  are reaped, and a seeder never replaces a store under a fresh lease.
- An update or rollback killed partway resumes on the next update command,
  keeping `previous` as the rollback target.
- Leftover rehearsal temp directories are cleaned up at the start of every
  update command.
- When the GitHub API returns 403 or 429, the updater finds the latest
  release through the web redirect. The token is read from
  `ANTON_GITHUB_TOKEN`, then `GITHUB_TOKEN`, then `gh auth token`.
- `apply-if-staged --budget` limits the whole call, including waiting for
  the update lock.
- The rehearsal health check no longer passes `--json`.
- The Codex stray-group cleanup no longer removes a user's own `hooks.json`
  group; it matches only anton's wrapper-script commands.
- The hook wrapper reads the pinned version under POSIX `sh` (Alpine's
  busybox ash).
- The public-surface check refuses a shipped reference that climbs out of
  the plugin tree.
- A development build can no longer leave the release you have installed
  locked out of your store. When it would raise the store's writer stamp, it
  refuses to open the store with `schema_skew` and names
  `ANTON_ALLOW_DEV_MIGRATE=1`, which lets it migrate anyway. A brand-new store
  and release builds are unaffected.
- `setup uninstall` removes everything setup wrote: the watch daemon's
  supervisor unit (`daemon`, with the command that unloads one still
  running), anton's region of Claude Code's instructions file
  (`claude_settings.fragment`), the status-line wrapper, including one a
  data-root move left under the old root, and the settings an earlier `setup
  profiler-env` wrote. `--dry-run` lists exactly what a real run removes.
- A Claude Code hook whose pinned binary is missing exits 0 with a warning on
  stderr, instead of exit 2, which Claude Code reads as a block.
- With `~/.codex` present but no anton-core plugin in Codex, setup leaves
  Codex's instructions file and memory settings alone, and health reports the
  plugin not installed. Naming it with `--harness` is `precondition_missing`.
- The bootstrap lock is created with its pid already inside, and one left
  with no pid for over 60 s is taken as stale.
- A data-root move killed partway resumes at the next session start, and
  resuming into a non-empty target merges with the move's conflict check.
- A wait for another process's store initialisation gives up with
  `db_locked` after 30 s, and stops on SIGINT or SIGTERM.
- Past the kernel's inotify watch limit the watch daemon logs one message
  naming `fs.inotify.max_user_watches`, and `watch status` and health report
  it degraded; the catch-up sync still indexes the unwatched directories.
- `watch install-daemon` on Linux without systemd refuses with
  `precondition_missing` and names the route to take instead, rather than
  writing a unit nothing loads.
- On musl Linux the embedder downloads nothing and health reports the vector
  arm unavailable; recall runs on full-text and graph.
- `setup wire-harness` records the values it replaces before it commits, so
  a crash between the two no longer leaves a re-run treating anton's values
  as yours, and setup verbs no longer drop each other's keys in
  `config.json` when they write at once.
- `config set` refuses a key it does not know, and any value that is not
  finite, is out of the key's range or enumeration, or is malformed JSON for
  a JSON key (`invalid_argument`, nothing written).
- `improvement list --since` accepts an ISO 8601 instant as well as epoch
  milliseconds; an ISO value used to return nothing.
- Dismissing an improvement no longer leaves an orphaned item behind.
- The dream pass spends one `dream.max_budget_usd` across its judging and
  theme synthesis, not one each. Link and dream skip their neighbour search
  when no engine is bound.
- Theme synthesis sends at most 40 members and 32 KiB per cluster, skips a
  cluster an existing theme already covers, and replaces a superseded theme
  in the same transaction that mints its successor.
- A judged `supersedes` edge points the way the judge said, an edit to
  either item reopens a pair judged unrelated (migration 0047), and the pair
  bodies are fenced so their text cannot pass as instructions.
- A relationship naming a title two items share binds to neither and waits
  as a pending edge until the title is unambiguous.
- A Codex headless run stops at its dollar cap, metered from the usage Codex
  reports, and a spend cap of 0 or below is refused rather than read as no
  cap.
- `maintenance decay` honours `maintenance.stale_days`,
  `maintenance.decay_factor` and `maintenance.edge_decay_factor` set with
  `config set`.
- The consolidation-stall health check reads each pass's full figures from
  a table of their own (migration 0048), so seven-digit counters no longer
  hide a stall.
- `maintenance reindex` re-embeds the documents in every repo's store after
  an embedder change, and resumes an interrupted re-embed where it stopped.
- A model id the price table does not list, a new point release included,
  is reported under `unpriced_models` instead of priced as its family.
- A session that runs past midnight books each day's tokens on that day.
- `report summary`'s `search_misses` counts only recalls that found nothing.
- A code-graph store removal killed partway is finished by the next one, and
  a scratch file a killed `db migrate` probe leaves is not counted as a
  store.
- A repo moved or deleted from a directory still on disk is counted by the
  `graph_stores` health check and its store reaped by the daily prune, and
  worktree stores past `code_graph.worktree_store_cap` are reaped least
  recently used first.
- A large TypeScript, Go or Python file indexes in time that grows with its
  length, not its cube: a 4,000-statement file takes seconds.
- Python method lookup follows the C3 resolution order, so a diamond
  resolves to the class Python calls.
- A call bound on its name alone is recorded `HEURISTIC`, not `EXTRACTED`.
- PHP `foreach`, `catch` and destructuring and Ruby `attr_writer` and
  subclass receivers are typed correctly, and C# `base.M()` binds to the base
  class, never an interface.

### Security

- Built with Go 1.27.4 and current `golang.org/x/net`, `grpc` and
  `sigstore-go`, which also drops the unmaintained `openpgp` package
  (GO-2026-6859, -6617, -6612, -6611, -6603, -6348 and -5932).
- `graph parse-reduce` no longer leaks your source text into the fragment
  it writes. Interpolation holes in C#, JS/TS, Python and Ruby strings are
  scrubbed like code, Go raw strings, regexes, Ruby word arrays, heredocs and
  markdown fences are scrubbed whole, and digits on preprocessor lines are
  replaced. A fragment that only stops the parser with some of your text put
  back is refused with `leak_risk` (exit 1); `--accept-restored` writes it
  anyway.
- Your data folder and its databases are readable by you alone. A fresh
  install creates them that way, and an install an older release left
  readable by other users is tightened the next time anton opens it.
- The command lines kept in the compression and error-recall logs have
  passwords, tokens and keys masked, and are cut without splitting a
  character.
- The dashboard refuses requests addressed to a host name other than
  localhost, so a web page using DNS rebinding can no longer read it. It
  also refuses cross-site writes.
- A PDF page whose content stream inflates past 64 MiB is refused before it
  is decompressed into memory, and a timed-out PDF parse blocks further PDF
  imports until it ends instead of piling up.
- A symlink resolving outside the repo is never indexed, and a macOS repo
  root resolves to its on-disk case, so one repo is one store.
- Update signatures are verified inside the binary against Sigstore's public
  trust root (release identity, issuer, push trigger, transparency log,
  SCT). No `cosign` binary is needed, and an asset without a verifying
  bundle is never staged.
- The update endpoint and signing-identity environment overrides exist only
  in test builds; release binaries ignore them.
- Bootstrap verifies each download against the plugin's
  `release-checksums.txt`, and refuses a download with no signature bundle
  when cosign is installed.
- A gitleaks pre-commit hook, pinned by SHA, refuses a staged secret.

## [4.1.2] - 2026-10-31

### Fixed

- anton-core's hooks run again under Codex 0.166 and later. Codex 0.166
  changed how it records a trusted plugin hook, and setup's trust entries no
  longer matched, so Codex skipped every anton-core hook. Run
  `anton setup wire-harness --harness codex` once after upgrading; `anton
  report health` says so when Codex's trust and anton-core's disagree.
  After any plugin update, Codex 0.166 and later asks you to review
  anton-core's hooks at startup: choose "Trust all", or run `anton setup
  wire-harness --harness codex`. If you only run headless `codex exec`, run
  wire-harness after updating.
- Updating anton-core no longer stalls for Codex users. Every plugin
  update changes what Codex fingerprints, and an install from 4.1.0 has no
  fingerprint at all, so `anton report health` marked the hooks critical and
  the update held itself back. That case now warns and names the fix, `anton
  setup wire-harness --harness codex`; anton-core still never re-trusts its
  hooks on its own.
- A markdown file the parser stops on is now indexed `partial` instead of
  quarantined whole: a bad inline span costs only its lines and a bad block
  only that block. Files without a final newline index cleanly, and
  `anton graph parse-reduce` shrinks markdown stops too.

## [4.1.0] - 2026-10-22

### Added

- The dashboard's graph page opens on your memory and explores one repo at
  a time: click a node to open the level below it, with breadcrumbs back
  up. No level draws more than 300 nodes, so large folders are grouped into
  buckets instead of being cut off. Search finds a memory or a code symbol
  by title or exact id and opens every level down to it, and the legend
  hides or shows a type.
- `anton graph views` lists one graph per repo, and `anton graph level`
  reads one level of a repo's graph, or of memory, from the command line.
- `anton report health` checks that every repo's graph view adds up to its
  real counts.
- `code_graph.max_file_bytes` (default 1 MiB, `0` for no cap) keeps the code
  graph away from very large files: one over the cap is skipped without being
  read, and `anton graph index --explain` says why.
- `anton graph parse-reduce <file>` shrinks a file the parser stops on to a
  small anonymized fragment that still stops it, so a parser bug can be
  reported without sharing the source.

### Fixed

- A quarantined file you delete, ignore in `repos.json` or unregister leaves
  the code graph and `anton report health` with it, instead of lingering as
  a warning.
- A parser defect in C#, Java, TypeScript/JavaScript, PHP, Go or Rust now
  costs only the lines it stops on: the rest of the file is indexed and
  marked `partial`. Health reports such a file as healthy, with a detail.
- A crash is blamed only on a file that crashes again when parsed alone, so
  a run killed from outside no longer quarantines whatever it was parsing.
- Each quarantined file in `anton report health` names its class and the fix
  that actually clears it, in place of "edit or remove the file".

### Changed

- The graph page draws every node of a level instead of cutting the graph
  off at a node limit, so the truncation banner is gone. Each code graph
  rebuilds from source once after updating.

## [4.0.0] - 2026-10-11

### Breaking

- Your data lives in one place, `~/.anton-core`, whichever harness runs
  anton-core. An existing Claude Code store is found and moved there
  automatically, with no setup needed, and your memory stays reachable
  throughout. A store kept elsewhere moves in once with `anton setup
  relocate-data-root` (`--dry-run` shows the move first), which leaves a
  symlink behind; `anton setup persist-data-dir` is gone.
- `anton setup uninstall` keeps your data. It removes anton-core's settings
  from each installed harness and the shell links; add `--purge-data` to
  delete the data as well.

### Added

- anton-core runs in the OpenAI Codex CLI as well as Claude Code. Install it
  with `codex plugin marketplace add to-infinity-labs/anton-core-plugin` then
  `codex plugin add anton-core@anton-core`, and run `anton setup wire-harness
  --harness codex` to trust its hooks and let them write to your data. Every
  skill runs as `$anton-core:<skill>`, memory, recall, session capture and
  usage work the same in both, and the two share one store.
- `headless.runner` picks what runs background extraction and consolidation:
  `auto` (Claude Code, else Codex), `claude` or `codex`.
- Usage covers Codex models and plan headroom, and `anton usage` takes
  `--harness`. The dashboard shows a headroom card per harness, a By harness
  table, and a Harness column on Sessions when you use both.
- `anton report health` checks each installed harness's wiring and names the
  fix for anything missing, and `anton setup probe` lists the harnesses it
  finds.
- `anton dashboard --background` keeps the dashboard running until the
  session that started it ends.

### Fixed

- Sessions record their real project, so the Sessions page and `anton session
  list` match `anton usage --project` instead of reading `core` for every row.

## [3.1.0] - 2026-10-08

### Changed

- Ending a Claude Code session stops the dashboards that session started, on
  whatever port, and any dashboard whose Claude Code session has gone. A
  dashboard you started outside Claude Code, or another live session's, is
  left running. `anton update` also stops dashboards left by an older version.
- Saving a batch of notes is all or nothing: if one note cannot be written,
  none are. Each note needs a `type`, `title` and `content`, a misspelt field
  is refused with the note it came from, and the same note twice in one batch
  is saved once.
- `anton graph coverage` counts symbols without modules, and adds module and
  doc counts. The dashboard's `/repos` and `/graph` pages show the same
  Symbols, Modules, Docs and Edges for each repo.
- The code-graph health check no longer warns about calls it could never
  resolve. It counts only real misses in your registered repos; calls into
  libraries and language builtins are counted as external instead, and
  `anton graph coverage`, `/graph` and `/health` show the same counts.
- Indexing skips vendored, minified and `repos.json` `ignore`d files, and flags
  generated ones. A file the parser cannot finish within
  `code_graph.parse_timeout_ms` (10 s) is quarantined and listed with its
  reason rather than indexed half-read.
- Call resolution is more accurate in C#, Java, JavaScript/TypeScript, PHP,
  Python, Ruby and Rust; Python and Rust class members are methods. Each code
  graph rebuilds from source once after updating.

### Added

- A batch save can link its notes: give a note a `key`, and `relations`
  pointing at another note in the batch (`@<key>`) or an existing one by id.
- `anton repos status` adds module and edge counts.

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

[Unreleased]: https://github.com/to-infinity-labs/anton-core-plugin/compare/v5.0.1...HEAD
[5.0.1]: https://github.com/to-infinity-labs/anton-core-plugin/compare/v4.1.2...v5.0.1
[4.1.2]: https://github.com/to-infinity-labs/anton-core-plugin/compare/v4.1.0...v4.1.2
[4.1.0]: https://github.com/to-infinity-labs/anton-core-plugin/compare/v4.0.0...v4.1.0
[4.0.0]: https://github.com/to-infinity-labs/anton-core-plugin/compare/v3.1.0...v4.0.0
[3.1.0]: https://github.com/to-infinity-labs/anton-core-plugin/compare/v3.0.0...v3.1.0
[3.0.0]: https://github.com/to-infinity-labs/anton-core-plugin/compare/v2.11.0...v3.0.0
[2.11.0]: https://github.com/to-infinity-labs/anton-core-plugin/compare/v2.10.0...v2.11.0
[2.10.0]: https://github.com/to-infinity-labs/anton-core-plugin/compare/v2.9.0...v2.10.0
[2.9.0]: https://github.com/to-infinity-labs/anton-core-plugin/compare/v2.8.0...v2.9.0
[2.8.0]: https://github.com/to-infinity-labs/anton-core-plugin/compare/v2.7.0...v2.8.0
[2.7.0]: https://github.com/to-infinity-labs/anton-core-plugin/compare/v2.6.0...v2.7.0
[2.6.0]: https://github.com/to-infinity-labs/anton-core-plugin/compare/v2.5.0...v2.6.0
[2.5.0]: https://github.com/to-infinity-labs/anton-core-plugin/compare/v2.4.0...v2.5.0
[2.4.0]: https://github.com/to-infinity-labs/anton-core-plugin/compare/v2.3.0...v2.4.0
