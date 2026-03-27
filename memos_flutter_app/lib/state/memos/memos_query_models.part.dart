part of 'memos_providers.dart';

typedef MemosQuery = ({
  String searchQuery,
  String state,
  String? tag,
  int? startTimeSec,
  int? endTimeSecExclusive,
  AdvancedSearchFilters advancedFilters,
  int pageSize,
});

typedef ShortcutMemosQuery = ({
  String searchQuery,
  String state,
  String? tag,
  String shortcutFilter,
  int? startTimeSec,
  int? endTimeSecExclusive,
  AdvancedSearchFilters advancedFilters,
  int pageSize,
});

typedef _CurrentAccountAuthContext = ({
  String key,
  String baseUrl,
  String personalAccessToken,
  String userName,
  String instanceVersion,
  String serverVersionOverride,
  bool? useLegacyApiOverride,
});

_CurrentAccountAuthContext? _currentAccountAuthContext(
  AsyncValue<AppSessionState> session,
) {
  final account = session.valueOrNull?.currentAccount;
  if (account == null) return null;
  return (
    key: account.key,
    baseUrl: account.baseUrl.toString(),
    personalAccessToken: account.personalAccessToken,
    userName: account.user.name,
    instanceVersion: account.instanceProfile.version.trim(),
    serverVersionOverride: (account.serverVersionOverride ?? '').trim(),
    useLegacyApiOverride: account.useLegacyApiOverride,
  );
}

enum QuickSearchKind { attachments, links, voice, onThisDay }

final RegExp _memoMarkdownLinkPattern = RegExp(
  r'\[[^\]]+\]\(([^)\s]+)\)',
  caseSensitive: false,
);
final RegExp _memoInlineUrlPattern = RegExp(
  r'(?:https?:\/\/|www\.)[^\s<>()]+',
  caseSensitive: false,
);

typedef QuickSearchMemosQuery = ({
  QuickSearchKind kind,
  String searchQuery,
  String state,
  String? tag,
  int? startTimeSec,
  int? endTimeSecExclusive,
  AdvancedSearchFilters advancedFilters,
  int pageSize,
});
