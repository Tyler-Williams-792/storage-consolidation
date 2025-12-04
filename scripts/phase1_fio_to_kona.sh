#!/bin/sh
set -e

# Adjust host/IP + username if needed
FIO_HOST=192.168.1.151
FIO_USER="fioregatto"
FIO_PATH="/run/media/fioregatto/HDD/kona"

STAGING_FIO="/mnt/mead/Staging_Fio"

mkdir -p "$STAGING_FIO"

echo "=== Phase 1: Pulling Fio historical data ==="
rsync -avhP --partial --append-verify \
    --log-file=/mnt/mead/logs/rsync_fio_phase1.log \
    ${FIO_USER}@${FIO_HOST}:"${FIO_PATH}/" \
    "${STAGING_FIO}/"

echo "=== Phase 1 complete: Fio data staged at ${STAGING_FIO} ==="
