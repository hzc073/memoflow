import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../data/db/app_database.dart';
import '../../state/database_provider.dart';
import '../../state/personal_access_token_repository_provider.dart';
import '../../state/preferences_provider.dart';
import '../../state/session_provider.dart';
import '../auth/login_screen.dart';

class AccountSecurityScreen extends ConsumerWidget {
  const AccountSecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final divider = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06);
    final hapticsEnabled = ref.watch(appPreferencesProvider.select((p) => p.hapticsEnabled));

    void haptic() {
      if (hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
    }

    final session = ref.watch(appSessionProvider).valueOrNull;
    final accounts = session?.accounts ?? const [];
    final currentKey = session?.currentKey;
    final currentAccount = session?.currentAccount;
    final currentName = currentAccount == null
        ? context.tr(zh: '未登录', en: 'Not signed in')
        : (currentAccount.user.displayName.isNotEmpty
            ? currentAccount.user.displayName
            : (currentAccount.user.name.isNotEmpty ? currentAccount.user.name : context.tr(zh: '账号', en: 'Account')));

    Future<void> removeAccountAndClearCache(String accountKey) async {
      final wasCurrent = accountKey == currentKey;
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                wasCurrent
                    ? context.tr(zh: '退出登录？', en: 'Sign out?')
                    : context.tr(zh: '移除账号？', en: 'Remove account?'),
              ),
              content: Text(
                context.tr(
                  zh: '这会同时清除该账号的本地缓存（离线数据/草稿/待同步队列）。此操作无法撤销。',
                  en: 'This will also clear local cache for this account (offline data/drafts/pending sync queue). This action cannot be undone.',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(context.tr(zh: '取消', en: 'Cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(context.tr(zh: '确认', en: 'Confirm')),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return;

      final dbName = databaseNameForAccountKey(accountKey);
      try {
        await ref.read(appSessionProvider.notifier).removeAccount(accountKey);
        await AppDatabase.deleteDatabaseFile(dbName: dbName);
        await ref.read(personalAccessTokenRepositoryProvider).deleteForAccount(accountKey: accountKey);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr(zh: '本地缓存已清除', en: 'Local cache cleared'))),
        );
        if (wasCurrent) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr(zh: '操作失败：$e', en: 'Action failed: $e'))),
        );
      }
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: context.tr(zh: '返回', en: 'Back'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(context.tr(zh: '账号与安全', en: 'Account & Security')),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          if (isDark)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0B0B0B),
                      bg,
                      bg,
                    ],
                  ),
                ),
              ),
            ),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              _ProfileCard(
                card: card,
                textMain: textMain,
                textMuted: textMuted,
                title: currentName,
                subtitle: currentAccount?.baseUrl.toString() ?? '',
              ),
              const SizedBox(height: 12),
              _CardGroup(
                card: card,
                divider: divider,
                children: [
                  _SettingRow(
                    icon: Icons.person_add,
                    label: context.tr(zh: '添加账号', en: 'Add Account'),
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () {
                      haptic();
                      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LoginScreen()));
                    },
                  ),
                  if (currentKey != null)
                    _SettingRow(
                      icon: Icons.logout,
                      label: context.tr(zh: '退出登录', en: 'Sign Out'),
                      textMain: textMain,
                      textMuted: textMuted,
                      onTap: () async {
                        haptic();
                        await removeAccountAndClearCache(currentKey);
                      },
                    ),
                ],
              ),
              if (accounts.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  context.tr(zh: '账号', en: 'Accounts'),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textMuted),
                ),
                const SizedBox(height: 10),
                _CardGroup(
                  card: card,
                  divider: divider,
                  children: [
                    for (final a in accounts)
                      _AccountRow(
                        isCurrent: a.key == currentKey,
                        title: a.user.displayName.isNotEmpty
                            ? a.user.displayName
                            : (a.user.name.isNotEmpty ? a.user.name : a.key),
                        subtitle: a.baseUrl.toString(),
                        textMain: textMain,
                        textMuted: textMuted,
                        onTap: () {
                          haptic();
                          ref.read(appSessionProvider.notifier).switchAccount(a.key);
                        },
                        onDelete: () async {
                          haptic();
                          await removeAccountAndClearCache(a.key);
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Text(
                context.tr(
                  zh: '移除/退出将清除该账号的本地缓存（离线数据/草稿/待同步队列）。',
                  en: 'Removing/signing out will clear local cache for this account (offline data/drafts/pending sync queue).',
                ),
                style: TextStyle(fontSize: 12, height: 1.4, color: textMuted.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.title,
    required this.subtitle,
  });

  final Color card;
  final Color textMain;
  final Color textMuted;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  color: Colors.black.withValues(alpha: 0.06),
                ),
              ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
            child: Icon(Icons.person, color: textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: textMain)),
                if (subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: textMuted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardGroup extends StatelessWidget {
  const _CardGroup({
    required this.card,
    required this.divider,
    required this.children,
  });

  final Color card;
  final Color divider;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  color: Colors.black.withValues(alpha: 0.06),
                ),
              ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) Divider(height: 1, color: divider),
          ],
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.textMain,
    required this.textMuted,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color textMain;
  final Color textMuted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: textMuted),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: textMain))),
              Icon(Icons.chevron_right, size: 20, color: textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.isCurrent,
    required this.title,
    required this.subtitle,
    required this.textMain,
    required this.textMuted,
    required this.onTap,
    required this.onDelete,
  });

  final bool isCurrent;
  final String title;
  final String subtitle;
  final Color textMain;
  final Color textMuted;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(isCurrent ? Icons.radio_button_checked : Icons.radio_button_off, size: 20, color: textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: textMain)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: textMuted)),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.tr(zh: '移除', en: 'Remove'),
                icon: Icon(Icons.delete_outline, color: textMuted),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
