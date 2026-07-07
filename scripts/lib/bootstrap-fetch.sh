#!/usr/bin/env bash
# bootstrap-fetch.sh — the setup-only synchronous binary fetch.
#
# Standalone executable, NEVER sourced by a hook. This is the ONE surface that
# downloads the anton-core binary: the hook path (scripts/lib/wrapper.sh) was
# gutted per ADR 0051 (hooks answer or enqueue) and now only resolves an
# already-installed binary; scripts/core emits a precondition envelope on a
# miss; and /anton-core:setup invokes THIS script to install on a fresh box,
# then rotates the staged slot in via `core update apply-if-staged`.
#
# It fetches the matching per-platform release binary from the PUBLIC release
# repo (unauthenticated HTTPS, ADR 0037 public-distribution), verifies it
# (transport-integrity checksum always; supply-chain cosign opportunistically),
# installs it into the pin layout at data/versions/v<ver>/anton-core, and writes
# the staged-update.json prefetch record so setup's apply-if-staged can rotate
# it to `current` and write the first pin (the only pin writer).
#
# Fetch transport is unauthenticated HTTPS (`curl -fsSL`) against the PUBLIC
# release repo; no token / auth / URL-base / API-base env vars are consulted.
# Assets are fetched by their stable releases/download/v<ver>/<asset> URLs.
#
# Root resolution: a caller-provided CLAUDE_PLUGIN_DATA is normalized (a
# trailing /data segment is stripped, mirroring the Go resolver); when unset
# and the plugin root is a Claude-Code cache path, the persistent root is
# self-derived and — on a successful install — seeded into
# ~/.anton-core/config.json (only when absent), so the rest of setup needs no
# environment at all.
#
# Honors:
#   ANTON_SKIP_BOOTSTRAP — non-empty disables the fetch entirely (hermetic
#                          test hatch); exits non-zero with a clear reason.
#
# Exit 0 on success (with a success line on stdout); non-zero on any failure
# (with a machine-parseable reason on stderr).
set -euo pipefail

# ── Resolve self + plugin roots ───────────────────────────────────────────
# Standalone: derive CLAUDE_PLUGIN_ROOT from the script's own location when the
# caller did not set it (setup / Claude Code do). Script lives at
# scripts/lib/bootstrap-fetch.sh, so ../.. is the repo/plugin root.
_script_dir="$(cd "$(dirname "$0")" && pwd)"
: "${CLAUDE_PLUGIN_ROOT:=$(cd "$_script_dir/../.." && pwd)}"

# CLAUDE_PLUGIN_DATA is the persistent state root. Resolution, in order:
#   1. Caller-provided env, NORMALIZED: a trailing `data` segment is stripped —
#      the exact mirror of internal/db/paths.go::normalizeRoot, which the Go
#      binary applies to CORE_DATA_DIR. Without this, a hand-assembled
#      `<root>/data` value stages into `<root>/data/data/{versions,state}`
#      while the binary reads `<root>/data/...` — the nested-tree failure that
#      bricked the v2.1.0 field install.
#   2. Self-derived from the plugin's own cache location: skills run in the
#      Bash tool, where CLAUDE_PLUGIN_DATA is NOT in the environment (it is
#      hook-only env), so when it is unset and CLAUDE_PLUGIN_ROOT matches the
#      Claude-Code-managed shape */plugins/cache/<marketplace>/<plugin>/<ver>,
#      the persistent root is <plugins-dir>/data/<marketplace>-<plugin> (the
#      Claude Code plugin-data convention). The marketplace-clone shape
#      (*/plugins/marketplaces/*) is deliberately NOT derived — it has no
#      version segment and setup never sees it; it falls through to the
#      managed-cache refusal below.
#   3. Repo/plugin-root fallback for repo-local dev runs, matching
#      scripts/lib/wrapper.sh's default.
_derived_root="false"
if [[ -n "${CLAUDE_PLUGIN_DATA:-}" ]]; then
    if [[ "$(basename "$CLAUDE_PLUGIN_DATA")" == "data" ]]; then
        CLAUDE_PLUGIN_DATA="$(dirname "$CLAUDE_PLUGIN_DATA")"
    fi
