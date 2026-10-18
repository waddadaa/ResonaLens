// tests/test_engines.cpp
// NO #define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN here!
#include "doctest/doctest.h"
#include "engines/DuckDuckGoEngine.h"
#include "engines/BingEngine.h"
#include "engines/BraveEngine.h"
#include "engines/GoogleEngine.h"
#include "engines/YahooEngine.h"
#include "engines/QwantEngine.h"
#include "engines/YepEngine.h"
#include "engines/BaiduEngine.h"
#include "engines/MojeekEngine.h"
#include "engines/NaverEngine.h"
#include "engines/YandexEngine.h"
#include "engines/AolEngine.h"
#include "engines/AskEngine.h"
#include "engines/StartpageEngine.h"
#include "engines/MarginaliaEngine.h"
#include <fstream>
#include <sstream>

using namespace websearch;

static std::string readFixture(const std::string& name) {
    std::ifstream f("fixtures/" + name);
    std::ostringstream ss;
    ss << f.rdbuf();
    return ss.str();
}

// ---- DuckDuckGo ----

TEST_CASE("DuckDuckGoEngine - buildRequest") {
    DuckDuckGoEngine e;
    auto req = e.buildRequest("test query");
    CHECK(req.method == "POST");
    CHECK(req.url == "https://html.duckduckgo.com/html/");
    CHECK(req.cookies.count("kl") > 0);
    CHECK(req.body.find("q=test") != std::string::npos);
}

TEST_CASE("DuckDuckGoEngine - parseResponse returns results") {
    DuckDuckGoEngine e;
    auto html = readFixture("duckduckgo.html");
    auto results = e.parseResponse(html, 200);
    REQUIRE(results.size() >= 3);
    for (const auto& r : results) {
        CHECK(!r.title.empty());
        CHECK(!r.url.empty());
        CHECK(r.url.find("http") == 0);
        CHECK(r.url.find("duckduckgo.com") == std::string::npos);
    }
}

// ---- Bing ----

TEST_CASE("BingEngine - buildRequest") {
    BingEngine e;
    auto req = e.buildRequest("test query");
    CHECK(req.method == "GET");
    CHECK(req.url.find("bing.com/search") != std::string::npos);
    CHECK(req.url.find("test") != std::string::npos);
}

TEST_CASE("BingEngine - parseResponse returns results") {
    BingEngine e;
    auto html = readFixture("bing.html");
    auto results = e.parseResponse(html, 200);
    REQUIRE(results.size() >= 3);
    for (const auto& r : results) {
        CHECK(!r.title.empty());
        CHECK(r.url.find("http") == 0);
        CHECK(r.url.find("bing.com") == std::string::npos);
    }
}

// ---- Brave ----

TEST_CASE("BraveEngine - buildRequest") {
    BraveEngine e;
    auto req = e.buildRequest("hello world");
    CHECK(req.method == "GET");
    CHECK(req.url.find("search.brave.com") != std::string::npos);
    CHECK(req.cookies.count("safesearch") > 0);
}

TEST_CASE("BraveEngine - parseResponse returns results") {
    BraveEngine e;
    auto html = readFixture("brave.html");
    auto results = e.parseResponse(html, 200);
    REQUIRE(results.size() >= 3);
    for (const auto& r : results) {
        CHECK(!r.title.empty());
        CHECK(r.url.find("http") == 0);
    }
}

// ---- Google ----

TEST_CASE("GoogleEngine - buildRequest") {
    GoogleEngine e;
    auto req = e.buildRequest("hello world");
    CHECK(req.method == "GET");
    CHECK(req.url.find("google.com/search") != std::string::npos);
    CHECK(req.cookies.count("CONSENT") > 0);
}

TEST_CASE("GoogleEngine - parseResponse returns results") {
    GoogleEngine e;
    auto html = readFixture("google.html");
    auto results = e.parseResponse(html, 200);
    REQUIRE(results.size() >= 3);
    for (const auto& r : results) {
        CHECK(!r.title.empty());
        CHECK(r.url.find("http") == 0);
        CHECK(r.url.find("google.com") == std::string::npos);
    }
}

// ---- Yahoo ----

TEST_CASE("YahooEngine - buildRequest") {
    YahooEngine e;
    auto req = e.buildRequest("hello world");
    CHECK(req.method == "GET");
    CHECK(req.url.find("search.yahoo.com") != std::string::npos);
}

TEST_CASE("YahooEngine - parseResponse returns results") {
    YahooEngine e;
    auto html = readFixture("yahoo.html");
    auto results = e.parseResponse(html, 200);
    REQUIRE(results.size() >= 3);
    for (const auto& r : results) {
        CHECK(!r.title.empty());
        CHECK(r.url.find("http") == 0);
    }
}

// ---- Qwant ----

TEST_CASE("QwantEngine - buildRequest") {
    QwantEngine e;
    auto req = e.buildRequest("hello world");
    CHECK(req.method == "GET");
    CHECK(req.url.find("api.qwant.com") != std::string::npos);
    CHECK(req.url.find("hello") != std::string::npos);
}

TEST_CASE("QwantEngine - parseResponse returns results") {
    QwantEngine e;
    auto json = readFixture("qwant.json");
    auto results = e.parseResponse(json, 200);
    REQUIRE(results.size() >= 3);
    for (const auto& r : results) {
        CHECK(!r.title.empty());
        CHECK(r.url.find("http") == 0);
    }
}

// ---- Yep ----

TEST_CASE("YepEngine - buildRequest") {
    YepEngine e;
    auto req = e.buildRequest("hello world");
    CHECK(req.method == "GET");
    CHECK(req.url.find("api.yep.com") != std::string::npos);
    CHECK(req.headers.count("Referer") > 0);
}

