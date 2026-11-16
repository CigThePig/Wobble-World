#!/usr/bin/env bash
set -euo pipefail
version=4.6.1
base="https://github.com/godotengine/godot-builds/releases/download/$version-stable"
folder="${RUNNER_TEMP:-/tmp}/wobble-godot"
mkdir -p "$folder"
curl -fL --retry 3 "$base/Godot_v$version-stable_linux.x86_64.zip" -o "$folder/editor.zip"
unzip -qo "$folder/editor.zip" -d "$folder"
chmod +x "$folder/Godot_v$version-stable_linux.x86_64"
echo "GODOT=$folder/Godot_v$version-stable_linux.x86_64" >> "$GITHUB_ENV"
if [[ ${1:-} == templates ]]; then
  curl -fL --retry 3 "$base/Godot_v$version-stable_export_templates.tpz" -o "$folder/templates.tpz"
  unzip -qo "$folder/templates.tpz" -d "$folder"
  mkdir -p "$HOME/.local/share/godot/export_templates/$version.stable"
  mv "$folder/templates/"* "$HOME/.local/share/godot/export_templates/$version.stable/"
fi
