## Why

macOS 本地 debug/profile 构建点击 memo 附件入口时，系统文件选择框没有出现。实际运行中的 Debug-Runner 签名权限缺少 `com.apple.security.files.user-selected.read-write`，而 public app 的附件功能需要用户显式选择文件后读取文件。

## What Changes

- 为 macOS Debug/Profile entitlement 配置补齐 `User Selected Files Read/Write` 权限，使本地开发构建与 Release 中已确认的公开附件能力保持一致。
- 保持变更范围仅限公开、非商业平台权限，不引入 StoreKit、订阅、付费、receipt、product ID、paywall 或私有 overlay 逻辑。
- 不改动 memo API、附件上传协议、图片处理流程或 UI 行为。

## Capabilities

### New Capabilities
- `macos-debug-file-picker-entitlement`: 约束 macOS debug/profile 构建必须声明用户选择文件读写权限，以支持公开附件选择流程。

### Modified Capabilities
- 无。

## Impact

- 影响文件：`memos_flutter_app/macos/Runner/DebugProfile.entitlements`
- 不影响 API、数据模型、同步协议、数据库结构或商业边界。
- Architecture phase: `evolve_modularity`。本变更不触碰 `state`、`application`、`core`、`features` 耦合热点，不新增 Dart runtime 依赖方向。
