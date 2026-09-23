#!/usr/bin/env bash
# Gather baseline info from a connected Galaxy Z Fold3 (q2q) over adb.
# USB debugging must already be enabled (Settings > About phone > tap Build number x7,
# then Settings > Developer options > USB debugging).
set -euo pipefail

ADB="${ADB:-$HOME/Android/sdk/platform-tools/adb}"

echo "== adb devices =="
"$ADB" devices -l

echo
echo "== build props =="
"$ADB" shell getprop ro.product.model
"$ADB" shell getprop ro.product.name
"$ADB" shell getprop ro.build.display.id
"$ADB" shell getprop ro.build.version.release
"$ADB" shell getprop ro.build.PDA
"$ADB" shell getprop ro.csc.sales_code
"$ADB" shell getprop ro.boot.bootloader

echo
echo "== OEM unlock / dev options relevant settings =="
"$ADB" shell settings get global development_settings_enabled
"$ADB" shell settings get global adb_enabled

echo
echo "== Knox/warranty (informational only) =="
"$ADB" shell getprop ro.boot.warranty_bit || true
"$ADB" shell getprop ro.boot.flash.locked || true

echo
echo "Next: reboot to download mode (adb reboot download) and check whether"
echo "OEM unlock is toggleable there, or check Settings > Developer options >"
echo "OEM unlocking manually."
