## ADDED Requirements

### Requirement: macOS settings-like menu commands SHALL route to targeted settings destinations
macOS 菜单中明确属于设置的 MemoFlow-specific commands SHALL use targeted desktop settings window routing as their primary path, instead of directly pushing standalone settings pages in the main window.

#### Scenario: Settings-like menu command is selected
- **GIVEN** a macOS menu command has been classified as a settings target
- **WHEN** the user selects that command from the macOS menu
- **THEN** the command seam SHALL request the desktop settings window with the matching target destination
- **AND** when the request succeeds, the settings window SHALL show the matching pane or pane-local nested settings page
- **AND** the command SHALL NOT directly push the standalone settings page as its primary path

#### Scenario: Settings-like command falls back
- **GIVEN** a macOS menu command has been classified as a settings target
- **WHEN** the target settings window request is unsupported or fails
- **THEN** the command seam SHALL open the original visible fallback page in the main window

#### Scenario: Non-settings menu command remains a normal workflow
- **GIVEN** a macOS menu command is classified as a business page, tool page, import/export workflow, diagnostic workflow, or task surface candidate
- **WHEN** the user selects that command
- **THEN** the command MAY continue to use the existing workflow-specific route or task presentation
- **AND** the command SHALL NOT be forced into the settings window solely because its label contains a settings-adjacent word

### Requirement: macOS settings-like command migration SHALL be allowlist based
迁移到 settings window 的 macOS menu commands SHALL be selected through an explicit reviewed allowlist and documented scan result, not through automatic string matching.

#### Scenario: Command migration list is reviewed
- **WHEN** settings-like macOS menu command routing is implemented
- **THEN** the change SHALL include a reviewed list of migrated, deferred, and unchanged commands
- **AND** each deferred or unchanged settings-adjacent command SHALL include a reason

#### Scenario: Guardrail checks migrated commands
- **WHEN** architecture or menu guardrail tests are run
- **THEN** they SHALL fail if an allowlisted migrated settings-like command uses direct standalone page push as its primary path
- **AND** they MAY allow direct page construction only in explicit fallback code
