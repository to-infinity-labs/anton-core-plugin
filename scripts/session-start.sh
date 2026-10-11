#!/usr/bin/env bash
# Plugin hook: SessionStart
# shellcheck source=lib/wrapper.sh disable=SC1091
source "$(dirname "$0")/lib/wrapper.sh"

# Rotate a staged update in via the resolved binary. Budget-bounded so
# SessionStart never hangs; stderr is tee'd to a data-dir log so apply
# failures don't pollute Claude Code's console; `|| true` keeps it
# non-blocking. Because the wrapper resolves ANTON_BIN to the STAGED binary
# when there is no pin (the staged-slot self-heal), this single call covers
# BOTH "pinned binary rotates a staged slot" and "staged binary rotates
# itself + writes the first pin".
LOG_DIR="${CORE_DATA_DIR:-/tmp}/data/logs"
mkdir -p "$LOG_DIR" 2>/dev/null || true
"$ANTON_BIN" update apply-if-staged --quiet --budget 10s 1>/dev/null 2>>"$LOG_DIR/update.err" || true

# Re-resolve the pin: the rotate above may have just written installed-version
# (the staged-arm self-heal), so the ANTON_BIN the wrapper resolved (possibly
# the staged slot) is now stale.
_pin_rc=0
_resolve_pinned_bin "$CORE_DATA_DIR" || _pin_rc=$?
if [[ $_pin_rc -ne 0 ]]; then
    [[ -n "$_anton_harness_flag" && "$ANTON_HARNESS" == codex ]] && exit 0
    exit 2
fi
export ANTON_BIN

# Move a store outside ~/.anton-core into it, detached so the hook never waits
# on it; this session keeps the old root, now a compat symlink.
# spawn-detached's own envelope stays off the hook's stdout.
# shellcheck disable=SC2094  # --log is the detached child's append target; nothing here reads it
"$ANTON_BIN" hook spawn-detached --log "$LOG_DIR/update.err" -- "$ANTON_BIN" setup relocate-data-root >/dev/null 2>>"$LOG_DIR/update.err" || true

hook_exec_fail_open session-start "$@"
