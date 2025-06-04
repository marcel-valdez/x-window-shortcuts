#!/bin/bash

# This script retrieves a list of open windows using wmctrl,
# formats the information to include app icons and titles for Rofi's dmenu mode,
# and then activates the selected window.

# --- Prerequisites ---
# - wmctrl: Install with `sudo apt install wmctrl`
# - rofi:   Install with `sudo apt install rofi`
# - An icon theme configured for your system (e.g., Papirus, Adwaita)
#   Ensure Rofi is set up to display icons in your theme config (e.g., ~/.config/rofi/config.rasi)

# set -euo pipefail # Uncomment for stricter error checking and pipeline behavior

readonly ACTIVE_WINDOW_LOG_FILE="/tmp/x-current-active-window.log"

# Retrieves the window ID of the previously focused window.
function get_prev_focused_window_id {
	if [[ -f "${ACTIVE_WINDOW_LOG_FILE}" ]]; then
		# Get the second to last line from the log file.
		# `tail -n 2 | head -n 1` is a standard and generally efficient way for this.
		local line
		tail -n 2 "${ACTIVE_WINDOW_LOG_FILE}" | head -n 1
	fi
}

# File generated using window-watcher-daemon.sh which contains an associative array of
# [<window class name>] = <icon name>
readonly GEN_APP_ICONS_FILE="/tmp/app_icons.sh"
readonly USER_APP_ICONS_FILE="${HOME}/.config/x-window-shortcuts/USER_ICONS.sh"

# Associative array for WM_CLASS values to ignore.
declare -A IGNORED_WM_CLASSES=(
	["xfce4-panel"]=1
	["conky-semi"]=1
	["xfdesktop"]=1
	["xfce4-notifyd"]=1
)

# Associative array for known WM_CLASS to icon name mappings.
# For best performance and icon accuracy, ensure this list is comprehensive for your apps.
declare -A KNOWN_ICONS=(
	["navigator"]="firefox"
	["google-chrome"]="google-chrome"
	["google-chrome-stable"]="google-chrome"
	["chromium"]="chromium"
	["chromium-browser"]="chromium"
	["thunderbird"]="thunderbird"
	["code"]="visual-studio-code"
	["gnome-terminal"]="utilities-terminal"
	["konsole"]="utilities-terminal"
	["xterm"]="utilities-terminal"
	["alacritty"]="utilities-terminal"
	["kitty"]="utilities-terminal"
	["discord"]="discord"
	["slack"]="slack"
	["libreoffice"]="libreoffice-writer"    # Example: specific app like writer
	["libreoffice-calc"]="libreoffice-calc" # Add other libreoffice apps if needed
	["libreoffice-impress"]="libreoffice-impress"
	["nautilus"]="folder" # Or "org.gnome.Nautilus" depending on wmctrl output
	["vlc"]="vlc"
	["gimp"]="gimp"
	["inkscape"]="inkscape"
	["org.wezfurlong.wezterm"]="org.wezfurlong.wezterm"
	# Add more entries here, e.g., ["Spotify"]="spotify"
  ["xfce4-backdrop-settings"]="org.xfce.xfdesktop"
  ["xfce4-workspaces-settings"]="org.xfce.workspaces"
  ["xfce4-session-settings"]="org.xfce.session"
  ["xfce4-wmtweaks-settings"]="org.xfce.xfwm4-tweaks"
  ["xfce4-settings-manager"]="org.xfce.settings.manager"
  ["xfce4-display-settings"]="org.xfce.settings.display"
  ["xfce4-mouse-settings"]="org.xfce.settings.mouse"
  ["xfce4-keyboard-settings"]="org.xfce.settings.keyboard"
  ["xfce4-wm-settings"]="org.xfce.xfwm4"
  ["xfce4-ui-settings"]="org.xfce.settings.appearance"
)

if [ -f "${USER_APP_ICONS_FILE}" ]; then
  source "${USER_APP_ICONS_FILE}"
