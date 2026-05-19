## Why

The public repository already uses `MemoFlow` branding for Android and Windows, while the checked-in macOS shell still exposes Flutter scaffold branding such as `memos_flutter_app`. This creates an avoidable public brand mismatch now that macOS scaffold files exist in the public checkout.

This change defines a narrow public-branding rule: Apple platform shell metadata may align with the public Android/Windows brand, without moving Apple commercial runtime, StoreKit, entitlement, signing, or release automation into the public repository.

## What Changes

- Define public Apple shell branding as allowed non-commercial metadata.
- Align public Apple display metadata with the existing public brand name `MemoFlow`.
- Align Apple app icon assets with the public brand icon used by Android and Windows.
- Keep Apple commercial metadata and release infrastructure outside the public repository.
- Preserve the `evolve_modularity` architecture phase; this change touches platform shell metadata only and does not affect the current Dart coupling hotspots.

## Capabilities

### New Capabilities

- `public-apple-branding`: Rules for Apple platform public shell branding, including allowed display names, public icons, and explicit commercial-boundary exclusions.

### Modified Capabilities

- None.

## Impact

- Affected areas:
  - `memos_flutter_app/macos/Runner/Configs/AppInfo.xcconfig`
  - `memos_flutter_app/macos/Runner/Info.plist`
  - `memos_flutter_app/macos/Runner/Assets.xcassets/AppIcon.appiconset/`
  - Public/private boundary documentation and specs
- No API route, API model, or API compatibility behavior changes.
- No new runtime dependency.
- No StoreKit, subscription, entitlement, receipt, pricing, signing secret, notarization, TestFlight, App Store, or private release automation behavior is introduced.
- Modularity impact: platform shell metadata only; no `state -> features`, `application -> features`, or `core -> higher-layer` dependencies are touched.
