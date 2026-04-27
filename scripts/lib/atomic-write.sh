#!/bin/bash
# Atomic state-file writes.
#
# Source this from other scripts:
#   source "$(dirname "$0")/lib/atomic-write.sh"
#   atomic_write "$HOME/drift-state/last-review-cycle" "$CYCLE"
#
# Why: a non-atomic `echo "$VAL" > "$FILE"` can leave a half-written file if
# the script crashes mid-write or the system loses power. The harness's small
# control files (drift-control.txt, last-review-cycle, etc.) need to either
# show the old value or the new value, never an empty/partial blob.
#
# Pattern (gstack-style): write to <path>.tmp.<pid>, sync, rename. Rename is
# atomic when source and destination are on the same filesystem, which they
# always are for state under $HOME.
#
# Limitations:
# - Works for small (<8KB) string content. For large blobs, use the
#   `atomic_write_file` variant (reads from stdin).
# - Caller is responsible for the directory existing.
# - Returns non-zero on failure; intermediate tmp file is removed on failure.

set -uo pipefail

atomic_write() {
    local target="$1"
    local content="$2"
    local tmp="${target}.tmp.$$"

    # Trap to clean up tmp on any failure path (caller's set -e or our own).
    # Guard with `${tmp:-}` so the trap doesn't fire `tmp: unbound variable`
    # under `set -u` when the calling function exits via RETURN before `local
    # tmp=...` ran (or at the moment the local scope is being torn down on
    # macOS bash). Watchdog was crash-looping 8x/day on this — see git log.
    trap 'rm -f "${tmp:-}"' RETURN

    # Print the content with a trailing newline (matches `echo > file` semantics).
    printf '%s\n' "$content" > "$tmp" || return 1

    # fsync the tmp file so its bytes are durable before the rename. macOS sync
    # is filesystem-wide, which is overkill but cheap for the small files we
    # write. On Linux, `sync "$tmp"` would target just that fd.
    sync "$tmp" 2>/dev/null || sync

    # Atomic rename; replaces target if it existed.
    mv -f "$tmp" "$target" || return 1
}

# Variant that reads from stdin — for slightly larger payloads (JSON state, etc.)
atomic_write_file() {
    local target="$1"
    local tmp="${target}.tmp.$$"

    # Guard with `${tmp:-}` so the trap doesn't fire `tmp: unbound variable`
    # under `set -u` when the calling function exits via RETURN before `local
    # tmp=...` ran (or at the moment the local scope is being torn down on
    # macOS bash). Watchdog was crash-looping 8x/day on this — see git log.
    trap 'rm -f "${tmp:-}"' RETURN

    cat > "$tmp" || return 1
    sync "$tmp" 2>/dev/null || sync
    mv -f "$tmp" "$target" || return 1
}
