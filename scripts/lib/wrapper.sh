#!/usr/bin/env bash
# Shared header for plugin hook wrappers. Sourced, never executed directly.
# Inside this file `$0` is the *caller's* path (the wrapper that sourced us),
# so `dirname $0` resolves to scripts/ and `..` to repo root.
set -euo pipefail

# Capture whether CLAUDE_PLUGIN_DATA was authoritatively provided by Claude
# Code (hooks/skills) vs. about-to-be-defaulted to CLAUDE_PLUGIN_ROOT below.
# Only an authoritative value drives CORE_DATA_DIR (the data root). Use an
# explicit yes/no sentinel + a presence test (${VAR+x}), NOT := — the colon
# form re-fires on a set-but-EMPTY value, so an exported empty from scripts/core
# would get re-defaulted to "yes" here (CLAUDE_PLUGIN_DATA is set by now),
# re-pinning the cache. scripts/core writes a non-empty "no" for operator-shell;
# the presence test below leaves any already-set value (incl. "no") untouched.
if [ -z "${ANTON_DATA_DIR_AUTHORITATIVE+x}" ]; then
    if [ -n "${CLAUDE_PLUGIN_DATA+x}" ]; then
        ANTON_DATA_DIR_AUTHORITATIVE=yes
    else
        ANTON_DATA_DIR_AUTHORITATIVE=no
    fi
fi
export ANTON_DATA_DIR_AUTHORITATIVE

# CLAUDE_PLUGIN_ROOT is set by Claude Code at hook fire time; fall back to the
# caller wrapper's parent-of-parent so the same script runs under
# `bash scripts/x.sh` during local testing.
: "${CLAUDE_PLUGIN_ROOT:=$(cd "$(dirname "$0")/.." && pwd)}"
export CLAUDE_PLUGIN_ROOT

# CLAUDE_PLUGIN_DATA is the persistent state root per
# docs/plugin-spec/00-overview.md:56 (the three-location split). The binary
# cache lives here so it survives plugin updates that wipe CLAUDE_PLUGIN_ROOT.
# For repo-local dev runs without DATA set, fall back to PLUGIN_ROOT so the
# Makefile's `make build` output at bin/ remains the source of truth.
: "${CLAUDE_PLUGIN_DATA:=$CLAUDE_PLUGIN_ROOT}"
export CLAUDE_PLUGIN_DATA

# Translate to the $CORE_DATA_DIR the Go resolver (internal/db.ResolveRoot,
# docs/plugin-spec/04-paths-and-config.md §path-resolution) reads — but ONLY
# when CLAUDE_PLUGIN_DATA is authoritative. In operator-shell mode it was just
# defaulted to the cache above; pinning CORE_DATA_DIR there is exactly the bug
# that stranded data in the rotating cache. Leaving it unset lets the resolver
# reach the ~/.anton-core/config.json step. := respects a pre-set override.
if [[ "${ANTON_DATA_DIR_AUTHORITATIVE:-}" == "yes" ]]; then
    : "${CORE_DATA_DIR:=$CLAUDE_PLUGIN_DATA}"
    export CORE_DATA_DIR
fi

# Resolve the expected binary version from the plugin manifest. jq is
# preferred; grep is a defensive fallback so the wrapper still functions
# on a host that hasn't installed jq yet (the bootstrap path then has a
# chance to surface the missing-jq case as a structured error).
_read_expected_version() {
    local manifest="${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json"
    if [[ ! -f "$manifest" ]]; then
        echo ""
        return 0
    fi
    if command -v jq >/dev/null 2>&1; then
        jq -r '.version // empty' "$manifest" 2>/dev/null || true
    else
        # Match the first `"version": "X.Y.Z…"` pair; tolerant of whitespace.
        grep -E '"version"[[:space:]]*:[[:space:]]*"[^"]+"' "$manifest" \
            | head -1 \
            | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' \
            || true
    fi
}

# Read .requires-binary-version (e.g. ">=1.0.2") from the manifest.
# Returns empty if absent. Same jq-then-grep fallback as the version reader so
# the wrapper remains usable on a host without jq.
_read_requires_binary_version() {
    local manifest="${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json"
    if [[ ! -f "$manifest" ]]; then
        echo ""
        return 0
    fi
    if command -v jq >/dev/null 2>&1; then
        jq -r '.["requires-binary-version"] // empty' "$manifest" 2>/dev/null || true
    else
        grep -E '"requires-binary-version"[[:space:]]*:[[:space:]]*"[^"]+"' "$manifest" \
            | head -1 \
            | sed -E 's/.*"requires-binary-version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' \
            || true
    fi
}

