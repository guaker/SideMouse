#!/bin/zsh
set -euo pipefail
TASK_ROOT="${0:A:h}"
TASK_STAGE="$(mktemp -d /tmp/DesktopSideKeys-release.XXXXXX)"
TASK_APP="$TASK_STAGE/SideMouse.app"
mkdir -p "$TASK_APP/Contents/MacOS" "$TASK_APP/Contents/Resources"
cp "$TASK_ROOT/Info.plist" "$TASK_APP/Contents/Info.plist"
cp "$TASK_ROOT/assets/SideMouse.icns" "$TASK_APP/Contents/Resources/SideMouse.icns"
ditto "$TASK_ROOT/localizations" "$TASK_APP/Contents/Resources"
swiftc "$TASK_ROOT/DesktopSideKeys.swift" "$TASK_ROOT/ShortcutSender.swift" "$TASK_ROOT/ShortcutVerification.swift" -o "$TASK_APP/Contents/MacOS/DesktopSideKeys" -framework Cocoa -framework Carbon -framework CoreGraphics
cp "$TASK_ROOT/THIRD_PARTY_NOTICES.md" "$TASK_APP/Contents/Resources/THIRD_PARTY_NOTICES.md"
codesign --force --sign 'Developer ID Application: Beijing Chuzheng Intelligent Technology Co., Ltd (7W443PQ7JZ)' "$TASK_APP"
codesign --verify --strict "$TASK_APP"
printf '%s\n' "$TASK_APP"
