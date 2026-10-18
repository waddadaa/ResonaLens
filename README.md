# ResonaLens

ResonaLens is a private, on-device AI assistant built with Qt 6 / QML for desktop
(Linux, macOS, Windows), Android and iOS. Models run locally on the device, so
conversations and documents never leave it unless you explicitly use a web skill.

## Features

- **Local LLM chat:** GGUF models through [llama.cpp](https://github.com/ggml-org/llama.cpp)
  and `.litertlm` models through Google LiteRT-LM (CPU/GPU), with streaming output and
  conversation history stored in a local SQLite database.
- **Model manager:** browse, search and download models from Hugging Face. An optional
  access token unlocks gated models.
- **Knowledge base:** import PDF (via poppler), Markdown and text files or web pages, convert
  them to Markdown, index them and let the model navigate and cite them.
- **Voice:** speech-to-text with [whisper.cpp](https://github.com/ggml-org/whisper.cpp) and
  text-to-speech with Kokoro via [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx).
- **Skills:** prompt-driven tools defined in [`skills/`](skills/): web search (a built-in
  multi-engine metasearch library, `third_party/websearchlib`), web reader, document reader,
  knowledge manager and academic paper finder.
- Light and dark themes, plus a mobile-first UI built with Qt Quick Controls.

## Repository layout

| Path | Contents |
|------|----------|
| `src/controllers` | QML-facing controllers (chat, models, knowledge, audio, TTS, skills, settings) |
| `src/core` | Inference backends (llama.cpp, LiteRT, whisper, TTS), document processing, web search/reader |
| `src/database`, `src/models`, `src/network` | SQLite persistence, data types, Hugging Face API and downloader |
| `qml/` | UI pages, components, modals and theme |
| `skills/` | Skill definitions (`Skill.md`) and their resources |
| `android/`, `ios/` | Platform manifests, resources and assets |
| `third_party/` | Vendored and submodule dependencies |
| `scripts/` | Build helpers for desktop, Android and iOS |
| `tests/` | Qt Test unit tests |

## Getting the source

```bash
git clone --recurse-submodules https://github.com/waddadaa/ResonaLens.git
# or, in an existing clone:
git submodule update --init --recursive
```

## Building

Requirements: Qt 6.7+ (Quick, QuickControls2, Sql, Network, Multimedia, Concurrent, Test),
CMake 3.21+ and a C++17 compiler. Ninja is recommended.

```bash
# Desktop
QT_DIR=~/Qt/6.8.0/gcc_64 ./scripts/build-desktop.sh release

# Android (arm64-v8a): build the native dependencies first, then the APK/AAB
./scripts/build-android-deps.sh
./scripts/build-android.sh release apk

# iOS (macOS only)
./scripts/build-ios.sh
```

See the header of each script for the environment variables it expects
(`QT_DIR`, `QT_ANDROID_DIR`, `ANDROID_SDK_ROOT`, `ANDROID_NDK_ROOT`, `JAVA_HOME`).

Optional components can be switched off at configure time:

| CMake option | Default | Purpose |
|--------------|---------|---------|
| `RESONALENS_ENABLE_LLAMA` | `ON` | llama.cpp inference |
| `RESONALENS_ENABLE_WHISPER` | `ON` | whisper.cpp speech-to-text |
| `RESONALENS_ENABLE_SHERPA_ONNX` | `ON` | Kokoro TTS |
| `RESONALENS_ENABLE_POPPLER` | `ON` | PDF import |

### LiteRT-LM binaries (optional)

LiteRT-LM support uses prebuilt binaries that are **not** in the repository because of their
size. To enable it, download the LiteRT-LM release for your platform from
[google-ai-edge/LiteRT-LM](https://github.com/google-ai-edge/LiteRT-LM) and place:

- Desktop (x86-64): `litert_lm_main` and its `lib*.so` files in `third_party/`
- Android: `litert_lm_main` and its GPU plugin `.so` files in `third_party/litert_android_arm64/`
  and in `android/assets/litert/`

The build detects these files automatically and skips LiteRT when they are missing.

## Tests

```bash
cmake -B build -S . && cmake --build build
ctest --test-dir build --output-on-failure
```

## Privacy

Models, chats, documents and settings are stored in the application data directory on the
device. Network access is used only to download models, to call Hugging Face, and when a web
skill (search, reader, paper finder) runs. The optional Hugging Face token is stored in the
local settings database.

## License

ResonaLens is licensed under the [GNU General Public License v3.0](LICENSE). It links
GPL-licensed components (poppler, espeak-ng data), which makes GPLv3 the license that
distributed builds must follow. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)
for the licenses of bundled dependencies.
