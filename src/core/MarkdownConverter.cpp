#include "MarkdownConverter.h"
#include "WebReaderBackend.h"

#include <QFile>
#include <QFileInfo>
#include <QTextStream>
#include <QTextDocument>
#include <QDateTime>
#include <QUuid>
#include <QDir>
#include <QProcess>
#include <QRegularExpression>
#include <QDebug>
#include <QThread>
#include <QCoreApplication>
#include <climits>
#include <memory>

#ifdef RESONALENS_HAS_POPPLER
#include <poppler-document.h>
#include <poppler-page.h>
#include <poppler-global.h>
#endif

#include "miniz.h"
#include <QXmlStreamReader>

MarkdownConverter::MarkdownConverter(WebReaderBackend *webReader, QObject *parent)
    : QObject(parent), m_webReader(webReader)
{}

QStringList MarkdownConverter::supportedExtensions() const
{
    return { "txt", "md", "markdown", "csv", "html", "htm",
             "pdf", "docx", "doc", "xlsx", "xls" };
}

QString MarkdownConverter::slugify(const QString &title)
{
    QString s = title.toLower();
    s.replace(QRegularExpression("[^a-z0-9]+"), "-");
    s.remove(QRegularExpression("^-|-$"));
    if (s.isEmpty()) s = "document";
    s = s.left(60);
    QString suffix = QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
    return s + "-" + suffix;
}

QString MarkdownConverter::writeMd(const QString &outDir, const QString &slug,
                                    const QString &title, const QString &source,
                                    const QString &body)
{
    QDir().mkpath(outDir);
    QString path = outDir + "/" + slug + ".md";
    if (QFile::exists(path)) {
        // Rare collision — use a fresh unique path
        path = outDir + "/" + slug + "-" +
               QUuid::createUuid().toString(QUuid::WithoutBraces).left(4) + ".md";
    }
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text)) {
        emit conversionFailed("Cannot write: " + path);
        return {};
    }
    QTextStream s(&f);
    s << "---\n"
      << "title: " << title << "\n"
      << "source: " << source << "\n"
      << "added: " << QDateTime::currentDateTime().toString("yyyy-MM-dd") << "\n"
      << "---\n\n"
      << body;
    return path;
}

QString MarkdownConverter::convert(const QString &inputPath, const QString &outputDir)
{
    QFileInfo fi(inputPath);
    QString ext = fi.suffix().toLower();

    if (ext == "txt")                       return convertTxt(inputPath, outputDir);
    if (ext == "md" || ext == "markdown")   return convertMd(inputPath, outputDir);
    if (ext == "csv")                       return convertCsv(inputPath, outputDir);
    if (ext == "html" || ext == "htm")      return convertHtml(inputPath, outputDir);
    if (ext == "pdf")                       return convertPdf(inputPath, outputDir);
    if (ext == "docx" || ext == "doc")      return convertDocx(inputPath, outputDir);
    if (ext == "xlsx" || ext == "xls")      return convertXlsx(inputPath, outputDir);

    emit conversionFailed("Unsupported format: " + ext);
    return {};
}

QString MarkdownConverter::convertTxt(const QString &path, const QString &outDir)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return {};
    QString content = QTextStream(&f).readAll();

    QString title;
    for (const QString &line : content.split('\n')) {
        if (!line.trimmed().isEmpty()) { title = line.trimmed(); break; }
    }
    if (title.isEmpty()) title = QFileInfo(path).baseName();

    return writeMd(outDir, slugify(title), title, QFileInfo(path).fileName(), content);
}

QString MarkdownConverter::convertMd(const QString &path, const QString &outDir)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return {};
    QString content = QTextStream(&f).readAll();

    if (content.startsWith("---")) {
        QString slug = slugify(QFileInfo(path).baseName());
        QDir().mkpath(outDir);
        QString outPath = outDir + "/" + slug + ".md";
        if (QFile::exists(outPath))
            QFile::remove(outPath);
        if (!QFile::copy(path, outPath)) {
            emit conversionFailed("Cannot copy to: " + outPath);
            return {};
        }
        return outPath;
    }

    QString title = QFileInfo(path).baseName();
    for (const QString &line : content.split('\n')) {
        if (line.startsWith("# ")) { title = line.mid(2).trimmed(); break; }
    }
    return writeMd(outDir, slugify(title), title, QFileInfo(path).fileName(), content);
}

