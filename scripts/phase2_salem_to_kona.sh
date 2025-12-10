#!/bin/sh
set -e

SALEM_HOST="192.168.1.184"     
SALEM_USER="tytrater"

STAGING_SALEM="/mnt/mead/Staging_Salem"

mkdir -p "${STAGING_SALEM}/kona"
mkdir -p "${STAGING_SALEM}/Documents"
mkdir -p "${STAGING_SALEM}/pve_backup"

echo "=== Phase 2: Pulling Salem /home/tytrater/kona ==="
rsync -avh --progress \
    ${SALEM_USER}@${SALEM_HOST}:/home/tytrater/kona/ \
    "${STAGING_SALEM}/kona/"

echo "=== Phase 2: Pulling Salem /home/tytrater/Documents ==="
rsync -avh --progress \
    ${SALEM_USER}@${SALEM_HOST}:/home/tytrater/Documents/ \
    "${STAGING_SALEM}/Documents/"

done

echo "=== Phase 2 complete: Salem data staged at ${STAGING_SALEM} ==="
