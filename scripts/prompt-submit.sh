#!/usr/bin/env bash
# Plugin hook: UserPromptSubmit
# shellcheck source=lib/wrapper.sh disable=SC1091
source "$(dirname "$0")/lib/wrapper.sh"
exec "$ANTON_BIN" hook nudge "$@"
