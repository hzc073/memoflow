## Context

Collections 已经采用统一 presenter 模式：

```text
parent entry
    |
    v
openCollectionEditor(...)
    |
    +-- desktop -> showPlatformSecondaryTaskSurface(...)
    |
    +-- mobile  -> Navigator.push(...)
```

这个模式把“任务怎么展示”集中到入口 helper 中，页面内容只负责表达任务本身。Settings 中的 `ShortcutEditorScreen` 和 `AiServiceWizardScreen` 还没有采用这个模式，仍然由多个入口直接 push 页面。

## Goals / Non-Goals

**Goals:**

- 让快捷方式编辑和 AI 服务新增向导在桌面端使用共享任务表面。
- 保持移动端原有页面导航体验。
- 让调用方只使用 `openShortcutEditor(...)` / `openAiServiceWizard(...)` 这类语义入口。
- 增加防回退检查，避免迁移后又出现直接 push 旧页面的写法。
- 保持 `PlatformSecondaryTaskSurface` 位于 platform/shared UI seam，不让它依赖 settings、memos、state、data 或 API。

**Non-Goals:**

- 不迁移 `AiServiceDetailScreen`，它由第二阶段 change 处理。
- 不迁移 `AiProxySettingsScreen`。AI 向导里打开代理设置的入口先保留现状。
- 不把所有 settings 二级页面一次性改成任务弹窗。
- 不改变快捷方式保存、AI 服务创建、AI 设置持久化的业务语义。
- 不修改 API、数据库 schema、同步协议或商业/private overlay 行为。

## Decisions

### 1. 采用 presenter 入口，而不是让父页面决定桌面弹窗

每个被迁移的任务流程应提供一个语义入口：

```text
openShortcutEditor(...)
openAiServiceWizard(...)
```

调用方不需要知道桌面端是不是弹窗，也不应该自己判断 macOS、Windows 或 Linux。入口内部根据 `shouldUsePlatformSecondaryTaskSurface(context)` 选择桌面任务表面或移动端 route。

这样可以减少重复判断，也让 guardrail 更容易识别：迁移后的调用方应使用入口 helper，而不是直接构造页面并 push。

### 2. 快捷方式编辑先迁移

`ShortcutEditorScreen` 是最清晰的任务型二级流程：输入名称和筛选条件，完成后返回 `ShortcutEditorResult`，取消则返回 null。桌面端使用任务表面不会改变结果传递方式。

迁移时应保留标签选择、日期选择等内部临时弹层的现有行为。它们是任务内部的小选择器，不需要在本 change 中一起改造。

### 3. AI 服务新增向导同批迁移

`AiServiceWizardScreen` 是新增服务任务。桌面端迁移到任务表面后，向导主体仍然可以保持 Stepper 和现有创建逻辑。保存成功后关闭任务表面并返回父页面。

AI 向导内的代理设置入口先不迁移。用户确认采用方案 C：先保持原状，避免本 change 同时处理嵌套设置页。

```text
AI 服务新增任务表面
    |
    +-- 打开代理设置：保持现有页面打开方式，后续单独评估
```

### 4. 不在第一阶段处理 AI 服务详情

`AiServiceDetailScreen` 比向导更复杂：它包含保存、删除、连接检查、模型管理、代理设置跳转和未来的未保存确认。把它放进第一阶段会扩大风险。

第二阶段 change `migrate-ai-service-detail-task-surface` 专门处理它，并允许新增未保存确认弹窗。

### 5. 增加防回退检查

迁移完成后，应增加 guardrail 或 focused test，检查：

- `shortcuts_settings_screen.dart` 和 `memos_list_route_delegate.dart` 使用 `openShortcutEditor(...)`。
- `ai_settings_screen.dart` 使用 `openAiServiceWizard(...)`。
- 已迁移入口不再直接 push `ShortcutEditorScreen` 或 `AiServiceWizardScreen`。
- 已迁移页面不手写 macOS traffic-light padding。

这个检查的目的不是替代人工 review，而是防止以后无意中把桌面端任务流程写回旧的完整页面模式。

## Risks / Trade-offs

- [Risk] `ShortcutEditorScreen` 的内部标签选择仍使用 Windows adaptive surface 和 bottom sheet，桌面体验可能不完全统一。
  Mitigation: 本 change 只迁移外层任务边界，内部选择器作为后续 surface 泛化候选。

- [Risk] `AiServiceWizardScreen` 里的代理设置入口从任务表面内打开完整页面，交互上可能显得跳出任务。
  Mitigation: 这是用户确认的方案 C；在本 change 中记录为后续评估，不扩大当前实现范围。

- [Risk] guardrail 过强会阻止测试中直接渲染页面。
  Mitigation: guardrail 只约束生产入口文件，不禁止 widget tests 直接 `home: const AiServiceWizardScreen()`。

- [Risk] settings 与 `generalize-desktop-settings-platform-sections` 同时修改 guardrail，可能产生冲突。
  Mitigation: 本 change 只增加二级任务表面防回退检查，不做桌面设置入口命名或 settings section 改造。

## Migration Plan

1. 新增 `openShortcutEditor(...)`，桌面端使用 `showPlatformSecondaryTaskSurface`，移动端保留 route。
2. 让 `ShortcutEditorScreen` 支持嵌入 `PlatformSecondaryTaskFrame`，保留原页面模式用于移动端。
3. 更新快捷方式设置页和 memo 标题菜单的快捷方式创建入口。
4. 新增 `openAiServiceWizard(...)`，桌面端使用 `showPlatformSecondaryTaskSurface`，移动端保留 route。
5. 让 `AiServiceWizardScreen` 支持嵌入 `PlatformSecondaryTaskFrame`，代理设置入口保持现状。
6. 更新 `AiSettingsScreen` 添加服务入口。
7. 增加 focused widget tests 和防回退 guardrail。
8. 运行 focused tests、`flutter analyze`、相关 architecture guardrails 和 `openspec validate`。

## Open Questions

- AI 服务新增任务表面的默认宽度是否沿用 `large`，还是因为 Stepper 内容较多需要显式 `maxWidth`。
- 快捷方式编辑的内部标签选择器是否在后续单独泛化为 `PlatformSecondaryTaskSurface`，还是保留当前 Windows adaptive surface。
