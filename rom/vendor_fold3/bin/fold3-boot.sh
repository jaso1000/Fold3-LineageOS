#!/system/bin/sh
# Fold3 one-shot fixes after boot_completed.
case "$(getprop ro.product.vendor.model)" in SM-F926*) ;; *) exit 0 ;; esac

LOG=/data/misc/fold3/boot.log
mv -f $LOG $LOG.prev 2>/dev/null

# Outer-screen boot logo: the bootloader lights both panels, and Android never sends the
# inactive one anything (its display device stays STATE_UNKNOWN, kernel dpms=On), so it keeps
# showing the Samsung logo until the first fold. Power off every disabled built-in logical
# display once; folding powers it on again as usual (UNKNOWN -> OFF is a real state change).
for id in $(dumpsys display | awk '
    /^  Display [0-9]+:/ { if (id != "" && dis && !ext) print id; id = $2; sub(":", "", id); dis = 0; ext = 0 }
    /mIsEnabled=false/ { dis = 1 }
    /mPrimaryDisplayDevice=(HDMI|DP|Virtual|Overlay)|mPrimaryDisplayDevice=null/ { ext = 1 }
    END { if (id != "" && dis && !ext) print id }'); do
    echo "$(date +%T) power-off disabled built-in display $id: $(cmd display power-off "$id" 2>&1)" >> $LOG
done

# Floss IMS hidden-API exemption (fold3-floss-ims.sh) and hotspot DNS (fold3-net-fixes.sh)
/system/bin/fold3-floss-ims.sh
/system/bin/fold3-net-fixes.sh

# Phone app blocks on rild's slow start and ANR-loops at boot; the safety-source receiver is
# what trips it (notes/procedure.md, "Phone app / no network after boot"). Persistent, so only
# needed once per data wipe.
pm disable com.android.phone/.security.SafetySourceReceiver >/dev/null 2>&1
exit 0
