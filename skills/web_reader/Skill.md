---
name: web_reader
description: Fetch a web page URL, strip boilerplate, and extract structured readable content with metadata
triggers:
  - read page
  - fetch url
  - open link
  - read article
  - summarize page
  - website
---

# Web Reader

## When to Use
- User shares a URL and asks to read, summarize, or analyze it
- A web_search result needs full page content beyond the snippet
- User wants to save a web page's content to the knowledge base
- Following a link from a paper or document that points to a web resource

## When NOT to Use
- The URL points to a PDF file — use document_reader instead
- The URL requires authentication, login, or is behind a paywall
- The page is a single-page app with no server-rendered content (JS-only)

## Instructions
1. **Fetch**: HTTP GET with a 15-second timeout, following up to 5 redirects. Send a browser-like User-Agent to avoid bot blocks.
2. **Detect failures**: Check for common failure patterns before parsing:
   - Cookie consent walls (look for "cookie", "consent" in blocking overlays)
   - Paywall indicators ("subscribe to read", "premium content")
   - JS-only pages (empty `<body>` or only `<noscript>` content)
   - If detected, return a clear error message instead of garbage text.
3. **Extract metadata**: Pull title, author, and publication date from `<meta>` tags and semantic HTML (see `readability_rules.json` for selectors).
4. **Strip boilerplate**: Remove all `<script>`, `<style>`, `<nav>`, `<footer>`, `<header>`, `<aside>`, `<iframe>`, `<noscript>`, `<form>` tags. Then select the main content area using priority selectors: `article` > `[role='main']` > `main` > `.content`.
5. **Preserve structure**: Keep heading hierarchy (h1-h4), bullet/numbered lists, code blocks, and blockquotes. Convert to clean Markdown.
6. **Truncate**: If the extracted content exceeds ~2000 tokens, truncate at the nearest paragraph boundary and append "[Content truncated — X tokens shown of ~Y total]".
7. **Return**: Output as structured Markdown with metadata header:
   ```
   **Title:** ...
   **Author:** ... | **Date:** ...
   **URL:** ...
   ---
   [extracted content]
   ```

## Best Practices
- Always include the source URL in the output for attribution
- Preserve code blocks verbatim — do not summarize or reformat code
- For long articles, prefer truncating from the end rather than the middle
- If the page has multiple articles (e.g., a blog index), extract only the first/main one
- Strip tracking parameters from URLs before storing (?utm_source, etc.)

## Example Invocations
<skill name="web_reader">https://arxiv.org/abs/2501.12345</skill>
<skill name="web_reader">https://huggingface.co/blog/gemma-3n</skill>
<skill name="web_reader">https://developer.android.com/ml/on-device</skill>
