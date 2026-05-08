#!/bin/bash

if [[ "$#" == '0' ]]; then
    echo -e 'ERROR: No File Specified!' && exit 1
fi

FILE="$1"

SERVER=$(curl -s https://api.gofile.io/servers | jq -r '.data.servers[0].name')

LINK=$(curl -# -F "file=@$FILE" "https://${SERVER}.gofile.io/uploadFile" | jq -r '.data|.downloadPage') 2>&1

echo "$LINK"
