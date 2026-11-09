#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
OUTPUT_DIR="${SIDEMOUSE_OUTPUT_DIR:-$ROOT/dist}"
APP="$ROOT/SideMouse.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")"
ARCH="$(uname -m)"
PROFILE="${SIDEMOUSE_NOTARY_PROFILE:-SideMouseNotary}"
NAME="SideMouse-${VERSION}-macos-${ARCH}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/sidemouse-notary.XXXXXX")"

cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

mkdir -p "$OUTPUT_DIR"
SIDEMOUSE_OUTPUT_DIR="$ROOT" "$ROOT/build.sh"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$WORK/$NAME.zip"
xcrun notarytool submit "$WORK/$NAME.zip" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"

ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUTPUT_DIR/$NAME.zip"
shasum -a 256 "$OUTPUT_DIR/$NAME.zip" > "$OUTPUT_DIR/$NAME.zip.sha256"
printf 'Release assets ready:\n%s\n%s\n' "$OUTPUT_DIR/$NAME.zip" "$OUTPUT_DIR/$NAME.zip.sha256"
