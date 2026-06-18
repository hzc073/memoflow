## 1. OpenSpec

- [x] 1.1 确认当前 architecture phase 为 `evolve_modularity`。
- [x] 1.2 记录本变更不触碰 API compatibility 或 Flutter runtime 耦合热点。
- [x] 1.3 新增 `public-repo-leak-guard` delta spec。

## 2. Guard 实现

- [x] 2.1 新增 `.memoflow-public-denylist`，覆盖高风险私有路径、商品 ID、购买/恢复符号和 StoreKit/IAP 入口。
- [x] 2.2 新增 `tools/memoflow_guard.sh`，实现 `check` 和 `check-staged`。
- [x] 2.3 在 Guard 中检查明显私有方向的 Git remote。
- [x] 2.4 避免当前公开仓治理文档、denylist 或 Guard 工具本身造成误报。

## 3. Git Hooks 与文档

- [x] 3.1 新增 `.githooks/pre-commit` 调用 `check-staged`。
- [x] 3.2 新增 `.githooks/pre-merge-commit` 和 `.githooks/pre-push` 调用 `check`。
- [x] 3.3 设置 Guard 和 hook 文件可执行权限。
- [x] 3.4 更新 README，说明 `core.hooksPath` 和 `chmod +x` 启用步骤。

## 4. Verification

- [x] 4.1 运行 `./tools/memoflow_guard.sh check`。
- [x] 4.2 运行 `./tools/memoflow_guard.sh check-staged`。
- [x] 4.3 检查新增 hook 文件权限。
- [x] 4.4 检查 staged/unstaged diff，确认未引入私有仓同步脚本、IAP、StoreKit、商品 ID 或 App Store 发布配置。
- [x] 4.5 使用临时 Git 仓库反向验证：暂存危险关键词、工作区禁止路径、私有方向 remote 均会被阻止。
