// src/engines/MarginaliaEngine.cpp
#include "engines/MarginaliaEngine.h"
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

MarginaliaEngine::MarginaliaEngine(const std::string& apiKey) : m_apiKey(apiKey) {}

HttpRequest MarginaliaEngine::buildRequest(const std::string& query) {
    HttpRequest req;
    req.url = "https://api2.marginalia-search.com/search?query=" + urlEncode(query)
              + "&count=20&nsfw=1";
    req.headers["API-Key"] = m_apiKey;
    req.headers["User-Agent"] = "ResonaLens/websearchlib";
    req.headers["Accept"] = "application/json";
    return req;
}

std::vector<SearchResult> MarginaliaEngine::parseResponse(const std::string& body, int status) {
    if (body.empty() || status == 401 || status == 403) return {};
    std::vector<SearchResult> results;
    try {
        using json = nlohmann::json;
        auto doc = json::parse(body);
        for (const auto& item : doc["results"]) {
            SearchResult r;
            r.url     = item.value("url", "");
            r.title   = item.value("title", "");
            r.snippet = item.value("description", "");
            if (!r.url.empty() && r.url.find("http") == 0
                && r.url.find("marginalia-search.com") == std::string::npos) {
                results.push_back(std::move(r));
            }
        }
    } catch (...) {}
    return results;
}

} // namespace websearch