else
    case "$CLAUDE_PLUGIN_ROOT" in
        */plugins/cache/*/*/*)
            _plugins_dir="${CLAUDE_PLUGIN_ROOT%/cache/*}"
            _cache_rel="${CLAUDE_PLUGIN_ROOT#*/plugins/cache/}"
            _mkt="${_cache_rel%%/*}"
            _rest="${_cache_rel#*/}"
            _plugin="${_rest%%/*}"
            if [[ -n "$_mkt" && -n "$_plugin" ]]; then
                CLAUDE_PLUGIN_DATA="${_plugins_dir}/data/${_mkt}-${_plugin}"
                _derived_root="true"
                printf 'bootstrap-fetch: derived persistent data root %s from the plugin cache location\n' \
                    "$CLAUDE_PLUGIN_DATA"
            else
                CLAUDE_PLUGIN_DATA="$CLAUDE_PLUGIN_ROOT"
            fi
            ;;
        *)
            CLAUDE_PLUGIN_DATA="$CLAUDE_PLUGIN_ROOT"
            ;;
    esac
fi
export CLAUDE_PLUGIN_ROOT CLAUDE_PLUGIN_DATA

_repo_slug="to-infinity-labs/anton-core-plugin"

_usage() {
    cat <<'USAGE'
Usage: bootstrap-fetch.sh [--version vX.Y.Z]

Fetches, verifies, and installs the anton-core binary into the pin layout
(data/versions/v<ver>/anton-core) and writes staged-update.json. Setup-only;
never sourced by a hook. Version defaults to the plugin manifest .version.
USAGE
}

# ── Cleanup + failure helpers ─────────────────────────────────────────────
_tmpdir=""
_lock_dir=""

# Invoked indirectly via `trap _cleanup EXIT` below, which shellcheck's
# flow analysis does not connect to the definition — so both "function never
# invoked" (SC2329) and "command unreachable" (SC2317) on the body are false
# positives here.
# shellcheck disable=SC2329,SC2317
_cleanup() {
    if [[ -n "$_tmpdir" ]]; then
        rm -rf "$_tmpdir" 2>/dev/null || true
        _tmpdir=""
    fi
    if [[ -n "$_lock_dir" ]]; then
        rmdir "$_lock_dir" 2>/dev/null || rm -rf "$_lock_dir" 2>/dev/null || true
        _lock_dir=""
    fi
}
# No `exec` on this path (unlike the sourced wrapper), so an EXIT trap is safe
# and fires on every return site — success and every _fail.
trap _cleanup EXIT

# _fail <reason> [detail] — machine-parseable reason on stderr, exit 1. The
# EXIT trap releases the lock + tmpdir. `reason` is a stable discriminator a
# caller can route on; `detail` is the human-readable cause.
_fail() {
    printf 'bootstrap-fetch: FAILED reason=%s detail=%s\n' "$1" "${2:-<none>}" >&2
    exit 1
}

# ── Manifest version reader (jq preferred, grep fallback) ─────────────────
_read_manifest_version() {
    local manifest="${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json"
    if [[ ! -f "$manifest" ]]; then
        echo ""
        return 0
    fi
    if command -v jq >/dev/null 2>&1; then
        jq -r '.version // empty' "$manifest" 2>/dev/null || true
    else
        grep -E '"version"[[:space:]]*:[[:space:]]*"[^"]+"' "$manifest" \
            | head -1 \
            | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' \
            || true
    fi
}

# ── Skip hatch ────────────────────────────────────────────────────────────
# Silent-on-skip would strand the operator; a fetch-suppressing hatch must say
# so and exit non-zero (setup surfaces it as a blocked notice).
if [[ -n "${ANTON_SKIP_BOOTSTRAP:-}" ]]; then
    _fail "skip_bootstrap" "ANTON_SKIP_BOOTSTRAP is set (hermetic-test hatch); refusing to fetch"
fi

# ── Argument parsing ──────────────────────────────────────────────────────
_arg_version=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --version=*) _arg_version="${1#*=}" ;;
        --version)
            if [[ $# -lt 2 ]]; then
                _fail "bad_args" "--version requires a value (e.g. --version v1.2.3)"
            fi
            _arg_version="$2"
            shift
            ;;
        -h|--help)
            _usage
            exit 0
            ;;
        *) _fail "bad_args" "unknown argument: $1" ;;
    esac
    shift
done

# ── Resolve + validate target version ─────────────────────────────────────
if [[ -n "$_arg_version" ]]; then
    ver="${_arg_version#v}"
else
    ver="$(_read_manifest_version)"
    ver="${ver#v}"
fi
if [[ -z "$ver" ]]; then
    _fail "missing_manifest_version" \
        "cannot determine target version (no --version arg and .claude-plugin/plugin.json missing or unreadable)"
