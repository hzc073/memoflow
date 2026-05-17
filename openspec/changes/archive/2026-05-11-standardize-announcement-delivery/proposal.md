## Why

当前通知公告和更新公告共用一条远端配置与启动展示链路，生产配置一旦修改就可能影响所有设备，缺少 preview/staging、发布状态、受众条件、过期时间、队列优先级和发布前校验。这个 change 规范公告交付规则，让公告可以先预览、可控发布、可回滚，并顺手收缩 `application/updates -> features/updates` 的 UI 耦合。

## What Changes

- Introduce an `announcement-delivery` capability for notification notices and update announcements with a phase A-E remediation rule:
  - Phase A: safe preview config source and Debug preview workflow.
  - Phase B: versioned config contract with `status`, `publish_at`, `expire_at`, audience targeting, and id/revision dismissal.
  - Phase C: startup delivery queue, priority policy, and once-per-startup behavior.
  - Phase D: modularity cleanup so application logic produces presentation requests without importing feature dialogs.
  - Phase E: validation, release checklist, rollback guidance, and documentation.
- Add a schema v3-compatible announcement config model while preserving legacy `version_info`, `announcement`, `notice_enabled`, `notice`, and `release_notes` parsing during migration.
- Split production and preview config behavior so formal startup uses production config while Debug tools can preview production, preview, custom URL, or local JSON sources.
- Normalize update announcement routing so Android Play builds still suppress full APK update prompts while ordinary non-update notices remain independently eligible.
- Replace content-hash-only notice dismissal with id/revision-aware dismissal policy for new v3 notices, while preserving existing hash behavior for legacy config.
- Add local config validation rules for production safety before publishing.
- Reduce touched modularity debt in active architecture phase `evolve_modularity`, specifically checklist item 2: no `application -> features` reverse dependencies.

## Capabilities

### New Capabilities

- `announcement-delivery`: Defines remote announcement config environments, notice/update eligibility, dismissal policy, delivery queue ordering, preview behavior, validation rules, and application/UI boundary expectations.

### Modified Capabilities

- `update-announcement-channel-routing`: Refines Android Play routing so full APK update prompts remain suppressed without blocking ordinary notice delivery or manual non-startup content surfaces.

## Impact

- Affected runtime areas:
  - `memos_flutter_app/lib/data/updates/update_config.dart`
  - `memos_flutter_app/lib/data/updates/update_config_service.dart`
  - `memos_flutter_app/lib/application/updates/update_announcement_runner.dart`
  - `memos_flutter_app/lib/application/updates/update_announcement_channel_policy.dart`
  - `memos_flutter_app/lib/features/updates/*`
  - `memos_flutter_app/lib/features/debug/debug_tools_screen.dart`
  - `memos_flutter_app/lib/state/system/update_config_provider.dart`
  - device preference models/providers that persist announcement dismissal state
- Affected tests:
  - update config parser tests
  - startup/update channel policy tests
  - announcement eligibility and queue tests
  - Debug preview tests where practical
  - architecture guardrail tests for shrinking `application/updates -> features/updates` allowlist entries
- No backend service is required. Remote JSON files remain the source of truth.
- No commercial, subscription, entitlement, paywall, or private overlay behavior is introduced.
