## Context

The public repository already carries Android and Windows branding for `MemoFlow`, while the checked-in macOS shell still reflects Flutter scaffold defaults in places such as `PRODUCT_NAME` and app icon assets. The desired outcome is to make Apple platform public shell branding consistent with the existing public brand without moving any private Apple commercial runtime into the public tree.

This change sits at the platform-shell boundary, not in shared business logic. It should not alter Dart feature routing, data models, synchronization behavior, or any commercial logic. The main stakeholders are public contributors, desktop release maintainers, and future private Apple overlay owners who need a stable public brand baseline.

## Goals / Non-Goals

**Goals:**
- Define a public Apple branding contract that matches the public `MemoFlow` identity.
- Keep the contract limited to display name, icon assets, and other non-commercial metadata.
- Make the boundary explicit so public Apple shell changes do not drift into StoreKit or entitlement space.

**Non-Goals:**
- Do not add or modify StoreKit, pricing, entitlement, receipt, or subscription behavior.
- Do not change API compatibility, data persistence, or sync behavior.
- Do not redefine the private Apple overlay ownership model beyond the public-branding boundary needed for this change.

## Decisions

1. **Use a dedicated `public-apple-branding` capability**
   The public rule set should live in one capability instead of being scattered across shell notes or generic desktop specs. This keeps the branding contract testable and keeps the scope limited to public Apple metadata.

   Alternatives considered:
   - Reusing a private-overlay capability: rejected because the desired behavior is explicitly public branding.
   - Folding this into general desktop branding: rejected because it would blur Apple-specific shell expectations.

2. **Treat name and icon as public presentation metadata**
   `PRODUCT_NAME`, bundle display name, and the app icon set are enough to align the visible brand. That satisfies the request without introducing runtime branching or commercial dependencies.

   Alternatives considered:
   - Updating every Apple signing and release setting at the same time: rejected because that crosses into private commercial release infrastructure.
   - Leaving the macOS scaffold name unchanged and only changing marketing text: rejected because the app identity would still mismatch in the OS shell.

3. **Keep commercial exclusions normative**
   The spec should explicitly forbid StoreKit, entitlement, receipt, pricing, signing, notarization, and App Store automation from entering the public repo through this branding work.

   Alternatives considered:
   - Relying on repository policy alone: rejected because the rule would be easy to miss during future shell cleanup.

## Risks / Trade-offs

- [Brand drift] → Keep the spec tied to the public brand source of truth and review Apple shell metadata whenever Android/Windows branding changes.
- [Boundary creep] → Explicitly exclude commercial Apple runtime and release behavior from the new capability.
- [Overfitting to current scaffold] → Keep the spec at the metadata level so future private Apple shell work can still overlay cleanly.

## Migration Plan

1. Approve the new public Apple branding capability.
2. Implement the Apple shell metadata and asset alignment under the public repository.
3. Verify the macOS build still works as a standalone public build.
4. Leave private Apple commercial runtime decisions in the private overlay path.

Rollback strategy:
- Revert the branding metadata and assets if the public Apple shell build or packaging becomes unstable.
- No data migration is required.

## Open Questions

- Should public Apple shell branding remain strictly aligned with Android/Windows forever, or may future platform-specific public presentation diverge slightly while keeping the same product name?
- Should the public repo eventually include any non-commercial iOS shell metadata, or remain macOS-only for Apple platforms?