else
  declare -A USER_ICONS
fi

if [ -f "${GEN_APP_ICONS_FILE}" ]; then
	source "${GEN_APP_ICONS_FILE}"
else
	declare -A GEN_APP_ICONS
fi

# Optimized function to get icon name.
# Relies on KNOWN_ICONS and GEN_APP_ICONS, falling back to short class name.
# Removed slow filesystem searches for .desktop files to meet performance goals.
function get_icon_name {
  if [[ -z "${ICONS_ENABLED}" ]]; then
    echo ""
    return 0
  fi
	local short_class_name="$1" # Expected to be lowercased
	local full_class_name="$2"  # Original case from wmctrl
	local icon_name

  # 1. Check if the user overrode the icon name. (takes precedence)
	if [[ -n "${USER_ICONS[${full_class_name}]}" ]]; then
    icon_name="${USER_ICONS[${full_class_name}]}"
  # 2. Check if we found the icon name in .desktop files in the system.
	elif [[ -n "${GEN_APP_ICONS[${full_class_name}]}" ]]; then
		icon_name="${GEN_APP_ICONS[${full_class_name}]}"
    USER_ICONS["${full_class_name}"]="${icon_name}"  # optimization
  # 3. Check if we have the icon name hardcoded.
  elif [[ -n "${KNOWN_ICONS[${full_class_name}]}" ]]; then
    icon_name="${KNOWN_ICONS[${full_class_name}]}"
    USER_ICONS["${full_class_name}"]="${icon_name}"  # optimization
  else
		# 4. Fallback: Use the short class name directly.
		icon_name="${short_class_name}"
    USER_ICONS["${full_class_name}"]="${icon_name}"  # optimization
	fi

	echo "${icon_name}"
}

function get_icon_img {
  locate "$1" | grep -E ".*/share/icons/.*(png|jpg|svg)$" | head -1
}

# Get window list from wmctrl.
readonly WMCTRL_OUTPUT=$(wmctrl -l -x)

# Initialize an empty array for Rofi entries.
WINDOW_ENTRIES=()

# Get current desktop ID.
# The original script used `wmctrl -j`, which is non-standard.
# This provides a fallback to a common method, then to 0.
CURRENT_DESKTOP_RAW="$(wmctrl -j 2>/dev/null)"
if [[ -z "${CURRENT_DESKTOP_RAW}" || ! "${CURRENT_DESKTOP_RAW}" =~ ^[0-9]+$ ]]; then
	CURRENT_DESKTOP_RAW="$(wmctrl -d | awk '/\*/ {print $1; exit}')"
fi
if [[ -z "${CURRENT_DESKTOP_RAW}" || ! "${CURRENT_DESKTOP_RAW}" =~ ^[0-9]+$ ]]; then
	CURRENT_DESKTOP_RAW="0"
fi

readonly CURRENT_DESKTOP="${CURRENT_DESKTOP_RAW}"

# Get the ID of the previously focused window.
readonly PREV_WINDOW_ID=$(get_prev_focused_window_id)

