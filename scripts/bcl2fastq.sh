#!/usr/bin/env bash
# MiSeq BCL -> FASTQ converter using Picard IlluminaBasecallsToFastq
# Usage: ./scripts/bcl2fastq.sh <run_dir> [output_dir]
#   run_dir    : MiSeq run directory (contains RunInfo.xml, Data/, ...)
#   output_dir : Output directory (default: ./fastq_output)
#
# Reads RunInfo.xml to derive:
#   - READ_STRUCTURE  (e.g. 130T, 150T8B8B150T, ...)
#   - FLOWCELL_BARCODE / MACHINE_NAME / RUN_BARCODE
# Requires picard available on PATH (devbox provides picard-tools).

set -euo pipefail

RUN_DIR="${1:?usage: bcl2fastq.sh <run_dir> [output_dir]}"
OUT_DIR="${2:-./fastq_output}"

RUN_INFO="${RUN_DIR}/RunInfo.xml"
BASECALLS_DIR="${RUN_DIR}/Data/Intensities/BaseCalls"

[[ -f "$RUN_INFO" ]]      || { echo "RunInfo.xml not found at $RUN_INFO" >&2; exit 1; }
[[ -d "$BASECALLS_DIR" ]] || { echo "BaseCalls dir not found at $BASECALLS_DIR" >&2; exit 1; }
command -v picard >/dev/null || { echo "picard not on PATH (run inside devbox shell)" >&2; exit 1; }

# Parse RunInfo.xml: build READ_STRUCTURE like 150T8B8B150T from <Read .../> entries.
READ_STRUCTURE=$(python3 - "$RUN_INFO" <<'PY'
import sys, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
parts = []
for r in root.findall(".//Read"):
    cycles = r.attrib["NumCycles"]
    kind = "B" if r.attrib.get("IsIndexedRead", "N") == "Y" else "T"
    parts.append(f"{cycles}{kind}")
print("".join(parts))
PY
)

FLOWCELL=$(python3 -c "import xml.etree.ElementTree as ET,sys; print(ET.parse(sys.argv[1]).getroot().findtext('.//Flowcell'))" "$RUN_INFO")
MACHINE=$( python3 -c "import xml.etree.ElementTree as ET,sys; print(ET.parse(sys.argv[1]).getroot().findtext('.//Instrument'))" "$RUN_INFO")
RUN_NUM=$( python3 -c "import xml.etree.ElementTree as ET,sys; print(ET.parse(sys.argv[1]).getroot().find('.//Run').attrib['Number'])" "$RUN_INFO")
LANE_COUNT=$(python3 -c "import xml.etree.ElementTree as ET,sys; print(ET.parse(sys.argv[1]).getroot().find('.//FlowcellLayout').attrib['LaneCount'])" "$RUN_INFO")

PREFIX="${OUT_DIR}/$(basename "$RUN_DIR")"
mkdir -p "$OUT_DIR"

echo "RUN_DIR        = $RUN_DIR"
echo "READ_STRUCTURE = $READ_STRUCTURE"
echo "FLOWCELL       = $FLOWCELL"
echo "MACHINE        = $MACHINE"
echo "RUN_BARCODE    = $RUN_NUM"
echo "LANES          = $LANE_COUNT"
echo "OUTPUT_PREFIX  = $PREFIX.<lane>"

# Note: this assumes no sample demultiplexing (single sample / no barcode split).
# For multiplexed runs, switch to MULTIPLEX_PARAMS / library_params.tsv.
for LANE in $(seq 1 "$LANE_COUNT"); do
  echo "--- Lane $LANE ---"
  picard IlluminaBasecallsToFastq \
    BASECALLS_DIR="$BASECALLS_DIR" \
    LANE="$LANE" \
    READ_STRUCTURE="$READ_STRUCTURE" \
    OUTPUT_PREFIX="${PREFIX}.L${LANE}" \
    RUN_BARCODE="$RUN_NUM" \
    MACHINE_NAME="$MACHINE" \
    FLOWCELL_BARCODE="$FLOWCELL" \
    COMPRESS_OUTPUTS=false \
    NUM_PROCESSORS=4
done

echo "Done. Output in: $OUT_DIR"
