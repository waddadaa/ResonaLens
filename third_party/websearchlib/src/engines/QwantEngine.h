// src/engines/QwantEngine.h
#pragma once
#include "websearch/Engine.h"

namespace websearch {
class QwantEngine : public IEngine {
public:
    std::string name() const override { return "qwant"; }
    HttpRequest buildRequest(const std::string& query) override;
    std::vector<SearchResult> parseResponse(const std::string& body, int status) override;
};
} // namespace websearch
