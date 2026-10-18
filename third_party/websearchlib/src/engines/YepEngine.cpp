// src/engines/YepEngine.cpp
#include "engines/YepEngine.h"
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

HttpRequest YepEngine::buildRequest(const std::string& query) {
    HttpRequest req;
    req.url = "https://api.yep.com/fs/2/search?client=web&no_correct=false"
              "&q=" + urlEncode(query) + "&safeSearch=off&type=web";
    req.headers["Referer"] = "https://yep.com/";
    req.headers["Origin"]  = "https://yep.com";
    return req;
}

std::vector<SearchResult> YepEngine::parseResponse(const std::string& body, int /*status*/) {
    if (body.empty()) return {};
    std::vector<SearchResult> results;
    try {
        using json = nlohmann::json;
        auto doc = json::parse(body);
        if (!doc.is_array() || doc.size() < 2) return {};
        for (const auto& item : doc[1]["results"]) {
            if (item.value("type", "") != "Organic") continue;
            SearchResult r;
            r.url     = item.value("url", "");
            r.title   = item.value("title", "");
            r.snippet = item.value("snippet", "");
            if (!r.url.empty() && r.url.find("http") == 0
                && r.url.find("yep.com") == std::string::npos) {
                results.push_back(std::move(r));
            }
        }
    } catch (...) {}
    return results;
}

} // namespace websearch
