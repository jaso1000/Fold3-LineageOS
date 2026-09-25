#!/system/bin/sh
# Developer options -> "Enable desktop experience features": read by WindowManager at boot, so set it
# before system_server starts. (The Settings side, override_desktop_experience_features, is in service.sh.)
resetprop -p persist.wm.debug.desktop_experience_devopts 1
