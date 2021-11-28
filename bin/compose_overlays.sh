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

FPS=60

if [ '' == "$1" ]; then
  echo "ERROR: required argument!" >&2
  exit 1
fi

START_POSITION="${2:-00.000}"
END_POSITION="${3:-99:99:99.000}"

input_path="$1"
exec < "$input_path"

input_dir="$(dirname "$input_path")"
read mlt_path_relative
original_mlt_path="$input_dir/$mlt_path_relative"
generated_mlt_path="$(dirname "$input_dir")/$(basename "$input_path" .txt)_$(basename "$input_dir").mlt"

master_template_path="$TEMPLATES_PATH/master.mlt.template"


generated_dir="$input_dir/generated"
mkdir -p "$generated_dir"
function overlay_base_path () {
  echo "$generated_dir/${count}_overlay_${entry_values[template]}"
}


function create_master_mlt () {
  local -A variables
  variables["original_length"]="$(get_mlt_length "$original_mlt_path")"
  variables["original_length-1"]=""$(len_plus_frame "${variables["original_length"]}" -1)""
  variables["original_path"]="$original_mlt_path"
  variables["original_md5"]="$(get_md5sum "$original_mlt_path")"
  # This should be calculated only at the very end...
  variables["total_length"]="${variables["original_length"]}"
  variables["total_length-1"]="${variables["original_length-1"]}"

  substitute_variables "$master_template_path" "variables" > "$generated_mlt_path"
}



declare next_position="0"
declare count=0

declare server_port="8910"
(
  python3 -m http.server --directory "$TEMPLATES_PATH" "$server_port" > .http_server.log 2>&1 
)&
trap "kill $!" EXIT
trap "kill $!" TERM
coproc "${PNG_EXTRACTOR[@]}"
trap "kill $COPROC_PID" EXIT
trap "kill $COPROC_PID" TERM
png_extractor_output="${COPROC[0]}"
png_extractor_input="${COPROC[1]}"



init_tracks overA overB overC overD overE overF

# Create MLT file and populate with main video information.
create_master_mlt

START_POSITION="$(len_to_mu "$START_POSITION")"
END_POSITION="$(len_to_mu "$END_POSITION")"

# Read entries from txt file with instructions.
read_entry
while [ '' != "$next_position" ]; do
  # Choose a non overlaping group of tracks.
  variant="$(pick_up_a_track_variant_for_position "$next_position")"

  # Create a sufficent number of tracks.
  create_tracks_for_overlay "$variant"
  insert_into_master_mlt "$variant"
  generate_pngs
  read_entry
done
update_track_numbers
hack_fix
cleanup_master_mlt