QString MarkdownConverter::convertCsv(const QString &path, const QString &outDir)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return {};
    QTextStream s(&f);

    QStringList rows;
    bool headerDone = false;
    while (!s.atEnd()) {
        QString line = s.readLine();
        if (line.trimmed().isEmpty()) continue;
        QStringList cells = line.split(',');
        for (QString &c : cells)
            c = c.trimmed().replace('|', "\\|");

        rows.append("| " + cells.join(" | ") + " |");
        if (!headerDone) {
            QStringList sep(cells.size(), "---");
            rows.append("|" + sep.join("|") + "|");
            headerDone = true;
        }
    }

    QString title = QFileInfo(path).baseName();
    QString body  = "# " + title + "\n\n" + rows.join('\n') + "\n";
    return writeMd(outDir, slugify(title), title, QFileInfo(path).fileName(), body);
}

QString MarkdownConverter::convertHtml(const QString &path, const QString &outDir)
{
    Q_ASSERT_X(qApp && QThread::currentThread() == qApp->thread(),
               "MarkdownConverter::convertHtml",
               "convertHtml must be called from the GUI thread (QTextDocument requirement)");
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return {};
    QString html = QTextStream(&f).readAll();

    QTextDocument doc;
    doc.setHtml(html);
    QString plainText = doc.toPlainText().trimmed();

    QString title = QFileInfo(path).baseName();
    QRegularExpression titleRe("<title>([^<]+)</title>",
                               QRegularExpression::CaseInsensitiveOption);
    auto m = titleRe.match(html);
    if (m.hasMatch()) title = m.captured(1).trimmed();

    return writeMd(outDir, slugify(title), title, QFileInfo(path).fileName(), plainText);
}

QString MarkdownConverter::convertPdf(const QString &path, const QString &outDir)
{
    QString body;
    QString title = QFileInfo(path).baseName();

#ifdef RESONALENS_HAS_POPPLER
    auto doc = std::unique_ptr<poppler::document>(
        poppler::document::load_from_file(path.toLocal8Bit().toStdString()));
    if (doc) {
        int pageCount = doc->pages();
        for (int i = 0; i < pageCount; ++i) {
            emit conversionProgress(pageCount > 0 ? (i * 100) / pageCount : 0);
            auto page = std::unique_ptr<poppler::page>(doc->create_page(i));
            if (!page) continue;
            poppler::byte_array arr = page->text(poppler::rectf()).to_utf8();
            QString text = QString::fromUtf8(arr.data(), static_cast<int>(qMin(arr.size(), static_cast<size_t>(INT_MAX))));
            if (!text.trimmed().isEmpty())
                body += text.trimmed() + "\n\n";
        }
        poppler::ustring metaTitle = doc->get_title();
        poppler::byte_array titleArr = metaTitle.to_utf8();
        if (!titleArr.empty()) {
            QString t = QString::fromUtf8(titleArr.data(), static_cast<int>(qMin(titleArr.size(), static_cast<size_t>(INT_MAX)))).trimmed();
            if (!t.isEmpty()) title = t;
        }
    }
#endif

    // Fallback: use pdftotext CLI (poppler-utils) when C++ lib unavailable or failed
    if (body.trimmed().isEmpty()) {
        QProcess process;
        process.start("pdftotext", {"-layout", "-enc", "UTF-8", path, "-"});
        if (process.waitForStarted(5000) && process.waitForFinished(30000)
                && process.exitCode() == 0) {
            body = QString::fromUtf8(process.readAllStandardOutput()).trimmed();
        }
    }

    if (body.trimmed().isEmpty()) {
        emit conversionFailed("PDF has no extractable text: " + path);
        return {};
    }

    emit conversionProgress(100);
    return writeMd(outDir, slugify(title), title, QFileInfo(path).fileName(), body);
}

