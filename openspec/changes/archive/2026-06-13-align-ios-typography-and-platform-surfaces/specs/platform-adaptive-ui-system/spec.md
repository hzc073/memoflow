## ADDED Requirements

### Requirement: Adaptive UI system SHALL centralize effective typography decisions
The platform adaptive UI system SHALL provide a centralized policy or equivalent stable seam for resolving effective app typography across platforms. Feature screens SHALL NOT duplicate platform-specific typography decisions for font family, font availability, text scaling, or UI chrome line-height behavior.

#### Scenario: App theme resolves effective typography
- **WHEN** `MaterialApp` theme, `CupertinoTheme`, or app-level `MediaQuery` needs effective font family, font fallback, text scaler, or UI line-height behavior
- **THEN** the app SHALL resolve those values through the centralized typography policy or equivalent stable seam
- **AND** feature pages MUST NOT add local `TargetPlatform.iOS` or `Platform.isIOS` branches to repair the same app-wide typography behavior

#### Scenario: Typography policy remains stable-layer safe
- **WHEN** a centralized typography policy or helper is introduced or changed
- **THEN** it MUST NOT depend on `features/*`, `application/*`, or UI page implementation details
- **AND** it SHALL accept only stable inputs such as platform classification, app preference values, existing text scaler, and theme-relevant primitive values

#### Scenario: Composition root delegates decisions
- **WHEN** `app.dart` composes `ThemeData`, `CupertinoTheme`, or `MediaQuery`
- **THEN** it SHALL delegate platform-specific typography decisions to the centralized policy or equivalent seam
- **AND** `app.dart` SHALL remain primarily a composition root rather than accumulating page-specific typography rules

### Requirement: Adaptive UI system SHALL expose font-selection capability by platform
The platform adaptive UI system SHALL expose whether a platform can select system fonts and what effective font label should be shown, so settings surfaces do not infer capability from an empty font list alone.

#### Scenario: iOS reports no selectable system-font capability
- **WHEN** Preferences evaluates the font setting on iPhone or iPadOS
- **THEN** the adaptive UI system SHALL report that system-font selection is unavailable or system-default-only for that platform
- **AND** the settings surface SHALL render a non-misleading state without opening an empty font picker

#### Scenario: Desktop reports selectable system-font capability
- **WHEN** Preferences evaluates the font setting on Windows, macOS, Linux, or another platform with supported system font discovery
- **THEN** the adaptive UI system SHALL allow the existing system-font picker path to remain available
- **AND** the displayed label SHALL continue to reflect the selected font or system default

#### Scenario: Settings remains semantic
- **WHEN** Preferences renders the font setting row, disabled state, hidden state, or read-only label
- **THEN** it SHALL use settings semantic components or an approved settings/platform seam
- **AND** it MUST NOT create a separate iOS-only Preferences page tree

### Requirement: Adaptive settings rows SHALL map value metadata to platform-native slots
The platform adaptive UI system SHALL render settings row value text through platform-native metadata slots rather than treating all right-side content as an unconstrained trailing control. Value text such as selected enum labels, font labels, and mode labels SHALL remain bounded under Apple mobile Dynamic Type while Android and desktop Material rows keep their existing trailing presentation.

#### Scenario: iOS value text uses Cupertino additional info
- **WHEN** a settings value row renders on iPhone or iPadOS with a value label and a disclosure indicator
- **THEN** the value label SHALL be mapped to the Cupertino row additional-info slot or an equivalent platform metadata seam
- **AND** the disclosure indicator SHALL remain the trailing control
- **AND** the value label MUST NOT be rendered as an unconstrained trailing control that can inherit inconsistent typography

#### Scenario: iOS large text remains bounded
- **WHEN** Preferences renders on iPhone or iPadOS with a large system `MediaQuery.textScaler`
- **THEN** settings value labels SHALL remain constrained, ellipsized, or otherwise reflowed without overflowing row chrome
- **AND** the row SHALL preserve system text scaling rather than disabling Dynamic Type globally

#### Scenario: Material rows keep existing behavior
- **WHEN** a settings value row renders on Android, Windows, macOS, Linux, or web Material surfaces
- **THEN** the row SHALL keep the existing Material trailing presentation for value labels, chevrons, switches, and icons
- **AND** this Apple mobile typography fix MUST NOT introduce Android-specific visual or interaction regressions

### Requirement: Adaptive UI typography changes SHALL include focused verification
Changes to adaptive typography, text scaling, font-selection capability, or Apple mobile surface rules SHALL include focused automated verification.

#### Scenario: Effective iOS font behavior is verified
- **WHEN** typography policy tests run
- **THEN** they SHALL verify that iPhone and iPadOS ignore persisted unsupported `fontFamily` / `fontFile` for effective app chrome
- **AND** they SHALL verify that non-iOS font behavior covered by existing support is not regressed

#### Scenario: Text scaling behavior is verified
- **WHEN** widget or unit tests run for iOS typography behavior
- **THEN** they SHALL verify that system text scaling contributes to the effective iOS text scaler
- **AND** `AppFontSize.standard` MUST NOT replace the system scaler with a fixed linear value

#### Scenario: Settings font entry behavior is verified
- **WHEN** iPhone Preferences widget tests run
- **THEN** they SHALL verify that the font entry does not open an empty iOS system-font picker
- **AND** the rendered state SHALL communicate system default or an equivalent non-misleading state

#### Scenario: Platform adapter dependency guardrail is verified
- **WHEN** architecture tests or repo scans run
- **THEN** they SHALL prevent new `platform -> features`, `platform -> state`, `platform -> application`, and `platform -> data` dependencies introduced by this typography adaptation unless an explicit OpenSpec-approved exception exists

### Requirement: Adaptive UI surface rules SHALL distinguish brand surfaces from platform chrome
The platform adaptive UI system SHALL document and enforce the distinction between MemoFlow brand surfaces and platform-native chrome so future iOS changes do not mix raw Material/Cupertino decisions arbitrarily.

#### Scenario: High-perception Apple chrome is adapted
- **WHEN** migrated iPhone or iPadOS UI renders page chrome, navigation, picker, dialog, grouped list, bottom navigation, settings rows, or primary actions
- **THEN** it SHALL use `platform/`, settings, or approved adaptive seams for platform semantics
- **AND** page-local raw Material/Cupertino substitutions MUST NOT be introduced as the default migration path

#### Scenario: Shared brand surface is retained
- **WHEN** a surface intentionally keeps MemoFlow brand styling such as card color, primary accent, or content card shape on Apple mobile
- **THEN** that behavior SHALL be implemented through shared theme/settings/platform tokens or documented design rationale
- **AND** it MUST NOT rely on accidental global typography side effects such as unsupported fonts, overridden system scaling, or reader line height on UI chrome

#### Scenario: Future migration stays scoped
- **WHEN** future iOS UI work touches home, settings, memos, onboarding, collections, review, or stats
- **THEN** it SHALL reuse the typography and platform surface policy from this change where applicable
- **AND** it SHALL keep the touched area equal or better structured during `evolve_modularity`
