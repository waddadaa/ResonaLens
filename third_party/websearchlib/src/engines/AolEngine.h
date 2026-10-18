// src/engines/AolEngine.h
#pragma once
#include "websearch/Engine.h"

namespace websearch {
class AolEngine : public IEngine {
public:
    std::string name() const override { return "aol"; }
    HttpRequest buildRequest(const std::string& query) override;
    std::vector<SearchResult> parseResponse(const std::string& body, int status) override;
private:
    static std::string deobfuscateUrl(const std::string& obfuscated);
};
} // namespace websearch