QString MarkdownConverter::convertDocx(const QString &path, const QString &outDir)
{
    mz_zip_archive zip{};
    if (!mz_zip_reader_init_file(&zip, path.toLocal8Bit().constData(), 0)) {
        emit conversionFailed("Cannot open DOCX: " + path);
        return {};
    }

    int idx = mz_zip_reader_locate_file(&zip, "word/document.xml", nullptr, 0);
    if (idx < 0) {
        mz_zip_reader_end(&zip);
        emit conversionFailed("Not a valid DOCX (missing word/document.xml): " + path);
        return {};
    }

    size_t size = 0;
    void *data = mz_zip_reader_extract_to_heap(&zip, idx, &size, 0);
    mz_zip_reader_end(&zip);
    if (!data) return {};

    QByteArray xmlBytes(static_cast<const char*>(data), static_cast<int>(size));
    mz_free(data);

    // Parse OpenXML paragraphs
    QString body;
    QXmlStreamReader xml(xmlBytes);
    while (!xml.atEnd()) {
        xml.readNext();
        if (xml.isStartElement() && xml.name() == QLatin1String("p")) {
            QString paraText;
            int headingLevel = 0;
            while (!xml.atEnd() && !(xml.isEndElement() && xml.name() == QLatin1String("p"))) {
                xml.readNext();
                if (xml.isStartElement()) {
                    if (xml.name() == QLatin1String("pStyle")) {
                        QString val = xml.attributes().value("w:val").toString();
                        if (val.startsWith("Heading")) {
                            headingLevel = val.mid(7).toInt();
                            if (headingLevel < 1 || headingLevel > 6) headingLevel = 0;
                        }
                    } else if (xml.name() == QLatin1String("t")) {
                        paraText += xml.readElementText();
                    }
                }
            }
            if (!paraText.trimmed().isEmpty()) {
                if (headingLevel > 0)
                    body += QString(headingLevel, '#') + " " + paraText + "\n\n";
                else
                    body += paraText + "\n\n";
            }
        }
    }

    QString title = QFileInfo(path).baseName();
    return writeMd(outDir, slugify(title), title, QFileInfo(path).fileName(), body);
}

QString MarkdownConverter::convertXlsx(const QString &path, const QString &outDir)
{
    mz_zip_archive zip{};
    if (!mz_zip_reader_init_file(&zip, path.toLocal8Bit().constData(), 0)) {
        emit conversionFailed("Cannot open XLSX: " + path);
        return {};
    }

    QStringList sharedStrings;
    int ssIdx = mz_zip_reader_locate_file(&zip, "xl/sharedStrings.xml", nullptr, 0);
    if (ssIdx >= 0) {
        size_t sz = 0;
        void *d = mz_zip_reader_extract_to_heap(&zip, ssIdx, &sz, 0);
        if (d) {
            QXmlStreamReader xml(QByteArray(static_cast<const char*>(d), static_cast<int>(sz)));
            mz_free(d);
            while (!xml.atEnd()) {
                xml.readNext();
                if (xml.isStartElement() && xml.name() == QLatin1String("t"))
                    sharedStrings.append(xml.readElementText());
            }
        }
    }

    int shIdx = mz_zip_reader_locate_file(&zip, "xl/worksheets/sheet1.xml", nullptr, 0);
    if (shIdx < 0) { mz_zip_reader_end(&zip); return {}; }
    size_t sz = 0;
    void *d = mz_zip_reader_extract_to_heap(&zip, shIdx, &sz, 0);
    mz_zip_reader_end(&zip);
    if (!d) return {};

    QXmlStreamReader xml(QByteArray(static_cast<const char*>(d), static_cast<int>(sz)));
    mz_free(d);

    QList<QStringList> rows;
    QStringList currentRow;
    QString currentType;
    while (!xml.atEnd()) {
        xml.readNext();
        if (xml.isStartElement()) {
            if (xml.name() == QLatin1String("row") && !currentRow.isEmpty()) {
                rows.append(currentRow);
                currentRow.clear();
            } else if (xml.name() == QLatin1String("c")) {
                currentType = xml.attributes().value("t").toString();
            } else if (xml.name() == QLatin1String("v")) {
                QString val = xml.readElementText();
                if (currentType == "s") {
                    int i = val.toInt();
                    val = (i < sharedStrings.size()) ? sharedStrings[i] : val;
                }
                currentRow.append(val);
            }
        }
    }
    if (!xml.hasError() && !currentRow.isEmpty()) rows.append(currentRow);
    if (xml.hasError())
        qWarning() << "XLSX XML parse error:" << xml.errorString();

    QString body;
    for (int r = 0; r < rows.size(); ++r) {
        const QStringList &row = rows[r];
        body += "| " + row.join(" | ") + " |\n";
        if (r == 0) {
            QStringList sep(row.size(), "---");
            body += "| " + sep.join(" | ") + " |\n";
        }
    }

    QString title = QFileInfo(path).baseName();
    return writeMd(outDir, slugify(title), title, QFileInfo(path).fileName(), body);
}

QString MarkdownConverter::convertUrl(const QString &url, const QString &outputDir)
{
    if (!m_webReader) {
        emit conversionFailed("No WebReaderBackend provided");
        return {};
    }
    QVariantMap result = m_webReader->fetch(url);
    QString text  = result.value("text").toString();
    QString title = result.value("title").toString();
    if (title.isEmpty()) title = url;
    if (text.isEmpty()) {
        emit conversionFailed("Failed to fetch: " + url);
        return {};
    }
    return writeMd(outputDir, slugify(title), title, url, text);
}
