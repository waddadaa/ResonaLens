// include/websearch/SearchManager.h
#pragma once
#include "Engine.h"
#include <memory>
#include <vector>

namespace websearch {

struct SearchOptions {
    int max_results = 10;
    int timeout_ms  = 5000;
    std::vector<std::string> engines = {};  // empty = all registered engines
};

class SearchManager {
public:
    SearchManager();
    ~SearchManager();
    SearchManager(SearchManager&&) noexcept;
    SearchManager& operator=(SearchManager&&) noexcept;

    void registerEngine(std::unique_ptr<IEngine> engine);

    // Blocking. Returns when all engines complete or timeout_ms elapses.
    std::vector<SearchResult> search(const std::string& query,
                                     const SearchOptions& opts = {});

private:
    struct Impl;
    std::unique_ptr<Impl> m_impl;
};

// Factory: returns SearchManager with all 15 V1 engines pre-registered.
SearchManager createDefaultSearchManager();

} // namespace websearch
