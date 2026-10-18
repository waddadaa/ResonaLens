#include <QtTest>
#include <QTemporaryDir>
#include <QFile>
#include <QTextStream>
#include "MarkdownConverter.h"

class TstMarkdownConverter : public QObject {
    Q_OBJECT

    QTemporaryDir m_src;
    QTemporaryDir m_out;

    QString writeSource(const QString &name, const QString &content) {
        QString path = m_src.filePath(name);
        QFile f(path);
        if (!f.open(QIODevice::WriteOnly | QIODevice::Text)) return {};
        QTextStream(&f) << content;
        return path;
    }

    QString readOutput(const QString &mdPath) {
        QFile f(mdPath);
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return {};
        return QTextStream(&f).readAll();
    }

    void createMinimalDocx(const QString &outPath, const QString &wordXml);
    void createMinimalXlsx(const QString &outPath, const QString &sharedStrings, const QString &sheet1);

private slots:
    void convert_txtFile_producesMdWithFrontMatter() {
        QString src = writeSource("notes.txt", "My Notes\n\nSome content here.");
        MarkdownConverter conv;
        QString out = conv.convert(src, m_out.path());
        QVERIFY(!out.isEmpty());
        QString content = readOutput(out);
        QVERIFY(content.contains("---"));
        QVERIFY(content.contains("Some content here."));
    }

    void convert_mdFile_copiesWithFrontMatter() {
        QString src = writeSource("doc.md", "# Title\n\nAlready markdown.");
        MarkdownConverter conv;
        QString out = conv.convert(src, m_out.path());
        QString content = readOutput(out);
        QVERIFY(content.contains("Already markdown."));
        QVERIFY(content.contains("---"));
    }

    void convert_csvFile_producesMarkdownTable() {
        QString csv = "Name,Age,City\nAlice,30,London\nBob,25,Paris\n";
        QString src = writeSource("data.csv", csv);
        MarkdownConverter conv;
        QString out = conv.convert(src, m_out.path());
        QString content = readOutput(out);
        QVERIFY(content.contains("| Name |"));
        QVERIFY(content.contains("| Alice |"));
        QVERIFY(content.contains("|---|"));
    }

    void convert_htmlFile_extractsText() {
        QString html = "<html><body><h1>Title</h1><p>Body text here.</p></body></html>";
        QString src = writeSource("page.html", html);
        MarkdownConverter conv;
        QString out = conv.convert(src, m_out.path());
        QString content = readOutput(out);
        QVERIFY(content.contains("Body text here."));
    }

    void convert_unsupportedFormat_returnsEmpty() {
        QString src = writeSource("video.mp4", "binary data");
        MarkdownConverter conv;
        QString out = conv.convert(src, m_out.path());
        QVERIFY(out.isEmpty());
    }

    void supportedExtensions_containsExpectedFormats() {
        MarkdownConverter conv;
        QStringList exts = conv.supportedExtensions();
        QVERIFY(exts.contains("txt"));
        QVERIFY(exts.contains("md"));
        QVERIFY(exts.contains("csv"));
        QVERIFY(exts.contains("html"));
        QVERIFY(exts.contains("pdf"));
        QVERIFY(exts.contains("docx"));
        QVERIFY(exts.contains("xlsx"));
    }

    void convert_docxFile_extractsParagraphs();
    void convert_xlsxFile_producesTable();
    void convertUrl_nullBackend_returnsEmpty();

    void convert_pdfFile_extractsText() {
        // Minimal valid PDF with embedded text "Hello World"
        // This is a real minimal PDF (not image-based), poppler can extract its text
        QByteArray pdfData = QByteArray::fromBase64(
            "JVBERi0xLjQKMSAwIG9iajw8L1R5cGUvQ2F0YWxvZy9QYWdlcyAyIDAgUj4+ZW5kb2JqCjIg"
            "MCBvYmo8PC9UeXBlL1BhZ2VzL0tpZHNbMyAwIFJdL0NvdW50IDE+PmVuZG9iagozIDAgb2Jq"
            "PDwvVHlwZS9QYWdlL01lZGlhQm94WzAgMCA2MTIgNzkyXS9QYXJlbnQgMiAwIFIvQ29udGVu"
            "dHMgNCAwIFIvUmVzb3VyY2VzPDwvRm9udDw8L0YxIDUgMCBSPj4+Pj4+ZW5kb2JqCjQgMCBv"
            "Ymo8PC9MZW5ndGggNDQ+PgpzdHJlYW0KQlQgL0YxIDEyIFRmIDEwMCA3MDAgVGQgKEhlbGxv"
            "IFdvcmxkKSBUaiBFVAplbmRzdHJlYW0KZW5kb2JqCjUgMCBvYmo8PC9UeXBlL0ZvbnQvU3Vi"
            "dHlwZS9UeXBlMS9CYXNlRm9udC9IZWx2ZXRpY2E+PmVuZG9iagp4cmVmCjAgNgowMDAwMDAw"
            "MDAwIDY1NTM1IGYgCjAwMDAwMDAwMDkgMDAwMDAgbiAKMDAwMDAwMDA1OCAwMDAwMCBuIAow"
            "MDAwMDAwMTE1IDAwMDAwIG4gCjAwMDAwMDAyNzQgMDAwMDAgbiAKMDAwMDAwMDM3MCAwMDAwMCBu"
            "IAp0cmFpbGVyPDwvU2l6ZSA2L1Jvb3QgMSAwIFI+PgpzdGFydHhyZWYKNDQxCiUlRU9G"
        );

        QString pdfPath = m_src.filePath("test.pdf");
        QFile pf(pdfPath);
        if (!pf.open(QIODevice::WriteOnly)) QFAIL("Cannot create test PDF");
        pf.write(pdfData);
        pf.close();

#ifdef RESONALENS_HAS_POPPLER
        MarkdownConverter conv;
        QString out = conv.convert(pdfPath, m_out.path());
        QVERIFY(!out.isEmpty());
        QString content = readOutput(out);
        QVERIFY(content.contains("---"));
        QVERIFY(content.size() > 20);
        QVERIFY(content.contains("Hello World"));
#else
        // When poppler is not available, conversion returns empty
        MarkdownConverter conv;
        QString out = conv.convert(pdfPath, m_out.path());
        QVERIFY(out.isEmpty());
#endif
    }
};

