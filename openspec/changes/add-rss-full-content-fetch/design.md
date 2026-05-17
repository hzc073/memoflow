## Context

The RSS MVP stores feed-provided article content:

```text
feed XML -> summary/content fields -> RSS article reader
```

This change adds an optional second content source:

```text
RSS article link
        |
        v
web page fetch -> readable extraction -> sanitizer -> RSS-owned full content
        |
        v
RSS article reader
```

The boundary remains the same: an RSS article is not a memo until the user explicitly saves it as a memo.

## Goals / Non-Goals

**Goals:**

- Fetch readable full content for selected feeds or individual articles.
- Preserve feed-provided content as fallback.
- Sanitize extracted HTML before storage or display.
- Keep extraction services outside UI widgets.
- Record recoverable fetch status and errors per article.
- Keep "save as memo" explicit and user initiated.

**Non-Goals:**

- No automatic RSS-to-memo conversion.
- No attempt to defeat paywalls, login requirements, bot protection, or DRM.
- No JavaScript-heavy browser automation in the first implementation.
- No OPML, notification, or scheduler behavior.

## Proposed Shape

### 1. Content source model

RSS articles should distinguish feed content from fetched content:

```text
rss_articles
  summary_html
  content_html                 # feed-provided body, if any
  full_content_html            # extracted body, if fetched
  full_content_status          # idle | fetching | fetched | failed | skipped
  full_content_fetched_time
  full_content_error
```

The exact schema can differ, but the important rule is that fetched content is RSS-owned content, not memo content.

### 2. Fetch controls

Support two practical entry points:

```text
feed setting: fetch full content for this feed
article action: fetch full content now
```

If background refresh exists, enabled feeds may fetch full content during scheduled refresh. Without background refresh, manual feed refresh and manual article fetch are sufficient.

### 3. Extraction pipeline

The pipeline should be service-owned:

```text
application/rss/rss_full_content_service.dart
  -> HTTP fetch with timeout and size limits
  -> content-type check
  -> readable article extraction
  -> HTML sanitizer
  -> RSS repository write
```

If existing quick-clip or web extraction logic is reusable, extract it into a stable service layer first. Lower layers must not import collection widgets or share-capture UI.

### 4. Reader selection

The RSS reader should choose content in this order:

```text
full_content_html
feed content_html
summary_html
empty-state / open original link
```

Failure to fetch full content should never make an article unreadable if feed content exists.

### 5. Failure and safety behavior

Fetch failures should be article-local:

```text
timeout
unsupported content type
oversized response
extraction failed
sanitization rejected content
```

The UI may expose retry, open original, and a compact failure state. A failed full-content fetch should not block feed refresh, collection opening, or save-as-memo.

## Risks / Trade-offs

- [Risk] Extraction quality varies by site. Mitigation: keep feed content fallback and make manual retry/open-original available.
- [Risk] Unsafe HTML could enter the reader. Mitigation: sanitize before storage or before rendering, preferably both if rendering supports it.
- [Risk] Reusing quick-clip extraction may create bad dependencies. Mitigation: move reusable extraction into an application/core service before sharing it.
- [Risk] Fetching full content can increase battery, bandwidth, and site load. Mitigation: per-feed opt-in, timeouts, size limits, and bounded concurrency.

## Resolved Decisions

- Full-content fetch SHALL NOT create memos automatically.
- Extracted content SHALL remain attached to RSS article state until the user explicitly saves the article as a memo.
- Feed-provided content SHALL remain available as fallback.
