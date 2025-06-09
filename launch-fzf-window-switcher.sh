#!/usr/bin/env bash

pkill -f 'x-window-shortcuts/draw_border_around_window.py' &
kill_border=$!
pkill -f 'x-window-shortcuts/fzf-window-switcher.sh' &
kill_switcher=$!

# NOTE: This function call is behaving as a sleep 0.01 as well, if you remove
# this line then you'll have to put in a sleep 0.01
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

wait "${kill_border}" "${kill_switcher}"

export WEZTERM_WINDOW_SWITCHER_MODE=1
# We use termit because it starts up faster than wezterm.
termit --role="GDK_WINDOW_TYPE_HINT_POPUP_MENU" --class="window-switcher" -e "${SCRIPT_DIR}/fzf-window-switcher.sh" --init="${SCRIPT_DIR}/termit_config.lua"

# Sleep 10 milliseconds to wait for the last draw border process to start
sleep 0.01

exec pkill -f 'x-window-shortcuts/draw_border_around_window.py'
