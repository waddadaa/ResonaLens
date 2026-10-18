#!/bin/bash
# ──────────────────────────────────────────────────────────────
# ResonaLens — Desktop Build (Linux / macOS / Windows)
# ──────────────────────────────────────────────────────────────
#
# Prerequisites:
#   - Qt 6.7+ installed (via Qt Online Installer or system package)
#   - CMake 3.21+
#   - Ninja (recommended) or Make
#
# Usage:
#   ./scripts/build-desktop.sh [debug|release]
#
# Environment variables:
#   QT_DIR    — Path to Qt installation (e.g., ~/Qt/6.8.0/gcc_64)
#   If not set, assumes Qt is in PATH via qt-cmake
# ──────────────────────────────────────────────────────────────

set -euo pipefail
cd "$(dirname "$0")/.."

BUILD_TYPE="${1:-Release}"
BUILD_DIR="build/desktop-${BUILD_TYPE,,}"

echo "═══ ResonaLens Desktop Build ═══"
echo "Build type: $BUILD_TYPE"
echo "Build dir:  $BUILD_DIR"

mkdir -p "$BUILD_DIR"

# Detect qt-cmake or cmake with Qt prefix
if command -v qt-cmake &> /dev/null; then
    CMAKE_CMD="qt-cmake"
elif [ -n "${QT_DIR:-}" ]; then
    CMAKE_CMD="$QT_DIR/bin/qt-cmake"
else
    CMAKE_CMD="cmake"
    echo "Warning: Using system cmake. Set QT_DIR or ensure qt-cmake is in PATH."
fi

echo "Using: $CMAKE_CMD"

$CMAKE_CMD -S . -B "$BUILD_DIR" \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -G Ninja

cmake --build "$BUILD_DIR" --parallel "$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)"

echo ""
echo "═══ Build complete ═══"
echo "Binary: $BUILD_DIR/resonalens"
echo ""
echo "Run with: ./$BUILD_DIR/resonalens"
