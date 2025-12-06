#!/usr/local/bin/bash
set -euo pipefail

BASE="/mnt/mead/konasmb"
cd "${BASE}"
LABEL="$1"                

# Data directory: /mnt/mead/konasmb/Staging_Fio
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

echo "[INFO] Hashing missing files and appending to ${HASHFILE}"
while IFS= read -r f; do
    [ -f "$f" ] || continue
    h=$(sha256 -q "$f" 2>/dev/null || echo "ERROR")
    [ "$h" = "ERROR" ] && continue
    printf "%s\t%s\n" "$h" "$f"
done < "${MISSING}" >> "${HASHFILE}"

echo "[INFO] Completed rehash for: ${LABEL}"
