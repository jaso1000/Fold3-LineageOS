#!/system/bin/sh
# The bootloader lights the outer panel with its splash; the display driver keeps showing it
# until that display gets a real frame. When booted unfolded Android never draws to the outer
# display, so the logo sticks until the first fold. Force one CLOSE->reset cycle at boot.

# Wait for system_server's device_state service (bail after ~3 min).
i=0
until state=$(cmd device_state print-state 2>/dev/null) && [ -n "$state" ]; do
    i=$((i + 1)); [ "$i" -gt 180 ] && exit 0; sleep 1
done
# Let the display pipeline settle so the outer display actually commits a frame.
until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 1; done
sleep 2

case "$(cmd device_state print-state)" in
    2|3) # HALF_FOLDED / OPEN: outer panel may still hold the splash
        cmd device_state state 0
        sleep 1.5
        cmd device_state state reset
        ;;
esac
