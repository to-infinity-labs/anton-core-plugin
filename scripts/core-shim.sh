#!/usr/bin/env bash
# Operator-shell launcher for anton-core. /anton-core:setup copies this file
# to <data-root>/data/bin/core and points the ~/.local/bin/anton convenience
# symlink at that copy. In a terminal its job is: self-locate, then exec the
# self-update system's live-binary pointer at <data-root>/data/versions/current
# — so a bare-shell `anton` always runs the version the self-update orchestrator
# last applied, NOT the version-pinned plugin cache that `/plugin update`
# rotates out from under the symlink. Inside a Claude Code session, where the
# plugin's own bin/anton is on PATH, it delegates to that launcher instead.
#
# DELIBERATELY MINIMAL on the terminal path. It sources nothing (in particular
# NOT scripts/lib/wrapper.sh), exports no environment, and performs no
# bootstrap/cosign. The bare binary self-resolves its data root with no env
# (CORE_DATA_DIR -> CORE_DEV_MODE-gated ./data -> ~/.anton-core/config.json),
# and binary bootstrap + supply-chain verification are the hooks' job.
# Duplicating the wrapper here would re-couple the operator entry point to a
# rotating cache.
#
# Symlink-safe: resolves $0 via a readlink loop (macOS has no `readlink -f`)
# so the launcher directory derives correctly even when invoked through the
# ~/.local/bin/anton symlink. The hop cap kills a cyclic-symlink hang.
set -euo pipefail

