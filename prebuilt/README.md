# Prebuilt Magisk modules

Ready-to-flash builds of this repo's modules, for the LineageOS 23.2 GSI
(`23.2-20260524-VANILLA-EXT4-GSI`) on SM-F926B with the F926BXXSJJZH3 vendor.
Install with Magisk (Modules → Install from storage), or
`adb shell su -c 'magisk --install-module /path/to/zip'`, then reboot.

| Zip | Version | What it does |
|---|---|---|
| `fold3-outer-touch.zip` | v2 | Patched GSI `libpowermanager.so`: both touch panels on at screen-on |
| `fold3-fold-config.zip` | v8 | Fold states/postures/hinge RRO (cover selfie, Flex mode), auto-brightness, double tap to wake, always-on display, Aperture lens overlay, Samsung hidden camera ids, outer-screen brightness |
| `fold3-fingerprint-fix.zip` | v3 | Re-sends `setActiveGroup` to Samsung's fingerprint HAL at boot and on HAL/rild restarts |
| `fold3-floss-ims.zip` | v20 | Floss IMS (VoLTE calls/SMS/MMS) built from `../floss-ims`, as a priv-app |
| `fold3-net-fixes.zip` | v1 | Hotspot DNS fix |
| `fold3-desktop.zip` | v5 | USB-C docks (USB host + DisplayPort) with One UI-style lock-screen USB protection, and Android 16 desktop mode on the external monitor |

**Not included, build it yourself:** `fold3-media-c2-seccomp`. It contains a copy of a Samsung
vendor file, so `scripts/make-media-c2-seccomp-module.sh` pulls it from your own phone. The
patched vendor image is also not included; build it with `scripts/make-vendor-image.sh` from
the stock JJZH3 vendor.

`fold3-outer-touch` only works on the exact GSI build above: it replaces a whole system library.
Rebuild these with `scripts/make-*-module.sh` and `scripts/make-overlays.sh`, then copy them here.
The Floss APK is signed with the AOSP test key. That's fine because it's trusted as a privileged
system app, not by its signature.
