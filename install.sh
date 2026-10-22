#!/bin/sh
# Installs CleanDroidFrame on your TV over Wi-Fi and makes it the Home screen. Needs adb.
#
#   sh install.sh <TV_IP>
#   sh install.sh <TV_IP> "com.netflix.ninja,com.google.android.youtube.tv"
#   sh install.sh <TV_IP> "com.netflix.ninja" playstation      # HDMI 1 tile: playstation | nintendoswitch | none
#
# Uses out/cleandroidframe.apk (run build.sh first). Nothing is turned off or uninstalled.
# Written for CleanDroidFrame; the adb flow follows tv-detox by Ansub Khan (MIT).
set -e
cd "$(dirname "$0")"

TARGET="$1"; APPS="$2"; CONSOLE="${3:-playstation}"
[ -n "$TARGET" ] || { echo "Usage: sh install.sh <TV_IP> [\"app1,app2,...\"] [playstation|nintendoswitch|none]" >&2; exit 1; }
command -v adb >/dev/null 2>&1 || { echo "adb is missing. On a Mac: brew install android-platform-tools" >&2; exit 1; }
[ -f out/cleandroidframe.apk ] || { echo "No APK yet. Run: sh build.sh" >&2; exit 1; }

case "$TARGET" in
  *.*.*.*:*) TV=$TARGET ;;
  *.*.*.*)   TV=$TARGET:5555 ;;
  *)         TV=$TARGET ;;
esac
case "$TV" in *:*) adb connect "$TV" >/dev/null || true ;; esac
case "$(adb -s "$TV" get-state 2>&1 || true)" in
  device) ;;
  *unauthorized*) echo "The TV is asking \"Allow USB debugging?\". Tick Always allow, press Allow, then run this again." >&2; exit 1 ;;
  *) echo "Can't reach $TV. Check the TV is on, on the same Wi-Fi, and has USB/network debugging on." >&2; exit 1 ;;
esac

PKG=app.cleandroidframe
ME=$PKG/.MainActivity
# Remember what Home was before, so undo.sh can put it back.
prev=$(adb -s "$TV" shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME | tail -1 | tr -d '\r')
case "$prev" in "$PKG"/*|""|android/*) ;; *) adb -s "$TV" shell "echo $prev > /data/local/tmp/cleandroidframe-prev-home.txt" ;; esac

adb -s "$TV" install -r out/cleandroidframe.apk

set -- --es stamp "$(date +%s)" --es console "$CONSOLE"
[ -n "$APPS" ] && set -- "$@" --es apps "\"$APPS\""
adb -s "$TV" shell am start -n "$ME" "$@" >/dev/null

# Make it the default Home (the role on Android 10+, and the classic way).
if [ "$(adb -s "$TV" shell getprop ro.build.version.sdk | tr -d '\r')" -ge 29 ]; then
  adb -s "$TV" shell cmd role add-role-holder --user 0 android.app.role.HOME "$PKG" >/dev/null 2>&1 || true
fi
adb -s "$TV" shell cmd package set-home-activity "$ME" >/dev/null 2>&1 || true
adb -s "$TV" shell input keyevent KEYCODE_HOME

now=$(adb -s "$TV" shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME | tail -1 | tr -d '\r')
if [ "$now" = "$ME" ]; then
  echo "Done. Press Home on your remote."
else
  echo "Installed, but Home still opens $now."
  echo "If your TV asks which home screen to use, pick CleanDroidFrame and choose Always."
  echo "Some TVs only follow it once their own home screen is turned off. See README > Make it the Home screen."
fi
