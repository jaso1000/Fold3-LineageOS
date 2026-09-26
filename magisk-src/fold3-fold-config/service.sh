#!/system/bin/sh
# Outer (cover) panel brightness. Android's only backlight path (Lights HAL light 0) is wired to
# the first display, and Samsung's HWC ignores per-display brightness, so the outer panel never
# follows the slider. Mirror the default display's brightness onto the outer panel's backlight
# while it's the active screen. Same scale as the inner panel: sysfs = float * 510.
until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 1; done

# Double tap to wake: the Samsung touch drivers (inner stm_ts_spi = tsp1, outer stm_ts = tsp2) only
# arm their low-power double-tap ("aot") mode when told to; they then report KEY_WAKEUP. Follow the
# Settings toggle, and re-assert periodically in case a driver reset clears it.
(
    last=""
    n=0
    while true; do
        v=$(settings get secure double_tap_to_wake 2>/dev/null)
        [ "$v" = "1" ] || v=0
        if [ "$v" != "$last" ] || [ $((n % 30)) -eq 0 ]; then
            for t in tsp1 tsp2; do echo "aot_enable,$v" > /sys/class/sec/$t/cmd 2>/dev/null; done
            last=$v
        fi
        n=$((n + 1))
        sleep 2
    done
) &

# Outer panel AOD brightness: follows the framework's doze brightness (auto-brightness while
# dozing, config_allowAutoBrightnessWhileDozing in the ROM overlay), never below DOZE_DEFAULT.
# Force a fixed level without reinstalling: `setprop persist.fold3.outer_aod 0.08` (0.02-1.0).
DOZE_DEFAULT=0.10
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
        # In AOD (power request policy DOZE) use the doze brightness, not the slider's: the
        # latest doze BrightnessEvent of the first (default) display's controller.
        FIXED=$(getprop persist.fold3.outer_aod)
        case "$FIXED" in 0.0[2-9]*|0.[1-9]*|1|1.0) ;; *) FIXED="" ;; esac
        f=$(dumpsys display 2>/dev/null | awk -v fixed="$FIXED" -v floor="$DOZE_DEFAULT" '
            /^Display Power Controller:/ { dpc++ }
            dpc == 1 && /mPowerRequest=policy=DOZE/ { doze = 1 }
            dpc == 1 && /BrightnessEvent: brt=/ && /policy=DOZE/ {
                s = $0; sub(/.*BrightnessEvent: brt=/, "", s); sub(/[(,].*/, "", s); dbrt = s + 0 }
            tmp == "" && /mTemporaryScreenBrightness:/ {
                s = $0; sub(/.*mTemporaryScreenBrightness:/, "", s)
                if (s !~ /NaN/ && s + 0 >= 0 && s + 0 <= 1) tmp = s + 0 }
            END {
                if (doze) { v = fixed != "" ? fixed : (dbrt > floor ? dbrt : floor); print v }
                else if (tmp != "") print tmp }')
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
