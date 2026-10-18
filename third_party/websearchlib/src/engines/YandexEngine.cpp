// src/engines/YandexEngine.cpp
#include "engines/YandexEngine.h"
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

HttpRequest YandexEngine::buildRequest(const std::string& query) {
    HttpRequest req;
    req.url = "https://yandex.com/search/?text=" + urlEncode(query) + "&lang=en";
    req.headers["Accept-Language"] = "en-US,en;q=0.9";
    return req;
}

std::vector<SearchResult> YandexEngine::parseResponse(const std::string& body, int status) {
    if (body.empty()) return {};
    HtmlParser parser(body);
    std::vector<SearchResult> results;

    auto links = parser.xpathNodes(
        "//li[contains(@class,'serp-item')]"
        "//a[@class='b-serp-item__title-link']",
        {"href"});
    auto snippets = parser.xpath(
        "//li[contains(@class,'serp-item')]"
        "//div[@class='b-serp-item__content']//div[@class='b-serp-item__text']");

    for (size_t i = 0; i < links.size(); ++i) {
        SearchResult r;
        r.url     = links[i].count("href") ? links[i].at("href") : "";
        r.title   = links[i].count("text") ? links[i].at("text") : "";
        r.snippet = (i < snippets.size()) ? snippets[i] : "";
        if (!r.url.empty() && r.url.find("http") == 0 && !r.title.empty()
            && r.url.find("yandex.com") == std::string::npos) {
            results.push_back(std::move(r));
        }
    }
    return results;
}

} // namespace websearch
