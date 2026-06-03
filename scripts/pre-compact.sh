#!/usr/bin/env bash
# Plugin hook: PreCompact
# shellcheck source=lib/wrapper.sh disable=SC1091
source "$(dirname "$0")/lib/wrapper.sh"

_extract_session_id
if [[ -n "$SESSION_ID" ]]; then
    set -- --session-id "$SESSION_ID" "$@"
fi
exec "$ANTON_BIN" hook pre-compact "$@"
