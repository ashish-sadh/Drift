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

    # Explicit cleanup on failure paths (no RETURN trap). The earlier RETURN-
    # trap version persisted globally — bash sets the trap once and it fires
    # on every subsequent function return in the calling chain, where the
    # local `tmp` is out of scope. `${tmp:-}` guard didn't help on macOS bash;
    # under `set -u` the trap still threw `tmp: unbound variable`. Cleaner
    # to just inline the rm on failure and skip the trap altogether.
    # (Watchdog was crash-looping 8x/day on this — see git log.)
    if ! printf '%s\n' "$content" > "$tmp"; then
        rm -f "$tmp"
        return 1
    fi
    sync "$tmp" 2>/dev/null || sync
    if ! mv -f "$tmp" "$target"; then
        rm -f "$tmp"
        return 1
    fi
}

# Variant that reads from stdin — for slightly larger payloads (JSON state, etc.)
atomic_write_file() {
    local target="$1"
    local tmp="${target}.tmp.$$"

    if ! cat > "$tmp"; then
        rm -f "$tmp"
        return 1
    fi
    sync "$tmp" 2>/dev/null || sync
    if ! mv -f "$tmp" "$target"; then
        rm -f "$tmp"
        return 1
    fi
}
