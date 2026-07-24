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
LOG_DIR="${CLAUDE_PLUGIN_DATA:-/tmp}/data/logs"
mkdir -p "$LOG_DIR" 2>/dev/null || true
"$ANTON_BIN" update apply-if-staged --quiet --budget 10s 1>/dev/null 2>>"$LOG_DIR/update.err" || true

# Re-resolve the pin: the rotate above may have just written installed-version
# (the staged-arm self-heal), so the ANTON_BIN the wrapper resolved (possibly
# the staged slot) is now stale. Recompute it from the pin file so the exec
# below runs the now-current binary. Guard the slot-missing case with the same
# pin_drift envelope shape the wrapper emits.
PIN_FILE="${CLAUDE_PLUGIN_DATA}/data/state/installed-version"
if [[ -f "$PIN_FILE" ]]; then
    _pin_ver="$(<"$PIN_FILE")"
    _pin_ver="${_pin_ver#v}"
    _pin_ver="${_pin_ver//$'\n'/}"
    ANTON_BIN="${CLAUDE_PLUGIN_DATA}/data/versions/v${_pin_ver}/anton-core"
    if [[ ! -x "$ANTON_BIN" ]]; then
        printf '⚠ pin names a missing binary slot v%s; operator action required\n' "$_pin_ver" >&2
        printf '{"status":"error","error":{"kind":"internal","reason":"pin_drift_fatal","pinned_version":"v%s"}}\n' "$_pin_ver" >&2
        exit 2
    fi
    export ANTON_BIN
fi

# Seed ~/.anton-core/config.json with the resolved data root at the earliest
# authoritative moment (hooks get CLAUDE_PLUGIN_DATA → wrapper.sh set
# CORE_DATA_DIR). This makes the shim's config.json fallback (Bug 2 A1) work on
# first run, before setup Step 3b would otherwise write it. Best-effort.
"$ANTON_BIN" setup persist-data-dir >/dev/null 2>>"$LOG_DIR/update.err" || true

hook_exec_fail_open session-start "$@"
