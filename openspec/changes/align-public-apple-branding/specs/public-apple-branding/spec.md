## ADDED Requirements

### Requirement: Public Apple shell branding SHALL match the public brand name
The Apple platform public shell SHALL use the same public product name as the existing Android and Windows public brand, so the user-visible application identity is consistent across public platforms.

#### Scenario: macOS display name is rendered
- **WHEN** the public macOS application bundle is built
- **THEN** the visible product name SHALL present the public brand `MemoFlow`

### Requirement: Public Apple shell icon assets SHALL align with the public brand
The Apple platform public shell SHALL use icon assets that represent the public `MemoFlow` brand and SHALL not retain scaffold placeholder imagery.

#### Scenario: macOS app icon is packaged
- **WHEN** the public macOS application bundle is built
- **THEN** the packaged app icon SHALL match the public brand icon set used for the public release identity

### Requirement: Public Apple branding SHALL not introduce commercial Apple logic
Public Apple shell branding SHALL remain limited to non-commercial presentation metadata and assets. The public repository SHALL NOT add StoreKit, entitlement, receipt validation, pricing, signing secret, notarization, or App Store release automation behavior through this capability.

#### Scenario: A branding-only change is reviewed
- **WHEN** a change updates only Apple public branding
- **THEN** the change SHALL not require commercial runtime code, private product identifiers, or release automation
