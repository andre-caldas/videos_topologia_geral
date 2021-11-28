#!/bin/bash

set -x
set -e

shopt -s nullglob

IN_DIR="$1"

UNDRIFTER="$HOME/repositorios/sandbox/audio_aligner/undrifted_and_aligned_xml.sh"

for IN_MP4 in "$IN_DIR"/*/*.MP4 "$IN_DIR"/*.MP4; do
(
  cd "$(dirname "$IN_MP4")"
  IN_MP4="$(basename "$IN_MP4")"

  IN_WAV="$(basename "$IN_MP4" .MP4).WAV"
  OUT_WAV="$(basename "$IN_MP4" .MP4)_48000.WAV"
  ORIGINAL_DIR="original_audio"
  RENAMED_WAV="$ORIGINAL_DIR/$(basename "$IN_WAV")"
  XML_NAME="$(basename "$IN_MP4" .MP4).mlt"

  if [ -e "$IN_WAV" ]; then
    ffmpeg -y -stats -i "$IN_WAV" -v error -vn -ar 48000 "$OUT_WAV"
    $UNDRIFTER "$IN_MP4" "$OUT_WAV" atsc_1080p_60 > "$XML_NAME"

    mkdir -p "$ORIGINAL_DIR"
    mv "$IN_WAV" "$RENAMED_WAV"
  fi
)
done
