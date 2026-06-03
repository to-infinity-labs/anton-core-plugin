#!/usr/bin/env bash
# Plugin hook: SessionEnd
# shellcheck source=lib/wrapper.sh disable=SC1091
source "$(dirname "$0")/lib/wrapper.sh"

_extract_session_id
if [[ -n "$SESSION_ID" ]]; then
    set -- --session-id "$SESSION_ID" "$@"
fi

# Background prefetch; never blocks SessionEnd. Stderr is tee'd to a data-dir
# log (mirroring session-start.sh) so a silent prefetch failure — asset
# missing, disk full, arch mismatch — leaves a forensic trail instead of
# vanishing into /dev/null. The orchestrator additionally records
# PREFETCH_FAILED (verification) / PREFETCH_DEFERRED (transient) rows in
# events_log for the /health and `update status` surfaces.
LOG_DIR="${CLAUDE_PLUGIN_DATA:-/tmp}/data/logs"
mkdir -p "$LOG_DIR" 2>/dev/null || true
("$ANTON_BIN" update prefetch --quiet --budget 60s 1>/dev/null 2>>"$LOG_DIR/update.err" &)

exec "$ANTON_BIN" hook session-end "$@"
