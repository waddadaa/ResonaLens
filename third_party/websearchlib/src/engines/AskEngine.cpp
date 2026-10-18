// src/engines/AskEngine.cpp
// Ask embeds results as window.MESON.initialState = {<json>};
// in a <script> tag. We extract JSON using brace-counting and parse
// search.webResults.results[].url/title/abstract
#include "engines/AskEngine.h"
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

// Extract a JSON object from the body starting after startMarker (which ends just before {).
// Uses a string-aware brace counter to find the matching closing brace.
std::string extractJson(const std::string& body, const std::string& startMarker) {
    size_t markerPos = body.find(startMarker);
    if (markerPos == std::string::npos) return "";
    size_t jsonStart = markerPos + startMarker.size();
    if (jsonStart >= body.size() || body[jsonStart] != '{') return "";

    int depth = 0;
    bool inString = false;
    bool escape = false;
    for (size_t i = jsonStart; i < body.size(); ++i) {
        char c = body[i];
        if (escape) { escape = false; continue; }
        if (c == '\\' && inString) { escape = true; continue; }
        if (c == '"') { inString = !inString; continue; }
        if (inString) continue;
        if (c == '{') ++depth;
        else if (c == '}') {
            --depth;
            if (depth == 0) return body.substr(jsonStart, i - jsonStart + 1);
        }
    }
    return "";
}
} // anonymous namespace

HttpRequest AskEngine::buildRequest(const std::string& query) {
    HttpRequest req;
    req.url = "https://www.ask.com/web?q=" + urlEncode(query) + "&page=1";
    req.headers["Accept-Language"] = "en-US,en;q=0.9";
    return req;
}

std::vector<SearchResult> AskEngine::parseResponse(const std::string& body, int status) {
    if (body.empty()) return {};
    std::vector<SearchResult> results;

    // Ask embeds: window.MESON.initialState = {<json>};
    std::string jsonStr = extractJson(body, "window.MESON.initialState = ");
    if (jsonStr.empty()) return {};

    try {
        using json = nlohmann::json;
        auto doc = json::parse(jsonStr, nullptr, false);
        if (doc.is_discarded()) return {};

        if (!doc.contains("search") || !doc["search"].contains("webResults") ||
            !doc["search"]["webResults"].contains("results")) return {};

        for (const auto& item : doc["search"]["webResults"]["results"]) {
            std::string url = item.value("url", "");
            // Strip tracking suffix
            size_t cut = url.find("&ueid");
            if (cut != std::string::npos) url = url.substr(0, cut);
            // Strip other common tracking params
            cut = url.find("?ad=");
            if (cut != std::string::npos) url = url.substr(0, cut);

            SearchResult r;
            r.url     = url;
            r.title   = item.value("title", "");
            r.snippet = item.value("abstract", "");
            if (!r.url.empty() && r.url.find("http") == 0 && !r.title.empty()
                && r.url.find("ask.com") == std::string::npos) {
                results.push_back(std::move(r));
            }
        }
    } catch (...) {}
    return results;
}

} // namespace websearch
