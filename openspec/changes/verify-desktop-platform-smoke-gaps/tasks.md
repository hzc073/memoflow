## 1. Source Transfer Records

- [x] 1.1 Record `fix-desktop-inline-compose-resize` manual smoke items as transferred here without claiming platform verification.
- [x] 1.2 Record `unify-settings-ui-platform-experience` manual review items as transferred here without claiming visual verification.
- [x] 1.3 Record `fix-desktop-settings-nested-navigation` manual review items as transferred here without claiming native window verification.
- [x] 1.4 Record `add-desktop-share-task-window` macOS runtime and manual smoke items as transferred here without claiming share-window runtime verification.
- [x] 1.5 Record `move-macos-quick-actions-to-titlebar` macOS titlebar smoke and screenshot items as transferred here without claiming traffic-light verification.

## 2. 内联编辑框尺寸调整冒烟验证

- [ ] 2.1 来源 `fix-desktop-inline-compose-resize`：在 Windows 桌面端打开首页“全部笔记”，在底部内联编辑框分别拖动右侧、底部、右下角三个调整手柄；通过标准：宽度、高度、宽高同时调整都跟随鼠标变化，页面没有闪烁、错位或卡死。
- [ ] 2.2 来源 `fix-desktop-inline-compose-resize`：在 Windows 桌面端先把内联编辑框调大或调小，再通过左侧导航切到任意其他页面，然后返回“全部笔记”继续拖动调整手柄；通过标准：返回后仍能继续调整尺寸，拖动区域位置正确。
- [ ] 2.3 来源 `fix-desktop-inline-compose-resize`：调整内联编辑框尺寸后，关闭并重新打开窗口，或触发一次页面重建后再回到“全部笔记”；通过标准：编辑框恢复到上次调整后的尺寸，而不是回到默认大小。
- [ ] 2.4 来源 `fix-desktop-inline-compose-resize`：在内联编辑框中输入草稿、添加一个附件预览，并打开右侧备忘录预览，再拖动调整编辑框尺寸；通过标准：草稿文字、附件预览、右侧预览内容都没有丢失，拖动结束后仍可继续编辑。
- [ ] 2.5 来源 `fix-desktop-inline-compose-resize`：如果当前版本在 macOS 也启用了内联编辑框尺寸调整，在 macOS 桌面端重复 2.1 到 2.4；通过标准：红黄绿窗口按钮没有被遮挡，标题栏可拖动，编辑框调整体验和 Windows 一致。

## 3. 设置页跨平台界面检查

- [ ] 3.1 来源 `unify-settings-ui-platform-experience`：把窗口调到手机宽度，分别打开“设置 > 偏好设置”和“设置 > 组件”；通过标准：两页标题栏、背景、分组样式和列表行高度一致，内容没有横向溢出或文字截断。
- [ ] 3.2 来源 `unify-settings-ui-platform-experience`：把窗口调到 iPad/平板宽度，分别打开“偏好设置”和“组件”；通过标准：两页内容宽度、左右边距、分组间距一致，没有一页像手机布局、另一页像桌面布局的割裂感。
- [ ] 3.3 来源 `unify-settings-ui-platform-experience`：在 macOS 桌面宽度下分别打开“偏好设置”和“组件”；通过标准：两页都使用相同的桌面页面宽度限制、标题栏样式和背景层级，红黄绿窗口按钮区域不被内容遮挡。
- [ ] 3.4 来源 `unify-settings-ui-platform-experience`：如果有 Windows 环境，在 Windows 桌面宽度下分别打开“偏好设置”和“组件”；通过标准：两页都使用相同的 Windows 桌面标题栏和页面宽度，右上角窗口按钮不被页面操作按钮挤压。
- [ ] 3.5 来源 `unify-settings-ui-platform-experience`：在浅色和深色模式下对比“偏好设置”和“组件”的标题栏、背景色、分组容器、列表行密度、开关大小与选中色、可点击行右侧箭头、桌面最大内容宽度；通过标准：这些视觉元素在两页之间一致，差异只来自具体设置项内容。
- [ ] 3.6 来源 `unify-settings-ui-platform-experience`：打开“偏好设置”和“组件”并来回切换；通过标准：“组件”不再像另一套独立卡片系统，卡片圆角、边距、阴影或分割线风格与“偏好设置”一致。
- [ ] 3.7 来源 `unify-settings-ui-platform-experience`：在两页各修改一个不会造成风险的开关或选项，再退出并重新进入设置页；通过标准：设置项仍能正常保存、恢复和响应点击，没有因为界面统一导致原功能失效。

## 4. 设置页二级导航检查

