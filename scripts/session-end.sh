#!/usr/bin/env bash
# Plugin hook: SessionEnd
# shellcheck source=lib/wrapper.sh disable=SC1091
source "$(dirname "$0")/lib/wrapper.sh"

_extract_session_id
if [[ -n "$SESSION_ID" ]]; then
    set -- --session-id "$SESSION_ID" "$@"
fi
if [[ -n "$TRANSCRIPT_PATH" ]]; then
    set -- --transcript-path "$TRANSCRIPT_PATH" "$@"
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

# Best-effort: reap a session-scoped dashboard server on the default port.
# LISTEN-filtered (a bare port query also matches established browser
# sockets) and command-matched against the dashboard binary's basename —
# anchored so every install layout matches (`anton-core` pinned/dev,
# `anton-core-vX.Y.Z` bootstrap) and a foreign command line that merely
# contains similar words (e.g. `encore dashboard`) never does. Insurance
# behind Claude Code's own background-task teardown; custom-port instances
# rely on that teardown alone. Each kill (or failed attempt) appends one
# line to the data-dir log so the reap leaves a forensic trail instead of
# vanishing into /dev/null. Guarded by scripts/lib/wrapper_test/session_end_reap.bats.
if command -v lsof >/dev/null 2>&1; then
    for pid in $(lsof -ti tcp:7777 -sTCP:LISTEN 2>/dev/null); do
        if ps -o command= -p "$pid" 2>/dev/null | grep -Eq '(^|/)anton-core[^/ ]* dashboard( |$)'; then
            if kill "$pid" 2>/dev/null; then
                echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) reaped dashboard pid $pid (port 7777)" >>"$LOG_DIR/dashboard-reap.log" 2>/dev/null || true
            else
                echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) kill failed for dashboard pid $pid (port 7777)" >>"$LOG_DIR/dashboard-reap.log" 2>/dev/null || true
            fi
        fi
    done
fi

# Orphan sweep: reap any core-dashboard whose parent is already init (ppid==1)
# — abnormal-session-exit leftovers on a non-default port. A live session's
# dashboard has ppid=its session, never 1, so this never touches another
# session's server. Complements the in-process self-reap watchdog and is the
# only path that reaps pre-watchdog orphans.
if command -v pgrep >/dev/null 2>&1; then
    for pid in $(pgrep -f 'dashboard' 2>/dev/null); do
        ps -o command= -p "$pid" 2>/dev/null | grep -Eq '(^|/)anton-core[^/ ]* dashboard( |$)' || continue
        [ "$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')" = "1" ] || continue
        if kill "$pid" 2>/dev/null; then
            echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) reaped orphan dashboard pid $pid (ppid=1)" >>"$LOG_DIR/dashboard-reap.log" 2>/dev/null || true
        fi
    done
fi

exec "$ANTON_BIN" hook session-end "$@"
