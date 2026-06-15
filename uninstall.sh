#!/bin/bash
# Clean StupidNotch + every residue macOS holds onto: TCC permissions, prefs,
# caches, login items, leftover Application Support data. Designed to leave the
# system as if the app were never installed, so a fresh install starts from a
# clean prompt state instead of stale TCC entries from a previous signature.

set -u

BUNDLE_ID="io.kubilay.stupidnotch"
APP_NAME="StupidNotch"

say() { printf "→ %s\n" "$*"; }
soft() { "$@" 2>/dev/null || true; }

say "Killing running instances"
soft pkill -f "${APP_NAME}.app"
sleep 1

say "Removing .app bundles"
soft rm -rf "/Applications/${APP_NAME}.app"
soft rm -rf "$HOME/Applications/${APP_NAME}.app"
soft rm -rf "$(pwd)/${APP_NAME}.app"

say "Resetting TCC permissions for ${BUNDLE_ID}"
# 'All' covers Accessibility, AppleEvents, Microphone, Camera, Calendar,
# Reminders, Photos, ScreenCapture, SystemPolicyAllFiles, etc.
soft tccutil reset All "${BUNDLE_ID}"
# Older macOS sometimes only reset individual services — belt and suspenders.
for svc in Accessibility AppleEvents Microphone Camera Calendar Reminders Photos \
           ScreenCapture SystemPolicyAllFiles SystemPolicyDesktopFolder \
           SystemPolicyDocumentsFolder SystemPolicyDownloadsFolder \
           PostEvent ListenEvent; do
  soft tccutil reset "$svc" "${BUNDLE_ID}"
done

say "Removing preferences"
soft defaults delete "${BUNDLE_ID}"
soft rm -f "$HOME/Library/Preferences/${BUNDLE_ID}.plist"

say "Removing app support, caches, saved state, http storage"
soft rm -rf "$HOME/Library/Application Support/${APP_NAME}"
soft rm -rf "$HOME/Library/Caches/${BUNDLE_ID}"
soft rm -rf "$HOME/Library/Saved Application State/${BUNDLE_ID}.savedState"
soft rm -rf "$HOME/Library/HTTPStorages/${BUNDLE_ID}"
soft rm -rf "$HOME/Library/WebKit/${BUNDLE_ID}"
soft rm -rf "$HOME/Library/Containers/${BUNDLE_ID}"
soft rm -rf "$HOME/Library/Group Containers/${BUNDLE_ID}"

say "Unregistering login item (SMAppService)"
soft osascript -e "tell application \"System Events\" to delete login item \"${APP_NAME}\""
# Background service registered via SMAppService — try to unload its
# launch service plist if present.
soft launchctl unload "$HOME/Library/LaunchAgents/${BUNDLE_ID}.plist"
soft rm -f "$HOME/Library/LaunchAgents/${BUNDLE_ID}.plist"

say "Unregistering only StupidNotch from Launch Services (targeted, not a full rebuild)"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
for candidate in \
    "/Applications/${APP_NAME}.app" \
    "$HOME/Applications/${APP_NAME}.app" \
    "$(pwd)/${APP_NAME}.app"; do
    [ -d "$candidate" ] && soft "$LSREGISTER" -u "$candidate"
done

say "Done. The next install will be treated as a fresh app."
say "NOTE: This script no longer touches the global Launch Services DB. Earlier"
say "versions did and could break System Settings preference panes — fix is a reboot."
