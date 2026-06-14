# phase-1-boundary-freeze Specification

## Purpose
TBD - created by archiving change phase-1-boundary-freeze-and-inventory. Update Purpose after archive.
## Requirements
### Requirement: 第 1 阶段 SHALL 冻结公开/私有仓库边界
在桌面重构开始前，项目 SHALL 明确冻结公开/私有边界：公开仓库 MAY 包含已批准的非商业 Apple public shell scaffolding；公开仓库 MUST NOT 包含商业运行时逻辑、StoreKit 集成、权益评估、价格元数据、签名秘密或 Apple 发布自动化。

#### Scenario: 第 1 阶段审查公开边界
- **WHEN** 项目批准第 1 阶段基线或后续治理变更更新边界
- **THEN** 公开/私有边界必须被记录，并作为后续变更的活动规则集
- **AND** approved Apple public shell scaffolding SHALL be treated separately from Apple commercial runtime

### Requirement: 第 1 阶段 SHALL 保留已批准的私有 Dart 接入点
在第 1 阶段，唯一批准的私有 Dart 集成接入点 SHALL 保持为 `memos_flutter_app/lib/private_hooks/active_private_extension_bundle.dart`。

#### Scenario: 第 1 阶段讨论私有集成
- **WHEN** 在边界冻结阶段提出新的私有集成路径
- **THEN** 除非后续治理变更明确扩大批准接入点，否则必须拒绝

