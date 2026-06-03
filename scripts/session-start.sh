#!/usr/bin/env bash
# Plugin hook: SessionStart
# shellcheck source=lib/wrapper.sh disable=SC1091
source "$(dirname "$0")/lib/wrapper.sh"

# Foreground apply-if-staged; budget-bounded so SessionStart never hangs.
# Stderr is tee'd to a data-dir log so apply failures don't pollute Claude
# Code's console.
LOG_DIR="${CLAUDE_PLUGIN_DATA:-/tmp}/data/logs"
mkdir -p "$LOG_DIR" 2>/dev/null || true
"$ANTON_BIN" update apply-if-staged --quiet --budget 10s 1>/dev/null 2>>"$LOG_DIR/update.err" || true

exec "$ANTON_BIN" hook session-start "$@"
