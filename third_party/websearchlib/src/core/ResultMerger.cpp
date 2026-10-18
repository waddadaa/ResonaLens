// src/core/ResultMerger.cpp
#include "core/ResultMerger.h"
#include <algorithm>
#include <cctype>
#include <map>
#include <sstream>
#include <unordered_set>

namespace websearch {

namespace {

std::string toLower(std::string s) {
    std::transform(s.begin(), s.end(), s.begin(),
                   [](unsigned char c) { return std::tolower(c); });
    return s;
}

struct ParsedUrl {
    std::string scheme, host, path, query, fragment;
};

ParsedUrl parseUrl(const std::string& url) {
    ParsedUrl p;
    size_t schemeEnd = url.find("://");
    if (schemeEnd == std::string::npos) return p;
    p.scheme = url.substr(0, schemeEnd);
    size_t hostStart = schemeEnd + 3;
    size_t pathStart = url.find('/', hostStart);
    size_t queryStart = url.find('?', hostStart);
    size_t fragStart  = url.find('#', hostStart);

    size_t hostEnd = std::min({pathStart, queryStart, fragStart, url.size()});
    p.host = url.substr(hostStart, hostEnd - hostStart);

    if (pathStart != std::string::npos) {
        size_t pathEnd = std::min({queryStart, fragStart, url.size()});
        p.path = url.substr(pathStart, pathEnd - pathStart);
    }
    if (queryStart != std::string::npos) {
        size_t queryEnd = (fragStart != std::string::npos) ? fragStart : url.size();
        p.query = url.substr(queryStart + 1, queryEnd - queryStart - 1);
    }
    if (fragStart != std::string::npos) {
        p.fragment = url.substr(fragStart + 1);
    }
    return p;
}

std::string cleanQuery(const std::string& query) {
    static const std::unordered_set<std::string> trackingKeys = {
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
        "fbclid", "gclid", "ref", "source"
    };
    if (query.empty()) return "";

    std::string result;
    std::string part;
    std::istringstream ss(query);
    bool first = true;
    while (std::getline(ss, part, '&')) {
        std::string key = part.substr(0, part.find('='));
        bool isTracking = (trackingKeys.count(key) > 0) || (key.size() >= 4 && key.substr(0, 4) == "utm_");
        if (!isTracking) {
            if (!first) result += '&';
            result += part;
            first = false;
        }
    }
    return result;
}

} // anonymous namespace

std::string normalizeUrl(const std::string& rawUrl) {
    ParsedUrl p = parseUrl(rawUrl);
    if (p.scheme.empty()) return rawUrl;

    p.scheme = toLower(p.scheme);
    p.host   = toLower(p.host);

    if (p.host.size() >= 4 && p.host.substr(0, 4) == "www.") {
        p.host = p.host.substr(4);
    }

    while (p.path.size() > 1 && p.path.back() == '/') {
        p.path.pop_back();
    }
    if (p.path == "/") p.path = "";

    std::string cleanedQuery = cleanQuery(p.query);

    std::string result = p.scheme + "://" + p.host + p.path;
    if (!cleanedQuery.empty()) result += '?' + cleanedQuery;
    return result;
}

std::vector<SearchResult> mergeResults(
    const std::vector<std::pair<std::string, std::vector<SearchResult>>>& engineResults,
    int maxResults)
{
    std::map<std::string, SearchResult> merged;

    for (const auto& [engineName, results] : engineResults) {
        for (int i = 0; i < static_cast<int>(results.size()); ++i) {
            const SearchResult& r = results[i];
            if (r.url.empty()) continue;
            std::string normUrl = normalizeUrl(r.url);
            if (normUrl.empty()) continue;

            auto it = merged.find(normUrl);
            if (it == merged.end()) {
                SearchResult m = r;
                m.url = normUrl;
                m.engines = {engineName};
                m.positions = {i + 1};
                merged[normUrl] = std::move(m);
            } else {
                it->second.engines.push_back(engineName);
                it->second.positions.push_back(i + 1);
                if (it->second.title.empty() && !r.title.empty())
                    it->second.title = r.title;
                if (it->second.snippet.empty() && !r.snippet.empty())
                    it->second.snippet = r.snippet;
            }
        }
    }

    std::vector<SearchResult> scored;
    scored.reserve(merged.size());
    for (auto& [url, result] : merged) {
        double score = 0.0;
        for (int pos : result.positions) {
            score += 1.0 / pos;
        }
        result.score = score;
        scored.push_back(std::move(result));
    }

    std::sort(scored.begin(), scored.end(),
              [](const SearchResult& a, const SearchResult& b) {
                  return a.score > b.score;
              });

    if (static_cast<int>(scored.size()) > maxResults) {
        scored.resize(maxResults);
    }
    return scored;
}

} // namespace websearch
