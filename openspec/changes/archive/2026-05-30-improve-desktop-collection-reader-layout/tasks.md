## 1. 布局策略与偏好模型

- [x] 1.1 新增 `CollectionReaderContentWidthMode` 或等价枚举，定义窄、标准、宽、跟随窗口四档内容宽度。
- [x] 1.2 将内容宽度偏好接入 `CollectionReaderPreferences` 或 `CollectionReaderDisplayConfig`，补齐 `toJson`、`fromJson`、`copyWith` 和默认值。
- [x] 1.3 新增 feature-local `collection_reader_layout_policy.dart` 或等价 helper，统一计算桌面版心宽度、可读视口、水平留白、顶部 chrome inset 和控制区宽度。
- [x] 1.4 为 layout policy 增加 unit tests，覆盖桌面宽屏、桌面窄窗口、移动端、`full` 跟随窗口和 macOS 标题栏安全区。

## 2. 第一阶段：桌面正文版心

- [x] 2.1 在 `CollectionReaderShell` 接入 layout policy，使背景、遮罩和菜单拦截层继续全窗口铺满。
- [x] 2.2 调整 `CollectionReaderVerticalView` 使用居中的可读内容宽度，确保 memo、RSS HTML、图片和章节分隔线与版心对齐。
- [x] 2.3 保持移动端和窄窗口现有宽度行为，避免桌面版心规则让手机正文异常变窄。
- [x] 2.4 补充 widget tests，验证桌面宽屏正文居中收窄、窄窗口无横向溢出、移动端保持可用宽度。

## 3. 第二阶段：分页模式一致性

- [x] 3.1 调整 `CollectionReaderPageEngine` 调用路径，使分页计算使用版心后的可读宽度和扣除 chrome 后的可读高度。
- [x] 3.2 调整 `CollectionReaderPagedView` 渲染和交互，使点击、拖拽 preview、滚轮、键盘翻页使用可见分页内容边界。
- [x] 3.3 检查并更新分页 cache key，确保内容宽度变化会触发重新分页，不复用旧宽度缓存。
- [x] 3.4 补充分页 engine 和 paged view tests，验证同一宽度设置下页数、渲染宽度和交互区域一致。

## 4. 第三阶段：用户设置与文案

- [x] 4.1 在合集阅读样式或更多设置中加入内容宽度控制，使用易懂中文文案展示窄、标准、宽、跟随窗口。
- [x] 4.2 补齐 `strings*.i18n.yaml` 相关文案，并运行项目既有本地化生成或验证流程。
- [x] 4.3 增加偏好序列化/反序列化测试，验证旧偏好缺少内容宽度字段时默认使用标准宽度。
- [x] 4.4 验证用户修改内容宽度后，纵向阅读和分页阅读都会立即按新宽度重新布局。

## 5. 第四阶段：提示栏、控制栏与交互区域

- [x] 5.1 调整页眉/页脚提示栏，使桌面宽屏下与阅读版心对齐或使用受控最大宽度。
- [x] 5.2 调整底部控制栏、进度条和浮动操作区，使其在桌面宽屏下居中且不被推到窗口边缘。
- [x] 5.3 确认 macOS 下正文、菜单首个交互控件、提示栏和底部控制不会进入系统按钮区域。
- [x] 5.4 补充 overlay/tip bar widget tests，覆盖宽屏对齐、控制栏可达和 macOS titlebar safe-area。

## 6. 架构守护与验证

- [x] 6.1 增加或更新 architecture guardrail，防止 reader 布局重新硬编码 `kMacosTrafficLightReservedWidth` 或绕开共享 chrome safe-area seam。
- [x] 6.2 增加 guardrail 或 focused test，确认 layout policy 不引入 `state -> features`、`application -> features` 或 `core -> features` 新反向依赖。
- [x] 6.3 运行 focused tests：`flutter test test/features/collections/...` 中的 reader layout、page engine、paged view、overlay 相关测试。
- [x] 6.4 运行 `flutter analyze`、相关 architecture guardrail tests、`openspec validate improve-desktop-collection-reader-layout --strict` 和 `git diff --check`。
- [x] 6.5 进行桌面手动验证：macOS、Windows、Linux 宽屏窗口下分别检查纵向阅读、分页阅读、内容宽度切换、菜单唤醒、提示栏和底部控制布局。
