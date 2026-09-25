#!/usr/bin/env bash
# Build the "fold3-android-auto" Magisk module: Android Auto as a privileged system app.
# Since Android 10, Android Auto refuses to run unless it's bundled with the OS
# ("Communication error 22 - Android Auto was not preinstalled on this device"); BiTGApps Core
# doesn't ship it. This takes the Play Store install from your phone (APKs are Google's, so they
# never go in the repo), puts it in /system/priv-app, and allowlists every permission it requests
# (only the privileged ones matter). Play Store updates keep working on top of it.
set -euo pipefail
ADB="${ADB:-$HOME/Android/sdk/platform-tools/adb}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG=com.google.android.projection.gearhead
OUT="$ROOT/magisk/fold3-android-auto"
APP="$OUT/system/priv-app/AndroidAuto"

rm -rf "$OUT" && mkdir -p "$APP" "$OUT/system/etc/permissions"
for p in $($ADB shell pm path $PKG | tr -d '\r' | sed 's/^package://'); do
    f=$(basename "$p"); [ "$f" = base.apk ] && f=AndroidAuto.apk
    $ADB shell "su -c 'cat $p'" > "$APP/$f"
done
[ -s "$APP/AndroidAuto.apk" ] || { echo "Android Auto not installed? install it from Play first" >&2; exit 1; }

{
    echo '<?xml version="1.0" encoding="utf-8"?>'
    echo '<permissions>'
    echo "    <privapp-permissions package=\"$PKG\">"
    $ADB shell dumpsys package $PKG | sed -n '/requested permissions:/,/install permissions:/p' \
        | grep -oE '[A-Za-z0-9_.]+\.permission\.[A-Z0-9_]+' | sort -u \
        | sed 's|.*|        <permission name="&"/>|'
    echo '    </privapp-permissions>'
    echo '</permissions>'
} > "$OUT/system/etc/permissions/privapp-permissions-fold3-androidauto.xml"

cat > "$OUT/module.prop" <<EOS
id=fold3-android-auto
name=Fold3 Android Auto (system app)
version=v1
versionCode=1
author=jason
description=Installs Android Auto as a privileged system app so it stops failing with "Communication error 22 - not preinstalled".
EOS
(cd "$OUT" && rm -f ../fold3-android-auto.zip && zip -qr ../fold3-android-auto.zip .)
ls -la "$APP"; grep -c "<permission " "$OUT/system/etc/permissions/privapp-permissions-fold3-androidauto.xml"
echo "Built $ROOT/magisk/fold3-android-auto.zip"
