cmake_minimum_required(VERSION 3.21)

project(ResonaLens VERSION 0.1.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# Enable baseline compiler warnings — silent warnings let real bugs accumulate.
# Applied globally because Qt's AUTOMOC-generated code is already -Wno-unused-parameter clean.
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang|AppleClang")
    add_compile_options(-Wall -Wextra -Wpedantic -Wno-unused-parameter)
elseif(MSVC)
    add_compile_options(/W3)
endif()

# Default to Release if not specified — avoids debug-mode overhead (120MB → ~25MB)
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
    message(STATUS "Defaulting CMAKE_BUILD_TYPE to Release")
endif()

find_package(Qt6 6.7 REQUIRED COMPONENTS
    Quick
    QuickControls2
    Sql
    Network
    Multimedia
    Concurrent
    Test
)

qt_standard_project_setup(REQUIRES 6.7)

# ══════════════════════════════════════════════════════════════
# Platform Detection
# ══════════════════════════════════════════════════════════════
if(ANDROID)
    message(STATUS "Building for Android (ABI: ${ANDROID_ABI})")
    set(PLATFORM_ANDROID TRUE)
elseif(IOS)
    message(STATUS "Building for iOS")
    set(PLATFORM_IOS TRUE)
else()
    message(STATUS "Building for Desktop (${CMAKE_SYSTEM_NAME})")
    set(PLATFORM_DESKTOP TRUE)
endif()

# ══════════════════════════════════════════════════════════════
# C++ Sources
# ══════════════════════════════════════════════════════════════
set(CPP_SOURCES
    src/main.cpp
    src/database/Database.h
    src/database/Database.cpp
    src/models/Conversation.h
    src/models/Message.h
    src/models/LLMModel.h
    src/models/KnowledgeItem.h
    src/controllers/SettingsController.h
    src/controllers/SettingsController.cpp
    src/controllers/ChatController.h
    src/controllers/ChatController.cpp
    src/controllers/ModelController.h
    src/controllers/ModelController.cpp
    src/controllers/KnowledgeController.h
    src/controllers/KnowledgeController.cpp
    src/controllers/AudioController.h
    src/controllers/AudioController.cpp
    src/controllers/TtsController.h
    src/controllers/TtsController.cpp
    src/controllers/SkillController.h
    src/controllers/SkillController.cpp
    src/core/LlamaBackend.h
    src/core/LlamaBackend.cpp
    src/core/WhisperBackend.h
    src/core/WhisperBackend.cpp
    src/core/TtsBackend.h
    src/core/TtsBackend.cpp
    src/core/StreamingPcmDevice.h
    src/core/StreamingPcmDevice.cpp
    src/core/FileProcessor.h
    src/core/FileProcessor.cpp
    src/core/MarkdownConverter.h
    src/core/MarkdownConverter.cpp
    src/core/KnowledgeIndexFile.h
    src/core/KnowledgeIndexFile.cpp
    src/core/DocumentNavigator.h
    src/core/DocumentNavigator.cpp
    src/core/KnowledgeReader.h
    src/core/KnowledgeReader.cpp
    src/core/SkillExecutor.h
    src/core/SkillExecutor.cpp
    src/core/WebSearchBackend.h
    src/core/WebSearchBackend.cpp
    src/core/WebReaderBackend.h
    src/core/WebReaderBackend.cpp
    src/core/LiteRTBackend.h
    src/core/LiteRTBackend.cpp
    src/network/HuggingFaceApi.h
    src/network/HuggingFaceApi.cpp
    src/network/ModelDownloader.h
    src/network/ModelDownloader.cpp
    third_party/miniz/miniz.c
)

# ══════════════════════════════════════════════════════════════
# QML Files
# ══════════════════════════════════════════════════════════════
set(QML_FILES
    qml/main.qml
    qml/theme/Theme.qml
    qml/theme/qmldir
    qml/NavigationDrawerForm.ui.qml
    qml/NavigationDrawer.qml
    qml/pages/ChatPage.ui.qml
    qml/pages/ChatPage.qml
    qml/pages/ModelsPage.ui.qml
    qml/pages/ModelsPage.qml
    qml/pages/DocumentsPage.ui.qml
    qml/pages/DocumentsPage.qml
    qml/pages/SettingsPage.ui.qml
    qml/pages/SettingsPage.qml
    qml/components/ThemedIcon.qml
    qml/components/navigation/DrawerNavItem.ui.qml
    qml/components/navigation/ChatHistoryItem.ui.qml
    qml/components/chat/TextBubble.ui.qml
    qml/components/chat/InputBar.ui.qml
    qml/components/chat/InputBar.qml
    qml/components/chat/MessageList.ui.qml
    qml/components/chat/MessageList.qml
    qml/components/chat/StreamingIndicator.ui.qml
    qml/components/chat/ImageBubble.ui.qml
    qml/components/chat/AudioBubble.ui.qml
    qml/components/chat/DocumentBubble.ui.qml
    qml/components/chat/AttachMenu.ui.qml
    qml/components/chat/AttachMenu.qml
    qml/components/models/ModelCard.ui.qml
    qml/components/models/ModelSearchBar.ui.qml
    qml/components/models/ModelSearchBar.qml
    qml/components/models/ModelFilterBar.ui.qml
    qml/components/models/ModelFilterBar.qml
    qml/components/models/DownloadProgress.ui.qml
    qml/components/documents/DocumentRow.ui.qml
    qml/components/documents/AddDocumentSheet.ui.qml
    qml/components/documents/AddDocumentSheet.qml
    qml/components/documents/ChunkPreview.ui.qml
    qml/components/settings/ModelSelector.ui.qml
    qml/components/settings/ModelSelector.qml
    qml/components/settings/GenerationParams.ui.qml
    qml/components/settings/GenerationParams.qml
    qml/components/settings/TtsSettings.ui.qml
    qml/components/settings/TtsSettings.qml
    qml/components/settings/StorageManager.ui.qml
    qml/components/settings/StorageManager.qml
    qml/components/settings/ThemeSelector.ui.qml
    qml/components/settings/ThemeSelector.qml
    qml/modals/ModelDetailSheet.ui.qml
    qml/modals/ModelDetailSheet.qml
    qml/modals/AudioRecorderSheet.ui.qml
    qml/modals/AudioRecorderSheet.qml
    qml/modals/ImagePreview.ui.qml
    qml/modals/ImagePreview.qml
    qml/modals/DocumentViewer.ui.qml
    qml/modals/DocumentViewer.qml
    qml/modals/ChatSearchSheet.ui.qml
    qml/modals/ChatSearchSheet.qml
)

# ══════════════════════════════════════════════════════════════
# Resources
# ══════════════════════════════════════════════════════════════
set(RESOURCE_FILES
    ResonaLensContent/fonts/Outfit-Variable.ttf
    ResonaLensContent/images/icons/menu.svg
    ResonaLensContent/images/icons/arrow-left.svg
    ResonaLensContent/images/icons/search.svg
    ResonaLensContent/images/icons/send.svg
    ResonaLensContent/images/icons/paperclip.svg
    ResonaLensContent/images/icons/mic.svg
    ResonaLensContent/images/icons/square-pen.svg
    ResonaLensContent/images/icons/message-circle.svg
    ResonaLensContent/images/icons/brain.svg
    ResonaLensContent/images/icons/file-text.svg
    ResonaLensContent/images/icons/settings.svg
    ResonaLensContent/images/icons/download.svg
    ResonaLensContent/images/icons/x.svg
    ResonaLensContent/images/icons/chevron-right.svg
    ResonaLensContent/images/icons/chevron-down.svg
    ResonaLensContent/images/icons/ellipsis-vertical.svg
    ResonaLensContent/images/icons/plus.svg
    ResonaLensContent/images/icons/trash-2.svg
    ResonaLensContent/images/icons/volume-2.svg
    ResonaLensContent/images/icons/audio-lines.svg
    ResonaLensContent/images/icons/sun.svg
    ResonaLensContent/images/icons/moon.svg
    ResonaLensContent/images/icons/monitor.svg
    ResonaLensContent/images/icons/signal.svg
    ResonaLensContent/images/icons/wifi.svg
    ResonaLensContent/images/icons/battery-full.svg
    ResonaLensContent/images/icons/sparkles.svg
    ResonaLensContent/images/icons/link.svg
    ResonaLensContent/images/icons/pen-line.svg
    ResonaLensContent/images/icons/file.svg
    ResonaLensContent/images/icons/sliders-horizontal.svg
    ResonaLensContent/images/icons/key.svg
    ResonaLensContent/images/icons/eye.svg
    ResonaLensContent/images/icons/eye-off.svg
    ResonaLensContent/images/icons/lock.svg
    ResonaLensContent/images/icons/square.svg
)

# ══════════════════════════════════════════════════════════════
# Target Creation
# ══════════════════════════════════════════════════════════════
qt_add_executable(resonalens ${CPP_SOURCES})

qt_add_qml_module(resonalens
    URI ResonaLensApp
    VERSION 1.0
    QML_FILES ${QML_FILES}
    RESOURCES ${RESOURCE_FILES}
    NO_RESOURCE_TARGET_PATH
)

target_include_directories(resonalens PRIVATE
    src
    src/controllers
    src/core
    src/database
    src/models
    src/network
    third_party/miniz
)

target_link_libraries(resonalens PRIVATE
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Sql
    Qt6::Network
    Qt6::Multimedia
    Qt6::Concurrent
)

# ══════════════════════════════════════════════════════════════
# Third-party Libraries
# ══════════════════════════════════════════════════════════════

# websearchlib — multi-engine web search
set(WEBSEARCH_BUILD_TESTS OFF CACHE BOOL "" FORCE)
add_subdirectory(third_party/websearchlib)
target_link_libraries(resonalens PRIVATE websearch)

# ── poppler-cpp — PDF text extraction (cross-platform) ──
option(RESONALENS_ENABLE_POPPLER "Enable PDF support via poppler" ON)
if(RESONALENS_ENABLE_POPPLER)
    set(ENABLE_SPLASH OFF CACHE BOOL "" FORCE)
    set(ENABLE_UTILS OFF CACHE BOOL "" FORCE)
    set(ENABLE_GLIB OFF CACHE BOOL "" FORCE)
    set(ENABLE_GOBJECT_INTROSPECTION OFF CACHE BOOL "" FORCE)
    set(ENABLE_QT5 OFF CACHE BOOL "" FORCE)
    set(ENABLE_QT6 OFF CACHE BOOL "" FORCE)
    set(ENABLE_LIBOPENJPEG "none" CACHE STRING "" FORCE)
    set(ENABLE_DCTDECODER "none" CACHE STRING "" FORCE)
    set(ENABLE_CMS "none" CACHE STRING "" FORCE)
    set(ENABLE_LCMS OFF CACHE BOOL "" FORCE)
    set(ENABLE_LIBCURL OFF CACHE BOOL "" FORCE)
    set(ENABLE_CPP ON CACHE BOOL "" FORCE)
    set(BUILD_GTK_TESTS OFF CACHE BOOL "" FORCE)
    set(BUILD_CPP_TESTS OFF CACHE BOOL "" FORCE)
    set(BUILD_MANUAL_TESTS OFF CACHE BOOL "" FORCE)
    set(ENABLE_NSS3 OFF CACHE BOOL "" FORCE)
    set(ENABLE_GPGME OFF CACHE BOOL "" FORCE)
    set(ENABLE_LIBTIFF OFF CACHE BOOL "" FORCE)
    set(ENABLE_BOOST OFF CACHE BOOL "" FORCE)
    set(FONT_CONFIGURATION "generic" CACHE STRING "" FORCE)

    # Disable AUTOMOC for poppler (pure C/C++, no Qt signals)
    set(CMAKE_AUTOMOC_SAVED ${CMAKE_AUTOMOC})
    set(CMAKE_AUTOMOC OFF)
    add_subdirectory(third_party/poppler)
    set(CMAKE_AUTOMOC ${CMAKE_AUTOMOC_SAVED})

    target_link_libraries(resonalens PRIVATE poppler-cpp)
    target_compile_definitions(resonalens PRIVATE RESONALENS_HAS_POPPLER)
    target_include_directories(resonalens PRIVATE
        third_party/poppler/cpp
        ${CMAKE_BINARY_DIR}/third_party/poppler/cpp
    )
    message(STATUS "poppler enabled — PDF support active")
endif()

option(RESONALENS_ENABLE_LLAMA "Enable llama.cpp LLM inference" ON)

if(RESONALENS_ENABLE_LLAMA)
    set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
    set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
    set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)
    set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
    if(PLATFORM_IOS)
        set(GGML_METAL ON CACHE BOOL "" FORCE)
    else()
        # Vulkan for Android + Desktop (Linux/Windows). Metal handles iOS above.
        # No FORCE — allows override via -DGGML_VULKAN=OFF on command line.
        set(GGML_VULKAN ON CACHE BOOL "")
    endif()

    # Disable Qt AUTOMOC/AUTOUIC/AUTORCC for llama.cpp (pure C/C++, no Qt)
    set(CMAKE_AUTOMOC_SAVED ${CMAKE_AUTOMOC})
    set(CMAKE_AUTOUIC_SAVED ${CMAKE_AUTOUIC})
    set(CMAKE_AUTORCC_SAVED ${CMAKE_AUTORCC})
    set(CMAKE_AUTOMOC OFF)
    set(CMAKE_AUTOUIC OFF)
    set(CMAKE_AUTORCC OFF)

    add_subdirectory(third_party/llama.cpp)

    set(CMAKE_AUTOMOC ${CMAKE_AUTOMOC_SAVED})
    set(CMAKE_AUTOUIC ${CMAKE_AUTOUIC_SAVED})
    set(CMAKE_AUTORCC ${CMAKE_AUTORCC_SAVED})

    target_link_libraries(resonalens PRIVATE llama ggml)
    target_compile_definitions(resonalens PRIVATE RESONALENS_HAS_LLAMA)
    target_include_directories(resonalens PRIVATE
        third_party/llama.cpp/include
        third_party/llama.cpp/common
    )
