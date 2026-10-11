#!/usr/bin/env bash
# Plugin hook: SessionEnd
# shellcheck source=lib/wrapper.sh disable=SC1091
source "$(dirname "$0")/lib/wrapper.sh"

_anton_payload_args
if [[ -n "$_anton_transcript_path" ]]; then
    set -- --transcript-path "$_anton_transcript_path" "$@"
fi
if [[ -n "$_anton_session_id" ]]; then
    set -- --session-id "$_anton_session_id" "$@"
fi
hook_exec_fail_open session-end "$@"
