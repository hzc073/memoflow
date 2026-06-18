## ADDED Requirements

### Requirement: Local public repository Guard SHALL block denylisted private capability content
公共仓库 SHALL provide a local Guard tool that blocks high-confidence private capability leakage before commit, after merge, and before push.

#### Scenario: Pre-commit checks staged content
- **WHEN** a developer commits from the public repository with hooks enabled
- **THEN** the pre-commit hook SHALL run `tools/memoflow_guard.sh check-staged`
- **AND** it SHALL fail if staged paths match denylisted private paths
- **AND** it SHALL fail if staged added lines contain denylisted private capability keywords
- **AND** it SHALL fail if configured Git remotes point to obvious private, StoreKit, IAP, App Store, release, billing, entitlement, commercial, or TestFlight destinations

#### Scenario: Merge and push check working tree
- **WHEN** a merge commit is created or a push is attempted with hooks enabled
- **THEN** the corresponding hook SHALL run `tools/memoflow_guard.sh check`
- **AND** it SHALL fail if denylisted private paths exist in tracked or untracked working tree files
- **AND** it SHALL fail if Git tracked text contains denylisted private capability keywords
- **AND** it SHALL fail if configured Git remotes point to obvious private, StoreKit, IAP, App Store, release, billing, entitlement, commercial, or TestFlight destinations

#### Scenario: Guard reports actionable failures
- **WHEN** the Guard finds one or more violations
- **THEN** it SHALL print each matched path, content hit, or remote hit
- **AND** it SHALL exit with a non-zero status so Git blocks the operation
- **AND** the message SHALL direct the developer to remove private content from the public repository or move it to the private overlay

### Requirement: Denylist SHALL be maintainable without disabling the Guard
公共仓库 SHALL keep private leakage rules in a repository-local denylist file that can be refined when legitimate public governance text would otherwise create false positives.

#### Scenario: Denylist is read as plain text rules
- **WHEN** `tools/memoflow_guard.sh` runs
- **THEN** it SHALL read `.memoflow-public-denylist`
- **AND** it SHALL ignore blank lines and lines whose first non-space character is `#`
- **AND** each remaining line SHALL be treated as a literal substring rule

#### Scenario: Existing public governance text remains allowed
- **WHEN** public documentation, OpenSpec artifacts, or guardrail tests describe public/private boundaries without containing high-confidence leaked implementation details
- **THEN** the local Guard SHOULD pass
- **AND** future false positives SHOULD be fixed by narrowing denylist rules or scanner scope rather than removing the Guard or hooks
