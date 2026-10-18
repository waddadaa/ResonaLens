#pragma once
#include <map>
#include <memory>
#include <string>
#include <vector>

namespace websearch {

class HtmlParser {
public:
    explicit HtmlParser(const std::string& html);
    ~HtmlParser();

    std::vector<std::string> xpath(const std::string& expr) const;
    std::string xpathAttr(const std::string& expr, const std::string& attr) const;
    std::vector<std::map<std::string, std::string>>
        xpathNodes(const std::string& expr,
                   const std::vector<std::string>& attrs = {}) const;

private:
    struct Impl;
    std::unique_ptr<Impl> m_impl;
};

} // namespace websearch
