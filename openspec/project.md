# Project Instructions

## Documentation Language

本项目的 OpenSpec 文档 SHOULD 使用中英混合写法，以兼顾中文沟通效率和代码/协议语义的一致性。

- 中文用于背景说明、设计理由、权衡分析、实现备注、任务解释和风险说明。
- English SHOULD be preserved for OpenSpec structure words and requirement language, such as `Requirement`, `Scenario`, `GIVEN`, `WHEN`, `THEN`, `MUST`, `SHALL`, `SHOULD`, and `MAY`.
- English MUST be preserved for code identifiers, API names, file paths, class names, function names, package names, database terms, protocol terms, and server route terms.
- 技术名词在会影响搜索、实现或代码定位时 SHOULD 保留英文，例如 `plain-text query`, `literal substring`, `SQLite FTS`, `LIKE`, `provider`, `controller`, and `AppDatabase.listMemos`.
- 需求描述 SHOULD 保持可验证：即使正文使用中文，也应清楚表达输入、行为、输出、边界条件和验收标准。
- 编写中文内容时 MUST 使用 UTF-8 安全的编辑方式，避免通过不安全 shell 写入造成 mojibake 或编码损坏。

## OpenSpec Artifact Style

- `design.md` SHOULD use Chinese for rationale and trade-offs while preserving English technical identifiers.
- `spec.md` SHOULD preserve English requirement/scenario headings and normative keywords, with Chinese explanations allowed in scenario descriptions.
- `tasks.md` MAY use Chinese task descriptions, but SHOULD include relevant English code/module names when the task maps to implementation files.
