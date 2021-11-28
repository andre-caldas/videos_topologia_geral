#!/bin/bash
set -e
set -x

BIN_DIR="$(dirname "$0")"
if [ '.' == "$BIN_DIR" ]; then
  echo 'No hard coded path to library.' >&2
  exit 1
fi
. "$BIN_DIR/lib/tools.sh"

shopt -s nullglob

LANG="C.UTF-8"

MLT_FILE="$1"
OUTPUT_DIRECTORY={2:-"."}
first_char="$(cut -b 1 <<<"$OUTPUT_DIRECTORY")"
if [ '/' != "$first_char" -a '~' != "$first_char" ]; then
  OUTPUT_DIRECTORY="$(dirname "$PWD/$OUTPUT_DIRECTORY/")"
fi
OUTPUT_VIDEO="$OUTPUT_DIRECTORY/$(basename .mlt "$MLT_FILE").mp4"
TEMP_INPUT="$OUTPUT_DIRECTORY/temp__$(basename "$MLT_FILE")"
trap "rm -f '$TEMP_INPUT'" EXIT
trap "rm -f '$TEMP_INPUT'" KILL

MELT="melt-7"

INSERT_STRING=<<EOF
  <profile height="1080" frame_rate_den="1" description="PAL 4:3 DV or DVD" display_aspect_den="9" frame_rate_num="60" sample_aspect_num="1" sample_aspect_den="1" display_aspect_num="16" width="1920" colorspace="709" progressive="1"/>
CONSUMER_STRING=
  <consumer deinterlace_method="yadif-nospatial" threads="0" vcodec="libx264" acodec="aac" ab="384k" ar="48000" g="300" rescale="bilinear" frame_rate_num="30000000" target="$OUTPUT_VIDEO" preset="fast" mlt_service="avformat" crf="30" bf="3" height="720" width="1280" movflags="+faststart" top_field_first="2" channels="2" frame_rate_den="1000000" real_time="-4" f="mp4"/>
EOF

(
  sed '/<profile/,$d' "$MLT_FILE"
  echo "$INSERT_STRING"
  sed '0,/<consumer/d' "$MLT_FILE"
) > $TEMP_INPUT

colocar caminhos absolutos
colocar aquele negócio pro melt não usar muita memória

time $MELT "$TEMP_INPUT"

