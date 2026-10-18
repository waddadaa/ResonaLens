// src/engines/BaiduEngine.cpp
#include "engines/BaiduEngine.h"
#include <json.hpp>
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

HttpRequest BaiduEngine::buildRequest(const std::string& query) {
    HttpRequest req;
    req.url = "https://www.baidu.com/s?wd=" + urlEncode(query) + "&rn=10&pn=0&tn=json";
    req.headers["Accept-Language"] = "zh-CN,zh;q=0.9,en;q=0.8";
    return req;
}

std::vector<SearchResult> BaiduEngine::parseResponse(const std::string& body, int /*status*/) {
    if (body.empty()) return {};
    std::vector<SearchResult> results;
    try {
        using json = nlohmann::json;
        auto doc = json::parse(body, nullptr, false);
        if (doc.is_discarded()) return {};
        for (const auto& entry : doc["feed"]["entry"]) {
            std::string url   = entry.value("url", "");
            std::string title = entry.value("title", "");
            std::string snip  = entry.value("abs", "");
            if (!url.empty() && url.find("http") == 0 && !title.empty()
                && url.find("baidu.com") == std::string::npos) {
                SearchResult r; r.url = url; r.title = title; r.snippet = snip;
                results.push_back(std::move(r));
            }
        }
    } catch (...) {}
    return results;
}

} // namespace websearch
