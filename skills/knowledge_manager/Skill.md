# Knowledge Manager Skill

## Purpose
Read files from the user's personal knowledge base and extract answers to queries.

## When to use
- User asks about their saved notes, documents, papers, or bookmarks
- Query references content the user has previously saved
- Phrases like "my notes", "the paper I saved", "in my knowledge base"

## How to invoke
Emit this XML when you want to read knowledge files:

```xml
<skill name="knowledge_manager">
  files: filename1.md, filename2.md
  query: specific thing you want to find
</skill>
```

The `files` list comes from the Knowledge Base table of contents in your system prompt.
You may list 1 to 5 files per invocation.
The skill will extract relevant content and return it as context for your answer.

## Important
- Only list files that appear in the Knowledge Base index
- Be specific in the query — it guides section selection inside each file
- If the index shows no relevant files, tell the user directly