QTEST_MAIN(TstMarkdownConverter)

#include "miniz.h"

void TstMarkdownConverter::createMinimalDocx(const QString &outPath, const QString &wordXml)
{
    mz_zip_archive zip{};
    QVERIFY(mz_zip_writer_init_file(&zip, outPath.toLocal8Bit().constData(), 0));

    QByteArray xmlBytes = wordXml.toUtf8();
    QByteArray rels = R"(<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>)";
    QByteArray ctypes = R"(<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>)";

    mz_zip_writer_add_mem(&zip, "_rels/.rels", rels.constData(), rels.size(), MZ_DEFAULT_COMPRESSION);
    mz_zip_writer_add_mem(&zip, "[Content_Types].xml", ctypes.constData(), ctypes.size(), MZ_DEFAULT_COMPRESSION);
    mz_zip_writer_add_mem(&zip, "word/document.xml", xmlBytes.constData(), xmlBytes.size(), MZ_DEFAULT_COMPRESSION);
    QVERIFY(mz_zip_writer_finalize_archive(&zip));
    mz_zip_writer_end(&zip);
}

void TstMarkdownConverter::createMinimalXlsx(const QString &outPath,
                                               const QString &sharedStrings,
                                               const QString &sheet1)
{
    mz_zip_archive zip{};
    QVERIFY(mz_zip_writer_init_file(&zip, outPath.toLocal8Bit().constData(), 0));

    QByteArray ss  = sharedStrings.toUtf8();
    QByteArray s1  = sheet1.toUtf8();
    QByteArray rels = R"(<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>)";
    QByteArray ctypes = R"(<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/></Types>)";
    QByteArray workbook = R"(<?xml version="1.0"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheets><sheet name="Sheet1" sheetId="1" r:id="rId1" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/></sheets></workbook>)";

    mz_zip_writer_add_mem(&zip, "_rels/.rels", rels.constData(), rels.size(), MZ_DEFAULT_COMPRESSION);
    mz_zip_writer_add_mem(&zip, "[Content_Types].xml", ctypes.constData(), ctypes.size(), MZ_DEFAULT_COMPRESSION);
    mz_zip_writer_add_mem(&zip, "xl/workbook.xml", workbook.constData(), workbook.size(), MZ_DEFAULT_COMPRESSION);
    mz_zip_writer_add_mem(&zip, "xl/sharedStrings.xml", ss.constData(), ss.size(), MZ_DEFAULT_COMPRESSION);
    mz_zip_writer_add_mem(&zip, "xl/worksheets/sheet1.xml", s1.constData(), s1.size(), MZ_DEFAULT_COMPRESSION);
    QVERIFY(mz_zip_writer_finalize_archive(&zip));
    mz_zip_writer_end(&zip);
}

void TstMarkdownConverter::convert_docxFile_extractsParagraphs()
{
    QString docxPath = m_src.filePath("test.docx");
    QString wordXml = R"(<?xml version="1.0" encoding="UTF-8"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:body>
<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>Hello DOCX</w:t></w:r></w:p>
<w:p><w:r><w:t>This is body text from a Word document.</w:t></w:r></w:p>
</w:body>
</w:document>)";
    createMinimalDocx(docxPath, wordXml);

    MarkdownConverter conv;
    QString out = conv.convert(docxPath, m_out.path());
    QVERIFY(!out.isEmpty());
    QString content = readOutput(out);
    QVERIFY(content.contains("Hello DOCX"));
    QVERIFY(content.contains("# Hello DOCX"));
    QVERIFY(content.contains("body text from a Word document"));
}

void TstMarkdownConverter::convert_xlsxFile_producesTable()
{
    QString xlsxPath = m_src.filePath("test.xlsx");
    QString sharedStrings = R"(<?xml version="1.0"?>
<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="4" uniqueCount="4">
<si><t>Name</t></si><si><t>Value</t></si><si><t>Alice</t></si><si><t>42</t></si>
</sst>)";
    QString sheet1 = R"(<?xml version="1.0"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<sheetData>
<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c></row>
<row r="2"><c r="A2" t="s"><v>2</v></c><c r="B2" t="s"><v>3</v></c></row>
</sheetData>
</worksheet>)";
    createMinimalXlsx(xlsxPath, sharedStrings, sheet1);

    MarkdownConverter conv;
    QString out = conv.convert(xlsxPath, m_out.path());
    QVERIFY(!out.isEmpty());
    QString content = readOutput(out);
    QVERIFY(content.contains("Name"));
    QVERIFY(content.contains("Alice"));
    QVERIFY(content.contains("|"));
    QVERIFY(content.contains("---"));
}

void TstMarkdownConverter::convertUrl_nullBackend_returnsEmpty()
{
    MarkdownConverter convNoBackend(nullptr);
    QString out = convNoBackend.convertUrl("https://example.com", m_out.path());
    QVERIFY(out.isEmpty()); // fails gracefully with no backend
}

#include "tst_markdown_converter.moc"
