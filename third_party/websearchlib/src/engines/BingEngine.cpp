// src/engines/BingEngine.cpp
// Ported from SearxNG's bing.py
#include "engines/BingEngine.h"
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

std::string base64UrlDecode(const std::string& encoded) {
    std::string s = encoded;
    s += std::string((4 - s.size() % 4) % 4, '=');
    for (char& c : s) { if (c == '-') c = '+'; else if (c == '_') c = '/'; }
    static const std::string b64chars =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    std::string result;
    int val = 0, valb = -8;
    for (unsigned char c : s) {
        if (c == '=') break;
        size_t pos = b64chars.find(c);
        if (pos == std::string::npos) continue;
        val = (val << 6) + static_cast<int>(pos);
        valb += 6;
        if (valb >= 0) {
            result.push_back(static_cast<char>((val >> valb) & 0xFF));
            valb -= 8;
        }
    }
    return result;
}

std::string deobfuscateBingUrl(const std::string& href) {
    if (href.find("bing.com/ck/a?") == std::string::npos) return href;
    size_t uPos = href.find("&u=");
    if (uPos == std::string::npos) return href;
    std::string uVal = href.substr(uPos + 3);
    size_t end = uVal.find('&');
    if (end != std::string::npos) uVal = uVal.substr(0, end);
    if (uVal.size() >= 2 && uVal.substr(0, 2) == "a1") {
        return base64UrlDecode(uVal.substr(2));
    }
    return href;
}
} // anonymous namespace

HttpRequest BingEngine::buildRequest(const std::string& query) {
    HttpRequest req;
    // Keep it simple — no freshness filter (the encoded filter was triggering CAPTCHA).
    // SearxNG's bing.py only sends q + adlt + locale params.
    req.url = "https://www.bing.com/search?q=" + urlEncode(query) + "&adlt=off";
    req.headers["Accept-Language"] = "en-US,en;q=0.9";
    return req;
}

std::vector<SearchResult> BingEngine::parseResponse(const std::string& body, int /*status*/) {
    if (body.empty()) return {};

    // Detect CAPTCHA — Bing returns a page with class="captcha" when blocking
    if (body.find("class=\"captcha\"") != std::string::npos) return {};

    HtmlParser parser(body);
    std::vector<SearchResult> results;

    // SearxNG: //ol[@id="b_results"]/li[contains(@class, "b_algo")]
    //          .//h2/a for link+title, .//p for snippet
    auto links = parser.xpathNodes(
        "//ol[@id='b_results']/li[contains(@class,'b_algo')]//h2/a",
        {"href"});
    auto snippets = parser.xpath(
        "//ol[@id='b_results']/li[contains(@class,'b_algo')]//p[not(@class)]");

    for (size_t i = 0; i < links.size(); ++i) {
        SearchResult r;
        r.title = links[i].count("text") ? links[i].at("text") : "";
        std::string href = links[i].count("href") ? links[i].at("href") : "";
        r.url = deobfuscateBingUrl(href);
        r.snippet = (i < snippets.size()) ? snippets[i] : "";
        if (!r.url.empty() && r.url.find("http") == 0
            && r.url.find("bing.com") == std::string::npos) {
            results.push_back(std::move(r));
        }
    }
    return results;
}

} // namespace websearch
