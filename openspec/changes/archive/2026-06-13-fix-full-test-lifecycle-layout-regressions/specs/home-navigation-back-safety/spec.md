## ADDED Requirements

### Requirement: Shell-launched About routes SHALL contain long content without overflow

Shell-launched drawer routes that render `AboutScreen` SHALL preserve the home navigation shell and SHALL keep About content accessible under compact height constraints. Long content SHALL be scrollable or otherwise bounded rather than causing a Flutter vertical overflow.

#### Scenario: Bottom navigation shell opens About route
- **WHEN** the user opens the About drawer destination from `HomeBottomNavShell`
- **THEN** `AboutScreen` SHALL render without a vertical overflow under the route's available body height
- **AND** invoking system back SHALL dismiss the About route or return to the shell primary destination while `HomeBottomNavShell` remains mounted

#### Scenario: Standalone About fallback uses configured home entry
- **WHEN** standalone `AboutScreen` is displayed with bottom navigation preferences and system back is invoked
- **THEN** the route SHALL return through `HomeEntryScreen` or an equivalent configured home entry seam
- **AND** the About content layout SHALL NOT produce a Flutter bottom overflow before the fallback completes

#### Scenario: Settings About page keeps existing scroll seam
- **WHEN** `AboutUsScreen` is opened from settings
- **THEN** it SHALL continue to use `SettingsPage` or an equivalent settings semantic page seam for scrolling and page chrome
- **AND** the shell-launched About overflow fix SHALL NOT introduce nested scrolling into `AboutUsScreen`
