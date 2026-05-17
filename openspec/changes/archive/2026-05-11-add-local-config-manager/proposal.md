## Why

`memoflow_config` 现在通过手工编辑 `update/manifest.json`, `update/announcements/*.json`, and `update/donors.json` 来维护更新公告、通知公告、更新候选和捐赠者数据，字段之间存在索引、旧版兼容和构建产物同步关系，纯手改容易漏维护。随着 `schema_version: 3` announcement delivery 已经在 app 侧成型，需要一个只在本地运行的可视化管理工具，降低发布配置错误和旧版兼容回归风险。

## What Changes

- Add a localhost-only config management tool under `F:/Homework/memoflow_config/config/`.
- Provide a browser UI for:
  - 查看和编辑当前更新公告。
  - 查看历史更新公告。
  - 编写、发布、查看 v3 notification notices.
  - 可视化管理 v3 update candidates.
  - 查看、添加、删除捐赠者，并处理头像资源引用。
- Add a local service that owns file-system writes, validation, preview data loading, optional asset upload, and build-script invocation.
- Keep split source files as the source of truth:
  - `update/manifest.json`
  - `update/announcements/*.json`
  - `update/donors.json`
  - `update/assets/*`
- Preserve legacy app compatibility:
  - `version_info`, `announcement`, `release_notes`, `donors`, `notice_enabled`, and `notice` remain available in generated output for old clients.
  - v3 `notices[]` and `updates[]` are authored for new clients.
  - One selected v3 notice MAY be explicitly synced to legacy `notice` / `notice_enabled`; this is opt-in.
  - The active primary v3 update candidate MAY be synced to legacy `version_info` for old update prompts.
- Do not directly edit `dist/update/latest.json`; it remains a build artifact generated through `.github/scripts/build_update_config.py`.
- No breaking changes are intended for app clients or existing CI publish flows.

## Capabilities

### New Capabilities

- `local-config-manager`: Defines the local-only visual management workflow for MemoFlow remote config source files, including v3/legacy compatibility behavior, local preview, validation, build integration, and safe file ownership.

### Modified Capabilities

- None.

## Impact

- Target implementation repository:
  - `F:/Homework/memoflow_config`
- Expected new local tool files:
  - `config/server.py`
  - `config/manager.html`
  - `config/manager.js`
  - `config/manager.css`
- Affected config source files:
  - `update/manifest.json`
  - `update/announcements/*.json`
  - `update/donors.json`
  - `update/assets/*`
- Existing build and validation path:
  - `.github/scripts/build_update_config.py --root update --validate-only`
  - `.github/scripts/build_update_config.py --root update --output dist/update/latest.json`
- Active architecture phase is `evolve_modularity`.
  - This change does not add Flutter runtime dependencies and SHOULD NOT touch the existing `state -> features`, `application -> features`, or `core -> higher-layer` coupling hotspots.
  - It preserves critical modularity checklist items 1-4 by keeping this tool outside `memos_flutter_app/lib` and by putting config-file mutation behind a local service boundary.
  - It touches checklist item 7 because write paths gain a clear local service owner, and checklist item 9 because this OpenSpec change documents expected behavior.
