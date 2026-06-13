## MODIFIED Requirements

### Requirement: Apple UI migration coverage and progress tracking

The system SHALL track Apple UI migration coverage until all high-perception Apple UI areas are completed.

#### Scenario: Migration inventory

- **WHEN** implementation begins
- **THEN** the change MUST create or update a migration inventory covering scaffold / app bar / navigation, tab / sidebar / drawer, dialog / alert, bottom sheet / popup menu, picker, form controls, text input, grouped list / card, key icons, route transition / back gesture, scrolling, safe area, dark mode, dynamic type, accessibility, and macOS menu / window behavior

#### Scenario: Settings subpage batch progress

- **WHEN** each settings subpage platformization batch is completed
- **THEN** `tasks.md` or an associated OpenSpec note MUST identify which settings files are complete, in progress, deferred, exception-allowlisted, and still pending
- **AND** iPhone/iPadOS smoke coverage for migrated files SHALL be recorded

#### Scenario: Apple mobile settings regression is prevented

- **WHEN** settings subpage smoke tests run for migrated pages
- **THEN** they SHALL fail if `No Material widget found` or equivalent Flutter framework errors are thrown
- **AND** known crash classes such as Material chips inside Apple grouped settings content SHALL remain covered

#### Scenario: Completion standard

- **WHEN** the change is considered complete
- **THEN** high-perception Apple UI areas in home shell, settings, memo list, memo detail, memo editor, note input, collections, reminders, review, stats, and debug flows MUST either use the platform UI adapter or have a documented reason why existing behavior is acceptable on Apple platforms
