// src/engines/QwantEngine.cpp
#include "engines/QwantEngine.h"
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

HttpRequest QwantEngine::buildRequest(const std::string& query) {
    HttpRequest req;
    req.url = "https://api.qwant.com/v3/search/web?q=" + urlEncode(query)
              + "&count=10&offset=0";
    req.headers["Accept"] = "application/json";
    return req;
}

std::vector<SearchResult> QwantEngine::parseResponse(const std::string& body, int /*status*/) {
    if (body.empty()) return {};
    std::vector<SearchResult> results;

    try {
        using json = nlohmann::json;
        auto doc = json::parse(body);
        if (doc.value("status", "") != "success") return {};

        auto mainline = doc["data"]["result"]["items"]["mainline"];
        for (const auto& group : mainline) {
            if (group.value("type", "") != "web") continue;
            for (const auto& item : group["items"]) {
                SearchResult r;
                r.url     = item.value("url", "");
                r.title   = item.value("title", "");
                r.snippet = item.value("desc", "");
                if (!r.url.empty() && r.url.find("http") == 0
                    && r.url.find("qwant.com") == std::string::npos) {
                    results.push_back(std::move(r));
                }
            }
        }
    } catch (...) {}
    return results;
}

} // namespace websearch
