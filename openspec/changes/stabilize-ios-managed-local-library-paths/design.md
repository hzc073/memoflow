## Context

日志中的失败路径类似：

```text
LocalSyncController.syncNow()
  └── fileSystem.ensureStructure()
      └── LocalLibraryFileSystem._ensureDir(['memos'])
          └── Directory(oldRootPath).createSync(recursive: true)
              -> PathAccessException: Operation not permitted
```

`oldRootPath` 形如：

```text
/var/mobile/Containers/Data/Application/<old-uuid>/Library/Application Support/workspaces/<key>/library
```

当前代码中 `LocalLibraryImportMigrationService.migrateIfNeeded()` 对 `managedPrivate` 直接返回：

```dart
if (library.storageKind == LocalLibraryStorageKind.managedPrivate) {
  return library;
}
```

这意味着已经迁入 managed private 的本地库不会在启动时重新解析当前 App Support 容器路径。与此同时，`LocalLibraryRepository` 使用 `flutter_secure_storage`，iOS 上 secure storage 可能落在 Keychain；Keychain 的生命周期可能长于 App data container。因此重新安装或重新部署后，Keychain 里还保留本地库列表和 `currentKey`，但 App Support、数据库和本地库文件已经处在新的容器甚至已经丢失。

当前状态可以表示为：

```text
Keychain / secure storage
  ├── app session currentKey = local_...
  └── local_library_state_v1.rootPath = old container path

Current App data container
  ├── Application Support/workspaces/local_.../library  (new path or absent)
  └── databases/memos_app_<hash>.db                     (new path or absent)
```

根本修复需要同时解决两件事：

- managed private 路径不能把旧容器绝对路径当作权威值。
- 非秘密的 local library metadata 不应长期只依赖 Keychain，否则 App data 已清空时会恢复出 stale local workspace。

## Goals / Non-Goals

**Goals:**

- 启动和同步时永远不尝试写入旧 iOS App container 的 managed local library path。
- 对 `managedPrivate` 本地库进行 current-container path rebase，并持久化修正后的路径或改为运行时派生。
- 将 local library metadata 的长期 owner 从 secure-storage-only 迁向 App Support 中的 app-data storage，避免卸载/重装后的 Keychain stale local library 幽灵状态。
- 明确 stale secure storage 与当前 App Support/DB 不一致时的处理：不得访问旧路径，不得误删数据，不得静默把旧 workspace 当作完整可用。
- 保持账号 token 等秘密数据仍由 secure storage 管理。
- 添加 focused tests 覆盖 iOS-like stale path 和 stale metadata 场景。

**Non-Goals:**

- 不实现 WebDAV、远程 Memos API 或数据库 schema 迁移。
- 不保证从已被 iOS 删除的旧 App container 恢复文件；旧容器不可访问时只能停止引用旧路径。
- 不在本变更中重建所有 local library markdown/attachment 文件；如需要从 DB 重建磁盘库，应作为后续数据修复任务或明确子任务实现，并单独验证不会丢数据。
- 不改变用户主动删除本地库、退出登录或首次 onboarding 的既有意图。

## Decisions

### Decision: `managedPrivate` path 每次加载都必须 rebase 到当前容器

`LocalLibraryImportMigrationService.migrateIfNeeded()` 不应对 `managedPrivate` 直接返回。实现阶段应对 managed library 执行：

```text
expectedPath = resolveManagedWorkspacePath(library.key)
if normalize(library.rootPath) != normalize(expectedPath):
  next = library.copyWith(rootPath: expectedPath, clearTreeUri: true)
  persist next
```

该 rebase 只改变 managed library 的当前路径，不从旧容器复制文件，也不尝试创建旧容器父目录。

Alternatives considered:

- 只在 `LocalLibraryFileSystem._ensureDir` 捕获 `PathAccessException` 后改路径：太晚，文件系统层不知道 repository/persist 语义，也无法更新 provider state。
- 要求用户删除 App 或清 Keychain：不是产品级修复，且 iOS Keychain 保留行为会继续复现。
- 保持旧 `rootPath`，仅跳过 sync：会让 home 进入但本地库永远不可同步。

### Decision: managed library 的稳定持久字段是 `key`，不是绝对 `rootPath`

长期模型应把 `rootPath` 视为运行时派生字段。为了兼容现有 JSON，可先继续写入当前 `rootPath`，但读取时必须以 resolver 结果为准。后续可把 `rootPath` 从 persisted contract 中降级为 diagnostic/display cache。

```text
Stable:
  key
  name
  storageKind = managedPrivate
  createdAt / updatedAt

Derived:
  rootPath = current App Support + workspaces/<key>/library
```

### Decision: local library metadata 不应继续 Keychain-only

`local_library_state_v1` 是非秘密 workspace metadata。长期 owner 应在 App Support 的 app-data storage 中，例如 repository-owned JSON file；secure storage 可以作为 legacy read source，用于一次性迁移旧版本数据。账号 token、PAT、password-derived secrets 仍留在 secure storage。

迁移原则：

