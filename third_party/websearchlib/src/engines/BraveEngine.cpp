// src/engines/BraveEngine.cpp
// Ported from SearxNG's brave.py — uses current Svelte-based DOM selectors.
#include "engines/BraveEngine.h"
#include "core/HtmlParser.h"
#include <sstream>
#include <iomanip>

namespace websearch {

namespace {
std::string urlEncode(const std::string& s) {
    std::ostringstream out;
    for (unsigned char c : s) {
        if (std::isalnum(c) || c == '-' || c == '_' || c == '.' || c == '~') out << c;
        else if (c == ' ') out << '+';
        else out << '%' << std::uppercase << std::hex << std::setw(2) << std::setfill('0') << (int)c;
    }
    return out.str();
}
} // anonymous namespace

HttpRequest BraveEngine::buildRequest(const std::string& query) {
    HttpRequest req;
    // tf=pw = past week freshness filter
    req.url = "https://search.brave.com/search?q=" + urlEncode(query) + "&source=web&tf=pw";
    req.cookies["safesearch"] = "off";
    req.cookies["country"]    = "us";
    req.cookies["useLocation"] = "0";
    req.cookies["summarizer"]  = "0";
    return req;
}

std::vector<SearchResult> BraveEngine::parseResponse(const std::string& body, int /*status*/) {
    if (body.empty()) return {};
    HtmlParser parser(body);
    std::vector<SearchResult> results;

    // SearxNG xpath: //div[contains(@class, 'snippet ')] — note trailing space
    // distinguishes result snippets from other snippet-like elements.
    // Inside each snippet:
    //   .//a/@href                                        → result URL
    //   .//div[contains(@class, 'title')]                 → title text
    //   .//p[1]                                           → snippet/description
    auto snippetDivs = parser.xpathNodes(
        "//div[contains(@class,'snippet ')]",
        {});

    for (auto& node : snippetDivs) {
        // Each snippet div should have been parsed with its text — but we need
        // structured sub-elements. Use separate xpaths scoped to snippet divs.
        // Since HtmlParser doesn't support scoped queries, we use full-document
        // queries and pair them by index.
    }

    // Extract links: <a> tags inside snippet divs that have external hrefs
    // SearxNG: eval_xpath_getindex(result, ".//a/@href", 0)
    auto linkNodes = parser.xpathNodes(
        "//div[contains(@class,'snippet ')]//a[starts-with(@href,'http')]",
        {"href"});

    // Extract titles: div with class containing 'title'
    // SearxNG: eval_xpath_getindex(result, ".//div[contains(@class, 'title')]", 0)
    auto titleNodes = parser.xpath(
        "//div[contains(@class,'snippet ')]//div[contains(@class,'title')]");

    // Extract descriptions: first <p> in each snippet
    // SearxNG gets content from .//p[1] (the description paragraph)
    auto descNodes = parser.xpath(
        "//div[contains(@class,'snippet ')]//p[1]");

    size_t count = linkNodes.size();
    for (size_t i = 0; i < count; ++i) {
        SearchResult r;
        r.url = linkNodes[i].count("href") ? linkNodes[i].at("href") : "";
        if (r.url.empty() || r.url.find("http") != 0) continue;
        if (r.url.find("brave.com") != std::string::npos) continue;

        r.title = (i < titleNodes.size()) ? titleNodes[i] : "";
        if (r.title.empty()) continue;

        r.snippet = (i < descNodes.size()) ? descNodes[i] : "";
        results.push_back(std::move(r));
    }

    return results;
}

} // namespace websearch
