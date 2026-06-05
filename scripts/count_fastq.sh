#!/usr/bin/env bash
# Run FASTAptamer-Count on every FASTQ in a directory.
# For each <in_dir>/<name>.fastq -> writes <out_dir>/<name>.fasta
# (non-redundant FASTA with headers ">RANK-READS-RPM").
#
# Usage:
#   ./scripts/count_fastq.sh <in_dir> [out_dir] [jobs]
#
# Defaults:
#   out_dir = ./counts
#   jobs    = 4
#
# Requires perl on PATH and FASTAptamer at .devbox/tools/FASTAptamer/.

set -euo pipefail

IN_DIR="${1:?usage: count_fastq.sh <in_dir> [out_dir] [jobs]}"
OUT_DIR="${2:-./counts}"
JOBS="${3:-4}"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
FAS="$REPO_DIR/.devbox/tools/FASTAptamer/fastaptamer_count"

[[ -d "$IN_DIR" ]] || { echo "in_dir not found: $IN_DIR" >&2; exit 1; }
[[ -f "$FAS" ]]    || { echo "FASTAptamer-Count not found at $FAS (run \`devbox shell\` once to clone)" >&2; exit 1; }
command -v perl >/dev/null || { echo "perl not on PATH (run inside devbox)" >&2; exit 1; }

mkdir -p "$OUT_DIR"

shopt -s nullglob
running=0
for f in "$IN_DIR"/*.fastq; do
  base=$(basename "$f" .fastq)
  out="$OUT_DIR/${base}.fasta"
  echo "[count] $f -> $out"
  perl "$FAS" -i "$f" -o "$out" -q &
  if (( ++running >= JOBS )); then
    wait -n
    ((running--))
  fi
done
wait

echo "Done."
command -v seqkit >/dev/null && seqkit stats "$OUT_DIR"/*.fasta || true
