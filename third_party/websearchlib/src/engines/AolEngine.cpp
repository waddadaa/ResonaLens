// src/engines/AolEngine.cpp
#include "engines/AolEngine.h"
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

std::string urlDecode(const std::string& s) {
    std::string result;
    for (size_t i = 0; i < s.size(); ++i) {
        if (s[i] == '%' && i + 2 < s.size()) {
            int val = std::stoi(s.substr(i+1, 2), nullptr, 16);
            result += static_cast<char>(val);
            i += 2;
        } else if (s[i] == '+') {
            result += ' ';
        } else {
            result += s[i];
        }
    }
    return result;
}
} // anonymous namespace

std::string AolEngine::deobfuscateUrl(const std::string& href) {
    if (href.empty()) return "";
    // Split on / and find part starting with RU=
    std::istringstream ss(href);
    std::string part;
    while (std::getline(ss, part, '/')) {
        if (part.size() >= 3 && part.substr(0, 3) == "RU=") {
            return urlDecode(part.substr(3));
        }
    }
    return href;
}

HttpRequest AolEngine::buildRequest(const std::string& query) {
    HttpRequest req;
    req.url = "https://search.aol.com/aol/search?q=" + urlEncode(query)
              + "&b=1&pz=10&fr2=sb-top-search";
    req.cookies["sB"] = "vm=p";
    return req;
}

std::vector<SearchResult> AolEngine::parseResponse(const std::string& body, int status) {
    if (body.empty()) return {};
    HtmlParser parser(body);
    std::vector<SearchResult> results;

    // AOL is Yahoo-powered — try Yahoo-style selectors first
    auto links    = parser.xpathNodes(
        "//div[@id='web']//ol/li//h3/a",
        {"href"});
    auto snippets = parser.xpath(
        "//div[@id='web']//ol/li//div[contains(@class,'compText')]");

    // Fallback: Yahoo algo-sr pattern
    if (links.empty()) {
        links = parser.xpathNodes(
            "//div[contains(@class,'algo-sr')]//div[contains(@class,'compTitle')]/a",
            {"href"});
        snippets = parser.xpath(
            "//div[contains(@class,'algo-sr')]//div[contains(@class,'compText')]");
    }

    for (size_t i = 0; i < links.size(); ++i) {
        std::string obfHref = links[i].count("href") ? links[i].at("href") : "";
        std::string url = deobfuscateUrl(obfHref);
        if (url.empty()) url = obfHref;
        SearchResult r;
        r.url     = url;
        r.title   = links[i].count("text") ? links[i].at("text") : "";
        r.snippet = (i < snippets.size()) ? snippets[i] : "";
        if (!r.url.empty() && r.url.find("http") == 0 && !r.title.empty()
            && r.url.find("aol.com") == std::string::npos
            && r.url.find("yahoo.com") == std::string::npos) {
            results.push_back(std::move(r));
        }
    }
    return results;
}

} // namespace websearch
