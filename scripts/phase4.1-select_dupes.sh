#!/usr/local/bin/bash
set -euo pipefail

# Input: duplicates.tsv (hash \t path1 \t path2 ...)
DUPES_FILE="duplicates.tsv"

# Substring that identifies the "golden" copy
# Adjust this if the exact path is a little different
KEEP_SUBSTRING="/Kona/SynologyDrive/"

KEEP_LIST="keep_paths.txt"
DELETE_LIST="delete_paths.txt"

# Truncate/initialize output files
: > "$KEEP_LIST"
: > "$DELETE_LIST"

awk -F '\t' -v keep_sub="$KEEP_SUBSTRING" \
    -v keep_out="$KEEP_LIST" \
    -v del_out="$DELETE_LIST" '
    # Need at least: hash + 2 files to be considered a duplicate group
    NF < 3 { next }

    {
        hash = $1

        # Find the preferred file (one under Kona/SynologyDrive)
        keep_idx = -1
        for (i = 2; i <= NF; i++) {
            if (index($i, keep_sub) > 0) {
                keep_idx = i
                break
            }
        }

        # If no Kona/SynologyDrive match, just keep the first file in the group
        if (keep_idx == -1) {
            keep_idx = 2
        }

        # Record the keep path
        print $keep_idx >> keep_out

        # Everything else in the group is marked for deletion
        for (i = 2; i <= NF; i++) {
            if (i == keep_idx) {
                continue
            }
            print $i >> del_out
        }
    }
' "$DUPES_FILE"
