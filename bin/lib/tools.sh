TEMPLATES_PATH="$BIN_DIR/../templates"
ASSETS_DIR="$BIN_DIR/../assets"
PNG_EXTRACTOR=("python3" "$BIN_DIR/png_extractor.py")


declare -A global_entry_values=()
declare -A entry_values=()
function read_entry () {
  next_position=''
  local x
  while read x; do
    [ '' == "$x" ] && continue

    next_position="$(echo "$x" | sed -r -e 's,.*== *([^ ]+) *==.*,\1,')"
    if [ "$next_position" == 'globals' ]; then
      echo ''
      echo '== GLOBAL variables =='
      _read_entry_sub "global_entry_values"
      read_entry
    else
      count="$(($count + 1))"
      echo ''
      echo "== $count =="
      echo "New entry at position $next_position."
      next_position="$(len_to_mu "$next_position")"
      local i
      entry_values=()
      for i in "${!global_entry_values[@]}"; do
        entry_values["$i"]="${global_entry_values["$i"]}"
      done
      entry_values[id]="$count"
      _read_entry_sub 'entry_values'
    fi
    return
  done
}

function _read_entry_sub () {
  local -n array="$1"
  while IFS=" =" read -r tag val; do
    if [ '' == "$tag" ]; then
      break
    fi
    echo "$tag = $val"
    array["$tag"]="$val"
  done
}



function create_tracks_for_overlay () {
  local variant="$1"
  local -a playlist_ids

  IFS=$'\n' playlist_ids=($(cat_overlay_template | sed -r -e '/playlist *id="playlist/!d; s,.*id="playlist([^"]*)".*,\1,'))

  for track_id in "${playlist_ids[@]}"; do
    create_track_if_none "$variant" "$track_id"
  done
}


function create_track_if_none () {
  local variant="$1"
  local track_id="$2"
  local -n x="$(track_positions_array_name "$variant")"
  if [ '' != "${x["$track_id"]}" ]; then
    return
  fi
  set_track_position "$variant" "$track_id" "0"

  local -A variant_info=()
  variant_info['track_id']="${variant}_${track_id}"
  variant_info['track_variant']="$variant"

  # We do not know the track number yet.
  # Those who write the template can just say @track_number@
  # instead of @track_number_@track_id@@.
  variant_info["track_number"]="@track_number_${variant}_${track_id}@"
  process_foreach "track" "variant_info"
}


function process_foreach () {
  local kind="$1"
  local vars_array_name="$2"
  local temp_path="$generated_mlt_path.pfe.temp"
  touch "$temp_path"

  while grep FOREACH "$generated_mlt_path" > /dev/null; do
    sed "/FOREACH $kind/,\$d" "$generated_mlt_path" > "$temp_path"

    sed "0,/FOREACH $kind/d ; /END FOREACH $kind/,\$d; /REMOVE LINE/d" "$generated_mlt_path" |
      substitute_variables - "$vars_array_name" >> "$temp_path"

    # Put this "x", so we can proceed to the next FOREACH.
    echo "<!-- FORxEACH $kind -->" >> "$temp_path"
    sed "0,/FOREACH $kind/d ; /END FOREACH $kind/,\$d" "$generated_mlt_path" >> "$temp_path"
    echo "<!-- END FORxEACH $kind -->" >> "$temp_path"

    sed "0,/END FOREACH $kind/d" "$generated_mlt_path" >> "$temp_path"
    cp "$temp_path" "$generated_mlt_path"
  done
  sed -i -e "s,FORxEACH $kind,FOREACH $kind," "$generated_mlt_path"
  rm "$temp_path"
}


function insert_into_master_mlt () {
  local variant="$1"
  local temp_path="$generated_mlt_path.iimm.temp"
  local template="${entry_values[template]}"

  local link_target="$generated_dir/${template}_static"
  if [ ! -e "$link_target" ]; then
    ln -s "../../$ASSETS_DIR/$template/${template}_static" "$link_target"
  fi

  before_entry_point child_producers > "$temp_path"
  echo "<!-- Producers (template: $template - $count) -->" >> "$temp_path"
  cat_overlay_template |
    sed '/<producer id=/,$!d' |
      sed '/<tractor/,$d' |
      sed '/<playlist/,/playlist>/d' |
      sed '/<producer.*id="black/,/producer>/d' |
      sed -r -e 's,( id=")([^"]*)("),\1@id@_overlay_\2\3,' |
      sed -r -e 's,( producer=")([^"]*)("),\1@id@_overlay_\2\3,' |
    substitute_variables - "entry_values" >> "$temp_path"
  after_entry_point child_producers >> "$temp_path"

  mv "$temp_path" "$generated_mlt_path"

  local -n x="$(track_positions_array_name "$variant")"
  for track_id in "${!x[@]}"; do
    insert_into_master_mlt_track "$variant" "$track_id"
  done
}

