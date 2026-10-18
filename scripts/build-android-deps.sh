#!/bin/bash
# ──────────────────────────────────────────────────────────────
# ResonaLens — Cross-compile Android dependencies
# ──────────────────────────────────────────────────────────────
# Builds: OpenSSL, mbedTLS → libcurl → libxml2  (arm64-v8a)
#
# Usage:  ./scripts/build-android-deps.sh [ABI] [API_LEVEL]
# Output: build/android-deps/<ABI>/  (lib/ + include/)
# ──────────────────────────────────────────────────────────────

set -euo pipefail
cd "$(dirname "$0")/.."

ABI="${1:-arm64-v8a}"
API_LEVEL="${2:-28}"
PREFIX="$(pwd)/build/android-deps/$ABI"
SRC_DIR="$(pwd)/build/android-deps/src"
NDK="${ANDROID_NDK_ROOT}"
TOOLCHAIN="$NDK/build/cmake/android.toolchain.cmake"
NJOBS="$(nproc 2>/dev/null || echo 4)"

echo "═══ Android Dependencies Build ═══"
echo "ABI:        $ABI"
echo "API level:  $API_LEVEL"
echo "NDK:        $NDK"
echo "Prefix:     $PREFIX"
echo ""

COMMON_CMAKE_ARGS=(
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN"
    -DANDROID_ABI="$ABI"
    -DANDROID_NATIVE_API_LEVEL="$API_LEVEL"
    -DANDROID_STL=c++_shared
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX="$PREFIX"
    -DCMAKE_PREFIX_PATH="$PREFIX"
    -DCMAKE_FIND_ROOT_PATH="$PREFIX"
    -DBUILD_SHARED_LIBS=OFF
    -G Ninja
)

mkdir -p "$SRC_DIR"

# ── 0. OpenSSL (shared libs — required by Qt's QSslSocket for HTTPS) ──
if [ ! -f "$PREFIX/lib/libssl.so" ]; then
    echo "=== [0/4] Building OpenSSL (shared, for Qt TLS) ==="
    if [ ! -d "$SRC_DIR/openssl" ]; then
        git clone --depth 1 --branch openssl-3.3.1 \
            https://github.com/openssl/openssl.git "$SRC_DIR/openssl"
    fi
    cd "$SRC_DIR/openssl"
    export ANDROID_NDK_HOME="$NDK"
    export PATH="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH"
    ./Configure android-arm64 \
        -D__ANDROID_API__="$API_LEVEL" \
        --prefix="$PREFIX" \
        --openssldir="$PREFIX/ssl" \
        shared \
        no-tests \
        no-ui-console
    make -j"$NJOBS"
    make install_sw
    # Qt on Android expects libssl_3.so / libcrypto_3.so naming
    cp -f "$PREFIX/lib/libssl.so" "$PREFIX/lib/libssl_3.so"
    cp -f "$PREFIX/lib/libcrypto.so" "$PREFIX/lib/libcrypto_3.so"
    cd "$OLDPWD"
    echo "    OpenSSL installed."
else
    echo "=== [0/4] OpenSSL — already built, skipping ==="
fi

# ── 1. mbedTLS (TLS backend for curl) ──
if [ ! -f "$PREFIX/lib/libmbedtls.a" ]; then
    echo "=== [1/4] Building mbedTLS ==="
    if [ ! -d "$SRC_DIR/mbedtls" ]; then
        git clone --depth 1 --branch v3.6.0 --recurse-submodules \
            https://github.com/Mbed-TLS/mbedtls.git "$SRC_DIR/mbedtls"
    fi
    cmake -S "$SRC_DIR/mbedtls" -B "$SRC_DIR/mbedtls-build" \
        "${COMMON_CMAKE_ARGS[@]}" \
        -DENABLE_TESTING=OFF \
        -DENABLE_PROGRAMS=OFF \
        -DMBEDTLS_FATAL_WARNINGS=OFF
    cmake --build "$SRC_DIR/mbedtls-build" --parallel "$NJOBS"
    cmake --install "$SRC_DIR/mbedtls-build"
    echo "    mbedTLS installed."
else
    echo "=== [1/4] mbedTLS — already built, skipping ==="
fi

