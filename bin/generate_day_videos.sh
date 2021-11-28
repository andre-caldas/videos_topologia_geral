#!/bin/bash
set -e
#set -x

BIN_DIR="$(dirname "$0")"
if [ '.' == "$BIN_DIR" ]; then
  echo 'No hard coded path to library.' >&2
  exit 1
fi

INPUT_DIR="$1"
if [ '' == "$INPUT_DIR" ]; then
  echo 'Required argument!' >&2
  exit 1
fi

OUTPUT_DIR="${2:-'~/Vídeos'}"
mkdir -p "$OUTPUT_DIR"

cd "$INPUT_DIR"
# Only relative bindir... I am tired!!!
BIN_DIR="../$BIN_DIR"
for x in */insertions.txt; do
  echo "==================================="
  echo "Will generate $x."
  "$BIN_DIR/compose_overlays.sh" "$x"
set -x
echo "insertions_$(basename "$(dirname "$x")").mlt"
  "$BIN_DIR/mp4_generator.sh" "insertions_$(basename "$(dirname "$x")").mlt" "$OUTPUT_DIR/"
  echo "==================================="
  echo ''
done

