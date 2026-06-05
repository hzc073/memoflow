# macos-debug-file-picker-entitlement Specification

## ADDED Requirements

### Requirement: macOS Debug/Profile builds SHALL allow user-selected file access
macOS Debug/Profile 构建 SHALL 声明用户显式选择文件后的读写权限，以支持公开 memo 附件选择、导入等本地开发验证流程。

#### Scenario: Debug/Profile entitlements are reviewed
- **WHEN** `memos_flutter_app/macos/Runner/DebugProfile.entitlements` 被检查
- **THEN** it SHALL include `com.apple.security.files.user-selected.read-write`
- **AND** it SHALL keep `com.apple.security.app-sandbox` enabled

#### Scenario: Commercial capabilities remain excluded
- **WHEN** Debug/Profile entitlement 配置发生变化
- **THEN** it SHALL NOT add StoreKit, subscription, receipt validation, product ID, price, paywall, App Store Connect, signing secret, provisioning profile, notarization credential, camera, photos library, contacts, calendar, Bluetooth, USB, Apple Events, screen recording, or accessibility/input monitoring capabilities
