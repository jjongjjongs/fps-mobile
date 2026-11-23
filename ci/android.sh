#!/usr/bin/env bash
set -euo pipefail

# The release template is shared by the installable preview and the production build.
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
mkdir -p "$install_dir" "$HOME/.config/godot" build/preview build/unsigned
unzip -p "$work/$templates" templates/android_release.apk > "$install_dir/android_release.apk"
test -s "$install_dir/android_release.apk"
cat > "$HOME/.config/godot/editor_settings-4.7.tres" <<SETTINGS
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$ANDROID_HOME"
export/android/java_sdk_path = "$JAVA_HOME"
SETTINGS

"$godot" --headless --editor --import
XDG_DATA_HOME="$work/smoke-user" "$godot" --headless --script tests/smoke.gd
tools_dir=$(dirname "$(find "$ANDROID_HOME/build-tools" -name apksigner | sort -V | tail -1)")
test -x "$tools_dir/zipalign"
# The ephemeral checkout carries the run number; the committed preset is unchanged.
sed -i "s/^version\/code=1$/version\/code=${GITHUB_RUN_NUMBER:-1}/" export_presets.cfg
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
  grep -Fq "versionName='0.1.0'" "$work/manifest"
  grep -Eq "^native-code: 'arm64-v8a' *$" "$work/manifest"
  if grep -q '^application-debuggable' "$work/manifest"; then exit 1; fi
}

export_apk production
cp "$work/production.apk" build/unsigned/VectorRange-unsigned.apk
verify_package build/unsigned/VectorRange-unsigned.apk com.jjongjjongs.vectorrange
sed -i 's/^package\/unique_name="com.jjongjjongs.vectorrange"$/package\/unique_name="com.jjongjjongs.vectorrange.preview"/;s/^package\/name="Vector Range"$/package\/name="Vector Range Preview"/' export_presets.cfg
export_apk preview

# Never use this single-run test identity for the production package.
keytool -genkeypair -noprompt -keystore "$work/preview.p12" -storetype PKCS12 \
  -storepass android -keypass android -alias preview -keyalg RSA -keysize 2048 \
  -validity 365 -dname "CN=Vector Range Preview"
"$tools_dir/apksigner" sign --ks "$work/preview.p12" --ks-pass pass:android \
  --ks-key-alias preview --out build/preview/VectorRange-preview.apk "$work/preview.apk"
"$tools_dir/apksigner" verify --verbose build/preview/VectorRange-preview.apk
verify_package build/preview/VectorRange-preview.apk com.jjongjjongs.vectorrange.preview
for dir in build/preview build/unsigned; do
  (cd "$dir" && sha256sum *.apk > SHA256SUMS.txt)
done
