#include "core/HtmlParser.h"
#include <libxml/HTMLparser.h>
#include <libxml/xpath.h>
#include <libxml/xpathInternals.h>

static void silenceXmlErrors(void*, const char*, ...) {}

namespace websearch {

struct HtmlParser::Impl {
    xmlDocPtr doc = nullptr;

    ~Impl() {
        if (doc) xmlFreeDoc(doc);
    }

    std::string nodeText(xmlNodePtr node) const {
        xmlChar* raw = xmlNodeGetContent(node);
        if (!raw) return "";
        std::string s = reinterpret_cast<const char*>(raw);
        xmlFree(raw);
        size_t start = s.find_first_not_of(" \t\n\r");
        size_t end   = s.find_last_not_of(" \t\n\r");
        if (start == std::string::npos) return "";
        return s.substr(start, end - start + 1);
    }
};

HtmlParser::HtmlParser(const std::string& html) : m_impl(std::make_unique<Impl>()) {
    xmlSetGenericErrorFunc(nullptr, silenceXmlErrors);
    m_impl->doc = htmlReadMemory(
        html.c_str(), static_cast<int>(html.size()),
        nullptr, "UTF-8",
        HTML_PARSE_NOERROR | HTML_PARSE_NOWARNING | HTML_PARSE_RECOVER);
}

HtmlParser::~HtmlParser() = default;

std::vector<std::string> HtmlParser::xpath(const std::string& expr) const {
    std::vector<std::string> results;
    if (!m_impl->doc) return results;

    xmlXPathContextPtr ctx = xmlXPathNewContext(m_impl->doc);
    if (!ctx) return results;

    xmlXPathObjectPtr obj = xmlXPathEvalExpression(
        reinterpret_cast<const xmlChar*>(expr.c_str()), ctx);
    xmlXPathFreeContext(ctx);
    if (!obj) return results;

    if (obj->nodesetval) {
        for (int i = 0; i < obj->nodesetval->nodeNr; ++i) {
            results.push_back(m_impl->nodeText(obj->nodesetval->nodeTab[i]));
        }
    }
    xmlXPathFreeObject(obj);
    return results;
}

std::string HtmlParser::xpathAttr(const std::string& expr, const std::string& attr) const {
    if (!m_impl->doc) return "";
    xmlXPathContextPtr ctx = xmlXPathNewContext(m_impl->doc);
    if (!ctx) return "";

    xmlXPathObjectPtr obj = xmlXPathEvalExpression(
        reinterpret_cast<const xmlChar*>(expr.c_str()), ctx);
    xmlXPathFreeContext(ctx);
    if (!obj) return "";

    std::string result;
    if (obj->nodesetval && obj->nodesetval->nodeNr > 0) {
        xmlNodePtr node = obj->nodesetval->nodeTab[0];
        xmlChar* val = xmlGetProp(node, reinterpret_cast<const xmlChar*>(attr.c_str()));
        if (val) {
            result = reinterpret_cast<const char*>(val);
            xmlFree(val);
        }
    }
    xmlXPathFreeObject(obj);
    return result;
}

std::vector<std::map<std::string, std::string>>
HtmlParser::xpathNodes(const std::string& expr,
                        const std::vector<std::string>& attrs) const {
    std::vector<std::map<std::string, std::string>> results;
    if (!m_impl->doc) return results;

    xmlXPathContextPtr ctx = xmlXPathNewContext(m_impl->doc);
    if (!ctx) return results;

    xmlXPathObjectPtr obj = xmlXPathEvalExpression(
        reinterpret_cast<const xmlChar*>(expr.c_str()), ctx);
    xmlXPathFreeContext(ctx);
    if (!obj) return results;

    if (obj->nodesetval) {
        for (int i = 0; i < obj->nodesetval->nodeNr; ++i) {
            xmlNodePtr node = obj->nodesetval->nodeTab[i];
            std::map<std::string, std::string> row;
            row["text"] = m_impl->nodeText(node);
            for (const auto& a : attrs) {
                xmlChar* val = xmlGetProp(node,
                    reinterpret_cast<const xmlChar*>(a.c_str()));
                if (val) {
                    row[a] = reinterpret_cast<const char*>(val);
                    xmlFree(val);
                } else {
                    row[a] = "";
                }
            }
            results.push_back(std::move(row));
        }
    }
    xmlXPathFreeObject(obj);
    return results;
}

} // namespace websearch
