#!/bin/bash
set -euo pipefail
[[ "$#" -lt 1 ]] && { echo "Usage: $0 <dir1> <dir2> ..." >&2; exit 1; }
for DIR in "$@"; do
  [[ -z "$DIR" || "$DIR" == "/" ]] && { echo "Refusing unsafe directory: $DIR" >&2; exit 1; }
  rm -rf "$DIR" && mkdir -p "$DIR" && echo "Prepared: $DIR"
done
