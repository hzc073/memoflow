## Context

探索阶段对 `memos_flutter_app/lib/features/settings` 做了静态扫描，发现设置子页面存在多类 raw Material 控件：

```text
LocationSettingsScreen
  -> ChoiceChip  已在 iPhone 真机触发 No Material widget found

MemoToolbarSettingsScreen
  -> ChoiceChip / raw AlertDialog / TextField / Material buttons

AI settings pages
  -> ActionChip / FilterChip / SwitchListTile / TextField / TextFormField / raw dialogs / MaterialPageRoute

WebDavSyncScreen
  -> DropdownButton / CheckboxListTile / RadioListTile / many showDialog / buttons / progress

Migration settings pages
  -> SegmentedButton / CheckboxListTile / LinearProgressIndicator / MaterialPageRoute
```

这些控件不是全部都会立刻崩溃：如果它们在 `showDialog` 或 `showPlatformPopoverOrSheet` 内，可能已有 Material surface。但它们仍然造成三个问题：

- Apple mobile 设置页某些路径会因缺少 `Material` ancestor 崩溃。
- 同一类设置交互在不同子页面里呈现不统一。
- 页面直接选择 Material/Cupertino widget，平台差异散落在 feature files，违背 `evolve_modularity` 期间对 coupled area 的要求。

本 change 应在 `platformize-settings-core-controls` 提供通用 seam 后执行；如果核心控件 seam 未完成，应暂停或只处理不依赖新 seam 的低风险替换。

## Goals / Non-Goals

**Goals:**

- 让主要设置子页面在 iPhone/iPadOS 下可打开、可滚动、可进行核心交互，不再出现 `No Material widget found`。
- 让设置子页面复用 settings/platform semantic controls，而不是页面内直接使用 Material-only chip/radio/checkbox/dropdown/button/dialog。
- 保持现有 provider mutation、validation、routes、labels、keys、sync/backup semantics、AI model/service semantics 不变。
- 为 migrated pages 增加 iOS smoke tests 或 focused widget tests。
- 更新 guardrail 或 allowlist，防止已迁移文件重新引入高风险控件。

**Non-Goals:**

- 不重写 WebDAV、AI、migration 等复杂业务流程。
- 不改变 API compatibility、WebDAV protocol、database schema、sync protocol、backup archive format 或 migration data format。
- 不把所有页面改成完全原生 iOS 视觉；目标是 Apple-safe、平台一致、结构收敛。
- 不新增商业/private overlay 逻辑。

## Decisions

### Decision: 按风险分批迁移，而不是一次性大重写

建议迁移顺序：

```text
Batch A: 已知崩溃和简单 selection
  - LocationSettingsScreen precision choice
  - bottom/customize navigation radio dialogs
  - Components checkbox dialog

Batch B: toolbar/template/shortcut 编辑类页面
  - MemoToolbarSettingsScreen custom dialog + icon group choice
  - ShortcutEditorScreen tag chips / checkbox list
  - TemplateSettingsScreen raw text fields/actions/dialogs

Batch C: AI 设置页面
  - AiServiceWizardScreen
  - AiServiceModelScreen
  - AiServiceDetailScreen
  - AiProviderSettingsScreen

Batch D: WebDAV / vault / account / storage / self repair
  - WebDavSyncScreen
  - VaultSecurityStatusScreen
  - AccountSecurityScreen
  - StorageSpaceScreen
  - SelfRepairScreen

Batch E: migration and remaining pages
  - memoflow migration sender/receiver/method/result
  - user/general/support/export/import pages
```

每个 batch 都应保持 scoped diff，并在完成后跑对应 focused tests。

### Decision: 迁移页面只使用 approved seams，不新增页面级 iOS wrapper

页面不应用以下方式“局部止血”：

- 在每个 `ChoiceChip` 外包 `Material`。
- 每个页面自己写 `if (iOS) Cupertino... else Material...`。
- 在 `PlatformListSection` iOS 分支全局包 `Material` 掩盖问题。

页面应改为：

```text
SettingsOptionChoiceRow / SettingsSingleChoiceRow / SettingsMultiChoiceRow
SettingsAction / PlatformPrimaryAction
showPlatformDialog / showPlatformAlertDialog / showPlatformPicker
buildPlatformPageRoute
PlatformProgress / SettingsLoadingRow / equivalent seam
```

### Decision: 复杂弹窗优先抽 content，presentation 走平台 seam

AI/WebDAV/模板/toolbar 这类复杂弹窗不需要一次拆成全新架构，但应至少做到：

- 弹窗 presentation 走 `showPlatformDialog` / `showPlatformAlertDialog` / `showPlatformPicker` 或 approved surface。
- 弹窗内容里使用 `PlatformTextField`、settings action、choice seam。
- 表单 validation 和 business mutation 留在原 owner，不迁到 platform 层。

### Decision: 路由统一走 `buildPlatformPageRoute`

设置子页面内直接 `MaterialPageRoute` 的地方，应改成 platform route seam，除非该 route 是明确 desktop-only Material task surface 且 design 记录例外。

### Decision: Guardrail 允许分阶段收缩

由于 `features/settings` 文件多、历史迁移多，guardrail 可以采用迁移清单：

- `migratedFiles`: 已完成平台化约束的文件。
- `legacyAllowlist`: 暂未迁移但已记录风险的文件。

每完成一个 batch，应把对应文件从 allowlist 移到 migrated list。对 migrated files，应阻止直接新增高风险 raw Material-only 控件。

## Risks / Trade-offs

- [Risk] `WebDavSyncScreen` 体量大，一次迁移容易引入业务回归。→ Mitigation: 分 batch，先替换 visible UI seam，不改 WebDAV 协议和 repository/service 语义。
- [Risk] 一些 raw Material 控件在 dialog 内目前不崩，迁移会带来视觉变化。→ Mitigation: 优先迁移 Apple mobile 高风险路径；低风险路径保持行为并通过 tests 验证。
- [Risk] iOS smoke tests 可能需要较多 provider overrides。→ Mitigation: 先建立页面级 smoke harness，对复杂页面使用 minimal fake state，避免集成真实网络/API。
- [Risk] touched area 是 coupled hotspot。→ Mitigation: 每个 batch 都把页面局部控件逻辑收敛到 settings/platform seam，并收紧 guardrail。

## Migration Plan

1. 确认 `platformize-settings-core-controls` 已提供 choice/multi-choice/action/dialog/feedback/progress seam。
2. 建立 settings subpage migration inventory，标记文件为 migrated / pending / deferred / exception。
3. 先修复 `LocationSettingsScreen` 已知崩溃路径，并补 iOS focused test。
4. 按 batch 迁移其他子页面，尽量保持每批 diff 小而可测。
5. 为每批添加或扩展 iOS smoke/focused tests。
6. 更新 guardrail allowlist/migrated list。
7. 运行 focused tests、`flutter analyze` 和按需要 `flutter test`。

Rollback: 若某个复杂页面迁移引入业务回归，应回退该页面的 batch，但保留已建立的 core seam 和 smoke test；不得删除对已知崩溃路径的测试。

## Open Questions

- `WebDavSyncScreen` 是否需要拆出更小的子组件再迁移。实现时如果单文件改动过大，应先做 UI-only component extraction。
- AI 向导是否应继续使用 Material `Stepper` 风格，还是通过 settings task surface 重构为多页/分段表单。此问题可在 AI batch 前单独确认。
