#!/usr/bin/env bash
# Build the "fold3-floss-ims" Magisk module: phh's Floss IMS (github.com/phhusson/ims, main)
# with our Telstra fixes (branch fold3-telstra-outgoing in build/src/floss-ims), installed as
# a privileged app. See notes/procedure.md ("Calls / VoLTE").
#
# Why a priv-app: upstream's release APK is signed with the TrebleDroid key, which this GSI
# trusts as platform (android.uid.system). We can't sign with that key, so we drop the
# sharedUserId and grant what it needs via privapp-permissions + a narrow hidden-API exemption.
#
# One-time setup (already done on this machine):
#   - build/src/floss-sdk: SDK with platforms;android-33 + build-tools;34.0.0, with
#     android/telephony/ims/feature/MmTelFeature*.class deleted from android.jar (upstream README)
#   - build/src/floss-ims/local.properties -> sdk.dir=<that SDK>
#   - app/jniLibs/arm64-v8a/librnnoise_jni.so taken from phh's release APK (native build disabled)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/build/src/floss-ims"
BT="$ROOT/build/src/floss-sdk/build-tools/34.0.0"
MOD="$ROOT/magisk-src/fold3-floss-ims"
APKDIR="$MOD/system/priv-app/FlossIms"

(cd "$SRC" && ./gradlew assembleRelease --no-daemon -q)

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
"$BT/zipalign" -f -p 4 "$SRC/app/build/outputs/apk/release/app-release-unsigned.apk" "$tmp/aligned.apk"
mkdir -p "$APKDIR/lib/arm64"
# Any key works: trust comes from being a privileged system app, not from the signature.
"$BT/apksigner" sign --key "$SRC/keys/platform.pk8" --cert "$SRC/keys/platform.x509.pem" \
    --out "$APKDIR/FlossIms.apk" "$tmp/aligned.apk"
rm -f "$APKDIR/FlossIms.apk.idsig"
cp "$SRC/app/jniLibs/arm64-v8a/librnnoise_jni.so" "$APKDIR/lib/arm64/"

mkdir -p "$ROOT/magisk"
(cd "$MOD" && rm -f "$ROOT/magisk/fold3-floss-ims.zip" && zip -qr "$ROOT/magisk/fold3-floss-ims.zip" .)
echo "Built $ROOT/magisk/fold3-floss-ims.zip"
