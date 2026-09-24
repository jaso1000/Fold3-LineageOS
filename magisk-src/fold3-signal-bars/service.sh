#!/system/bin/sh
# Start the signal-bar daemon (tools/seh-signal) once the phone process has registered its own
# ISehRadio callbacks, and keep it running: Samsung's RIL restarts itself if its ISehRadio client
# dies, which drops the network for ~1 min.
MODDIR=${0%/*}
until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 1; done
sleep 30
while true; do
    CLASSPATH=$MODDIR/seh-signal.dex app_process /system/bin me.jason.fold3.seh.SehSignal slot1 >/dev/null 2>&1
    echo "$(date '+%m-%d %T') daemon exited rc=$?" >> /data/local/tmp/fold3-signal.log
    sleep 5
done
