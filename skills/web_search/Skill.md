---
name: web_search
description: Search the internet for current information with query reformulation and auto-read of top results
triggers:
  - search online
  - find online
  - look up online
  - latest news
  - current news
  - what happened today
  - recent news
---

# Web Search

## When to Use
- User asks about current events, news, or developments after training cutoff
- User asks "what is the latest..." or "what happened with..."
- Factual claims need verification against current sources
- User explicitly asks to search the web
- Knowledge base has no relevant results and the question is factual

## When NOT to Use
- The question is about well-established facts unlikely to have changed
- The user is asking for opinions, creative writing, or conversation
- The answer is already in the knowledge base or uploaded documents

## Instructions
1. **Query reformulation**: The LLM rewrites the user's question into 1-2 specific search queries optimized for keyword matching. For current events, append the month and year (e.g., "April 2026"). Avoid vague queries like "tell me about AI" — prefer "large language model breakthroughs Q1 2026".
2. **Execute search**: The harness sends the reformulated query to DuckDuckGo Lite (default) or the user's SearXNG instance. Returns up to 5 result snippets with titles and URLs.
3. **Auto-read top results**: The harness automatically fetches the full page content of the top 3 results using the web_reader pipeline (boilerplate stripped, truncated to ~2000 tokens each). This gives the LLM actual page content, not just snippets.
4. **Retry on poor results**: If the top results are irrelevant (off-topic titles, error pages, or empty content), the harness retries once with a refined query. The LLM generates the refined query by narrowing terms or adding qualifiers.
5. **Return to LLM**: The combined content (up to ~6000 tokens from 3 pages) is injected into the prompt as context. The LLM synthesizes an answer and cites sources with URLs.

## Best Practices
- Always reformulate: never pass the user's raw question as the search query
- Add date qualifiers for time-sensitive queries ("latest", "recent", "this week")
- Prefer specific terms over generic ones: "Gemma 3n benchmark MMLU" not "Google AI model"
- Cite every factual claim with the source URL in the response
- If results conflict, present both sides and note the disagreement
- For multi-faceted questions, issue 2 separate targeted queries rather than one broad query

## Example Invocations
<skill name="web_search">latest breakthroughs in on-device LLM inference April 2026</skill>
<skill name="web_search">EU AI Act enforcement timeline 2026</skill>
<skill name="web_search">Qwen3 model release date and benchmark results</skill>
