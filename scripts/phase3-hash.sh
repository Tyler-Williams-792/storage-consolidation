#!/usr/local/bin/bash
set -e

# Base directory for Staging Grounds
BASE="/mnt/mead/konasmb"

# Logging
LOGDIR="${BASE}/logs"
mkdir -p "$LOGDIR"
LOGFILE="${LOGDIR}/phase3_run_$(date +%Y%m%d-%H%M%S).log"
log() {
    printf '%s\n' "$@" | tee -a "$LOGFILE"
}

# If using bash:
exec > >(tee "$LOGFILE") 2>&1

log "Phase 3 hashing script started"

# Staging roots for each source
FIO_ROOT="${BASE}/Staging_Fio"
SALEM_ROOT="${BASE}/Staging_Salem"

# For Kona, prefer a staging copy if it exists; otherwise hash the live dataset
if [ -d "${BASE}/Staging_KonaCurrent" ]; then
    KONA_ROOT="${BASE}/Staging_KonaCurrent"
else
    KONA_ROOT="/mnt/mead/Kona"
fi

# Filepath to Hashes
OUTDIR="${BASE}/hashes"
mkdir -p "$OUTDIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

hash_dir() {
    LABEL="$1"
    ROOT="$2"
    OUTFILE="${OUTDIR}/${LABEL}.tsv"

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

hash_dir "Fio"   "$FIO_ROOT"
hash_dir "Salem" "$SALEM_ROOT"
hash_dir "Kona"  "$KONA_ROOT"

log "All hashing complete."
