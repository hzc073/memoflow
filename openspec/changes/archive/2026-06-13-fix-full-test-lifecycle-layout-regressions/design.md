## Context

当前失败链路可以拆成两个互不依赖的局部问题。

```text
App teardown
  └─ _AppState.dispose()
       └─ DesktopQuickInputController.unregisterHotKey()
            ├─ release system hotkey
            └─ write Riverpod status provider  <-- ref already disposed
```

`unregisterHotKey()` 同时承担“释放系统资源”和“更新运行时 UI 状态”两个职责。正常运行时两者都需要；但 widget dispose 阶段只能安全释放资源，不能再通过 disposed `WidgetRef` 写 provider。

```text
AboutScreen as drawer/home destination
  └─ AboutUsContent
       └─ Column(logo + version + 7 rows + debug text)
            └─ no scroll container in AboutScreen body
```

`AboutUsScreen` 通过 `SettingsPage` 获得 `ListView`，但 `AboutScreen` 直接复用 `AboutUsContent`。当它作为 bottom navigation shell 上方的 overlay route 或 standalone home fallback route 渲染时，内容高度超过可用 body 高度并触发 Flutter overflow。

## Decisions

### Decision: 分离 hotkey resource release 与 provider 状态写入

实现阶段应让 teardown path 只释放 `_desktopQuickInputHotKey` 和插件 hotkey，不再写 `desktopQuickRecordHotKeyRegistrationStatusProvider`。正常运行时的 unregister/register failure 仍应写 provider，使 feature-level fallback 能继续判断 system hotkey 是否 active。

可行形态：

```text
unregisterHotKey()
  └─ release + set provider unavailable

dispose()
  └─ release only, skip provider write
```

Alternatives considered:

- 在 `App.dispose` 外层捕获 Riverpod disposed exception：能让测试通过，但会隐藏生命周期边界，且异常仍可能在其他 teardown path 出现。
- 在 `_setQuickRecordHotKeyRegistrationStatus` 内吞掉所有错误：会让正常运行时 provider 写入失败也静默，降低诊断能力。
- 让 `App.dispose` 先调用 unregister 再关闭 ref 相关订阅：Flutter unmount/dispose 时 Riverpod 对 `ConsumerState.ref` 的可用性仍不适合作为资源释放依赖。

### Decision: About destination 自己提供滚动/宽度容器

`AboutUsContent` 继续作为纯内容组件，避免在 `AboutUsScreen` 的 `SettingsPage` 内形成嵌套滚动。`AboutScreen` 应在 destination body 中包裹 `ListView` 和 `PlatformBoundedContent` 或等效现有 seam，使内容在手机、桌面 fallback、bottom navigation overlay 约束下都可滚动。

Alternatives considered:

- 把 `AboutScreen` 改成直接嵌入 `AboutUsScreen`：会重复 app/page chrome，并改变 drawer destination shell 结构。
- 给 `AboutUsContent` 根节点改成 `SingleChildScrollView`：设置页已有 `SettingsPage` 滚动，嵌套 scroll 风险更高。
- 只压缩 logo/row 间距：不能保证小视窗、debug text 或未来本地化长度下不再 overflow。

### Decision: 不改变 shell/back 导航语义

About overflow 修复只处理 layout containment。`presentation`、`embeddedNavigationHost`、`PopScope`、`HomeEntryScreen` fallback、bottom navigation shell preservation 都应保持现有行为，由已有 tests 继续验证。

## Risks / Trade-offs

- [Risk] Dispose-only release path 不写 provider 后，测试或调试对象在 widget dispose 后读到旧状态。→ Mitigation: app teardown 后 UI 不再消费该 provider；正常运行时 unregister 仍写 unavailable。
- [Risk] About destination 增加 scroll container 后桌面宽屏内容宽度变化。→ Mitigation: 使用与 settings page 相近的 bounded width/padding，保持内容不全宽铺开。
- [Risk] `application/desktop` 已有 `application -> features` 反向依赖。→ Mitigation: 本修复不新增 imports，不扩大该耦合，只收敛 controller 的 lifecycle API。

## Verification

- `flutter test test/private_hooks/app_ready_hook_test.dart --reporter expanded`
- `flutter test test/application/desktop/desktop_quick_input_controller_test.dart --reporter expanded`
- `flutter test test/features/home/home_bottom_nav_shell_test.dart --reporter expanded`
- `flutter analyze`
- 尽量运行 `flutter test --reporter expanded`；若仍失败，记录新的失败点。
