#!/bin/bash
# Install the pinned TensorFold native release (sha256-verified) and check the host.
set -euo pipefail
. "$(dirname "$0")/env.sh"

echo "== host"
chip=$(sysctl -n machdep.cpu.brand_string); ram=$(ram_gib); os=$(sw_vers -productVersion)
echo "   $chip, ${ram} GB, macOS $os"
case "$chip" in *"M5 Ultra"*) ;; *) echo "   note: this recipe is measured on M5 Ultra; other Apple Silicon may run it with smaller contexts" ;; esac
[ "$ram" -ge 192 ] || echo "   warning: ${ram} GB RAM. The main model alone needs ~150 GiB resident; see docs/memory.md for smaller configs."
need curl; need shasum; need tar; need python3

if [ -x "$TF_BIN" ]; then
  echo "== tensorfold already installed: $("$TF_BIN" --version)"
else
  echo "== installing TensorFold $TF_VERSION native"
  d="$TF_HOME/$TF_VERSION"; mkdir -p "$d"; cd "$d"
  base="https://github.com/ashhart/TensorFold/releases/download/v$TF_VERSION"
  curl -sSfL -o tf.tgz "$base/tensorfold-$TF_VERSION-macos-arm64.tar.gz"
  curl -sSfL -o tf.tgz.sha256 "$base/tensorfold-$TF_VERSION-macos-arm64.tar.gz.sha256"
  echo "$(cut -d' ' -f1 tf.tgz.sha256)  tf.tgz" | shasum -a 256 -c -
  tar xzf tf.tgz && rm -f tf.tgz tf.tgz.sha256
  echo "   installed $("$TF_BIN" --version) at $TF_BIN"
fi

echo "== engine capabilities"
"$TF_BIN" capabilities --json | python3 -c '
import sys,json; j=json.load(sys.stdin)
fam=j["families"]; need={"qwen4_exp":"mlx-q6g32","nemotron_h":"mlx-q4g64"}
for f,fmt in need.items():
    ok = fmt in fam.get(f,[]); print("   %-12s %-10s %s" % (f, fmt, "ok" if ok else "MISSING"))
    if not ok: sys.exit(1)
print("   chip:", j.get("chip"), "backends:", j.get("backends"))'
echo "== done. next: bin/download.sh"
