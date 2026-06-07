# Private Bundle Template

Use this template inside the private repository when replacing `memos_flutter_app/lib/private_hooks/active_private_extension_bundle.dart`.

The goal is to keep the public shell unchanged while letting the Apple private repository contribute settings entries, startup hooks, and product-level capability decisions.

## Minimal template

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../access_boundary/access_boundary.dart';
import '../access_boundary/access_decision.dart';
import '../access_boundary/app_capability.dart';
import '../module_boundary/settings_entry_contribution.dart';
import 'private_extension_bundle.dart';

PrivateExtensionBundle createActivePrivateExtensionBundle() =>
    const _PrivateExtensionBundle();

class _PrivateExtensionBundle implements PrivateExtensionBundle {
  const _PrivateExtensionBundle();

  @override
  AccessBoundary get diagnosticsAccessBoundary => const _PrivateAccessBoundary();

  @override
  Future<void> onAppReady(WidgetRef ref) async {
    // Initialize private Apple billing / entitlement services here.
  }

  @override
  List<SettingsEntryContribution> settingsEntries(
    BuildContext context,
    WidgetRef ref,
  ) {
    return [
      SettingsEntryContribution(
        id: 'private-subscription-center',
        order: 100,
        icon: Icons.workspace_premium_outlined,
        titleBuilder: (_) => 'Subscription Center',
        subtitleBuilder: (_) => 'Manage private paid features',
        onTap: () {
          // Open private settings / subscription screen.
        },
      ),
    ];
  }
}

class _PrivateAccessBoundary implements AccessBoundary {
  const _PrivateAccessBoundary();

  @override
  AccessDecision decisionFor(AppCapability capability) {
    switch (capability) {
      case AppCapability.subscriptionCenter:
      case AppCapability.premiumEntitlements:
      case AppCapability.appleCommercialRuntime:
      case AppCapability.iosCommercialRuntime:
        return const AccessDecision(enabled: true, source: 'private-bundle');
    }
  }
}
```

## Important rules
- Do not change the public shell just to fit private code.
- Keep capability decisions inside the private bundle.
- Map macOS, iPhone, and iPadOS paid entitlement state to product-level `AppCapability` decisions before public code sees it.
- Let `settingsEntries(...)` decide whether a private entry exists.
- Never make public shell files branch on `AccessDecision.source`.
- Keep product IDs, receipts, pricing, and App Store details out of the public repository.

## Recommended private next steps
- Move billing adapters into a private package.
- Move entitlement evaluation into a private package.
- Keep the active bundle thin; it should orchestrate, not own, all private business logic.
