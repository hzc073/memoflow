## Context

合集连续阅读器目前同时承担 smart/manual collection 和 RSS continuous reader 的正文展示。移动端阅读区天然较窄，体验问题不明显；桌面宽屏下，纵向阅读和分页阅读会使用接近整窗的内容宽度，造成行长过长、眼动距离过大，也让提示栏、控制栏和交互区域显得分散。

前一个桌面二级页面 change 已经引入共享的窗口 chrome safe-area seam，并补充了阅读页正文避开 macOS 系统按钮的处理。本 change 应继续复用这个 seam，但重点不是隐藏系统按钮或改变窗口管理，而是定义“桌面阅读版心”：背景铺满窗口，正文、分页、提示栏和关键控制围绕一个适合阅读的中心宽度组织。

当前架构阶段为 `evolve_modularity`。本 change 触及 `features/collections` 内的阅读器布局、分页计算和偏好模型，不应新增 `state -> features`、`application -> features`、`core -> state|application|features` 依赖。布局规则应从大型 screen/widget 中抽出为 feature-local pure helper，减少共享阅读规则继续散落在 UI 文件中的风险。

## Goals / Non-Goals

**Goals:**

- 桌面端为合集连续阅读器提供居中的阅读版心，默认正文宽度适合长文阅读。
- 纵向阅读、分页阅读、分页测量、提示栏和主要控制区域使用一致的版心约束。
- 增加可理解的内容宽度设置，使用户能选择窄、标准、宽或跟随窗口。
- 保持移动端现有阅读体验，不因为桌面宽屏优化导致手机内容变窄。
- 通过 focused tests 和 guardrail 确保分页计算、macOS 标题栏安全区和桌面版心不会再次分叉。

**Non-Goals:**

- 不重新设计 RSS article-flow reader 的双栏布局。
- 不隐藏 macOS 原生红黄绿窗口按钮，不改变主窗口 titlebar style。
- 不更改 Memos API、数据库同步协议、RSS 抓取逻辑或 memo mutation 语义。
- 不引入新的外部依赖、商业逻辑、订阅/付费/entitlement/StoreKit 代码。
- 不把阅读正文做成浮动卡片；阅读体验应保持全屏背景和沉浸感。

## Decisions

### 1. 使用 feature-local layout policy 表达桌面阅读版心

新增或抽取 `collection_reader_layout_policy.dart` 一类 pure helper，负责根据 `TargetPlatform`、viewport size、用户选择的 content width mode、window chrome insets 计算：

- `contentMaxWidth`
- `readableViewportSize`
- `horizontalGutter`
- `topChromeInset`
- 控制栏和提示栏应使用的最大宽度

理由：当前阅读器规则分散在 `CollectionReaderShell`、`CollectionReaderVerticalView`、`CollectionReaderPagedView` 和 `CollectionReaderPageEngine` 中。抽成 feature-local pure helper 可以让纵向、分页和测试复用同一套计算，并符合 `evolve_modularity` 下“触碰区域保持或改善结构”的要求。

备选方案：

- 直接在 `CollectionReaderShell` 里写宽度判断。实现最快，但会让分页、纵向和控制栏继续各自推导布局。
- 把 policy 放到 `core/desktop`。当前规则是合集阅读器特有，不需要让 `core` 了解 feature 语义，放到 feature-local helper 更稳。

依赖方向：

- Before：阅读宽度和视口规则主要隐含在 feature widget 中。
- After：`features/collections` 内部由 pure helper 统一输出布局约束；`state`、`application`、`core` 不导入 collection reader UI。

### 2. 桌面版心默认收窄，移动端继续跟随窗口

桌面端默认使用 `standard` 内容宽度，建议初始最大正文宽度在约 `760-860px` 区间；`narrow` 可更适合专注阅读，`wide` 给代码块、图片或宽内容更多空间，`full` 保留现在接近跟随窗口的行为。移动端和窄窗口应自动退化为可用宽度，避免产生过窄正文。

理由：用户反馈的痛点来自桌面宽屏拉伸，不应把移动端或小窗口也强制居中窄列。

备选方案：

- 只硬编码一个最大宽度。简单但不可调，后续用户偏好差异会很快出现。
- 默认完全跟随窗口，只提供设置。不能解决当前默认体验问题。

### 3. 分页模式必须使用版心后的可读视口重新测量

