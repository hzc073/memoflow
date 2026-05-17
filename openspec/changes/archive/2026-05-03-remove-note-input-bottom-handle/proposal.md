## Why

Issue #175 反馈在 Android 设备点击 `+` 打开输入面板后，输入法上方会出现一个非预期横条，并且键盘弹起过程中有明显停顿感。经确认，该横条不是设计意图，而是早期 AI 截图还原界面时遗留的视觉元素；本变更选择确定性修复，先移除该遗留元素，避免继续误导用户。

## What Changes

- 移除 `NoteInputSheet` 底部靠近输入法区域的遗留 `130x6` 横条。
- 保留输入面板顶部的短 drag handle，继续提供面板形态提示。
- 不重构 keyboard inset 动画、不改变输入面板打开方式、不改变编辑器、toolbar、语音按钮、附件、草稿或提交逻辑。
- 限定为 UI visual cleanup，避免引入新的跨层依赖或行为分支。

## Capabilities

### New Capabilities
- `note-input-sheet`: 定义移动端 memo 输入面板的基础视觉契约，尤其是输入法弹出时不得显示非设计意图的底部横条。

### Modified Capabilities
- None.

## Impact

- Affected code: `memos_flutter_app/lib/features/memos/note_input_sheet.dart`
- Affected behavior: Android `NoteInputSheet` 打开并触发键盘时，输入法上方不再出现额外横条。
- APIs/dependencies: 无 API、数据模型、Riverpod provider、同步、存储或第三方依赖变化。
- Architecture phase: 当前为 `evolve_modularity`，本变更只触及 `features/memos` 内部 widget 视觉结构，不触及 critical checklist `1-4` 的已知 coupling hotspots；触及 checklist `10`，实现时必须保持该区域结构不变或更清晰，不新增 reverse dependency、shared domain logic 或商业逻辑。
