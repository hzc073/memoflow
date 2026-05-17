# Announcement Release Workflow

Use this workflow before changing the production announcement config. The goal
is to preview the message on a developer device first, then publish only after
validation passes.

## 1. Prepare Preview Config

1. Copy `tool/announcement_config.preview.example.json` or the current
   production JSON into a preview-only file.
2. Set `environment` to `preview`.
3. Keep new items at `status: "preview"` while drafting.
4. Use stable item ids and increment `revision` when the same notice should be
   shown again after an earlier dismissal.
5. Keep legacy fallback fields present and safe while older clients still read
   them.

Do not put sensitive drafts in a public production JSON file. `draft` is a
validation blocker for production, not a security boundary.

## 2. Preview Locally

1. Open the app in a Debug build.
2. Use Debug tools to select the preview, custom URL, or local JSON source.
3. Confirm the exact title, body, update URL, schedule, platform/channel
   targeting, and dismissal behavior.
4. Confirm preview display does not write formal startup dismissal state.

Formal startup must continue to fetch the production source only. If preview
loading fails, fix the preview source instead of changing production fallback
behavior.

## 3. Validate Production Config

Before publishing, move intended items to `status: "public"` in the production
JSON and run:

```bash
dart run tool/validate_announcement_config.dart tool/announcement_config.production.example.json
```

For a real release, replace the example path with the production JSON file that
will be uploaded.

Validation errors must block publishing. Warnings require human review before
publishing.

Blocked examples:

- invalid JSON
- duplicate ids
- `draft` items in production
- public items without `publish_at`
- invalid `publish_at` / `expire_at` order
- notices without body content
- forced updates without a valid HTTP(S) download URL

Warning examples:

- expiry windows longer than 45 days
- missing English body content
- update items without a matching release note
- Play-channel update items pointing to APK URLs
- wording that still looks like test/debug content

## 4. Publish

1. Upload the validated production JSON.
2. Re-fetch it from the public URL and validate the downloaded copy.
3. Start one Debug build with the production source selected and confirm the
   visible behavior.
4. For startup announcements, restart the app once and verify only the
   highest-priority eligible non-forced item is shown.

## 5. Roll Back

Prefer config rollback over app changes.

Fast rollback options:

1. Set the affected v3 item to `status: "archived"`.
2. Remove the affected item from `notices` or `updates`.
3. Restore the previous production JSON file.
4. For legacy clients, keep legacy fallback fields safe: `notice_enabled:
   false`, empty `announcement`, and non-forced `version_info` when no update
   prompt should appear.

After rollback, validate the replacement JSON and confirm a fresh app startup
no longer selects the retired item.
