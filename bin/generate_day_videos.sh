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

OUTPUT_DIR="${2:-"$HOME/Vídeos"}"
mkdir -p "$OUTPUT_DIR"

exclude_map=($EXCLUDE_MAP)

cd "$INPUT_DIR"
# Only relative bindir... I am tired!!!
BIN_DIR="../$BIN_DIR"
count="-1"
for x in */insertions.txt; do
  count="$(("$count" + 1))"
  if [ 'x' == "${exclude_map["$count"]}" -o 'X' == "${exclude_map["$count"]}" ]; then
    echo "===> Ignoring file $x."
    continue
  fi
  mp4_path="$OUTPUT_DIR/$(basename "$(dirname "$x")").mp4"
  stamp_file="$mp4_path.stamp"
  if [ ! "$x" -nt "$stamp_file" ]; then
    echo "====> SKIPING.... Not generating $mp4_path."
    echo "Remove timestamp $stamp_file to force generation."
    continue
  fi

  echo "==================================="
  echo "Will generate from $x."
  "$BIN_DIR/compose_overlays.sh" "$x"
  echo "Will generate $mp4_path."
  "$BIN_DIR/mp4_generator.sh" "insertions_$(basename "$(dirname "$x")").mlt" "$mp4_path"
  touch "$stamp_file"
  echo "==================================="
  echo ''
done

