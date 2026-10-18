// src/engines/MojeekEngine.cpp
#include "engines/MojeekEngine.h"
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

HttpRequest MojeekEngine::buildRequest(const std::string& query) {
    HttpRequest req;
    req.url = "https://www.mojeek.com/search?q=" + urlEncode(query) + "&safe=0";
    return req;
}

std::vector<SearchResult> MojeekEngine::parseResponse(const std::string& body, int /*status*/) {
    if (body.empty()) return {};
    HtmlParser parser(body);
    std::vector<SearchResult> results;

    // Mojeek structure:
    //   <li class="r1"><a class="ob" href="https://...">...</a>
    //     <h2><a class="title" href="...">Title</a></h2>
    //     <p class="s">Snippet</p>
    //   </li>
    // Use h2/a[@class='title'] as primary driver: exactly one per web result,
    // provides both URL (href attr) and title (text content).
    auto titleNodes  = parser.xpathNodes("//h2/a[@class='title']", {"href"});
    auto snippets    = parser.xpath("//p[@class='s']");

    for (size_t i = 0; i < titleNodes.size(); ++i) {
        SearchResult r;
        r.url     = titleNodes[i].count("href") ? titleNodes[i].at("href") : "";
        r.title   = titleNodes[i].count("text") ? titleNodes[i].at("text") : "";
        r.snippet = (i < snippets.size()) ? snippets[i] : "";
        if (!r.url.empty() && r.url.find("http") == 0 && !r.title.empty()
            && r.url.find("mojeek.com") == std::string::npos) {
            results.push_back(std::move(r));
        }
    }
    return results;
}

} // namespace websearch
