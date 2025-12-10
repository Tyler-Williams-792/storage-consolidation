#!/usr/bin/env bash
set -euo pipefail

# CONFIG
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${PROJECT_ROOT}/logs"
DELETE_LIST="${LOG_DIR}/delete_paths.txt"

# Archive lives under Kona, dated so you can run this multiple times safely
RUN_DATE="$(date +%Y%m%d_%H%M%S)"
ARCHIVE_ROOT="/mnt/mead/Kona/_Dedup_Archive/${RUN_DATE}"

ARCHIVE_LOG="${LOG_DIR}/archive_moves_${RUN_DATE}.tsv"
ARCHIVE_FAIL_LOG="${LOG_DIR}/archive_failures_${RUN_DATE}.log"
TAR_OUTPUT="/mnt/mead/Kona/_Dedup_Archive/duplicates_${RUN_DATE}.tar.zst"

mkdir -p "${ARCHIVE_ROOT}"
mkdir -p "${LOG_DIR}"

if [[ ! -f "${DELETE_LIST}" ]]; then
  echo "ERROR: Cannot find ${DELETE_LIST}. Run Phase 4.2 first."
  exit 1
fi

echo "Archiving duplicates listed in ${DELETE_LIST}"
echo -e "original_path\tarchived_path" > "${ARCHIVE_LOG}"
: > "${ARCHIVE_FAIL_LOG}"

# Move each duplicate into the archive, preserving full original path as a suffix
# e.g. /mnt/mead/Fio/...  →  /mnt/mead/Kona/_Dedup_Archive/20251210_.../mnt/mead/Fio/...
while IFS= read -r src; do
  # skip blank lines
  [[ -z "${src}" ]] && continue

  if [[ ! -e "${src}" ]]; then
    echo "WARN: Source does not exist, skipping: ${src}" | tee -a "${ARCHIVE_FAIL_LOG}"
    continue
  fi

  dest="${ARCHIVE_ROOT}${src}"
  dest_dir="$(dirname "${dest}")"

  mkdir -p "${dest_dir}"

  if mv -v -- "${src}" "${dest}"; then
    echo -e "${src}\t${dest}" >> "${ARCHIVE_LOG}"
  else
    echo "ERROR: Failed to move ${src} → ${dest}" | tee -a "${ARCHIVE_FAIL_LOG}"
  fi
done < "${DELETE_LIST}"

echo "Creating compressed archive at ${TAR_OUTPUT} (this may take a while)..."

# Compress the entire ARCHIVE_ROOT directory contents
# -C ensures archive paths start from ARCHIVE_ROOT's contents, not full paths.
tar -C "${ARCHIVE_ROOT}" -cf - . | zstd -T0 -o "${TAR_OUTPUT}"

echo "Archive created: ${TAR_OUTPUT}"
echo "You can later restore from ${ARCHIVE_LOG} if needed."
