## Why

当前仓库采用公共仓库和私有仓库分离开发。公共仓库应承载公开 UI、笔记、同步、窗口体验、测试和架构调整；App Store / IAP / StoreKit / 商品 ID / 私有 entitlement / 发布配置等内容应保留在私有仓库。

目前 CI 中已有公开仓边界 guardrail，但提交、合并和推送前缺少本地自动拦截。开发者可能在本地误暂存私有目录、StoreKit 配置、购买恢复代码或明显私有方向的 remote，直到 CI 或人工 review 才发现。需要新增一个轻量本地 Guard 工具，并接入 Git hooks，让问题在进入提交历史前被阻止。

当前 architecture phase 为 `evolve_modularity`。本变更不触碰 Flutter runtime、API compatibility、`state -> features`、`application -> features` 或 `core -> higher-layer` 耦合热点；它新增仓库级 guardrail，主要覆盖 checklist item `8.`、`9.`、`10.`。

## What Changes

- 新增 `.memoflow-public-denylist`，集中维护公共仓库禁止出现的高风险路径和关键词。
- 新增 `tools/memoflow_guard.sh`，支持 `check` 和 `check-staged` 两种模式。
- `check` 检查工作区中的 denylist 路径、Git 已跟踪文本内容中的 denylist 关键词，以及明显私有方向的 Git remote。
- `check-staged` 检查暂存路径、暂存新增内容中的 denylist 关键词，以及明显私有方向的 Git remote。
- 新增 `.githooks/pre-commit`、`.githooks/pre-merge-commit`、`.githooks/pre-push`，分别调用对应 Guard 模式。
- 更新 README，说明如何启用 hooks 和执行权限。
- 不引入私有仓库同步脚本，不添加 IAP / StoreKit / 商品 ID / App Store 发布配置，不修改业务功能。

## Capabilities

### New Capabilities

- `public-repo-leak-guard`: 定义公共仓本地防泄漏 Guard、denylist 维护方式和 Git hook 集成行为。

### Modified Capabilities

- 无。

## Impact

- 新增仓库级工具和 hooks：
  - `.memoflow-public-denylist`
  - `tools/memoflow_guard.sh`
  - `.githooks/pre-commit`
  - `.githooks/pre-merge-commit`
  - `.githooks/pre-push`
- 更新根 README 的 hooks 启用说明。
- 不修改 `memos_flutter_app/lib/data/api` 或 `memos_flutter_app/test/data/api`。
- 不修改 Flutter 运行时代码、数据库 schema、WebDAV 协议、业务状态模型或 public/private runtime seam。
