#!/usr/bin/env bash
# Plugin hook: PostToolUse (compress subsystem). Pipes the full payload
# (command + tool_response + session_id) straight to the verb on stdin —
# unlike SessionEnd/PreCompact this wrapper must NOT consume stdin.
# shellcheck source=lib/wrapper.sh disable=SC1091
source "$(dirname "$0")/lib/wrapper.sh"

hook_exec_fail_open post-tool-use "$@"
