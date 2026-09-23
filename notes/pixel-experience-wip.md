# The "mostly working" Pixel Experience build (Super291, 2022-23)

https://xdaforums.com/t/pixel-experience-running-on-my-fold-3-wip-development.4483239/

One person (forum handle Super291, O2/Vodafone UK unit) got a real device-specific Pixel
Experience (Android 12-based) build running on their own Fold3, with a proper device tree
— not a GSI. By the Feb 2023 update:

**Working**: boot, inner+outer display switching (activities push to outer screen when
folded), brightness on both screens, RIL (3G/4G/5G/WiFi/BT), camera, wireless + reverse
charging.
**Broken**: flashlight, biometrics (fingerprint/face — pattern unlock worked as a fallback).

## What this actually means for us

This proves the hardware/kernel on q2q *can* support a fully-foldable-aware ROM with
near-total feature parity — useful ceiling evidence. It does **not** de-risk our plan,
because:

- **The build was never released.** No download link, no source, anywhere in the thread.
- The developer (Super291) went quiet after the Feb 2023 update, bought an iPhone, moved,
  changed jobs. A reply in Oct 2023 says "Project is dead I guess" — confirmed correct, a
  Aug 2026 "any update?" post (a month before this research) got no response either.
- It was a **full device tree port** (proper LineageOS/PixelExperience-style build with
  device-specific kernel integration), not a generic GSI. That's a much bigger effort than
  what our plan (flash a generic GSI onto an existing recovery) attempts — reaching that
  level of polish ourselves would mean building a device tree from scratch, closer to a
  multi-month personal project than a weekend one.

So: doesn't raise the odds of our GSI-based plan succeeding, but it does confirm the top end
is achievable *in principle* if someone (eventually us, or another dev) puts in device-tree
level effort. Also worth noting: Azkali (who maintains the q2q TWRP/OrangeFox recovery we're
relying on) separately got Ubuntu Touch booting on the Fold3, with a thread still getting
replies as recently as March 2026 — the most currently-active person in this device's scene,
worth a direct XDA message if we get serious about a real device-tree LineageOS port later.
