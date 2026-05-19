## 1. Apple Public Branding Alignment

- [x] 1.1 Update macOS public shell product metadata so the visible application name uses `MemoFlow`.
- [x] 1.2 Verify `Info.plist` resolves display metadata from the public product name rather than hardcoded scaffold branding.
- [x] 1.3 Replace or regenerate the macOS `AppIcon.appiconset` assets from the public brand icon source.

## 2. Boundary Protection

- [x] 2.1 Review the touched Apple shell files for commercial Apple leakage such as StoreKit, entitlement, receipt, pricing, signing secret, notarization, TestFlight, or App Store release automation content.
- [x] 2.2 Confirm the change does not touch Dart runtime commercial seams, API code, shared public models, or architecture coupling hotspots.

## 3. Verification

- [x] 3.1 Run a focused repository search to confirm scaffold branding no longer appears in macOS user-visible product metadata.
- [x] 3.2 Run the relevant macOS build or metadata inspection command from `memos_flutter_app` to verify the public app bundle presents `MemoFlow`.
- [x] 3.3 Report any verification command that cannot be run locally, including the reason and residual risk.
