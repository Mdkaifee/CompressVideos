#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT_DIR="${1:-$SCRIPT_DIR/input}"
OUTPUT_DIR="${2:-$SCRIPT_DIR/output}"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg is required but was not found in PATH."
  exit 1
fi

if ! command -v ffprobe >/dev/null 2>&1; then
  echo "ffprobe is required but was not found in PATH."
  exit 1
fi

mkdir -p "$INPUT_DIR" "$OUTPUT_DIR"

FILES=()
while IFS= read -r -d '' file; do
  FILES+=("$file")
done < <(
  find "$INPUT_DIR" -maxdepth 1 -type f \
    \( -iname '*.mp4' -o -iname '*.mov' -o -iname '*.m4v' -o -iname '*.webm' \) \
    -print0 | sort -z
)

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "No video files found in: $INPUT_DIR"
  echo "Drop .mp4/.mov/.m4v/.webm files into the input folder and run again."
  exit 0
fi

human_size() {
  local bytes="$1"
  awk -v bytes="$bytes" '
    function human(x) {
      split("B KB MB GB TB", units, " ")
      idx = 1
      while (x >= 1024 && idx < 5) {
        x /= 1024
        idx++
      }
      return sprintf("%.2f %s", x, units[idx])
    }
    BEGIN { print human(bytes) }
  '
}

video_summary() {
  local file="$1"
  ffprobe -v error \
    -select_streams v:0 \
    -show_entries stream=codec_name,width,height,avg_frame_rate,bit_rate \
    -show_entries format=duration,size,bit_rate \
    -of default=noprint_wrappers=1:nokey=0 \
    "$file"
}

echo "Input:  $INPUT_DIR"
echo "Output: $OUTPUT_DIR"
echo

for file in "${FILES[@]}"; do
  base_name="$(basename "$file")"
  stem="${base_name%.*}"
  output_file="$OUTPUT_DIR/${stem}_optimized.mp4"

  input_size_bytes="$(stat -f%z "$file")"

  echo "Processing: $base_name"
  echo "Before:"
  video_summary "$file" | sed 's/^/  /'

  ffmpeg -y -i "$file" \
    -map 0:v:0 -map 0:a? \
    -c:v libx264 \
    -preset slow \
    -crf 22 \
    -profile:v high \
    -pix_fmt yuv420p \
    -vf "scale='min(1280,iw)':-2" \
    -movflags +faststart \
    -c:a aac \
    -b:a 96k \
    "$output_file"

  output_size_bytes="$(stat -f%z "$output_file")"
  reduction_percent="$(awk -v input_bytes="$input_size_bytes" -v output_bytes="$output_size_bytes" 'BEGIN {
    if (input_bytes <= 0) {
      print "0.00"
    } else {
      printf "%.2f", ((input_bytes - output_bytes) / input_bytes) * 100
    }
  }')"

  echo "After:"
  video_summary "$output_file" | sed 's/^/  /'
  echo "Size change:"
  echo "  $(human_size "$input_size_bytes") -> $(human_size "$output_size_bytes") (${reduction_percent}% smaller)"
  echo
done

echo "Done. Optimized videos are in: $OUTPUT_DIR"
