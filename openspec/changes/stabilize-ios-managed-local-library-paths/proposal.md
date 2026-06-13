## Why

iPhone 真机日志显示 `LocalSync` 在 `LocalLibraryFileSystem.ensureStructure()` 中尝试创建旧 iOS App 容器路径，触发 `PathAccessException: Operation not permitted`。根因是本地库元数据把 `managedPrivate` 的绝对 `rootPath` 持久化在 secure storage/Keychain 中，而 iOS App 数据容器会在重装、重新部署或数据迁移后改变，Keychain 状态却可能继续存在。

当前架构阶段是 `evolve_modularity`。本变更触及 `state/system`、`application/sync`、`data/local_library` 等 workspace/storage 边界，必须让 touched area equal or better structured：把 managed local library 的稳定身份收敛到 `key`，把容器相关路径作为运行时派生状态，并明确 stale Keychain/App Support 不一致时的恢复语义。

## What Changes

- 明确 `LocalLibraryStorageKind.managedPrivate` 的持久身份是 workspace `key`，`rootPath` 是可重算的当前运行时路径，不应作为跨启动/跨容器的权威路径。
- 加载本地库时对 managed private library 执行 path rebase：通过 `resolveManagedWorkspacePath(library.key)` 或等价 resolver 得到当前容器路径，发现旧 `rootPath` 时更新并持久化。
- 迁移本地库非秘密元数据的长期 owner：避免把 local library list / managed root path 继续作为 Keychain-only 状态；保留 secure storage 用于账号 token 等秘密数据。
- 处理 iOS Keychain 生命周期长于 App Support 的 stale 状态：当 secure storage 指向本地 workspace，但当前 App Support/数据库/本地库文件明确不存在时，不应继续访问旧容器路径，也不应静默制造不可解释的旧 workspace。
- 保持本地同步安全：path rebase 不得把新空目录误判为用户删除所有磁盘 memo，也不得清除 memo DB、outbox、附件私有源、WebDAV 备份或账号数据。
- 增加 focused tests 覆盖 stale managed `rootPath`、legacy secure-storage migration、stale local workspace reconciliation 和 local sync 不再访问旧容器路径。
- 不修改 Memos API、request/response models、route adapters、version compatibility、WebDAV 协议或数据库 schema。

## Capabilities

### New Capabilities

- `managed-local-library-storage`: 约束 managed private local library 的路径派生、元数据持久化、iOS stale container 修复和同步安全行为。

### Modified Capabilities

- 无。

## Impact

- 预计修改：
  - `memos_flutter_app/lib/application/sync/local_library_import_migration_service.dart`
  - `memos_flutter_app/lib/data/local_library/local_library_paths.dart`
  - `memos_flutter_app/lib/data/repositories/local_library_repository.dart`
  - `memos_flutter_app/lib/state/system/local_library_provider.dart`
  - 可能涉及 `memos_flutter_app/lib/state/system/session_provider.dart` 的 stale local workspace key 对齐
- 预计补充 tests：
  - `memos_flutter_app/test/application/sync/local_library_import_migration_service_test.dart`
  - `memos_flutter_app/test/state/system/local_library_provider_test.dart` 或等价 focused provider test
  - 按需要补充 local sync/path regression test
- 不新增第三方依赖。
- 本变更不触碰 `memos_flutter_app/lib/data/api` 或 `memos_flutter_app/test/data/api`。
