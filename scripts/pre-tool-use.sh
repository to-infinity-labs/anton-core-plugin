#!/usr/bin/env bash
# Plugin hook: PreToolUse (blast-radius). Advisory instrumentation ONLY — it must
# NEVER block an Edit/Write. The pin decouples the running binary from Claude
# Code's /plugin update cadence (wrapper.sh binary-resolution header), so a
# pinned binary that predates the blast-radius verb is a SUPPORTED state: its
# `unknown command` error (exit 2) must fail OPEN, not gate the edit. Run the
# verb best-effort, forward its advisory output only on success (so a lagging
# binary's error envelope is never surfaced as a PreToolUse decision), and always
# exit 0 — the non-blocking-hooks contract (docs/plugin-spec/08-hooks.md).
# shellcheck source=lib/wrapper.sh disable=SC1091
source "$(dirname "$0")/lib/wrapper.sh"

hook_exec_fail_open blast-radius "$@"
