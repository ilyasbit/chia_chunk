#!/bin/bash
file=$1
log_path=$HOME/worker/log/mount
mkdir /storj-bucket
mkdir -p $log_path

while true; do
  umount -l /storj-bucket/* 2>/dev/null
  if [[ "$(mount | grep 'storj-bucket' | wc -l)" -eq 0 ]]; then
    echo "All mountpoints unmounted"
    break
  fi
  sleep 5
done

for remote in $(rclone listremotes --config $file | grep "^UNION"); do
  remotename=$(echo $remote | cut -d ":" -f1)
  mountpoint="/storj-bucket/${remotename}"
  echo "--- Mounting $remotename on $mountpoint ---"
  mkdir -p $mountpoint
  rclone mount $remotename: $mountpoint \
    --allow-other \
    --vfs-read-chunk-size 64K \
    --buffer-size 0 \
    --vfs-read-wait 1ms \
    --max-read-ahead 0 \
    --vfs-cache-mode full \
    --vfs-cache-max-size 50M \
    --no-checksum \
    --no-modtime \
    --read-only \
    --use-mmap \
    --no-check-certificate \
    --vfs-cache-max-age 1h \
    --log-level INFO \
    --log-file ${log_path}/${remotename}.log \
    --timeout 1h \
    --config $file \
    --user-agent s3cli &
  sleep 5
done
