# private-macos-overlay-boundary Specification

## Purpose
TBD - created by archiving change desktop-platform-split-and-private-macos. Update Purpose after archive.
## Requirements
### Requirement: 公开仓库 SHALL 在没有私有商业代码时仍可构建
公开仓库 SHALL 在不依赖私有计费、权益、StoreKit、Apple 商业运行时代码、签名秘密或私有发布自动化的情况下继续构建和运行公开基础应用，包括已批准的 Apple public shell scaffolding。

#### Scenario: 单独检出公开仓库
- **WHEN** 在没有私有覆盖仓库的情况下使用公开仓库
- **THEN** 应用必须仅通过公开代码路径和公开桩实现完成构建
- **AND** 已批准的 `macos/` 或 `ios/` public shell scaffolding SHALL NOT require private commercial modules

### Requirement: 私有集成 SHALL 使用批准的私有接入点
私有仓库中的 Apple 商业集成 SHALL 只能通过 `memos_flutter_app/lib/private_hooks/active_private_extension_bundle.dart` 这个批准的 Dart 接入点进入公开 Flutter 代码，除非未来治理变更明确扩大接入点范围。

#### Scenario: 接入私有运行时
- **WHEN** Apple private overlay 覆盖公开 checkout 以提供 macOS、iPhone 或 iPadOS 商业运行时
- **THEN** 活跃私有 bundle 实现必须替换或提供批准的接入点，且不要求公开外壳文件直接导入私有商业模块
- **AND** public shell SHALL remain runnable with the public no-op bundle when the private overlay is absent

### Requirement: 机密商业数据 MUST NOT 进入公开仓库
公开仓库 MUST NOT 包含产品标识符、订阅档位、收据校验逻辑、权益评估逻辑、价格数据、签名密钥、provisioning profile、Team ID、TestFlight 自动化、App Store Connect 自动化或 Apple 发布凭据。

#### Scenario: 引入新的商业关注点
- **WHEN** 某个变更需要订阅、计费、权益、StoreKit、购买恢复、收据校验、商品配置、价格、签名或发布密钥行为
- **THEN** 该行为及其相关数据只能在 Apple private overlay 或私有发布基础设施中实现
- **AND** public repository SHALL expose only approved public seams or product-level capability decisions

### Requirement: Apple public shell scaffolding SHALL be allowed in public repository
公开仓库 SHALL be allowed to contain non-commercial Apple public shell scaffolding such as `memos_flutter_app/macos/` and `memos_flutter_app/ios/` when that scaffolding supports public base app behavior.

#### Scenario: 添加公开 Apple 平台壳
- **WHEN** a change adds or updates `memos_flutter_app/ios/` or `memos_flutter_app/macos/`
- **THEN** the platform project SHALL remain limited to public base shell behavior, public permissions, public branding, and public plugin registration
- **AND** it SHALL NOT include StoreKit, private entitlement evaluation, product IDs, prices, receipt validation, Apple signing secrets, or private release automation

### Requirement: Apple commercial runtime SHALL stay private
Apple 商业运行时 SHALL remain owned by Apple private overlay or private packages.

#### Scenario: Apple paid entitlement is introduced
- **WHEN** a paid Apple entitlement, purchase flow, restore flow, product display, receipt validation, or commercial release process is introduced for macOS, iPhone, or iPadOS
- **THEN** it SHALL be implemented in Apple private overlay or private release infrastructure
- **AND** public repository code SHALL only consume approved contribution seams or product-level `AppCapability` decisions

