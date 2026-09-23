# Handoff: LineageOS on Galaxy Tab S7 + Galaxy Z Fold3 research

Context carried over from a Claude (Cowork) chat, 23 Sep 2026. Owner: Jason. Laptop: Surface, Arch Linux (Omarchy), adb at `~/Android/sdk/platform-tools/adb` (not on PATH by default).

## 1. Galaxy Tab S7 WiFi (SM-T870, gts7lwifi) — DONE

- Installed official LineageOS 23.2 (weekly build 20260921) + MindTheGapps 16.0.0 arm64, via samloader-rs (vbmeta, recovery) and `adb sideload`.
- Working: HDMI/USB-C DisplayPort out (merged Aug 2026), keyboard cover typing + touchpad (tap-to-click fix merged Mar 2026), S Pen, BT keyboards.
- Desktop windowing enabled via (needs Developer options > Rooted debugging, then `adb root`):
  ```
  adb shell device_config put window_manager enable_desktop_windowing_mode true
  adb shell setprop persist.wm.debug.desktop_mode 1
  adb shell setprop persist.wm.debug.desktop_mode_enforce_device_restrictions false
  ```
  May need re-running after OTA updates (unverified).
- OPEN ISSUE: external monitor only mirrors; no extended desktop at native resolution (DeX-like). Tried: Force desktop mode, freeform, "Enable desktop experience features", `force_desktop_mode_on_external_displays=1`, `enable_freeform_support=1`. Likely ROM lacks config for desktop mode on external displays. Next step: run
  `adb shell dumpsys display | grep -iE "DisplayDeviceInfo|mDisplayId|FLAG_OWN_CONTENT|mirror"`
  with monitor attached; if it's mirror-only, ask maintainer bgcngm on XDA.
- Known bugs in current builds: lockscreen won't dismiss after idle (StrongBox keymaster hang; fix pending at review.lineageos.org change 501377, unmerged as of 23 Sep; workaround `su -c "stop keymaster-sb-4-0"` or Magisk module from XDA thread); Dolby Atmos no effect; Super+S screenshot soft-reboots; USB-C headphone dropouts.

## 2. Galaxy Z Fold3 (SM-F926B, Australian, codename q2q) — NEXT PROJECT

- SoC: Snapdragon 888 (SM8350). The Fold5 LineageOS 23.2 ROM by josip-k (q5q, SM8550, github.com/Exynoobs) is NOT portable — different chipset/kernel/blobs. Only foldable-specific logic (inner/outer display switching, dual brightness, fold sensor) is useful reference.
- Fold3 scene (XDA, Sep 2026): no official or active unofficial LineageOS. Exists: TWRP (Android 13 era), a custom kernel (SOLOW), abandoned Pixel Experience port (2022–23), Ubuntu Touch WIP.
- Realistic path: TrebleDroid-based LineageOS GSI. Try first via DSU (Dynamic System Updates) after bootloader unlock — boots GSI alongside One UI; reboot returns to stock.
- Expected GSI issues: outer screen switching/brightness, side fingerprint, some cameras, VoLTE/VoWiFi carrier-dependent, manual updates.
- Unlocking trips Knox permanently (Samsung Pay/Wallet, Secure Folder, Health lost; some banking apps may fail).

## Next steps
1. Confirm Fold3 model (SM-F926B), current One UI/Android version, and that OEM unlocking is visible.
2. Pick current best Android 16 GSI (arm64, TrebleDroid/LineageOS based) and verify on XDA.
3. Write step-by-step: unlock bootloader → DSU test → (optional) full flash via fastbootd.
4. Optional: draft XDA post to josip-k about q2q interest; draft post to bgcngm about extended display on Tab S7.

## Sources
- Tab S7 LOS23 thread: https://xdaforums.com/t/rom-official-lineageos-23-weeklies-for-galaxy-tab-s7-wifi-and-s7-lte.4763404/
- Install guide: https://wiki.lineageos.org/devices/gts7lwifi/install/
- Fold5 unofficial LOS 23.2: https://xdaforums.com/t/rom-unofficial-volte-vowifi-lineageos-23-2-for-galaxy-z-fold5.4774598/
- Fold3 forum: https://xdaforums.com/f/samsung-galaxy-z-fold3.12349/
- Fold3 Pixel Experience WIP: https://xdaforums.com/t/pixel-experience-running-on-my-fold-3-wip-development.4483239/
