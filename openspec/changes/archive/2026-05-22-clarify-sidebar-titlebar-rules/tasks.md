## 1. Policy Audit

- [x] 1.1 Audit current `DesktopShellHost`, `AppleMacosPageShell`, `WindowsDesktopPageShell`, and top-level drawer destination usage to identify where `leadingTitle` duplicates visible expanded-sidebar state.
- [x] 1.2 Classify affected pages as top-level drawer destinations, rail/overlay title-needed destinations, or macOS main-window secondary routes that should rely on native close for logical pop.
- [x] 1.3 Confirm existing window chrome safe-area helpers, route-depth signals, and shell seams that should own macOS traffic-light avoidance and native close dispatch.

## 2. Shell Policy

- [x] 2.1 Define a centralized desktop titlebar navigation-context policy in the shell/platform-adapter layer rather than individual feature pages.
- [x] 2.2 Make macOS expanded-sidebar top-level destinations omit duplicated titlebar leading titles while preserving visible sidebar selected state.
- [x] 2.3 Preserve titlebar or toolbar title context for rail, overlay, narrow, and hidden-navigation modes outside native window chrome reserved space.
- [x] 2.4 Preserve meaningful title/task context for secondary/detail/editor/settings-subsection pages outside native or custom window-control reserved space.
- [x] 2.5 Omit app-level back, close, and done controls for macOS main-window secondary routes whose dismissal is handled by native close dispatch.
- [x] 2.6 Route macOS main-window native red close by route depth: secondary routes pop to the previous app context, root/top-level routes keep normal window close or hide behavior.
- [x] 2.7 Align supported window-close shortcuts such as `Cmd+W` with the same secondary-route pop versus root-window close dispatch.
- [x] 2.8 Preserve a stable macOS expanded-sidebar top-level titlebar spacer height when repeated title and leading controls are hidden, so sidebar body content does not jump between drawer destinations.
- [x] 2.9 Suppress page-specific titlebar or toolbar bottom dividers when macOS expanded-sidebar top-level chrome is hidden and only the stable spacer remains.

## 3. Modularity Guardrails

- [x] 3.1 Ensure the titlebar navigation-context policy does not introduce `state -> features`, `application -> features`, or lower-layer imports of desktop shell chrome details.
- [x] 3.2 Ensure native close dispatch does not introduce route-specific interception inside individual feature pages.
- [x] 3.3 Add or tighten focused tests, architecture tests, or review checklist coverage so future fixes do not reintroduce page-local macOS traffic-light padding or native close interception in feature pages.
- [x] 3.4 Leave touched `home`, route stack, and desktop shell areas equal or better structured by moving title visibility and native close dispatch decisions into a seam instead of spreading platform branches across pages.

## 4. Verification

- [x] 4.1 Add focused verification for macOS expanded sidebar top-level destinations: repeated titlebar leading titles are absent and sidebar selected state remains visible.
- [x] 4.2 Add focused verification for at least one rail/overlay/narrow title-visible fallback mode.
- [x] 4.3 Add focused verification for at least one macOS main-window secondary route: no app-level back/close/done control is rendered, native red close pops the route, and the window remains open.
- [x] 4.4 Add focused verification that macOS main-window root/top-level route native red close keeps normal window close or hide behavior.
- [x] 4.5 Add focused verification that unsaved or guarded secondary route dismissal follows the existing save/discard/cancel policy before popping.
- [x] 4.6 Run `flutter analyze` from `memos_flutter_app`.
- [x] 4.7 Run relevant focused Flutter tests from `memos_flutter_app`; run broader `flutter test` if shell changes affect shared navigation behavior.
- [x] 4.8 Add focused verification that a macOS expanded-sidebar `PlatformPage` keeps the shared titlebar spacer even when title and leading controls are suppressed.
- [x] 4.9 Add focused verification that macOS expanded-sidebar hidden top-level chrome suppresses page-specific toolbar dividers while other titlebar contexts can keep them.
