#!/bin/bash
# ──────────────────────────────────────────────────────────────
# ResonaLens — iOS Build (Xcode project generation + archive)
# ──────────────────────────────────────────────────────────────
#
# Prerequisites:
#   1. macOS with Xcode 15+ installed
#   2. Qt 6.7+ for iOS installed (via Qt Online Installer)
#      - Select: Qt > Qt 6.x.x > iOS
#   3. Apple Developer account (for device deployment)
#   4. Valid signing certificate and provisioning profile
#
# Environment variables:
#   QT_IOS_DIR         — Qt for iOS (e.g., ~/Qt/6.8.0/ios)
#   DEVELOPMENT_TEAM   — Apple Developer Team ID (e.g., "ABCDE12345")
#
# Usage:
#   ./scripts/build-ios.sh [debug|release]
#   ./scripts/build-ios.sh xcode          # Generate Xcode project only
#   ./scripts/build-ios.sh archive        # Build .ipa for distribution
#
# After 'xcode' mode:
#   open build/ios/ResonaLens.xcodeproj
# ──────────────────────────────────────────────────────────────

set -euo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-debug}"
BUILD_DIR="build/ios"

echo "═══ ResonaLens iOS Build ═══"
echo "Mode: $MODE"

# ── Validate Environment ──
if [ "$(uname)" != "Darwin" ]; then
    echo "ERROR: iOS builds require macOS."
    exit 1
fi

if ! xcode-select -p &>/dev/null; then
    echo "ERROR: Xcode command line tools not found."
    echo "Run: xcode-select --install"
    exit 1
fi

if [ -z "${QT_IOS_DIR:-}" ]; then
    for candidate in \
        "$HOME/Qt/6.8.0/ios" \
        "$HOME/Qt/6.7.0/ios" \
        "/opt/Qt/6.8.0/ios" \
        "/opt/Qt/6.7.0/ios"; do
        if [ -d "$candidate" ]; then
            QT_IOS_DIR="$candidate"
            break
        fi
    done
fi

if [ -z "${QT_IOS_DIR:-}" ] || [ ! -d "${QT_IOS_DIR}" ]; then
    echo "ERROR: QT_IOS_DIR not set or not found."
    echo "Install Qt for iOS and set: export QT_IOS_DIR=~/Qt/6.8.0/ios"
    exit 1
fi

echo "Qt iOS: $QT_IOS_DIR"

CMAKE_CMD="$QT_IOS_DIR/bin/qt-cmake"
HOST_QT_DIR="$(dirname "$QT_IOS_DIR")/macos"

mkdir -p "$BUILD_DIR"

# ── Configure (generates Xcode project) ──
$CMAKE_CMD -S . -B "$BUILD_DIR" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=16.0 \
    -DQT_HOST_PATH="$HOST_QT_DIR" \
    -G Xcode

case "$MODE" in
    xcode)
        echo ""
        echo "═══ Xcode Project Generated ═══"
        echo "Open: $BUILD_DIR/ResonaLens.xcodeproj"
        echo ""
        echo "In Xcode:"
        echo "  1. Select your Development Team in Signing & Capabilities"
        echo "  2. Select a connected iOS device or simulator"
        echo "  3. Press Cmd+R to build and run"
        open "$BUILD_DIR/ResonaLens.xcodeproj" 2>/dev/null || true
        ;;

    archive)
        echo "Building archive for distribution..."

        TEAM_ID="${DEVELOPMENT_TEAM:-}"
        if [ -z "$TEAM_ID" ]; then
            echo "WARNING: DEVELOPMENT_TEAM not set. Archive may fail signing."
            echo "Set: export DEVELOPMENT_TEAM=YOUR_TEAM_ID"
        fi

        # Build archive
        xcodebuild archive \
            -project "$BUILD_DIR/ResonaLens.xcodeproj" \
            -scheme resonalens \
            -configuration Release \
            -archivePath "$BUILD_DIR/ResonaLens.xcarchive" \
            -destination "generic/platform=iOS" \
            ${TEAM_ID:+DEVELOPMENT_TEAM="$TEAM_ID"} \
            CODE_SIGN_STYLE=Automatic \
            -allowProvisioningUpdates

        # Export IPA
        cat > "$BUILD_DIR/ExportOptions.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>compileBitcode</key>
    <false/>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
</dict>
</plist>
PLIST

        xcodebuild -exportArchive \
            -archivePath "$BUILD_DIR/ResonaLens.xcarchive" \
            -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
            -exportPath "$BUILD_DIR/export"

        echo ""
        echo "═══ IPA Export Complete ═══"
        echo "Output: $BUILD_DIR/export/ResonaLens.ipa"
        ;;

    release)
        echo "Building Release..."
        cmake --build "$BUILD_DIR" --config Release --parallel "$(sysctl -n hw.ncpu)"
        echo ""
        echo "═══ Release Build Complete ═══"
        echo "To deploy: open $BUILD_DIR/ResonaLens.xcodeproj in Xcode"
        ;;

    debug|*)
        echo "Building Debug..."
        cmake --build "$BUILD_DIR" --config Debug --parallel "$(sysctl -n hw.ncpu)"
        echo ""
        echo "═══ Debug Build Complete ═══"
        echo "To deploy: open $BUILD_DIR/ResonaLens.xcodeproj in Xcode"
        ;;
esac
