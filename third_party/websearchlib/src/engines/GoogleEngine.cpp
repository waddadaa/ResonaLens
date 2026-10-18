// src/engines/GoogleEngine.cpp
// Ported from SearxNG's google.py — uses GSA User-Agent to get server-rendered
// HTML instead of the JS-only page that Google serves to browser UAs.
#include "engines/GoogleEngine.h"
#include "core/HtmlParser.h"
#include <sstream>
#include <iomanip>
#include <random>

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
    std::string decoded;
    for (size_t i = 0; i < s.size(); ++i) {
        if (s[i] == '%' && i + 2 < s.size()) {
            int val = std::stoi(s.substr(i + 1, 2), nullptr, 16);
            decoded += static_cast<char>(val);
            i += 2;
        } else if (s[i] == '+') {
            decoded += ' ';
        } else {
            decoded += s[i];
        }
    }
    return decoded;
}

// SearxNG uses Android Chrome + "GoogleApp/N" suffix.
// This tricks Google into returning server-rendered HTML with data-ved links
// instead of the JS-only page served to normal browsers.
std::string gsaUserAgent() {
    static const char* bases[] = {
        "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Mobile Safari/537.36",
        "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Mobile Safari/537.36",
        "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Mobile Safari/537.36",
    };
    static constexpr size_t count = sizeof(bases) / sizeof(bases[0]);
    thread_local std::mt19937 rng(std::random_device{}());
    std::uniform_int_distribution<size_t> dist(0, count - 1);
    std::uniform_int_distribution<int> appDist(0, 9);
    return std::string(bases[dist(rng)]) + " GoogleApp/" + std::to_string(appDist(rng));
}
} // anonymous namespace

HttpRequest GoogleEngine::buildRequest(const std::string& query) {
    HttpRequest req;
    // SearxNG-style URL: hl, lr, ie, oe, filter=0 params.
    // tbs=qdr:w for past-week freshness.
    req.url = std::string("https://www.google.com/search?")
        + "q=" + urlEncode(query)
        + "&hl=en-US&lr=lang_en&ie=utf8&oe=utf8&filter=0"
        + "&tbs=qdr:w";
    req.cookies["CONSENT"] = "YES+";
    // GSA User-Agent is the key — gets server-rendered HTML
    req.headers["User-Agent"] = gsaUserAgent();
    req.headers["Accept"] = "*/*";
    return req;
}

std::vector<SearchResult> GoogleEngine::parseResponse(const std::string& body, int /*status*/) {
    if (body.empty()) return {};
    HtmlParser parser(body);
    std::vector<SearchResult> results;

    // SearxNG xpath: //a[@data-ved and not(@class)]
    // These are the organic result links. Title is in .//div[@style],
    // snippet is in ../..//div[contains(@class, "ilUpNd")].
    auto resultLinks = parser.xpathNodes(
        "//a[@data-ved and not(@class)]",
        {"href"});

    for (auto& node : resultLinks) {
        std::string href = node.count("href") ? node.at("href") : "";
        if (href.empty()) continue;

        // Strip Google redirect: /url?q=https://actual.com&sa=U...
        if (href.find("/url?q=") == 0) {
            href = href.substr(7);
            size_t saPos = href.find("&sa=");
            if (saPos != std::string::npos) href = href.substr(0, saPos);
            href = urlDecode(href);
        }

        if (href.find("http") != 0) continue;
        if (href.find("google.com") != std::string::npos) continue;

        std::string title = node.count("text") ? node.at("text") : "";
        if (title.empty()) continue;

        SearchResult r;
        r.url   = href;
        r.title = title;
        results.push_back(std::move(r));
    }

    // Try to get snippets separately (class "ilUpNd" per SearxNG).
    // These don't always align 1:1 with links, so match best-effort.
    auto snippetNodes = parser.xpath(
        "//div[contains(@class,'ilUpNd')]");
    for (size_t i = 0; i < results.size() && i < snippetNodes.size(); ++i) {
        results[i].snippet = snippetNodes[i];
    }

    return results;
}

} // namespace websearch
