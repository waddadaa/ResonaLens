// src/engines/YahooEngine.h
#pragma once
#include "websearch/Engine.h"

namespace websearch {
class YahooEngine : public IEngine {
public:
    std::string name() const override { return "yahoo"; }
    HttpRequest buildRequest(const std::string& query) override;
    std::vector<SearchResult> parseResponse(const std::string& body, int status) override;
};
} // namespace websearch
