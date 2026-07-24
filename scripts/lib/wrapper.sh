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

# ── Binary resolution (ADR 0051 — hooks answer or enqueue) ────────────────
# Hooks never fetch or manage the binary. Resolution is a fixed precedence:
#   (1) the pin written by a successful `update apply-if-staged`;
#   (2) a repo-local dev build (`make build` → bin/anton-core);
#   (3) a staged-but-not-yet-rotated slot (self-heal — SessionStart rotates
#       it in on the next fire; a present staged slot is NOT "missing").
# If none resolve, emit a structured precondition envelope and exit 0 (hooks
# are non-blocking) — install/repair is /anton-core:setup's job, never a
# hook's. The fetch/skew/bootstrap machinery that used to live here moved to
# setup + the detached stage step per the update-lifecycle re-home.

# Read the binary_path field out of a staged-update.json record (the prefetch
# artefact, internal/update.StagedUpdate). jq preferred; grep is a defensive
# fallback so the wrapper still self-heals on a host without jq. Prints the
# path, or empty on any miss.
_read_staged_binary_path() {
    local state_file="$1"
    if [[ ! -f "$state_file" ]]; then
        echo ""
        return 0
    fi
    if command -v jq >/dev/null 2>&1; then
        jq -r '.binary_path // empty' "$state_file" 2>/dev/null || true
    else
        grep -E '"binary_path"[[:space:]]*:[[:space:]]*"[^"]+"' "$state_file" \
            | head -1 \
            | sed -E 's/.*"binary_path"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' \
            || true
    fi
}

# (1) Pin resolution. Source of truth is
# ${CLAUDE_PLUGIN_DATA}/data/state/installed-version (a single `vX.Y.Z\n` line
# written by `update apply-if-staged` after its health gate). The pin
# decouples the running binary from Claude Code's /plugin update cadence: a
# `git pull` that bumps plugin.json never changes which binary the wrapper
# exec's. Per docs/adr/0051-hooks-answer-or-enqueue.md.
PIN_FILE="${CLAUDE_PLUGIN_DATA}/data/state/installed-version"
ANTON_BIN=""
if [[ -f "$PIN_FILE" ]]; then
    INSTALLED_VERSION="$(<"$PIN_FILE")"
    INSTALLED_VERSION="${INSTALLED_VERSION#v}"
    INSTALLED_VERSION="${INSTALLED_VERSION//$'\n'/}"
    ANTON_BIN="${CLAUDE_PLUGIN_DATA}/data/versions/v${INSTALLED_VERSION}/anton-core"
    if [[ ! -x "$ANTON_BIN" ]]; then
        # Pin names a slot that doesn't exist. Refuse to start rather than
        # silently resolve a different version — the pin exists precisely to
        # prevent that drift. Operator must run `core update rollback` or
        # repair the versions/ directory.
        printf '⚠ pin names a missing binary slot v%s; operator action required\n' "$INSTALLED_VERSION" >&2
        printf '{"status":"error","error":{"kind":"internal","reason":"pin_drift_fatal","pinned_version":"v%s"}}\n' "$INSTALLED_VERSION" >&2
        exit 2
    fi
fi
export ANTON_BIN

# (2) Dev-build override. When running from a working tree with a freshly
# built bin/anton-core (`make build`) and no valid pin resolved, prefer it so
# contributors can test wrapper changes without staging a release binary.
if [[ -x "${CLAUDE_PLUGIN_ROOT}/bin/anton-core" ]] && [[ ! -x "$ANTON_BIN" ]]; then
    ANTON_BIN="${CLAUDE_PLUGIN_ROOT}/bin/anton-core"
    export ANTON_BIN
fi