fi
# Sanity-clamp the version before it lands in a URL and JSON. A trusted source
# (manifest / operator arg) still gets validated so a malformed value can never
# inject into the fetch URL or the staged-update.json record.
if ! [[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.]+)?$ ]]; then
    _fail "bad_version" "version '$ver' is not a X.Y.Z(-suffix) form"
fi

# ── Platform detection ────────────────────────────────────────────────────
os="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$os" in
    linux|darwin) ;;
    *) _fail "unsupported_os:$os" "unsupported OS '$os' (release pipeline ships linux + darwin only)" ;;
esac
arch="$(uname -m)"
case "$arch" in
    x86_64|amd64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) _fail "unsupported_arch:$arch" "unsupported arch '$arch' (release pipeline ships amd64 + arm64 only)" ;;
esac

# ── Refuse to install into a Claude-Code-managed cache/marketplace clone ──
# Those dirs are never pruned by Claude Code, so a binary installed there leaks
# ~55 MB per version indefinitely. Match the literal install root (no realpath
# — it may not exist yet).
_versions_root="${CLAUDE_PLUGIN_DATA}/data/versions"
case "$_versions_root" in
    */plugins/cache/*|*/plugins/marketplaces/*)
        _fail "install_dir_in_managed_cache" \
            "refusing to install into the Claude Code plugin cache/marketplace clone ($_versions_root) — that location is wiped on plugin updates, and the persistent data root could not be determined from this plugin-root shape"
        ;;
esac

# curl is required for the fetch — hard-fail early so the reason is precise.
command -v curl >/dev/null 2>&1 || _fail "curl_not_installed" \
    "curl not found on \$PATH; install curl to fetch the release binary"

dest_dir="${_versions_root}/v${ver}"
dest="${dest_dir}/anton-core"
state_dir="${CLAUDE_PLUGIN_DATA}/data/state"

# ── Bootstrap lock (mkdir mutex, BOUNDED wait) ────────────────────────────
# Concurrent setup flows (or a setup racing a manual re-run) would otherwise
# both download ~30 MB and both mv over the same slot. mkdir is atomic on every
# POSIX filesystem. This is an interactive path, so the wait is BOUNDED: 60
# attempts ~1s apart, then give up — never an unbounded wait. Stale-lock
# reclaim is PID-fenced: a waiter that finds a dead holder races to atomically
# rename the lockdir aside; exactly one waiter wins the rename and cleans up.
mkdir -p "${CLAUDE_PLUGIN_DATA}/data"
_lock_target="${CLAUDE_PLUGIN_DATA}/data/.bootstrap-fetch.lock"
_lock_attempt=0
while true; do
    # A concurrent fetch may have already installed the slot while we waited.
    if [[ -x "$dest" ]]; then
        _lock_dir=""
        printf 'bootstrap-fetch: anton-core v%s already installed by a concurrent fetch (%s/%s)\n' "$ver" "$os" "$arch"
        exit 0
    fi
    if mkdir "$_lock_target" 2>/dev/null; then
        _lock_dir="$_lock_target"
        echo "$$" > "$_lock_dir/pid"
        # Post-acquire re-check: a peer could have installed between the
        # pre-check and this mkdir.
        if [[ -x "$dest" ]]; then
            rmdir "$_lock_dir" 2>/dev/null || rm -rf "$_lock_dir" 2>/dev/null || true
            _lock_dir=""
            printf 'bootstrap-fetch: anton-core v%s already installed by a concurrent fetch (%s/%s)\n' "$ver" "$os" "$arch"
            exit 0
        fi
        break
    fi
    # Lock held. PID-fenced reclaim if the holder is gone.
    _holder_pid=""
    _holder_pid="$(cat "$_lock_target/pid" 2>/dev/null || true)"
    if [[ -n "$_holder_pid" ]] && ! kill -0 "$_holder_pid" 2>/dev/null; then
        _dead_lock="${_lock_target}.dead.$$"
        if mv "$_lock_target" "$_dead_lock" 2>/dev/null; then
            rm -rf "$_dead_lock" 2>/dev/null || true
            printf 'bootstrap-fetch: reclaimed stale lock from dead pid %s\n' "$_holder_pid" >&2
            continue
        fi
        # Lost the rename race; another waiter is reclaiming — fall through to wait.
    fi
    _lock_attempt=$((_lock_attempt + 1))
    if [[ $_lock_attempt -ge 60 ]]; then
        _fail "lock_timeout" \
            "could not acquire the bootstrap-fetch lock after 60 attempts (~60s); another install may be stuck — remove $_lock_target if no fetch is running"
    fi
    sleep 1
done

# ── Stage the download in a tmpdir ────────────────────────────────────────
_tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/anton-bootstrap-fetch.XXXXXX")"
binary_name="anton-core-v${ver}-${os}-${arch}"
bin_tmp="${_tmpdir}/${binary_name}"
checksums_tmp="${_tmpdir}/checksums.txt"
bundle_tmp="${_tmpdir}/${binary_name}.sigstore.json"

base_url="https://github.com/${_repo_slug}/releases/download/v${ver}"

# Required download — hard-fail on error. `… || dl_rc=$?` (not a bare
# `curl …; dl_rc=$?`) is required under set -e: a failing simple command would
# abort the script before the assignment.
dl_err="${_tmpdir}/curl-download.err"
dl_rc=0
curl -fsSL -o "$bin_tmp" "${base_url}/${binary_name}" 2>"$dl_err" || dl_rc=$?
if [[ $dl_rc -eq 0 ]]; then
    curl -fsSL -o "$checksums_tmp" "${base_url}/checksums.txt" 2>>"$dl_err" || dl_rc=$?
fi
if [[ $dl_rc -ne 0 ]]; then
    dl_msg=""
    if [[ -s "$dl_err" ]]; then
        dl_msg="$(head -1 "$dl_err" 2>/dev/null || true)"
    fi
    _fail "download_failed" \
        "curl failed to fetch v${ver} (curl exit ${dl_rc}): ${dl_msg:-<no stderr>}"
fi

# ── Checksum verify (transport integrity, always) ─────────────────────────
# checksums.txt is `<sha256>  <filename>`, one line per artifact.
expected_sha="$(awk -v name="$binary_name" '$2 == name { print $1; exit }' "$checksums_tmp")"
if [[ -z "$expected_sha" ]]; then
    _fail "checksum_entry_missing" \
        "checksums.txt has no entry for ${binary_name}"
fi
if command -v shasum >/dev/null 2>&1; then
    actual_sha="$(shasum -a 256 "$bin_tmp" | awk '{print $1}')"
elif command -v sha256sum >/dev/null 2>&1; then
    actual_sha="$(sha256sum "$bin_tmp" | awk '{print $1}')"
else
    # shellcheck disable=SC2016  # $PATH is literal in the user-facing message
    _fail "missing_sha256_tool" 'neither shasum nor sha256sum found on $PATH; cannot verify checksum'
fi
if [[ "$expected_sha" != "$actual_sha" ]]; then
    _fail "checksum_mismatch" \
        "checksum mismatch for ${binary_name}: expected ${expected_sha}, got ${actual_sha}"
fi

# ── Cosign verify (supply-chain, opportunistic) ───────────────────────────
# cosign absent, or the sigstore bundle 404s → checksum-only integrity, proceed
# (ADR 0037 § verification). cosign present AND it REJECTS → hard-fail.
cosign_verified="false"
if command -v cosign >/dev/null 2>&1; then
    # Best-effort bundle fetch. MUST be a separate curl call: a release missing
    # the sigstore bundle should skip supply-chain verification, not sink the
    # whole fetch — so a 404 here is tolerated (warn + proceed), whereas the
    # required binary/checksums fetch above hard-fails.
    if ! curl -fsSL -o "$bundle_tmp" "${base_url}/${binary_name}.sigstore.json" 2>/dev/null; then
        printf 'bootstrap-fetch: cosign installed but bundle fetch failed; skipping supply-chain verification\n' >&2
    elif cosign verify-blob \
            --certificate-identity-regexp '^https://github\.com/to-infinity-labs/anton-core-go/\.github/workflows/release\.yml@refs/tags/v[0-9]+\.[0-9]+\.[0-9]+.*$' \
            --certificate-oidc-issuer https://token.actions.githubusercontent.com \
            --certificate-github-workflow-trigger push \
            --bundle "$bundle_tmp" \
            "$bin_tmp" >/dev/null 2>&1; then
        cosign_verified="true"
    else
        _fail "cosign_verify_failed" \
            "cosign rejected ${binary_name} — refusing to install"
    fi
else
    printf 'bootstrap-fetch: cosign not installed; skipping supply-chain verification (checksum verified)\n' >&2
fi

# ── Install into the pin layout (chmod, atomic mv) ────────────────────────
mkdir -p "$dest_dir"
chmod +x "$bin_tmp"
mv_err=""
if ! mv_err="$(mv "$bin_tmp" "$dest" 2>&1)"; then
    _fail "install_failed" \
        "failed to move the binary into place at ${dest}: ${mv_err:-unknown error}"
fi

# ── Exec sanity probe (unwind on fail) ────────────────────────────────────
# A checksum-valid but unusable artifact (corrupt bytes, glibc-version mismatch,
# wrong-arch upload that still hashes correctly) would otherwise install and
# then crash on every hook fire. Probe `--version` and rm the install if it
# faults, so the next setup re-attempts rather than pinning a broken slot.
probe_err="${_tmpdir}/exec-probe.err"
if ! "$dest" --version >/dev/null 2>"$probe_err"; then
    probe_msg=""
    if [[ -s "$probe_err" ]]; then
        probe_msg="$(head -1 "$probe_err" 2>/dev/null || true)"
    fi
    rm -f "$dest"
    _fail "exec_probe_failed" \
        "${dest} installed but '--version' probe failed: ${probe_msg:-<no stderr>}; slot cleared"
fi

# ── Write the staged-update.json prefetch record (atomic, mode 0600) ──────
# This is "the prefetch layout — one staging contract": the exact JSON keys of
# internal/update.StagedUpdate. binary_path is RELATIVE to the data dir (matches
# the Go prefetch writer); target_version + binary_path are load-bearing
# (apply-if-staged + wrapper.sh read them). Setup then rotates it in.
mkdir -p "$state_dir"
_now_ms=$(( $(date +%s 2>/dev/null || echo 0) * 1000 ))
staged_tmp="${state_dir}/.staged-update.json.tmp.$$"
printf '{"target_version":"v%s","source_release_url":"https://github.com/%s/releases/tag/v%s","binary_path":"data/versions/v%s/anton-core","fetched_from":"bootstrap","fetched_at":%s,"checksum_verified":true,"cosign_verified":%s}\n' \
    "$ver" "$_repo_slug" "$ver" "$ver" "$_now_ms" "$cosign_verified" > "$staged_tmp"
chmod 600 "$staged_tmp"
if ! mv "$staged_tmp" "${state_dir}/staged-update.json" 2>/dev/null; then
    rm -f "$staged_tmp" 2>/dev/null || true
    _fail "staged_write_failed" \
        "installed the binary but failed to write ${state_dir}/staged-update.json"
fi

# ── Seed the operator config (self-derived root only, only-if-absent) ─────
# When the root was self-derived (no env), persist it to
# ~/.anton-core/config.json so every later binary call — `update
# apply-if-staged`, `db init`, all of Stage 1+ — resolves the same root via
# the operator-config step (internal/db/paths.go::ResolveRoot step 3, and
# scripts/core's non-authoritative read) with NO environment at all. An
# existing config is operator-owned and never touched; `core setup
# persist-data-dir` remains the owner for all later updates. Deliberately
# NOT seeded for caller-provided or dev-fallback roots — a repo checkout
# must never become the operator's persistent data root. Best-effort: a
# seed failure warns (setup's persist-data-dir step still covers it).
if [[ "$_derived_root" == "true" && -n "${HOME:-}" ]]; then
    _op_cfg_dir="${HOME}/.anton-core"
    _op_cfg="${_op_cfg_dir}/config.json"
    if [[ ! -e "$_op_cfg" ]]; then
        _cfg_tmp="${_op_cfg_dir}/.config.json.tmp.$$"
        _seed_ok="false"
        if mkdir -p "$_op_cfg_dir" 2>/dev/null; then
            if command -v jq >/dev/null 2>&1; then
                jq -n --arg root "$CLAUDE_PLUGIN_DATA" '{data_root: $root}' > "$_cfg_tmp" 2>/dev/null && _seed_ok="true"
            else
                printf '{\n  "data_root": "%s"\n}\n' "$CLAUDE_PLUGIN_DATA" > "$_cfg_tmp" 2>/dev/null && _seed_ok="true"
            fi
        fi
        if [[ "$_seed_ok" == "true" ]] \
            && chmod 600 "$_cfg_tmp" 2>/dev/null \
            && mv "$_cfg_tmp" "$_op_cfg" 2>/dev/null; then
            printf 'bootstrap-fetch: seeded %s with data_root=%s\n' "$_op_cfg" "$CLAUDE_PLUGIN_DATA"
        else
            rm -f "$_cfg_tmp" 2>/dev/null || true
            printf 'bootstrap-fetch: warning: could not seed %s; setup will persist the data root later\n' "$_op_cfg" >&2
        fi
    fi
fi

printf 'bootstrap-fetch: installed anton-core v%s (%s/%s) cosign_verified=%s\n' \
    "$ver" "$os" "$arch" "$cosign_verified"
exit 0
