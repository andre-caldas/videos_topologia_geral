#!/bin/bash
set -e
#set -x

BIN_DIR="$(dirname "$0")"
if [ '.' == "$BIN_DIR" ]; then
  echo 'No hard coded path to library.' >&2
  exit 1
fi
. "$BIN_DIR/lib/tools.sh"

shopt -s nullglob

LANG="C.UTF-8"

function absolute_path () {
  local result="$(sed "s|^~/|$HOME/|"<<<"$1")"
  local first_char="$(cut -b 1 <<<"$result")"
  if [ '/' != "$first_char" ]; then
    result="$(dirname "$PWD/$result/")"
  fi
  echo "$result"
}

ORIGINAL_MLT_FILE="$1"
ORIGINAL_MLT_ABSDIR="$(absolute_path $(dirname "$ORIGINAL_MLT_FILE"))"

auto_filename="$(basename "$ORIGINAL_MLT_FILE" .mlt).mp4"
OUTPUT_FILENAME="${2:-"$auto_filename"}"

OUTPUT_DIRECTORY="$(dirname "$OUTPUT_FILENAME")"
OUTPUT_ABSDIR="$(absolute_path "$OUTPUT_DIRECTORY")"
OUTPUT_VIDEO_ABSPATH="$OUTPUT_ABSDIR/$(basename $OUTPUT_FILENAME)"
TEMP_INPUT="$OUTPUT_ABSDIR/temp__$(basename "$ORIGINAL_MLT_FILE")"
trap "rm -f '$TEMP_INPUT'" EXIT
trap "rm -f '$TEMP_INPUT'" KILL

MELT="melt-7"

INSERT_STRING="$(cat <<EOF
  <consumer deinterlace_method="yadif-nospatial" threads="0" vcodec="libx264" acodec="aac" ab="384k" ar="48000" g="300" rescale="bilinear" frame_rate_num="30000000" target="$OUTPUT_VIDEO_ABSPATH" preset="fast" mlt_service="avformat" crf="30" bf="3" height="720" width="1280" movflags="+faststart" top_field_first="2" channels="2" frame_rate_den="1000000" real_time="-4" f="mp4"/>
EOF
)"

(
  sed '0,/<profile/!d' "$ORIGINAL_MLT_FILE"
  echo "$INSERT_STRING"
  sed '0,/<profile/d' "$ORIGINAL_MLT_FILE"
) |
  sed -r -e '/<playlist /s,(<playlist ),\1autoclose="1" ,' |
  sed -r -e '/<property name="resource">[^#/][^<][^<][^<]/s,>,>'"$ORIGINAL_MLT_ABSDIR"'/,' > $TEMP_INPUT

duration="$(sed -r '/id="black"/!d; /black/s/.*out="([^"]*)".*/\1/' "$ORIGINAL_MLT_FILE")"

echo "======="
echo "Will generate file: $duration."
echo "That is... $(("$(len_to_mu "$duration")" * 60 / 1000)) frames."
echo "======="

date
time $MELT "$TEMP_INPUT"

