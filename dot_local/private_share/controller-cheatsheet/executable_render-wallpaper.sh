#!/bin/bash
set -euo pipefail

# Render controller-cheatsheet HTML and produce two artifacts:
#   1. Wallpaper composite (timestamped filename so xfdesktop sees a new path
#      each run and reloads — its per-path cache otherwise ignores same-path
#      content changes). Set as XFCE desktop background.
#   2. Standalone fullscreen image at 4K for the Sunshine "Controller Help"
#      app (matches monitor resolution for crisp display, no upscaling).
#
# Base wallpaper resolution order:
#   1. $BASE_WALLPAPER env var (manual override)
#   2. Current XFCE wallpaper, IF it is not one of our timestamped composites
#   3. Saved sidecar (~/.config/controller-cheatsheet/base.path) from prior run
#   4. EndeavourOS default

CHEAT_DIR="$HOME/.local/share/controller-cheatsheet"
HTML="$CHEAT_DIR/cheatsheet.html"
PROFILE="$CHEAT_DIR/firefox-profile"
RENDER_HTML="$CHEAT_DIR/cheatsheet-render.html"
RENDERED="$CHEAT_DIR/cheatsheet.png"
TRIMMED="$CHEAT_DIR/cheatsheet-trimmed.png"
SCALED="$CHEAT_DIR/cheatsheet-scaled.png"

OUT_DIR="$HOME/Pictures"
WALLPAPER_PREFIX="wallpaper-with-cheatsheet-"
TS=$(date +%s)
WALLPAPER_OUT="$OUT_DIR/${WALLPAPER_PREFIX}${TS}.png"
FULLSCREEN_OUT="$OUT_DIR/cheatsheet-fullscreen.png"

CONFIG_DIR="$HOME/.config/controller-cheatsheet"
BASE_PATH_FILE="$CONFIG_DIR/base.path"
DEFAULT_BASE="/usr/share/endeavouros/backgrounds/endeavouros-wallpaper.png"

SCALE="${WALLPAPER_SCALE:-2}"
FS_SIZE="${FULLSCREEN_SIZE:-3840x2160}"

mkdir -p "$CONFIG_DIR" "$OUT_DIR" "$PROFILE"

resolve_base() {
    if [[ -n "${BASE_WALLPAPER:-}" ]]; then
        echo "$BASE_WALLPAPER"
        return
    fi
    while IFS= read -r prop; do
        local v
        v=$(xfconf-query -c xfce4-desktop -p "$prop" 2>/dev/null || true)
        if [[ -f "$v" && "$v" != *"wallpaper-with-cheatsheet"* ]]; then
            echo "$v" > "$BASE_PATH_FILE"
            echo "$v"
            return
        fi
    done < <(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep "/last-image$")
    if [[ -f "$BASE_PATH_FILE" ]]; then
        local saved
        saved=$(<"$BASE_PATH_FILE")
        [[ -f "$saved" ]] && { echo "$saved"; return; }
    fi
    echo "$DEFAULT_BASE"
}

BASE=$(resolve_base)
[[ -f "$HTML" ]] || { echo "missing: $HTML" >&2; exit 1; }
[[ -f "$BASE" ]] || { echo "missing base wallpaper: $BASE" >&2; exit 1; }

echo "[base] $BASE"

echo "[1/4] Rendering HTML via firefox headless..."
sed "s|background: #0a0a0a;|background: transparent;|" "$HTML" > "$RENDER_HTML"
firefox --headless --no-remote --profile "$PROFILE" \
    --screenshot "$RENDERED" \
    --window-size=820,1200 \
    "file://$RENDER_HTML" 2>/dev/null

echo "[2/4] Trimming transparent margins..."
magick "$RENDERED" -trim +repage "$TRIMMED"

echo "[3/4] Compositing wallpaper variant (scale=${SCALE}x)..."
magick "$TRIMMED" -resize "$((100*SCALE))%" "$SCALED"
magick "$BASE" "$SCALED" -gravity southeast -geometry +40+40 -composite "$WALLPAPER_OUT"

echo "[4/4] Building fullscreen variant ($FS_SIZE)..."
fs_h=$(echo "$FS_SIZE" | cut -dx -f2)
fs_h_target=$(awk -v h="$fs_h" 'BEGIN { print int(h * 0.98) }')
magick "$TRIMMED" \
    -resize "x${fs_h_target}" \
    -background "#0a0a0a" -gravity center -extent "$FS_SIZE" \
    "$FULLSCREEN_OUT"

echo "[set] Applying as XFCE wallpaper..."
mapfile -t props < <(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep "/last-image$")
for p in "${props[@]}"; do
    xfconf-query -c xfce4-desktop -p "$p" -s "$WALLPAPER_OUT"
done
echo "  Set on ${#props[@]} XFCE backdrop slot(s)"

# Belt-and-suspenders refresh: signal xfdesktop and clean up old composites.
DISPLAY=":0" xfdesktop --reload 2>/dev/null || true
find "$OUT_DIR" -maxdepth 1 -name "${WALLPAPER_PREFIX}*.png" ! -name "$(basename "$WALLPAPER_OUT")" -delete 2>/dev/null || true

echo "Done:"
echo "  Base:       $BASE"
echo "  Wallpaper:  $WALLPAPER_OUT"
echo "  Fullscreen: $FULLSCREEN_OUT"
