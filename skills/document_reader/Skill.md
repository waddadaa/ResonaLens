---
name: document_reader
description: Read local documents (PDF, Markdown, plain text, HTML) with structure-aware chunking
triggers:
  - read document
  - read file
  - open file
  - extract text
  - pdf
  - document
---

# Document Reader

## When to Use
- User uploads or references a local file and asks about its content
- A downloaded PDF (from paper_finder or web_reader) needs text extraction
- Content needs to be chunked before adding to the knowledge base
- User asks to summarize, analyze, or answer questions about a document

## When NOT to Use
- The content is already in the knowledge base — use knowledge_manager to search
- The source is a live web page — use web_reader instead
- The file format is not supported (images, audio, video, spreadsheets)

## Instructions
1. **Detect format**: Identify file type by extension and MIME type. Supported: `.pdf`, `.md`, `.txt`, `.html`.
2. **Extract text**:
   - **PDF**: Use `pdftotext` with `-layout` flag to preserve spatial structure (columns, tables, indentation). Fall back to MuPDF if pdftotext is unavailable. Extract page-by-page.
   - **Markdown**: Parse raw text, preserving all heading levels, lists, code blocks, and frontmatter.
   - **Plain text**: Read as-is, split by double newlines into paragraphs.
   - **HTML**: Run through the same readability pipeline as web_reader (strip boilerplate, extract main content).
3. **Structure-aware chunking**:
   - **PDF**: Split by page boundaries. If a single page exceeds 512 tokens, split at paragraph breaks within the page.
   - **Markdown**: Split at `##` heading boundaries. Each chunk starts with its heading as context. If a section exceeds 512 tokens, split at paragraph breaks.
   - **Plain text / HTML**: Split at paragraph boundaries targeting 256-512 tokens per chunk.
   - **No overlap**: Chunks do not overlap (2026 research confirms overlap adds noise without improving retrieval quality for BM25).
   - **Minimum chunk size**: Discard chunks under 64 tokens (likely noise — headers, page numbers, etc.).
4. **Attach metadata**: Each chunk gets: `{source_file, chunk_index, heading_or_page, total_chunks}`.
5. **Return**: Output all chunks with metadata. For direct user queries (not knowledge base ingestion), also return the first 3 chunks inline for immediate context.

## Best Practices
- Target 256-512 tokens per chunk — small enough for on-device context windows, large enough for coherent content
- Preserve code blocks as single chunks even if they exceed 512 tokens
- For PDFs with headers/footers on every page, detect and strip repeating text
- Include the document title and relevant heading in each chunk for BM25 searchability
- When chunking for knowledge base ingestion, pass chunks to knowledge_manager with source attribution

## Example Invocations
<skill name="document_reader">/sdcard/Download/research_paper.pdf</skill>
<skill name="document_reader">/data/user/0/com.resonalens/files/notes/meeting_notes.md</skill>
<skill name="document_reader">/sdcard/Documents/report.txt</skill>
