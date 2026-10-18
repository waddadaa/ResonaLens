// tests/test_json_parser.cpp
// DO NOT add #define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN here
#include "doctest/doctest.h"
#include "core/JsonParser.h"

using namespace websearch;

TEST_CASE("JsonParser - get string by dotted path") {
    JsonParser p(R"({"data":{"result":{"query":"hello"}}})");
    CHECK(p.get("data.result.query") == "hello");
}

TEST_CASE("JsonParser - get returns empty string on missing path") {
    JsonParser p(R"({"a":1})");
    CHECK(p.get("a.b.c") == "");
}

TEST_CASE("JsonParser - getArray returns items") {
    JsonParser p(R"({"results":[{"url":"https://a.com","title":"A"},{"url":"https://b.com","title":"B"}]})");
    auto arr = p.getArray("results");
    REQUIRE(arr.size() == 2);
    CHECK(arr[0].get("url") == "https://a.com");
    CHECK(arr[1].get("title") == "B");
}

TEST_CASE("JsonParser - handles invalid JSON") {
    JsonParser p("not json at all {{{");
    CHECK(p.get("anything") == "");
    CHECK(p.getArray("anything").empty());
}
