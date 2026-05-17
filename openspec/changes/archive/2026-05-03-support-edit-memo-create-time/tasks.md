## 1. Memo Time Adjustment UI

- [x] 1.1 Add a memo-card action for `Adjust time` near the existing edit action, hidden for archived/non-editable memo states.
- [x] 1.2 Add a detail-view access path for the same adjustment surface without adding a new always-visible AppBar icon.
- [x] 1.3 Create a shared feature-local time adjustment surface that initializes from `memo.effectiveDisplayTime`, supports cancel/save, and explains timeline ordering impact.
- [x] 1.4 Add or reuse localized strings for action label, sheet title, field labels, helper copy, cancel, and save states.

## 2. State and Local Persistence

- [x] 2.1 Add or extend a `state/memos` mutation seam for adjusting an existing memo timestamp from feature UI.
- [x] 2.2 Persist the selected timestamp into both local `create_time` and `display_time` while preserving existing content, visibility, pin, state, tags, attachments, location, and relations.
- [x] 2.3 Update local `update_time`, sync state, and provider/list refresh behavior consistently with other memo metadata mutations.
- [x] 2.4 Keep timestamp write logic out of widgets/screens; UI should only collect the selected time and call the state-layer seam.

## 3. Remote Sync Behavior

- [x] 3.1 Extend the queued `update_memo` payload for time adjustment to include explicit creation and display timestamp values.
- [x] 3.2 Update remote outbox handling to parse timestamp payloads and pass them to existing memo update API methods when processing `update_memo`.
- [x] 3.3 Preserve local adjusted time and existing sync error visibility when the remote server rejects unsupported timestamp updates.
- [x] 3.4 Pause for explicit user approval before editing any files under `memos_flutter_app/lib/data/api` or `memos_flutter_app/test/data/api`, if implementation discovers API-layer changes are required.

## 4. Focused Tests and Guardrails

- [x] 4.1 Add widget coverage that the memo card menu exposes `Adjust time` for editable normal memos and hides it for archived/read-only cases.
- [x] 4.2 Add widget coverage for opening the time adjustment surface, canceling without mutation, and saving a selected timestamp.
- [x] 4.3 Add state or database coverage that a saved adjustment updates both `create_time` and `display_time` and changes effective list ordering/display.
- [x] 4.4 Add sync/outbox coverage that timestamp adjustments enqueue and process explicit timestamp payloads.
- [x] 4.5 Add or run architecture guardrail coverage confirming no new `state -> features`, `application -> features`, or `core -> higher-layer` imports were introduced.

## 5. Verification

- [x] 5.1 Run focused Flutter tests for memo time adjustment UI and mutation behavior from `memos_flutter_app`.
- [x] 5.2 Run focused sync/outbox tests affected by timestamp payload handling.
- [x] 5.3 Run `flutter analyze` from `memos_flutter_app`.
- [x] 5.4 Run `flutter test` from `memos_flutter_app`, or document unrelated pre-existing failures.
