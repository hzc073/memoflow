# Private Overlay Workflow

This document describes how to continue private commercial development without moving commercial code back into the public repository.

## Goal
- Keep the public repository buildable on its own.
- Keep commercial / billing / entitlement code in a private repository.
- Connect private features only through the reserved seam in `memos_flutter_app/lib/private_hooks/active_private_extension_bundle.dart`.

## Recommended private repository layout
Use a separate private repository, for example:

```text
private-memoflow/
  overlay/
    memos_flutter_app/
      lib/
        private_hooks/
          active_private_extension_bundle.dart
  packages/
    private_billing/
    private_entitlements/
```

## What the public repository may know
- The public app may know that a bundle exists.
- The public app may render settings entries returned by the bundle.
- The public app may notify the bundle once the app is ready.

## What the public repository must not know
- Product identifiers
- Subscription tiers
- Receipt or entitlement data
- App Store verification logic
- StoreKit-specific runtime branching

## Public shell contract
- `app.dart` may call `privateExtensionBundleProvider` only.
- `settings_screen.dart` may render `SettingsEntryContribution` only.
- `settings_screen.dart` must not perform capability checks.
- `AccessDecision.source` is diagnostic-only metadata.

## Private implementation flow
1. Checkout the public repository into a clean working directory.
2. Apply the private overlay on top of the public checkout.
3. Replace only the reserved seam file under `private_hooks`.
4. Add private package dependencies from the private repository.
5. Build and release from the private pipeline, not from the public GitHub workflow.

## Things that stay public
- Donation entry and QR asset
- Donor acknowledgement UI and donor update data
- Generic shell, storage, sync, memo core, and non-commercial platform code

## Things that stay private
- Billing adapters
- Entitlement evaluation
- Commercial runtime adapters
- Store configuration and release secrets
- Private build scripts and App Store release automation
