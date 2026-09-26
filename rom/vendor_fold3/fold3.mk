# Fold3 (SM-F926B, q2q) additions to the LineageOS 23.2 TrebleDroid GSI.
# Inherited from device/phh/treble/lineage_arm64_bvN4.mk (patch in rom/patches/). Everything here
# replaces a Magisk module; see rom/README.md for the mapping.

SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += vendor/fold3/sepolicy

PRODUCT_PACKAGES += \
    Fold3FrameworkOverlay \
    Fold3ApertureOverlay \
    Fold3LineageOverlay \
    FlossIms

# Boot scripts (copied from magisk-src/ by rom/apply.sh) + init
PRODUCT_COPY_FILES += \
    vendor/fold3/init/fold3.rc:$(TARGET_COPY_OUT_SYSTEM)/etc/init/fold3.rc \
    vendor/fold3/bin/fold3-early.sh:$(TARGET_COPY_OUT_SYSTEM)/bin/fold3-early.sh \
    vendor/fold3/bin/fold3-fold-config.sh:$(TARGET_COPY_OUT_SYSTEM)/bin/fold3-fold-config.sh \
    vendor/fold3/bin/fold3-desktop.sh:$(TARGET_COPY_OUT_SYSTEM)/bin/fold3-desktop.sh \
    vendor/fold3/bin/fold3-net-fixes.sh:$(TARGET_COPY_OUT_SYSTEM)/bin/fold3-net-fixes.sh \
    vendor/fold3/bin/fold3-floss-ims.sh:$(TARGET_COPY_OUT_SYSTEM)/bin/fold3-floss-ims.sh \
    vendor/fold3/bin/fold3-fingerprint.sh:$(TARGET_COPY_OUT_SYSTEM)/bin/fold3-fingerprint.sh \
    vendor/fold3/bin/fold3-boot.sh:$(TARGET_COPY_OUT_SYSTEM)/bin/fold3-boot.sh \
    vendor/fold3/fp/fpactive.dex:$(TARGET_COPY_OUT_SYSTEM)/etc/fold3/fpactive.dex

# Outer (cover) panel brightness via HWC
PRODUCT_COPY_FILES += \
    vendor/fold3/etc/display_id_4630947232161729155.xml:$(TARGET_COPY_OUT_PRODUCT)/etc/displayconfig/display_id_4630947232161729155.xml

# Floss IMS: native lib next to the priv-app (as in the Magisk module) + permissions
PRODUCT_COPY_FILES += \
    vendor/fold3/prebuilt/FlossIms/librnnoise_jni.so:$(TARGET_COPY_OUT_SYSTEM)/priv-app/FlossIms/lib/arm64/librnnoise_jni.so \
    vendor/fold3/etc/privapp-permissions-me.phh.ims.xml:$(TARGET_COPY_OUT_SYSTEM)/etc/permissions/privapp-permissions-me.phh.ims.xml

PRODUCT_SYSTEM_PROPERTIES += \
    persist.sys.phh.samsung.camera_ids=true \
    persist.sys.phh.ims.floss=true \
    persist.wm.debug.desktop_experience_devopts=1

# AOD in the panel's low-power mode. SystemUI's doze_display_state_supported defaults to false, so
# AOD asked for a fully-on screen (SurfaceFlinger power On, 48-60 Hz, Samsung panel LPM off).
# With STATE_DOZE, HWC dozes and Samsung's driver enters panel LPM (outer screen: 30 Hz).
# DozeParameters reads this property before the resource.
PRODUCT_SYSTEM_PROPERTIES +=     doze.display.supported=true
