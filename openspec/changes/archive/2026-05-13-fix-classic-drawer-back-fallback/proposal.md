# Change: Fix classic drawer destination back fallback

## Summary

Fix Android/system back behavior for classic navigation drawer destinations whose route becomes the navigator root after drawer `pushReplacement`.

## Problem

在 classic navigation mode（无底部导航栏）下，用户从 home drawer 打开 `DraftBoxNavigationScreen` 或 `CollectionsScreen` 后，按一次系统返回会退出 app。当前观察到的路径是：

```text
HomeEntryScreen
  -> HomeScreen / MemosListScreen
      -> drawer destination
          -> closeDrawerThenPushReplacement(...)
              -> Draft Box / Collections becomes root route
                  -> system back exits app
```

Bottom navigation mode 不触发该问题，因为 `HomeBottomNavShell` 在 shell 内切换 `HomeRootDestination`，并通过 `PopScope` 把非 primary destination 的 back 转回 primary memos destination。

## Scope

- Add back-to-home fallback behavior for standalone/classic `DraftBoxNavigationScreen`.
- Add back-to-home fallback behavior for standalone/classic `CollectionsScreen`.
- Preserve embedded bottom navigation behavior through `HomeEmbeddedNavigationHost`.
- Preserve local nested route pop behavior, such as collection detail/editor routes and draft edit editor routes.
- Add focused widget tests covering classic/standalone back fallback for Draft Box and Collections.

## Out of Scope

- Redesigning `closeDrawerThenPushReplacement`.
- Changing bottom navigation destination switching behavior.
- Changing draft restore/edit behavior.
- Changing collection CRUD, collection detail, or reader behavior.
- Changing API, persistence models, commercial/private extension seams, or app startup routing.

## Modularity Notes

This change touches coupled navigation UI under `features`. It should leave the touched area equal or better structured by reusing existing seams:

- `HomeEntryScreen` for home fallback that respects workspace navigation preferences.
- `HomeEmbeddedNavigationHost` for shell-owned navigation.
- Existing route-local `Navigator` behavior for nested editors/details.

No new dependency from `state` or `application` to `features` should be introduced.
