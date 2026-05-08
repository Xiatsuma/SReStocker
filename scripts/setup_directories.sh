#!/bin/bash
set -e

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <dir1> <dir2> ... <dirN>"
    exit 1
fi

for DIR in "$@"; do
    rm -rf "$DIR"
    mkdir -p "$DIR"
    echo "Directory prepared: $DIR"
done
