// src/core/ResultMerger.h
#pragma once
#include "websearch/Engine.h"
#include <string>
#include <vector>

namespace websearch {

std::string normalizeUrl(const std::string& url);

std::vector<SearchResult> mergeResults(
    const std::vector<std::pair<std::string, std::vector<SearchResult>>>& engineResults,
    int maxResults);

} // namespace websearch
