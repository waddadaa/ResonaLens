---
name: paper_finder
description: Search for academic papers via Semantic Scholar and arXiv with structured metadata and open-access PDF extraction
triggers:
  - paper
  - research
  - academic
  - study
  - journal
  - arxiv
  - citation
  - find papers
---

# Paper Finder

## When to Use
- User asks about academic research, scientific studies, or the research literature
- User says "find papers about...", "what does the research say about...", or "cite sources for..."
- User wants to find the original paper behind a scientific claim
- User needs papers filtered by year, citation count, or open-access availability
- A web_search result references a paper and the user wants the full metadata

## When NOT to Use
- The question is about general knowledge, blog posts, or news — use web_search
- The user already has the PDF and wants to read it — use document_reader
- The user wants web articles or tutorials, not academic papers

## Instructions
1. **Query reformulation**: The LLM rewrites the user's question into specific academic search terms. Use technical vocabulary, not casual language:
   - "how does ChatGPT work" -> "reinforcement learning human feedback language model alignment"
   - "why do transformers forget things" -> "transformer catastrophic forgetting continual learning"
   - Include key author names if the user mentions them.
2. **Search Semantic Scholar** (primary): Query the Semantic Scholar Graph API with fields: `title, authors, year, abstract, citationCount, openAccessPdf, externalIds`. Free, no API key required. Rate limit: 100 requests per 5 minutes.
3. **Filter results**:
   - If user specifies a year range, filter by `year`.
   - Sort by citation count by default (most-cited first) unless user asks for "recent" or "latest" (then sort by year descending).
   - Flag open-access papers with a direct PDF link.
4. **Fallback to arXiv**: If Semantic Scholar returns fewer than 3 results, also query arXiv API. arXiv always has PDFs available but has weaker metadata (no citation counts).
5. **Auto-download open-access PDFs**: For the top 1-2 papers with open-access PDFs, download the PDF to the temp directory and run document_reader to extract text. This gives the LLM actual paper content to cite, not just the abstract.
6. **Return structured results**: Each paper returned as:
   ```
   **Title:** ...
   **Authors:** First Author et al. (Year)
   **Citations:** N | **Open Access:** Yes/No
   **Abstract:** [first 200 words]
   **DOI:** ... | **URL:** ...
   ```

## Best Practices
- Use precise academic terms: "retrieval augmented generation" not "making AI search stuff"
- For well-known papers, search by title keywords + first author: "attention vaswani 2017"
- Prefer highly-cited papers (>50 citations) for established topics, recent papers (<2 years) for cutting-edge topics
- Always include the DOI or URL so the user can access the paper
- When presenting results, summarize the abstract in 1-2 sentences rather than dumping raw text
- If the user asks a research question, search for 2-3 complementary queries to cover different angles

## Example Invocations
<skill name="paper_finder">retrieval augmented generation for knowledge-intensive tasks</skill>
<skill name="paper_finder">on-device large language model inference optimization 2025 2026</skill>
<skill name="paper_finder">BM25 vs dense retrieval comparison benchmark</skill>
