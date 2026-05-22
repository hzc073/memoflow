## ADDED Requirements

### Requirement: Desktop titlebar navigation context SHALL prioritize native window chrome
The system SHALL treat native window chrome reserved areas as higher priority than page title text when rendering desktop titlebar, toolbar, navigation, or command content.

#### Scenario: macOS traffic lights take precedence
- **WHEN** a macOS desktop window uses native traffic lights and allows Flutter content to draw into the titlebar region
- **THEN** the top-leading titlebar area reserved for native red/yellow/green controls MUST NOT render page title text, navigation labels, or first interactive controls

#### Scenario: Decorative or duplicate title is omitted
- **WHEN** a titlebar title does not add information beyond visible navigation state
- **THEN** the desktop shell SHALL omit that title instead of moving it into native window chrome reserved space

### Requirement: Expanded sidebar top-level destinations SHALL NOT repeat their title in macOS top-leading titlebar
The system SHALL use the expanded sidebar selected state as the primary current-page indicator for top-level drawer destinations on macOS.

#### Scenario: Top-level destination with expanded sidebar
- **WHEN** a macOS desktop shell displays an expanded sidebar with readable destination labels and a selected top-level drawer destination
- **THEN** the titlebar leading area SHALL NOT repeat that destination label as a page title

#### Scenario: Sidebar selection remains visible
- **WHEN** the titlebar leading page title is omitted for an expanded-sidebar top-level destination
- **THEN** the selected destination state in the sidebar MUST remain visible and sufficient to identify the current page

#### Scenario: Top-level titlebar spacer remains stable
- **WHEN** a macOS expanded-sidebar top-level destination omits its repeated titlebar leading title or leading control
- **THEN** the shell or platform adapter SHALL preserve a consistent top titlebar or toolbar spacer height across supported top-level drawer destinations so the sidebar body content does not shift vertically during menu navigation

#### Scenario: Hidden top-level chrome spacer does not add page separators
- **WHEN** a macOS expanded-sidebar top-level destination renders only the stable top titlebar or toolbar spacer because repeated titlebar chrome is omitted
- **THEN** the spacer SHALL NOT render a page-specific bottom divider or separator line unless visible toolbar content explicitly requires that boundary

### Requirement: Hidden navigation modes SHALL allow page title outside window chrome
The system SHALL allow a top-level destination title to appear when the current navigation label is not persistently visible, provided it is laid out outside native or custom window-control regions.

#### Scenario: Rail navigation needs title context
- **WHEN** a desktop shell uses rail navigation where destination labels are not persistently visible
- **THEN** the shell SHALL allow the current destination title to render in a chrome-safe titlebar or toolbar region

#### Scenario: Overlay navigation needs title context
- **WHEN** a desktop shell uses overlay navigation or a narrow layout where the sidebar is hidden until opened
- **THEN** the shell SHALL allow the current destination title to render in a chrome-safe titlebar or toolbar region

### Requirement: Secondary task pages SHALL retain meaningful title context without app-level close controls
The system SHALL preserve title context for secondary pages, detail pages, editors, modal task surfaces, or pushed routes while avoiding duplicate app-level back or close controls in macOS main-window chrome.

#### Scenario: Secondary page title is meaningful
- **WHEN** a desktop page represents a secondary task, detail view, editor, settings subsection, or pushed route rather than a selected top-level drawer destination
- **THEN** the page title SHALL be available in a safe toolbar or content header that does not overlap native window controls

#### Scenario: macOS main-window secondary page omits app-level dismissal control
- **WHEN** a secondary page is shown as a pushed route inside the macOS main window
- **THEN** the page SHALL NOT render an additional app-level back button, close button, or done button for dismissing that route

### Requirement: macOS main-window native close SHALL dismiss secondary routes before closing the window
The system SHALL dispatch the native macOS red close control according to the main window's route depth: secondary routes are dismissed first, while root or top-level routes keep normal window close or hide behavior.

#### Scenario: Secondary route intercepts native close
- **WHEN** the macOS main window is displaying a secondary pushed route that can be popped
- **THEN** activating the native red close control SHALL dismiss the current route and return to the previous app context while keeping the main window open

#### Scenario: Root route keeps window close semantics
- **WHEN** the macOS main window is displaying a root or top-level route that should not be popped for page navigation
- **THEN** activating the native red close control SHALL follow the normal window close or hide policy

#### Scenario: Window close shortcut follows native close dispatch
- **WHEN** the macOS main window receives a supported window-close command such as `Cmd+W`
- **THEN** it SHALL follow the same secondary-route pop versus root-window close dispatch as the native red close control

#### Scenario: Unsaved changes are protected
- **WHEN** a secondary route has unsaved edits, in-flight work, or destructive dismissal constraints
- **THEN** native close dispatch MUST honor the same save, discard, cancel, or confirmation policy as an explicit route dismissal

### Requirement: Titlebar navigation context policy SHALL be centralized and verifiable
The system SHALL centralize desktop title visibility decisions in a shell, platform adapter, or equivalent desktop UI seam rather than distributing platform-specific title rules across feature pages.

#### Scenario: Feature page provides semantic title
- **WHEN** a feature page provides a title, leading action, trailing action, command bar, or body content to a desktop shell
- **THEN** the feature page SHALL NOT need to know whether macOS expanded-sidebar mode will render or omit that title

#### Scenario: Shell policy is tested
- **WHEN** titlebar visibility policy, navigation mode selection, or macOS window chrome handling changes
- **THEN** focused tests, layout tests, smoke checklist entries, or architecture guardrails SHALL verify expanded-sidebar suppression, secondary-route native close dispatch, and at least one title-visible fallback mode
