#!/usr/bin/env bash
# Build the "fold3-outer-touch" Magisk module: a 2-instruction patch to the GSI's
# /system/lib64/libpowermanager.so so Samsung's miscpower HAL enables BOTH touch panels
# on screen-on, instead of only the inner one. See notes/procedure.md
# ("Outer touchscreen: FIXED") for the full root-cause writeup.
#
# Both call sites of ISehMiscPower::setInteractiveAsync(on, mode) pass a hard-coded
# mode=0 ("main display only" -> tsp2 disabled). We change `mov w2, wzr` to
# `mov w2, #-1` ("all devices follow `on`"). Offsets are specific to the
# LineageOS-23.2-20260524 GSI build; the script refuses to patch anything else.
set -euo pipefail

ADB="${ADB:-$HOME/Android/sdk/platform-tools/adb}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/magisk/fold3-outer-touch"
ORIG_SHA=ba4d80650124ba0bc5e97cdaf5ba69e1c22fa650648f0f9f5d6cb60fd17da6b6
OFFSETS=(0x28810 0x298e0) # AidlHalWrapper::setMode(INTERACTIVE), HidlHalWrapperSeh::setInteractive

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Run with the module disabled/uninstalled, so this pulls the GSI's original file.
"$ADB" pull /system/lib64/libpowermanager.so "$tmp/libpowermanager.so" >/dev/null

if [ "$(sha256sum "$tmp/libpowermanager.so" | cut -d' ' -f1)" != "$ORIG_SHA" ]; then
    echo "libpowermanager.so on device doesn't match the known GSI build (or is already patched)." >&2
    echo "Offsets would need re-deriving; refusing to patch." >&2
    exit 1
fi

mkdir -p "$OUT/system/lib64"
cp "$tmp/libpowermanager.so" "$OUT/system/lib64/libpowermanager.so"
for off in "${OFFSETS[@]}"; do
    # expect e2 03 1f 2a (mov w2, wzr), write 02 00 80 12 (mov w2, #-1)
    [ "$(od -An -tx1 -j $((off)) -N4 "$OUT/system/lib64/libpowermanager.so" | tr -d ' ')" = "e2031f2a" ] \
        || { echo "unexpected bytes at $off" >&2; exit 1; }
    printf '\x02\x00\x80\x12' | dd of="$OUT/system/lib64/libpowermanager.so" bs=1 seek=$((off)) conv=notrunc 2>/dev/null
done

cat > "$OUT/module.prop" <<'EOF'
id=fold3-outer-touch
name=Fold3 outer touchscreen fix
version=v2
versionCode=2
author=jason
description=Patch GSI libpowermanager so Samsung miscpower HAL enables both touch panels on screen-on (mode -1 instead of hard-coded 0).
EOF

(cd "$OUT" && rm -f ../fold3-outer-touch.zip && zip -qr ../fold3-outer-touch.zip .)
echo "Built $ROOT/magisk/fold3-outer-touch.zip"
echo "Install: adb push it to /data/local/tmp, then: adb shell su -c 'magisk --install-module /data/local/tmp/fold3-outer-touch.zip' && adb reboot"
