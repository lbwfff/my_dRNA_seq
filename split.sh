#!/bin/bash

SOURCE_DIR="./"
BATCH_SIZE=40000
DEST_DIR="compressed_batches"
FILE_COUNT=0
BATCH_COUNT=1

mkdir -p "$DEST_DIR"

find "$SOURCE_DIR" -type f | while read -r FILE
do

  BATCH_DIR="${DEST_DIR}/batch_${BATCH_COUNT}"

  mkdir -p "$BATCH_DIR"

  cp "$FILE" "$BATCH_DIR"
  
  FILE_COUNT=$((FILE_COUNT + 1))
  
  if [[ "$FILE_COUNT" -ge "$BATCH_SIZE" ]]; then
    tar -czf "${DEST_DIR}/batch_${BATCH_COUNT}.tar.gz" -C "$BATCH_DIR" .
    rm -rf "$BATCH_DIR"  
    FILE_COUNT=0
    BATCH_COUNT=$((BATCH_COUNT + 1))
  fi
done

if [[ "$FILE_COUNT" -gt 0 ]]; then  #最后一个批次出了一些问题，没太明白最后一段的运行逻辑，写得很奇怪，有时间再优化吧
  tar -czf "${DEST_DIR}/batch_${BATCH_COUNT}.tar.gz" -C "$BATCH_DIR" .
  rm -rf "$BATCH_DIR"
fi

echo "ALL DONE!"
