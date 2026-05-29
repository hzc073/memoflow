# Project Instructions

## Documentation Language

本项目的 OpenSpec 文档默认使用简体中文输出，除非用户明确要求其他语言，或续写既有不同语言 artifact 时为保持一致需要保留原语言。

- 中文 MUST 用于 `proposal.md`、`design.md`、`tasks.md`、delta specs、implementation notes 和归档说明中的正文、背景说明、设计理由、权衡分析、实现备注、任务解释和风险说明。
- English SHOULD be preserved for OpenSpec structure words, template headings, and requirement language, such as `Requirement`, `Scenario`, `GIVEN`, `WHEN`, `THEN`, `MUST`, `SHALL`, `SHOULD`, and `MAY`.
- English MUST be preserved for code identifiers, API names, file paths, class names, function names, package names, database terms, protocol terms, and server route terms.
- 技术名词在会影响搜索、实现或代码定位时 SHOULD 保留英文，例如 `plain-text query`, `literal substring`, `SQLite FTS`, `LIKE`, `provider`, `controller`, and `AppDatabase.listMemos`.
- 需求描述 SHOULD 保持可验证：即使正文使用中文，也应清楚表达输入、行为、输出、边界条件和验收标准。
- 编写中文内容时 MUST 使用 UTF-8 安全的编辑方式，避免通过不安全 shell 写入造成 mojibake 或编码损坏。

## OpenSpec Artifact Style

- `proposal.md` SHOULD use Chinese for Why, What Changes, Capabilities descriptions, and Impact details while preserving capability IDs in kebab-case English.
- `design.md` SHOULD use Chinese for rationale, decisions, alternatives, risks, and trade-offs while preserving English technical identifiers.
- `spec.md` SHOULD preserve English operation headers, requirement/scenario headings, and normative keywords, with Chinese requirement descriptions and scenario explanations by default.
- `tasks.md` SHOULD use Chinese task descriptions, but include relevant English code/module names when the task maps to implementation files.
