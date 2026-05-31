## ADDED Requirements

### Requirement: AI Summary setup CTA SHALL open the desktop settings AI pane when supported
`AI 总结` 页面在 AI 模型未配置时显示的 `去设置` CTA SHALL prefer the desktop settings window AI pane on supported desktop platforms, rather than directly opening a standalone `AiSettingsScreen` route.

#### Scenario: Desktop setup CTA opens AI settings pane
- **GIVEN** the user is on a supported desktop platform
- **AND** the `AI 总结` page shows the AI setup CTA because no usable chat model is configured
- **WHEN** the user clicks `去设置`
- **THEN** the app SHALL request the desktop settings window with the AI settings target
- **AND** the main window SHALL NOT push standalone `AiSettingsScreen` when the target settings window opens successfully

#### Scenario: Setup CTA falls back visibly
- **GIVEN** the user is on an unsupported platform or the target settings window request fails
- **AND** the `AI 总结` page shows the AI setup CTA
- **WHEN** the user clicks `去设置`
- **THEN** the app SHALL open a visible `AiSettingsScreen` fallback route

#### Scenario: AI Summary content remains unchanged
- **WHEN** this routing behavior is added
- **THEN** AI summary templates, report generation, AI settings provider state, repositories, API routes, database schema, and AI service detail forms SHALL remain unchanged
