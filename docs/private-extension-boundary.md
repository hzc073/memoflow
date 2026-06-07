# Private Extension Boundary

This repository stays buildable as a standalone public app.

## Public shell rules
- Public shell code may depend only on `privateExtensionBundleProvider`.
- Public shell code may render extension entries returned by the bundle.
- Public shell code must not import access or commercial implementations directly.
- `settings_screen.dart` renders extension entries only; visibility decisions stay inside the bundle.

## Allowed public seam
- The only Dart overlay seam reserved for a private repository is `memos_flutter_app/lib/private_hooks/active_private_extension_bundle.dart`.

## Public vs private responsibility
- Public repository: memo core, sync, storage, UI shell, donor acknowledgement, general platform support, and non-commercial Apple public shell scaffolding such as macOS and iOS runners.
- Private repository: paid features, Apple commercial runtime, entitlement evaluation, product policy, store configuration, signing secrets, and related release automation.

## Diagnostic-only metadata
- `AccessDecision.source` is for diagnostics and logging only.
- `AccessDecision.source` must not be used for routing, visibility, unlocking, or any business branch.

## Repo hygiene rules
- Do not place private overlays inside this public repository.
- Do not add paid-feature state to shared session or preferences models.
- Do not route commercial decisions through update config or donor data.

## Current public decisions
- The donation entry and QR asset remain public.
- Crown state and crown persistence are removed from the public app.
- Donor acknowledgement remains public.
- Apple public shell scaffolding may live in the public repository when it is non-commercial and buildable without a private overlay.
- Apple commercial runtime, StoreKit, product IDs, prices, receipts, entitlement state, signing secrets, and TestFlight/App Store release automation stay private.
