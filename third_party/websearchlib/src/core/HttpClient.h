// src/core/HttpClient.h
#pragma once
#include "websearch/Engine.h"
#include <string>
#include <memory>

namespace websearch {

class HttpClient {
public:
    struct Response {
        int         status = 0;
        std::string body;
        std::string error;
        bool ok() const { return status >= 200 && status < 300; }
    };

    HttpClient();
    ~HttpClient();
    HttpClient(const HttpClient&) = delete;
    HttpClient& operator=(const HttpClient&) = delete;

    Response execute(const HttpRequest& req, int timeout_ms);

private:
    struct Impl;
    std::unique_ptr<Impl> m_impl;
};

// Pool of realistic browser User-Agent strings
const char* randomUserAgent();

} // namespace websearch
