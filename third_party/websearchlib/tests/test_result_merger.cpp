#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest/doctest.h"
#include "core/ResultMerger.h"

using namespace websearch;

TEST_CASE("URL normalization - lowercase scheme and host") {
    CHECK(normalizeUrl("HTTPS://Example.COM/path") == "https://example.com/path");
}

TEST_CASE("URL normalization - strip trailing slash") {
    CHECK(normalizeUrl("https://example.com/page/") == "https://example.com/page");
    CHECK(normalizeUrl("https://example.com/") == "https://example.com");
}

TEST_CASE("URL normalization - strip www prefix") {
    CHECK(normalizeUrl("https://www.example.com/") == "https://example.com");
}

TEST_CASE("URL normalization - strip tracking params") {
    CHECK(normalizeUrl("https://example.com/page?utm_source=google&id=1")
          == "https://example.com/page?id=1");
    CHECK(normalizeUrl("https://example.com/page?fbclid=abc123")
          == "https://example.com/page");
    CHECK(normalizeUrl("https://example.com/page?gclid=abc&q=hello")
          == "https://example.com/page?q=hello");
}

TEST_CASE("URL normalization - preserve non-tracking params") {
    CHECK(normalizeUrl("https://example.com/search?q=hello&page=2")
          == "https://example.com/search?q=hello&page=2");
}

TEST_CASE("mergeResults - deduplication by normalized URL") {
    using ER = std::pair<std::string, std::vector<SearchResult>>;
    SearchResult r1; r1.title = "Example"; r1.url = "https://example.com/page"; r1.snippet = "foo";
    SearchResult r2; r2.title = "Example"; r2.url = "https://www.example.com/page/"; r2.snippet = "bar";

    std::vector<ER> input = {
        {"engine_a", {r1}},
        {"engine_b", {r2}},
    };
    auto results = mergeResults(input, 10);
    CHECK(results.size() == 1);
    CHECK(results[0].engines.size() == 2);
}

TEST_CASE("mergeResults - score: higher position = lower score") {
    using ER = std::pair<std::string, std::vector<SearchResult>>;
    SearchResult p1; p1.url = "https://p1.com"; p1.title = "P1"; p1.snippet = "";
    SearchResult p5; p5.url = "https://p5.com"; p5.title = "P5"; p5.snippet = "";
    std::vector<ER> input2 = {{"engine", {p1, p5}}};
    auto results = mergeResults(input2, 10);
    REQUIRE(results.size() == 2);
    CHECK(results[0].url == "https://p1.com");
    CHECK(results[1].url == "https://p5.com");
}

TEST_CASE("mergeResults - score: appearing in 2 engines > appearing in 1") {
    using ER = std::pair<std::string, std::vector<SearchResult>>;
    SearchResult shared; shared.url = "https://shared.com"; shared.title = "S"; shared.snippet = "";
    SearchResult solo;   solo.url   = "https://solo.com";   solo.title   = "L"; solo.snippet = "";

    std::vector<ER> input = {
        {"engine_a", {solo, shared}},
        {"engine_b", {shared}},
    };
    auto results = mergeResults(input, 10);
    REQUIRE(results.size() == 2);
    CHECK(results[0].url == "https://shared.com");
    CHECK(results[1].url == "https://solo.com");
}

TEST_CASE("mergeResults - truncates to maxResults") {
    using ER = std::pair<std::string, std::vector<SearchResult>>;
    std::vector<SearchResult> many;
    for (int i = 0; i < 20; ++i) {
        SearchResult r; r.url = "https://site" + std::to_string(i) + ".com";
        r.title = "T" + std::to_string(i); r.snippet = "";
        many.push_back(r);
    }
    auto results = mergeResults({{"engine", many}}, 5);
    CHECK(results.size() == 5);
}
