#!/bin/sh
set -eu
cd "$(dirname "$0")"
bundle=build/Orbit.app
mkdir -p "$bundle/Contents/MacOS"
cp Info.plist "$bundle/Contents/"
xcrun swiftc -O -target arm64-apple-macos13.0 Orbit.swift -o "$bundle/Contents/MacOS/Orbit"
codesign --force --sign - "$bundle"
codesign --verify --strict "$bundle"
ditto -c -k --keepParent "$bundle" build/Orbit-macOS.zip
