#!/system/bin/sh
# Samsung's fingerprint HAL forgets its active group (enroll: "gid != m_active_group -1") after
# boot and whenever rild restarts (modem restart resets its secure-world session). Android only
# sends setActiveGroup once, so re-send it: ~30 s after boot, and after every rild restart.
MODDIR=${0%/*}
set_group() {
    CLASSPATH=$MODDIR/fpactive.dex:/system/framework/services.jar \
        app_process /system/bin FpActiveGroup 0 /data/vendor_de/0/fpdata >/dev/null 2>&1
}
until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 1; done
sleep 30
set_group
last=$(pidof rild)
while true; do
    sleep 10
    now=$(pidof rild)
    if [ -n "$now" ] && [ "$now" != "$last" ]; then
        sleep 20
        set_group
        last=$now
    fi
done
