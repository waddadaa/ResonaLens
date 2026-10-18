// include/websearch/Engine.h
#pragma once
#include <map>
#include <string>
#include <vector>

namespace websearch {

struct HttpRequest {
    std::string url;
    std::string method = "GET";
    std::map<std::string, std::string> headers;
    std::map<std::string, std::string> cookies;
    std::string body;  // non-empty only for POST engines (e.g. DuckDuckGo)
};

struct SearchResult {
    std::string title;
    std::string url;
    std::string snippet;
    // populated by ResultMerger after aggregation:
    std::vector<std::string> engines;
    std::vector<int>         positions;
    double                   score = 0.0;
};

class IEngine {
public:
    virtual ~IEngine() = default;
    virtual std::string name()       const = 0;
    virtual double      weight()     const { return 1.0; }
    virtual int         timeout_ms() const { return 5000; }

    virtual HttpRequest                buildRequest(const std::string& query) = 0;
    virtual std::vector<SearchResult>  parseResponse(const std::string& body,
                                                     int http_status) = 0;
};

} // namespace websearch