function insert_into_master_mlt_track () {
  local variant="$1"
  local track_id="$2"
  local temp_path="$generated_mlt_path.iimmt.temp"

  before_entry_point "blank_and_producer_${variant}_${track_id}" > "$temp_path"
  insert_blank "$variant" "$track_id" >> "$temp_path"
  insert_tracks "$track_id" >> "$temp_path"
  after_entry_point "blank_and_producer_${variant}_${track_id}" >> "$temp_path"

  substitute_variables "$temp_path" "entry_values" > "$generated_mlt_path"
  rm "$temp_path"

  update_track_positions "$variant" "$track_id"
}

function before_entry_point () {
  sed "/ENTRY POINT.*$1/,\$d" "$generated_mlt_path"
}

function after_entry_point () {
  sed "/ENTRY POINT.*$1/,\$!d" "$generated_mlt_path"
}


function insert_blank () {
  local variant="$1"
  local track_id="$2"
  local difference=$(("$next_position" - "$(get_track_position "$variant" "$track_id")"))
  if [ "$difference" -ge "0" ]; then
    echo "    <blank length='$(mu_to_len "$difference")'/>"
    set_track_position "$variant" "$track_id" "$next_position"
  fi
}

function insert_tracks () {
  local track_id="$1"

  local selector="/<playlist *id=\"playlist$track_id\"/,/playlist>/"
  cat_overlay_template |
    sed "$selector!d" |
    sed -r '/entry/!d' |
    sed -r -e 's,( id=")([^"]*)("),'"\1@id@_overlay_\2\3," |
    sed -r -e 's,( producer=")([^"]*)("),'"\1@id@_overlay_\2\3," |
    substitute_variables - "entry_values"
}

function update_track_positions () {
  local variant="$1"
  local track_id="$2"

  local selector="/<playlist *id=\"playlist$track_id\"/,/playlist>/"
  local -a outs_ins
  IFS=$'\n' outs_ins=($(cat_overlay_template | sed -r "$selector!d" | sed -r '/entry/!d' | sed -r 's,.*in="([^"]*)".*out="([^"]*)".*,\2 \1,'))
  for out_in in "${outs_ins[@]}"; do
    local out in
    IFS=" " read -r out in <<<"$out_in"
    increase_track_position "$variant" "$track_id" "$(len_minus_len_to_mu "$out" "$in")"
  done
}


function cleanup_master_mlt () {
#  while grep FOREACH "$generated_mlt_path"; do
#    sed -i '/FOREACH/,/END FOREACH/d' "$generated_mlt_path"
#  done
true
}

# Very ugly... I am tired!!!
function hack_fix () {
  sed -r -e 's,(<property name="resource">)(.*static/),\1'"$generated_dir"'/\2,' -i "$generated_mlt_path"
  sed -r -e 's,(<track *producer="overlay_track_[^"]*_0"),\1 hide="video",' -i "$generated_mlt_path"
}

function update_track_numbers () {
  local -A vars=()

  # 0: blank
  # 1: main clip at playlist0
  current_track_number="1"
  for v in "${track_variant_names[@]}"; do
   local -n x="$(track_positions_array_name "$v")"
    for track_id in "${!x[@]}"; do
      current_track_number="$(("$current_track_number" + 1))"
      vars["track_number_${v}_${track_id}"]="$current_track_number"
    done
  done

  substitute_variables $generated_mlt_path "vars" -i
}


function substitute_variables () {
  local template="$1"
  local -n xvars="$2"
  local -a sed_params
  shift 2
  if [ '0' == "${#xvars[@]}" ]; then
    return
  fi

  local x
  for x in "${!xvars[@]}"; do
    # TODO: figure the best way to avoid $sep in variable value.
    local sep='`'
    sed_params+=("-e" "s${sep}@$x@${sep}${xvars["$x"]}${sep}g")
  done

  if [ '-' == "$template" ]; then
    sed -r "${sed_params[@]}" "$@"
  else
    sed -r "${sed_params[@]}" "$template" "$@"
  fi
}


function generate_pngs () {
  local template="${entry_values[template]}"
  local html_path="$template/generator.html"

  local stamp_file="$generated_dir/.${count}_${template}.stamp"
  if [ ! -e "$stamp_file" ] \
       || [ "$next_position" -ge "$START_POSITION" \
            -a "$next_position" -le "$END_POSITION" ]; then
    echo "http://localhost:$server_port/$html_path" >&"$png_extractor_input"
    echo "$generated_dir/${count}_${template}" >&"$png_extractor_input"
    for x in "${!entry_values[@]}"; do
      if [ "$x" == 'javascript' ]; then
        echo "${entry_values[$x]}"
      else
        echo "set_value('$x', '$(sed -r -e 's,\\,\\\\,g' -e 's,'\'',\\'\'',g' <<<"${entry_values[$x]}")');"
      fi
    done >&"$png_extractor_input"
    echo '' >&"$png_extractor_input"
    insert_pngs_into_mlt <&"$png_extractor_output"
    touch "$stamp_file"
  else
    echo "===> Skipping PNG generation for $(mu_to_len "$next_position")..." >&2
    # A little hack to avoid building the pngs.
    for png in "$generated_dir/${count}_${template}_"*.png; do
      echo "$(sed "s,^${count}_${template}_,," <<<"$(basename "$png" .png)")" "$png"
    done | insert_pngs_into_mlt
  fi
}


