#!/usr/bin/env bash
# Split a FASTQ into per-barcode FASTQs by matching the 5' prefix.
# Equivalent to: seqkit grep -sirp ^<seq> in.fastq > <id>.fastq for each row.
#
# Usage:
#   ./scripts/split_by_barcode.sh <barcodes.csv> <input.fastq> [output_dir] [jobs]
#
# CSV format (header required):
#   id,sequence
#   bc1,tatagtagct
#   ...
#
# Requires seqkit on PATH (devbox provides it).

set -euo pipefail

CSV="${1:?usage: split_by_barcode.sh <barcodes.csv> <input.fastq> [output_dir] [jobs]}"
IN_FASTQ="${2:?usage: split_by_barcode.sh <barcodes.csv> <input.fastq> [output_dir] [jobs]}"
OUT_DIR="${3:-./split_output}"
JOBS="${4:-4}"

[[ -f "$CSV" ]]      || { echo "barcodes CSV not found: $CSV" >&2; exit 1; }
[[ -f "$IN_FASTQ" ]] || { echo "input FASTQ not found: $IN_FASTQ" >&2; exit 1; }
command -v seqkit >/dev/null || { echo "seqkit not on PATH (run inside devbox shell)" >&2; exit 1; }

mkdir -p "$OUT_DIR"

# `|| [[ -n "$id" ]]` catches the last line when the CSV has no trailing newline.
# tr -d '\r' strips CRLF.  awk filters out blank/comment lines.
running=0
tail -n +2 "$CSV" | tr -d '\r' | awk -F, 'NF>=2 && $1!="" && $2!="" && $1!~/^#/' \
  | while IFS=, read -r id seq _ || [[ -n "${id:-}" ]]; do
    out="$OUT_DIR/${id}.fastq"
    echo "[$id] ^$seq -> $out"
    seqkit grep -sirp "^${seq}" "$IN_FASTQ" > "$out" &
    if (( ++running >= JOBS )); then
      wait -n
      ((running--))
    fi
  done
wait

echo "Done. Per-barcode FASTQs in: $OUT_DIR"
seqkit stats "$OUT_DIR"/*.fastq
