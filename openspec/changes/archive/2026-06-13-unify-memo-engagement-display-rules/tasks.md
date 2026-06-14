## 1. 规则与命名确认

- [x] 1.1 确认本 change 只改变 memo 点赞/评论展示 gate、设置文案、runtime 命名和 tests/guardrails，不实现 local comments/reactions。
- [x] 1.2 确认本地库模式语义为 unsupported：不展示、不挂载 `MemoEngagementSurface`、不触发 reactions/comments loading。
- [x] 1.3 确认服务端工作区中一个偏好开关统一控制 home cards、desktop preview pane、memo detail、desktop reader surface、explore/notification read-only detail 等所有支持 engagement 的 surface。
- [x] 1.4 确认不修改 `memos_flutter_app/lib/data/api`、`memos_flutter_app/test/data/api`、API route adapters、request/response models、server compatibility 或 SSE protocol。

## 2. Preference / resolved gate

- [x] 2.1 在 workspace preference/runtime seam 中引入或收敛到 `showMemoEngagement` 语义，保留旧 `showEngagementInAllMemoDetails` storage compatibility。
- [x] 2.2 增加 `effectiveShowMemoEngagement`、`canShowMemoEngagement` 或等价 resolved gate，语义为 remote account + 非本地库 + preference enabled。
- [x] 2.3 确保本地库模式下设置页隐藏或禁用该开关；若禁用，文案 SHALL 明确本地工作区不支持点赞与评论展示。
- [x] 2.4 更新用户可见文案为“显示点赞与评论”及各 locale 对应翻译，并调整 i18n tests。

## 3. Memo surfaces 接入

- [x] 3.1 更新 home memo cards，使其继续通过统一 resolved gate 控制 compact engagement surface。
- [x] 3.2 更新 desktop preview pane，移除 `shouldShowEngagement: true` 硬编码，改为统一 resolved gate。
- [x] 3.3 更新 `MemoDetailScreen`，移除 `widget.showEngagement || preference` 绕过语义；surface 只能表达 support，最终由 resolved gate 决定。
- [x] 3.4 更新 desktop reader surface，移除 `showEngagement: true` 强制显示语义，确保未来打开 supplementary sections 时仍尊重统一 gate。
- [x] 3.5 更新 explore/notification read-only detail 入口，不再通过 `showEngagement: true` 绕过偏好。
- [x] 3.6 确认本地库模式下所有上述入口均不挂载 `MemoEngagementSurface`，且不会触发 engagement provider load。

## 4. Guardrail / tests

- [x] 4.1 增加或更新 widget tests：服务端工作区偏好关闭时，home card、desktop preview pane、memo detail 均隐藏 engagement。
- [x] 4.2 增加或更新 widget tests：服务端工作区偏好开启时，支持 engagement 的 surfaces 展示点赞/评论。
- [x] 4.3 增加本地库模式 tests：即使旧入口曾经传入 force flag，也不挂载 `MemoEngagementSurface`，fake engagement client load count 保持 0。
- [x] 4.4 更新 i18n tests，断言设置名称不再限定 home cards / memo details，而是统一表达“显示点赞与评论”。
- [x] 4.5 增加或收紧 architecture guardrail，阻止 `shouldShowEngagement: true`、`showEngagement: true`、`widget.showEngagement ||` 等绕过统一 gate 的模式回流。

## 5. 验证与收尾

- [x] 5.1 从 `memos_flutter_app` 运行 `dart format` 覆盖所有修改过的 Dart 文件。
- [x] 5.2 从 `memos_flutter_app` 运行 focused tests：memo engagement surface/detail/desktop preview/home card/i18n/architecture guardrail tests。
- [x] 5.3 从 `memos_flutter_app` 运行 `flutter analyze`。
- [x] 5.4 从 `memos_flutter_app` 运行 `flutter test`；如环境或既有失败阻塞，记录具体命令、失败用例和剩余风险。
- [x] 5.5 人工检查本地库与服务端工作区设置页：本地库不会让用户误以为可启用点赞/评论，服务端工作区开关能统一控制所有展示位置。
