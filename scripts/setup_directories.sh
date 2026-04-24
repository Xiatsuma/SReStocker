#!/bin/bash
set -e

echo "Running script: $(basename "$0")"

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <dir1> <dir2> ... <dirN>"
    exit 1
fi

for DIR in "$@"; do
    if [[ -z "$DIR" || "$DIR" == "/" ]]; then
        echo "Refusing unsafe directory target: '$DIR'"
        exit 1
    fi
    # Clean old dir
    rm -rf "$DIR"
    # Recreate dir
    mkdir -p "$DIR"
    # Show result
    echo "Directory prepared: $DIR"
done