endif()

# ── whisper.cpp — on-device Whisper STT (audio → text) ──
option(RESONALENS_ENABLE_WHISPER "Enable whisper.cpp speech-to-text" ON)
if(RESONALENS_ENABLE_WHISPER)
    set(WHISPER_BUILD_TESTS    OFF CACHE BOOL "" FORCE)
    set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
    set(WHISPER_BUILD_SERVER   OFF CACHE BOOL "" FORCE)
    set(WHISPER_SDL2           OFF CACHE BOOL "" FORCE)
    set(WHISPER_CURL           OFF CACHE BOOL "" FORCE)
    set(BUILD_SHARED_LIBS      OFF CACHE BOOL "" FORCE)

    # Disable Qt AUTOMOC for whisper.cpp (pure C/C++, no Qt)
    set(CMAKE_AUTOMOC_SAVED2 ${CMAKE_AUTOMOC})
    set(CMAKE_AUTOUIC_SAVED2 ${CMAKE_AUTOUIC})
    set(CMAKE_AUTORCC_SAVED2 ${CMAKE_AUTORCC})
    set(CMAKE_AUTOMOC OFF)
    set(CMAKE_AUTOUIC OFF)
    set(CMAKE_AUTORCC OFF)

    # whisper.cpp guards with: if (NOT TARGET ggml) ... endif()
    # Since llama.cpp already built the ggml target above, whisper.cpp
    # will reuse it — no duplicate symbols.
    add_subdirectory(third_party/whisper.cpp)

    set(CMAKE_AUTOMOC ${CMAKE_AUTOMOC_SAVED2})
    set(CMAKE_AUTOUIC ${CMAKE_AUTOUIC_SAVED2})
    set(CMAKE_AUTORCC ${CMAKE_AUTORCC_SAVED2})

    target_link_libraries(resonalens PRIVATE whisper)
    target_compile_definitions(resonalens PRIVATE RESONALENS_HAS_WHISPER)
    target_include_directories(resonalens PRIVATE
        third_party/whisper.cpp/include
    )
    message(STATUS "whisper.cpp enabled — STT active (sharing ggml with llama.cpp)")
