#!/system/bin/sh
# USB-C docks (USB host + DisplayPort) and Android 16 desktop mode on the GSI.
#
# Samsung's usb_notify driver gates USB host (and so DisplayPort alt mode) on a lock state in
# /sys/class/usb_notify/usb_control/usb_sl. It boots as SKY_DEFAULT ("init", treated as restricted)
# and One UI's services.jar UsbHostRestrictor drives it. Replicated here, same rules as stock:
#   device unlocked                         -> SUNNY_WORK_MODE     (USB allowed)
#   secure lock screen locked, block on     -> RAINY_RESTRICT_MODE (new USB devices refused;
#                                                                   already-connected keep working)
#   secure lock screen locked, block off    -> CLOUDY_WORK_MODE    (USB allowed while locked)
# "block" is Settings.Secure block_usb_lock, default 1 (on) like stock. deviceLocked from
# `dumpsys trust` is only true with a secure (PIN/pattern/password) lock screen, so no lock = no
# restriction, as on stock. (Stock's post-lock timer and MDM/SIM/DeX policy hooks are omitted.)
#
# Desktop mode on external displays needs freeform + force desktop mode + "Enable desktop
# experience features" (override_desktop_experience_features=1 and, read at boot,
# persist.wm.debug.desktop_experience_devopts=1, set in post-fs-data.sh); re-apply in case of
# resets. New external displays can arrive disabled (they then just mirror the phone): enable them.
SL=/sys/class/usb_notify/usb_control/usb_sl
DP=/sys/class/drm/card0-DP-1/status
LOG=/data/local/tmp/fold3-desktop.log

until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 1; done
n=0
while true; do
    locked=$(dumpsys trust 2>/dev/null | grep -m1 -o 'deviceLocked=[01]')
    block=$(settings get secure block_usb_lock 2>/dev/null)
    [ "$block" = "0" ] || block=1
    if [ "$locked" = "deviceLocked=1" ]; then
        [ "$block" = "1" ] && want=RAINY_RESTRICT_MODE || want=CLOUDY_WORK_MODE
    else
        want=SUNNY_WORK_MODE
    fi
    # Each read of usb_sl logs a kernel line, so only re-read it every ~30 s (in case something
    # else changed it); otherwise trust the value we last wrote.
    [ -z "$cur" ] || [ $((n % 15)) -eq 0 ] && cur=$(cat $SL 2>/dev/null)
    if [ -n "$cur" ] && [ "$cur" != "$want" ]; then
        echo $want > $SL 2>/dev/null
        echo "$(date '+%m-%d %T') usb_sl $cur -> $want ($locked block_usb_lock=$block)" >> $LOG
        if [ "$want" = "SUNNY_WORK_MODE" ]; then
            # Devices plugged in while RAINY are left unauthorized (e.g. a dock's hubs). The
            # driver only re-enumerates on unlock when there's no hub and no PD contract, and
            # re-authorizing isn't enough (Samsung's allowlist still refuses a configuration), so
            # a dock stays dead until replugged. Do a software replug of USB host via usb_notify's
            # own disable control (DisplayPort stays up).
            blocked=""
            for d in /sys/bus/usb/devices/*; do
                [ "$(cat $d/authorized 2>/dev/null)" = "0" ] && blocked="$blocked $(basename $d)"
            done
            if [ -n "$blocked" ]; then
                echo ON_HOST_REPLUG > /sys/class/usb_notify/usb_control/disable 2>/dev/null
                sleep 1
                echo OFF > /sys/class/usb_notify/usb_control/disable 2>/dev/null
                echo "$(date '+%m-%d %T') re-plugged USB host (blocked while locked:$blocked)" >> $LOG
            fi
        fi
        cur=$want
    fi

    if [ $((n % 3)) -eq 0 ]; then
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
    fi
    n=$((n + 1))
    sleep 2
done
