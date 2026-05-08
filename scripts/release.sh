#!/bin/bash

set -e

TAG_NAME="${TARGET_DEVICE}-to-${STOCK_DEVICE}-$(date +%s)"
RELEASE_NAME="${TARGET_DEVICE} Port For ${STOCK_DEVICE}"

echo "Uploading to GoFile..."
GOFILE_LINK=$(sudo bash scripts/upload.sh "$ZIP_PATH")
echo "🌎 File uploaded here: $GOFILE_LINK"

FILE_SIZE=$(du -h "$ZIP_PATH" | cut -f1)
MD5_SUM=$(md5sum "$ZIP_PATH" | awk '{print $1}')

RELEASE_BODY="#### 🌎 Download:
$GOFILE_LINK

#### 📊 File Info:
• Size: $FILE_SIZE
• Build Time: $BUILD_TIME
• MD5: $MD5_SUM

#### 📱 Rom Info:
• Ported From: $TARGET_DEVICE
• Ported For: $STOCK_DEVICE

#### ⚙️ Build Options:
• Filesystem: $OUTPUT_FILESYSTEM
• Compressed IMG: $COMPRESS_IMG_TO_XZ
"

JSON_BODY=$(printf '%s' "$RELEASE_BODY" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')

if [ -n "$GIT_TOKEN" ]; then
  echo "Creating GitHub release..."

  curl -X POST "https://api.github.com/repos/${GITHUB_REPOSITORY}/releases" \
    -H "Authorization: token $GIT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"tag_name\": \"$TAG_NAME\",
      \"name\": \"$RELEASE_NAME\",
      \"body\": $JSON_BODY,
      \"draft\": false,
      \"prerelease\": false
    }"
else
  echo "GIT_TOKEN not found. Skipping release."
fi