分页阅读不能只在渲染层居中；`CollectionReaderPageEngine` 的 `viewportSize` 也必须接收版心后的可读宽度和扣除标题栏后的可读高度。`CollectionReaderPagedView` 的点按区域、拖拽 preview 和动画 surface 同样使用该可读视口，避免页数、截断和交互命中区域不一致。

理由：分页内容是否截断、页数是否准确取决于测量宽高。只做视觉居中会产生“显示宽度变了但分页仍按整窗计算”的错误。

备选方案：

- 分页模式不套版心。两种阅读模式会明显割裂。
- 分页只限制渲染宽度。存在页数和内容截断风险。

### 4. 提示栏和控制栏跟随版心，但背景和遮罩仍铺满

顶部/底部提示栏、底部控制栏、进度条和浮动操作区应在桌面宽屏下与阅读版心对齐或使用略宽于正文的最大宽度；遮罩、背景色、背景图、亮度遮罩仍全窗口铺满。

理由：用户需要的是阅读内容不被拉伸，而不是把整个阅读页面变成卡片。控制区过宽也会增加视线移动成本，但全窗口背景有助于保持沉浸感。

备选方案：

- 所有 overlay 控件继续全宽。实现简单，但桌面宽屏下操作分散。
- 把正文和控件包成浮动卡片。不符合当前阅读器沉浸式体验。

### 5. 内容宽度设置进入现有 reader preferences

在 `CollectionReaderDisplayConfig` 或相邻 reader preference model 中加入内容宽度设置，例如 `CollectionReaderContentWidthMode`。序列化通过既有 JSON 偏好字段完成，并在 `PreferencesMigrationService` 或现有偏好读取默认逻辑中保证旧用户得到 `standard` 默认值。

理由：这是阅读显示偏好，不需要服务器参与，也不应进入 API 或同步协议改动。

备选方案：

- 只存在内存中，不持久化。用户每次打开都要重新调整。
- 作为全局设置散落在别的 settings provider。会扩大影响范围，不符合本 change 的合集阅读器边界。

## Risks / Trade-offs

- [Risk] 桌面默认收窄后，包含宽代码块、表格或大图的内容可能需要横向处理。
  Mitigation：提供 `wide` 和 `full` 模式；检查 RSS HTML、markdown code/table/image 的溢出和滚动行为。

- [Risk] 分页测量宽度变化会改变已保存阅读进度对应的页号。
  Mitigation：继续优先使用 memo uid、章节索引、搜索命中 offset 等已有恢复逻辑；内容宽度改变后允许重新分页并夹紧页号。

- [Risk] 纵向阅读下移和桌面版心叠加后，macOS 顶部安全区可能被重复计算。
  Mitigation：layout policy 统一输出 `readableViewportSize` 和 `topChromeInset`，测试覆盖 macOS 下第一行正文位置。

- [Risk] 偏好模型新增字段可能影响旧 JSON 读取。
  Mitigation：新增字段必须有默认值和 fromJson fallback；补充序列化/反序列化测试。

- [Risk] 把所有规则塞进 screen 文件会继续恶化可维护性。
  Mitigation：本 change 明确抽取 feature-local layout policy，并添加 guardrail 或 focused unit tests 验证 policy 独立可测。

## Migration Plan

1. 新增 `CollectionReaderContentWidthMode` 和布局 policy，先用 unit tests 锁定桌面/移动/窄窗口输出。
2. 在 `CollectionReaderShell` 中接入 policy，背景保持全窗口，阅读正文使用居中可读区域。
3. 调整纵向阅读和分页阅读，使两者都接收版心后的可读宽度；同步更新分页引擎调用和缓存 key。
4. 在样式/更多设置中加入内容宽度控制，并补齐中文文案。
5. 调整提示栏、底部控制栏、进度条和翻页交互区域，让桌面宽屏下与阅读版心协调。
6. 补充 widget tests、分页 engine tests、偏好 JSON tests、桌面 guardrail。
7. 运行 `flutter analyze`、focused tests、architecture guardrails、`openspec validate`。

Rollback 策略：若桌面版心上线后出现严重分页或内容溢出问题，可将默认内容宽度模式临时切回 `full`，保留设置项和 policy 以便继续修复。

## Open Questions

- 四档内容宽度的最终像素值是否需要根据用户实际设备微调；实现时可先采用保守默认并通过测试保证行为范围。
- 底部控制栏是严格等宽跟随正文，还是允许略宽以容纳更多按钮；实现时应以不分散、不拥挤为原则。
