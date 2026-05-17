## Context

`ServerSettingsScreen` receives per-field `ServerSettingValue<int>` state from `serverSettingsProvider`. Editable known fields are rendered as `TextField`s whose controllers are synchronized back to the server-confirmed value whenever the field is not focused.

Chosen interaction:

```text
focus + clear memo field       -> show allowed byte range
focus + clear attachment field -> show current server upload limit
enter numeric text             -> hint disappears
blur while empty               -> field restores the server-confirmed value
```

This is a UI presentation refinement. No API, model, or provider ownership change is needed.

Dependency direction before and after remains:

```text
features/settings/ServerSettingsScreen
  -> state/settings/serverSettingsProvider
      -> data/api/MemosApi
      -> data/models/ServerSettingValue
```

The active architecture phase is `evolve_modularity`. This change does not touch a relevant coupling hotspot because it only formats existing UI state inside the settings widget and does not move shared server-setting parsing, permission classification, route selection, or write behavior.

## Goals / Non-Goals

**Goals:**

- Show field-specific `TextField.hintText` when an editable server limit field is empty.
- For memo content length, show the supported byte range instead of echoing the current configured value.
- For attachment upload capacity, keep showing the current server-confirmed upload limit.
- Preserve current controller sync behavior: an empty field that loses focus returns to the server-confirmed value.
- Add focused widget coverage for the empty-field hint behavior.

**Non-Goals:**

- Do not change server setting API routes, response parsing, permission classification, or merge-before-update behavior.
- Do not change `serverSettingsProvider` state ownership.
- Do not allow blank values to mean "unset", "default", or "unlimited".
- Do not invent a precise theoretical maximum for attachment upload capacity.
- Do not add helper text below the field that competes with validation, permission, or saved-state messages.

## Decisions

### Decision 1: Use `TextField.hintText` for gray placeholder guidance

Use `InputDecoration.hintText` instead of the message area below the field.

Rationale: the requested behavior is placeholder behavior. `hintText` appears only when the text is empty and disappears automatically when the user types. The existing message area already carries validation errors, permission messages, unavailable states, and save feedback.

Alternative considered: show separate helper text below the input. This was rejected because it would need extra priority rules with existing messages and could make the screen noisy.

### Decision 2: Keep hint content field-specific

The memo field uses static supported-range copy:

```text
en memo: Allowed range: 1-2147483647 bytes
```

The attachment field keeps the current-limit copy:

```text
en attachment: Current server limit: 64 MiB
```

Rationale: memo content length is a bounded integer field in the supported server setting shape, so range guidance is more useful than repeating the configured value. Attachment upload capacity can be affected by deployment limits outside the Memos setting, such as reverse proxies and storage backend behavior, so keeping the current-limit hint avoids implying a precise universal maximum.

Alternative considered: show supported-range style hints for both fields. This was rejected for attachment upload because the practical upload ceiling is deployment-dependent.

### Decision 3: Keep blur behavior aligned with existing `_syncController`

Do not introduce persistent blank edit state. If the user clears a field and then the field loses focus, `_syncController` should restore the current server-confirmed value.

Rationale: this preserves the low-risk方案 A behavior and avoids introducing dirty-state flags, reset buttons, or a new "blank but unsaved" state.

Alternative considered: keep the field blank after blur. This was rejected because it requires extra local edit-state tracking and makes it less clear whether the blank value is pending, invalid, or merely a hint surface.

## Risks / Trade-offs

- [Risk] Exact text assertions can become brittle if copy changes. -> Mitigation: keep the copy short and test only the focused behavior and representative hints.
- [Risk] The memo range may look like a UX guarantee beyond local validation. -> Mitigation: keep existing save/API feedback unchanged; the server remains the final authority.
- [Risk] Adding hint logic directly to the widget could grow into broader domain formatting. -> Mitigation: keep it limited to display text derived from existing state and constants; do not add API/provider logic.

## Migration Plan

No data migration is required.

Implementation rollout:

1. Add field-specific hint formatting to the server settings limit input presentation.
2. Add focused widget tests for clearing fields, hint visibility, text entry behavior, and blur restoration.
3. Run the focused settings test file, then standard checks.

Rollback is straightforward: remove the hint text wiring and focused tests.

## Open Questions

- None. Attachment upload remains on current-limit hint behavior; memo content length uses supported byte-range guidance.
