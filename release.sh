#!/bin/bash
set -euo pipefail
: "${ZIP_PATH:?ZIP_PATH is required}"
: "${BUILD_TIME:?BUILD_TIME is required}"
: "${STOCK_DEVICE:?STOCK_DEVICE is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${GOFILE_LINK:?GOFILE_LINK is required}"
TARGET_DEVICE_DISPLAY="${TARGET_DEVICE:-$STOCK_DEVICE}"
TAG_NAME="${STOCK_DEVICE}-$(date +%s)"
RELEASE_NAME="${TARGET_DEVICE_DISPLAY} Port For ${STOCK_DEVICE}"
FILE_SIZE=$(du -h "$ZIP_PATH" | cut -f1)
MD5_SUM=$(md5sum "$ZIP_PATH" | awk '{print $1}')
RELEASE_BODY="Download:
$GOFILE_LINK

File Info:
Size: $FILE_SIZE
Build Time: $BUILD_TIME
MD5: $MD5_SUM

Rom Info:
Ported For: $STOCK_DEVICE
Ported From: $TARGET_DEVICE_DISPLAY

Build Options:
Filesystem: $OUTPUT_FILESYSTEM
Compressed IMG: $COMPRESS_IMG_TO_XZ
Used UI8 Tethering APEX: $USE_UI_8_TETHERING_APEX
"
JSON_BODY=$(printf '%s' "$RELEASE_BODY" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
if [ -n "${GIT_TOKEN:-}" ]; then
  curl -sS -X POST "https://api.github.com/repos/${GITHUB_REPOSITORY}/releases" \
    -H "Authorization: token $GIT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"tag_name\":\"$TAG_NAME\",\"name\":\"$RELEASE_NAME\",\"body\":$JSON_BODY,\"draft\":false,\"prerelease\":false}"
fi
