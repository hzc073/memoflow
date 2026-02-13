import 'server_api_profile.dart';

enum MemosCurrentUserRoute {
  authSessionCurrent,
  authMe,
  authStatusPost,
  authStatusGet,
  authStatusV2,
  userMeV1,
  usersMeV1,
  userMeLegacy,
}

class MemosRouteAdapter {
  const MemosRouteAdapter({
    required this.profile,
    required this.currentUserRoutes,
    required this.requiresMemoFullView,
    required this.usesLegacyRowStatusFilterInListMemos,
    required this.sendsStateInListMemos,
  });

  final MemosServerApiProfile profile;
  final List<MemosCurrentUserRoute> currentUserRoutes;
  final bool requiresMemoFullView;
  final bool usesLegacyRowStatusFilterInListMemos;
  final bool sendsStateInListMemos;

  bool get usesRowStatusMemoStateField =>
      profile.memoStateField == MemosMemoStateRouteField.rowStatus;

  bool get requiresCreatorScopedListMemos =>
      profile.requiresCreatorScopedListMemos;

  bool get supportsMemoParentQuery => profile.supportsMemoParentQuery;
}

class MemosRouteAdapters {
  static const MemosVersionNumber _v026 = MemosVersionNumber(0, 26, 0);

  static MemosRouteAdapter fallback() {
    return resolve(
      profile: MemosServerApiProfiles.fallbackProfile,
      parsedVersion: MemosServerApiProfiles.tryParseVersion(
        MemosServerApiProfiles.fallbackVersion,
      ),
    );
  }

  static MemosRouteAdapter resolve({
    required MemosServerApiProfile profile,
    required MemosVersionNumber? parsedVersion,
  }) {
    return switch (profile.flavor) {
      MemosServerFlavor.v0_21 => MemosRouteAdapter(
        profile: profile,
        currentUserRoutes: const <MemosCurrentUserRoute>[
          MemosCurrentUserRoute.authStatusV2,
          MemosCurrentUserRoute.userMeV1,
          MemosCurrentUserRoute.userMeLegacy,
          MemosCurrentUserRoute.usersMeV1,
          MemosCurrentUserRoute.authStatusPost,
          MemosCurrentUserRoute.authStatusGet,
          MemosCurrentUserRoute.authSessionCurrent,
          MemosCurrentUserRoute.authMe,
        ],
        requiresMemoFullView: false,
        usesLegacyRowStatusFilterInListMemos: false,
        sendsStateInListMemos: true,
      ),
      MemosServerFlavor.v0_22 => MemosRouteAdapter(
        profile: profile,
        currentUserRoutes: const <MemosCurrentUserRoute>[
          MemosCurrentUserRoute.authStatusPost,
          MemosCurrentUserRoute.authStatusGet,
          MemosCurrentUserRoute.userMeV1,
          MemosCurrentUserRoute.userMeLegacy,
          MemosCurrentUserRoute.usersMeV1,
          MemosCurrentUserRoute.authStatusV2,
          MemosCurrentUserRoute.authSessionCurrent,
          MemosCurrentUserRoute.authMe,
        ],
        requiresMemoFullView: false,
        usesLegacyRowStatusFilterInListMemos: true,
        sendsStateInListMemos: false,
      ),
      MemosServerFlavor.v0_23 => MemosRouteAdapter(
        profile: profile,
        currentUserRoutes: const <MemosCurrentUserRoute>[
          MemosCurrentUserRoute.authStatusPost,
          MemosCurrentUserRoute.authStatusGet,
          MemosCurrentUserRoute.userMeV1,
          MemosCurrentUserRoute.userMeLegacy,
          MemosCurrentUserRoute.usersMeV1,
          MemosCurrentUserRoute.authStatusV2,
          MemosCurrentUserRoute.authSessionCurrent,
          MemosCurrentUserRoute.authMe,
        ],
        requiresMemoFullView: true,
        usesLegacyRowStatusFilterInListMemos: true,
        sendsStateInListMemos: false,
      ),
      MemosServerFlavor.v0_24 => MemosRouteAdapter(
        profile: profile,
        currentUserRoutes: const <MemosCurrentUserRoute>[
          MemosCurrentUserRoute.authStatusPost,
          MemosCurrentUserRoute.authStatusGet,
          MemosCurrentUserRoute.userMeV1,
          MemosCurrentUserRoute.userMeLegacy,
          MemosCurrentUserRoute.usersMeV1,
          MemosCurrentUserRoute.authStatusV2,
          MemosCurrentUserRoute.authSessionCurrent,
          MemosCurrentUserRoute.authMe,
        ],
        requiresMemoFullView: false,
        usesLegacyRowStatusFilterInListMemos: false,
        sendsStateInListMemos: true,
      ),
      MemosServerFlavor.v0_25Plus => _resolveV025Plus(
        profile: profile,
        parsedVersion: parsedVersion,
      ),
    };
  }

  static MemosRouteAdapter _resolveV025Plus({
    required MemosServerApiProfile profile,
    required MemosVersionNumber? parsedVersion,
  }) {
    final is026OrAbove = _isAtLeast(parsedVersion, _v026);
    return MemosRouteAdapter(
      profile: profile,
      currentUserRoutes: is026OrAbove
          ? const <MemosCurrentUserRoute>[
              MemosCurrentUserRoute.authMe,
              MemosCurrentUserRoute.authStatusV2,
              MemosCurrentUserRoute.authSessionCurrent,
              MemosCurrentUserRoute.userMeV1,
              MemosCurrentUserRoute.usersMeV1,
              MemosCurrentUserRoute.userMeLegacy,
              MemosCurrentUserRoute.authStatusPost,
              MemosCurrentUserRoute.authStatusGet,
            ]
          : const <MemosCurrentUserRoute>[
              MemosCurrentUserRoute.authSessionCurrent,
              MemosCurrentUserRoute.authStatusV2,
              MemosCurrentUserRoute.authMe,
              MemosCurrentUserRoute.userMeV1,
              MemosCurrentUserRoute.usersMeV1,
              MemosCurrentUserRoute.userMeLegacy,
              MemosCurrentUserRoute.authStatusPost,
              MemosCurrentUserRoute.authStatusGet,
            ],
      requiresMemoFullView: false,
      usesLegacyRowStatusFilterInListMemos: false,
      sendsStateInListMemos: true,
    );
  }

  static bool _isAtLeast(
    MemosVersionNumber? version,
    MemosVersionNumber target,
  ) {
    if (version == null) return false;
    return version >= target;
  }
}
