#!/usr/bin/env bash
# Shows each .screen file from docs/screenshot-fixtures.sh in a real Ghostty
# window and saves the window as $DEST/<name>.png. It needs Hyprland, grim and ImageMagick,
# and each window flashes on the current workspace for about a second.
set -e
SRC=${1:?screen dir}
DEST=${2:?png dir}
CLASS=sonar.shot

# We float the capture windows and turn off the theme's transparency, rounded
# corners, border and open animation, so the PNG holds only the terminal. The
# rule lasts until Hyprland reloads its config, and it matches only our class.
hyprctl eval 'hl.window_rule({ match = { class = "^sonar\\.shot$" }, float = true, center = true,
  opacity = "1 1", rounding = 0, border_size = 0, no_anim = true, no_shadow = true })' >/dev/null

client() { # prints "pid x y w h" for our window, or fails when it is not open
  hyprctl clients -j | python3 -c '
import json, sys
c = [c for c in json.load(sys.stdin) if c["class"] == sys.argv[1]]
if not c: sys.exit(1)
print(c[0]["pid"], *c[0]["at"], *c[0]["size"])' "$CLASS"
}

shot() { # $1 name, $2 columns
  local pid x y w h i
  # The window prints nothing until the terminal is $2 or $2 + 1 columns wide.
  # Otherwise the 140-column bar wraps in a window that is one cell short.
  setsid -f ghostty --gtk-single-instance=false --class="$CLASS" --font-size=12 \
    --cursor-style-blink=false -e bash -c \
    'until c=$(stty size); (( ${c#* } == $2 || ${c#* } == $2 + 1 )); do sleep 0.1; done
     clear; cat "$1"; exec sleep 30' \
    _ "$SRC/$1.screen" "$2" >/dev/null 2>&1
  for (( i = 0; i < 50; i++ )); do read -r pid x y w h < <(client) && break; sleep 0.2; done
  [[ -n $pid ]] || { echo "no window for $1" >&2; return 1; }
  # Ghostty's --window-width comes out a few cells short under Hyprland, so we
  # size the window in pixels. A cell at 12 pt is about 9.72 px wide and 24.6 px
  # tall, and the padding adds 28 px. Twelve rows leave room for wrapped prompts.
  hyprctl dispatch "hl.dsp.window.resize({ x = $(( 28 + $2 * 972 / 100 + 4 )), y = $(( 28 + 12 * 246 / 10 )), window = \"pid:$pid\" })" >/dev/null
  hyprctl dispatch "hl.dsp.window.center({ window = \"pid:$pid\" })" >/dev/null 2>&1 || true
  sleep 0.5
  read -r pid x y w h < <(client)
  # Ghostty draws its first frame a little after the window maps.
  sleep 1
  grim -g "$x,$y ${w}x$h" "$SRC/$1.raw.png"
  kill "$pid"
  while client >/dev/null; do sleep 0.1; done
  # The window has more rows than the screen text, so we cut the empty rows off the
  # bottom and keep the full width, which shows how wide the pane was.
  local bbox top pad
  # We shave the outer pixels first, because a stray edge pixel stops the trim.
  bbox=$(magick "$SRC/$1.raw.png" -shave 8x8 -fuzz 3% -trim -format '%h %Y' info:)
  read -r h top <<< "$bbox"
  top=$(( top + 8 )) pad=$top
  magick "$SRC/$1.raw.png" -crop "x$(( top + h + pad ))+0+0" +repage "$DEST/$1.png"
}

shot flow 140
shot trouble 140
shot calm 140
shot worktree-72 72
