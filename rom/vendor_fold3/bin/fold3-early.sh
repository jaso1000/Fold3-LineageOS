#!/system/bin/sh
# Fold3 early boot (init, on post-fs, before system_server and audioserver start).
case "$(getprop ro.product.vendor.model)" in SM-F926*) ;; *) exit 0 ;; esac

# Dual-screen switching. The vendor's generic device_state_configuration.xml gates the folded
# state on a <lid-switch> that the GSI never reports as closed, so the outer screen never takes
# over. Use Samsung's own sec/ 6-state sensor config with every <lid-switch> condition removed
# (same result as scripts/make-vendor-image.sh, but done at boot, so a stock vendor works).
# Also add the Android 16 power properties Samsung's file lacks: folding to CLOSE (0) may put the
# device to sleep (only if Settings > Display > "Continue using apps on fold" is "Never"), and
# unfolding to HALF_FOLDED (2) / OPEN (3) wakes it, like One UI.
SEC=/vendor/etc/devicestate/sec/device_state_configuration.xml
DST=/vendor/etc/devicestate/device_state_configuration.xml
FIX=/mnt/fold3/device_state_configuration.xml
P=com.android.server.policy.PROPERTY_POWER_CONFIGURATION
if grep -q '<lid-switch>' "$SEC" 2>/dev/null; then
    mkdir -p /mnt/fold3
    sed '/<lid-switch>/,/<\/lid-switch>/d' "$SEC" | awk -v p="$P" '
        /<identifier>/ { id = $0; gsub(/[^0-9]/, "", id); state_name = 1 }
        { print }
        state_name && /<\/name>/ {
            state_name = 0
            if (id == "0") prop = p "_TRIGGER_SLEEP"
            else if (id == "2" || id == "3") prop = p "_TRIGGER_WAKE"
            else prop = ""
            if (prop != "") print "    <properties>\n      <property>" prop "</property>\n    </properties>"
        }' > "$FIX"
    chcon u:object_r:vendor_configs_file:s0 "$FIX"
    chmod 644 "$FIX"
    mount -o bind "$FIX" "$DST"
fi

# USB-C headphones: load Samsung's audio policy (primary module routes USB headsets through the
# ADSP offload path) instead of the vendor's generic one without USB routing.
AP_SEC=/vendor/etc/audio_policy_configuration_sec.xml
AP_DEF=/vendor/etc/audio_policy_configuration.xml
[ -f "$AP_SEC" ] && mount -o bind "$AP_SEC" "$AP_DEF"

# Samsung's audio effects, as One UI loads them: SoundBooster Plus (speaker loudness/protection;
# without it loud speaker playback sounds strained and muffled), SoundAlive, sa3d on music/ring/
# alarm, Dolby Atmos (dap). All libraries are on the vendor partition except Adapt Sound's
# libmysound (skipped with a log line).
# Calls: One UI's voice path runs in the modem, so Samsung's file only puts echo cancellation on
# voice_communication. Floss IMS calls use that (VoIP) mic path, so also keep the generic file's
# noise suppression there, or background noise goes out unfiltered and the caller sounds faint.
AE_SEC=/vendor/etc/audio_effects_sec.xml
AE_DEF=/vendor/etc/audio_effects.xml
AE_FIX=/mnt/fold3/audio_effects.xml
if [ -f "$AE_SEC" ]; then
    mkdir -p /mnt/fold3
    awk '
        /<stream type="voice_communication">/ { vc = 1 }
        { print }
        vc && /<apply effect="aec"\/>/ { sub(/<apply effect="aec"\/>/, "<apply effect=\"ns\"/>"); print; vc = 0 }
    ' "$AE_SEC" > "$AE_FIX"
    chcon u:object_r:vendor_configs_file:s0 "$AE_FIX"
    chmod 644 "$AE_FIX"
    mount -o bind "$AE_FIX" "$AE_DEF"
fi

# Dolby decoders (AC-3, E-AC-3 incl. Atmos/JOC, AC-4): Samsung's codec service has them, but the
# codec list the GSI reads (media_codecs_lahaina.xml) doesn't include Dolby's codec file, so apps
# (Netflix, Disney+, Plex...) never see them. One UI adds it in its framework; add the include.
MC=/vendor/etc/media_codecs_lahaina.xml
MC_FIX=/mnt/fold3/media_codecs_lahaina.xml
if [ -f /vendor/etc/media_codecs_dolby_audio.xml ] && ! grep -q dolby_audio "$MC" 2>/dev/null; then
    mkdir -p /mnt/fold3
    sed 's|<Include href="media_codecs_vendor_audio.xml" />|&\n    <Include href="media_codecs_dolby_audio.xml" />|' "$MC" > "$MC_FIX"
    chcon u:object_r:vendor_configs_file:s0 "$MC_FIX"
    chmod 644 "$MC_FIX"
    mount -o bind "$MC_FIX" "$MC"
fi
exit 0
