#!/system/bin/sh
# USB-C docks (USB host + DisplayPort) on the GSI.
#
# Samsung's usb_notify driver starts every boot in lock state SKY_DEFAULT ("init") and treats it
# as restricted: USB host requests from a dock are refused ("now restricted, skip this command"),
# so no keyboard/mouse/hub and no DisplayPort alt mode. On One UI, services.jar's
# UsbHostRestrictor writes SUNNY_WORK_MODE (unlocked) / CLOUDY_WORK_MODE (locked, USB allowed) /
# RAINY_RESTRICT_MODE (locked, USB blocked) to usb_sl. The GSI never does, so do it here. We keep
# SUNNY_WORK_MODE, i.e. AOSP behaviour (no lock-screen USB blocking).
#
# Android 16 desktop mode on external displays needs freeform + force desktop mode + "Enable desktop
# experience features" (override_desktop_experience_features=1 and, read at boot,
# persist.wm.debug.desktop_experience_devopts=1, set in post-fs-data.sh); re-apply in case of resets. New external displays can arrive disabled (they then
# just mirror the phone), so enable them.
SL=/sys/class/usb_notify/usb_control/usb_sl
DP=/sys/class/drm/card0-DP-1/status
until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 1; done
while true; do
    [ "$(cat $SL 2>/dev/null)" != "SUNNY_WORK_MODE" ] && echo SUNNY_WORK_MODE > $SL 2>/dev/null
    [ "$(settings get global enable_freeform_support)" = "1" ] || settings put global enable_freeform_support 1
    [ "$(settings get global force_desktop_mode_on_external_displays)" = "1" ] || settings put global force_desktop_mode_on_external_displays 1
    [ "$(settings get global override_desktop_experience_features)" = "1" ] || settings put global override_desktop_experience_features 1
    if [ "$(cat $DP 2>/dev/null)" = "connected" ]; then
        # logical displays whose primary device is external (HDMI/DP) and disabled
        for id in $(dumpsys display | awk '
            /^  Display [0-9]+:/ { id = $2; sub(":", "", id); ext = 0 }
            /mPrimaryDisplayDevice=HDMI|mPrimaryDisplayDevice=DP/ { ext = 1 }
            /mIsEnabled=false/ { if (ext) print id }'); do
            cmd display enable-display "$id" >/dev/null 2>&1
        done
    fi
    sleep 5
done
