// src/engines/BaiduEngine.h
#pragma once
#include "websearch/Engine.h"

namespace websearch {
class BaiduEngine : public IEngine {
public:
    std::string name() const override { return "baidu"; }
    HttpRequest buildRequest(const std::string& query) override;
    std::vector<SearchResult> parseResponse(const std::string& body, int status) override;
};
} // namespace websearch
