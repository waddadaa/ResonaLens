// src/engines/MarginaliaEngine.h
#pragma once
#include "websearch/Engine.h"
#include <string>

namespace websearch {
class MarginaliaEngine : public IEngine {
public:
    explicit MarginaliaEngine(const std::string& apiKey = "");
    std::string name() const override { return "marginalia"; }
    HttpRequest buildRequest(const std::string& query) override;
    std::vector<SearchResult> parseResponse(const std::string& body, int status) override;
private:
    std::string m_apiKey;
};
} // namespace websearch
