#!/usr/bin/env bash
# Reverse-complement every per-barcode FASTQ in a directory.
# For each <in_dir>/<name>.fastq -> writes <out_dir>/<name>RC.fastq.
# If --out is omitted, output is written next to the input.
# Already-suffixed *RC.fastq inputs are skipped, so re-runs are safe.
#
# Usage:
#   ./scripts/rc_barcodes.sh <in_dir> [out_dir] [jobs]
#
# Requires seqkit on PATH (devbox provides it).

set -euo pipefail

IN_DIR="${1:?usage: rc_barcodes.sh <in_dir> [out_dir] [jobs]}"
OUT_DIR="${2:-$IN_DIR}"
JOBS="${3:-4}"

[[ -d "$IN_DIR" ]] || { echo "in_dir not found: $IN_DIR" >&2; exit 1; }
command -v seqkit >/dev/null || { echo "seqkit not on PATH (run inside devbox shell)" >&2; exit 1; }

mkdir -p "$OUT_DIR"

shopt -s nullglob
running=0
for f in "$IN_DIR"/*.fastq; do
  base=$(basename "$f" .fastq)
  [[ "$base" == *RC ]] && continue
  out="$OUT_DIR/${base}RC.fastq"
  echo "$f -> $out"
  seqkit seq -t DNA -pr "$f" > "$out" &
  if (( ++running >= JOBS )); then
    wait -n
    ((running--))
  fi
done
wait

echo "Done."
