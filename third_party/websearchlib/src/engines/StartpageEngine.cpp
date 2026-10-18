// src/engines/StartpageEngine.cpp
// Startpage embeds results as React.createElement(UIStartpage.AppSerpWeb, {<json>})
// We extract the JSON object and parse
// render.presenter.regions.mainline[n (display_type=="web-google")].results[i].clickUrl/siteTitleData/description
#include "engines/StartpageEngine.h"
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
// Uses a string-aware brace counter.
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

// Strip HTML tags from a string
std::string stripHtml(const std::string& s) {
    std::string result;
    bool inTag = false;
    for (char c : s) {
        if (c == '<') { inTag = true; continue; }
        if (c == '>') { inTag = false; continue; }
        if (!inTag) result += c;
    }
    return result;
}
} // anonymous namespace

HttpRequest StartpageEngine::buildRequest(const std::string& query) {
    HttpRequest req;
    req.url = "https://www.startpage.com/search?q=" + urlEncode(query) + "&cat=web&with_date=w";
    req.headers["Referer"] = "https://www.startpage.com/";
    return req;
}

std::vector<SearchResult> StartpageEngine::parseResponse(const std::string& body, int status) {
    if (body.empty()) return {};
    std::vector<SearchResult> results;

    // Try both component names (Startpage has used both AppSerpSearch and AppSerpWeb)
    std::string jsonStr = extractJson(body, "React.createElement(UIStartpage.AppSerpSearch, ");
    if (jsonStr.empty())
        jsonStr = extractJson(body, "React.createElement(UIStartpage.AppSerpWeb, ");
    if (jsonStr.empty()) return {};

    try {
        using json = nlohmann::json;
        auto doc = json::parse(jsonStr, nullptr, false);
        if (doc.is_discarded()) return {};

        if (!doc.contains("render") || !doc["render"].contains("presenter") ||
            !doc["render"]["presenter"].contains("regions") ||
            !doc["render"]["presenter"]["regions"].contains("mainline")) return {};

        for (const auto& region : doc["render"]["presenter"]["regions"]["mainline"]) {
            if (region.value("display_type", "") != "web-google") continue;
            if (!region.contains("results")) continue;
            for (const auto& item : region["results"]) {
                SearchResult r;
                // Live fixture uses clickUrl for actual URL, anonViewUrl is a proxy
                if (item.contains("clickUrl"))
                    r.url = item.value("clickUrl", "");
                else if (item.contains("url"))
                    r.url = item.value("url", "");

                // siteTitleData is the title string in live fixture; stub uses "title"
                if (item.contains("siteTitleData") && item["siteTitleData"].is_string())
                    r.title = item.value("siteTitleData", "");
                else if (item.contains("title"))
                    r.title = item.value("title", "");

                r.snippet = stripHtml(item.value("description", ""));

                if (!r.url.empty() && r.url.find("http") == 0 && !r.title.empty()
                    && r.url.find("startpage.com") == std::string::npos) {
                    results.push_back(std::move(r));
                }
            }
        }
    } catch (...) {}
    return results;
}

} // namespace websearch
