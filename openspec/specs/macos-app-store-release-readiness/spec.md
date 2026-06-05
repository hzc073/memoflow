# macos-app-store-release-readiness Specification

## Purpose
TBD - created by archiving change prepare-macos-app-store-release. Update Purpose after archive.
## Requirements
### Requirement: macOS release permissions SHALL match confirmed public features
macOS Release 配置 SHALL 只声明首版公开功能实际需要的系统能力：`App Sandbox`、`Network Client`、`Network Server`、`User Selected Files Read/Write`、`Microphone`、`Location`、`Local Network/Bonjour`，以及 Keychain self-use。

#### Scenario: Release entitlements are reviewed
- **WHEN** `memos_flutter_app/macos/Runner/Release.entitlements` 被检查
- **THEN** it SHALL include sandbox, outbound network, inbound/local network server, user-selected read/write file access, microphone, and location entitlements
- **AND** it SHALL NOT include notification, camera, photos library, accessibility/input monitoring, screen recording, contacts, calendar, Bluetooth, USB, Apple Events, StoreKit, subscription, receipt, pricing, signing secret, or App Store release automation capabilities

#### Scenario: Info.plist privacy strings are reviewed
- **WHEN** `memos_flutter_app/macos/Runner/Info.plist` 被检查
- **THEN** it SHALL include user-facing purpose strings for microphone, location, and local network use
- **AND** those strings SHALL describe current public features rather than future commercial or private capabilities

### Requirement: macOS release permissions SHALL remain commercially neutral
macOS Release 权限配置 SHALL NOT 引入商业 Apple runtime、私有产品标识、签名机密或发布凭据。

#### Scenario: Permission configuration changes are reviewed
- **WHEN** macOS permission or entitlement files change
- **THEN** the change SHALL remain limited to non-commercial platform capabilities required by public features
- **AND** it SHALL NOT add StoreKit, IAP, entitlement evaluation, receipt validation, product IDs, prices, Team ID, certificates, provisioning profiles, App Store Connect credentials, notarization credentials, or release automation

