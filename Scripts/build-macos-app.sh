#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
OUTPUT_DIR="${1:-$PROJECT_DIR/dist}"
APP_DIR="$OUTPUT_DIR/BFLauncher.app"
BUILD_DIR="$PROJECT_DIR/.build/universal"
SOURCES=("$PROJECT_DIR"/Sources/BFLauncher/*.swift)

mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"

swiftc -O -parse-as-library -target arm64-apple-macosx13.0 \
    "${SOURCES[@]}" -o "$BUILD_DIR/BFLauncher-arm64"
swiftc -O -parse-as-library -target x86_64-apple-macosx13.0 \
    "${SOURCES[@]}" -o "$BUILD_DIR/BFLauncher-x86_64"

if [[ -e "$APP_DIR" ]]; then
    rm -rf "$APP_DIR"
fi
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
lipo -create \
    "$BUILD_DIR/BFLauncher-arm64" \
    "$BUILD_DIR/BFLauncher-x86_64" \
    -output "$APP_DIR/Contents/MacOS/BFLauncher"
cp "$PROJECT_DIR/Packaging/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$PROJECT_DIR/Sources/BFLauncher/Resources/BFGEmblem.png" \
    "$APP_DIR/Contents/Resources/BFGEmblem.png"
cp "$PROJECT_DIR/Packaging/BFLauncher.icns" \
    "$APP_DIR/Contents/Resources/BFLauncher.icns"
chmod +x "$APP_DIR/Contents/MacOS/BFLauncher"
codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

echo "$APP_DIR"
