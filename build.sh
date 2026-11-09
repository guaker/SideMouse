#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
OUTPUT_DIR="${SIDEMOUSE_OUTPUT_DIR:-$ROOT}"
APP="$OUTPUT_DIR/SideMouse.app"
SIGNING_IDENTITY="${SIDEMOUSE_SIGNING_IDENTITY:-Developer ID Application: Beijing Chuzheng Intelligent Technology Co., Ltd (7W443PQ7JZ)}"
mkdir -p "$OUTPUT_DIR"
STAGE="$(mktemp -d "$OUTPUT_DIR/.sidemouse-build.XXXXXX")"
STAGED_APP="$STAGE/SideMouse.app"
EXECUTABLE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$ROOT/Resources/Info.plist")"

cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT

mkdir -p "$STAGED_APP/Contents/MacOS" "$STAGED_APP/Contents/Resources"
cp "$ROOT/Resources/Info.plist" "$STAGED_APP/Contents/Info.plist"
cp "$ROOT/Resources/SideMouse.icns" "$STAGED_APP/Contents/Resources/SideMouse.icns"
for localization in "$ROOT"/Resources/*.lproj; do
  ditto "$localization" "$STAGED_APP/Contents/Resources/${localization:t}"
done

swiftc \
  "$ROOT"/Sources/SideMouse/*.swift \
  -O -warnings-as-errors \
  -target "$(uname -m)-apple-macosx13.0" \
  -o "$STAGED_APP/Contents/MacOS/$EXECUTABLE" \
  -framework Cocoa \
  -framework Carbon \
  -framework CoreGraphics

cp "$ROOT/THIRD_PARTY_NOTICES.md" "$STAGED_APP/Contents/Resources/THIRD_PARTY_NOTICES.md"
codesign --force --sign "$SIGNING_IDENTITY" "$STAGED_APP"
codesign --verify --deep --strict "$STAGED_APP"

rm -rf "$APP"
mv "$STAGED_APP" "$APP"
printf 'Built and verified: %s\n' "$APP"