# ── 2. libcurl (HTTP client) ──
if [ ! -f "$PREFIX/lib/libcurl.a" ]; then
    echo "=== [2/4] Building libcurl ==="
    if [ ! -d "$SRC_DIR/curl" ]; then
        git clone --depth 1 --branch curl-8_7_1 \
            https://github.com/curl/curl.git "$SRC_DIR/curl"
    fi
    cmake -S "$SRC_DIR/curl" -B "$SRC_DIR/curl-build" \
        "${COMMON_CMAKE_ARGS[@]}" \
        -DCURL_USE_MBEDTLS=ON \
        -DCURL_USE_OPENSSL=OFF \
        -DBUILD_CURL_EXE=OFF \
        -DBUILD_TESTING=OFF \
        -DCURL_DISABLE_LDAP=ON \
        -DCURL_DISABLE_LDAPS=ON \
        -DHTTP_ONLY=ON
    cmake --build "$SRC_DIR/curl-build" --parallel "$NJOBS"
    cmake --install "$SRC_DIR/curl-build"
    echo "    libcurl installed."
else
    echo "=== [2/4] libcurl — already built, skipping ==="
fi

# ── 3. libxml2 (HTML/XML parser) ──
if [ ! -f "$PREFIX/lib/libxml2.a" ]; then
    echo "=== [3/4] Building libxml2 ==="
    if [ ! -d "$SRC_DIR/libxml2" ]; then
        git clone --depth 1 --branch v2.12.6 \
            https://github.com/GNOME/libxml2.git "$SRC_DIR/libxml2"
    fi
    cmake -S "$SRC_DIR/libxml2" -B "$SRC_DIR/libxml2-build" \
        "${COMMON_CMAKE_ARGS[@]}" \
        -DLIBXML2_WITH_PYTHON=OFF \
        -DLIBXML2_WITH_TESTS=OFF \
        -DLIBXML2_WITH_PROGRAMS=OFF \
        -DLIBXML2_WITH_LZMA=OFF \
        -DLIBXML2_WITH_ZLIB=OFF \
        -DLIBXML2_WITH_ICU=OFF \
        -DLIBXML2_WITH_ICONV=OFF
    cmake --build "$SRC_DIR/libxml2-build" --parallel "$NJOBS"
    cmake --install "$SRC_DIR/libxml2-build"
    echo "    libxml2 installed."
else
    echo "=== [3/4] libxml2 — already built, skipping ==="
fi

# ── 4. Freetype (font rasterizer — required by poppler for PDF) ──
if [ ! -f "$PREFIX/lib/libfreetype.a" ]; then
    echo "=== [4/6] Building Freetype ==="
    if [ ! -d "$SRC_DIR/freetype" ]; then
        git clone --depth 1 --branch VER-2-13-3 \
            https://github.com/freetype/freetype.git "$SRC_DIR/freetype"
    fi
    cmake -S "$SRC_DIR/freetype" -B "$SRC_DIR/freetype-build" \
        "${COMMON_CMAKE_ARGS[@]}" \
        -DFT_DISABLE_HARFBUZZ=ON \
        -DFT_DISABLE_BROTLI=ON \
        -DFT_DISABLE_BZIP2=ON \
        -DFT_DISABLE_PNG=ON \
        -DFT_DISABLE_ZLIB=OFF
    cmake --build "$SRC_DIR/freetype-build" --parallel "$NJOBS"
    cmake --install "$SRC_DIR/freetype-build"
    echo "    Freetype installed."
else
    echo "=== [4/6] Freetype — already built, skipping ==="
fi

# ── 5. Sherpa-onnx pre-built (Kokoro TTS) ──
SHERPA_VER="1.11.3"
if [ ! -f "$PREFIX/lib/libsherpa-onnx-c-api.so" ]; then
    echo "=== [5/6] Downloading sherpa-onnx pre-built Android ==="
    SHERPA_URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/v${SHERPA_VER}/sherpa-onnx-v${SHERPA_VER}-android.tar.bz2"
    mkdir -p "$SRC_DIR/sherpa-onnx-prebuilt"
    if [ ! -d "$SRC_DIR/sherpa-onnx-prebuilt/jniLibs" ]; then
        curl -fsSL "$SHERPA_URL" | tar xj -C "$SRC_DIR/sherpa-onnx-prebuilt" --strip-components=1
    fi
    # The archive has jniLibs/arm64-v8a/*.so and include/
    if [ -d "$SRC_DIR/sherpa-onnx-prebuilt/jniLibs/arm64-v8a" ]; then
        cp -f "$SRC_DIR/sherpa-onnx-prebuilt/jniLibs/arm64-v8a/"*.so "$PREFIX/lib/"
    fi
    if [ -d "$SRC_DIR/sherpa-onnx-prebuilt/include" ]; then
        cp -r "$SRC_DIR/sherpa-onnx-prebuilt/include/"* "$PREFIX/include/"
    fi
    echo "    sherpa-onnx pre-built installed."
else
    echo "=== [5/6] sherpa-onnx — already installed, skipping ==="
fi

echo ""
echo "═══ All dependencies ready at: $PREFIX ═══"
