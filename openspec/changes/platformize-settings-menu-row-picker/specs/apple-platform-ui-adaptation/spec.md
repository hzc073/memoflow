## ADDED Requirements

### Requirement: Apple settings menu rows SHALL avoid Material-only inline dropdowns

Apple mobile 设置页中的 `SettingsMenuRow<T>` SHALL avoid 在 `CupertinoPageScaffold`、`CupertinoListSection` 或 `CupertinoListTile` 内容中直接内嵌需要 `Material` ancestor 的 `DropdownButton<T>` 作为主要选择控件。

#### Scenario: Image compression settings renders on iPhone

- **WHEN** 用户在 iPhone 上打开图片压缩设置页
- **THEN** compression mode、output format、resize mode、JPEG chroma subsampling、TIFF compression、TIFF deflate preset、max output unit 等 menu rows SHALL render without Flutter framework errors
- **AND** opening each enabled menu row SHALL present options through an Apple-safe platform picker surface

#### Scenario: Other settings menu rows use the same seam

- **WHEN** location provider、AI proxy protocol 或其他设置页复用 `SettingsMenuRow<T>`
- **THEN** those rows SHALL use the same shared menu-row picker behavior
- **AND** implementation MUST NOT create page-specific Apple-only dropdown wrappers for each setting screen

#### Scenario: Apple settings picker remains public-shell safe

- **WHEN** Apple settings menu picker behavior is implemented in the public repository
- **THEN** it MUST NOT add StoreKit, subscription, entitlement, receipt, product ID, price, paywall, private overlay, or `AccessDecision.source` business branching logic
- **AND** platform adapter files MUST preserve existing dependency direction rules
