#!/usr/bin/env bash
# Put the Fold3 changes into a LineageOS 23.2 TrebleDroid GSI source tree, after MisterZtr's
# patches (LineageOS_gsi/patches/apply-patches.sh). Re-runnable.
#
#   cd ~/android/lineage && bash ~/Projects/Fold3-LineageOS/rom/apply.sh .
#
# 1. vendor/fold3/  <- rom/vendor_fold3/ plus files taken from this repo, so the ROM ships the
#    same scripts, overlays and Floss APK as the Magisk modules (single source of truth).
# 2. rom/patches/<project>/*.patch -> git am in each project (same naming as MisterZtr's).
set -euo pipefail

TOP="$(cd "${1:-.}" && pwd)"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
V="$TOP/vendor/fold3"
[ -f "$TOP/build/envsetup.sh" ] || { echo "not an Android source tree: $TOP" >&2; exit 1; }

GATE='case "$(getprop ro.product.vendor.model)" in SM-F926*) ;; *) exit 0 ;; esac'

rm -rf "$V"
mkdir -p "$V/bin" "$V/etc" "$V/fp" "$V/overlays" "$V/prebuilt/FlossIms"
cp -a "$REPO/rom/vendor_fold3/." "$V/"
cp -a "$REPO"/overlays/*/ "$V/overlays/"
rm -rf "$V"/overlays/*/build

# Module scripts -> /system/bin/fold3-<module>.sh, with a device gate after the shebang
module_script() { # <module dir> <script> <dest name>
    local src="$REPO/magisk-src/$1/$2" dst="$V/bin/$3"
    { head -n1 "$src"; echo "$GATE"; tail -n +2 "$src"; } > "$dst"
}
module_script fold3-fold-config  service.sh fold3-fold-config.sh
module_script fold3-desktop      service.sh fold3-desktop.sh
module_script fold3-net-fixes    service.sh fold3-net-fixes.sh
module_script fold3-floss-ims    service.sh fold3-floss-ims.sh
module_script fold3-fingerprint-fix service.sh fold3-fingerprint.sh

# Paths that differ from Magisk: known-USB-device list out of /data/adb (keep the old one),
# fingerprint helper dex in /system/etc/fold3.
edit() { # <file> <exact line> <replacement>
    grep -qxF "$2" "$1" || { echo "apply.sh: expected line not found in $1: $2" >&2; exit 1; }
    F="$1" OLD="$2" NEW="$3" python3 - <<'EOF'
import os
p, old, new = os.environ["F"], os.environ["OLD"], os.environ["NEW"]
s = open(p).read().split("\n")
s = [new if l == old else l for l in s]
open(p, "w").write("\n".join(s))
EOF
}
edit "$V/bin/fold3-desktop.sh" 'HIST=/data/adb/fold3-usb-history' \
    'HIST=/data/misc/fold3/usb-history; [ -f $HIST ] || cp /data/adb/fold3-usb-history $HIST 2>/dev/null'
edit "$V/bin/fold3-fingerprint.sh" 'MODDIR=${0%/*}' 'MODDIR=/system/etc/fold3'
chmod 755 "$V"/bin/*.sh

cp "$REPO/magisk-src/fold3-fold-config/system/product/etc/displayconfig/display_id_4630947232161729155.xml" "$V/etc/"
cp "$REPO/magisk-src/fold3-floss-ims/system/etc/permissions/privapp-permissions-me.phh.ims.xml" "$V/etc/"

# Floss IMS APK + JNI lib, and the fingerprint helper dex, from the committed module zips
unzip -qjo "$REPO/prebuilt/fold3-floss-ims.zip" \
    system/priv-app/FlossIms/FlossIms.apk system/priv-app/FlossIms/lib/arm64/librnnoise_jni.so \
    -d "$V/prebuilt/FlossIms"
unzip -qjo "$REPO/prebuilt/fold3-fingerprint-fix.zip" fpactive.dex -d "$V/fp"

# Source patches
for dir in "$REPO"/rom/patches/*/; do
    project="$(basename "$dir")"
    tree="$(tr _ / <<<"$project" | sed -e 's;platform/;;g')"
    [ "$tree" == build ] && tree=build/make
    [ "$tree" == device/phh/treble ] || [ -d "$TOP/$tree" ] || { echo "no $tree" >&2; exit 1; }
    for patch in "$dir"*.patch; do
        subject="$(git mailinfo /dev/null /dev/null < "$patch" | sed -n 's/^Subject: //p')"
        recent="$(git -C "$TOP/$tree" log --format=%s -50)"
        if grep -qxF "$subject" <<<"$recent"; then
            echo "already applied: $tree: $subject"
        else
            git -C "$TOP/$tree" am -q "$patch"
            echo "applied: $tree: $subject"
        fi
    done
done
echo "Fold3 changes in place ($V)"
