#!/bin/zsh
# Records a demo scene with Godot's movie writer while its DemoAutopilot plays it, and turns the result into an
# mp4 plus a contact sheet of stills to look over.
#
#   tools/record_demo.sh res://addons/3d_player_controller/scenes/demo/zelda/zelda_demo.tscn 60 out/zelda
#
# Arguments: the scene, the seconds to record, the output path without extension. Needs ffmpeg on the PATH.
export PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin
set -eu
SCENE=$1
SECONDS_TO_RECORD=$2
OUT=$3
FPS=30
GODOT=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
cd "$(dirname "$0")/.."
mkdir -p "$(dirname "$OUT")"
rm -f "$OUT.avi"
"$GODOT" --path . --write-movie "$OUT.avi" --fixed-fps $FPS --quit-after $((SECONDS_TO_RECORD * FPS)) "$SCENE" -- --autopilot > "$OUT.log" 2>&1 || true
ffmpeg -y -loglevel error -i "$OUT.avi" -c:v libx264 -pix_fmt yuv420p -crf 22 -c:a aac "$OUT.mp4"
ffmpeg -y -loglevel error -i "$OUT.mp4" -vf "fps=1/5,scale=426:-1,tile=4x4" -frames:v 1 "$OUT.sheet.png"
rm -f "$OUT.avi"
echo "wrote $OUT.mp4 and $OUT.sheet.png"
