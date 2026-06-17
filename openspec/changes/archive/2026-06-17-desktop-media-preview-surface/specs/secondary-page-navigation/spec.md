## ADDED Requirements

### Requirement: Dedicated desktop media preview surfaces SHALL be classified separately from full-page secondary pages

独立桌面媒体查看 surface SHALL NOT be treated as a normal full-page secondary page. It SHALL use media-viewer close semantics instead of ordinary `Back + Page Title` secondary page chrome.

#### Scenario: Dedicated media surface root is shown on desktop
- **WHEN** a desktop image, video, or media attachment preview opens in a dedicated media surface
- **THEN** the media surface root SHALL NOT be required to render App-level Back navigation
- **AND** it SHALL NOT render ordinary secondary page `Back + Page Title` chrome
- **AND** native media-surface close and `Esc` SHALL be valid close paths for that viewer.

#### Scenario: Media fallback is immersive instead of ordinary secondary page
- **WHEN** desktop dedicated media-window capability is unavailable and the app uses a main-window fallback viewer
- **THEN** the fallback SHALL still be classified as a media viewer rather than an ordinary full-page secondary page
- **AND** it SHALL provide viewer-specific close behavior without restoring the old top-left AppBar Back button.

#### Scenario: Mobile media route keeps platform back behavior
- **WHEN** the same media preview is opened on phone or tablet
- **THEN** the existing fullscreen media route SHALL continue to use platform-appropriate Back or gesture navigation
- **AND** this desktop media-surface classification SHALL NOT remove mobile route back behavior.

#### Scenario: Ordinary secondary pages remain unchanged
- **WHEN** settings, share child pages, memo detail fallback pages, editors, or other non-media full-page secondary pages are shown
- **THEN** they SHALL continue to follow the existing secondary page navigation requirements
- **AND** the media-surface exception SHALL NOT be used to remove required Back navigation from unrelated pages.
