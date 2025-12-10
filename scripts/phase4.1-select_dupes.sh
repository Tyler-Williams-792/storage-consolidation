#!/usr/local/bin/bash
set -euo pipefail

# Input: duplicates.tsv (hash \t path1 \t path2 ...)
DUPES_FILE="logs/duplicates_20251210_122930.tsv"

# Substring that identifies the "golden" copy
# Adjust this if the exact path is a little different
KEEP_SUBSTRING="/mnt/mead/Kona/SynologyDrive/"

KEEP_LIST="outputs/keep_paths.txt"
DELETE_LIST="outputs/delete_paths.txt"

# Truncate/initialize output files
: > "$KEEP_LIST"
: > "$DELETE_LIST"

awk -v keep_sub="$KEEP_SUBSTRING" \
    -v keep_out="$KEEP_LIST" \
    -v del_out="$DELETE_LIST" '
    # Called when we are done collecting a group for a given hash
    function process_group(    keep_idx, i) {
        if (path_count < 2) {
            # Not actually duplicates, nothing to do
            return
        }

        group_count++

        # Look for a preferred path that lives under Kona/SynologyDrive
        keep_idx = -1
        for (i = 1; i <= path_count; i++) {
            if (index(paths[i], keep_sub) > 0) {
                keep_idx = i
                break
            }
        }

        # If no preferred path, just keep the first
        if (keep_idx == -1) {
            keep_idx = 1
        }

        # Record the keep path
        print paths[keep_idx] >> keep_out
        kept_total++

        # Record all others as delete candidates
        for (i = 1; i <= path_count; i++) {
            if (i == keep_idx) continue
            print paths[i] >> del_out
            deleted_total++
        }
    }

    {
        # Strip trailing CRLF if any
        sub(/\r$/, "", $0)
    }

    # New group header: "HASH: <hashvalue>"
    /^HASH:/ {
        # If we were already in a group, process the previous one
        if (current_hash != "") {
            process_group()
        }

        # Start a new group
        current_hash = $0
        gsub(/^HASH:[[:space:]]*/, "", current_hash)

        # Reset path store for this hash
        delete paths
        path_count = 0

        next
    }

    # Skip empty lines
    /^[[:space:]]*$/ { next }

    # Any non-HASH, non-empty line is a path for the current hash
    {
        path_count++
        paths[path_count] = $0
    }

    END {
        # Process the last group at EOF
        if (current_hash != "") {
            process_group()
        }

        # Progress summary
        printf("Duplicate groups processed: %d\n", group_count) > "/dev/stderr"
        printf("Total kept: %d\n", kept_total) > "/dev/stderr"
        printf("Total delete candidates: %d\n", deleted_total) > "/dev/stderr"
    }
' "$DUPES_FILE"
