## Context

当前 engagement 展示控制存在三种语义：

```text
home memo card
  -> prefs.showEngagementInAllMemoDetails && account != null

memo detail
  -> widget.showEngagement || prefs.showEngagementInAllMemoDetails

desktop preview pane
  -> shouldShowEngagement: true
```

这让“偏好开关”不再是唯一用户意图。只要某个入口传入 `showEngagement: true` 或 `shouldShowEngagement: true`，就能绕过设置页中的开关。更重要的是，本地库模式没有 Memos server reactions/comments 能力，挂载 `MemoEngagementSurface` 会进入 remote engagement loading 路径，而不是稳定的 unsupported behavior。

## Goals / Non-Goals

**Goals:**

- 本地库模式中，memo 点赞/评论展示 SHALL be unsupported。
- 服务端工作区中，一个偏好开关统一控制所有 memo engagement surfaces。
- 将用户可见设置名称更新为更通用的“显示点赞与评论”。
- 将新代码语义收敛为 `showMemoEngagement` / `effectiveShowMemoEngagement`，消除“强制显示”参数语义。
- 保留旧偏好存储读取兼容，避免用户已保存设置丢失。
- 增加 tests/guardrail，防止 `showEngagement: true`、`shouldShowEngagement: true` 重新绕过统一 gate。

**Non-Goals:**

- 不实现本地库评论、点赞、reaction storage、local-only comments 或 sync。
- 不修改 Memos server API、request/response models、route adapters、version compatibility logic、SSE payload parsing 或 `memos_flutter_app/lib/data/api`。
- 不改变 reaction/comment API 的业务能力本身；本 change 只定义 display gate。
- 不新增商业/private/premium 逻辑。
- 不要求第一阶段重命名持久化 JSON key；可通过 compatibility adapter 读取旧 key。

## Decisions

### 1. 使用统一 effective gate，而不是 surface-local 强制显示

后续实现应把展示判断收敛为等价语义：

```text
effectiveShowMemoEngagement =
  hasRemoteAccount
  && !isLocalLibraryMode
  && workspacePrefs.showMemoEngagement
```

其中 `showMemoEngagement` 是用户偏好，`effectiveShowMemoEngagement` 是运行时 gate。所有 memo engagement surface 都应消费这个 gate 或由父级传入的 equivalent value。

### 2. Surface 只能表达“支持”，不能表达“绕过偏好”

旧参数名 `showEngagement` 容易被理解成“强制显示”。新的语义应拆成：

```text
surfaceSupportsMemoEngagement  // 该 surface 是否有位置展示
effectiveShowMemoEngagement    // 最终是否展示
```

例如 explore/notification read-only detail MAY 支持 engagement，但仍 MUST 被统一偏好和 workspace capability gate 限制。

### 3. 本地库模式是 unsupported，不是 preference-disabled

本地库模式下应直接 veto engagement surface：

```text
local library mode
  -> no like/comment buttons
  -> no like/comment counts
  -> no liker avatars
  -> no comment list/composer
  -> no MemoEngagementSurface mount
  -> no reactions/comments remote loading
```

设置页在本地工作区中 SHOULD hide 或 disable 该开关，并说明本地工作区不支持点赞与评论展示；如果第一阶段只隐藏开关，也必须保证实际 surfaces 不展示。

### 4. 命名采取渐进迁移

推荐命名：

- 用户可见中文：`显示点赞与评论`
- 用户可见英文：`Show likes and comments`
- runtime/preference field：`showMemoEngagement`
- resolved gate：`effectiveShowMemoEngagement` 或 `canShowMemoEngagement`

持久化兼容建议：

```text
read:
  showMemoEngagement
  fallback to showEngagementInAllMemoDetails

write:
  implementation MAY continue writing old key in first phase
  OR write new key with explicit migration tests
```

第一阶段优先保证行为统一和文案准确；如果重命名存储 key 会扩大迁移风险，可以先保留旧 key 作为 storage detail。

### 5. Guardrail 保护“无绕过点”

应增加 focused guardrail 或 widget tests，覆盖：

- `memos_list_desktop_preview_pane.dart` 不再硬编码 `shouldShowEngagement: true`。
- `MemoDetailScreen` 不再使用 `widget.showEngagement || preference` 这种 bypass gate。
- detail/explore/notification/reader 入口不再用 `showEngagement: true` 强制显示。
- 本地模式 harness 中，相关 surfaces 不挂载 `MemoEngagementSurface`，且 fake engagement client load count 为 0。

## Dependency Direction

Before:

```text
features/memos widgets/screens
  -> each decides engagement display locally
  -> some paths bypass workspace preference
  -> MemoEngagementSurface owns loading once mounted
```

After:

```text
settings/workspace preference
  -> resolved UI/provider seam computes effectiveShowMemoEngagement
  -> features/memos surfaces consume the gate
  -> MemoEngagementSurface only mounts when gate is true
```

依赖方向应保持在 UI/provider seam 内。不得让 `state`、`application` 或 `core` 引入 `features/*` 来判断具体 screen；也不得把 UI display policy 下沉到 Memos API layer。

本 change 触及 memos/detail/desktop preview coupled area。在 `evolve_modularity` 阶段，改动通过集中 gate、清理强制显示参数语义、补 guardrail，使 touched area equal or better structured。

## Risks / Trade-offs

- [Risk] 直接重命名 storage key 可能让现有用户偏好恢复默认。Mitigation: 读取兼容旧 key，必要时第一阶段只改 runtime 命名和 UI 文案。
- [Risk] explore/notifications 入口之前刻意强制显示 engagement，改为统一偏好后部分用户会看到更少内容。Mitigation: 这是用户明确要求的统一开关语义；测试应覆盖这些入口尊重 gate。
- [Risk] 将 gate 放到过低层可能引入 reverse dependency 或 API 层污染。Mitigation: gate 只应在 settings/resolved preference seam 或 feature UI boundary 解析，不修改 API layer。
- [Risk] 隐藏本地模式开关可能影响设置页布局或 i18n tests。Mitigation: 明确本地模式 unsupported，设置页可隐藏或 disabled，但 surfaces 必须强制不展示。
