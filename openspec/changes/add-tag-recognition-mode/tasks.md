## 1. 核心标签识别 seam

- [ ] 1.1 在 `lib/core/tags.dart` 增加 `TagRecognitionMode`、storage parse/label 所需的纯逻辑，并保持 lower-layer 无 UI/import 依赖。
- [ ] 1.2 将现有严格标签区提取保留为 `memoflowStrict`，新增 `memosCompatible` 全文 Markdown-aware inline tag 提取，覆盖正文、列表、句末标点、中文、emoji、层级 tag 和数字 tag。
- [ ] 1.3 抽出 `deriveVisibleMemoTags` 或等价 shared seam，统一处理 `content`、remote/provided tags 和 active mode 的本地可见 tag set。
- [ ] 1.4 更新 tag decoration 预处理接口，使 `memoflowStrict` 只装饰严格标签区，`memosCompatible` 装饰普通 Markdown text inline tags，并避开 code/link/URL 等保护上下文。

## 2. 工作区偏好与设置 UI

- [ ] 2.1 在 `WorkspacePreferences`、workspace preferences provider 和相关 model tests 中加入 `tagRecognitionMode`，实现新默认 `memosCompatible` 与旧 JSON 缺字段解析为 `memoflowStrict`。
- [ ] 2.2 在 preferences settings page 增加“标签识别规则”单选设置，保存到 `currentWorkspacePreferencesProvider`。
- [ ] 2.3 在该设置标题旁增加 tip 图标按钮；点击后展示居中说明弹窗，包含两种模式说明和 `今天记录 #生活`、`#生活\n\n今天记录`、`今天记录\n\n#生活` 等示例。
- [ ] 2.4 更新 i18n YAML 与 generated strings，确保新增设置 label、mode label、tip dialog、重算提示在现有语言体系中可访问。

## 3. 写入、同步、搜索与维护路径

- [ ] 3.1 替换 memo create/edit、quick input、share save、import、timeline restore、attachment append 等路径中的裸 `extractTags(content)`，改用 active mode-aware shared seam。
- [ ] 3.2 更新 remote sync tag merge/equivalence：`memosCompatible` 可合并远端 tags；`memoflowStrict` 以严格正文派生结果作为本地可见 tag 权威。
- [ ] 3.3 更新 memo search、AI search 和 search-document fallback，使 tag filter 和 searchable tag metadata 使用 active mode 的 app-visible tags。
- [ ] 3.4 扩展 self-repair maintenance：`rebuildMemoTagsFromContent(mode)` 按当前模式重算 `memo_tags`/`memos.tags`，并保持 orphan pruning、search rebuild、stats rebuild 的安全维护 owner。
- [ ] 3.5 在偏好切换后弹出重算确认；确认时通过 maintenance seam 运行 mode-aware tag rebuild、orphan prune、search rebuild、stats rebuild，取消时只保留偏好变化。
- [ ] 3.6 更新 memo tag autocomplete helper，使兼容模式保留 inline query 建议，严格模式只在可成为严格标签区前缀的位置显示建议。

## 4. Modularity guardrails

- [ ] 4.1 增加或更新 focused guardrail，禁止 feature screen/widget 重新实现 mode-specific tag parsing，确保 lower layers 不新增 `features/memos` 或 `features/settings` UI imports。
- [ ] 4.2 检查并收敛裸 `extractTags(content)` 调用，保留的调用必须是 core tests、显式 mode 参数调用或有注释说明的低层 helper。
- [ ] 4.3 确认本变更未触碰 `memos_flutter_app/lib/data/api` request/response models、route adapters 或 server-version compatibility logic。

## 5. 测试与验证

- [ ] 5.1 扩展 `test/core/tags_test.dart`，覆盖两种 mode、Memos-compatible inline cases、strict zone cases 和 protected Markdown contexts。
- [ ] 5.2 增加 workspace preference tests，覆盖默认、旧 JSON migration、round-trip 和 invalid value fallback。
- [ ] 5.3 增加 data/self-repair tests，覆盖 mode-aware tag rebuild、strict 移除 inline-only derived tags、compatible 保留 inline tags、orphan pruning。
- [ ] 5.4 增加 search/AI-search focused tests，覆盖 tag filter 在两种 mode 下的不同可见结果。
- [ ] 5.5 增加 settings UI/widget tests，覆盖 mode row、tip dialog、mode switch recompute confirmation 和取消行为。
- [ ] 5.6 增加 autocomplete focused tests，覆盖兼容模式 inline suggestions、严格模式正文不提示、严格模式标签区提示。
- [ ] 5.7 在 `memos_flutter_app` 运行 `dart run build_runner build --delete-conflicting-outputs`、`flutter analyze`、`flutter test`；若时间受限，至少运行受影响 focused tests 并记录未跑的全量验证。
