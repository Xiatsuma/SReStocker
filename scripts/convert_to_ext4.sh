#!/bin/bash
set -euo pipefail

Version="2.1"

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <img_path> [destination_directory]"
    exit 1
fi

IMG_PATH="$1"
DEST_DIR="${2:-$(pwd)}"
IMG_NAME_BASE=$(basename "$IMG_PATH" .img)
NEW_IMG_NAME="$DEST_DIR/ext4_${IMG_NAME_BASE}.img"
SRC_MOUNT="$DEST_DIR/${IMG_NAME_BASE}_mount"
DST_MOUNT="$DEST_DIR/$IMG_NAME_BASE"

cleanup() {
    umount "$DST_MOUNT" 2>/dev/null || true
    umount "$SRC_MOUNT" 2>/dev/null || true
    rm -rf "$DST_MOUNT" "$SRC_MOUNT"
}
trap cleanup EXIT

if [ ! -f "$IMG_PATH" ]; then
    echo "Image not found: $IMG_PATH"
    exit 1
fi

for cmd in fuse2fs mkfs.ext4 mount umount du dd cp; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "Missing required command: $cmd"; exit 1; }
done

# Clean previous mounts
cleanup

# Create mount point
mkdir -p "$SRC_MOUNT"

# 🔥 Mount
fuse2fs "$IMG_PATH" "$SRC_MOUNT"

# Calculate size
MOUNT_SIZE=$(du -sb "$SRC_MOUNT" | awk '{print int($1 * 1.3)}')
echo "Mounted image size: ${MOUNT_SIZE} bytes"

# Create ext4 image
dd if=/dev/zero of="$NEW_IMG_NAME" bs=1 count=0 seek=$MOUNT_SIZE
mkfs.ext4 -F -b 4096 "$NEW_IMG_NAME"

# Mount new image
mkdir -p "$DST_MOUNT"
mount -o loop "$NEW_IMG_NAME" "$DST_MOUNT"

# Copy files
cp -a "$SRC_MOUNT"/. "$DST_MOUNT"/

# Cleanup mounts
# 🔥 Rename back to original name
FINAL_IMG="$DEST_DIR/${IMG_NAME_BASE}.img"
rm -f "$FINAL_IMG"
mv "$NEW_IMG_NAME" "$FINAL_IMG"
