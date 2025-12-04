{
  echo "===== ZPOOL STATUS ====="
  zpool status

  echo
  echo "===== ZFS DATASETS ====="
  zfs list -r -o name,used,avail,mountpoint

  echo
  echo "===== DISK USAGE (TOP LEVEL) ====="
  df -h

  echo
  echo "===== KONA TOP LEVEL LS ====="
  ls -lha ~ || echo "/mnt/kona not found"

  echo
  echo "===== KONA DIR STRUCTURE (DEPTH 2) ====="
  # All dirs within 2 levels
  find ~ -maxdepth 2 -mindepth 1 -type d 2>/dev/null | sort

} > contents-kona.txt
