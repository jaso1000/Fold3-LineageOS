#!/system/bin/sh
# Fold3 early boot (init, on post-fs, before system_server and audioserver start).
case "$(getprop ro.product.vendor.model)" in SM-F926*) ;; *) exit 0 ;; esac

# Dual-screen switching. The vendor's generic device_state_configuration.xml gates the folded
# state on a <lid-switch> that the GSI never reports as closed, so the outer screen never takes
# over. Use Samsung's own sec/ 6-state sensor config with every <lid-switch> condition removed
# (same result as scripts/make-vendor-image.sh, but done at boot, so a stock vendor works).
SEC=/vendor/etc/devicestate/sec/device_state_configuration.xml
DST=/vendor/etc/devicestate/device_state_configuration.xml
FIX=/mnt/fold3/device_state_configuration.xml
if grep -q '<lid-switch>' "$SEC" 2>/dev/null; then
    mkdir -p /mnt/fold3
    sed '/<lid-switch>/,/<\/lid-switch>/d' "$SEC" > "$FIX"
    chcon u:object_r:vendor_configs_file:s0 "$FIX"
    chmod 644 "$FIX"
    mount -o bind "$FIX" "$DST"
fi

# USB-C headphones: load Samsung's audio policy (primary module routes USB headsets through the
# ADSP offload path) instead of the vendor's generic one without USB routing.
AP_SEC=/vendor/etc/audio_policy_configuration_sec.xml
AP_DEF=/vendor/etc/audio_policy_configuration.xml
[ -f "$AP_SEC" ] && mount -o bind "$AP_SEC" "$AP_DEF"
exit 0
