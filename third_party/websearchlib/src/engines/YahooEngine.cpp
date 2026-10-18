// src/engines/YahooEngine.cpp
#include "engines/YahooEngine.h"
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

HttpRequest YahooEngine::buildRequest(const std::string& query) {
    HttpRequest req;
    req.url = "https://search.yahoo.com/search?p=" + urlEncode(query) + "&age=1w&btf=7d";
    req.headers["Accept-Language"] = "en-US,en;q=0.9";
    return req;
}

std::vector<SearchResult> YahooEngine::parseResponse(const std::string& body, int /*status*/) {
    if (body.empty()) return {};
    HtmlParser parser(body);
    std::vector<SearchResult> results;

    // Yahoo structure:
    //   <li class="algo-sr">
    //     <div class="compTitle">
    //       <a href="https://..."><h3><span>Title Text</span></h3></a>
    //     </div>
    //     <div class="compText">Snippet text</div>
    //   </li>
    auto links = parser.xpathNodes(
        "//li[contains(@class,'algo-sr')]//div[contains(@class,'compTitle')]/a",
        {"href"});
    auto titles = parser.xpath(
        "//li[contains(@class,'algo-sr')]//div[contains(@class,'compTitle')]/a//span");
    auto snippets = parser.xpath(
        "//li[contains(@class,'algo-sr')]//div[contains(@class,'compText')]");

    for (size_t i = 0; i < links.size(); ++i) {
        SearchResult r;
        r.url   = links[i].count("href") ? links[i].at("href") : "";
        r.title = (i < titles.size()) ? titles[i] : "";
        if (r.title.empty()) {
            // Fallback: use link text content
            r.title = links[i].count("text") ? links[i].at("text") : "";
        }
        r.snippet = (i < snippets.size()) ? snippets[i] : "";
        if (!r.url.empty() && r.url.find("http") == 0 && !r.title.empty()
            && r.url.find("yahoo.com") == std::string::npos) {
            results.push_back(std::move(r));
        }
    }
    return results;
}

} // namespace websearch
