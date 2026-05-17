## Context

`NoteInputSheet` 通过 `showModalBottomSheet` 以透明背景展示自定义输入面板，并在 `TextField` autofocus 后由 `MediaQuery.viewInsetsOf(context).bottom` 将面板顶到输入法上方。当前面板内部存在两个 handle-like visual elements：

```text
NoteInputSheet
├─ top drag handle: 40x6，位于 sheet 顶部，保留
├─ editor / attachments / toolbar / voice-send button
└─ bottom legacy handle: 130x6，位于 sheet 底部，移除
```

Issue #175 中截图显示的输入法上方横条，与底部 `130x6` legacy handle 的位置、尺寸和颜色一致。用户已确认该元素不是设计意图，而是早期界面截图还原时遗留。

当前架构阶段为 `evolve_modularity`。本变更只触及 `features/memos/note_input_sheet.dart` 内部 widget tree，不改变 provider、repository、application service、core utility 或 feature boundary。

依赖方向：

```text
Before:
features/memos/note_input_sheet.dart
  └─ renders extra bottom visual chrome

After:
features/memos/note_input_sheet.dart
  └─ renders only intentional sheet chrome
```

本变更不触及已知 critical coupling hotspots：

- 不新增或修改 `state -> features` reverse dependency。
- 不新增或修改 `application -> features` reverse dependency。
- 不新增或修改 `core -> state|application|features` upward dependency。
- 不移动或新增 shared domain logic 到 screen/widget 文件。

因此不做 seam extraction 或 guardrail 扩展；modularity preservation 的策略是保持改动局限在现有 feature widget 内，并避免新增 import、状态、业务判断或跨层抽象。

## Goals / Non-Goals

**Goals:**

- 删除输入面板底部非设计意图的横条。
- 保留顶部短 drag handle，维持用户对 bottom sheet 形态的感知。
- 保持 `NoteInputSheet` 的编辑、toolbar、附件、草稿、定位、语音/发送按钮和提交逻辑不变。
- 保持变更足够小，以便快速验证 issue #175 的确定性视觉问题。

**Non-Goals:**

- 不重构 keyboard transition、IME animation 或 `viewInsets` 处理。
- 不改变 `showModalBottomSheet` 的 route、barrier、shape 或 dismiss 行为。
- 不引入新的 animation controller、layout coordinator 或 platform-specific workaround。
- 不修改 API、数据模型、同步、SQLite/WebDAV、Riverpod provider 或桌面端编辑器逻辑。

## Decisions

### Decision 1: 直接删除 bottom legacy handle，而不是隐藏或条件渲染

选择：删除 `NoteInputSheet` `Column` 尾部的 `Padding -> Container(width: 130, height: 6)`。

理由：

- 该元素已确认不是设计意图，没有保留为 feature flag 或 platform condition 的价值。
- 直接删除比 `if (false)`、透明色、尺寸归零或平台判断更清晰，避免未来误读。
- 上方 toolbar 本身已有 `EdgeInsets.fromLTRB(20, 10, 20, 18)`，删除底部横条后仍保留底部呼吸空间。

备选方案：

- **仅 Android 隐藏**：不采用，因为问题元素本身无设计价值，跨平台都不应显示。
- **改成更淡或更短**：不采用，因为这会继续保留非预期视觉元素。
- **同时平滑 keyboard inset 动画**：不纳入本次确定性修复，避免扩大范围和引入平台差异风险。

### Decision 2: 保留 top drag handle

选择：保留顶部 `40x6` handle。

理由：

- 顶部 handle 是 bottom sheet 常见视觉提示，位置不会漂浮在输入法上方。
- issue 描述聚焦“输入法上方多了一个横条”，不是顶部 handle。
- 移除顶部 handle 会改变 sheet 视觉语言，超出确定性修复范围。

### Decision 3: 不新增测试专用 selector 或语义节点

选择：本次不为这个纯视觉元素新增 key、Semantics 或测试辅助结构。

理由：

- 被删除元素当前没有 key 或语义标签，新增测试 hook 反而会扩大实现面。
- 更合适的验证方式是静态检查删除目标 widget block，并在 Android 真机/模拟器进行视觉确认。

## Risks / Trade-offs

- [Risk] 删除底部横条后，输入面板底部视觉留白减少。→ Mitigation: 现有 toolbar row 仍有 `18` bottom padding；验证时确认按钮和 toolbar 未贴边。
- [Risk] 用户感知到的“停顿感”可能部分来自 keyboard inset 更新节奏，删除横条不能完全消除所有动画停顿。→ Mitigation: 本变更明确只做确定性视觉修复；若仍有停顿反馈，后续单独创建 keyboard transition change。
- [Risk] 视觉回归不容易被单元测试捕获。→ Mitigation: 任务中加入 Android 打开输入面板的手工/截图验证，并运行 `flutter analyze` 确认删除后代码结构合法。
- [Risk] 误删顶部 handle。→ Mitigation: 实现时只删除底部 `130x6` block，保留顶部 `40x6` block。
