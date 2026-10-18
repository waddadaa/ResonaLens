# third_party/websearchlib/CMakeLists.txt
cmake_minimum_required(VERSION 3.16)
project(websearch CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(websearch STATIC
    src/core/HtmlParser.cpp
    src/core/JsonParser.cpp
    src/core/ResultMerger.cpp
    src/core/SearchManager.cpp
    src/engines/DuckDuckGoEngine.cpp
    src/engines/BingEngine.cpp
    src/engines/BraveEngine.cpp
    src/engines/GoogleEngine.cpp
    src/engines/YahooEngine.cpp
    src/engines/QwantEngine.cpp
    src/engines/YepEngine.cpp
    src/engines/BaiduEngine.cpp
    src/engines/MojeekEngine.cpp
    src/engines/NaverEngine.cpp
    src/engines/YandexEngine.cpp
    src/engines/AolEngine.cpp
    src/engines/AskEngine.cpp
    src/engines/StartpageEngine.cpp
    src/engines/MarginaliaEngine.cpp
)

# On Android, use Qt-based HTTP (device's native OpenSSL) instead of curl (mbedTLS broken).
# All 14 search engines work through QNetworkAccessManager.
if(ANDROID)
    find_package(Qt6 REQUIRED COMPONENTS Network)
    target_sources(websearch PRIVATE src/core/HttpClientQt.cpp)
    target_compile_definitions(websearch PRIVATE WEBSEARCH_USE_QT_HTTP)
    target_link_libraries(websearch PRIVATE Qt6::Network)
else()
    target_sources(websearch PRIVATE src/core/HttpClient.cpp)
    find_package(CURL REQUIRED)
    target_link_libraries(websearch PRIVATE CURL::libcurl)
endif()

target_include_directories(websearch PUBLIC include)
target_include_directories(websearch PRIVATE
    src
    third_party/nlohmann_json
)

find_package(LibXml2 REQUIRED)
target_link_libraries(websearch PRIVATE LibXml2::LibXml2)

option(WEBSEARCH_BUILD_TESTS "Build websearchlib tests" ON)
if(WEBSEARCH_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()
