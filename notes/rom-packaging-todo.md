# TODO when packaging a real ROM (patched GSI or device tree build)

Things deliberately deferred because they need source/framework changes, plus everything
currently delivered via Magisk that must be baked in. See notes/procedure.md for details.

## Must bake in (currently Magisk modules / manual steps)
- [ ] libpowermanager miscpower mode -1 (outer touch) — source fix in phh's frameworks/native patch
- [ ] Samsung Codec2 seccomp `mremap` rule (storage/media/fingerprint) — bind-mount at boot
- [ ] device_state_configuration.xml lid-switch fix (dual-screen) — bind-mount at boot
- [ ] Floss IMS (patched, patches/floss-ims) as priv-app + privapp-permissions + hidden-API exemptions
- [ ] GSF runtime permissions (default-permissions XML)
- [ ] `pm disable com.android.phone/.security.SafetySourceReceiver` (boot ANR mitigation) — or fix properly
- [ ] IMS APN + carrier_volte_available: make automatic per SIM, not hand-set for 505-01

## Framework fixes to do in source
- [ ] **Signal bars**: synthesize SignalStrength from registered CellInfo when Samsung RIL returns
      all-invalid values (telephony-common is in the boot image — must be a real build)
- [ ] Resend SET_UNSOLICITED_RESPONSE_FILTER / device state when the radio becomes available
      (DeviceStateMonitor caches the failed boot-time send)
- [ ] Phone/rild startup: phone process blocks in IRadio.getService during rild's slow init
      → "failed to complete startup" ANR loop. Consider more HwBinder threads / async RIL init.
- [ ] Fingerprint: re-send setActiveGroup after HAL restart / rild restart (currently module fold3-fingerprint-fix)

## Floss IMS for other carriers
- [ ] Precondition fallback: offer QoS preconditions, retry without on 400/420/421 (Telstra rejects them)
- [ ] Test on other carriers (Optus, Vodafone AU, overseas)
- [ ] AMR-WB/EVS (HD voice), SMS over IMS; confirm speakerphone audio in calls; proper uplink gain instead of AGC

## Cosmetic / later
- [ ] Outer-screen boot logo — new approach that doesn't flip device state (the old one killed fingerprint)

## Added 2026-09-24 evening
- [ ] Hotspot DNS: TetheringNext never starts a DNS proxy → currently DNAT to 8.8.8.8 (module fold3-net-fixes)
- [ ] Fold device-state config (foldedDeviceStates/postures/display_features) — RRO overlays/Fold3FrameworkOverlay
- [ ] Outer display brightness: lights HAL/framework path for the second panel (currently a polling helper writing panel1-backlight)
- [ ] Adaptive refresh rate: make it ramp to 120 Hz on interaction (DisplayModeDirector / peak refresh config, touch boost) instead of forcing min = 120 Hz
