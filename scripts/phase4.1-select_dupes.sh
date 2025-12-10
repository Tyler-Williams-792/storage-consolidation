#!/usr/local/bin/bash
set -euo pipefail

DUPES_FILE="logs/duplicates_20251210_132452.tsv"

# Root identifier for the "golden" area
KEEP_ROOT="/mnt/mead/Kona/SynologyDrive/"

KEEP_LIST="outputs/keep_paths.txt"
DELETE_LIST="outputs/delete_paths.txt"

# Truncate/initialize output files
: > "$KEEP_LIST"
: > "$DELETE_LIST"

awk -v keep_root="$KEEP_ROOT" \
    -v keep_out="$KEEP_LIST" \
    -v del_out="$DELETE_LIST" '
    # Determine priority score for a given path:
    # 3 = SynologyDrive main (non-backup)
    # 2 = SynologyDrive backup-ish (Backup/Backups in path)
    # 1 = everything else
    function path_score(p,    lower, score) {
        lower = tolower(p)
        score = 1

        if (index(p, keep_root) > 0) {
            # It is under SynologyDrive
            score = 2   # baseline for SynologyDrive
            # If it contains backup-ish patterns, treat as backup-tier
            if (index(lower, "backup") == 0 && index(lower, "backups") == 0) {
                # No "backup" substrings: treat as main copy
                score = 3
            }
        }

        return score
    }

    # Process a finished group of paths
    function process_group(    best_idx, best_score, s, i) {
        if (path_count < 2) {
            # Not actually duplicates, ignore
            return
        }

        group_count++

        best_idx = 1
        best_score = path_score(paths[1])

        for (i = 2; i <= path_count; i++) {
            s = path_score(paths[i])
            if (s > best_score) {
                best_score = s
                best_idx = i
            }
        }

        # Keep the best-scoring path
        print paths[best_idx] >> keep_out
        kept_total++

        # Others are delete candidates
        for (i = 1; i <= path_count; i++) {
            if (i == best_idx) continue
            print paths[i] >> del_out
            deleted_total++
        }
    }

    {
        sub(/\r$/, "", $0)  # strip CR if present
    }

    # Group header line: "HASH: <hashvalue>"
    /^HASH:/ {
        if (current_hash != "") {
            process_group()
        }

        current_hash = $0
        gsub(/^HASH:[[:space:]]*/, "", current_hash)

        delete paths
        path_count = 0
        next
    }

    # Skip blank lines
    /^[[:space:]]*$/ { next }

    # Any non-HASH, non-empty line is a path
    {
        path_count++
        paths[path_count] = $0
    }

    END {
        if (current_hash != "") {
            process_group()
        }

        printf("Duplicate groups processed: %d\n", group_count) > "/dev/stderr"
        printf("Total kept: %d\n", kept_total) > "/dev/stderr"
        printf("Total delete candidates: %d\n", deleted_total) > "/dev/stderr"
    }
' "$DUPES_FILE"
