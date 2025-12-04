echo "===== ZPOOL STATUS ====="
sudo zpool status

echo
echo "===== ZFS DATASETS ====="
sudo zfs list -r -o name,used,avail,mountpoint

echo
echo "===== DISK USAGE (TOP LEVEL) ====="
df -h

echo
echo "===== TREE (2 LEVELS) ====="
for m in $(zfs list -H -o mountpoint | grep '^/'); do
    echo "---- $m ----"
    tree -L 2 "$m" 2>/dev/null || echo "(no tree available)"
    echo
done

echo
echo "===== NEWEST 20 FILES ====="
find / -type f -printf "%TY-%Tm-%Td %TH:%TM %p\n" 2>/dev/null \
    | sort -r | head -n 20


