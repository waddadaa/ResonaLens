# Helper to create a Qt Test executable
function(add_qt_test NAME)
    qt_add_executable(${NAME} ${ARGN})
    target_include_directories(${NAME} PRIVATE
        ${CMAKE_SOURCE_DIR}/src
        ${CMAKE_SOURCE_DIR}/src/core
        ${CMAKE_SOURCE_DIR}/src/database
        ${CMAKE_SOURCE_DIR}/src/controllers
        ${CMAKE_SOURCE_DIR}/src/models
        ${CMAKE_SOURCE_DIR}/src/network
    )
    target_link_libraries(${NAME} PRIVATE
        Qt6::Core
        Qt6::Test
        Qt6::Sql
        Qt6::Network
        Qt6::Concurrent
    )
    add_test(NAME ${NAME} COMMAND ${NAME})
endfunction()

add_qt_test(tst_document_navigator
    core/tst_document_navigator.cpp
    ${CMAKE_SOURCE_DIR}/src/core/DocumentNavigator.cpp
)
add_qt_test(tst_knowledge_index_file
    core/tst_knowledge_index_file.cpp
    ${CMAKE_SOURCE_DIR}/src/core/KnowledgeIndexFile.cpp
)
add_qt_test(tst_markdown_converter
    core/tst_markdown_converter.cpp
    ${CMAKE_SOURCE_DIR}/src/core/MarkdownConverter.cpp
    ${CMAKE_SOURCE_DIR}/src/core/WebReaderBackend.cpp
    ${CMAKE_SOURCE_DIR}/third_party/miniz/miniz.c
)
target_link_libraries(tst_markdown_converter PRIVATE Qt6::Network Qt6::Gui)
target_include_directories(tst_markdown_converter PRIVATE
    ${CMAKE_SOURCE_DIR}/third_party/miniz
)
if(RESONALENS_ENABLE_POPPLER)
    target_compile_definitions(tst_markdown_converter PRIVATE RESONALENS_HAS_POPPLER)
    target_link_libraries(tst_markdown_converter PRIVATE poppler-cpp)
    target_include_directories(tst_markdown_converter PRIVATE
        ${CMAKE_SOURCE_DIR}/third_party/poppler/cpp
        ${CMAKE_BINARY_DIR}/third_party/poppler/cpp
    )
endif()
add_qt_test(tst_knowledge_reader
    core/tst_knowledge_reader.cpp
    ${CMAKE_SOURCE_DIR}/src/core/KnowledgeReader.cpp
    ${CMAKE_SOURCE_DIR}/src/core/DocumentNavigator.cpp
)
