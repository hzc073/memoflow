# ios-mobile-platform-feature-readiness Specification

## ADDED Requirements

### Requirement: iOS mobile visible feature entries match executable capability

The system SHALL ensure every iPhone and iPadOS visible entry for platform-sensitive features maps to an executable capability, an explicit disabled state, a hidden state, or a documented manual fallback.

#### Scenario: Unsupported iOS mobile feature is not presented as enabled
- **GIVEN** a feature lacks the required iOS mobile runtime implementation, native target, channel handler, permission path, or plugin support
- **WHEN** the app renders settings, drawer actions, memo editor actions, memo card actions, startup flows, or feature subpages on `PlatformTarget.iPhone` or `PlatformTarget.iPad`
- **THEN** the corresponding entry SHALL be hidden or disabled with a user-visible reason
- **AND** toggles SHALL NOT persist an enabled state that the platform cannot execute

#### Scenario: Manual fallback is explicit
- **GIVEN** an iOS mobile feature cannot perform the automated action but has a manual alternative
- **WHEN** the app renders the feature entry
- **THEN** the UI SHALL identify the manual fallback path rather than implying the automated action is available

### Requirement: iOS mobile feature readiness is centralized and layer-safe

The system SHALL expose platform feature readiness through `memos_flutter_app/lib/platform_capabilities/` or an equivalent approved platform capability boundary that can be consumed by feature UI and application services without introducing reverse dependencies.

#### Scenario: Readiness model is complete
- **WHEN** iOS mobile readiness is implemented
- **THEN** the seam SHALL represent feature id, readiness status, reason code, native requirement, and manual fallback description
- **AND** readiness status SHALL use the fixed set `available`, `disabledWithReason`, `hidden`, `manualFallback`, and `requiresNativeImplementation`

#### Scenario: Feature UI consumes readiness seam
- **WHEN** settings pages, home drawer actions, memo editor actions, reminder actions, share startup, widget services, compression services, or attachment settings need platform-sensitive availability
- **THEN** they SHALL consume the centralized readiness result or an equivalent approved platform capability boundary
- **AND** new or changed readiness logic SHALL NOT be duplicated as unrelated `Platform.isIOS` branches across feature pages

#### Scenario: iPhone and iPadOS are both covered
- **WHEN** readiness is evaluated for `TargetPlatform.iOS`
- **THEN** the result SHALL cover both `PlatformTarget.iPhone` and `PlatformTarget.iPad`
- **AND** iPadOS SHALL NOT be left with Android/Windows-only behavior that was fixed for iPhone

#### Scenario: Dependency direction is preserved
- **WHEN** readiness seam files are added or changed
- **THEN** they MUST NOT import `features/*`, `state/*`, `application/*`, or `data/*`
- **AND** they MUST NOT create `state -> features`, `application -> features`, or `core -> state|application|features` reverse dependencies

#### Scenario: Public/private boundary is preserved
- **WHEN** iOS mobile feature readiness logic is added to public app code
- **THEN** it MUST NOT reference StoreKit, subscriptions, paid entitlements, receipts, prices, paywalls, App Store Connect, signing secrets, private overlays, or `AccessDecision.source` for business decisions

### Requirement: iOS mobile widgets use WidgetKit

The system SHALL implement iOS mobile home-screen widgets through WidgetKit and keep Flutter widget UI aligned with WidgetKit capabilities.

#### Scenario: WidgetKit data is updated
- **GIVEN** the iOS project includes a WidgetKit target and shared data path
- **WHEN** memo/widget data changes or the user requests widget refresh on iOS mobile
- **THEN** the app SHALL update shared widget data and request a WidgetKit timeline reload
- **AND** focused tests or smoke notes SHALL cover the iOS mobile widget path

#### Scenario: iOS widget add action uses system fallback
- **GIVEN** iOS does not allow the app to directly add a home-screen widget
- **WHEN** the widgets page renders on iPhone or iPadOS
- **THEN** Android-style add, configure, or system-widget actions that cannot execute SHALL be replaced with system widget setup guidance or another manual fallback
- **AND** preview-only UI SHALL NOT imply that a system widget can be installed from inside the app

### Requirement: iOS mobile location and map picker are executable

The system SHALL allow iOS mobile location UI only when the full provider, permission, and embedded map path can run on iPhone and iPadOS.

#### Scenario: iOS mobile location path is supported
- **GIVEN** iOS mobile has location permission strings, runtime permission handling, provider configuration, and embedded map host support
- **WHEN** the user enables location or opens the memo editor location picker on iPhone or iPadOS
- **THEN** the app SHALL allow the flow and persist selected location data through the existing memo editor path

#### Scenario: Provider requirement is missing
- **GIVEN** a required iOS mobile location provider key, permission, or embedded map dependency is missing
- **WHEN** settings or memo editor location UI renders on iOS mobile
- **THEN** the affected provider or entry SHALL be hidden or disabled with a clear unsupported reason
- **AND** the validator SHALL NOT report misleading Android/Windows-only guidance

