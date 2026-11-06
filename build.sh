#!/bin/zsh
set -eu
cd "${0:A:h}"
mkdir -p .cache/modules Braino.app/Contents/MacOS
cp Info.plist Braino.app/Contents/Info.plist
swiftc -target arm64-apple-macos14.0 -swift-version 5 -O -module-cache-path "$PWD/.cache/modules" Sources/Braino.swift -o Braino.app/Contents/MacOS/Braino
codesign --force --sign - Braino.app
print "Built Braino.app — open it with: open Braino.app"
