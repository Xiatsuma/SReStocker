#!/bin/bash

Version="2.1"

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <img_path> [destination_directory]"
    exit 1
fi

IMG_PATH="$1"
DEST_DIR="${2:-$(pwd)}"
IMG_NAME_BASE=$(basename "$IMG_PATH" .img)
NEW_IMG_NAME="$DEST_DIR/ext4_${IMG_NAME_BASE}.img"

if [ ! -f "$IMG_PATH" ]; then
    echo "Image not found: $IMG_PATH"
    exit 1
fi

# Clean previous mounts
umount "$DEST_DIR/$IMG_NAME_BASE" 2>/dev/null
rm -rf "$DEST_DIR/$IMG_NAME_BASE"
umount "$DEST_DIR/${IMG_NAME_BASE}_mount" 2>/dev/null
rm -rf "$DEST_DIR/${IMG_NAME_BASE}_mount"

# Create mount point
mkdir -p "$DEST_DIR/${IMG_NAME_BASE}_mount"

# 🔥 Mount
fuse2fs "$IMG_PATH" "$DEST_DIR/${IMG_NAME_BASE}_mount"

# Calculate size
MOUNT_SIZE=$(du -sb "$DEST_DIR/${IMG_NAME_BASE}_mount" | awk '{print int($1 * 1.3)}')
echo "Mounted image size: ${MOUNT_SIZE} bytes"

# Create ext4 image
dd if=/dev/zero of="$NEW_IMG_NAME" bs=1 count=0 seek=$MOUNT_SIZE
mkfs.ext4 -F -b 4096 "$NEW_IMG_NAME"

# Mount new image
mkdir -p "$DEST_DIR/$IMG_NAME_BASE"
mount -o loop "$NEW_IMG_NAME" "$DEST_DIR/$IMG_NAME_BASE"

# Copy files
cp -a "$DEST_DIR/${IMG_NAME_BASE}_mount"/* "$DEST_DIR/$IMG_NAME_BASE"

# Cleanup mounts
umount "$DEST_DIR/$IMG_NAME_BASE"
rm -rf "$DEST_DIR/$IMG_NAME_BASE"

umount "$DEST_DIR/${IMG_NAME_BASE}_mount" 2>/dev/null
rm -rf "$DEST_DIR/${IMG_NAME_BASE}_mount"

# 🔥 Rename back to original name
FINAL_IMG="$DEST_DIR/${IMG_NAME_BASE}.img"
rm -f "$FINAL_IMG"
mv "$NEW_IMG_NAME" "$FINAL_IMG"
