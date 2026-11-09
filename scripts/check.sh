#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/sidemouse-check.XXXXXX")"
cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT

zsh -n "$ROOT/build.sh" "$ROOT/scripts/check.sh"
plutil -lint "$ROOT/Resources/Info.plist" "$ROOT"/Resources/*.lproj/InfoPlist.strings
swiftc -typecheck -warnings-as-errors -target "$(uname -m)-apple-macosx13.0" "$ROOT"/Sources/SideMouse/*.swift
swiftc -warnings-as-errors \
  "$ROOT/Sources/SideMouse/DesktopDirection.swift" \
  "$ROOT/Sources/SideMouse/ShortcutSender.swift" \
  "$ROOT/Tests/ShortcutSenderTests.swift" \
  -o "$STAGE/SideMouseTests"
"$STAGE/SideMouseTests"
