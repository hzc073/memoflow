## 1. 建立 macOS 设置窗口运行时支持

- [x] 1.1 在 `macos/Runner/MainFlutterWindow.swift` 为 `desktop_multi_window` 的子窗口创建添加必要插件注册 hook，确保 settings 子窗口 engine 可用
- [x] 1.2 校准 settings 子窗口所需的最小插件清单，避免重复注册主窗口 multi-window 绑定或引入不稳定插件
- [x] 1.3 让 macOS settings 子窗口通过健康检查/响应检查后再视为可用

## 2. 统一设置打开 seam 与失败回退

- [x] 2.1 将桌面设置窗口打开逻辑改为可观测结果，区分 unsupported、opened、failed 三种状态
- [x] 2.2 让 macOS、Windows、Linux 的设置入口共享同一个打开判断流程，避免 fire-and-forget 误判成功
- [x] 2.3 在设置窗口不可用或打开失败时，统一回退到可见的主窗口 `SettingsScreen`

## 3. 收敛所有设置入口

- [x] 3.1 更新 `app.dart` 中 macOS 菜单的 Settings / Open Settings Window 处理逻辑，使其在失败时自动 fallback
- [x] 3.2 检查并统一主界面设置按钮、抽屉入口、托盘入口和其他 settings 入口的行为
- [x] 3.3 保持 `SettingsScreen` 作为可见 fallback，不新增 Apple 专属整套页面树

## 4. 增加边界测试与回归守卫

- [x] 4.1 为 macOS 设置入口添加测试，覆盖 settings window 成功、失败和 fallback 三种路径
- [x] 4.2 为 macOS Runner 的子窗口插件注册增加可验证的测试或守卫说明
- [x] 4.3 维持公共仓 Apple/macOS 设置代码的商业边界守卫，防止引入 StoreKit、paywall、receipt 或 entitlement 逻辑

## 5. 验证与收口

- [x] 5.1 运行 `flutter analyze` 和相关 focused tests，确认设置入口和 guardrail 通过
- [x] 5.2 记录 macOS 设置窗口的 smoke test 结果或已知限制，确认是否需要后续独立视觉微调
