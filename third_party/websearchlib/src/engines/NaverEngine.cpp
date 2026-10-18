// src/engines/NaverEngine.cpp
#include "engines/NaverEngine.h"
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

HttpRequest NaverEngine::buildRequest(const std::string& query) {
    HttpRequest req;
    req.url = "https://search.naver.com/search.naver?query=" + urlEncode(query)
              + "&where=web&start=1";
    req.headers["Accept-Language"] = "ko-KR,ko;q=0.9,en;q=0.8";
    return req;
}

std::vector<SearchResult> NaverEngine::parseResponse(const std::string& body, int /*status*/) {
    if (body.empty()) return {};
    HtmlParser parser(body);
    std::vector<SearchResult> results;

    // Naver stub structure:
    //   <ul class="lst_total">
    //     <li class="bx"><a class="link_tit" href="...">Title</a>
    //       <div class="total_dsc_wrap"><a class="api_txt_lines">Snippet</a></div>
    //     </li>
    //   </ul>
    auto links = parser.xpathNodes(
        "//ul[contains(@class,'lst_total')]/li[contains(@class,'bx')]"
        "//a[contains(@class,'link_tit')]",
        {"href"});
    auto snippets = parser.xpath(
        "//ul[contains(@class,'lst_total')]/li[contains(@class,'bx')]"
        "//div[contains(@class,'total_dsc_wrap')]//a[contains(@class,'api_txt_lines')]");

    for (size_t i = 0; i < links.size(); ++i) {
        SearchResult r;
        r.url     = links[i].count("href") ? links[i].at("href") : "";
        r.title   = links[i].count("text") ? links[i].at("text") : "";
        r.snippet = (i < snippets.size()) ? snippets[i] : "";
        if (!r.url.empty() && r.url.find("http") == 0 && !r.title.empty()
            && r.url.find("naver.com") == std::string::npos) {
            results.push_back(std::move(r));
        }
    }
    return results;
}

} // namespace websearch
