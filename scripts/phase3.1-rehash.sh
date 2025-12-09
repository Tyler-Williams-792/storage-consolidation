#!/usr/local/bin/bash
set -euo pipefail

BASE="/mnt/mead/konasmb"
cd "${BASE}"

LABEL="$1"                       # e.g. Fio
JOBS="${2:-$(sysctl -n hw.ncpu 2>/dev/null || echo 4)}"

ROOT="${BASE}/Staging_${LABEL}"

ALL="/tmp/${LABEL}_all.txt"
HASHED="/tmp/${LABEL}_hashed.txt"
MISSING="/tmp/${LABEL}_missing.txt"

HASHFILE="hashes/${LABEL}.tsv"

echo "[INFO] Building file list for: ${ROOT}"
find "${ROOT}" -type f | sort > "${ALL}"

echo "[INFO] Extracting list of previously hashed files (if any)"
if [ -f "${HASHFILE}" ]; then
    cut -f2 "${HASHFILE}" | sort > "${HASHED}"
else
    : > "${HASHED}"  # create empty list
fi

echo "[INFO] Determining missing files"
comm -23 "${ALL}" "${HASHED}" > "${MISSING}"

if [ ! -s "${MISSING}" ]; then
    echo "[INFO] No missing files to hash. Nothing to do."
    exit 0
fi

echo "[INFO] Hashing missing files in parallel (${JOBS} jobs) and appending to ${HASHFILE}"

# xargs runs multiple bash subshells in parallel; xargs itself is the *only*
# writer to ${HASHFILE}, so the TSV won't get corrupted, even if the line order
# is non-deterministic (which we don't care about).
cat "${MISSING}" | xargs -P "${JOBS}" -I{} bash -c '
    f="$1"
    [ -f "$f" ] || exit 0
    h=$(sha256 -q "$f" 2>/dev/null || echo "ERROR")
    [ "$h" = "ERROR" ] && exit 0
    printf "%s\t%s\n" "$h" "$f"
' _ "{}" >> "${HASHFILE}"

echo "[INFO] Completed rehash for: ${LABEL} (parallel=${JOBS})"
