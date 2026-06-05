## 1. macOS 权限声明

- [x] 1.1 更新 `memos_flutter_app/macos/Runner/Info.plist`，为麦克风、定位和本地网络添加用户可见用途说明。
- [x] 1.2 更新 `memos_flutter_app/macos/Runner/Release.entitlements`，保留 Sandbox 和 Network Client，并加入 Network Server、User Selected Files Read/Write、Microphone、Location。
- [x] 1.3 确认不添加通知、相机、照片库、辅助功能/输入监控、屏幕录制、通讯录、日历、蓝牙、USB、Apple Events 或商业 Apple 权限。

## 2. 验证

- [x] 2.1 使用 `plutil -lint` 验证 `Info.plist` 和 Release entitlements 语法。
- [x] 2.2 使用 `plutil -p` 检查最终权限键集合。
- [x] 2.3 运行 macOS public shell guardrail，确认未引入 StoreKit/IAP/订阅/收据/价格/发布密钥等公开仓库泄漏。
- [x] 2.4 检查 diff，确认未触碰 API compatibility 文件和商业私有 seam。