endif()

# ── sherpa-onnx — on-device Kokoro TTS (text → phonemes → ONNX → audio) ──
option(RESONALENS_ENABLE_SHERPA_ONNX "Enable sherpa-onnx Kokoro TTS" ON)
if(RESONALENS_ENABLE_SHERPA_ONNX)
    if(PLATFORM_ANDROID)
        # Android: use pre-built shared libraries from build-android-deps.sh
        set(_SHERPA_LIB "${CMAKE_CURRENT_SOURCE_DIR}/build/android-deps/${ANDROID_ABI}/lib")
        if(EXISTS "${_SHERPA_LIB}/libsherpa-onnx-c-api.so")
            add_library(sherpa-onnx-c-api SHARED IMPORTED)
            set_target_properties(sherpa-onnx-c-api PROPERTIES
                IMPORTED_LOCATION "${_SHERPA_LIB}/libsherpa-onnx-c-api.so"
            )
            add_library(onnxruntime SHARED IMPORTED)
            set_target_properties(onnxruntime PROPERTIES
                IMPORTED_LOCATION "${_SHERPA_LIB}/libonnxruntime.so"
            )
            target_link_libraries(resonalens PRIVATE sherpa-onnx-c-api onnxruntime)
            target_compile_definitions(resonalens PRIVATE RESONALENS_HAS_SHERPA_ONNX)
            target_include_directories(resonalens PRIVATE third_party/sherpa-onnx)
            message(STATUS "sherpa-onnx enabled (pre-built Android) — Kokoro TTS active")
        else()
            message(WARNING "sherpa-onnx pre-built libs not found at ${_SHERPA_LIB}")
        endif()
    else()
        # Desktop: build from source
        set(SHERPA_ONNX_ENABLE_TESTS      OFF CACHE BOOL "" FORCE)
        set(SHERPA_ONNX_ENABLE_PYTHON     OFF CACHE BOOL "" FORCE)
        set(SHERPA_ONNX_ENABLE_PORTAUDIO  OFF CACHE BOOL "" FORCE)
        set(SHERPA_ONNX_ENABLE_JNI        OFF CACHE BOOL "" FORCE)
        set(SHERPA_ONNX_ENABLE_NODEJS     OFF CACHE BOOL "" FORCE)
        set(SHERPA_ONNX_ENABLE_BINARY     OFF CACHE BOOL "" FORCE)
        set(SHERPA_ONNX_ENABLE_WEBSOCKET  OFF CACHE BOOL "" FORCE)
        set(SHERPA_ONNX_ENABLE_TTS        ON  CACHE BOOL "" FORCE)
        set(SHERPA_ONNX_ENABLE_ASR        OFF CACHE BOOL "" FORCE)

        set(CMAKE_AUTOMOC_SAVED ${CMAKE_AUTOMOC})
        set(CMAKE_AUTOUIC_SAVED ${CMAKE_AUTOUIC})
        set(CMAKE_AUTORCC_SAVED ${CMAKE_AUTORCC})
        set(CMAKE_AUTOMOC OFF)
        set(CMAKE_AUTOUIC OFF)
        set(CMAKE_AUTORCC OFF)

        if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/third_party/sherpa-onnx/CMakeLists.txt")
            add_subdirectory(third_party/sherpa-onnx)
        else()
            include(FetchContent)
            FetchContent_Declare(sherpa_onnx
                GIT_REPOSITORY https://github.com/k2-fsa/sherpa-onnx.git
                GIT_TAG        v1.11.3
                GIT_SHALLOW    TRUE
            )
            FetchContent_MakeAvailable(sherpa_onnx)
        endif()

        set(CMAKE_AUTOMOC ${CMAKE_AUTOMOC_SAVED})
        set(CMAKE_AUTOUIC ${CMAKE_AUTOUIC_SAVED})
        set(CMAKE_AUTORCC ${CMAKE_AUTORCC_SAVED})

        target_link_libraries(resonalens PRIVATE sherpa-onnx-c-api)
        target_compile_definitions(resonalens PRIVATE RESONALENS_HAS_SHERPA_ONNX)
        target_include_directories(resonalens PRIVATE third_party/sherpa-onnx)
        message(STATUS "sherpa-onnx enabled (source build) — Kokoro TTS active")
    endif()

    # Copy the complete espeak-ng-data (fetched by sherpa-onnx via FetchContent)
    # next to the executable so TtsBackend can find it at runtime on desktop.
    # espeak-ng lands in _deps/espeak_ng-src/ because sherpa-onnx declares it
    # with FetchContent_Declare(espeak_ng ...) internally.
    set(_ESPEAK_DATA_SRC "${CMAKE_BINARY_DIR}/_deps/espeak_ng-src/espeak-ng-data")
    if(PLATFORM_DESKTOP)
        add_custom_command(TARGET resonalens POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_directory
                "${_ESPEAK_DATA_SRC}"
                "$<TARGET_FILE_DIR:resonalens>/espeak-ng-data"
            COMMENT "Copying espeak-ng-data next to executable"
            VERBATIM
        )
        message(STATUS "espeak-ng-data will be copied from: ${_ESPEAK_DATA_SRC}")
    endif()
