#!/usr/bin/env bash
# Plugin hook: PostToolUseFailure (recall-on-error). Pipes the full payload
# (command + error + session_id) straight to the verb on stdin.
# shellcheck source=lib/wrapper.sh disable=SC1091
source "$(dirname "$0")/lib/wrapper.sh"

hook_exec_fail_open recall-on-error "$@"
