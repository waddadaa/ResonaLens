// src/engines/DuckDuckGoEngine.cpp
#include "engines/DuckDuckGoEngine.h"
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

HttpRequest DuckDuckGoEngine::buildRequest(const std::string& query) {
    HttpRequest req;
    req.url    = "https://html.duckduckgo.com/html/";
    req.method = "POST";
    req.headers["Referer"]      = "https://html.duckduckgo.com/";
    req.headers["Content-Type"] = "application/x-www-form-urlencoded";
    req.cookies["kl"] = "en-us";
    req.body = "q=" + urlEncode(query) + "&b=&df=w";
    return req;
}

std::vector<SearchResult> DuckDuckGoEngine::parseResponse(const std::string& body, int /*status*/) {
    if (body.empty()) return {};
    std::vector<SearchResult> results;
    HtmlParser parser(body);

    // DDG HTML structure:
    //   <div class="result results_links results_links_deep web-result">
    //     <div class="links_main links_deep result__body">
    //       <h2 class="result__title">
    //         <a class="result__a" href="https://...">Title Text</a>
    //       </h2>
    //       <a class="result__snippet" href="...">Snippet text</a>
    //     </div>
    //   </div>
    auto links = parser.xpathNodes(
        "//div[contains(@class,'web-result')]//h2[@class='result__title']/a[@class='result__a']",
        {"href"});
    auto snippets = parser.xpath(
        "//div[contains(@class,'web-result')]//a[@class='result__snippet']");

    for (size_t i = 0; i < links.size(); ++i) {
        SearchResult r;
        r.url   = links[i].count("href") ? links[i].at("href") : "";
        r.title = links[i].count("text") ? links[i].at("text") : "";
        r.snippet = (i < snippets.size()) ? snippets[i] : "";
        if (!r.url.empty() && r.url.find("http") == 0
            && r.url.find("duckduckgo.com") == std::string::npos) {
            results.push_back(std::move(r));
        }
    }
    return results;
}

} // namespace websearch
