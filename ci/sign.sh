#!/usr/bin/env bash
set -euo pipefail
umask 077
keydir=$(mktemp -d)
trap 'rm -rf "$keydir"' EXIT
export KEYDIR="$keydir"
# One repository secret: the keystore and its unlock information as JSON.
python3 - <<'PY'
import base64, json, os
from pathlib import Path
directory = Path(os.environ["KEYDIR"])
config = json.loads(os.environ["ANDROID_SIGNING"])
for name in ("keystore_base64", "alias", "store_password"):
    if not isinstance(config.get(name), str) or not config[name]:
        raise SystemExit(f"ANDROID_SIGNING needs a nonempty {name} field")
(directory / "key").write_bytes(base64.b64decode("".join(config["keystore_base64"].split()), validate=True))
(directory / "alias").write_text(config["alias"])
(directory / "store").write_text(config["store_password"])
(directory / "pass").write_text(config.get("key_password", config["store_password"]))
PY
unset ANDROID_SIGNING
tool=$(find "$ANDROID_HOME/build-tools" -name apksigner | sort -V | tail -1)
mkdir -p build/release
out="build/release/VectorRange-$(cat release-version.txt)-arm64.apk"
alias_name=$(cat "$keydir/alias")
"$tool" sign --ks "$keydir/key" --ks-key-alias "$alias_name" --ks-pass "file:$keydir/store" \
  --key-pass "file:$keydir/pass" --out "$out" build/unsigned/VectorRange-unsigned.apk
"$tool" verify --verbose --print-certs "$out" > "$keydir/verified"
expected=$(keytool -exportcert -keystore "$keydir/key" -alias "$alias_name" -storepass:file "$keydir/store" | sha256sum | cut -d' ' -f1)
actual=$(sed -nE 's/^(Signer #1 certificate|V[0-9.]+ Signer: certificate) SHA-256 digest: //p' "$keydir/verified" | sort -u)
test "$expected" = "$actual"
if grep -Eiq 'certificate DN:.*CN=(Android Debug|Vector Range Preview)([, ]|$)' "$keydir/verified"; then
  echo 'A production keystore is required for release signing.' >&2
  exit 1
fi
test "$actual" = "767c05ea60ee5dcd423465eef7dd6ff0d4fadc18b1d3626a2964bdaef912db5f"
"$tool" sign --ks "$keydir/key" --ks-key-alias "$alias_name" --ks-pass "file:$keydir/store" \
  --key-pass "file:$keydir/pass" --out build/baseline/previous-signed.apk build/baseline/previous.apk
(cd build/release && sha256sum *.apk > SHA256SUMS.txt)