# Process wmctrl output line by line.
while IFS= read -r line; do
	# Efficiently parse the line using Bash's read.
	# Format: <window_id> <desktop_id> <WM_CLASS> <hostname> <Title>
	# _host_ignored is used to consume the hostname field.
	# shellcheck disable=SC2162 # We want word splitting for read here.
	read -r window_id wm_desktop wm_class_full _host_ignored window_title <<<"${line}"

	# Skip potentially malformed lines from wmctrl.
	if [[ -z "${window_id}" || -z "${wm_class_full}" ]]; then
		continue
	fi

	# Preserve original full class name for cache key and IGNORED_WM_CLASSES lookup.
	original_wm_class_for_check="${wm_class_full}"

	# Normalize WM_CLASS names using a single sed process for efficiency.
	# Rule 1 (case-insensitive): "Name.Name" -> "Name" (e.g., "Firefox.Firefox" -> "Firefox")
	# Rule 2 (case-sensitive): "crx_....Google-chrome" -> "chrome-...-Default"
	wm_class_full=$(echo "${wm_class_full}" | sed -E \
		-e 's/^(.*)\.\1$/\1/I' \
		-e 's/^crx_([^\.]+)\.Google-chrome$/chrome-\1-Default/')

	# Check if this WM_CLASS should be ignored (check original and normalized).
	if [[ -n "${IGNORED_WM_CLASSES[${original_wm_class_for_check}]}" || -n "${IGNORED_WM_CLASSES[${wm_class_full}]}" ]]; then
		continue
	fi

	# Adjust desktop ID for windows shown on all desktops (-1).
	# These should appear as if they are on the current desktop for filtering purposes.
	if [[ "${wm_desktop}" -eq -1 ]]; then
		wm_desktop="${CURRENT_DESKTOP}"
	fi

	# Extract the short WM_CLASS name (e.g., "Navigator.Firefox" -> "firefox").
	# Uses Bash string manipulation for speed.
	_short_class_part="${wm_class_full%%.*}" # Get part before first '.'
	_wm_class_short="${_short_class_part,,}" # Convert to lowercase

	_icon_name=$(get_icon_name "${_wm_class_short}" "${wm_class_full}") # Pass original (potentially normalized) full_class_name

	# Construct the Rofi entry string. Desktop numbers from wmctrl are 0-indexed.
	# Adding 1 for display and matching Rofi filter, as in the original script.
	_display_desktop_num=$((wm_desktop + 1))
	_window_window_entry_text="${_display_desktop_num} ${window_title} (${window_id})"
	# Rofi expects specific format for icons: "text\0icon\x1ficon_name"
  if [[ "${_icon_name}" ]]; then
    _window_entry="$(wezterm imgcat --height 1 $(locate ${_icon_name} | grep -E "/share/icons/.*(png|jpg|svg)" | head -1))\\\t${_window_window_entry_text}\0"
  else
    _window_entry="${_window_window_entry_text}"
  fi

	# Prepend if it's the previously focused window to make it appear higher (or first).
	if [[ ${PREV_WINDOW_ID} -eq ${window_id} ]]; then
		WINDOW_ENTRIES=("${_window_entry}" "${WINDOW_ENTRIES[@]}")
	else
		WINDOW_ENTRIES+=("${_window_entry}")
	fi
done <<<"${WMCTRL_OUTPUT}"

# Check if there are any windows to display.
if [[ ${#WINDOW_ENTRIES[@]} -eq 0 ]]; then
	echo "No windows found to display in Rofi." >&2
	exit 0
fi

# Note: `printf "%b\n"` is used to interpret backslash escapes like \0 and \x1f.
_filter_string="^$((CURRENT_DESKTOP + 1)) "
SELECTED_LINE=$(printf "%b\n" "${WINDOW_ENTRIES[@]}" | \
  fzf --no-sort --prompt "Window: " --query "${_filter_string}"\
  --preview='${HOME}/modules/x-window-shortcuts/draw_border_around_window.py -w $(echo {} | grep -oP "0x[0-9a-fA-F]+")'\
  --preview-window=up,0%
)

# Check if a selection was made.
if [[ -n "${SELECTED_LINE}" ]]; then
	# Extract the window ID from the selected line using Bash regex.
	# The ID is expected to be in parentheses, e.g., "... (0x12345678)".
	if [[ "${SELECTED_LINE}" =~ \((0x[0-9a-fA-F]+)\) ]]; then
		wmctrl -ia "${BASH_REMATCH[1]}"
	else
		echo "Error: Could not extract window ID from selected line: '${SELECTED_LINE}'" >&2
		exit 1
	fi
else
	echo "Window selection cancelled or Rofi closed." >&2
	# exit 1 # Optionally exit with a different code on cancel
fi
