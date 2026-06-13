## 1. Managed path rebase

- [x] 1.1 增加或调整 managed workspace path helper，使实现可以解析当前容器路径，并在 stale detection 需要时进行 non-creating probe。
- [x] 1.2 更新 `LocalLibraryImportMigrationService.migrateIfNeeded`：`LocalLibraryStorageKind.managedPrivate` 不再直接返回，而是根据 `library.key` rebase 到当前 managed path。
- [x] 1.3 对 rebased library 清理不适用的 `treeUri`，保持 `storageKind: managedPrivate`，并更新 `updatedAt`。
- [x] 1.4 确认 `LocalLibraryFileSystem.ensureStructure()` 在 rebase 后只访问当前 App Support path，不访问旧 iOS container path。

## 2. Local library metadata owner

- [x] 2.1 为 `LocalLibraryRepository` 增加 App Support file-backed metadata store，作为 local library list 的长期权威来源。
- [x] 2.2 保留 legacy secure-storage `local_library_state_v1` read path：当 App Support metadata 不存在时读取 legacy state 并迁移。
- [x] 2.3 legacy migration 期间对所有 managed private libraries 执行 path rebase，再写入 App Support metadata store。
- [x] 2.4 确认账号 token、PAT、密码相关 secret 和 account state 不被迁入 plain App Support JSON。
- [x] 2.5 决定并实现 legacy secure-storage local library state 的保留或清理策略，确保运行时不再以 legacy value 覆盖 App Support metadata。

## 3. Stale workspace reconciliation

- [x] 3.1 增加 stable probe，区分“当前容器中已有空 workspace”和“Keychain 指向但当前 App data 完全不存在”的 stale local workspace。
- [x] 3.2 当 legacy local workspace 被稳定确认为 stale 时，不迁移该 stale library record，也不使用旧 `rootPath`。
- [x] 3.3 评估并按需要对齐 `session.currentKey`：如果 active key 只指向 stale local workspace，应清理、修复或进入明确 recoverable 状态。
- [x] 3.4 与 `prevent-transient-workspace-onboarding` 的 pending route 语义保持一致，避免把短暂 local library reload miss 误判为 stale。

## 4. Local sync safety

- [x] 4.1 增加 local sync regression test：rebased path 下 `ensureStructure()` 创建当前 path 的 `memos`、`memos/_meta`、`attachments`。
- [x] 4.2 增加 scan safety test：rebased empty directory + non-empty DB + no manifest 时，不会批量删除 DB memos。
- [x] 4.3 如实现 DB-to-disk rebuild，必须作为显式 sync/repair 行为并补充 markdown、sidecar、attachment handling tests；若不实现，需在代码路径中避免隐式重建承诺。

## 5. Provider 与 repository 测试

- [x] 5.1 扩展 `local_library_import_migration_service_test.dart`：managed private stale `rootPath` 被 rebase 到 current `resolveManagedWorkspacePath(key)`。
- [x] 5.2 增加 repository migration test：legacy secure-storage local library state 迁移到 App Support metadata，并且 App Support metadata 之后优先。
- [x] 5.3 增加 stale metadata test：secure storage 指向 local workspace 但当前 App data 不存在时，不使用旧路径、不注册为可用 local library。
- [x] 5.4 增加 provider load test：rebased/migrated local library 会被持久化并暴露给 `currentLocalLibraryProvider`。

## 6. 验证

- [x] 6.1 从 `memos_flutter_app` 运行 focused local library/storage tests。
- [x] 6.2 从 `memos_flutter_app` 运行 `flutter analyze`。
- [ ] 6.3 按需要运行 `flutter test`。
- [x] 6.4 检查 diff，确认未触碰 API compatibility 文件、WebDAV 协议、数据库 schema、private hooks 或任何商业/paid-feature 逻辑。
