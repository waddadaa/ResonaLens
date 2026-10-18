# Third-party notices

ResonaLens includes or links the following third-party components. Each component remains
under its own license. See the license file in the component's directory or its upstream
repository for the full text.

| Component | Location | License |
|-----------|----------|---------|
| [llama.cpp](https://github.com/ggml-org/llama.cpp) | `third_party/llama.cpp` (submodule) | MIT |
| [whisper.cpp](https://github.com/ggml-org/whisper.cpp) | `third_party/whisper.cpp` (submodule) | MIT |
| [poppler](https://poppler.freedesktop.org/) | `third_party/poppler` (submodule) | GPL-2.0-or-later / GPL-3.0 |
| [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) | `third_party/sherpa-onnx` (submodule) | Apache-2.0 |
| [ONNX Runtime](https://github.com/microsoft/onnxruntime) | via sherpa-onnx | MIT |
| [espeak-ng](https://github.com/espeak-ng/espeak-ng) data | `android/assets/espeak-ng-data`, fetched by sherpa-onnx | GPL-3.0-or-later |
| [LiteRT-LM](https://github.com/google-ai-edge/LiteRT-LM) | prebuilt, not committed | Apache-2.0 |
| [miniz](https://github.com/richgel999/miniz) | `third_party/miniz` | MIT / Unlicense |
| [nlohmann/json](https://github.com/nlohmann/json) | `third_party/websearchlib/third_party/nlohmann_json` | MIT |
| [doctest](https://github.com/doctest/doctest) | `third_party/websearchlib/third_party/doctest` | MIT |
| [Outfit](https://fonts.google.com/specimen/Outfit) font | `ResonaLensContent/fonts` | SIL Open Font License 1.1 |
| [Lucide](https://lucide.dev/) icons | `ResonaLensContent/images/icons` | ISC |
| Mozilla CA certificate bundle | `android/assets/cacert.pem` | MPL-2.0 |
| [Qt](https://www.qt.io/) 6 | system / SDK | LGPL-3.0 (open-source edition) |
| OpenSSL, mbedTLS, libcurl, libxml2, FreeType | built by `scripts/build-android-deps.sh` | Apache-2.0, Apache-2.0, curl, MIT, FTL/GPL-2.0 |
