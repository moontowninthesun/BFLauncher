#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
TEST_BINARY="$PROJECT_DIR/.build/BFLauncherSelfTest"

mkdir -p "$PROJECT_DIR/.build"
swiftc -parse-as-library \
    "$PROJECT_DIR/Sources/BFLauncher/Models.swift" \
    "$PROJECT_DIR/Sources/BFLauncher/WADInspector.swift" \
    "$PROJECT_DIR/Sources/BFLauncher/LaunchCommandBuilder.swift" \
    "$PROJECT_DIR/Sources/BFLauncher/LegacySSGLImporter.swift" \
    "$PROJECT_DIR/Tests/SelfTest.swift" \
    -o "$TEST_BINARY"
"$TEST_BINARY"
