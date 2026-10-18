#!/bin/bash
# ──────────────────────────────────────────────────────────────
# ResonaLens — Android Build (APK / AAB)
# ──────────────────────────────────────────────────────────────
#
# Prerequisites:
#   1. Qt 6.7+ for Android installed (via Qt Online Installer)
#      - Select: Qt > Qt 6.x.x > Android (arm64-v8a)
#   2. Android SDK (API 34+) with:
#      - SDK Platform 34
#      - Build-Tools 34.0.0
#      - NDK 26.1.10909125 (or version matching your Qt)
#      - CMake (Android SDK version)
#   3. Java JDK 17 (required by Gradle 8.x)
#   4. Set environment variables (or Qt handles them)
#
# Environment variables:
#   QT_ANDROID_DIR    — Qt for Android (e.g., ~/Qt/6.8.0/android_arm64_v8a)
#   ANDROID_SDK_ROOT  — Android SDK path (e.g., ~/Android/Sdk)
#   ANDROID_NDK_ROOT  — Android NDK path (auto-detected from SDK if not set)
#   JAVA_HOME         — JDK 17 path
#
# Usage:
#   ./scripts/build-android.sh [debug|release] [apk|aab]
#
# Output:
#   APK: build/android/android-build/build/outputs/apk/
#   AAB: build/android/android-build/build/outputs/bundle/
# ──────────────────────────────────────────────────────────────

set -euo pipefail
cd "$(dirname "$0")/.."

BUILD_TYPE="${1:-Release}"
PACKAGE_TYPE="${2:-apk}"
BUILD_DIR="build/android"
ABI="arm64-v8a"

echo "═══ ResonaLens Android Build ═══"
echo "Build type:   $BUILD_TYPE"
echo "Package:      $PACKAGE_TYPE"
echo "ABI:          $ABI"

# ── Validate Environment ──
if [ -z "${QT_ANDROID_DIR:-}" ]; then
    # Try common locations
    for candidate in \
        "$HOME/Qt/6.8.0/android_arm64_v8a" \
        "$HOME/Qt/6.7.0/android_arm64_v8a" \
        "/opt/Qt/6.8.0/android_arm64_v8a" \
        "/opt/Qt/6.7.0/android_arm64_v8a"; do
        if [ -d "$candidate" ]; then
            QT_ANDROID_DIR="$candidate"
            break
        fi
    done
fi

if [ -z "${QT_ANDROID_DIR:-}" ] || [ ! -d "${QT_ANDROID_DIR}" ]; then
    echo "ERROR: QT_ANDROID_DIR not set or not found."
    echo "Install Qt for Android and set: export QT_ANDROID_DIR=~/Qt/6.8.0/android_arm64_v8a"
    exit 1
fi

if [ -z "${ANDROID_SDK_ROOT:-}" ]; then
    for candidate in "$HOME/Android/Sdk" "$HOME/Library/Android/sdk" "/opt/android-sdk"; do
        if [ -d "$candidate" ]; then
            ANDROID_SDK_ROOT="$candidate"
            break
        fi
    done
fi

if [ -z "${ANDROID_SDK_ROOT:-}" ]; then
    echo "ERROR: ANDROID_SDK_ROOT not set."
    echo "Set: export ANDROID_SDK_ROOT=~/Android/Sdk"
    exit 1
fi

# Auto-detect NDK from SDK
if [ -z "${ANDROID_NDK_ROOT:-}" ]; then
    ANDROID_NDK_ROOT=$(ls -d "$ANDROID_SDK_ROOT/ndk/"* 2>/dev/null | sort -V | tail -1)
fi

echo "Qt Android:   $QT_ANDROID_DIR"
echo "Android SDK:  $ANDROID_SDK_ROOT"
echo "Android NDK:  $ANDROID_NDK_ROOT"
echo ""

# ── Build cross-compiled dependencies (curl, libxml2, mbedtls) ──
DEPS_PREFIX="$(pwd)/build/android-deps/$ABI"
./scripts/build-android-deps.sh "$ABI" 28

CMAKE_CMD="$QT_ANDROID_DIR/bin/qt-cmake"

# Detect Qt host path (gcc_64 or linux_gcc_64 depending on Qt version)
QT_BASE="$(dirname "$QT_ANDROID_DIR")"
if [ -d "$QT_BASE/gcc_64" ]; then
    QT_HOST_PATH="$QT_BASE/gcc_64"
elif [ -d "$QT_BASE/linux_gcc_64" ]; then
    QT_HOST_PATH="$QT_BASE/linux_gcc_64"
else
    echo "ERROR: Cannot find Qt host tools (gcc_64 or linux_gcc_64) in $QT_BASE"
    exit 1
fi

mkdir -p "$BUILD_DIR"

# ── Configure ──
$CMAKE_CMD -S . -B "$BUILD_DIR" \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DQT_HOST_PATH="$QT_HOST_PATH" \
    -DCMAKE_PREFIX_PATH="$DEPS_PREFIX" \
    -DCMAKE_FIND_ROOT_PATH="$DEPS_PREFIX;$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/sysroot" \
    -DANDROID_SDK_ROOT="$ANDROID_SDK_ROOT" \
    -DANDROID_NDK="$ANDROID_NDK_ROOT" \
    -DANDROID_ABI="$ABI" \
    -DANDROID_NATIVE_API_LEVEL=28 \
    -DANDROID_STL=c++_shared \
    -DRESONALENS_ENABLE_POPPLER=ON \
    -DRESONALENS_ENABLE_SHERPA_ONNX=ON \
    -DGGML_VULKAN=OFF \
    -G Ninja

# ── Build ──
cmake --build "$BUILD_DIR" --parallel "$(nproc 2>/dev/null || echo 4)"

# ── Package ──
if [ "$PACKAGE_TYPE" = "aab" ]; then
    echo "Building Android App Bundle (AAB)..."
    cmake --build "$BUILD_DIR" --target aab
    echo ""
    echo "═══ AAB Build Complete ═══"
    echo "Output: $BUILD_DIR/android-build/build/outputs/bundle/"
else
    echo "Building APK..."
    cmake --build "$BUILD_DIR" --target apk
    echo ""
    echo "═══ APK Build Complete ═══"
    echo "Output: $BUILD_DIR/android-build/build/outputs/apk/"
    echo ""
    echo "Install to device:"
    echo "  adb install $BUILD_DIR/android-build/build/outputs/apk/debug/android-build-debug.apk"
fi
