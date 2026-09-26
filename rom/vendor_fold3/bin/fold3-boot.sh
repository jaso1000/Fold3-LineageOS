#!/system/bin/sh
# Fold3 one-shot fixes after boot_completed.
case "$(getprop ro.product.vendor.model)" in SM-F926*) ;; *) exit 0 ;; esac

# AOD panel mode. Samsung's display driver expects One UI's AOD service to pick the low-power
# mode before AOD starts; without it the panel dozes with no AOD brightness (dim, kernel:
# "AOD service didn't set proper LPM mode"). 0x10000 = LPM version 1 (AOD brightness from the
# backlight level via Samsung's candela table), 2 = HLPM.
for p in panel panel1; do echo 65538 > /sys/class/lcd/$p/alpm 2>/dev/null; done

# Floss IMS hidden-API exemption (fold3-floss-ims.sh) and hotspot DNS (fold3-net-fixes.sh)
/system/bin/fold3-floss-ims.sh
/system/bin/fold3-net-fixes.sh

# Phone app blocks on rild's slow start and ANR-loops at boot; the safety-source receiver is
# what trips it (notes/procedure.md, "Phone app / no network after boot"). Persistent, so only
# needed once per data wipe.
pm disable com.android.phone/.security.SafetySourceReceiver >/dev/null 2>&1
exit 0
