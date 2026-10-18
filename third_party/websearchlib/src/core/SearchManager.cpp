// src/core/SearchManager.cpp
#include "websearch/SearchManager.h"
#include "core/HttpClient.h"
#include "core/ResultMerger.h"
#include <atomic>
#include <chrono>
#include <memory>
#include <mutex>
#include <thread>
#include <vector>

#include "engines/DuckDuckGoEngine.h"
#include "engines/BingEngine.h"
#include "engines/BraveEngine.h"
#include "engines/GoogleEngine.h"
#include "engines/YahooEngine.h"
#include "engines/QwantEngine.h"
#include "engines/YepEngine.h"
#include "engines/BaiduEngine.h"
#include "engines/MojeekEngine.h"
#include "engines/NaverEngine.h"
#include "engines/YandexEngine.h"
#include "engines/AolEngine.h"
#include "engines/AskEngine.h"
#include "engines/StartpageEngine.h"
// MarginaliaEngine requires API key — excluded from default factory

namespace websearch {

struct SearchManager::Impl {
    std::vector<std::unique_ptr<IEngine>> engines;
};

SearchManager::SearchManager() : m_impl(std::make_unique<Impl>()) {}
SearchManager::~SearchManager() = default;
SearchManager::SearchManager(SearchManager&&) noexcept = default;
SearchManager& SearchManager::operator=(SearchManager&&) noexcept = default;

void SearchManager::registerEngine(std::unique_ptr<IEngine> engine) {
    m_impl->engines.push_back(std::move(engine));
}

std::vector<SearchResult> SearchManager::search(const std::string& query,
                                                  const SearchOptions& opts)
{
    std::vector<IEngine*> activeEngines;
    for (auto& e : m_impl->engines) {
        if (opts.engines.empty()) {
            activeEngines.push_back(e.get());
        } else {
            for (const auto& name : opts.engines) {
                if (e->name() == name) { activeEngines.push_back(e.get()); break; }
            }
        }
    }

    // Shared state via shared_ptr so detached threads don't cause UB
    struct SharedState {
        std::vector<std::pair<std::string, std::vector<SearchResult>>> results;
        std::mutex mutex;
        std::atomic<int> doneCount{0};
    };

    auto state = std::make_shared<SharedState>();
    int totalCount = static_cast<int>(activeEngines.size());

    auto deadline = std::chrono::steady_clock::now()
                    + std::chrono::milliseconds(opts.timeout_ms);

    std::vector<std::thread> threads;
    threads.reserve(activeEngines.size());

    for (IEngine* engine : activeEngines) {
        threads.emplace_back([state, engine, query, opts]() {
            HttpClient client;
            HttpRequest req = engine->buildRequest(query);
            int engineTimeout = std::min(opts.timeout_ms, engine->timeout_ms());
            auto resp = client.execute(req, engineTimeout);
            auto results = engine->parseResponse(resp.body, resp.status);

            {
                std::lock_guard<std::mutex> lock(state->mutex);
                state->results.emplace_back(engine->name(), std::move(results));
            }
            state->doneCount.fetch_add(1, std::memory_order_release);
        });
    }

    // Poll until all threads finish or deadline is reached
    while (state->doneCount.load(std::memory_order_acquire) < totalCount) {
        if (std::chrono::steady_clock::now() >= deadline) break;
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }

    // Detach any still-running threads (timed-out ones)
    for (auto& t : threads) {
        if (t.joinable()) t.detach();
    }

    return mergeResults(state->results, opts.max_results);
}

SearchManager createDefaultSearchManager() {
    SearchManager mgr;
    mgr.registerEngine(std::make_unique<DuckDuckGoEngine>());
    mgr.registerEngine(std::make_unique<BingEngine>());
    mgr.registerEngine(std::make_unique<BraveEngine>());
    mgr.registerEngine(std::make_unique<GoogleEngine>());
    mgr.registerEngine(std::make_unique<YahooEngine>());
    mgr.registerEngine(std::make_unique<QwantEngine>());
    mgr.registerEngine(std::make_unique<YepEngine>());
    mgr.registerEngine(std::make_unique<BaiduEngine>());
    mgr.registerEngine(std::make_unique<MojeekEngine>());
    mgr.registerEngine(std::make_unique<NaverEngine>());
    mgr.registerEngine(std::make_unique<YandexEngine>());
    mgr.registerEngine(std::make_unique<AolEngine>());
    mgr.registerEngine(std::make_unique<AskEngine>());
    mgr.registerEngine(std::make_unique<StartpageEngine>());
    // To enable Marginalia: mgr.registerEngine(std::make_unique<MarginaliaEngine>("YOUR_KEY"));
    return mgr;
}

} // namespace websearch
