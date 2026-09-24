#!/system/bin/sh
# Samsung's fingerprint HAL doesn't load its secure app / templates until setActiveGroup, and
# forgets the group whenever the HAL or rild restarts (modem restart resets its secure-world
# session). If system_server talks to it before that (keyguard detect at boot), the HAL dies,
# restarts empty, and the framework's boot-time cleanup enumerates 0 templates and DELETES the
# enrollment from settings_fingerprint.xml. So: set the group the moment the HAL process appears
# (before system_server gets to it), again whenever the HAL restarts, and after rild restarts.
MODDIR=${0%/*}
HAL=vendor.samsung.hardware.biometrics.fingerprint@3.0-service
set_group() {
    CLASSPATH=$MODDIR/fpactive.dex:/system/framework/services.jar \
        app_process /system/bin FpActiveGroup 0 /data/vendor_de/0/fpdata >/dev/null 2>&1
}
until [ -n "$(pidof $HAL)" ]; do sleep 0.2; done
sleep 0.5
set_group
lastfp=$(pidof $HAL)
lastril=$(pidof rild)
while true; do
    sleep 1
    fp=$(pidof $HAL)
    if [ -n "$fp" ] && [ "$fp" != "$lastfp" ]; then
        sleep 0.3
        set_group
        lastfp=$fp
    fi
    ril=$(pidof rild)
    if [ -n "$ril" ] && [ "$ril" != "$lastril" ]; then
        sleep 20
        set_group
        lastril=$ril
    fi
done
