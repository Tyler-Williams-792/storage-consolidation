#!/bin/sh
set -e

OUTDIR="/mnt/mead/logs"
mkdir -p "$OUTDIR"

hash_dir() {
    LABEL="$1"
    ROOT="$2"
    OUTFILE="${OUTDIR}/hashes_${LABEL}.tsv"

    echo "=== Hashing ${LABEL} at ${ROOT} ==="
    : > "$OUTFILE"

    # One file at a time to keep memory low; sha256 -q prints just the hash
    find "$ROOT" -type f -print0 2>/dev/null | \
    xargs -0 -n1 sh -c '
        for f; do
            h=$(sha256 -q "$f" 2>/dev/null || echo "ERROR")
            [ "$h" = "ERROR" ] && continue
            printf "%s\t%s\n" "$h" "$f"
        done
    ' _ >> "$OUTFILE"

    echo "=== Done: ${OUTFILE} ==="
}

hash_dir "fio"   "/mnt/mead/Staging_Fio"
hash_dir "salem" "/mnt/mead/Staging_Salem"
hash_dir "kona"  "/mnt/mead/Kona"

