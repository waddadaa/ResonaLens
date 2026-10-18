// tests/test_search_manager.cpp
#include "doctest/doctest.h"
#include "websearch/SearchManager.h"
#include "websearch/Engine.h"
#include <chrono>
#include <thread>

using namespace websearch;

class MockEngine : public IEngine {
public:
    std::string engineName;
    std::vector<SearchResult> fixedResults;
    int delayMs = 0;

    MockEngine(const std::string& name, std::vector<SearchResult> results, int delay = 0)
        : engineName(name), fixedResults(std::move(results)), delayMs(delay) {}

    std::string name()       const override { return engineName; }
    double      weight()     const override { return 1.0; }
    int         timeout_ms() const override { return 2000; }

    HttpRequest buildRequest(const std::string&) override { return {}; }

    std::vector<SearchResult> parseResponse(const std::string&, int) override {
        if (delayMs > 0) std::this_thread::sleep_for(std::chrono::milliseconds(delayMs));
        return fixedResults;
    }
};

TEST_CASE("SearchManager - aggregates results from multiple engines") {
    SearchManager mgr;
    SearchResult r1; r1.url = "https://a.com"; r1.title = "A"; r1.snippet = "";
    SearchResult r2; r2.url = "https://b.com"; r2.title = "B"; r2.snippet = "";
    SearchResult r3; r3.url = "https://c.com"; r3.title = "C"; r3.snippet = "";

    mgr.registerEngine(std::make_unique<MockEngine>("e1", std::vector<SearchResult>{r1, r2}));
    mgr.registerEngine(std::make_unique<MockEngine>("e2", std::vector<SearchResult>{r3, r1}));

    // r1 appears in both engines → highest score
    // MockEngine.buildRequest returns empty HttpRequest (empty URL)
    // curl will fail immediately with an error, parseResponse will be called with body="" status=0
    // MockEngine.parseResponse ignores body/status → returns fixedResults always
    auto results = mgr.search("test", {.max_results = 10, .timeout_ms = 2000});
    REQUIRE(results.size() == 3);
    CHECK(results[0].url == "https://a.com");  // highest score (appears in both engines)
}

TEST_CASE("SearchManager - respects max_results") {
    SearchManager mgr;
    std::vector<SearchResult> many;
    for (int i = 0; i < 15; ++i) {
        SearchResult r; r.url = "https://site" + std::to_string(i) + ".com";
        r.title = "T"; r.snippet = "";
        many.push_back(r);
    }
    mgr.registerEngine(std::make_unique<MockEngine>("e1", many));
    auto results = mgr.search("test", {.max_results = 5});
    CHECK(results.size() == 5);
}

TEST_CASE("SearchManager - slow engine is skipped after timeout") {
    SearchManager mgr;
    SearchResult fast; fast.url = "https://fast.com"; fast.title = "F"; fast.snippet = "";
    SearchResult slow; slow.url = "https://slow.com"; slow.title = "S"; slow.snippet = "";

    mgr.registerEngine(std::make_unique<MockEngine>("fast", std::vector<SearchResult>{fast}, 0));
    mgr.registerEngine(std::make_unique<MockEngine>("slow", std::vector<SearchResult>{slow}, 3000));

    auto t0 = std::chrono::steady_clock::now();
    auto results = mgr.search("test", {.max_results = 10, .timeout_ms = 500});
    auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now() - t0).count();

    CHECK(elapsed < 1500);
    bool hasFast = false;
    for (const auto& r : results) if (r.url == "https://fast.com") hasFast = true;
    CHECK(hasFast);
}
