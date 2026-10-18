// src/core/JsonParser.h
#pragma once
#include <string>
#include <vector>
#include <memory>

namespace websearch {

class JsonParser {
public:
    explicit JsonParser(const std::string& json);
    // Copyable: instances share the underlying JSON node (cheap copy).
    // Used by getArray() to return child parsers without deep-copying.
    JsonParser(const JsonParser&) = default;

    // Get string value at dotted path (e.g. "data.result.query").
    // Returns "" if path is missing, value is null, or JSON is invalid.
    // Note: key names containing '.' are not supported.
    std::string get(const std::string& path) const;

    // Get array at dotted path; each element is itself a JsonParser
    std::vector<JsonParser> getArray(const std::string& path) const;

private:
    struct Impl;
    std::shared_ptr<Impl> m_impl;
    explicit JsonParser(std::shared_ptr<Impl> impl);
};

} // namespace websearch
