#!/usr/bin/env bash
# Build the "fold3-media-c2-seccomp" Magisk module: lets Samsung's software Codec2 HAL
# (samsung.software.media.c2@1.0-service, IComponentStore/default0) survive on the
# Android 16 GSI. See notes/procedure.md ("Storage + media: FIXED").
#
# Its vendor seccomp policy only allows `mremap: arg3 == 3`; the GSI's newer bionic
# allocator calls mremap with MREMAP_MAYMOVE alone, so minijail kills the service
# ("blocked syscall: mremap"). default0 then never registers, every MediaCodecList
# build blocks forever waiting for it, and that hangs StorageManagerService's
# handler thread (configureTranscoding -> isHevcDecoderSupported), so /sdcard never
# mounts. Fix: widen that one rule to match AOSP's own mediacodec.policy.
set -euo pipefail

ADB="${ADB:-$HOME/Android/sdk/platform-tools/adb}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/magisk/fold3-media-c2-seccomp"
POLICY=vendor/etc/seccomp_policy/samsung.software.media.c2-base-policy

rm -rf "$OUT"
mkdir -p "$OUT/system/$(dirname "$POLICY")"
# Run with the module disabled/uninstalled, so this pulls the stock vendor file.
"$ADB" shell "su -c 'cat /$POLICY'" | tr -d '\r' > "$OUT/system/$POLICY"

grep -qx 'mremap: arg3 == 3' "$OUT/system/$POLICY" \
    || { echo "expected 'mremap: arg3 == 3' rule not found; refusing to patch" >&2; exit 1; }
sed -i 's/^mremap: arg3 == 3$/mremap: arg3 == 3 || arg3 == MREMAP_MAYMOVE/' "$OUT/system/$POLICY"

cat > "$OUT/module.prop" <<'EOF'
id=fold3-media-c2-seccomp
name=Fold3 Samsung Codec2 seccomp fix
version=v1
versionCode=1
author=jason
description=Allow mremap(MREMAP_MAYMOVE) in Samsung's software Codec2 HAL seccomp policy so it stops crashing on the A16 GSI (fixes codec list hang, media playback and /sdcard mount).
EOF

(cd "$OUT" && rm -f ../fold3-media-c2-seccomp.zip && zip -qr ../fold3-media-c2-seccomp.zip .)
echo "Built $ROOT/magisk/fold3-media-c2-seccomp.zip"
echo "Install: adb push it to /data/local/tmp, then: adb shell su -c 'magisk --install-module /data/local/tmp/fold3-media-c2-seccomp.zip' && adb reboot"
