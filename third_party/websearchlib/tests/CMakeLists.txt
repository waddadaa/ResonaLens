# third_party/websearchlib/tests/CMakeLists.txt
add_executable(websearch_tests
    test_result_merger.cpp
    test_html_parser.cpp
    test_json_parser.cpp
    test_search_manager.cpp
    test_engines.cpp
)
target_include_directories(websearch_tests PRIVATE
    ${CMAKE_SOURCE_DIR}/include
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/third_party/nlohmann_json
    ${CMAKE_SOURCE_DIR}/third_party
)
target_link_libraries(websearch_tests PRIVATE websearch CURL::libcurl LibXml2::LibXml2)
add_test(NAME websearch_tests COMMAND websearch_tests)
