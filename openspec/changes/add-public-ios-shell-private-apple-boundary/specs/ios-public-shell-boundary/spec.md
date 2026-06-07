## ADDED Requirements

### Requirement: Public iOS Runner SHALL live in the public repository
公开仓库 SHALL own `memos_flutter_app/ios/` as a non-commercial iOS public shell so the iPhone app can be built and tested without private commercial code.

#### Scenario: Public checkout builds the iOS shell
- **WHEN** a developer checks out the public repository without an Apple private overlay
- **THEN** `memos_flutter_app/ios/` SHALL contain the public iOS Runner configuration required for a base iPhone build
- **AND** the build SHALL NOT require private billing, StoreKit, entitlement, product configuration, receipt validation, signing secret, TestFlight, or App Store Connect automation code

#### Scenario: Public iOS shell uses public Dart entrypoints
- **WHEN** the iOS Runner starts the Flutter app
- **THEN** it SHALL use the public `memos_flutter_app/lib/main.dart` entrypoint or an approved public entrypoint
- **AND** it SHALL NOT import private repository paths, private packages, or commercial Apple runtime modules directly

### Requirement: Public iOS app identity SHALL be stable
公开 iOS shell SHALL use the public MemoFlow identity confirmed for iPhone distribution.

#### Scenario: iOS display name is reviewed
- **WHEN** iOS bundle metadata is inspected
- **THEN** the user-visible app name SHALL be `MemoFlow`

#### Scenario: iOS bundle identifier is reviewed
- **WHEN** iOS bundle metadata is inspected
- **THEN** the bundle identifier SHALL be `com.memoflow.hzc073`
- **AND** public configuration SHALL NOT include Team ID, provisioning profile, certificate, App Store Connect key, notarization credential, or signing secret

### Requirement: iOS permissions SHALL match public full-feature scope
公开 iOS shell SHALL review permissions against the public feature scope, using Android `full` as a reference for base capabilities but not as permission auto-approval.

#### Scenario: iOS privacy descriptions are reviewed
- **WHEN** `memos_flutter_app/ios/Runner/Info.plist` declares camera, photo library, microphone, location, local network, notification, nearby discovery, share, or media access usage
- **THEN** each usage description SHALL map to a current public feature such as attachments, camera capture, voice memo, location attachment, local migration, reminders, or share handling
- **AND** the description SHALL NOT mention paid support, subscription, entitlement, StoreKit, Apple supporter status, private commercial features, or future-only capabilities

#### Scenario: Future private Apple capability is planned
- **WHEN** a planned private Apple capability needs iCloud, App Groups, Shortcuts/App Intents, Spotlight, StoreKit, receipt validation, or another Apple ecosystem entitlement
- **THEN** public iOS shell configuration SHALL NOT add that entitlement or permission unless a separate OpenSpec change approves a public non-commercial use

### Requirement: Public iOS shell SHALL remain commercial-free
公开 iOS shell SHALL not contain Apple commercial runtime behavior or business decisions.

#### Scenario: Public iOS files are scanned
- **WHEN** files under `memos_flutter_app/ios/`, public shell Dart files, platform seams, shared models, and private hook interfaces are scanned
- **THEN** they MUST NOT include StoreKit implementation, in-app purchase SDK wiring, product IDs, prices, purchase, restore purchase, receipt validation, raw entitlement state, paywall routing, signing secrets, App Store Connect credentials, TestFlight automation, or private release automation

#### Scenario: Private Apple support UI is available
- **WHEN** an Apple private overlay contributes purchase, restore, supporter, or entitlement UI
- **THEN** the public iOS shell SHALL receive it only through an approved private bundle contribution or product-level `AppCapability`
- **AND** public iOS code SHALL NOT infer commercial UI availability from `TargetPlatform.iOS` alone

### Requirement: iOS public shell guardrails SHALL protect the boundary
The system SHALL include focused guardrails that make public iOS shell regressions visible before release.

#### Scenario: iOS guardrail test runs
- **WHEN** architecture or public repository guardrails inspect iOS public shell files
- **THEN** they SHALL verify the public app identity, allowed permission posture, absence of commercial Apple runtime terms, and absence of signing or release secrets

#### Scenario: Restricted public shell files are reviewed
- **WHEN** changes touch `memos_flutter_app/lib/app.dart`, `memos_flutter_app/lib/main.dart`, `memos_flutter_app/lib/private_hooks/`, shared public models, or `memos_flutter_app/ios/`
- **THEN** the review SHALL confirm that no paid-feature state, commercial branch, private repository import, or `AccessDecision.source` business logic was introduced
