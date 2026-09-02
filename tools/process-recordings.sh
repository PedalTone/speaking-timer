#!/usr/bin/env bash
#
# Splits a long voice recording into individual phrase clips for the app.
#
#   ./tools/process-recordings.sh raw/alex.m4a alex hype
#
# Arguments:
#   1. the raw recording (m4a, wav, mp3 — anything ffmpeg reads)
#   2. a short name for the speaker, used in filenames
#   3. which pool the clips belong to: "hype" or "completion"
#
# Splits on the ~2s pauses between phrases, trims silence, normalises loudness
# so no one speaker is louder than the rest, and writes web-ready m4a files to
# audio/<pool>/. Run tools/build-manifest.sh afterwards.

set -euo pipefail

SRC="${1:?usage: process-recordings.sh <recording> <speaker> <hype|completion>}"
SPEAKER="${2:?missing speaker name}"
POOL="${3:?missing pool: hype or completion}"

case "$POOL" in
  hype|completion) ;;
  *) echo "pool must be 'hype' or 'completion', got '$POOL'" >&2; exit 1 ;;
esac

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$REPO_ROOT/audio/$POOL"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

mkdir -p "$OUT_DIR"

# -35dB suits real rooms: a phone recording carries enough room tone that a
# stricter -45dB reads the gaps as speech and merges phrases together. Lower it
# toward -45dB for a very quiet recording that splits mid-sentence, and raise
# MIN_PAUSE if natural pauses inside a sentence are being treated as breaks.
SILENCE_DB="${SILENCE_DB:--35dB}"
MIN_PAUSE="${MIN_PAUSE:-0.9}"

echo "Splitting $SRC on pauses (threshold $SILENCE_DB, min gap ${MIN_PAUSE}s)..."
# Needs -loglevel info: silencedetect reports at info level, so anything
# quieter swallows the results and the recording comes back as one clip.
ffmpeg -hide_banner -loglevel info -i "$SRC" \
  -af "silencedetect=noise=${SILENCE_DB}:d=${MIN_PAUSE}" \
  -f null - 2> "$WORK_DIR/silence.txt" || true

# Turn the detected silences into [start,end] speech spans.
python3 - "$SRC" "$WORK_DIR/silence.txt" "$WORK_DIR/spans.txt" <<'PY'
import re, subprocess, sys

src, silence_log, out = sys.argv[1], sys.argv[2], sys.argv[3]

duration = float(subprocess.check_output([
    "ffprobe", "-v", "error", "-show_entries", "format=duration",
    "-of", "default=noprint_wrappers=1:nokey=1", src,
]).decode().strip())

log = open(silence_log).read()
starts = [float(x) for x in re.findall(r"silence_start: ([\d.]+)", log)]
ends = [float(x) for x in re.findall(r"silence_end: ([\d.]+)", log)]

# Speech runs from each silence_end to the next silence_start.
bounds = [0.0] + ends
stops = starts + [duration]

spans = []
for a, b in zip(bounds, stops):
    if b - a > 0.35:          # drop anything too short to be a phrase
        spans.append((max(0.0, a - 0.10), min(duration, b + 0.25)))

with open(out, "w") as f:
    for a, b in spans:
        f.write(f"{a:.3f} {b:.3f}\n")

print(f"  found {len(spans)} phrases")
PY

COUNT=0
while read -r START END; do
  COUNT=$((COUNT + 1))
  NAME=$(printf "%s-%02d" "$SPEAKER" "$COUNT")
  # printf, not bc: bc renders values under 1 as ".998" and ffmpeg rejects
  # that as a duration. Clamped so very short clips don't get a negative start.
  FADE_ST=$(awk -v e="$END" -v s="$START" 'BEGIN{ v = e - s - 0.05; if (v < 0) v = 0; printf "%.3f", v }')
  DUR=$(awk -v e="$END" -v s="$START" 'BEGIN{ printf "%.3f", e - s }')
  # -ss/-t before -i (input seeking). With -ss after -i, -to is measured on a
  # different timeline and every segment past the first comes out silent.
  ffmpeg -hide_banner -loglevel error -y \
    -ss "$START" -t "$DUR" -i "$SRC" \
    -af "loudnorm=I=-16:TP=-1.5:LRA=11,afade=t=in:d=0.02,afade=t=out:st=${FADE_ST}:d=0.05" \
    -ac 1 -ar 44100 -c:a aac -b:a 64k \
    "$OUT_DIR/$NAME.m4a"
done < "$WORK_DIR/spans.txt"

echo "Wrote $COUNT clips to audio/$POOL/ as ${SPEAKER}-NN.m4a"
echo "Listen through them, delete any duds, then run tools/build-manifest.sh"