### Requirement: iOS mobile reminders schedule real notifications

The system SHALL expose enabled memo reminder behavior on iOS mobile only when local notification scheduling can run on iPhone and iPadOS.

#### Scenario: Reminder scheduling is available on iOS mobile
- **GIVEN** iOS local notification initialization and permission handling are configured
- **WHEN** the user enables reminders or schedules a memo reminder on iPhone or iPadOS
- **THEN** the app SHALL schedule, cancel, and update local notifications through the iOS mobile scheduler path
- **AND** notification activation SHALL restore or route to the relevant memo context when supported by the app lifecycle

#### Scenario: Android-only reminder options are gated
- **WHEN** reminder UI renders on iOS mobile
- **THEN** Android-only options such as exact alarm permission, battery optimization guidance, or Android ringtone picker SHALL be hidden or replaced with iOS-supported alternatives
- **AND** iOS mobile SHALL use system notification sound unless a supported iOS-specific ringtone design is added

### Requirement: iOS mobile third-party share has native handoff and complete media handling

The system SHALL enable third-party share intake on iOS mobile only when the iOS app can receive shared payloads and process supported media through the existing share flow.

#### Scenario: Share Extension or equivalent handoff delivers payloads
- **GIVEN** an iOS Share Extension, URL scheme, app group, or equivalent native handoff path delivers payloads to the Flutter share flow
- **WHEN** third-party share is enabled on iPhone or iPadOS
- **THEN** shared text, links, and supported files SHALL enter the existing share handling path
- **AND** startup recovery SHALL consume pending iOS mobile share payloads without data loss

#### Scenario: Shared video requires compression
- **GIVEN** an iOS mobile shared video exceeds the app's attachment size limit and a supported compression engine is available
- **WHEN** the share flow prepares that video
- **THEN** the app SHALL compress the video or prepare an attachment that satisfies the existing share attachment limit
- **AND** the user SHALL see progress or a clear processing state while the video is being prepared

#### Scenario: Shared video cannot be compressed
- **GIVEN** an iOS mobile shared video exceeds the attachment size limit and no supported compression path can produce an acceptable output
- **WHEN** the share flow handles the payload
- **THEN** the app SHALL show a visible failure reason or alternative path
- **AND** the compression service SHALL NOT silently return `null` in a way that loses payload context

### Requirement: iOS mobile QR scan readiness is based on scanner capability

The system SHALL expose QR scan actions on iPhone and iPadOS only when camera permission and scanner implementation are available.

#### Scenario: Scanner is available on iOS mobile
- **GIVEN** camera permission and the scanner plugin path are available on iOS mobile
- **WHEN** the user opens drawer scan, bridge pairing scan, or migration QR scan on iPhone or iPadOS
- **THEN** the scanner SHALL open and return recognized QR payloads to the existing handling flow

#### Scenario: Scanner is unavailable on iOS mobile
- **GIVEN** the scanner path is not available on iOS mobile
- **WHEN** scan actions render on iPhone or iPadOS
- **THEN** they SHALL be hidden or disabled with an explicit reason
- **AND** manual pairing or text entry fallback SHALL remain reachable where the workflow supports it

### Requirement: iOS mobile image compression options reflect actual engine and format support

The system SHALL only expose image compression behavior on iOS mobile that the current engine, output format, and picker path can actually perform.

#### Scenario: Dart fallback compression is available
- **GIVEN** the iOS mobile path uses a Dart fallback engine for supported formats
- **WHEN** a supported image format is attached and compression is enabled
- **THEN** the app SHALL process the image through the supported fallback path or use a recorded safe fallback reason
- **AND** upload readiness SHALL remain compatible with existing attachment processing contracts

#### Scenario: Unsupported compression option is selected on iOS mobile
- **GIVEN** a compression option depends on unsupported native FFI, WebP output, Android-only picker behavior, or Android-only original-image semantics
- **WHEN** image compression settings render on iPhone or iPadOS
- **THEN** that option SHALL be hidden, disabled, or replaced with an iOS-supported alternative
- **AND** the UI SHALL NOT imply parity with Android-only gallery toolbar behavior

### Requirement: iOS mobile readiness is covered by tests and guardrails

The system SHALL include focused tests or guardrails that prevent iOS mobile visible feature gaps from recurring.

#### Scenario: iOS mobile readiness tests cover high-risk UI entries
- **WHEN** tests run for this change
- **THEN** focused tests SHALL cover iPhone and iPadOS availability states for settings entries, home drawer scan actions, memo editor location actions, memo reminder actions, widget page actions, share intake settings, share video compression, and image compression options

#### Scenario: Architecture guardrail covers readiness seam
- **WHEN** architecture guardrail tests or repo scans run
- **THEN** they SHALL fail on new reverse dependencies introduced by readiness code
- **AND** they SHOULD flag new platform-sensitive iOS mobile UI entries that do not consume the approved readiness seam or document an exception
