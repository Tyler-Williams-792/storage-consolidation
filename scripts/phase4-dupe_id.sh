#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/phase4-dupe_id.sh hashes/Fio.tsv hashes/Salem.tsv hashes/Kona.tsv

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <tsv-file> [tsv-file ...]"
    exit 1
fi

TMPDIR=$(mktemp -d)
COMBINED="$TMPDIR/all_hashes.tsv"

# Combine all TSVs into a single file
cat /mnt/mead/konasmb/hashes > "$COMBINED"

# Sort by hash (first column) for grouping
sort -k1,1 "$COMBINED" > "$COMBINED.sorted"

# Output file for found duplicates
OUT="logs/duplicates_$(date +%Y%m%d_%H%M%S).tsv"

# Find all hashes that appear more than once
awk -F'\t' '
{
    hash=$1
    files[hash]=files[hash] ? files[hash] ORS $2 : $2
    count[hash]++
}
END {
    for (h in count) {
        if (count[h] > 1) {
            printf("HASH: %s\n", h) >> "'"$OUT"'"
            print files[h] >> "'"$OUT"'"
            printf("\n") >> "'"$OUT"'"
        }
    }
}' "$COMBINED.sorted"

echo "Duplicate scan complete."
echo "Results written to: $OUT"
