#!/usr/bin/env bash

pkill -f '/modules/x-window-shortcuts/draw_border_around_window.py' &
pkill -f '/modules/x-window-shortcuts/fzf-window-switcher.sh' &

sleep 0.01

export WEZTERM_WINDOW_SWITCHER_MODE=1
wezterm start --class "window-switcher" -e "${HOME}/modules/x-window-shortcuts/fzf-window-switcher.sh"

sleep 0.01

exec pkill -f '/modules/x-window-shortcuts/draw_border_around_window.py'
