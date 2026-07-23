#!/usr/bin/env bash
# Plugin hook: PreToolUse (blast-radius). Pipes the payload
# (tool_name + tool_input.file_path + session_id) straight to the verb on stdin.
# shellcheck source=lib/wrapper.sh disable=SC1091
source "$(dirname "$0")/lib/wrapper.sh"

exec "$ANTON_BIN" hook blast-radius "$@"