endif()

# ── Copy LiteRT-LM binary and shared libs next to the executable (Desktop) ──
if(NOT PLATFORM_ANDROID AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/third_party/litert_lm_main")
    # Desktop: copy x86-64 binary and libs
    file(GLOB LITERT_SHARED_LIBS CONFIGURE_DEPENDS
         "${CMAKE_CURRENT_SOURCE_DIR}/third_party/lib*.so")
    add_custom_command(TARGET resonalens POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${CMAKE_CURRENT_SOURCE_DIR}/third_party/litert_lm_main"
            "$<TARGET_FILE_DIR:resonalens>/litert_lm_main"
        COMMENT "Copying litert_lm_main to build output"
    )
    foreach(LIB ${LITERT_SHARED_LIBS})
        add_custom_command(TARGET resonalens POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${LIB}"
                "$<TARGET_FILE_DIR:resonalens>/"
            COMMENT "Copying ${LIB} to build output"
        )
    endforeach()
endif()

# ══════════════════════════════════════════════════════════════
# Android Configuration
# ══════════════════════════════════════════════════════════════
if(PLATFORM_ANDROID)
    # Android-specific properties
    set_target_properties(resonalens PROPERTIES
        QT_ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/android"
        QT_ANDROID_MIN_SDK_VERSION 28
        QT_ANDROID_TARGET_SDK_VERSION 34
        QT_ANDROID_VERSION_CODE 1
        QT_ANDROID_VERSION_NAME "0.1.0"
        QT_ANDROID_ABIS "${ANDROID_ABI}"
    )

    # Bundle native shared libs that Android doesn't provide
    set(ANDROID_EXTRA_LIBS_LIST "")

    # libomp.so (OpenMP runtime needed by llama.cpp/whisper.cpp)
    find_library(ANDROID_LIBOMP omp PATHS
        "${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/lib/clang/21/lib/linux/aarch64"
        "${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/lib/clang/*/lib/linux/aarch64"
        NO_DEFAULT_PATH
    )
    if(ANDROID_LIBOMP)
        list(APPEND ANDROID_EXTRA_LIBS_LIST "${ANDROID_LIBOMP}")
        message(STATUS "Bundling libomp.so: ${ANDROID_LIBOMP}")
    endif()

    # OpenSSL (libssl_3.so + libcrypto_3.so — required by Qt for HTTPS)
    set(_DEPS_PREFIX "${CMAKE_CURRENT_SOURCE_DIR}/build/android-deps/${ANDROID_ABI}")
    if(EXISTS "${_DEPS_PREFIX}/lib/libssl_3.so")
        list(APPEND ANDROID_EXTRA_LIBS_LIST
            "${_DEPS_PREFIX}/lib/libcrypto_3.so"
            "${_DEPS_PREFIX}/lib/libssl_3.so"
        )
        message(STATUS "Bundling OpenSSL from: ${_DEPS_PREFIX}/lib/")
    else()
        message(WARNING "OpenSSL not found at ${_DEPS_PREFIX} — HTTPS won't work")
    endif()

    # LiteRT-LM: binary + GPU plugins bundled as assets (NOT in lib/).
    set(_LITERT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/third_party/litert_android_arm64")
    if(EXISTS "${_LITERT_DIR}/litert_lm_main")
        target_compile_definitions(resonalens PRIVATE RESONALENS_HAS_LITERT_CLI)
        message(STATUS "Bundling LiteRT-LM arm64 as assets: ${_LITERT_DIR}")
    endif()

    # Sherpa-onnx shared libs (TTS runtime)
    set(_SHERPA_LIB "${CMAKE_CURRENT_SOURCE_DIR}/build/android-deps/${ANDROID_ABI}/lib")
    if(EXISTS "${_SHERPA_LIB}/libsherpa-onnx-c-api.so")
        list(APPEND ANDROID_EXTRA_LIBS_LIST
            "${_SHERPA_LIB}/libonnxruntime.so"
            "${_SHERPA_LIB}/libsherpa-onnx-c-api.so"
        )
        message(STATUS "Bundling sherpa-onnx shared libs for TTS")
    endif()

    set_target_properties(resonalens PROPERTIES
        QT_ANDROID_EXTRA_LIBS "${ANDROID_EXTRA_LIBS_LIST}"
    )

    # Multi-ABI build support: arm64-v8a is primary, armeabi-v7a optional
    if(NOT ANDROID_ABI)
        set(ANDROID_ABI "arm64-v8a" CACHE STRING "Android ABI")
    endif()

    # Enable extractNativeLibs for large native libs (llama.cpp can be 50MB+)
    set_property(TARGET resonalens PROPERTY QT_ANDROID_EXTRA_PLUGINS "")

    # Android permissions are declared in AndroidManifest.xml
    # Runtime permissions are requested in QML/C++ when needed

    # Request large heap for LLM inference
    # (already set in AndroidManifest.xml via android:largeHeap="true")

    message(STATUS "Android SDK: ${ANDROID_SDK_ROOT}")
    message(STATUS "Android NDK: ${ANDROID_NDK}")
    message(STATUS "Android ABI: ${ANDROID_ABI}")
    message(STATUS "Android API: ${ANDROID_NATIVE_API_LEVEL}")
endif()

# ══════════════════════════════════════════════════════════════
# iOS Configuration
# ══════════════════════════════════════════════════════════════
if(PLATFORM_IOS)
    set_target_properties(resonalens PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/ios/Info.plist"
        MACOSX_BUNDLE_GUI_IDENTIFIER "com.resonalens.app"
        MACOSX_BUNDLE_BUNDLE_NAME "ResonaLens"
        MACOSX_BUNDLE_BUNDLE_VERSION "1"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "0.1.0"
        MACOSX_BUNDLE_LONG_VERSION_STRING "0.1.0"
        XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
        XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "16.0"
        XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME "AppIcon"
        XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "com.resonalens.app"
        XCODE_ATTRIBUTE_DEVELOPMENT_TEAM ""
        XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "iPhone Developer"
        XCODE_ATTRIBUTE_CODE_SIGN_STYLE "Automatic"
        XCODE_ATTRIBUTE_SWIFT_VERSION "5.0"
        XCODE_ATTRIBUTE_ENABLE_BITCODE "NO"
    )

    # Add iOS-specific resources
    set(IOS_RESOURCES
        ios/LaunchScreen.storyboard
    )
    target_sources(resonalens PRIVATE ${IOS_RESOURCES})
    set_source_files_properties(${IOS_RESOURCES} PROPERTIES
        MACOSX_PACKAGE_LOCATION Resources
    )

    # Entitlements
    set_target_properties(resonalens PROPERTIES
        XCODE_ATTRIBUTE_CODE_SIGN_ENTITLEMENTS
        "${CMAKE_CURRENT_SOURCE_DIR}/ios/ResonaLens.entitlements"
    )

    # Frameworks needed on iOS
    find_library(UIKIT_FRAMEWORK UIKit REQUIRED)
    find_library(AVFOUNDATION_FRAMEWORK AVFoundation REQUIRED)
    find_library(METAL_FRAMEWORK Metal REQUIRED)
    find_library(METALPERFORMANCESHADERS_FRAMEWORK MetalPerformanceShaders)
    find_library(ACCELERATE_FRAMEWORK Accelerate REQUIRED)

    target_link_libraries(resonalens PRIVATE
        ${UIKIT_FRAMEWORK}
        ${AVFOUNDATION_FRAMEWORK}
        ${METAL_FRAMEWORK}
        ${ACCELERATE_FRAMEWORK}
    )

    # Metal Performance Shaders (optional, for llama.cpp GPU acceleration)
    if(METALPERFORMANCESHADERS_FRAMEWORK)
        target_link_libraries(resonalens PRIVATE ${METALPERFORMANCESHADERS_FRAMEWORK})
    endif()

    message(STATUS "iOS SDK: ${CMAKE_OSX_SYSROOT}")
    message(STATUS "iOS Deployment Target: 16.0")
    message(STATUS "iOS Architectures: ${CMAKE_OSX_ARCHITECTURES}")
endif()

# ══════════════════════════════════════════════════════════════
# Desktop Configuration
# ══════════════════════════════════════════════════════════════
if(PLATFORM_DESKTOP)
    set_target_properties(resonalens PROPERTIES
        WIN32_EXECUTABLE TRUE
        MACOSX_BUNDLE TRUE
    )
endif()

# ══════════════════════════════════════════════════════════════
# Install Rules
# ══════════════════════════════════════════════════════════════
# ── Embed skills/ into binary via Qt resource system ──
# This makes them accessible at ":/skills/..." via QFile on all platforms
qt_add_resources(resonalens "skills"
    PREFIX "/skills"
    BASE "skills"
    FILES
        skills/web_search/Skill.md
        skills/web_search/resources/search_providers.json
        skills/web_reader/Skill.md
        skills/web_reader/resources/readability_rules.json
        skills/document_reader/Skill.md
        skills/document_reader/resources/supported_formats.json
        skills/knowledge_manager/Skill.md
        skills/knowledge_manager/resources/reader_config.json
        skills/paper_finder/Skill.md
        skills/paper_finder/resources/academic_apis.json
)

# ══════════════════════════════════════════════════════════════
# Tests (desktop only — Qt Test doesn't run on device)
# ══════════════════════════════════════════════════════════════
if(PLATFORM_DESKTOP)
    enable_testing()
    add_subdirectory(tests)
endif()

install(TARGETS resonalens
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

# Qt deploy helper (creates deployment scripts for all platforms)
qt_generate_deploy_qml_app_script(
    TARGET resonalens
    OUTPUT_SCRIPT deploy_script
    NO_UNSUPPORTED_PLATFORM_ERROR
)
install(SCRIPT ${deploy_script})
