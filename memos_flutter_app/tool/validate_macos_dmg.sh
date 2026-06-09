#!/usr/bin/env bash
set -euo pipefail

# Production macOS builds should pass:
#   flutter build macos --release \
#     --dart-define=MEMOFLOW_MACOS_DISTRIBUTION_CHANNEL=production

EXPECTED_BUNDLE_ID="${EXPECTED_BUNDLE_ID:-com.memoflow.hzc073}"
EXPECTED_CHANNEL="${EXPECTED_CHANNEL:-production}"
EXPECTED_KEYCHAIN_SERVICE="${EXPECTED_KEYCHAIN_SERVICE:-com.memoflow.hzc073.secure.production}"

usage() {
  printf 'Usage: %s path/to/MemoFlow.dmg\n' "${0##*/}" >&2
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_tool() {
  local tool="$1"
  if ! command -v "$tool" >/dev/null 2>&1; then
    fail "Required tool not found: $tool"
  fi
}

if [[ $# -ne 1 ]]; then
  usage
  exit 64
fi

if [[ "$EXPECTED_CHANNEL" != "production" ]]; then
  fail "This validator is for production DMG checks; EXPECTED_CHANNEL=$EXPECTED_CHANNEL"
fi

DMG_PATH="$1"
if [[ ! -f "$DMG_PATH" ]]; then
  fail "DMG not found: $DMG_PATH"
fi

require_tool /usr/bin/hdiutil
require_tool /usr/bin/codesign
require_tool /usr/sbin/spctl
require_tool /usr/libexec/PlistBuddy
require_tool /usr/bin/xcrun

MOUNT_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/memoflow-dmg.XXXXXX")"
VOLUME_PATH=""

cleanup() {
  if [[ -n "$VOLUME_PATH" ]]; then
    /usr/bin/hdiutil detach "$VOLUME_PATH" -quiet >/dev/null 2>&1 ||
      /usr/bin/hdiutil detach "$VOLUME_PATH" -force -quiet >/dev/null 2>&1 ||
      true
  fi
  rm -rf "$MOUNT_ROOT"
}
trap cleanup EXIT

ATTACH_OUTPUT="$(
  /usr/bin/hdiutil attach \
    -readonly \
    -nobrowse \
    -noautoopen \
    -mountroot "$MOUNT_ROOT" \
    "$DMG_PATH"
)"
VOLUME_PATH="$(
  printf '%s\n' "$ATTACH_OUTPUT" |
    awk -F '\t' '$NF ~ /^\// { print $NF; exit }'
)"
if [[ -z "$VOLUME_PATH" || ! -d "$VOLUME_PATH" ]]; then
  fail "Unable to locate mounted volume for $DMG_PATH"
fi

APP_PATH="$(
  find "$VOLUME_PATH" -maxdepth 3 -type d -name 'MemoFlow.app' -print -quit
)"
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  fail "MemoFlow.app not found in mounted DMG"
fi

INFO_PLIST="$APP_PATH/Contents/Info.plist"
if [[ ! -f "$INFO_PLIST" ]]; then
  fail "Info.plist not found inside app bundle"
fi

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST")"
if [[ "$BUNDLE_ID" != "$EXPECTED_BUNDLE_ID" ]]; then
  fail "Bundle ID mismatch: expected $EXPECTED_BUNDLE_ID, got $BUNDLE_ID"
fi

if ! /usr/bin/grep -R -a -q -- "$EXPECTED_KEYCHAIN_SERVICE" "$APP_PATH"; then
  fail "Expected production Keychain service string not found in app bundle"
fi

CODESIGN_DETAILS="$(/usr/bin/codesign -dv --verbose=4 "$APP_PATH" 2>&1)"
if printf '%s\n' "$CODESIGN_DETAILS" | grep -q '^Signature=adhoc$'; then
  fail "App is signed ad-hoc"
fi
if ! printf '%s\n' "$CODESIGN_DETAILS" | grep -q '^Authority=Developer ID Application:'; then
  fail "Developer ID Application authority missing"
fi
if ! printf '%s\n' "$CODESIGN_DETAILS" | grep -Eq '^TeamIdentifier=[A-Z0-9]+$'; then
  fail "TeamIdentifier missing"
fi

ENTITLEMENTS="$(/usr/bin/codesign -d --entitlements :- "$APP_PATH" 2>&1 || true)"
if printf '%s\n' "$ENTITLEMENTS" | grep -q 'com.apple.security.get-task-allow'; then
  fail "Release app includes get-task-allow entitlement"
fi

/usr/bin/codesign --verify --deep --strict --verbose=4 "$APP_PATH"

SPCTL_OUTPUT="$(/usr/sbin/spctl -a -vvv -t exec "$APP_PATH" 2>&1)"
if ! printf '%s\n' "$SPCTL_OUTPUT" | grep -q 'accepted'; then
  printf '%s\n' "$SPCTL_OUTPUT" >&2
  fail "spctl did not accept the app"
fi

if ! /usr/bin/xcrun stapler validate "$DMG_PATH"; then
  fail "DMG stapled notarization ticket validation failed"
fi

printf 'DMG validation passed: %s\n' "$DMG_PATH"
printf 'Bundle ID: %s\n' "$BUNDLE_ID"
printf 'Keychain service: %s\n' "$EXPECTED_KEYCHAIN_SERVICE"
