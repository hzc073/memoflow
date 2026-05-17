## Context

OPML is a subscription exchange format. In this app it should map to RSS feed subscriptions and collection organization, not article content:

```text
OPML outline -> feeds/groups -> collection RSS sources
```

It should not map to memos:

```text
OPML -X-> memos
OPML -X-> RSS articles
```

## Goals / Non-Goals

**Goals:**

- Import common OPML feed outlines.
- Export current RSS subscriptions as OPML.
- Preview import results before writing subscriptions.
- Handle duplicate feed URLs predictably.
- Preserve collection/group organization where practical.
- Keep parser/exporter logic outside UI widgets.

**Non-Goals:**

- No article import/export.
- No memo import/export.
- No automatic memo creation.
- No feed refresh requirement during import, except optional metadata validation if explicitly selected.

## Proposed Shape

### 1. Parser and exporter services

Prefer service-owned OPML logic:

```text
application/rss/opml_import_service.dart
application/rss/opml_export_service.dart
data/models/rss_opml_preview.dart
```

The parser should support common outline attributes:

```text
text
title
xmlUrl
htmlUrl
type
description
```

Unknown attributes can be ignored unless a safe preservation path is deliberately added later.

### 2. Import preview

Import should be two-phase:

```text
select OPML file
        |
        v
parse + normalize + classify
        |
        v
preview: new feeds, duplicates, folders, invalid entries
        |
        v
commit selected changes
```

The preview should make it clear what will be added, skipped, merged, or left unresolved.

### 3. Duplicate handling

Normalize feed URLs before comparison where safe:

```text
existing feed_url matches imported xmlUrl -> duplicate
duplicate in same import file -> single candidate with source count
```

Commit behavior should avoid duplicate feed rows. Existing feeds can be attached to the selected target collection if not already attached.

### 4. Collection and folder mapping

Simple first rule:

```text
import target = selected collection
all imported feeds attach to selected collection by default
```

If OPML folders are present, the UI may offer one of these explicit mappings:

```text
flatten into selected collection
create collections from folders
map folders to existing collections
```

Do not silently create a large set of collections without preview and confirmation.

### 5. Export mapping

Export should include subscription organization:

```text
collections / folders
  -> outline text/title
feeds
  -> outline type="rss" xmlUrl htmlUrl title/text
```

Exported OPML should not include memo content, RSS article bodies, read state, saved memo links, or notification/full-content settings unless a future change explicitly adds a supported extension.

## Risks / Trade-offs

- [Risk] OPML files vary widely. Mitigation: support common attributes, surface invalid entries, and import partially.
- [Risk] Folder-to-collection mapping can surprise users. Mitigation: preview and require confirmation before creating collections.
- [Risk] Duplicate handling can be confusing. Mitigation: normalize feed URLs and show add/skip/attach decisions before commit.
- [Risk] Parser logic could end up embedded in UI. Mitigation: keep parser/exporter in RSS application/data services with focused tests.

## Resolved Decisions

- OPML SHALL exchange RSS subscription metadata only.
- OPML import SHALL NOT create memos or RSS articles.
- Import SHALL provide a preview before committing subscription changes.
