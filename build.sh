#!/bin/zsh
set -eu
cd "${0:A:h}"
mkdir -p .cache/modules Braino.app/Contents/{MacOS,Resources}
swift -module-cache-path "$PWD/.cache/modules" scripts/BrandAssets.swift "$PWD"
python3 scripts/package_icon.py
cp Info.plist Braino.app/Contents/Info.plist
cp Assets/Braino.icns Braino.app/Contents/Resources/Braino.icns
cp Assets/BrainoIcon.png Assets/BrainoMark.png Assets/BrainoMenu.png Braino.app/Contents/Resources/
swiftc -target arm64-apple-macos14.0 -swift-version 5 -O -module-cache-path "$PWD/.cache/modules" Sources/Braino.swift -o Braino.app/Contents/MacOS/Braino
codesign --force --sign - Braino.app
print "Built Braino.app — open it with: open Braino.app"
