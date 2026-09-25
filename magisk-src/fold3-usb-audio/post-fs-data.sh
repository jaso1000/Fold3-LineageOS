#!/system/bin/sh
# The GSI's audioserver loads the vendor's generic /vendor/etc/audio_policy_configuration.xml, which
# has no USB routing: USB headsets get "could not find HW module for device AUDIO_DEVICE_OUT_USB_HEADSET",
# and adding the plain usb module doesn't help, because with vendor.audio.feature.usb_offload.enable=true
# the ADSP owns the headset's playback PCM. One UI loads Samsung's audio_policy_configuration_sec.xml,
# whose primary module routes USB headsets through the ADSP offload path. Use that one. (Bind mount:
# no Samsung file is shipped in this module.)
SEC=/vendor/etc/audio_policy_configuration_sec.xml
DEF=/vendor/etc/audio_policy_configuration.xml
[ -f "$SEC" ] && mount -o bind "$SEC" "$DEF"
