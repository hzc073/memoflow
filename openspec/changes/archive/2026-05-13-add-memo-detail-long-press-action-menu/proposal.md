## Why

GitHub issue #193 reports that when a memo is short, opening the memo detail page and interacting with the blank space below the memo content does not enter editing. The current detail implementation already supports double-tap edit on the primary memo content, but the editable hit area is scoped to the rendered content block rather than the whole detail body, so short or empty details expose a large non-interactive area.

The explored product direction is to use a long-press action menu at the pressed position, visually matching the home memo card more menu. This gives the blank area a clear contextual interaction without relying only on double-tap, and it can reuse the recently extracted home memo action popover visual language.

## What Changes

- Add a memo detail long-press entry point that opens an anchored action popover at the long-press position for editable memo detail surfaces.
- Reuse the home memo card more-menu popover style and action metadata where practical so detail actions and home card actions stay visually consistent.
- Keep existing double-tap edit behavior on memo detail content.
- Include normal memo actions such as copy, edit, reminder, pin/unpin, add to collection, archive, adjust time, history, and delete, subject to existing read-only and archived restrictions.
- For archived memos, expose only the existing archived-safe action subset such as copy, history, restore, and delete.
- Preserve existing interactive child gestures where applicable, including image preview, task toggles, links, audio rows, attachment rows, and selectable text behavior.
- Keep all action execution routed through existing detail-screen handlers or existing mutation seams; the popover only selects an action.

## Capabilities

### New Capabilities

- `memo-detail-action-menu`: Defines the memo detail long-press action menu, action availability, gesture boundaries, viewport-safe anchoring, and selection semantics.

### Modified Capabilities

- None.

## Impact

- Affected UI: `memos_flutter_app/lib/features/memos/memo_detail_screen.dart`, `memos_flutter_app/lib/features/memos/memo_detail_view.dart` only if a body-level wrapper is needed, and likely a focused helper under `memos_flutter_app/lib/features/memos/widgets`.
- Affected shared UI seam: `memos_flutter_app/lib/features/memos/widgets/memo_card_action_menu.dart` may be reused or lightly generalized so the detail menu can share the same popover surface without duplicating visual logic.
- Affected tests: add or update memo detail widget tests for long-press opening, action availability, action selection, archived/read-only behavior, empty-space hit testing, and interaction preservation around child controls.
- No API contract changes and no edits expected under `memos_flutter_app/lib/data/api` or `memos_flutter_app/test/data/api`.
- No subscription, billing, entitlement, paywall, or private-extension behavior.
- Architecture phase: `evolve_modularity`.
- Modularity checklist touched: item 4 (avoid hiding reused shared interaction/action logic inside screen files), item 6 (feature collaboration should prefer stable seams over direct screen imports), item 7 (touched write paths keep clear owners), item 8 (guardrail/widget tests protect behavior), and item 10 (touched coupled areas should be left equal or better structured).
- Modularity intent: do not add more action-menu branching directly into the already large `MemoDetailScreen`; extract a focused detail action-menu adapter or reuse the existing popover seam so the touched area stays equal or better structured.

## Non-Goals

- Do not remove or replace double-tap edit.
- Do not change Memos server APIs, request/response models, API compatibility tests, or sync route/version behavior.
- Do not redesign the memo detail page layout, markdown renderer, image preview, task toggle behavior, comments/engagement section, relations section, or attachment rendering.
- Do not make the popover execute mutations directly.
- Do not introduce commercial/private-extension logic.
