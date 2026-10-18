// src/engines/StartpageEngine.h
#pragma once
#include "websearch/Engine.h"

namespace websearch {
class StartpageEngine : public IEngine {
public:
    std::string name() const override { return "startpage"; }
    HttpRequest buildRequest(const std::string& query) override;
    std::vector<SearchResult> parseResponse(const std::string& body, int status) override;
};
} // namespace websearch
