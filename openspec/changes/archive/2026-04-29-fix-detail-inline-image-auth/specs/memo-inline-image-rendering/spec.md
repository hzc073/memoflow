## ADDED Requirements

### Requirement: Detail inline attachment images carry memo auth context
The system SHALL render memo detail Markdown and HTML inline images with the resolved Memos server image request context when the source points to a relative or same-origin Memos file URL.

#### Scenario: Same-origin attachment image in detail content
- **WHEN** a memo detail page renders expanded clipped-article content containing an inline image whose source resolves to the current account's Memos server origin
- **THEN** the Markdown image renderer receives the current `baseUrl`, `authHeader`, `rebaseAbsoluteFileUrlForV024`, and `attachAuthForSameOriginAbsolute` context needed to attach the `Authorization` header

#### Scenario: Relative attachment image in detail content
- **WHEN** a memo detail page renders expanded clipped-article content containing an inline image with a relative `/file/attachments/...` source
- **THEN** the Markdown image renderer receives the current `baseUrl` and `authHeader` context needed to resolve the URL and attach the `Authorization` header

#### Scenario: Collapsed detail content does not start inline image requests
- **WHEN** memo detail content is displayed in the collapsed state
- **THEN** inline image rendering remains disabled for the collapsed preview and no remote image request is started by the collapsed Markdown content

### Requirement: Detail auth propagation is regression-tested
The system SHALL include focused automated coverage for the memo detail `contentOverride` rendering path so Markdown image authorization context is not dropped by wrapper widgets.

#### Scenario: Detail wrapper passes auth context to MemoMarkdown
- **WHEN** `MemoDocumentPrimaryContent` builds its `_CollapsibleText` content override from `MemoDocumentResolvedData` that contains `baseUrl`, `authHeader`, and server-version image flags
- **THEN** the descendant `MemoMarkdown` receives the same image request context values
