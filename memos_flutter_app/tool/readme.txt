generate_memo_zip.py
====================

PowerShell example
------------------

$env:OPENAI_API_KEY="YOUR_API_KEY"
$env:OPENAI_BASE_URL="https://api.deepseek.com/v1"
$env:OPENAI_MODEL="deepseek-chat"

python .\tool\generate_memo_zip.py `
  --start-date 2025-01-01 `
  --end-date 2026-02-23 `
  --memo-count 300 `
  --tag-count 17 `
  --language zh `
  --tag-source ai `
  --content-source ai `
  --content-batch-size 10 `
  --recent-memo-count 3 `
  --author-profile "29-year-old product manager in Shanghai, also building a side project after work." `
  --memo-context "Recurring themes: side project progress, workouts, reading notes, family errands, sleep and schedule adjustments." `
  --output .\tool\my_memos_zh_ai.zip

Important options
-----------------

--start-date          Start date in YYYY-MM-DD
--end-date            End date in YYYY-MM-DD
--memo-count          Total memo count to generate
--tag-count           Tag pool size, capped at 50
--language            zh or en
--tag-source          auto | ai | builtin
--content-source      auto | ai | builtin
--content-batch-size  AI memo count per request, default 10
--recent-memo-count   Recent memo previews passed back to AI, default 3
--author-profile      Optional persona/profile text for more realistic memos
--memo-context        Optional long-running projects or life context
--output              Output zip path
--seed                Optional random seed
--ai-timeout          AI request timeout in seconds

Notes
-----

- If you want memo bodies to feel more real, set both --content-source ai and a useful --author-profile / --memo-context.
- If --content-source is auto, the script falls back to built-in memo templates when the AI request fails.
- Tags are still written to front matter. Memo body output keeps hashtags on the last line for compatibility with the current generated format.
