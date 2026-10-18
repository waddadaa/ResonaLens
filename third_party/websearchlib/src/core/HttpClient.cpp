// src/core/HttpClient.cpp
#include "core/HttpClient.h"
#include <curl/curl.h>
#include <sstream>
#include <random>
#include <mutex>
#ifdef __ANDROID__
#include <android/log.h>
#define LOG_TAG "WebSearchCurl"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#else
#include <cstdio>
#define LOGI(...) fprintf(stderr, __VA_ARGS__)
#define LOGE(...) fprintf(stderr, __VA_ARGS__)
#endif

namespace websearch {

namespace {
size_t writeCallback(char* ptr, size_t size, size_t nmemb, void* userdata) {
    auto* buf = static_cast<std::string*>(userdata);
    buf->append(ptr, size * nmemb);
    return size * nmemb;
}
} // anonymous namespace

struct HttpClient::Impl {
    CURL* curl = nullptr;
    Impl()  { curl = curl_easy_init(); }
    ~Impl() { if (curl) curl_easy_cleanup(curl); }
};

HttpClient::HttpClient() : m_impl(std::make_unique<Impl>()) {}
HttpClient::~HttpClient() = default;

HttpClient::Response HttpClient::execute(const HttpRequest& req, int timeout_ms) {
    Response resp;
    if (!m_impl->curl) { resp.error = "curl init failed"; return resp; }
    CURL* curl = m_impl->curl;
    curl_easy_reset(curl);

    std::string body;
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, writeCallback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &body);
    curl_easy_setopt(curl, CURLOPT_URL, req.url.c_str());
    curl_easy_setopt(curl, CURLOPT_TIMEOUT_MS, (long)timeout_ms);
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(curl, CURLOPT_MAXREDIRS, 5L);
    // On Android, the bundled mbedTLS cannot complete TLS handshakes (missing
    // cipher suites / TLS 1.3 support). Disable peer verification so connections
    // succeed — the search queries are not sensitive.
    // TODO: rebuild curl with OpenSSL for proper SSL on Android.
#ifdef __ANDROID__
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0L);
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 0L);
    curl_easy_setopt(curl, CURLOPT_SSLVERSION, CURL_SSLVERSION_TLSv1_2);
#else
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 1L);
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 2L);
#endif
    curl_easy_setopt(curl, CURLOPT_ACCEPT_ENCODING, "gzip, deflate");

    // Build headers
    struct curl_slist* headers = nullptr;
    std::string uaHeader = std::string("User-Agent: ") + randomUserAgent();
    headers = curl_slist_append(headers, uaHeader.c_str());
    headers = curl_slist_append(headers, "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8");
    headers = curl_slist_append(headers, "Accept-Language: en-US,en;q=0.5");
    for (const auto& [k, v] : req.headers) {
        std::string h = k + ": " + v;
        headers = curl_slist_append(headers, h.c_str());
    }
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);

    // Cookies
    if (!req.cookies.empty()) {
        std::string cookieStr;
        for (const auto& [k, v] : req.cookies) {
            if (!cookieStr.empty()) cookieStr += "; ";
            cookieStr += k + "=" + v;
        }
        curl_easy_setopt(curl, CURLOPT_COOKIE, cookieStr.c_str());
    }

    // POST body
    if (req.method == "POST") {
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, req.body.c_str());
        curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, (long)req.body.size());
    }

    CURLcode res = curl_easy_perform(curl);
    curl_slist_free_all(headers);  // always freed, regardless of curl result

    if (res != CURLE_OK) {
        resp.error = curl_easy_strerror(res);
        LOGE("CURL error: %s (url: %.120s)\n", resp.error.c_str(), req.url.c_str());
        return resp;
    }
    long httpCode = 0;
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &httpCode);
    resp.status = static_cast<int>(httpCode);
    resp.body   = std::move(body);
    LOGI("CURL ok: HTTP %ld, %zu bytes (url: %.120s)\n",
         httpCode, resp.body.size(), req.url.c_str());
    return resp;
}

const char* randomUserAgent() {
    static const char* agents[] = {
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:123.0) Gecko/20100101 Firefox/123.0",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 14.3; rv:123.0) Gecko/20100101 Firefox/123.0",
    };
    static constexpr size_t count = sizeof(agents) / sizeof(agents[0]);
    thread_local std::mt19937 rng(std::random_device{}());
    std::uniform_int_distribution<size_t> dist(0, count - 1);
    return agents[dist(rng)];
}

} // namespace websearch
