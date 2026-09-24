#!/system/bin/sh
# Outer (cover) panel brightness. Android's only backlight path (Lights HAL light 0) is wired to
# the first display, and Samsung's HWC ignores per-display brightness, so the outer panel never
# follows the slider. Mirror the default display's brightness onto the outer panel's backlight
# while it's the active screen. Same scale as the inner panel: sysfs = float * 510.
until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 1; done

INNER=/sys/class/backlight/panel0-backlight/brightness
OUTER=/sys/class/backlight/panel1-backlight/brightness
last=-1
while true; do
    read inner < "$INNER"
    read outer < "$OUTER"
    # Outer panel lit (non-zero) and inner dark => outer is the active screen
    if [ "$outer" -gt 0 ] && [ "$inner" -eq 0 ]; then
        # While the slider is being dragged SystemUI only sets a temporary brightness, which
        # get-brightness doesn't report; DisplayPowerController's dump does.
        f=$(dumpsys display 2>/dev/null | awk -F: '/mTemporaryScreenBrightness:/ { v = $2 + 0; if ($2 !~ /NaN/ && v >= 0 && v <= 1) { print v; exit } }')
        [ -z "$f" ] && f=$(cmd display get-brightness 2>/dev/null)
        want=$(awk -v f="$f" 'BEGIN { v = int(f * 510 + 0.5); if (v < 2) v = 2; if (v > 510) v = 510; print v }')
        # Also re-apply if the kernel reset the panel (e.g. after screen off/on)
        if [ "$want" != "$last" ] || [ "$outer" != "$want" ]; then
            echo "$want" > "$OUTER"
            last=$want
        fi
        sleep 0.3
    else
        last=-1
        sleep 2
    fi
done
