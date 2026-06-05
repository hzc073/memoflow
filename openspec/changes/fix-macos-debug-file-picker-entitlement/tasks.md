## Tasks

- [x] 更新 `memos_flutter_app/macos/Runner/DebugProfile.entitlements`，加入 `com.apple.security.files.user-selected.read-write`。
- [x] 验证 entitlement 源文件包含新增权限且未引入商业或无关敏感能力。
- [x] 重建或检查 macOS Debug-Runner 签名权限，确认生成产物包含 `com.apple.security.files.user-selected.read-write`。
