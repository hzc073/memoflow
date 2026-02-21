# Update Config Layout

This folder stores update configuration in split files to avoid single-file blast radius.

## Files

- `manifest.json`: global settings and index pointers.
- `donors.json`: optional donor list consumed by client UI.
- `announcements/{id}.json`: one announcement per file.

## Workflow

1. Update `donors.json` and other static fields in `manifest.json` as needed.
2. Open a PR and let `Update Config Validate` run reference checks.
3. Push a `v*` tag and build release assets.
4. Cloudflare Worker auto-creates a new announcement file and updates:
   - `manifest.json -> announcement_ids`
   - `manifest.json -> latest_announcement_id`
   - `manifest.json -> announcement_tag_index`
5. `Update Config Build` generates merged `latest.json` (triggered by release, push to `update_config/**`, or manual dispatch).
6. `Update Config Publish` publishes to `gh-pages/update/`.

## Announcement File Fields

- `id`: unique numeric string, should never be reused.
- `release_tag`: optional idempotency marker such as `v1.0.15`.
- `version`: display version for release notes.
- `date`: display date label.
- `title`: dialog title.
- `show_when_up_to_date`: whether to show dialog even when no update exists.
- `contents`: localized announcement paragraphs.
- `new_donor_ids`: optional donor IDs to highlight.
- `items`: release note groups.
