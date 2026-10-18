// src/core/JsonParser.cpp
#include "core/JsonParser.h"
#include <json.hpp>
#include <sstream>

namespace websearch {

using json = nlohmann::json;

struct JsonParser::Impl {
    json data;
    bool valid = false;
};

JsonParser::JsonParser(const std::string& jsonStr)
    : m_impl(std::make_shared<Impl>())
{
    try {
        m_impl->data = json::parse(jsonStr);
        m_impl->valid = true;
    } catch (...) {
        m_impl->valid = false;
    }
}

JsonParser::JsonParser(std::shared_ptr<Impl> impl) : m_impl(std::move(impl)) {}

std::string JsonParser::get(const std::string& path) const {
    if (!m_impl->valid) return "";
    const json* node = &m_impl->data;
    std::istringstream ss(path);
    std::string segment;
    while (std::getline(ss, segment, '.')) {
        if (!node->is_object() || !node->contains(segment)) return "";
        node = &(*node)[segment];
    }
    if (node->is_string()) return node->get<std::string>();
    if (node->is_number_integer()) return std::to_string(node->get<int64_t>());
    if (node->is_number_float()) return std::to_string(node->get<double>());
    if (node->is_boolean()) return node->get<bool>() ? "true" : "false";
    return "";
}

std::vector<JsonParser> JsonParser::getArray(const std::string& path) const {
    if (!m_impl->valid) return {};
    const json* node = &m_impl->data;
    if (!path.empty()) {
        std::istringstream ss(path);
        std::string segment;
        while (std::getline(ss, segment, '.')) {
            if (!node->is_object() || !node->contains(segment)) return {};
            node = &(*node)[segment];
        }
    }
    if (!node->is_array()) return {};
    std::vector<JsonParser> result;
    result.reserve(node->size());
    for (const auto& item : *node) {
        auto impl = std::make_shared<Impl>();
        impl->data = item;
        impl->valid = true;
        JsonParser child(std::move(impl));
        result.push_back(std::move(child));
    }
    return result;
}

} // namespace websearch
