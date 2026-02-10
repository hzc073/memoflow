import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../data/models/user_setting.dart';
import '../../state/memos_providers.dart';
import '../../state/preferences_provider.dart';
import '../../state/session_provider.dart';
import '../../state/user_settings_provider.dart';
import '../../i18n/strings.g.dart';

class UserGeneralSettingsScreen extends ConsumerStatefulWidget {
  const UserGeneralSettingsScreen({super.key});

  @override
  ConsumerState<UserGeneralSettingsScreen> createState() => _UserGeneralSettingsScreenState();
}

class _UserGeneralSettingsScreenState extends ConsumerState<UserGeneralSettingsScreen> {
  var _saving = false;

  Future<void> _updateSetting(UserGeneralSetting current, {String? locale, String? visibility}) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final mask = <String>[];
      if (locale != null) mask.add('locale');
      if (visibility != null) mask.add('memoVisibility');

      final next = current.copyWith(
        locale: locale ?? current.locale,
        memoVisibility: visibility ?? current.memoVisibility,
      );
      final account = ref.read(appSessionProvider).valueOrNull?.currentAccount;
      if (account == null) {
        throw StateError('Not authenticated');
      }
      await ref.read(memosApiProvider).updateUserGeneralSetting(
            userName: account.user.name,
            setting: next,
            updateMask: mask,
          );
      ref.invalidate(userGeneralSettingProvider);
      if (!mounted) return;
      showTopToast(
        context,
        context.t.strings.legacy.msg_settings_updated,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.strings.legacy.msg_update_failed(e: e))),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _selectLocale(UserGeneralSetting current) async {
    final currentLocale = (current.locale ?? '').trim();
    const options = ['', 'en', 'zh-Hans'];
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(context.t.strings.legacy.msg_locale),
              ),
            ),
            for (final option in options)
              ListTile(
                leading: Icon(option == currentLocale ? Icons.radio_button_checked : Icons.radio_button_off),
                title: Text(_localeLabel(option)),
                onTap: () => context.safePop(option),
              ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final trimmed = result.trim();
    if (trimmed == currentLocale) return;
    await _updateSetting(current, locale: trimmed);
  }

  Future<void> _selectVisibility(UserGeneralSetting current) async {
    final currentVisibility = (current.memoVisibility ?? '').trim().isNotEmpty
        ? current.memoVisibility!.trim()
        : 'PRIVATE';
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(context.t.strings.legacy.msg_default_visibility),
              ),
            ),
            for (final option in const ['PRIVATE', 'PROTECTED', 'PUBLIC'])
              ListTile(
                leading: Icon(option == currentVisibility ? Icons.radio_button_checked : Icons.radio_button_off),
                title: Text(_visibilityLabel(option)),
                onTap: () => context.safePop(option),
              ),
          ],
        ),
      ),
    );
    if (result == null || result.trim().isEmpty) return;
    await _updateSetting(current, visibility: result.trim());
  }

  String _visibilityLabel(String value) {
    switch (value) {
      case 'PUBLIC':
        return context.t.strings.legacy.msg_public;
      case 'PROTECTED':
        return context.t.strings.legacy.msg_protected;
      default:
        return context.t.strings.legacy.msg_private_2;
    }
  }

  String _localeLabel(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return context.t.strings.legacy.msg_default;
    }
    if (normalized == 'en' || normalized.startsWith('en-')) {
      return context.t.strings.legacy.msg_english;
    }
    if (normalized == 'zh-hans' || normalized == 'zh_cn' || normalized == 'zh-cn') {
      return context.t.strings.legacy.msg_chinese_simplified;
    }
    if (normalized == 'zh-hant' || normalized == 'zh_tw' || normalized == 'zh-tw') {
      return context.t.strings.legacy.msg_chinese_traditional;
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final divider = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06);
    final hapticsEnabled = ref.watch(appPreferencesProvider.select((p) => p.hapticsEnabled));

    void maybeHaptic() {
      if (hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
    }

    final settingsAsync = ref.watch(userGeneralSettingProvider);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: context.t.strings.legacy.msg_back,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(context.t.strings.legacy.msg_user_general_settings),
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
          settingsAsync.when(
            data: (settings) {
              final locale = (settings.locale ?? '').trim();
              final visibility = (settings.memoVisibility ?? '').trim().isNotEmpty
                  ? settings.memoVisibility!.trim()
                  : 'PRIVATE';
              final localeLabel = _localeLabel(locale);

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                children: [
                  _Group(
                    card: card,
                    divider: divider,
                    children: [
                      _SelectRow(
                        label: context.t.strings.legacy.msg_locale,
                        value: localeLabel,
                        textMain: textMain,
                        textMuted: textMuted,
                        onTap: _saving
                            ? null
                            : () {
                                maybeHaptic();
                              _selectLocale(settings);
                              },
                      ),
                      _SelectRow(
                        label: context.t.strings.legacy.msg_default_visibility,
                        value: _visibilityLabel(visibility),
                        textMain: textMain,
                        textMuted: textMuted,
                        onTap: _saving
                            ? null
                            : () {
                                maybeHaptic();
                                _selectVisibility(settings);
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.t.strings.legacy.msg_these_settings_apply_newly_created_memos,
                    style: TextStyle(fontSize: 12, color: textMuted),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.t.strings.legacy.msg_failed_load_2,
                      style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => ref.invalidate(userGeneralSettingProvider),
                      child: Text(context.t.strings.legacy.msg_retry),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
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

class _SelectRow extends StatelessWidget {
  const _SelectRow({
    required this.label,
    required this.value,
    required this.textMain,
    required this.textMuted,
    this.onTap,
  });

  final String label;
  final String value;
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
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
                ),
              ),
              Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: textMuted)),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, size: 18, color: textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
