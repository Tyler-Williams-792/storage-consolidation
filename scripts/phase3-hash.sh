#!/bin/sh
set -e

# Base directory for Staging Grounds
BASE="/mnt/mead/konasmb"

# Staging roots for each source
FIO_ROOT="${BASE}/Staging_Fio"
SALEM_ROOT="${BASE}/Staging_Salem"

# For Kona, prefer a staging copy if it exists; otherwise hash the live dataset
if [ -d "${BASE}/Staging_KonaCurrent" ]; then
    KONA_ROOT="${BASE}/Staging_KonaCurrent"
else
    KONA_ROOT="/mnt/mead/Kona"
fi

# Logs live inside the git workspace so they can be versioned if desired
OUTDIR="${BASE}/logs"
mkdir -p "$OUTDIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

hash_dir() {
    LABEL="$1"
    ROOT="$2"
    OUTFILE="${OUTDIR}/hashes_${LABEL}.tsv"

    if [ ! -d "$ROOT" ]; then
        log "SKIP: ${LABEL} root ${ROOT} does not exist; not hashing."
        return 0
    fi

    log "Starting hash catalog for ${LABEL} at ${ROOT}"
    : > "$OUTFILE"

    # Use find -print0 + xargs -0 to safely handle weird filenames
    find "$ROOT" -type f -print0 2>/dev/null | \
    xargs -0 -n1 sh -c '
        for f; do
            h=$(sha256 -q "$f" 2>/dev/null || echo "ERROR")
            [ "$h" = "ERROR" ] && continue
            printf "%s\t%s\n" "$h" "$f"
        done
    ' _ >> "$OUTFILE"

    log "Completed ${LABEL}. Output: ${OUTFILE}"
}

hash_dir "fio"   "$FIO_ROOT"
hash_dir "salem" "$SALEM_ROOT"
hash_dir "kona"  "$KONA_ROOT"

log "All hashing complete."
