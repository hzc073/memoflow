## Context

现有公开仓已经包含关于 private overlay、StoreKit 边界和商业能力隔离的文档、OpenSpec 归档以及 CI guardrail 测试。这些治理文件会合法地出现一些商业边界词。如果本地 Guard 简单扫描所有文本中的泛化词，会在启用当天就误报；如果完全不扫描关键词，又无法阻止商品 ID、购买/恢复实现或 StoreKit 配置泄漏。

因此本地 Guard 采用可维护的 denylist，同时将规则分为路径规则和关键词规则：

- 路径规则用于检查工作区和暂存区路径，即使文件未被 Git 跟踪也能拦截明显私有目录或 StoreKit 配置。
- 关键词规则用于扫描 Git 已跟踪文本内容或 staged 新增行，重点覆盖商品 ID、购买/恢复代码符号、StoreKit 导入、IAP 插件包名等高置信泄漏。

## Decisions

### Guard entrypoints

`tools/memoflow_guard.sh` 提供两个入口：

- `check`: 用于 merge 后和 push 前，检查当前工作区路径、Git 已跟踪文本内容和 remotes。
- `check-staged`: 用于 commit 前，检查 staged 文件路径、staged 新增行和 remotes。

脚本失败时输出所有命中项，并以非零状态阻止对应 Git 操作；通过时输出简短通过信息。

### Denylist format

`.memoflow-public-denylist` 一行一个规则，空行和 `#` 开头的行忽略。规则只使用普通文本，不引入正则语法，降低维护成本。

脚本按规则形态自动区分用途：

- 包含 `/` 或明显敏感文件扩展名的规则按路径规则处理。
- 其他规则按关键词规则处理。
- 路径检查会对所有 denylist 规则做 substring 匹配，避免新增规则因分类不准而漏掉文件名。

初始 denylist 保留高风险路径、商品 ID、StoreKit 导入和购买/恢复调用形态。对当前公开仓中合法出现的治理说明和 guardrail 测试，避免使用过宽泛的单词级规则。

### Staged scan behavior

`check-staged` 只扫描 staged 新增行，不扫描删除行。这样删除或清理私有内容不会被 pre-commit 阻止。

### Remote scan behavior

两个模式都会检查 `git remote -v`。如果 remote 名称或 URL 命中明显私有方向词，如 private、StoreKit、IAP、App Store、release、billing、entitlement、commercial、TestFlight，则阻止操作并提示移除或重命名 remote。

## Modularity

本变更不修改 Flutter 应用运行时代码，不触碰已知 `state -> features`、`application -> features`、`core -> higher-layer` 耦合热点。它新增仓库级 guardrail，防止 public/private 边界在后续改动中恶化，符合 `evolve_modularity` 阶段 checklist item `8.`、`9.`、`10.`。

## Risks

- Denylist 过宽会造成误报。缓解方式是保持规则偏高置信，并在发现合法占位代码时收紧具体规则，而不是关闭 Guard。
- Denylist 过窄会漏掉未知私有实现。缓解方式是保留 CI 中更严格的公开仓 guardrail，并让 denylist 可持续增补。
- Git hooks 需要开发者本地执行 `git config core.hooksPath .githooks` 后才会生效。README 会明确安装步骤。
