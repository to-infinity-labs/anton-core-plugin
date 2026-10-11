#!/usr/bin/env bash
# Shared header for plugin hook wrappers. Sourced, never executed directly.
# Inside this file `$0` is the *caller's* path (the wrapper that sourced us),
# so `dirname $0` resolves to scripts/ and `..` to repo root.
set -euo pipefail

# _json_field <key> <file> — the string value of <key> in a JSON file, empty on
# any miss. jq preferred; the grep fallback keeps a jq-less host working.
_json_field() {
    [[ -f "$2" ]] || return 0
    if command -v jq >/dev/null 2>&1; then
        jq -r --arg k "$1" '.[$k] // empty' "$2" 2>/dev/null || true
    else
        grep -E "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]+\"" "$2" 2>/dev/null \
            | head -1 \
            | sed -E "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"([^\"]+)\".*/\1/" \
            || true
    fi
}

# _normalize_root <root> — the Go resolver's NormalizeRoot: a trailing /data
# segment is stripped, else the store would nest data/data.
_normalize_root() {
    local r="$1"
    while [[ "$r" == */ && "$r" != / ]]; do r="${r%/}"; done
    [[ "${r##*/}" == data ]] && r="${r%data}" && r="${r%/}"
    printf '%s' "${r:-/}"
}

# _resolve_data_root [override] — the binary's data-root chain, so the shell and
# Go always agree: the override or CORE_DATA_DIR, the CORE_DEV_MODE-gated
# ./data probe, ~/.anton-core/config.json's data_root, a previous release's
# Claude Code store while ~/.anton-core holds none (a real directory, not the
# compat symlink a move leaves), then ~/.anton-core. Sets _anton_root and
# _anton_root_src (env|dev_mode|operator_config|legacy|default); returns 1 when
# CORE_DATA_DIR and HOME are both unset. No harness's plugin-data variable
# takes part.
_resolve_data_root() {
    local v="${1:-${CORE_DATA_DIR:-}}"
    _anton_root=""
    _anton_root_src=""
    if [[ -n "$v" ]]; then
        _anton_root="$(_normalize_root "$v")"
        _anton_root_src="env"
        return 0
    fi
    if [[ -n "${CORE_DEV_MODE:-}" && -d "$PWD/data" ]]; then
        _anton_root="$(_normalize_root "$PWD")"
        _anton_root_src=dev_mode
        return 0
    fi
    [[ -n "${HOME:-}" ]] || return 1
    v="$(_json_field data_root "$HOME/.anton-core/config.json")"
    if [[ -n "$v" ]]; then
        _anton_root="$(_normalize_root "$v")"
        _anton_root_src=operator_config
        return 0
    fi
    if [[ ! -e "$HOME/.anton-core/data/core.db" ]]; then
        v="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/data/anton-core-anton-core"
        if [[ -d "$v" && ! -L "$v" && -f "$v/data/core.db" ]]; then
            _anton_root="$v"
            _anton_root_src=legacy
            return 0
        fi
    fi
    _anton_root="$HOME/.anton-core"
    _anton_root_src=default
}

# _resolve_pinned_bin <root> — sets ANTON_BIN by a fixed precedence: (1) the pin
# `update apply-if-staged` writes at data/state/installed-version, (2) a
# repo-local dev build (`make build` → bin/anton-core), (3) a staged slot not
# yet rotated in, so SessionStart has a binary to rotate it with. Hooks never
# fetch: installing is the setup skill's job. A pin naming a missing slot
# returns 2 with ANTON_BIN left on that slot — resolving any other version is
# exactly the drift the pin exists to prevent. A dev-mode root is the cwd,
# which a hook can fire in any checkout of, so only the plugin's own dev build
# is ever executed for it — never a pin or staged slot found under ./data.
_resolve_pinned_bin() {
    local root="$1" ver staged
    ANTON_BIN=""
    if [[ "${_anton_root_src:-}" == dev_mode ]]; then
        [[ -x "$ANTON_PLUGIN_ROOT/bin/anton-core" ]] && ANTON_BIN="$ANTON_PLUGIN_ROOT/bin/anton-core"
        return 0
    fi
    if [[ -f "$root/data/state/installed-version" ]]; then
        ver="$(<"$root/data/state/installed-version")"
        ver="${ver#v}"
        ver="${ver//$'\n'/}"
        ANTON_BIN="$root/data/versions/v${ver}/anton-core"
        [[ -x "$ANTON_BIN" ]] && return 0
        # The remedy must not pass this gate: the anton launcher runs
        # `bootstrap` before scripts/core sources this file.
        printf '⚠ pin names a missing binary slot v%s; restore it with: anton bootstrap --version v%s\n' "$ver" "$ver" >&2
        printf '{"status":"error","error":{"kind":"internal","reason":"pin_drift_fatal","pinned_version":"v%s"}}\n' "$ver" >&2
        return 2
    fi
    if [[ -x "$ANTON_PLUGIN_ROOT/bin/anton-core" ]]; then
        ANTON_BIN="$ANTON_PLUGIN_ROOT/bin/anton-core"
        return 0
    fi
    # binary_path is written relative to the data dir; tolerate an absolute one.
    staged="$(_json_field binary_path "$root/data/state/staged-update.json")"
    case "$staged" in
        "") ;;
        /*) [[ -x "$staged" ]] && ANTON_BIN="$staged" ;;
        *) [[ -x "$root/$staged" ]] && ANTON_BIN="$root/$staged" ;;
    esac
    return 0
}

# ANTON_HARNESS: the hook runner's --harness, else the harness whose session
# variables are set. _anton_harness_flag records that the runner named it, the
# one case where a precondition must stay off stdout.
ANTON_HARNESS=""
_anton_harness_flag=""
_prev=""
for _arg in "$@"; do
    case "$_arg" in
        --harness=*) ANTON_HARNESS="${_arg#--harness=}" _anton_harness_flag=1 ;;
        *) [[ "$_prev" == "--harness" ]] && ANTON_HARNESS="$_arg" _anton_harness_flag=1 ;;
    esac
    _prev="$_arg"
done
unset _prev _arg
if [[ -z "$ANTON_HARNESS" ]]; then
    if [[ -n "${CODEX_SESSION_ID:-}${CODEX_THREAD_ID:-}" ]]; then
        ANTON_HARNESS=codex
    elif [[ -n "${CLAUDE_PLUGIN_DATA:-}${CLAUDE_CODE_SESSION_ID:-}" ]]; then
        ANTON_HARNESS=claude
    fi
fi
export ANTON_HARNESS

# The harness sets its own plugin-root variable at hook fire time; a sourcing
# script may name its own root in _anton_self_root, else the caller sits in
# scripts/ and the root is its parent. CLAUDE_PLUGIN_ROOT stays exported for a
# pinned binary older than ANTON_PLUGIN_ROOT.
ANTON_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-${PLUGIN_ROOT:-${_anton_self_root:-$(cd "$(dirname "$0")/.." && pwd)}}}"
: "${CLAUDE_PLUGIN_ROOT:=$ANTON_PLUGIN_ROOT}"
export ANTON_PLUGIN_ROOT CLAUDE_PLUGIN_ROOT

if _resolve_data_root "${CORE_DATA_DIR:-}"; then
    CORE_DATA_DIR="$_anton_root"
    export CORE_DATA_DIR
fi

# ANTON_RESOLVE_ONLY: a sourcing script wants the exports, not a binary.
if [[ -n "${ANTON_RESOLVE_ONLY:-}" ]]; then
    return 0
fi

ANTON_BIN=""
if [[ -n "$_anton_root" ]]; then
    _pin_rc=0
    _resolve_pinned_bin "$_anton_root" || _pin_rc=$?
    if [[ $_pin_rc -ne 0 ]]; then
        # scripts/core captures this file's stderr; an exit here would end it
        # with the message still in the capture file.
        [[ -n "${ANTON_DEFER_BOOTSTRAP_ERROR:-}" ]] && return 2
        # Codex reads a non-zero hook exit as a failed hook.
        [[ -n "$_anton_harness_flag" && "$ANTON_HARNESS" == codex ]] && exit 0
        exit 2
    fi
fi
export ANTON_BIN

# Nothing resolved. A hook prints the precondition envelope and exits 0 (hooks
# are non-blocking). Under the runner's --harness codex the envelope goes to
# stderr instead: Codex's strict parse fails any {-prefixed stdout that is not
# a valid output. A Codex shell call, with no flag, is a command rather than a
# hook, so it fails non-zero. ANTON_DEFER_BOOTSTRAP_ERROR lets a sourcing
# script (scripts/core) emit its own skill-shape envelope instead.
if [[ ! -x "$ANTON_BIN" && -z "${ANTON_DEFER_BOOTSTRAP_ERROR:-}" ]]; then
    # shellcheck disable=SC2016  # $anton-core:setup is Codex's skill syntax, not an expansion
    _missing='{"status":"error","error":{"kind":"precondition_missing","reason":"binary_missing_run_setup","detail":"anton-core binary not found; run the setup skill (/anton-core:setup, or $anton-core:setup in Codex) to install anton-core."}}'
    if [[ "$ANTON_HARNESS" == codex ]]; then
        if [[ -n "$_anton_harness_flag" ]]; then
            printf '%s\n' "$_missing" >&2
            exit 0
        fi
        printf '%s\n' "$_missing"
        exit 2
    fi
    printf '%s\n' "$_missing"
    exit 0
fi

# _anton_payload_args — reads the hook payload from stdin once, byte-exact,
# into _anton_payload (no read when stdin is a TTY), its session_id and
# transcript_path into _anton_session_id and _anton_transcript_path, then
# re-feeds the payload as the shell's stdin. The caller puts them ahead of
# its args with `set --` (an empty array under `set -u` dies in /bin/bash
# 3.2): a previous release's still-pinned binary reads only the flags.
_anton_payload_args() {
    _anton_payload="" _anton_session_id="" _anton_transcript_path=""
    [[ -t 0 ]] && return 0
    _anton_payload="$(cat; printf x)"
    _anton_payload="${_anton_payload%x}"
    _anton_session_id="$(_anton_payload_field session_id)"
    _anton_transcript_path="$(_anton_payload_field transcript_path)"
    exec < <(printf '%s' "$_anton_payload")
}

# _anton_payload_field <key> — a top-level string of _anton_payload, empty on
# any miss; jq preferred, else grep.
_anton_payload_field() {
    [[ -n "$_anton_payload" ]] || return 0
    if command -v jq >/dev/null 2>&1; then
        printf '%s' "$_anton_payload" | jq -r --arg k "$1" '.[$k] // empty | strings' 2>/dev/null || true
    else
        printf '%s' "$_anton_payload" \
            | grep -oE "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
            | head -1 \
            | sed -E 's/.*:[[:space:]]*"([^"]*)"$/\1/' \
            || true
    fi
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