function insert_pngs_into_mlt () {
  local -A variables=()

  while IFS=" " read -r tag png_path; do
    if [ '' == "$tag" ]; then
      break
    fi
    variables["temp_dir"]='generated'
    variables["$tag"]="$png_path"
    variables["$tag"_hash]=$(get_md5sum "$png_path")
  done
  substitute_variables "$generated_mlt_path" "variables" -i
}


function get_mlt_length () {
  local mlt_path="$1"
  grep -E 'producer id="black"' "$mlt_path" | sed -r -e 's,.*out="([^"]*)".*,\1,'
}


ONE_FRAME=17 #"$((1000 / "$FPS"))"
function len_plus_frame () {
  local len="$1"
  shift 1
  local mu="$(("$(len_to_mu "$len")" + "$ONE_FRAME" * ("$@")))"
  mu_to_len "$mu"
}

function len_to_mu () {
  local len="00:00:$1"
  local mu="$(echo "$len" | sed -r -e "s,.*[.](...)$,\1,")"
  local ss="$(echo "$len" | sed -r -e "s,.*(..)[.].*,\1,")"
  local mm="$(echo "$len" | sed -r -e "s,.*(..):..[.].*,\1,")"
  local hh="$(echo "$len" | sed -r -e "s,.*(..):..:..[.].*,\1,")"

  echo "$(("10#$mu" + 1000 * "10#$ss" + 1000 * 60 * "10#$mm" + 1000 * 60 * 60 * "10#$hh"))"
}

function mu_to_len () {
  local r="$(("$@"))"
  local mu="00$(("$r" % 1000))"
  r="$(("$r" / 1000))"
  local ss="0$(("$r" % 60))"
  r="$(("$r" / 60))"
  local mm="0$(("$r" % 60))"
  r="$(("$r" / 60))"
  local hh="0$(("$r" % 60))"
  r="$(("$r" / 60))"

  echo "${hh: -2}:${mm: -2}:${ss: -2}.${mu: -3}"
}

function len_minus_len_to_mu () {
  local from="$(len_to_mu "$1")"
  local to="$(len_to_mu "$2")"
  echo "$(("$from" - "$to"))"
}


function get_md5sum () {
  md5sum "$1" | sed -e 's, .*,,'
}



function cat_overlay_template () {
  local template="${entry_values[template]}"

  local -a stub_files=("$ASSETS_DIR/$template/stub"/*.png)

  local -a sed_args

  local x
  for x in "${stub_files[@]}"; do
    local tag="$(basename "$x" .png)"
    local md5="$(get_md5sum "$x")"

    sed_args+=(-e "s,>stub/$tag.png<,>@$tag@<,g")
    sed_args+=(-e "s,>$md5<,>@${tag}_hash@<,g")
  done

  if [ '' != "$sed_args" ]; then
    sed -r "${sed_args[@]}" "$ASSETS_DIR/$template/$template.mlt"
  else
    cat "$ASSETS_DIR/$template/$template.mlt"
  fi
}



#
# Manage track variants.
# Each variat has a list of tracks.
# Each item of this list is the next starting point for the track.
#

function track_positions_array_name () {
  local variant="$1"
  echo "track_variant_positions_$variant"
}

function init_tracks () {
  declare -g -a track_variant_names=("$@")
  for v in "${track_variant_names[@]}"; do
    declare -a "$(track_positions_array_name "$v")"
  done
}

function get_track_position () {
  local variant="$1"
  local track_id="$2"
  local -n x="$(track_positions_array_name "$variant")"
  echo "${x["$track_id"]}"
}

function set_track_position () {
  local variant="$1"
  local track_id="$2"
  local pos="$3"
  local -n x="$(track_positions_array_name "$variant")"
  x["$track_id"]="$pos"
}

function increase_track_position () {
  local variant="$1"
  local track_id="$2"
  local plus_mu="$3"
  local curr_pos="$(get_track_position "$variant" "$track_id")"

  set_track_position "$variant" "$track_id" "$(("$curr_pos" + "$plus_mu"))"
}

function pick_up_a_track_variant_for_position () {
  local mu="$1"

  for v in "${track_variant_names[@]}"; do
    local x="track_variant_positions_${v}[@]"
    for pos in "${!x}"; do
      if [ "$pos" -gt "$mu" ]; then
        # This track overlaps.
        continue 2
      fi
    done
    # No overlaping track in this variant.
    echo "$v"
    return
  done
  echo "Too many overlapping layers!" >&2
  exit 1
}




