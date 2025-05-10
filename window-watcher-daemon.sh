#!/usr/bin/env bash
log_file=/tmp/x-current-active-window.log
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
