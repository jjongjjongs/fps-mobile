#!/usr/bin/env bash
set -euo pipefail

game_version=$(cat release-version.txt)
[[ "$game_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
IFS=. read -r major minor patch <<<"$game_version"
(( minor < 1000 && patch < 1000 ))
code=$((major*1000000+minor*1000+patch))
(( code > 1 && code <= 2100000000 ))

# Use the upstream release template for the production build.
version=4.7.2
tag="$version-stable"
editor="Godot_v${tag}_linux.x86_64"
templates="Godot_v${tag}_export_templates.tpz"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
base="https://github.com/godotengine/godot-builds/releases/download/$tag"

for asset in "$editor.zip" "$templates" SHA512-SUMS.txt; do
  curl --fail --silent --show-error --location --retry 3 "$base/$asset" -o "$work/$asset"
done
(
  cd "$work"
  for asset in "$editor.zip" "$templates"; do
    awk -v file="$asset" '$2 == file || $2 == "*" file {print}' SHA512-SUMS.txt > check
    test -s check
    sha512sum -c check
  done
  unzip -qo "$editor.zip"
)
godot="$work/$editor"
chmod +x "$godot"
install_dir="$HOME/.local/share/godot/export_templates/$version.stable"
mkdir -p "$install_dir" "$HOME/.config/godot" build/unsigned
unzip -p "$work/$templates" templates/android_release.apk > "$install_dir/android_release.apk"
test -s "$install_dir/android_release.apk"
cat > "$HOME/.config/godot/editor_settings-4.7.tres" <<SETTINGS
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$ANDROID_HOME"
export/android/java_sdk_path = "$JAVA_HOME"
SETTINGS

"$godot" --headless --editor --import
XDG_DATA_HOME="$work/smoke-user" "$godot" --headless --fixed-fps 60 --script tests/smoke.gd
XDG_DATA_HOME="$work/arena-user" "$godot" --headless --fixed-fps 60 --script tests/arena.gd
tools_dir=$(dirname "$(find "$ANDROID_HOME/build-tools" -name apksigner | sort -V | tail -1)")
test -x "$tools_dir/zipalign"
sed -i "s|^version/code=.*|version/code=$code|" export_presets.cfg
export_apk() {
  local stem="$1"
  "$godot" --headless --export-release Android "$work/$stem-raw.apk"
  "$tools_dir/zipalign" -P 16 -f 4 "$work/$stem-raw.apk" "$work/$stem.apk"
}
verify_package() {
  local apk="$1" package="$2"
  "$tools_dir/zipalign" -c -P 16 4 "$apk"
  "$tools_dir/aapt" dump badging "$apk" > "$work/manifest"
  grep -Fq "package: name='$package'" "$work/manifest"
  grep -Fq "versionName='$game_version'" "$work/manifest"
  grep -Eq "^native-code: 'arm64-v8a' *$" "$work/manifest"
  grep -Fq 'android.permission.INTERNET' "$work/manifest"
  grep -Fq 'android.permission.REQUEST_INSTALL_PACKAGES' "$work/manifest"
  if grep -q '^application-debuggable' "$work/manifest"; then exit 1; fi
}

export_apk production
cp "$work/production.apk" build/unsigned/VectorRange-unsigned.apk
verify_package build/unsigned/VectorRange-unsigned.apk com.jjongjjongs.vectorrange
(cd build/unsigned && sha256sum *.apk > SHA256SUMS.txt)

# Build a disposable lower-version app to exercise the first in-app upgrade against
# the published 0.3.0. The release above contains no test driver.
mkdir -p build/probe
sed -i 's|^version/code=.*|version/code=2999|;s|^version/name=.*|version/name="0.2.999"|' export_presets.cfg
sed -i 's|^config/version=.*|config/version="0.2.999"|' project.godot
sed -i 's|/releases/latest"|/releases/tags/v0.3.0"|' game/updater.gd
python3 - <<'PYPROBE'
from pathlib import Path
p=Path("game/range.gd")
p.write_text(p.read_text().replace("func _ready():", 'func _ready():\n\tcall_deferred("run_upgrade_probe")', 1))
PYPROBE
cat ci/probe.gd.inc >> game/range.gd
export_apk probe
cp "$work/probe.apk" build/probe/input.apk
