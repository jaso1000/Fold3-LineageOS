#!/usr/bin/env bash
# Build the static RROs in overlays/ into the fold3-fold-config Magisk module
# (system/product/overlay/<Name>.apk). Any key works for a static product overlay.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK="$ROOT/build/src/floss-sdk"
BT="$SDK/build-tools/34.0.0"
JAR="$SDK/platforms/android-33/android.jar"
KEYS="$ROOT/build/src/floss-ims/keys"
DEST="$ROOT/magisk-src/fold3-fold-config/system/product/overlay"
mkdir -p "$DEST"

for dir in "$ROOT"/overlays/*/; do
    name="$(basename "$dir")"
    out="$dir/build"
    rm -rf "$out" && mkdir -p "$out"
    "$BT/aapt2" compile --dir "$dir/res" -o "$out/res.zip"
    "$BT/aapt2" link -o "$out/unsigned.apk" -I "$JAR" --manifest "$dir/AndroidManifest.xml" "$out/res.zip"
    "$BT/zipalign" -f -p 4 "$out/unsigned.apk" "$out/aligned.apk"
    "$BT/apksigner" sign --key "$KEYS/platform.pk8" --cert "$KEYS/platform.x509.pem" \
        --out "$DEST/$name.apk" "$out/aligned.apk"
    rm -f "$DEST/$name.apk.idsig"
    echo "Built $DEST/$name.apk"
done
