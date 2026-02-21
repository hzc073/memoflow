# Cloudflare Update Config Worker

This Worker automates update metadata when you push a `v*` tag.

## What It Updates

Given a release tag, it will:

1. Read release assets from GitHub Releases.
2. Update `update_config/manifest.json`:
   - `version_info.android.url`
   - `version_info.android.latest_version`
   - `version_info.windows.url`
   - `version_info.windows.latest_version`
   - `publish_at` for updated platforms
3. Auto-create a new announcement file in `update_config/announcements/`.
4. Update:
   - `announcement_ids` (append new id)
   - `latest_announcement_id` (switch to new id)

## ID Strategy

- New announcement ID format: `yyyyMMddHHmmss + random(100-999)`.
- Timestamp uses release `published_at` (or `created_at`) in UTC.
- The 3-digit random part is stable per tag (hash-based) to prevent duplicates on retries/concurrent triggers.
- IDs are stored as strings in `manifest` for JS safety.
- Idempotency by tag:
  - `manifest.announcement_tag_index["v1.0.15"] = "<id>"`
  - repeated calls for the same tag will reuse the same ID.

## Required Worker Secrets

- `UPDATE_TOKEN`: shared token used by GitHub Actions caller.
- `GITHUB_TOKEN`: GitHub PAT with repo `contents:write`.

## Optional Worker Vars

- `DEFAULT_APP_REPO` (default: `hzc073/memoflow`)
- `DEFAULT_CONFIG_REPO` (default: `hzc073/memoflow`)
- `DEFAULT_CONFIG_BRANCH` (default: `main`)
- `DEFAULT_MANIFEST_PATH` (default: `update_config/manifest.json`)
- `DEFAULT_ANNOUNCEMENTS_DIR` (default: `update_config/announcements`)

## Deploy

1. Copy `wrangler.toml.example` to `wrangler.toml`.
2. Set secrets:
   - `wrangler secret put UPDATE_TOKEN`
   - `wrangler secret put GITHUB_TOKEN`
3. Deploy:
   - `wrangler deploy`

## Caller Payload (JSON)

```json
{
  "tag": "1.0.15",
  "app_repo": "hzc073/memoflow"
}
```

Tag with or without leading `v` is accepted.

## GitHub Repository Secrets

Set these in your app repository:

- `CF_UPDATE_CONFIG_URL`: Worker endpoint URL
- `CF_UPDATE_CONFIG_TOKEN`: same value as Worker `UPDATE_TOKEN`

Current workflows call this endpoint automatically after tag builds.
