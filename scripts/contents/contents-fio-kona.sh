{
# Top level
  echo "===== LS TOP LEVEL ====="
  ls -lha /run/media/fioregatto/HDD/kona

  echo
 # Two-level map
  echo "===== TREE LEVEL 2 ====="
  tree -L 2 /run/media/fioregatto/HDD/kona 2>/dev/null

  echo
 # Optional (if tree is slow)
  echo "===== DIRECTORY LISTING (FIND) ====="
  find /run/media/fioregatto/HDD/kona -maxdepth 2 -type d 2>/dev/null

} > ~/contents-fio-kona.txt

