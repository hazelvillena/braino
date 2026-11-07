#!/bin/zsh
set -eu
cd "${0:A:h}"
./build.sh
mkdir -p dist
stage=$(mktemp -d "$PWD/.cache/installer.XXXXXX")
trap 'rm -rf "$stage"' EXIT
ditto Braino.app "$stage/Braino.app"
ln -s /Applications "$stage/Applications"
cp Assets/Braino.icns "$stage/.VolumeIcon.icns"
cat > "$stage/Start here.txt" <<'WELCOME'
B R A I N O
One thing at a time.

Drag Braino to Applications, then open it.
Control–Space brings your tasks forward.
Use the pin to keep Braino above other windows.

Requires Apple Silicon and macOS 14 or later.
Tasks stay on your Mac. Replacing the app does not remove your tasks.
WELCOME
# Set the mounted volume's custom-icon Finder flag when developer tools include SetFile.
if command -v SetFile >/dev/null; then SetFile -a C "$stage"; fi
hdiutil create -volname Braino -srcfolder "$stage" -ov -format UDZO dist/Braino.dmg
swift -module-cache-path "$PWD/.cache/modules" scripts/InstallerIcon.swift "$PWD"
hdiutil verify dist/Braino.dmg
print "Installer ready: dist/Braino.dmg"
