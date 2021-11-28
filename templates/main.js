var original_html = document.body.innerHTML;

function init_template () {
  document.body.innerHTML = original_html;
  document.body.style.backgroundImage = 'none';
  if(MathJax.typeset) MathJax.typeset();
}

img_regexp = /@inline_image:([^@]*)@/g
function set_value (key, val) {
  val = val.replaceAll(img_regexp, '<img src="../images/$1.svg" class="inline_image"/>');
  var e = document.body;
  e.innerHTML = e.innerHTML.replace('@' + key + '@', val);
  if(MathJax.typeset) MathJax.typeset();
}

var pieces = [];
function declare_piece (...keys) {
  pieces.push(...keys);
}

function hide_all () {
  for (e of document.getElementsByClassName('background')) {
    e.style.visibility = 'hidden';
  }
  for (e of document.getElementsByClassName('foreground')) {
    e.style.visibility = 'hidden';
  }
}

function background_only (key) {
  hide_all();
  document.getElementById('bg_' + key).style.visibility = 'visible';
}

function foreground_only (key) {
  hide_all();
  document.getElementById('fg_' + key).style.visibility = 'visible';
}

function overlap (key=1) {
  document.body.classList.add('overlap_' + key);
}

function lower () {
  document.body.classList.add('lower');
}

function create_image(image_file, ...class_names) {
  var img = document.createElement('img');
  img.classList.add(...class_names);
  img.src = '../images/' + image_file + '.svg';
  return img;
}

function prepend_image(parent_id, image_file, ...class_names) {
  class_names.push('prepended_image');
  var img = create_image(image_file, ...class_names);
  document.getElementById('fg_' + parent_id).prepend(img);
}

function append_image(parent_id, image_file, ...class_names) {
  class_names.push('appended_image');
  var img = create_image(image_file, ...class_names);
  document.getElementById('fg_' + parent_id).append(img);
}

function image_above(parent_id, image_file, ...class_names) {
  class_names.push('image_above');
  var img = create_image(image_file, ...class_names);
  var parent = document.getElementById('fg_' + parent_id);
  parent.classList.add('has_image_above');
  parent.prepend(img);
}

