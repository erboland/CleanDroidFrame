#!/bin/sh
# Removes CleanDroidFrame and gives Home back to the home screen it replaced.
# Usage: sh undo.sh <TV_IP>
[ -n "$1" ] || { echo "Usage: sh undo.sh <TV_IP>" >&2; exit 1; }
case "$1" in *.*.*.*:*) TV=$1 ;; *.*.*.*) TV=$1:5555 ;; *) TV=$1 ;; esac
case "$TV" in *:*) adb connect "$TV" >/dev/null || true ;; esac
[ "$(adb -s "$TV" get-state 2>/dev/null)" = device ] || { echo "Can't reach $TV." >&2; exit 1; }
prev=$(adb -s "$TV" shell cat /data/local/tmp/cleandroidframe-prev-home.txt 2>/dev/null | tr -d '\r')
adb -s "$TV" uninstall app.cleandroidframe >/dev/null 2>&1
# After the uninstall, so Android doesn't drop the choice together with the app.
[ -n "$prev" ] && adb -s "$TV" shell cmd package set-home-activity "$prev" >/dev/null 2>&1
adb -s "$TV" shell rm -f /data/local/tmp/cleandroidframe-prev-home.txt
adb -s "$TV" shell input keyevent KEYCODE_HOME
echo "Removed. If the TV's own home screen was turned off, turn it back on: adb shell pm enable <its package>"