- [ ] 4.1 来源 `fix-desktop-settings-nested-navigation`：在 macOS 打开设置首页，进入“组件”，再进入任意一个组件详情页；通过标准：能从设置首页逐级进入详情页，没有空白页、重复标题栏或导航卡住。
- [ ] 4.2 来源 `fix-desktop-settings-nested-navigation`：停留在组件详情页查看页面顶部；通过标准：顶部显示“返回按钮 + 当前详情页标题”，标题能说明当前页面，不显示父页面标题。
- [ ] 4.3 来源 `fix-desktop-settings-nested-navigation`：在组件详情页观察左上角红黄绿窗口按钮和 App 返回按钮的位置；通过标准：返回按钮、页面标题、红黄绿窗口按钮互不重叠，点击区域不会互相覆盖。
- [ ] 4.4 来源 `fix-desktop-settings-nested-navigation`：在组件详情页点击 App 内的返回按钮；通过标准：返回到上一级“组件”页面，而不是关闭设置窗口或跳回设置首页。
- [ ] 4.5 来源 `fix-desktop-settings-nested-navigation`：在组件详情页点击 macOS 红色关闭按钮，或使用系统关闭窗口操作；通过标准：只关闭设置窗口，主窗口仍保留，应用没有崩溃。
- [ ] 4.6 来源 `fix-desktop-settings-nested-navigation`：完成 4.5 后重新打开设置；通过标准：设置从设置首页打开，不会自动停留在上次的组件详情页。
- [ ] 4.7 来源 `fix-desktop-settings-nested-navigation`：在桌面端打开一个全页分享相关页面，再进入它的二级页面；通过标准：二级页面同样使用“返回按钮 + 页面标题”，返回按钮回到分享父页面，不直接关闭整个流程。
- [ ] 4.8 来源 `fix-desktop-settings-nested-navigation`：在手机宽度和平板宽度分别打开已迁移的设置/分享相关页面并进入二级页面；通过标准：系统返回手势或返回按钮都按平台习惯返回上一级，没有桌面专用标题栏残留。

## 5. 分享任务子窗口运行时冒烟验证

- [ ] 5.1 来源 `add-desktop-share-task-window`：在 macOS 触发一次桌面分享入口，并观察是否创建独立分享子窗口；通过标准：子窗口能打开、能接收分享内容，主窗口和子窗口之间的数据传递正常，没有报错或无响应。
- [ ] 5.2 来源 `add-desktop-share-task-window`：在 macOS 分享子窗口中执行需要网页内容抓取的分享流程，例如通过 `ShareCaptureInAppWebViewEngine` 或当前替代实现抓取链接预览；通过标准：抓取流程能启动、加载、返回结果或明确错误提示，窗口不白屏不卡死。
- [ ] 5.3 来源 `add-desktop-share-task-window`：在 macOS 且分享子窗口能力开启时，向应用分享一段包含 URL 的文本；通过标准：打开的是分享任务子窗口，而不是直接占用主窗口。
- [ ] 5.4 来源 `add-desktop-share-task-window`：分享子窗口打开后，点击系统关闭按钮或按 `Cmd+W`；通过标准：只取消当前分享任务并关闭子窗口，主窗口仍然存在且可继续操作。
- [ ] 5.5 来源 `add-desktop-share-task-window`：在分享子窗口中完成一次保存、只保存链接或保存媒体的成功流程；通过标准：成功后分享子窗口关闭，主窗口回到前台，并打开现有的备忘录编辑器或对应写入入口。
- [ ] 5.6 来源 `add-desktop-share-task-window`：打开分享子窗口的根页面并检查页面顶部和底部；通过标准：根页面不显示 App 自己额外加的通用关闭/取消按钮，只使用系统窗口关闭或流程内必要操作。
- [ ] 5.7 来源 `add-desktop-share-task-window`：从分享子窗口进入一个内部二级页面，例如视频预览页；通过标准：二级页面的返回按钮能回到分享根页面，不会直接关闭子窗口或回到主窗口。
- [ ] 5.8 来源 `add-desktop-share-task-window`：在未开启分享子窗口能力的平台或配置下触发同样的分享流程；通过标准：应用回退到旧的主窗口分享流程，分享内容仍可继续处理。

## 6. macOS 标题栏和窗口按钮冒烟验证

- [ ] 6.1 来源 `move-macos-quick-actions-to-titlebar`：在 macOS 查看左上角红黄绿窗口按钮，分别悬停、点击最小化、点击缩放、切换窗口前后台；通过标准：按钮始终可见可点，悬停和非活跃窗口状态使用系统原生效果，没有被 App 内容覆盖。
- [ ] 6.2 来源 `move-macos-quick-actions-to-titlebar`：在 macOS 拖动标题栏空白区域移动窗口，并依次点击标题栏里的快捷筛选按钮、搜索按钮、排序按钮；通过标准：窗口拖动正常，每个标题栏操作都响应，关闭、最小化、缩放仍按系统行为执行。
- [ ] 6.3 来源 `move-macos-quick-actions-to-titlebar`：分别在浅色模式、深色模式、窗口非活跃状态截取标题栏截图；通过标准：标题栏内容不压到红黄绿按钮，不贴住窗口边缘，按钮、标题、搜索/排序操作之间留有清晰间距。