TEST_CASE("YepEngine - parseResponse returns results") {
    YepEngine e;
    auto json = readFixture("yep.json");
    auto results = e.parseResponse(json, 200);
    REQUIRE(results.size() >= 3);
    for (const auto& r : results) {
        CHECK(!r.title.empty());
        CHECK(r.url.find("http") == 0);
    }
}

// ---- Baidu ----

TEST_CASE("BaiduEngine - buildRequest") {
    BaiduEngine e;
    auto req = e.buildRequest("hello world");
    CHECK(req.method == "GET");
    CHECK(req.url.find("baidu.com/s") != std::string::npos);
    CHECK(req.url.find("tn=json") != std::string::npos);
}

TEST_CASE("BaiduEngine - parseResponse returns results") {
    BaiduEngine e;
    auto json = readFixture("baidu.json");
    auto results = e.parseResponse(json, 200);
    REQUIRE(results.size() >= 2);
    for (const auto& r : results) {
        CHECK(!r.title.empty());
        CHECK(r.url.find("http") == 0);
    }
}

// ---- Mojeek ----

TEST_CASE("MojeekEngine - buildRequest") {
    MojeekEngine e;
    auto req = e.buildRequest("hello world");
    CHECK(req.method == "GET");
    CHECK(req.url.find("mojeek.com") != std::string::npos);
}

TEST_CASE("MojeekEngine - parseResponse returns results") {
    MojeekEngine e;
    auto html = readFixture("mojeek.html");
    auto results = e.parseResponse(html, 200);
    REQUIRE(results.size() >= 3);
    for (const auto& r : results) {
        CHECK(!r.title.empty());
        CHECK(r.url.find("http") == 0);
    }
}

// ---- Naver ----

TEST_CASE("NaverEngine - buildRequest") {
    NaverEngine e;
    auto req = e.buildRequest("hello world");
    CHECK(req.method == "GET");
    CHECK(req.url.find("search.naver.com") != std::string::npos);
    CHECK(req.url.find("where=web") != std::string::npos);
}

TEST_CASE("NaverEngine - parseResponse returns results") {
    NaverEngine e;
    auto html = readFixture("naver.html");
    auto results = e.parseResponse(html, 200);
    REQUIRE(results.size() >= 3);
    for (const auto& r : results) {
        CHECK(!r.title.empty());
        CHECK(r.url.find("http") == 0);
    }
}

// ---- Yandex ----

TEST_CASE("YandexEngine - buildRequest") {
    YandexEngine e;
    auto req = e.buildRequest("hello world");
    CHECK(req.method == "GET");
    CHECK(req.url.find("yandex.com/search") != std::string::npos);
}

TEST_CASE("YandexEngine - parseResponse returns results") {
    YandexEngine e;
    auto html = readFixture("yandex.html");
    auto results = e.parseResponse(html, 200);
    REQUIRE(results.size() >= 3);
    for (const auto& r : results) {
        CHECK(!r.title.empty());
        CHECK(r.url.find("http") == 0);
    }
}

// ---- AOL ----

TEST_CASE("AolEngine - buildRequest") {
    AolEngine e;
    auto req = e.buildRequest("hello world");
    CHECK(req.method == "GET");
    CHECK(req.url.find("search.aol.com") != std::string::npos);
}

TEST_CASE("AolEngine - parseResponse returns results") {
    AolEngine e;
    auto html = readFixture("aol.html");
    auto results = e.parseResponse(html, 200);
    REQUIRE(results.size() >= 3);
    for (const auto& r : results) {
        CHECK(!r.title.empty());
        CHECK(r.url.find("http") == 0);
        CHECK(r.url.find("aol.com") == std::string::npos);
    }
}

// ---- Ask ----

TEST_CASE("AskEngine - buildRequest") {
    AskEngine e;
    auto req = e.buildRequest("hello world");
    CHECK(req.method == "GET");
    CHECK(req.url.find("ask.com/web") != std::string::npos);
}

TEST_CASE("AskEngine - parseResponse returns results") {
    AskEngine e;
    auto html = readFixture("ask.html");
    auto results = e.parseResponse(html, 200);
    REQUIRE(results.size() >= 3);
    for (const auto& r : results) {
        CHECK(!r.title.empty());
        CHECK(r.url.find("http") == 0);
    }
}

// ---- Startpage ----

TEST_CASE("StartpageEngine - buildRequest") {
    StartpageEngine e;
    auto req = e.buildRequest("hello world");
    CHECK(req.method == "GET");
    CHECK(req.url.find("startpage.com") != std::string::npos);
}

TEST_CASE("StartpageEngine - parseResponse returns results") {
    StartpageEngine e;
    auto html = readFixture("startpage.html");
    auto results = e.parseResponse(html, 200);
    REQUIRE(results.size() >= 3);
    for (const auto& r : results) {
        CHECK(!r.title.empty());
        CHECK(r.url.find("http") == 0);
    }
}

// ---- Marginalia ----

TEST_CASE("MarginaliaEngine - buildRequest") {
    MarginaliaEngine e("");
    auto req = e.buildRequest("hello world");
    CHECK(req.method == "GET");
    CHECK(req.url.find("marginalia-search.com") != std::string::npos);
    CHECK(req.headers.count("API-Key") > 0);
}

TEST_CASE("MarginaliaEngine - parseResponse returns results") {
    MarginaliaEngine e("");
    auto json = readFixture("marginalia.json");
    auto results = e.parseResponse(json, 200);
    REQUIRE(results.size() >= 1);
    for (const auto& r : results) {
        CHECK(!r.title.empty());
        CHECK(r.url.find("http") == 0);
    }
}
