#!/usr/bin/env bash
log_file=/tmp/x-current-active-window.log

function build_icon_map {
  echo "declare -A APP_ICONS=(" >/tmp/app_icons.sh
  find /usr/share/applications "${HOME}/.local/share/applications/" -name "*.desktop" -exec bash -c 'icon_name=$(grep -oP "(?<=Icon=).*" "$1"); if [ -n "$icon_name" ]; then printf "[\"%s\"]=\"%s\"\n" "$(basename $1 | sed -e 's/\.desktop//')" "$icon_name"; fi' _ {} \; >>/tmp/app_icons.sh
  echo ")" >>/tmp/app_icons.sh
}

build_icon_map

xprop -spy -root _NET_ACTIVE_WINDOW | \
  while IFS= read -r window_event; do
    echo ${window_event}
    focused_window_id=$(xprop -root _NET_ACTIVE_WINDOW | cut -d' ' -f5 | cut -d',' -f1)
    
    prev_focused_window_id=
    if [[ -f "${log_file}" ]]; then
      prev_focused_window_id=$(tail -1 "${log_file}")
    fi

    if [[ "${focused_window_id}" != "${prev_focused_window_id}" ]]; then
      echo "${focused_window_id}" >> /tmp/x-current-active-window.log
    fi
done 
