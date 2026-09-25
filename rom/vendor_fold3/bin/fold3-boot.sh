#!/system/bin/sh
# Fold3 one-shot fixes after boot_completed.
case "$(getprop ro.product.vendor.model)" in SM-F926*) ;; *) exit 0 ;; esac

# Floss IMS hidden-API exemption (fold3-floss-ims.sh) and hotspot DNS (fold3-net-fixes.sh)
/system/bin/fold3-floss-ims.sh
/system/bin/fold3-net-fixes.sh

# Phone app blocks on rild's slow start and ANR-loops at boot; the safety-source receiver is
# what trips it (notes/procedure.md, "Phone app / no network after boot"). Persistent, so only
# needed once per data wipe.
pm disable com.android.phone/.security.SafetySourceReceiver >/dev/null 2>&1
exit 0