# (3) Staged-slot self-heal. No pin and no dev build, but a staged-update.json
# record is present: resolve ANTON_BIN to the STAGED binary so SessionStart
# can rotate it in (its `update apply-if-staged` writes the first pin). This
# is the "staged-but-not-yet-rotated" case — a present staged slot must NOT
# be treated as missing, or SessionStart never gets a binary to run its
# rotate and the self-heal breaks.
STAGED_STATE="${CLAUDE_PLUGIN_DATA}/data/state/staged-update.json"
if [[ ! -x "$ANTON_BIN" ]] && [[ -f "$STAGED_STATE" ]]; then
    _staged_bin="$(_read_staged_binary_path "$STAGED_STATE")"
    if [[ -n "$_staged_bin" ]]; then
        # binary_path is written relative to the data dir
        # (data/versions/v<ver>/anton-core); tolerate an absolute path too.
        case "$_staged_bin" in
            /*) : ;;
            *)  _staged_bin="${CLAUDE_PLUGIN_DATA}/${_staged_bin}" ;;
        esac
        if [[ -x "$_staged_bin" ]]; then
            ANTON_BIN="$_staged_bin"
            export ANTON_BIN
        fi
    fi
fi

# Precondition: nothing resolved to an executable binary. Emit the structured
# precondition envelope on stdout so Claude Code surfaces the defect (rather
# than a raw `exec: not found`), then exit 0 — hooks are non-blocking, and
# installing the binary is /anton-core:setup's job.
#
# ANTON_DEFER_BOOTSTRAP_ERROR opts out of the print+exit path so a sourcing
# script (scripts/core, used by skills) can emit its own skill-shape envelope
# with a non-zero exit. Set non-empty by the caller before sourcing.
if [[ ! -x "$ANTON_BIN" ]]; then
    if [[ -z "${ANTON_DEFER_BOOTSTRAP_ERROR:-}" ]]; then
        printf '%s\n' '{"status":"error","error":{"kind":"precondition_missing","reason":"binary_missing_run_setup","detail":"anton-core binary not found; run /anton-core:setup to install anton-core."}}'
        exit 0
    fi
    # Deferred: the sourcing script inspects ANTON_BIN and emits its own
    # envelope shape + exit code. Fall through.
fi

# Helper used by SessionEnd and PreCompact wrappers. Sets SESSION_ID from
# Claude Code's stdin JSON payload (docs/plugin-spec/08-hooks.md) for
# injection as --session-id, and sets TRANSCRIPT_PATH from .transcript_path
# for --transcript-path injection (fail→success pattern mining). Production
# path: stdin is piped, jq is present, payload has session_id. TTY runs
# (manual invocation, tests) or missing jq fall through with SESSION_ID and
# TRANSCRIPT_PATH empty; the Go verb logs the skip.
#
# SESSION_ID and TRANSCRIPT_PATH are globals the calling wrapper reads after
# invocation — the static linter cannot see the cross-file usage, so the
# SC2034 disables below pin the contract instead of marking the vars unused.
_extract_session_id() {
    # shellcheck disable=SC2034  # read by sourcing wrapper after this returns
    SESSION_ID=""
    # shellcheck disable=SC2034  # read by sourcing wrapper after this returns
    TRANSCRIPT_PATH=""
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
    # shellcheck disable=SC2034  # read by sourcing wrapper after this returns
    TRANSCRIPT_PATH=$(printf '%s' "$payload" | jq -r '.transcript_path // empty' || true)
}

# hook_exec_fail_open <verb> [args…] — run the engine subcommand and ALWAYS
# exit 0, forwarding its stdout only on a zero exit. Generalizes the guarded
# invocation hotfix v2.2.1 applied to pre-tool-use.sh: a pinned binary that
# predates <verb> returns unknown-command/exit 2, a crash returns nonzero;
# either way the wrapper forwards nothing and exits 0, so Claude Code never
# reads the failure as a PreToolUse deny or a blocked UserPromptSubmit. Under
# `set -e` the command-substitution failure is caught by the `if`, not fatal.
# Buffering stdout is safe: hook outputs are small (advisory context / a
# protocol object). stdin passes through the substitution to the verb (the
# post-tool-use payload path).
hook_exec_fail_open() {
    local out
    if out="$("$ANTON_BIN" hook "$@")"; then
        printf '%s' "$out"
    fi
    exit 0
}
