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
STATS_LOG="${LOG_DIR}/archive_stats_${RUN_DATE}.log"

# Return size in bytes for a file or directory (Linux and FreeBSD compatible)
get_size_bytes() {
  local path="$1"

  if du -sb "$path" >/dev/null 2>&1; then
    # GNU/Linux style
    du -sb "$path" | awk '{print $1}'
  else
    # BSD/FreeBSD: use KiB and convert to bytes
    du -sk "$path" | awk '{print $1 * 1024}'
  fi
}

get_file_bytes() {
  local path="$1"

  if stat -c '%s' "$path" >/dev/null 2>&1; then
    # GNU stat
    stat -c '%s' "$path"
  else
    # BSD/FreeBSD stat
    stat -f '%z' "$path"
  fi
}


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

# Size of the archive root before compression
ORIG_SIZE_BYTES=$(get_size_bytes "${ARCHIVE_ROOT}")
ORIG_SIZE_HUMAN=$(du -sh "${ARCHIVE_ROOT}" | awk '{print $1}')

echo "Source directory: ${ARCHIVE_ROOT}"
echo "Original size: ${ORIG_SIZE_HUMAN} (${ORIG_SIZE_BYTES} bytes)"

# Use this size to give pv a total for progress/ETA
ARCHIVE_SIZE="${ORIG_SIZE_BYTES}"

# Time just the compression step
COMP_START=$(date +%s)

tar -C "${ARCHIVE_ROOT}" -cf - . \
  | pv -pterb "${ARCHIVE_SIZE}" \
  | zstd -T0 -15 -o "${TAR_OUTPUT}"


COMP_END=$(date +%s)
COMP_DURATION=$((COMP_END - COMP_START))

# Size of compressed archive
COMP_SIZE_BYTES=$(get_file_bytes "${TAR_OUTPUT}")
COMP_SIZE_HUMAN=$(du -sh "${TAR_OUTPUT}" | awk '{print $1}')

# Compute compression ratio (original / compressed)
if [ "${COMP_SIZE_BYTES}" -gt 0 ] 2>/dev/null; then
  COMPRESSION_RATIO=$(awk -v orig="${ORIG_SIZE_BYTES}" -v comp="${COMP_SIZE_BYTES}" 'BEGIN { printf "%.2f", orig / comp }')
else
  COMPRESSION_RATIO="N/A"
fi

echo "Archive created: ${TAR_OUTPUT}"
echo "Compressed size: ${COMP_SIZE_HUMAN} (${COMP_SIZE_BYTES} bytes)"
echo "Compression time: ${COMP_DURATION} seconds"
echo "Compression ratio (original / compressed): ${COMPRESSION_RATIO}:1"
echo "You can later restore from ${ARCHIVE_LOG} if needed."

# Log the stats to a dedicated stats log as well
{
  echo "===== Archive run ${RUN_DATE} ====="
  echo "Source directory: ${ARCHIVE_ROOT}"
  echo "Original size: ${ORIG_SIZE_HUMAN} (${ORIG_SIZE_BYTES} bytes)"
  echo "Archive file: ${TAR_OUTPUT}"
  echo "Compressed size: ${COMP_SIZE_HUMAN} (${COMP_SIZE_BYTES} bytes)"
  echo "Compression level: zstd -15"
  echo "Compression time (s): ${COMP_DURATION}"
  echo "Compression ratio (orig/comp): ${COMPRESSION_RATIO}:1"
  echo
} >> "${STATS_LOG}"