# --- self-locate -----------------------------------------------------------
# POSIX SYMLOOP_MAX is 8; 40 hops gives headroom for nested workspace
# symlinks while still killing an a->b, b->a cycle in well under a second
# (macOS readlink does not detect cycles, so the cap is load-bearing).
# _resolve_link <path> [fatal] — follows <path> to a non-link, setting
# _resolved. With "fatal" a failure exits 2 (self-locate); without, it returns 1
# so the plugin-launcher walk can skip a broken candidate.
_resolve_link() {
    local _hops=0 _target
    _resolved="$1"
    while [[ -L "$_resolved" ]]; do
        _hops=$((_hops + 1))
        if [[ $_hops -gt 40 ]]; then
            [[ "${2:-}" == fatal ]] || return 1
            printf 'anton-core: more than 40 symlink hops resolving %s — refusing to continue; check %s and ancestors for a cyclic symlink\n' \
                "$1" "$1" >&2
            exit 2
        fi
        if ! _target="$(readlink "$_resolved" 2>&1)"; then
            [[ "${2:-}" == fatal ]] || return 1
            printf 'anton-core: readlink failed on %s: %s; check link permissions and target existence\n' \
                "$_resolved" "$_target" >&2
            exit 2
        fi
        case "$_target" in
            /*) _resolved="$_target" ;;
            *)  _resolved="$(cd "$(dirname "$_resolved")" && cd "$(dirname "$_target")" && pwd)/$(basename "$_target")" || return 1 ;;
        esac
    done
}

_resolve_link "$0" fatal
_script_path="$_resolved"
_script_dir="$(cd "$(dirname "$_script_path")" && pwd)"

# The launcher lives at <data-root>/data/bin/core; the live-binary pointer is
# at <data-root>/data/versions/current — one directory up, then versions/.
_current="$_script_dir/../versions/current"

# In a Claude Code session the plugin's bin/anton is on PATH (appended, so this
# launcher wins the lookup); hand off to it so pin resolution, data-root
# translation and the bootstrap intercept apply. A terminal has no plugin bin/
# on PATH, so there this launcher runs the live binary itself.
_find_plugin_launcher() {
    _plugin_launcher=""
    # Recursion fence: never delegate twice.
    [[ -z "${ANTON_OPERATOR_DELEGATED:-}" ]] || return 1
    local _dir _cand _cdir IFS=:
    for _dir in $PATH; do
        _cand="${_dir:-.}/anton"
        # Resolve before the -x test: a cyclic link fails -x silently, and the
        # walk must reach _resolve_link's non-fatal path for it.
        [[ -L "$_cand" || -x "$_cand" ]] || continue
        _resolve_link "$_cand" || continue
        [[ -x "$_resolved" ]] || continue
        [[ "$_resolved" == "$_script_path" ]] && continue
        _cdir="$(cd "$(dirname "$_resolved")/.." 2>/dev/null && pwd)" || continue
        [[ -x "$_cdir/scripts/core" ]] || continue
        grep -Eq '"name"[[:space:]]*:[[:space:]]*"anton-core"' "$_cdir/.claude-plugin/plugin.json" 2>/dev/null || continue
        _plugin_launcher="$_cand"
        return 0
    done
    return 1
}

# --- --launcher-check diagnostic (resolve + report, no exec) ----------------
# Parallels `scripts/core --wrapper-check`, but reports the orthogonal set of
# facts this launcher cares about: where it resolved itself, what `current`
# points at, the live binary, and the data-root resolution inputs the binary
# will consult (the launcher itself sets none of them).
if [[ "${1:-}" == "--launcher-check" ]]; then
    if [[ -L "$_current" ]]; then
        _current_target="$(readlink "$_current" 2>/dev/null || echo '<unreadable>')"
    elif [[ -e "$_current" ]]; then
        _current_target="<not a symlink>"
    else
        _current_target="<absent>"
    fi
    if [[ -x "$_current" ]]; then
        _live_binary="ok"
        # Report the LIVE binary's own version so a stale-installed-binary
        # incident (old binary × newer schema) is visible from the diagnostic
        # the operator already runs. `--version` is DB-less (the binary's
        # argsNeedNoDB fast-path), so this capture needs no data root and never
        # execs the CLI flow — it is a probe, not the exec handoff below.
        _binary_version="$("$_current" --version 2>/dev/null || echo '<unavailable>')"
        [[ -n "$_binary_version" ]] || _binary_version="<unavailable>"
    else
        _live_binary="<missing or not executable>"
        _binary_version="<unavailable>"
    fi
    if [[ -n "${CORE_DATA_DIR:-}" ]]; then _core_data_dir="$CORE_DATA_DIR"; else _core_data_dir="<unset>"; fi
    if [[ -d "./data" ]]; then
        if [[ -n "${CORE_DEV_MODE:-}" ]]; then
            _devmode="enabled (\$PWD/data, CORE_DEV_MODE set)"
        else
            _devmode="gated off (\$PWD/data present, CORE_DEV_MODE unset)"
        fi
    else
        _devmode="<absent>"
    fi
    if [[ -f "${HOME:-}/.anton-core/config.json" ]]; then _opcfg="present"; else _opcfg="<absent>"; fi
    printf 'anton-core operator launcher\n'
    printf '  launcher:        %s\n' "$_script_path"
    printf '  current_link:    %s\n' "$_current"
    printf '  current_target:  %s\n' "$_current_target"
    printf '  live_binary:     %s\n' "$_live_binary"
    printf '  binary_version:  %s\n' "$_binary_version"
    _find_plugin_launcher || true
    printf '  plugin_launcher: %s\n' "${_plugin_launcher:-<none>}"
    printf '  data-root resolution (launcher sets no env; binary self-resolves):\n'
    printf '    CORE_DATA_DIR:               %s\n' "$_core_data_dir"
    printf '    dev-mode ./data:             %s\n' "$_devmode"
    printf '    ~/.anton-core/config.json:   %s\n' "$_opcfg"
    exit 0
fi

if _find_plugin_launcher; then
    export ANTON_OPERATOR_DELEGATED=1
    exec "$_plugin_launcher" "$@"
fi

# --- guard: the live-binary pointer must resolve to an executable -----------
if [[ ! -x "$_current" ]]; then
    # shellcheck disable=SC2016  # backticks are literal text in the operator message, not command substitution
    printf 'anton-core: live binary not found at %s — run /anton-core:setup to initialize the self-update state (or `anton update apply-if-staged` if a plugin update is pending).\n' \
        "$_current" >&2
    exit 2
fi

# --- config-absent hint (non-fatal) ----------------------------------------
# The bare binary resolves its data root with no env (CORE_DATA_DIR ->
# dev-mode ./data -> ~/.anton-core/config.json) and emits a precondition
# envelope when none is present. Surface a friendlier one-liner first, then
# still exec so the operator also gets the binary's authoritative envelope.
if [[ -z "${CORE_DATA_DIR:-}" ]] && [[ ! -d "./data" ]] && [[ ! -f "${HOME:-}/.anton-core/config.json" ]]; then
    printf 'anton-core: no data root configured (~/.anton-core/config.json absent) — run /anton-core:setup.\n' >&2
fi

# argv[0]=core keeps cobra usage strings tidy. This exec runs only from a
# terminal (a session delegates above), where the argv[0]-keyed hooks repos-sync
# self-dispatch never happens.
exec -a core "$_current" "$@"