# Check whether $installed satisfies $constraint. We only honor the `>=X.Y.Z`
# form because that is the only shape anton-core's manifest documents (per
# the update-ergonomics spec). Any other constraint form prints a stderr
# warning and returns 0 — degrade open: refusing to start because we can't
# parse a constraint we never advertised is worse than honoring the pin and
# logging the surprise.
_semver_satisfies() {
    local installed="$1" constraint="$2"
    if [[ "$constraint" =~ ^\>=([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        local req_major="${BASH_REMATCH[1]}" req_minor="${BASH_REMATCH[2]}" req_patch="${BASH_REMATCH[3]}"
        if [[ "$installed" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
            local inst_major="${BASH_REMATCH[1]}" inst_minor="${BASH_REMATCH[2]}" inst_patch="${BASH_REMATCH[3]}"
            if (( inst_major > req_major )); then return 0; fi
            if (( inst_major < req_major )); then return 1; fi
            if (( inst_minor > req_minor )); then return 0; fi
            if (( inst_minor < req_minor )); then return 1; fi
            (( inst_patch >= req_patch ))
            return $?
        fi
        printf '⚠ installed version %q not parseable; bypassing requires-binary-version gate\n' "$installed" >&2
        return 0
    fi
    printf '⚠ requires-binary-version constraint %q not understood; bypassing gate\n' "$constraint" >&2
    return 0
}

# Binary path resolution — pin-file first, manifest fallback.
#
# Source of truth is ${CLAUDE_PLUGIN_DATA}/data/state/installed-version (single
# line `vX.Y.Z\n` written by `core update apply-if-staged` after the health
# gate passes). The pin decouples the running binary from Claude Code's
# /plugin update cadence: a `git pull` that bumps plugin.json never changes
# which binary the wrapper exec's. Per docs/superpowers/specs/2026-05-28-
# update-ergonomics-design.md § "wrapper.sh change".
#
# Fallback to .claude-plugin/plugin.json .version applies only when the pin
# is absent — i.e. first-install before any successful apply, which routes
# through the existing _bootstrap_binary path further down. The legacy
# data/bin/anton-core-v${version} layout is preserved for that path; the
# new data/versions/v${version}/anton-core layout is exclusive to pin-driven
# resolution (set up by the update orchestrator).
PIN_FILE="${CLAUDE_PLUGIN_DATA}/data/state/installed-version"
ANTON_BIN_DIR="${CLAUDE_PLUGIN_DATA}/data/bin"
INSTALLED_VERSION=""

if [[ -f "$PIN_FILE" ]]; then
    INSTALLED_VERSION="$(<"$PIN_FILE")"
    INSTALLED_VERSION="${INSTALLED_VERSION#v}"
    INSTALLED_VERSION="${INSTALLED_VERSION//$'\n'/}"
    ANTON_BIN="${CLAUDE_PLUGIN_DATA}/data/versions/v${INSTALLED_VERSION}/anton-core"
    if [[ ! -x "$ANTON_BIN" ]]; then
        # Pin names a slot that doesn't exist. Refuse to start: bootstrap
        # would silently re-fetch the manifest version and disagree with the
        # pin, which is the exact decoupling problem the pin is supposed to
        # prevent. Operator must run `core update rollback` or repair the
        # versions/ directory.
        printf '⚠ pin names a missing binary slot v%s; operator action required\n' "$INSTALLED_VERSION" >&2
        printf '{"status":"error","error":{"kind":"internal","reason":"pin_drift_fatal","pinned_version":"v%s"}}\n' "$INSTALLED_VERSION" >&2
        exit 2
    fi
else
    EXPECTED_VERSION="$(_read_expected_version)"
    ANTON_BIN="${ANTON_BIN_DIR}/anton-core-v${EXPECTED_VERSION}"
fi
export ANTON_BIN_DIR ANTON_BIN

# Repo-local dev convenience: when running from a working tree that has a
# freshly-built bin/anton-core (e.g. after `make build`), prefer that over
# the cached versioned binary. Lets contributors test wrapper changes
# without re-running the bootstrap fetch.
if [[ -x "${CLAUDE_PLUGIN_ROOT}/bin/anton-core" ]] && [[ ! -x "$ANTON_BIN" ]]; then
    ANTON_BIN="${CLAUDE_PLUGIN_ROOT}/bin/anton-core"
    export ANTON_BIN
fi

# requires-binary-version gate. Only triggers when both the manifest
# constraint and a pin are present — first-install has no pin yet, and a
# manifest without the field opts out entirely. On mismatch, force a
# synchronous inline `core update apply-if-staged --include-not-yet-staged
# --budget 30s`. This is the one path where SessionStart cannot stay quick:
# /plugin update has bumped the manifest past what the pinned binary
# supports, so booting the old binary would surface as a version-skew
# failure downstream. Better to pay the full latency once.
REQUIRED_VERSION="$(_read_requires_binary_version 2>/dev/null || true)"
if [[ -n "$REQUIRED_VERSION" && -n "$INSTALLED_VERSION" ]]; then
    if ! _semver_satisfies "$INSTALLED_VERSION" "$REQUIRED_VERSION"; then
        # `|| true` so a non-zero apply exit (e.g. nothing staged, network
        # down) doesn't abort the wrapper; the subsequent exec will surface
        # the version-skew failure if the apply couldn't fix it.
        "$ANTON_BIN" update apply-if-staged --include-not-yet-staged --budget 30s >&2 || true
        # Re-resolve pin after the inline apply may have rewritten it.
        if [[ -f "$PIN_FILE" ]]; then
            INSTALLED_VERSION="$(<"$PIN_FILE")"
            INSTALLED_VERSION="${INSTALLED_VERSION#v}"
            INSTALLED_VERSION="${INSTALLED_VERSION//$'\n'/}"
            ANTON_BIN="${CLAUDE_PLUGIN_DATA}/data/versions/v${INSTALLED_VERSION}/anton-core"
            export ANTON_BIN
            # Re-check exec: the apply may have rewritten the pin without
            # populating the slot (orchestrator bug, disk full mid-write).
            # Without this re-check we fall through to `exec "$ANTON_BIN"`
            # and surface `not found` instead of the structured pin_drift
            # envelope. Same exit shape as the initial pin block.
            if [[ ! -x "$ANTON_BIN" ]]; then
                printf '⚠ pin names a missing binary slot v%s; operator action required\n' "$INSTALLED_VERSION" >&2
                printf '{"status":"error","error":{"kind":"internal","reason":"pin_drift_fatal","pinned_version":"v%s"}}\n' "$INSTALLED_VERSION" >&2
                exit 2
            fi
        fi
    fi
fi

# _bootstrap_binary — fetch the matching per-platform binary from the
# GitHub release named by EXPECTED_VERSION, verify it (transport-integrity
# checksum always; supply-chain cosign opportunistically), install it at
# ANTON_BIN, and emit a telemetry event. Returns 0 on success, 1 on any
# failure (caller emits the precondition envelope and exits 0 to keep the
# hook non-blocking).
#
# On any failure, sets BOOTSTRAP_FAIL_REASON to a machine-parseable
# discriminator (e.g. `unsupported_arch:riscv64`, `checksum_mismatch`,
# `cosign_verify_failed`, `exec_probe_failed`) so the precondition
# envelope at the bottom of this file can include it as a routing hint.
# Each failure also prints a stderr line so a contributor watching the
# wrapper output can see the specific cause without parsing JSON.
#
# Honors:
#   ANTON_SKIP_BOOTSTRAP — non-empty disables the fetch path entirely
#                          (used by make verify / make ci to keep tests hermetic).
#
# Fetch transport is unauthenticated HTTPS (`curl -fsSL`) against the PUBLIC
# release repo (ADR-0037 public-distribution); no token / auth / URL-base /
# API-base env vars are consulted. Assets are fetched by their stable
# releases/download/v<ver>/<asset> URLs.

BOOTSTRAP_FAIL_REASON=""
__bootstrap_tmpdir=""
__bootstrap_lock_dir=""

# Cleanup helper — removes the staging tmpdir and releases the bootstrap
# lock. Called at every return site (success and failure) instead of an
# EXIT trap, because `exec` later replaces this process without firing
# EXIT, which would leak the tmpdir on every successful first-install.
_bootstrap_cleanup() {
    if [[ -n "$__bootstrap_tmpdir" ]]; then
        rm -rf "$__bootstrap_tmpdir" 2>/dev/null || true
        __bootstrap_tmpdir=""
    fi
    if [[ -n "$__bootstrap_lock_dir" ]]; then
        rmdir "$__bootstrap_lock_dir" 2>/dev/null || rm -rf "$__bootstrap_lock_dir" 2>/dev/null || true
        __bootstrap_lock_dir=""
    fi
}

# Failure helper — sets the discriminator, optionally prints a stderr
# message, releases lock + tmpdir. Caller follows with `return 1`.
_bootstrap_fail() {
    BOOTSTRAP_FAIL_REASON="$1"
    if [[ -n "${2:-}" ]]; then
        printf '⚠ bootstrap: %s\n' "$2" >&2
    fi
    _bootstrap_cleanup
}

_bootstrap_binary() {
    BOOTSTRAP_FAIL_REASON=""

    # Skip-bootstrap escape hatch. Silent on purpose — `make verify` and
    # `make ci` set this and rely on the precondition envelope as their
    # expected output; a stderr warning here would pollute their logs.
    if [[ -n "${ANTON_SKIP_BOOTSTRAP:-}" ]]; then
        BOOTSTRAP_FAIL_REASON="skip_bootstrap"
        return 1
    fi

    # Refuse to fetch when EXPECTED_VERSION is empty — no manifest, no
    # safe URL to construct.
    if [[ -z "$EXPECTED_VERSION" ]]; then
        _bootstrap_fail "missing_manifest_version" \
            "cannot determine expected version (missing or unreadable .claude-plugin/plugin.json)"
        return 1
    fi

    # Platform detect. uname -s → linux/darwin; uname -m → amd64/arm64.
    local os arch
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    case "$os" in
        linux|darwin) ;;
        *)
            _bootstrap_fail "unsupported_os:$os" \
                "unsupported OS '$os' (release pipeline ships linux + darwin only)"
            return 1
            ;;
    esac
    arch="$(uname -m)"
    case "$arch" in
        x86_64|amd64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        *)
            _bootstrap_fail "unsupported_arch:$arch" \
                "unsupported arch '$arch' (release pipeline ships amd64 + arm64 only)"
            return 1
            ;;
    esac

    # Fetch transport is unauthenticated HTTPS against the PUBLIC repo
    # (docs/adr/0037-public-distribution.md). No gh, no token, no auth.
    command -v curl >/dev/null 2>&1 || { _bootstrap_fail "curl_not_installed" \
        "curl not found on \$PATH; install curl to fetch the release binary"; return 1; }

    # Mutex via mkdir (atomic on every POSIX filesystem). Hooks may fire
    # concurrently (SessionStart + UserPromptSubmit on a fresh install
    # race in practice); without this, both download ~30 MB twice and
    # both `mv` over the same target.
    #
    # Stale-lock recovery is PID-fenced. The holder writes its pid into
    # the lockdir; a waiter that finds an unresponsive (`kill -0`-dead)
    # pid races to atomically rename the lockdir to a per-waiter
    # dead-lock path — `mv` on a directory within the same filesystem
    # is atomic, so exactly one waiter wins the rename and cleans up.
    # Losers loop and either acquire a freshly-created lock or wait on
    # the new holder. The previous 30s-rm-rf approach raced itself:
    # two waiters at attempt #31 could both rm-then-mkdir, both win,
    # both `mv` over $ANTON_BIN, and a third reader could exec a
    # half-installed binary between the two `mv`s.
    mkdir -p "$ANTON_BIN_DIR"
    __bootstrap_lock_dir="${ANTON_BIN_DIR}/.bootstrap.lock"
    while true; do
        # Cheap pre-check: ANTON_BIN was installed by an earlier waiter.
        # Without this, a waiter that wakes after the holder finishes
        # AND cleans up the lock would re-acquire the empty lock and
        # redownload the binary on top of the installed one.
        if [[ -x "$ANTON_BIN" ]]; then
            __bootstrap_lock_dir=""
            return 0
        fi
        if mkdir "$__bootstrap_lock_dir" 2>/dev/null; then
            # Stake ownership. Readers consult $$ only when deciding
            # whether reclaim is safe; the lock itself is the dir.
            echo "$$" > "$__bootstrap_lock_dir/pid"
            # Post-acquire double-check: another waiter could have
            # installed between our pre-check and the mkdir.
            if [[ -x "$ANTON_BIN" ]]; then
                rmdir "$__bootstrap_lock_dir" 2>/dev/null \
                    || rm -rf "$__bootstrap_lock_dir" 2>/dev/null || true
                __bootstrap_lock_dir=""
                return 0
            fi
            break
        fi
        # mkdir failed — lock is held. Recheck before waiting.
        if [[ -x "$ANTON_BIN" ]]; then
            __bootstrap_lock_dir=""
            return 0
        fi
        # PID-fenced reclaim: if the holder process is gone, race to
        # rename the stale lockdir. Only one waiter wins.
        local holder_pid=""
        holder_pid="$(cat "$__bootstrap_lock_dir/pid" 2>/dev/null || true)"
        if [[ -n "$holder_pid" ]] && ! kill -0 "$holder_pid" 2>/dev/null; then
            local dead_lock="${ANTON_BIN_DIR}/.bootstrap.lock.dead.$$"
            if mv "$__bootstrap_lock_dir" "$dead_lock" 2>/dev/null; then
                rm -rf "$dead_lock" 2>/dev/null || true
                printf '⚠ bootstrap: stale lock from dead pid %s; reclaimed\n' "$holder_pid" >&2
                continue
            fi
            # Lost the rename race; another waiter is reclaiming. Sleep.
        fi
        sleep 1
    done

    local binary_name="anton-core-v${EXPECTED_VERSION}-${os}-${arch}"

    # Stage downloads in a tmpdir so a partial fetch never lands at ANTON_BIN.
    __bootstrap_tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/anton-bootstrap.XXXXXX")"

    local bin_tmp="${__bootstrap_tmpdir}/${binary_name}"
    local checksums_tmp="${__bootstrap_tmpdir}/checksums.txt"
    local bundle_tmp="${__bootstrap_tmpdir}/${binary_name}.sigstore.json"

    # date +%s%3N is GNU-only; BSD date on macOS outputs the literal `N`,
    # which breaks the arithmetic below. Stick to second precision so the
    # telemetry duration field is portable; we report ms for downstream
    # consistency by multiplying by 1000 at emit time.
    local start_s end_s elapsed_ms
    start_s="$(date +%s 2>/dev/null || echo 0)"

    # Fetch binary + checksums via unauthenticated HTTPS. Each asset is fetched
    # by its stable releases/download/v<ver>/<asset> URL with `curl -fsSL -o
    # <dest>`, landing at bin_tmp / checksums_tmp where the retained checksum
    # verify looks. Required download — hard-fail on error. `… || dl_rc=$?` (not
    # a bare `curl …; dl_rc=$?`) is required under set -e: a failing simple
    # command would abort the function before the assignment.
    local repo_slug="xlightxyearx/anton-core-plugin"
    local base_url="https://github.com/${repo_slug}/releases/download/v${EXPECTED_VERSION}"
    local dl_err="${__bootstrap_tmpdir}/curl-download.err" dl_rc=0
    curl -fsSL -o "$bin_tmp" "${base_url}/${binary_name}" 2>"$dl_err" || dl_rc=$?
    if [[ $dl_rc -eq 0 ]]; then
        curl -fsSL -o "$checksums_tmp" "${base_url}/checksums.txt" 2>>"$dl_err" || dl_rc=$?
    fi
    if [[ $dl_rc -ne 0 ]]; then
        local dl_msg=""
        [[ -s "$dl_err" ]] && dl_msg="$(head -1 "$dl_err" 2>/dev/null || true)"
        # Fold curl's stderr first-line into the discriminator. scripts/core
        # sources this file with stderr redirected to a tmpfile and, on the
        # deferred path, re-emits ONLY BOOTSTRAP_FAIL_REASON into its
        # skill-shape envelope — so the `⚠ bootstrap:` line below never
        # reaches the operator there. Carrying the curl reason in the
        # discriminator is the one channel that survives both the hook-shape
        # (this file) and skill-shape (scripts/core) envelopes. Sanitize for
        # JSON exactly as scripts/core sanitizes its own source-error line:
        # strip control bytes, escape backslash + double-quote, since both
        # envelopes interpolate the reason raw via printf %s.
        local dl_reason_detail
        dl_reason_detail="$(printf '%s' "${dl_msg:-<no stderr>}" | tr -d '\000-\037' | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
        _bootstrap_fail "download_failed:${dl_reason_detail}" \
            "curl failed to fetch v${EXPECTED_VERSION} (curl exit ${dl_rc}): ${dl_msg:-<no stderr>}"
        return 1
    fi

    # Checksum verify (transport-integrity, always). The checksums.txt
    # format is `<sha256>  <filename>` — one line per artifact.
    local expected_sha actual_sha
    expected_sha="$(awk -v name="$binary_name" '$2 == name { print $1; exit }' "$checksums_tmp")"
    if [[ -z "$expected_sha" ]]; then
        printf '⚠ bootstrap: checksums.txt is missing an entry for %s\n' "$binary_name" >&2
        printf '⚠ first lines of checksums.txt:\n' >&2
        head -5 "$checksums_tmp" >&2 || true
        _bootstrap_fail "checksum_entry_missing" ""
        return 1
    fi
    if command -v shasum >/dev/null 2>&1; then
        actual_sha="$(shasum -a 256 "$bin_tmp" | awk '{print $1}')"
    elif command -v sha256sum >/dev/null 2>&1; then
        actual_sha="$(sha256sum "$bin_tmp" | awk '{print $1}')"
    else
        # shellcheck disable=SC2016  # $PATH is literal text in the user-facing message
        _bootstrap_fail "missing_sha256_tool" \
            'neither shasum nor sha256sum found on $PATH; cannot verify checksum'
        return 1
    fi
    if [[ "$expected_sha" != "$actual_sha" ]]; then
        _bootstrap_fail "checksum_mismatch" \
            "checksum mismatch for $binary_name: expected $expected_sha, got $actual_sha"
        return 1
    fi

    # Cosign verify (supply-chain, opportunistic). When cosign is absent
    # we proceed with checksum-only integrity — see ADR 0032 Consequence §3.
    local cosign_verified="false"
    if command -v cosign >/dev/null 2>&1; then
        # Best-effort bundle fetch. MUST be a separate curl call: a release
        # missing the sigstore bundle should skip supply-chain verification, not
        # sink the whole bootstrap — so a 404 here is tolerated (warn + proceed),
        # whereas the required binary/checksums fetch above hard-fails.
        if ! curl -fsSL -o "$bundle_tmp" "${base_url}/${binary_name}.sigstore.json" 2>/dev/null; then
            printf '⚠ bootstrap: cosign installed but bundle fetch failed; skipping supply-chain verification\n' >&2
        elif cosign verify-blob \
                --certificate-identity-regexp '^https://github\.com/xlightxyearx/anton-core-go/\.github/workflows/release\.yml@refs/tags/v[0-9]+\.[0-9]+\.[0-9]+.*$' \
                --certificate-oidc-issuer https://token.actions.githubusercontent.com \
                --certificate-github-workflow-trigger push \
                --bundle "$bundle_tmp" \
                "$bin_tmp" >/dev/null 2>&1; then
            cosign_verified="true"
        else
            _bootstrap_fail "cosign_verify_failed" \
                "cosign rejected $binary_name — refusing to install"
            return 1
        fi
    else
        printf '⚠ bootstrap: cosign not installed; skipping supply-chain verification (checksum verified)\n' >&2
    fi

    # Install: chmod, atomic mv. ANTON_BIN_DIR was created above when we
    # took the lock.
    chmod +x "$bin_tmp"
    local mv_err
    if ! mv_err="$(mv "$bin_tmp" "$ANTON_BIN" 2>&1)"; then
        _bootstrap_fail "install_failed" \
            "failed to move binary into place at $ANTON_BIN: ${mv_err:-unknown error}"
        return 1
    fi

    # Exec sanity probe. A checksum-valid but unusable artifact (corrupt
    # bytes, glibc-version mismatch, accidental wrong-arch upload that
    # still hashes correctly to checksums.txt) would otherwise install
    # successfully and then crash on every subsequent hook fire with no
    # path to recovery. Run a cheap `--version` probe and unwind the
    # install if it faults, so the next hook fire re-attempts bootstrap
    # rather than re-exec'ing the broken cache.
    #
    # Capture stderr so the failure discriminator surfaces the actual
    # reason (dyld error, glibc symbol missing, illegal-instruction) —
    # otherwise the same install fails the same way on every retry with
    # no breadcrumb.
    local probe_err="${__bootstrap_tmpdir}/exec-probe.err"
    if ! "$ANTON_BIN" --version >/dev/null 2>"$probe_err"; then
        local probe_msg=""
        if [[ -s "$probe_err" ]]; then
            probe_msg="$(head -1 "$probe_err" 2>/dev/null || true)"
        fi
        rm -f "$ANTON_BIN"
        _bootstrap_fail "exec_probe_failed" \
            "$ANTON_BIN installed but '--version' probe failed: ${probe_msg:-<no stderr>}; cache cleared"
        return 1
    fi

    end_s="$(date +%s 2>/dev/null || echo 0)"
    elapsed_ms=$(( (end_s - start_s) * 1000 ))

    # Telemetry — best-effort. The exec sanity probe above already proved
    # the binary runs, so failure here means the `event log` subcommand
    # is unavailable (unlikely) or the events DB is unwritable (operator
    # config). Either way it's non-fatal for bootstrap; the cached binary
    # is good.
    "$ANTON_BIN" event log \
        --source plugin-bootstrap \
        --severity info \
        --type binary_fetched \
        --detail "version=${EXPECTED_VERSION} os=${os} arch=${arch} cosign_verified=${cosign_verified} checksum_verified=true duration_ms=${elapsed_ms}" \
        >/dev/null 2>&1 || true

    _bootstrap_cleanup
    return 0
}

# Binary readiness check. If the versioned binary at ANTON_BIN is absent,
# attempt to bootstrap it. On bootstrap failure, emit the structured
# precondition envelope so Claude Code surfaces the defect rather than
# `exec: not found`, then exit 0 (hooks are non-blocking). The `reason`
# field is set by _bootstrap_fail's discriminator; Claude Code can route
# on it (e.g. surface `unsupported_arch:*` differently from a network
# failure).
#
# ANTON_DEFER_BOOTSTRAP_ERROR opts out of the print+exit-0 path so a
# sourcing script (scripts/core, used by skills) can handle the
# failure itself with skill-shape (not hook-shape) envelope semantics.
# Set non-empty by the caller before sourcing this header.
if [[ ! -x "$ANTON_BIN" ]]; then
    if ! _bootstrap_binary; then
        if [[ -z "${ANTON_DEFER_BOOTSTRAP_ERROR:-}" ]]; then
            reason="${BOOTSTRAP_FAIL_REASON:-unknown}"
            # shellcheck disable=SC2016  # backticks are literal in the JSON detail string, not command substitution
            printf '{"status":"error","error":{"kind":"precondition_missing","reason":"%s","detail":"%s not found and bootstrap failed (%s). Build the plugin binary with `make build` in %s, or run /anton-core:setup, or verify network access to the GitHub release for v%s. If a corrupt cached binary is suspected, delete %s and re-fire any hook to re-bootstrap."}}\n' \
                "$reason" "$ANTON_BIN" "$reason" "$CLAUDE_PLUGIN_ROOT" "$EXPECTED_VERSION" "$ANTON_BIN"
            exit 0
        fi
        # Deferred: caller will inspect BOOTSTRAP_FAIL_REASON and emit
        # its own envelope shape + exit code. Fall through.
    fi
fi

# Helper used by SessionEnd and PreCompact wrappers. Sets SESSION_ID from
# Claude Code's stdin JSON payload (docs/plugin-spec/08-hooks.md) for
# injection as --session-id. Production path: stdin is piped, jq is
# present, payload has session_id. TTY runs (manual invocation, tests) or
# missing jq fall through with SESSION_ID empty; the Go verb logs the skip.
#
# SESSION_ID is a global the calling wrapper reads after invocation —
# the static linter cannot see the cross-file usage, so the SC2034
# disable below pins the contract instead of marking the var unused.
_extract_session_id() {
    # shellcheck disable=SC2034  # read by sourcing wrapper after this returns
    SESSION_ID=""
    if [[ -t 0 ]] || ! command -v jq >/dev/null 2>&1; then
        return 0
    fi
    local payload
    payload=$(cat)
    if [[ -z "$payload" ]]; then
        return 0
    fi
    # jq stderr is intentionally NOT muffled: a malformed payload should
    # surface a parse error in the wrapper's stderr (which Claude Code
    # captures) rather than collapse silently into SESSION_ID="". The
    # trailing `|| true` keeps the wrapper non-blocking even when jq
    # exits non-zero — the Go verb still receives an empty SESSION_ID
    # and logs the skip per the non-blocking-hooks contract.
    # shellcheck disable=SC2034  # read by sourcing wrapper after this returns
    SESSION_ID=$(printf '%s' "$payload" | jq -r '.session_id // empty' || true)
}