- 优先读取新 App Support storage。
- 如新 storage 不存在，再读取 legacy secure storage。
- 从 legacy 迁移时对每个 managed library 执行 path rebase。
- 成功迁移后写入新 storage；legacy secure value 可以保留一段兼容期或在设计明确后清理，但运行时不应继续以 legacy value 为权威。

### Decision: stale Keychain local workspace 必须被识别为可恢复/需重置状态

iOS 重装后可能出现 secure storage 仍有 `session.currentKey` 和 legacy local library state，但当前 App Support/DB 均不存在。实现阶段应增加 non-creating probe，避免 resolver 先创建目录后掩盖状态：

```text
legacy local key exists
current workspace directory existed before repair? no
current workspace database exists? no
current managed library files exist? no
=> stale local workspace metadata
```

对 stale local workspace metadata，系统不得访问旧 `rootPath`。可选处理：

- 不迁移该 local library record，并清理/对齐 `session.currentKey`，让 route gate 进入明确 onboarding/repair 状态。
- 或显示可操作的 storage repair/diagnostic 状态，提示本地 App data 已不可用。

实现选择应与 `prevent-transient-workspace-onboarding` 的 route stability 语义协调：短暂 reload miss 不等于 stale；只有稳定确认当前 App data 缺失时才处理为 stale。

### Decision: local sync rebase 后不得把空磁盘目录当作用户删除

如果 path rebase 后新目录为空，而 DB 仍有 memo，第一次 `scan_pre_push` 不应把空磁盘当成删除全部 memo 的用户意图。现有增量扫描在没有 manifest 时相对安全，但实现仍应通过 tests 固化：

- no manifest + empty disk + non-empty DB 不会批量 delete DB memos。
- rebase 后 `ensureStructure()` 创建的是当前容器目录。
- 后续是否从 DB 重建 markdown 文件应由明确 outbox/repair 任务负责。

### Decision: 边界保持在 data/application/state seam

路径解析属于 `data/local_library`，migration/rebase 属于 `application/sync` 或 repository migration service，provider 只协调加载和持久化。设置/home widget 不应直接判断路径是否 stale 或扫描 filesystem。

## Risks / Trade-offs

- [Risk] 把 local library metadata 迁出 secure storage 可能影响现有用户的本地库列表读取。→ Mitigation: 新 repository 先读 App Support storage，缺失时读 legacy secure storage 并迁移；测试覆盖 legacy migration。
- [Risk] stale detection 过于激进可能隐藏合法空 workspace。→ Mitigation: 使用 non-creating probe 判断当前 workspace directory marker、DB 文件或 existing library files；已存在的空 workspace 应保留。
- [Risk] path rebase 后磁盘为空但 DB 有 memo，可能造成文件/DB 不一致。→ Mitigation: 本变更先防止旧路径写入和 DB 误删；是否重建 local library files 作为明确任务处理，不作为隐式扫描副作用。
- [Risk] 修改 session/local library 对齐可能与 transient route stability 交叉。→ Mitigation: 区分 transient miss 与 stable stale；必要时复用或等待 `prevent-transient-workspace-onboarding` 的 pending route 语义。
- [Risk] touched area 横跨 `state/system` 和 `application/sync`。→ Mitigation: 不新增 `state -> features`、`application -> features` 或 `core -> higher-layer` 依赖，并补 focused provider/service tests。

## Migration Plan

1. 增加 managed workspace path helper：支持 current path resolve，并在需要 stale detection 时支持 non-creating probe。
2. 修改 local library migration/rebase 服务：`managedPrivate` 也会解析 current path，旧 `rootPath` 被替换为 current path。
3. 调整 `LocalLibraryRepository` 的 storage owner：新增 App Support file-backed storage；保留 legacy secure storage read/migration path。
4. 在 provider load 中持久化 rebase/migration 结果，并记录诊断日志。
5. 处理 stale legacy local workspace：当 legacy secure metadata 存在但当前 App data 明确不存在时，不迁移该 stale record，并对齐 active local session key 或暴露 repair/pending 状态。
6. 增加 tests 覆盖 stale path rebase、legacy migration、stale metadata reconciliation、local sync 不访问旧路径且不批量删除 DB memo。
7. 运行 focused tests、`flutter analyze` 和按需要 `flutter test`。

Rollback: 如果 App Support repository migration 发现兼容风险，可先保留 secure-storage repository 作为读写 owner，但必须保留 managed path rebase；完整 metadata owner 迁移可在后续补齐。

## Open Questions

- legacy secure storage 成功迁移到 App Support 后是否立即删除 `local_library_state_v1`，还是保留一个版本周期作为回滚兼容。实现前可根据风险选择，但运行时权威来源应是 App Support storage。
- stale local workspace 被确认后，用户界面应直接回 onboarding，还是进入 self-repair/storage diagnostics。若实现已有合适 repair seam，应优先给可解释状态；否则回 onboarding 也必须避免误导为数据仍存在。
- 是否在本变更内实现 DB -> local library markdown/attachment 重建。建议先只做安全 rebase 和 stale reconciliation，再根据用户数据恢复需求单独设计重建。
