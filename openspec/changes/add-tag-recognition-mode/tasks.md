## 1. 核心标签识别 policy seam

- [x] 1.1 在 `lib/core/tags.dart` 增加 `TagRecognitionPolicy`、预设、custom options、storage parse/label 所需的纯逻辑，并保持 lower-layer 无 UI/import 依赖。
- [x] 1.2 将现有严格标签区提取保留为 `memoflowStrict` 默认预设，新增 `memosCompatible` 全文 Markdown-aware inline tag 预设，覆盖正文、列表、句末标点、中文、emoji、层级 tag 和数字 tag。
- [x] 1.3 支持从受控 custom options 解析 resolved policy，初版至少覆盖 strict tag zones、ordinary inline body tags、numeric-only tags、hierarchical tags、emoji/symbol tags 和 remote tag handling。
- [x] 1.4 抽出 `deriveVisibleMemoTags` 或等价 shared seam，统一处理 `content`、remote/provided tags 和 active policy 的本地可见 tag set。
- [x] 1.5 更新 tag decoration 预处理接口，使 `memoflowStrict` 只装饰严格标签区，`memosCompatible` 装饰普通 Markdown text inline tags，`custom` 跟随 resolved options，并避开 code/link/URL 等保护上下文。

## 2. 工作区偏好与设置 UI

- [x] 2.1 在 `WorkspacePreferences`、workspace preferences provider 和相关 model tests 中加入 `tagRecognitionPolicy`，实现新默认与旧 JSON 缺字段均解析为 `memoflowStrict`。
- [x] 2.2 在 preferences settings page 增加“标签识别规则”设置，提供 `MemoFlow strict`、`Memos compatible`、`Custom` 选择并保存到 `currentWorkspacePreferencesProvider`。
- [x] 2.3 在该设置标题旁增加 tip 图标按钮；点击后展示居中说明弹窗，包含预设和 custom 说明，以及 `今天记录 #生活`、`#生活\n\n今天记录`、`今天记录\n\n#生活` 等示例。
- [x] 2.4 增加 custom policy 设置 UI；每个可组合选项后都有 info 弹窗入口，说明该选项影响的识别位置、示例和适用习惯；通用渲染/autocomplete/search/self-repair 影响和重算提示集中在自定义设置顶部。
- [x] 2.5 更新 i18n YAML 与 generated strings，确保新增设置 label、policy label、custom option label、每个 custom option tip、总 tip dialog、重算提示在现有语言体系中可访问。
- [x] 2.6 确认首次连接 Memos、首次同步、导入 Memos 数据和第三方导入流程不会弹出切换到 `memosCompatible` 的提示，也不会静默改变当前 policy。

## 3. 写入、同步、搜索与维护路径

- [x] 3.1 替换 memo create/edit、quick input、share save、import、timeline restore、attachment append 等路径中的裸 `extractTags(content)`，改用 active policy-aware shared seam。
- [x] 3.2 更新 remote sync tag merge/equivalence：`memosCompatible` 可合并远端 tags；`memoflowStrict` 以严格正文派生结果作为本地可见 tag 权威；`custom` 跟随 remote tag handling option。
- [x] 3.3 更新 memo search、AI search 和 search-document fallback，使 tag filter 和 searchable tag metadata 使用 active policy 的 app-visible tags。
- [x] 3.4 扩展 self-repair maintenance：`rebuildMemoTagsFromContent(policy)` 按当前策略重算 `memo_tags`/`memos.tags`，并保持 orphan pruning、search rebuild、stats rebuild 的安全维护 owner。
- [x] 3.5 在偏好切换后弹出重算确认；确认时通过 maintenance seam 运行 policy-aware tag rebuild、orphan prune、search rebuild、stats rebuild，取消时只保留偏好变化。
- [x] 3.6 更新 memo tag autocomplete helper，使建议只在当前位置可成为 active policy 下的 app-visible tag 时显示。

## 4. Modularity guardrails

- [x] 4.1 增加或更新 focused guardrail，禁止 feature screen/widget 重新实现 policy-specific tag parsing，确保 lower layers 不新增 `features/memos` 或 `features/settings` UI imports。
- [x] 4.2 检查并收敛裸 `extractTags(content)` 调用，保留的调用必须是 core tests、显式 policy 参数调用或有注释说明的低层 helper。
- [x] 4.3 确认本变更未触碰 `memos_flutter_app/lib/data/api` request/response models、route adapters 或 server-version compatibility logic。

## 5. 测试与验证

- [x] 5.1 扩展 `test/core/tags_test.dart`，覆盖 `memoflowStrict`、`memosCompatible`、custom options、Memos-compatible inline cases、strict zone cases 和 protected Markdown contexts。
- [x] 5.2 增加 workspace preference tests，覆盖默认严格、旧 JSON migration、round-trip、custom option round-trip 和 invalid value fallback。
- [x] 5.3 增加 data/self-repair tests，覆盖 policy-aware tag rebuild、strict 移除 inline-only derived tags、compatible 保留 inline tags、custom option rebuild、orphan pruning。
- [x] 5.4 增加 search/AI-search focused tests，覆盖 tag filter 在 strict、compatible、custom policy 下的不同可见结果。
- [x] 5.5 增加 settings UI/widget tests，覆盖 policy row、总 tip dialog、custom option info dialogs、policy switch recompute confirmation、取消行为，以及导入/连接流程不提示切换兼容。
- [x] 5.6 增加 autocomplete focused tests，覆盖 compatible inline suggestions、strict 正文不提示、strict 标签区提示、custom option 控制提示资格。
- [x] 5.7 在 `memos_flutter_app` 运行 `dart run build_runner build --delete-conflicting-outputs`、`flutter analyze`、`flutter test`；若时间受限，至少运行受影响 focused tests 并记录未跑的全量验证。
