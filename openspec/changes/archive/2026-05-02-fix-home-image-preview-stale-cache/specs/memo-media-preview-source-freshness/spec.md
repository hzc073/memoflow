## ADDED Requirements

### Requirement: Home media preview uses current attachment sources
The app SHALL build home/list memo media preview entries from the current memo attachment source metadata, and SHALL NOT reuse cached preview items whose attachment source metadata no longer matches the memo.

#### Scenario: Local attachment moves from queued upload source to private attachment source
- **WHEN** a memo image attachment keeps the same memo uid, attachment count, and memo update time, but its `externalLink` changes from a queued upload file path to a private attachment file path
- **THEN** tapping the image from the home/list memo card opens preview using the private attachment file path

#### Scenario: Deleted queued source is not reused by home preview
- **WHEN** the old queued upload file no longer exists after local sync and the current attachment `externalLink` points to an existing local file
- **THEN** the home/list image preview request MUST NOT reference the deleted queued upload file

### Requirement: Media cache freshness includes attachment preview metadata
The app SHALL include attachment preview source metadata in any memo media entry cache identity used by home/list cards.

#### Scenario: Attachment source metadata changes without memo update time change
- **WHEN** an attachment changes any preview-relevant field such as `name`, `filename`, `type`, `size`, `externalLink`, `width`, `height`, or `hash` while the memo `updateTime` is unchanged
- **THEN** the home/list media cache MUST miss or be refreshed before constructing the next image preview request

#### Scenario: Unchanged attachment metadata may reuse cache
- **WHEN** memo identity, content fingerprint, account URL/auth flags, and attachment preview source metadata are unchanged
- **THEN** the home/list media cache MAY reuse the previously built media entries

### Requirement: Source freshness logic stays within feature boundaries
The app SHALL keep memo media source freshness logic in a feature-level helper or equivalent seam and SHALL NOT introduce new `state -> features`, `application -> features`, or `core -> features` dependencies for this behavior.

#### Scenario: Implementing cache key freshness
- **WHEN** the media cache key or fingerprint logic is changed
- **THEN** the dependency direction remains within `features/memos` and lower data model dependencies, without adding reverse dependencies from lower layers to feature UI code

### Requirement: Local sync migrates clip inline image sources
The app SHALL update third-party clip inline image references when LocalSync migrates a share-inline image attachment from a queued upload source to a private attachment source.

#### Scenario: Share-inline image upload finalizes to private file path
- **WHEN** LocalSync processes an `upload_attachment` task with `share_inline_image` enabled and copies the processed image to a private attachment file path
- **THEN** the memo content MUST replace the old `share_inline_local_url` or queued file URL with the private attachment file URL before the queued source is deleted

#### Scenario: Expanded clip does not render deleted queued path
- **WHEN** a third-party clip memo is expanded after LocalSync deletes the old queued upload source
- **THEN** inline images in the rendered memo content MUST NOT reference the deleted queued upload source

#### Scenario: Attachment metadata and inline content stay aligned
- **WHEN** LocalSync updates an image attachment `externalLink` to a private local file URL
- **THEN** any matching share-inline image reference in the same memo content MUST resolve to the same current local file URL
