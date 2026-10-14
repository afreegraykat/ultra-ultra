#!/bin/bash
# Seed TensorFold's Hugging Face cache from a checkpoint you already have on disk, using hard links
# (no copy, same volume). Then `tensorfold pull REPO` only verifies hashes instead of downloading.
# Usage: bin/seed-from-local.sh REPO /path/to/checkpoint-dir REVISION_SHA
set -euo pipefail
. "$(dirname "$0")/env.sh"
repo=$1 src=$2 rev=$3
d="$HF_HUB_CACHE/models--${repo//\//--}"
snap="$d/snapshots/$rev"
mkdir -p "$d/refs" "$d/blobs" "$snap"
echo "$rev" >"$d/refs/main"
n=0
while IFS= read -r -d '' f; do
  rel=${f#"$src"/}; case "$rel" in .cache/*|.complete|.gitattributes) continue;; esac
  mkdir -p "$snap/$(dirname "$rel")"
  blob="$d/blobs/$(shasum -a 256 "$f" | cut -d' ' -f1)"
  [ -e "$blob" ] || ln "$f" "$blob"
  ln -sf "$blob" "$snap/$rel"; n=$((n+1))
done < <(find "$src" -type f -print0)
echo "seeded $n files into $snap"
echo "verify with: $TF_BIN pull $repo"
