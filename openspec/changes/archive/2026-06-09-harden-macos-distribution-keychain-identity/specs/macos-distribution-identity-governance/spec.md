## ADDED Requirements

### Requirement: macOS production distribution identity SHALL remain stable

macOS 正式分发版 SHALL 使用稳定的生产应用身份。生产 `Bundle ID`、生产 `Keychain service` 和正式签名身份一经发布 SHALL NOT 因本地测试、DMG 文件名、版本号、构建目录或临时打包方式而变化。

#### Scenario: Production DMG app identity is reviewed

- **WHEN** 最终 DMG 被挂载并检查其中的 `MemoFlow.app`
- **THEN** app SHALL use production `Bundle ID` `com.memoflow.hzc073`
- **AND** app SHALL use production Keychain service `com.memoflow.hzc073.secure.production` at runtime
- **AND** app SHALL be signed with the approved production distribution identity

#### Scenario: Production channel is explicit

- **WHEN** macOS production DMG is built
- **THEN** build or packaging flow SHALL explicitly select the production channel
- **AND** production channel selection SHALL drive the production Keychain service
- **AND** production channel selection SHALL be verifiable before publishing the DMG

### Requirement: macOS development and test builds SHALL NOT share production Keychain storage

macOS debug、profile、本地 release、ad-hoc、未公证测试构建和临时 QA 构建 SHALL NOT read or write the production Keychain service. 这些构建 SHALL 使用与正式分发版不同的 `Bundle ID` 或等价隔离身份，并使用不同的 Keychain service。

#### Scenario: Development build reads secure storage

- **GIVEN** app 以 development 或 local testing channel 运行
- **WHEN** app reads or writes secure storage on macOS
- **THEN** it SHALL use development Keychain service `com.memoflow.hzc073.secure.dev`
- **AND** it SHALL NOT read or write production Keychain service `com.memoflow.hzc073.secure.production`

#### Scenario: Ad-hoc or temporary build is created

- **WHEN** a macOS ad-hoc, unsigned, locally signed, or temporary QA build is created
- **THEN** it SHALL NOT use the production `Bundle ID` and production Keychain service together
- **AND** it SHALL NOT be allowed to pollute production Keychain access control entries

### Requirement: macOS secure storage SHALL use explicit channel-specific service names

macOS secure storage SHALL configure `flutter_secure_storage` with explicit channel-specific `MacOsOptions(accountName: ...)` rather than relying on the implicit default `flutter_secure_storage_service` as the long-term production service.

#### Scenario: Production secure storage options are created

- **WHEN** production macOS runtime creates secure storage options
- **THEN** `MacOsOptions.accountName` SHALL be set to the approved production service name
- **AND** the service name SHALL NOT be `flutter_secure_storage_service`

#### Scenario: Development secure storage options are created

- **WHEN** development or local testing macOS runtime creates secure storage options
- **THEN** `MacOsOptions.accountName` SHALL be set to `com.memoflow.hzc073.secure.dev` for development builds or `com.memoflow.hzc073.secure.qa` for QA/testing builds
- **AND** that service name SHALL be distinct from production service name `com.memoflow.hzc073.secure.production`

### Requirement: First macOS production release SHALL NOT migrate legacy Keychain storage

第一版 macOS production runtime SHALL NOT read, copy, delete, or migrate existing values from legacy default service `flutter_secure_storage_service`. This avoids triggering legacy Keychain authorization prompts during first release startup. Future legacy migration MUST be approved by a separate rule update or change.

#### Scenario: Production service is empty on first release

- **GIVEN** production app starts after the service-name change
- **AND** production service `com.memoflow.hzc073.secure.production` does not contain existing values
- **WHEN** startup reads macOS secure storage
- **THEN** the app SHALL read only production service `com.memoflow.hzc073.secure.production`
- **AND** it SHALL NOT read legacy service `flutter_secure_storage_service`
- **AND** it SHALL keep a path for the user to login or configure secure settings

#### Scenario: Legacy service contains old values

- **GIVEN** legacy service `flutter_secure_storage_service` contains old MemoFlow values
- **WHEN** production app starts
- **THEN** first-release startup SHALL NOT inspect, read, copy, delete, or migrate those old values
- **AND** startup SHALL NOT trigger Keychain authorization solely to access the legacy service

#### Scenario: Future migration is requested

- **WHEN** a future change wants to migrate values from `flutter_secure_storage_service`
- **THEN** that change SHALL update this capability with explicit migration behavior
- **AND** it SHALL define whether old values are read, copied, retained, or deleted
- **AND** it SHALL document that reading legacy values may trigger one-time legacy Keychain authorization prompts

### Requirement: macOS DMG publishing SHALL validate the final app bundle

macOS DMG publishing SHALL validate the `MemoFlow.app` contained in the final DMG, not only intermediate build folders. Validation SHALL reject ad-hoc signatures, debug entitlements, missing notarization, and mismatched production identity.

#### Scenario: Final DMG signature is verified

- **WHEN** a macOS DMG is prepared for distribution
- **THEN** validation SHALL mount the DMG and inspect the contained `MemoFlow.app`
- **AND** `codesign` output SHALL NOT report `Signature=adhoc`
- **AND** `codesign` output SHALL include the expected `Developer ID Application` authority and `TeamIdentifier`
- **AND** entitlements SHALL NOT include `com.apple.security.get-task-allow`

#### Scenario: Final DMG Gatekeeper acceptance is verified

- **WHEN** a macOS DMG is prepared for distribution
- **THEN** `spctl -a -vvv -t exec` on the contained app SHALL be accepted
- **AND** validation SHALL confirm the app is notarized or the DMG is otherwise accepted by the intended Developer ID distribution policy

#### Scenario: Final DMG identity matches production channel

- **WHEN** validation inspects the contained `MemoFlow.app`
- **THEN** its `Bundle ID` SHALL be `com.memoflow.hzc073`
- **AND** its runtime channel SHALL map to production Keychain service `com.memoflow.hzc073.secure.production`

### Requirement: Public repository SHALL keep distribution governance commercially neutral

macOS distribution identity and Keychain governance rules SHALL remain commercially neutral in the public repository. Public code and OpenSpec artifacts MAY describe non-secret identity and validation requirements, but SHALL NOT include signing secrets, private release credentials, StoreKit runtime, subscription logic, receipt validation, product IDs, prices, or private entitlement implementations.

#### Scenario: Distribution governance artifacts are reviewed

- **WHEN** OpenSpec artifacts, docs, scripts, or guardrails for macOS distribution governance are reviewed
- **THEN** they SHALL NOT include certificates, private keys, app-specific passwords, App Store Connect API keys, notarization credentials, provisioning profiles, StoreKit purchase code, receipt validation, subscription state, product IDs, or prices
- **AND** non-secret validation of signing status, `Bundle ID`, entitlements, notarization, and channel-specific Keychain service MAY remain in the public repository
