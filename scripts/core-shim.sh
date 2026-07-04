#!/usr/bin/env bash
# Operator-shell launcher for anton-core. /anton-core:setup copies this file
# to <data-root>/data/bin/core and points the ~/.local/bin/core convenience
# symlink at that copy. Its sole job: self-locate, then exec the self-update
# system's live-binary pointer at <data-root>/data/versions/current — so a
# bare-shell `core` always runs the version the self-update orchestrator last
# applied, NOT the version-pinned plugin cache that `/plugin update` rotates
# out from under the symlink (the staleness bug this launcher exists to fix).
#
# DELIBERATELY MINIMAL. It sources nothing (in particular NOT
# scripts/lib/wrapper.sh), exports no environment, and performs no
# bootstrap/cosign. The bare binary self-resolves its data root with no env
# (CORE_DATA_DIR -> dev-mode ./data -> ~/.anton-core/config.json), and binary
# bootstrap + supply-chain verification are the hooks' job. Duplicating the
# wrapper here would re-couple the operator entry point to a rotating cache —
# exactly what this fixes.
#
# Symlink-safe: resolves $0 via a readlink loop (macOS has no `readlink -f`)
# so the launcher directory derives correctly even when invoked through the
# ~/.local/bin/core symlink. The hop cap kills a cyclic-symlink hang.
set -euo pipefail

# --- self-locate -----------------------------------------------------------
# POSIX SYMLOOP_MAX is 8; 40 hops gives headroom for nested workspace
# symlinks while still killing an a->b, b->a cycle in well under a second
# (macOS readlink does not detect cycles, so the cap is load-bearing).
_script_path="$0"
_link_hops=0
while [[ -L "$_script_path" ]]; do
    _link_hops=$((_link_hops + 1))
    if [[ $_link_hops -gt 40 ]]; then
        printf 'anton-core: more than 40 symlink hops resolving %s — refusing to continue; check %s and ancestors for a cyclic symlink\n' \
            "$0" "$0" >&2
        exit 2
    fi
    if ! _target="$(readlink "$_script_path" 2>&1)"; then
        printf 'anton-core: readlink failed on %s: %s; check link permissions and target existence\n' \
            "$_script_path" "$_target" >&2
        exit 2
    fi
    case "$_target" in
        /*) _script_path="$_target" ;;
        *)  _script_path="$(cd "$(dirname "$_script_path")" && cd "$(dirname "$_target")" && pwd)/$(basename "$_target")" ;;
    esac
done
_script_dir="$(cd "$(dirname "$_script_path")" && pwd)"

# The launcher lives at <data-root>/data/bin/core; the live-binary pointer is
# at <data-root>/data/versions/current — one directory up, then versions/.
_current="$_script_dir/../versions/current"

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
    if [[ -d "./data" ]]; then _devmode="present (\$PWD/data)"; else _devmode="<absent>"; fi
    if [[ -f "${HOME:-}/.anton-core/config.json" ]]; then _opcfg="present"; else _opcfg="<absent>"; fi
    printf 'anton-core operator launcher\n'
    printf '  launcher:        %s\n' "$_script_path"
    printf '  current_link:    %s\n' "$_current"
    printf '  current_target:  %s\n' "$_current_target"
    printf '  live_binary:     %s\n' "$_live_binary"
    printf '  binary_version:  %s\n' "$_binary_version"
    printf '  data-root resolution (launcher sets no env; binary self-resolves):\n'
    printf '    CORE_DATA_DIR:               %s\n' "$_core_data_dir"
    printf '    dev-mode ./data:             %s\n' "$_devmode"
    printf '    ~/.anton-core/config.json:   %s\n' "$_opcfg"
    exit 0
fi

# --- guard: the live-binary pointer must resolve to an executable -----------
if [[ ! -x "$_current" ]]; then
    # shellcheck disable=SC2016  # backticks are literal text in the operator message, not command substitution
    printf 'anton-core: live binary not found at %s — run /anton-core:setup to initialize the self-update state (or `core update apply-if-staged` if a plugin update is pending).\n' \
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

# argv[0]=core keeps cobra usage strings tidy. The only argv[0]-keyed logic
# (the hooks repos-sync self-dispatch) is unreachable from operator-shell, and
# its PATH fallback resolves `core` regardless.
exec -a core "$_current" "$@"
