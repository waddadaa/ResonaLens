#include "doctest/doctest.h"
#include "core/HtmlParser.h"

using namespace websearch;

static const char* TEST_HTML = R"(
<html><body>
  <div id="results">
    <div class="result">
      <h2><a href="https://example.com/1">First Result</a></h2>
      <p class="snippet">This is the first snippet</p>
    </div>
    <div class="result">
      <h2><a href="https://example.com/2">Second Result</a></h2>
      <p class="snippet">This is the second snippet</p>
    </div>
  </div>
</body></html>
)";

TEST_CASE("xpath - extract text content") {
    HtmlParser p(TEST_HTML);
    auto titles = p.xpath("//div[@class='result']//h2/a");
    REQUIRE(titles.size() == 2);
    CHECK(titles[0] == "First Result");
    CHECK(titles[1] == "Second Result");
}

TEST_CASE("xpathAttr - extract attribute value") {
    HtmlParser p(TEST_HTML);
    std::string href = p.xpathAttr("//div[@class='result'][1]//h2/a", "href");
    CHECK(href == "https://example.com/1");
}

TEST_CASE("xpathNodes - extract multiple attributes per node") {
    HtmlParser p(TEST_HTML);
    auto nodes = p.xpathNodes("//div[@class='result']//h2/a", {"href"});
    REQUIRE(nodes.size() == 2);
    CHECK(nodes[0].at("href") == "https://example.com/1");
    CHECK(nodes[1].at("href") == "https://example.com/2");
    CHECK(nodes[0].at("text") == "First Result");
}

TEST_CASE("xpath - returns empty on no match") {
    HtmlParser p(TEST_HTML);
    auto res = p.xpath("//div[@id='nonexistent']");
    CHECK(res.empty());
}

TEST_CASE("HtmlParser - handles malformed HTML") {
    HtmlParser p("<html><body><p>Unclosed");
    auto res = p.xpath("//p");
    REQUIRE(res.size() == 1);
    CHECK(res[0] == "Unclosed");
}
