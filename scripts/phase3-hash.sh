#!/usr/local/bin/bash
set -euo pipefail

###############################################################################
# Phase 3 Hashing / Rehashing Script (Full + Incremental, Parallel, Safe)
#
# Usage:
#   ./phase3-hash.sh [--full|--incremental] [--jobs N] [LABEL ...]
#
# Examples:
#   # Incremental (default) for Fio, Salem, Kona
#   ./phase3-hash.sh
#
#   # Incremental rehash just Fio with auto CPU job count
#   ./phase3-hash.sh Fio
#
#   # Full rebuild of all catalogs with 14 parallel workers
#   ./phase3-hash.sh --full --jobs 14
#
#   # Full rebuild of Fio only
#   ./phase3-hash.sh --full Fio
#
# Notes:
#   - Uses sha256 -q and outputs "HASH<TAB>PATH"
#   - Handles weird characters (quotes, spaces, etc.) safely via -print0/-0
#   - Does NOT handle filenames containing literal newlines (same as comm).
###############################################################################

BASE="/mnt/mead/konasmb"
cd "${BASE}"

# ---------------------------------------------------------------------------
# Logging setup
# ---------------------------------------------------------------------------
LOGDIR="${BASE}/logs"
mkdir -p "${LOGDIR}"
LOGFILE="${LOGDIR}/phase3_run_$(date +%Y%m%d-%H%M%S).log"

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "${LOGFILE}"
}

# Mirror all stdout/stderr into the log as well
exec > >(tee -a "${LOGFILE}") 2>&1

log "Phase 3 hashing script started"

# ---------------------------------------------------------------------------
# Defaults and CLI parsing
# ---------------------------------------------------------------------------
MODE="incremental"   # or "full"
JOBS="$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"

usage() {
    cat <<EOF
Usage: $0 [--full|--incremental] [--jobs N] [LABEL ...]

Modes:
  --incremental  Only hash files that are not yet in hashes/LABEL.tsv (default)
  --full         Rebuild hashes/LABEL.tsv from scratch

Options:
  --jobs N       Number of parallel workers (default: hw.ncpu or 4)
  --help, -h     Show this help

Labels:
  If no LABELs are provided, defaults to: Fio Salem Kona
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --full)
            MODE="full"
            shift
            ;;
        --incremental)
            MODE="incremental"
            shift
            ;;
        --mode)
            MODE="$2"
            shift 2
            ;;
        --jobs)
            JOBS="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            # First non-flag arg: treat as a label and stop parsing flags
            break
            ;;
    esac
done

# Remaining args, if any, are labels
if [ $# -gt 0 ]; then
    LABELS=("$@")
else
    # Default labels
    LABELS=("Fio" "Salem" "Kona")
fi

# ---------------------------------------------------------------------------
# Hash directory
# ---------------------------------------------------------------------------
OUTDIR="${BASE}/hashes"
mkdir -p "${OUTDIR}"

# ---------------------------------------------------------------------------
# Root resolution per label (handles Kona specially)
# ---------------------------------------------------------------------------
get_root_for_label() {
    local label="$1"
    case "${label}" in
        Fio)
            echo "${BASE}/Staging_Fio"
            ;;
        Salem)
            echo "${BASE}/Staging_Salem"
            ;;
        Kona)
            # Prefer staging copy if available
            if [ -d "${BASE}/Staging_KonaCurrent" ]; then
                echo "${BASE}/Staging_KonaCurrent"
            elif [ -d "/mnt/mead/Kona" ]; then
                echo "/mnt/mead/Kona"
            else
                echo ""
            fi
            ;;
        *)
            # Generic fallback: Staging_<Label>
            if [ -d "${BASE}/Staging_${label}" ]; then
                echo "${BASE}/Staging_${label}"
            else
                echo ""
            fi
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Full rebuild hashing for one label (filename-safe)
# ---------------------------------------------------------------------------
full_hash_label() {
    local label="$1"
    local root="$2"
    local outfile="${OUTDIR}/${label}.tsv"

    if [ ! -d "${root}" ]; then
        log "SKIP: ${label} root ${root} does not exist; not hashing."
        return 0
    fi

    log "FULL: Rebuilding hash catalog for ${label} at ${root} (jobs=${JOBS})"
    : > "${outfile}"

    # Use -print0 / -0 and bash -c with "$@" to handle quotes/spaces safely
    find "${root}" -type f -print0 | \
    xargs -0 -P "${JOBS}" bash -c '
        for f in "$@"; do
            [ -f "$f" ] || continue
            h=$(sha256 -q "$f" 2>/dev/null || echo "ERROR")
            [ "$h" = "ERROR" ] && continue
            printf "%s\t%s\n" "$h" "$f"
        done
    ' _ >> "${outfile}"

    log "FULL: Completed ${label}. Output: ${outfile}"
}

# ---------------------------------------------------------------------------
# Incremental hashing for one label (append only missing paths)
# ---------------------------------------------------------------------------
incremental_hash_label() {
    local label="$1"
    local root="$2"
    local hashfile="${OUTDIR}/${label}.tsv"

    if [ ! -d "${root}" ]; then
        log "SKIP: ${label} root ${root} does not exist; not hashing."
        return 0
    fi

    local ALL="/tmp/${label}_all.txt"
    local HASHED="/tmp/${label}_hashed.txt"
    local MISSING="/tmp/${label}_missing.txt"

    log "INC: Building file list for ${label} from ${root}"
    find "${root}" -type f | sort > "${ALL}"

    log "INC: Extracting already hashed paths for ${label}"
    if [ -f "${hashfile}" ]; then
        # TSV format: HASH<TAB>PATH
        cut -f2 "${hashfile}" | sort > "${HASHED}"
    else
        : > "${HASHED}"  # empty sentinel file
    fi

    log "INC: Determining missing files for ${label}"
    comm -23 "${ALL}" "${HASHED}" > "${MISSING}"

    if [ ! -s "${MISSING}" ]; then
        log "INC: No missing files to hash for ${label}. Nothing to do."
        return 0
    fi

    log "INC: Hashing missing files for ${label} in parallel (jobs=${JOBS}) and appending to ${hashfile}"

    # Convert newline-delimited paths in MISSING to null-delimited, then use
    # xargs -0 + bash -c 'for f in "$@"; ...' to avoid quote issues.
    tr '\n' '\0' < "${MISSING}" | \
    xargs -0 -P "${JOBS}" bash -c '
        for f in "$@"; do
            [ -f "$f" ] || continue
            h=$(sha256 -q "$f" 2>/dev/null || echo "ERROR")
            [ "$h" = "ERROR" ] && continue
            printf "%s\t%s\n" "$h" "$f"
        done
    ' _ >> "${hashfile}"

    log "INC: Completed incremental hash update for ${label}"
}

# ---------------------------------------------------------------------------
# Main label loop
# ---------------------------------------------------------------------------
log "Mode: ${MODE}, Jobs: ${JOBS}, Labels: ${LABELS[*]}"

for label in "${LABELS[@]}"; do
    root="$(get_root_for_label "${label}")"
    if [ -z "${root}" ]; then
        log "SKIP: No valid root found for label ${label}"
        continue
    fi

    case "${MODE}" in
        full)
            full_hash_label "${label}" "${root}"
            ;;
        incremental)
            incremental_hash_label "${label}" "${root}"
            ;;
        *)
            log "ERROR: Unknown mode '${MODE}'"
            exit 1
            ;;
    esac
done

log "All hashing complete."
