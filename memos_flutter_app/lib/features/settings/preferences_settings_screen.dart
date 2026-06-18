import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../core/app_motion.dart';
import '../../core/app_route_transitions.dart';
import '../../core/app_localization.dart';
import '../../core/app_typography_policy.dart';
import '../../core/memoflow_palette.dart';
import '../../core/system_fonts.dart';
import '../../core/tags.dart';
import '../../core/theme_colors.dart';
import '../../core/top_toast.dart';
import '../../platform/platform_route.dart';
import '../../platform/widgets/platform_controls.dart';
import '../../platform/widgets/platform_dialog.dart';
import '../../platform/widgets/platform_picker.dart';
import '../../data/models/app_preferences.dart';
import '../../data/models/device_preferences.dart';
import '../../data/models/workspace_preferences.dart';
import '../../i18n/strings.g.dart';
import '../../platform/platform_target.dart';
import '../../state/maintenance/self_repair_mutation_service.dart';
import '../../state/settings/device_preferences_provider.dart';
import '../../state/settings/resolved_preferences_provider.dart';
import '../../state/settings/workspace_preferences_provider.dart';
import '../../state/system/system_fonts_provider.dart';
import 'settings_ui.dart';
import 'memo_toolbar_settings_screen.dart';

final tagRecognitionRecomputeInProgressProvider = StateProvider.autoDispose((
  ref,
) {
  return false;
});

class PreferencesSettingsScreen extends ConsumerWidget {
  const PreferencesSettingsScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  Future<void> _selectEnum<T>({
    required BuildContext context,
    required String title,
    required List<T> values,
    required String Function(T v) label,
    required T selected,
    required ValueChanged<T> onSelect,
  }) async {
    final next = await showSettingsSingleChoicePicker<T>(
      context: context,
      title: title,
      value: selected,
      options: [
        for (final value in values)
          SettingsChoiceOption<T>(value: value, label: label(value)),
      ],
      maxWidth: 440,
    );
    if (next == null || !context.mounted) return;
    onSelect(next);
  }

  Future<void> _selectFont({
    required BuildContext context,
    required WidgetRef ref,
    required DevicePreferences prefs,
    required List<SystemFontInfo> fonts,
  }) async {
    final systemDefault = SystemFontInfo(
      family: '',
      displayName: context.t.strings.settings.preferences.systemDefault,
    );
    final selectedFamily = prefs.fontFamily?.trim() ?? '';
    Widget fontContent(BuildContext context) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            SettingsSection(
              header: Text(context.t.strings.settings.preferences.font),
              children: [
                for (final font in [systemDefault, ...fonts])
                  SettingsCustomRow(
                    leading: Icon(
                      font.family == selectedFamily
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    title: SettingsRowTitle(font.displayName),
                    onTap: () async {
                      context.safePop();
                      if (font.isSystemDefault) {
                        ref
                            .read(devicePreferencesProvider.notifier)
                            .setFontFamily(family: null, filePath: null);
                        return;
                      }
                      await SystemFonts.ensureLoaded(font);
                      if (!context.mounted) return;
                      ref
                          .read(devicePreferencesProvider.notifier)
                          .setFontFamily(
                            family: font.family,
                            filePath: font.filePath,
                          );
                    },
                  ),
                if (fonts.isEmpty)
                  SettingsInfoRow(
                    description:
                        context.t.strings.settings.preferences.noSystemFonts,
                  ),
              ],
            ),
          ],
        ),
      );
    }

    await showPlatformPicker<void>(
      context: context,
      desktopMaxWidth: 720,
      builder: fontContent,
    );
  }

  Future<void> _showTagRecognitionHelp(BuildContext context) {
    final strings = context.t.strings.settings.preferences.tagRecognition;
    return showPlatformAlertDialog<void>(
      context: context,
      title: strings.helpTitle,
      message: strings.helpMessage,
      actions: [
        PlatformDialogAction<void>(
          value: null,
          label: context.t.strings.legacy.msg_ok,
          isDefault: true,
        ),
      ],
    );
  }

  String _tagRecognitionPolicyLabel(
    BuildContext context,
    TagRecognitionPolicy policy,
  ) {
    final strings = context.t.strings.settings.preferences.tagRecognition;
    return switch (policy.kind) {
      TagRecognitionPolicyKind.memoflowStrict => strings.strict,
      TagRecognitionPolicyKind.memosCompatible => strings.compatible,
      TagRecognitionPolicyKind.custom => strings.custom,
    };
  }

  List<SettingsChoiceOption<TagRecognitionPolicyKind>>
  _tagRecognitionPolicyOptions(BuildContext context) {
    final strings = context.t.strings.settings.preferences.tagRecognition;
    return [
      SettingsChoiceOption<TagRecognitionPolicyKind>(
        value: TagRecognitionPolicyKind.memoflowStrict,
        label: strings.strict,
        description: strings.strictDescription,
        icon: Icons.filter_alt_outlined,
      ),
      SettingsChoiceOption<TagRecognitionPolicyKind>(
        value: TagRecognitionPolicyKind.memosCompatible,
        label: strings.compatible,
        description: strings.compatibleDescription,
        icon: Icons.tag_outlined,
      ),
      SettingsChoiceOption<TagRecognitionPolicyKind>(
        value: TagRecognitionPolicyKind.custom,
        label: strings.custom,
        description: strings.customDescription,
        icon: Icons.tune_outlined,
      ),
    ];
  }

  Future<TagRecognitionPolicy?> _showCustomTagRecognitionPolicyEditor({
    required BuildContext context,
    required TagRecognitionPolicy initial,
  }) {
    return showPlatformPicker<TagRecognitionPolicy>(
      context: context,
      desktopMaxWidth: 560,
      builder: (_) =>
          _TagRecognitionCustomPolicySheet(initial: initial.asCustom()),
    );
  }

  Future<void> _selectTagRecognitionPolicy({
    required BuildContext context,
    required WidgetRef ref,
    required WorkspacePreferences prefs,
  }) async {
    final strings = context.t.strings.settings.preferences.tagRecognition;
    if (ref.read(tagRecognitionRecomputeInProgressProvider)) return;

    final selected =
        await showSettingsSingleChoicePicker<TagRecognitionPolicyKind>(
          context: context,
          title: strings.title,
          value: prefs.tagRecognitionPolicy.kind,
          options: _tagRecognitionPolicyOptions(context),
          maxWidth: 480,
        );
    if (selected == null || !context.mounted) return;

    final TagRecognitionPolicy? nextPolicy;
    switch (selected) {
      case TagRecognitionPolicyKind.memoflowStrict:
        nextPolicy = TagRecognitionPolicy.memoflowStrict;
      case TagRecognitionPolicyKind.memosCompatible:
        nextPolicy = TagRecognitionPolicy.memosCompatible;
      case TagRecognitionPolicyKind.custom:
        nextPolicy = await _showCustomTagRecognitionPolicyEditor(
          context: context,
          initial: prefs.tagRecognitionPolicy,
        );
    }
    if (nextPolicy == null || !context.mounted) return;
    if (nextPolicy == prefs.tagRecognitionPolicy) return;

    ref
        .read(currentWorkspacePreferencesProvider.notifier)
        .setTagRecognitionPolicy(nextPolicy);

    final recompute = await showSettingsConfirmationDialog(
      context: context,
      title: strings.recomputeTitle,
      message: strings.recomputeMessage,
      confirmLabel: strings.recomputeNow,
      cancelLabel: strings.recomputeSkip,
    );
    if (!recompute || !context.mounted) return;

    ref.read(tagRecognitionRecomputeInProgressProvider.notifier).state = true;
    try {
      await ref
          .read(selfRepairMutationServiceProvider)
          .recomputeTagRecognitionPolicy(nextPolicy);
      if (!context.mounted) return;
      showTopToast(context, strings.recomputeSuccess);
    } catch (error) {
      if (!context.mounted) return;
      showTopToast(context, strings.recomputeFailed(error: error));
    } finally {
      if (context.mounted) {
        ref.read(tagRecognitionRecomputeInProgressProvider.notifier).state =
            false;
      }
    }
  }

  String _fontLabel(
    BuildContext context,
    DevicePreferences prefs,
    List<SystemFontInfo> fonts, {
    required bool canChooseSystemFonts,
  }) {
    if (!canChooseSystemFonts) {
      return context.t.strings.settings.preferences.systemDefault;
    }
    final family = prefs.fontFamily?.trim() ?? '';
    if (family.isEmpty) {
      return context.t.strings.settings.preferences.systemDefault;
    }
    for (final font in fonts) {
      if (font.family == family) return font.displayName;
    }
    return family;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicePrefs = ref.watch(devicePreferencesProvider);
    final workspacePrefs = ref.watch(currentWorkspacePreferencesProvider);
    final deviceNotifier = ref.read(devicePreferencesProvider.notifier);
    final workspaceNotifier = ref.read(
      currentWorkspacePreferencesProvider.notifier,
    );
    final workspaceKey = ref.watch(currentWorkspaceKeyProvider);
    final resolvedSettings = ref.watch(resolvedAppSettingsProvider);

    void setThemeColor(AppThemeColor color) {
      if (workspaceKey == null) {
        deviceNotifier.setThemeColor(color);
        return;
      }
      workspaceNotifier.setThemeColorOverride(color);
    }

    void setCustomTheme(CustomThemeSettings settings) {
      if (workspaceKey == null) {
        deviceNotifier.setCustomTheme(settings);
        return;
      }
      workspaceNotifier.setCustomThemeOverride(settings);
    }

    final themeMode = devicePrefs.themeMode;
    final themeModeLabel = themeMode.labelFor(devicePrefs.language);
    final themeColor = resolvedSettings.resolvedThemeColor;
    final customTheme = resolvedSettings.resolvedCustomTheme;
    final canChooseSystemFonts =
        !isAppleMobilePlatform() && canChooseSystemFontsForPlatform();
    final fontsAsync = canChooseSystemFonts
        ? ref.watch(systemFontsProvider)
        : null;
    final fontLabel = _fontLabel(
      context,
      devicePrefs,
      fontsAsync?.valueOrNull ?? const [],
      canChooseSystemFonts: canChooseSystemFonts,
    );
    final tagRecognitionLabel = _tagRecognitionPolicyLabel(
      context,
      workspacePrefs.tagRecognitionPolicy,
    );
    final tagRecognitionRecomputing = ref.watch(
      tagRecognitionRecomputeInProgressProvider,
    );

    final tokens = settingsPageTokens(context);

    return SettingsPage(
      showBackButton: showBackButton,
      title: Text(context.t.strings.settings.preferences.title),
      contentKey: const ValueKey<String>('preferences.boundedContent'),
      children: [
        SettingsSection(
          children: [
            SettingsValueRow(
              label: context.t.strings.settings.preferences.language,
              value: devicePrefs.language.labelFor(devicePrefs.language),
              icon: Icons.expand_more,
              onTap: () => _selectEnum<AppLanguage>(
                context: context,
                title: context.t.strings.settings.preferences.language,
                values: AppLanguage.values,
                label: (v) => v.labelFor(devicePrefs.language),
                selected: devicePrefs.language,
                onSelect: deviceNotifier.setLanguage,
              ),
            ),
            SettingsValueRow(
              label: context.t.strings.settings.preferences.fontSize,
              value: devicePrefs.fontSize.labelFor(devicePrefs.language),
              onTap: () => _selectEnum<AppFontSize>(
                context: context,
                title: context.t.strings.settings.preferences.fontSize,
                values: AppFontSize.values,
                label: (v) => v.labelFor(devicePrefs.language),
                selected: devicePrefs.fontSize,
                onSelect: deviceNotifier.setFontSize,
              ),
            ),
            SettingsValueRow(
              label: context.t.strings.settings.preferences.lineHeight,
              value: devicePrefs.lineHeight.labelFor(devicePrefs.language),
              onTap: () => _selectEnum<AppLineHeight>(
                context: context,
                title: context.t.strings.settings.preferences.lineHeight,
                values: AppLineHeight.values,
                label: (v) => v.labelFor(devicePrefs.language),
                selected: devicePrefs.lineHeight,
                onSelect: deviceNotifier.setLineHeight,
              ),
            ),
            SettingsValueRow(
              label: context.t.strings.settings.preferences.font,
              value: fontLabel,
              enabled: canChooseSystemFonts,
              onTap: () async {
                if (!canChooseSystemFonts) return;
                try {
                  final List<SystemFontInfo> fonts =
                      fontsAsync?.valueOrNull ??
                      await ref.read(systemFontsProvider.future);
                  if (!context.mounted) return;
                  await _selectFont(
                    context: context,
                    ref: ref,
                    prefs: devicePrefs,
                    fonts: fonts,
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.t.strings.settings.preferences.loadFontsFailed(
                          error: e.toString(),
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
            SettingsToggleRow(
              label: context.t.strings.settings.preferences.collapseLongContent,
              value: workspacePrefs.collapseLongContent,
              onChanged: workspaceNotifier.setCollapseLongContent,
            ),
            SettingsToggleRow(
              label: context.t.strings.settings.preferences.collapseReferences,
              value: workspacePrefs.collapseReferences,
              onChanged: workspaceNotifier.setCollapseReferences,
            ),
            if (!resolvedSettings.isLocalLibraryMode)
              SettingsToggleRow(
                label:
                    context.t.strings.settings.preferences.showMemoEngagement,
                value: workspacePrefs.showMemoEngagement,
                onChanged: workspaceNotifier.setShowMemoEngagement,
              ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsSection(
          children: [
            SettingsValueRow(
              label: context.t.strings.settings.preferences.launchAction,
              value: devicePrefs.launchAction.labelFor(devicePrefs.language),
              icon: Icons.expand_more,
              onTap: () => _selectEnum<LaunchAction>(
                context: context,
                title: context.t.strings.settings.preferences.launchAction,
                values: LaunchAction.values
                    .where((v) => v != LaunchAction.sync)
                    .toList(growable: false),
                label: (v) => v.labelFor(devicePrefs.language),
                selected: devicePrefs.launchAction,
                onSelect: deviceNotifier.setLaunchAction,
              ),
            ),
            SettingsToggleRow(
              label: context.t.strings.settings.preferences.confirmExitOnBack,
              value: devicePrefs.confirmExitOnBack,
              onChanged: deviceNotifier.setConfirmExitOnBack,
            ),
            SettingsValueRow(
              key: const ValueKey('preferences-editor-toolbar-entry'),
              label: context.t.strings.settings.preferences.editorToolbar.title,
              value: context
                  .t
                  .strings
                  .settings
                  .preferences
                  .editorToolbar
                  .dragToSort,
              onTap: () => Navigator.of(context).push(
                buildPlatformPageRoute<void>(
                  context: context,
                  builder: (_) => const MemoToolbarSettingsScreen(),
                ),
              ),
            ),
            _TagRecognitionPolicyRow(
              label:
                  context.t.strings.settings.preferences.tagRecognition.title,
              helpTooltip: context
                  .t
                  .strings
                  .settings
                  .preferences
                  .tagRecognition
                  .helpTitle,
              value: tagRecognitionRecomputing
                  ? context
                        .t
                        .strings
                        .settings
                        .preferences
                        .tagRecognition
                        .recomputeInProgress
                  : tagRecognitionLabel,
              busy: tagRecognitionRecomputing,
              enabled: !tagRecognitionRecomputing,
              onHelp: () => _showTagRecognitionHelp(context),
              onTap: () => _selectTagRecognitionPolicy(
                context: context,
                ref: ref,
                prefs: workspacePrefs,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsSection(
          children: [
            SettingsValueRow(
              label: context.t.strings.settings.preferences.appearance,
              value: themeModeLabel,
              icon: Icons.expand_more,
              onTap: () => _selectEnum<AppThemeMode>(
                context: context,
                title: context.t.strings.settings.preferences.appearance,
                values: const [
                  AppThemeMode.system,
                  AppThemeMode.light,
                  AppThemeMode.dark,
                ],
                label: (v) => v.labelFor(devicePrefs.language),
                selected: themeMode,
                onSelect: deviceNotifier.setThemeMode,
              ),
            ),
            _ThemeColorRow(
              label: context.t.strings.settings.preferences.themeColor,
              selected: themeColor,
              textMain: tokens.textMain,
              isDark: tokens.isDark,
              onSelect: setThemeColor,
              onCustomTap: () async {
                final next = await CustomThemeDialog.show(
                  context: context,
                  initial: customTheme,
                );
                if (next == null || !context.mounted) return;
                setCustomTheme(next);
                setThemeColor(AppThemeColor.custom);
              },
            ),
            SettingsToggleRow(
              label: context.t.strings.settings.preferences.haptics,
              value: devicePrefs.hapticsEnabled,
              onChanged: deviceNotifier.setHapticsEnabled,
            ),
          ],
        ),
      ],
    );
  }
}

class _TagRecognitionPolicyRow extends StatelessWidget {
  const _TagRecognitionPolicyRow({
    required this.label,
    required this.helpTooltip,
    required this.value,
    required this.busy,
    required this.enabled,
    required this.onHelp,
    required this.onTap,
  });

  final String label;
  final String helpTooltip;
  final String value;
  final bool busy;
  final bool enabled;
  final VoidCallback onHelp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    return SettingsCustomRow(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: SettingsRowTitle(label)),
          const SizedBox(width: 6),
          Tooltip(
            message: helpTooltip,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
              padding: EdgeInsets.zero,
              iconSize: 17,
              color: tokens.textMuted,
              onPressed: enabled ? onHelp : null,
              icon: const Icon(Icons.help_outline),
            ),
          ),
        ],
      ),
      value: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: tokens.textMuted,
        ),
      ),
      trailing: busy
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: tokens.textMuted,
              ),
            )
          : Icon(Icons.chevron_right, size: 18, color: tokens.textMuted),
      onTap: enabled ? onTap : null,
      enabled: enabled,
      valueMaxWidthFactor: 0.34,
    );
  }
}

class _TagRecognitionCustomPolicySheet extends StatefulWidget {
  const _TagRecognitionCustomPolicySheet({required this.initial});

  final TagRecognitionPolicy initial;

  @override
  State<_TagRecognitionCustomPolicySheet> createState() =>
      _TagRecognitionCustomPolicySheetState();
}

class _TagRecognitionCustomPolicySheetState
    extends State<_TagRecognitionCustomPolicySheet> {
  late TagRecognitionCustomOptions _options;

  @override
  void initState() {
    super.initState();
    _options = widget.initial.options;
  }

  void _update(TagRecognitionCustomOptions next) {
    setState(() => _options = next);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.t.strings.settings.preferences.tagRecognition;
    final tokens = settingsPageTokens(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;

    return SafeArea(
      child: ColoredBox(
        color: tokens.background,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: SettingsContentHeader(
                  title: strings.customTitle,
                  prominent: true,
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SettingsSection(
                        children: [
                          SettingsInfoRow(description: strings.customIntro),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SettingsSection(
                        children: [
                          _TagRecognitionOptionToggleRow(
                            label: strings.strictFirstLine,
                            tip: strings.strictFirstLineTip,
                            value: _options.strictFirstLine,
                            onChanged: (value) => _update(
                              _options.copyWith(strictFirstLine: value),
                            ),
                          ),
                          _TagRecognitionOptionToggleRow(
                            label: strings.strictLastLine,
                            tip: strings.strictLastLineTip,
                            value: _options.strictLastLine,
                            onChanged: (value) => _update(
                              _options.copyWith(strictLastLine: value),
                            ),
                          ),
                          _TagRecognitionOptionToggleRow(
                            label: strings.strictAnyLine,
                            tip: strings.strictAnyLineTip,
                            value: _options.strictAnyLine,
                            onChanged: (value) => _update(
                              _options.copyWith(strictAnyLine: value),
                            ),
                          ),
                          _TagRecognitionOptionToggleRow(
                            label: strings.inlineBodyTags,
                            tip: strings.inlineBodyTagsTip,
                            value: _options.inlineBodyTags,
                            onChanged: (value) => _update(
                              _options.copyWith(inlineBodyTags: value),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SettingsSection(
                        children: [
                          _TagRecognitionOptionToggleRow(
                            label: strings.numericOnlyTags,
                            tip: strings.numericOnlyTagsTip,
                            value: _options.numericOnlyTags,
                            onChanged: (value) => _update(
                              _options.copyWith(numericOnlyTags: value),
                            ),
                          ),
                          _TagRecognitionOptionToggleRow(
                            label: strings.hierarchicalTags,
                            tip: strings.hierarchicalTagsTip,
                            value: _options.hierarchicalTags,
                            onChanged: (value) => _update(
                              _options.copyWith(hierarchicalTags: value),
                            ),
                          ),
                          _TagRecognitionOptionToggleRow(
                            label: strings.emojiAndSymbolTags,
                            tip: strings.emojiAndSymbolTagsTip,
                            value: _options.emojiAndSymbolTags,
                            onChanged: (value) => _update(
                              _options.copyWith(emojiAndSymbolTags: value),
                            ),
                          ),
                          _TagRecognitionOptionToggleRow(
                            label: strings.mergeRemoteTags,
                            tip: strings.mergeRemoteTagsTip,
                            value:
                                _options.remoteTagHandling ==
                                RemoteTagHandling.mergeRemote,
                            onChanged: (value) => _update(
                              _options.copyWith(
                                remoteTagHandling: value
                                    ? RemoteTagHandling.mergeRemote
                                    : RemoteTagHandling.localContentAuthority,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: Text(context.t.strings.common.cancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).pop(TagRecognitionPolicy.custom(_options)),
                        child: Text(context.t.strings.common.save),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagRecognitionOptionToggleRow extends StatelessWidget {
  const _TagRecognitionOptionToggleRow({
    required this.label,
    required this.tip,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String tip;
  final bool value;
  final ValueChanged<bool> onChanged;

  Future<void> _showHelpDialog(BuildContext context) {
    return showPlatformAlertDialog<void>(
      context: context,
      title: label,
      message: tip,
      actions: [
        PlatformDialogAction<void>(
          value: null,
          label: context.t.strings.legacy.msg_ok,
          isDefault: true,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    return SettingsCustomRow(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: SettingsRowTitle(label)),
          const SizedBox(width: 6),
          IconButton(
            tooltip: label,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 24, height: 24),
            padding: EdgeInsets.zero,
            iconSize: 16,
            color: tokens.textMuted,
            onPressed: () => _showHelpDialog(context),
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      trailing: PlatformSwitch(value: value, onChanged: onChanged),
      onTap: () => onChanged(!value),
    );
  }
}

class _ThemeColorRow extends StatelessWidget {
  const _ThemeColorRow({
    required this.label,
    required this.selected,
    required this.textMain,
    required this.isDark,
    required this.onSelect,
    required this.onCustomTap,
  });

  final String label;
  final AppThemeColor selected;
  final Color textMain;
  final bool isDark;
  final ValueChanged<AppThemeColor> onSelect;
  final VoidCallback onCustomTap;

  @override
  Widget build(BuildContext context) {
    final ringColor = textMain.withValues(alpha: isDark ? 0.28 : 0.18);

    return SettingsCustomRow(
      title: SettingsRowTitle(label, color: textMain),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final color in AppThemeColor.values) ...[
            if (color == AppThemeColor.custom)
              _CustomThemeColorDot(
                selected: color == selected,
                ringColor: ringColor,
                onTap: onCustomTap,
              )
            else
              _ThemeColorDot(
                color: color,
                selected: color == selected,
                ringColor: ringColor,
                onTap: () => onSelect(color),
              ),
            if (color != AppThemeColor.values.last) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _ThemeColorDot extends StatelessWidget {
  const _ThemeColorDot({
    required this.color,
    required this.selected,
    required this.ringColor,
    required this.onTap,
  });

  final AppThemeColor color;
  final bool selected;
  final Color ringColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spec = themeColorSpec(color);
    final fill = spec.primary;
    final size = 22.0;
    final ringPadding = selected ? 2.0 : 0.0;

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: AppMotion.effectiveDuration(context, AppMotion.fast),
          curve: AppMotion.standardCurve,
          padding: EdgeInsets.all(ringPadding),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: selected ? Border.all(color: ringColor, width: 1.4) : null,
          ),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
            child: selected
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
        ),
      ),
    );
  }
}

class _CustomThemeColorDot extends StatelessWidget {
  const _CustomThemeColorDot({
    required this.selected,
    required this.ringColor,
    required this.onTap,
  });

  final bool selected;
  final Color ringColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const size = 22.0;
    final ringPadding = selected ? 2.0 : 0.0;
    const gradient = SweepGradient(
      colors: [
        Color(0xFFE55B5B),
        Color(0xFFF2C879),
        Color(0xFF7BB98A),
        Color(0xFF5FB1C2),
        Color(0xFF5E7CE0),
        Color(0xFFB36BD3),
        Color(0xFFE55B5B),
      ],
    );

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: AppMotion.effectiveDuration(context, AppMotion.fast),
          curve: AppMotion.standardCurve,
          padding: EdgeInsets.all(ringPadding),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: selected ? Border.all(color: ringColor, width: 1.4) : null,
          ),
          child: Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: gradient,
            ),
            child: Icon(
              selected ? Icons.check : Icons.add,
              size: 14,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class CustomThemeDialog extends StatefulWidget {
  const CustomThemeDialog({super.key, required this.initial});

  final CustomThemeSettings initial;

  static Future<CustomThemeSettings?> show({
    required BuildContext context,
    required CustomThemeSettings initial,
  }) {
    return Navigator.of(context, rootNavigator: true).push<CustomThemeSettings>(
      buildDialogScaleRoute<CustomThemeSettings>(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.35),
        builder: (_) => CustomThemeDialog(initial: initial),
      ),
    );
  }

  @override
  State<CustomThemeDialog> createState() => _CustomThemeDialogState();
}

class _CustomThemeDialogState extends State<CustomThemeDialog> {
  late CustomThemeMode _mode;
  late Color _autoLight;
  late Color _manualLight;
  late Color _manualDark;
  late CustomThemeSurfaces _manualSurfacesLight;
  late CustomThemeSurfaces _manualSurfacesDark;
  late List<CustomThemeColorPair> _history;

  late TextEditingController _autoHexController;
  late TextEditingController _manualLightHexController;
  late TextEditingController _manualDarkHexController;
  late TextEditingController _surfaceLightBackgroundController;
  late TextEditingController _surfaceLightCardController;
  late TextEditingController _surfaceLightBorderController;
  late TextEditingController _surfaceDarkBackgroundController;
  late TextEditingController _surfaceDarkCardController;
  late TextEditingController _surfaceDarkBorderController;

  bool _suppressHexUpdate = false;
  bool _linkLightSurfaces = true;
  bool _linkDarkSurfaces = true;

  @override
  void initState() {
    super.initState();
    _mode = widget.initial.mode;
    _autoLight = widget.initial.autoLight;
    _manualLight = widget.initial.manualLight;
    _manualDark = widget.initial.manualDark;
    _manualSurfacesLight = widget.initial.manualSurfacesLight;
    _manualSurfacesDark = widget.initial.manualSurfacesDark;
    _history = List<CustomThemeColorPair>.from(widget.initial.history);
    _autoHexController = TextEditingController(text: _formatHex(_autoLight));
    _manualLightHexController = TextEditingController(
      text: _formatHex(_manualLight),
    );
    _manualDarkHexController = TextEditingController(
      text: _formatHex(_manualDark),
    );
    _surfaceLightBackgroundController = TextEditingController(
      text: _formatHex(_manualSurfacesLight.background),
    );
    _surfaceLightCardController = TextEditingController(
      text: _formatHex(_manualSurfacesLight.card),
    );
    _surfaceLightBorderController = TextEditingController(
      text: _formatHex(_manualSurfacesLight.border),
    );
    _surfaceDarkBackgroundController = TextEditingController(
      text: _formatHex(_manualSurfacesDark.background),
    );
    _surfaceDarkCardController = TextEditingController(
      text: _formatHex(_manualSurfacesDark.card),
    );
    _surfaceDarkBorderController = TextEditingController(
      text: _formatHex(_manualSurfacesDark.border),
    );
    _linkLightSurfaces = _manualSurfacesLight.matches(
      deriveThemeSurfaces(seed: _manualLight, brightness: Brightness.light),
    );
    _linkDarkSurfaces = _manualSurfacesDark.matches(
      deriveThemeSurfaces(seed: _manualDark, brightness: Brightness.dark),
    );
  }

  @override
  void dispose() {
    _autoHexController.dispose();
    _manualLightHexController.dispose();
    _manualDarkHexController.dispose();
    _surfaceLightBackgroundController.dispose();
    _surfaceLightCardController.dispose();
    _surfaceLightBorderController.dispose();
    _surfaceDarkBackgroundController.dispose();
    _surfaceDarkCardController.dispose();
    _surfaceDarkBorderController.dispose();
    super.dispose();
  }

  String _formatHex(Color color) {
    final value = color.toARGB32() & 0x00FFFFFF;
    return value.toRadixString(16).padLeft(6, '0').toUpperCase();
  }

  Color? _parseHex(String raw) {
    if (raw.length != 6) return null;
    final parsed = int.tryParse(raw, radix: 16);
    if (parsed == null) return null;
    return Color(0xFF000000 | parsed);
  }

  void _syncHex(TextEditingController controller, Color color) {
    final next = _formatHex(color);
    if (controller.text.toUpperCase() == next) return;
    _suppressHexUpdate = true;
    controller.text = next;
    controller.selection = TextSelection.collapsed(offset: next.length);
    _suppressHexUpdate = false;
  }

  void _handleHexChanged(String value, ValueChanged<Color> onColorChanged) {
    if (_suppressHexUpdate) return;
    final color = _parseHex(value);
    if (color == null) return;
    onColorChanged(color);
  }

  void _updateAutoLight(Color color) {
    setState(() => _autoLight = color);
    _syncHex(_autoHexController, color);
  }

  void _updateManualLight(Color color) {
    setState(() => _manualLight = color);
    _syncHex(_manualLightHexController, color);
    if (_linkLightSurfaces) {
      _updateManualSurfacesLight(
        deriveThemeSurfaces(seed: color, brightness: Brightness.light),
      );
    }
  }

  void _updateManualDark(Color color) {
    setState(() => _manualDark = color);
    _syncHex(_manualDarkHexController, color);
    if (_linkDarkSurfaces) {
      _updateManualSurfacesDark(
        deriveThemeSurfaces(seed: color, brightness: Brightness.dark),
      );
    }
  }

  void _updateManualSurfacesLight(
    CustomThemeSurfaces surfaces, {
    bool linked = true,
  }) {
    setState(() {
      _manualSurfacesLight = surfaces;
      _linkLightSurfaces = linked;
    });
    _syncHex(_surfaceLightBackgroundController, surfaces.background);
    _syncHex(_surfaceLightCardController, surfaces.card);
    _syncHex(_surfaceLightBorderController, surfaces.border);
  }

  void _updateManualSurfacesDark(
    CustomThemeSurfaces surfaces, {
    bool linked = true,
  }) {
    setState(() {
      _manualSurfacesDark = surfaces;
      _linkDarkSurfaces = linked;
    });
    _syncHex(_surfaceDarkBackgroundController, surfaces.background);
    _syncHex(_surfaceDarkCardController, surfaces.card);
    _syncHex(_surfaceDarkBorderController, surfaces.border);
  }

  void _updateSurfaceColor({
    required bool isLight,
    required _SurfaceSlot slot,
    required Color color,
  }) {
    if (isLight) {
      final next = _manualSurfacesLight.copyWith(
        background: slot == _SurfaceSlot.background ? color : null,
        card: slot == _SurfaceSlot.card ? color : null,
        border: slot == _SurfaceSlot.border ? color : null,
      );
      _updateManualSurfacesLight(next, linked: false);
    } else {
      final next = _manualSurfacesDark.copyWith(
        background: slot == _SurfaceSlot.background ? color : null,
        card: slot == _SurfaceSlot.card ? color : null,
        border: slot == _SurfaceSlot.border ? color : null,
      );
      _updateManualSurfacesDark(next, linked: false);
    }
  }

  Future<void> _pickSurfaceColor({
    required String title,
    required bool isLight,
    required _SurfaceSlot slot,
    required Color color,
  }) async {
    final picked = await _SurfaceColorDialog.show(
      context: context,
      title: title,
      initial: color,
    );
    if (picked == null || !mounted) return;
    _updateSurfaceColor(isLight: isLight, slot: slot, color: picked);
  }

  void _applyHistory(CustomThemeColorPair pair) {
    if (_mode == CustomThemeMode.auto) {
      _updateAutoLight(pair.light);
      return;
    }
    _updateManualLight(pair.light);
    _updateManualDark(pair.dark);
  }

  void _save() {
    final pair = _mode == CustomThemeMode.manual
        ? CustomThemeColorPair(light: _manualLight, dark: _manualDark)
        : CustomThemeColorPair(
            light: _autoLight,
            dark: deriveAutoDarkColor(_autoLight),
          );
    final nextHistory = <CustomThemeColorPair>[pair, ..._history];
    if (nextHistory.length > 4) {
      nextHistory.removeRange(4, nextHistory.length);
    }
    final next = CustomThemeSettings(
      mode: _mode,
      autoLight: _autoLight,
      manualLight: _manualLight,
      manualDark: _manualDark,
      manualSurfacesLight: _manualSurfacesLight,
      manualSurfacesDark: _manualSurfacesDark,
      history: nextHistory,
    );
    Navigator.of(context).pop(next);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? MemoFlowPalette.cardDark : Colors.white;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.6 : 0.55);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final field = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final accent = MemoFlowPalette.primary;
    final shadow = Colors.black.withValues(alpha: 0.16);
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 26,
                    offset: const Offset(0, 18),
                    color: shadow,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SettingsContentHeader(
                      title: context.t.strings.settings.preferences.customTheme,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    _ModeToggle(
                      mode: _mode,
                      accent: accent,
                      field: field,
                      border: border,
                      textMuted: textMuted,
                      onSelect: (mode) => setState(() => _mode = mode),
                    ),
                    const SizedBox(height: 14),
                    if (_mode == CustomThemeMode.auto) ...[
                      _ColorSquarePicker(
                        color: _autoLight,
                        height: 180,
                        border: border,
                        onChanged: _updateAutoLight,
                      ),
                      const SizedBox(height: 10),
                      _HexInputRow(
                        controller: _autoHexController,
                        color: _autoLight,
                        field: field,
                        border: border,
                        textMain: textMain,
                        textMuted: textMuted,
                        onChanged: (value) =>
                            _handleHexChanged(value, _updateAutoLight),
                      ),
                      if (_history.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _HistoryRow(
                          title: context.t.strings.settings.preferences.history,
                          entries: _history,
                          border: border,
                          onTap: _applyHistory,
                        ),
                      ],
                    ] else ...[
                      SettingsSectionHeader(
                        title: context.t.strings.settings.preferences.lightMode,
                        caption: 'LIGHT MODE',
                      ),
                      const SizedBox(height: 8),
                      _ColorSquarePicker(
                        color: _manualLight,
                        height: 150,
                        border: border,
                        onChanged: _updateManualLight,
                      ),
                      const SizedBox(height: 10),
                      _HexInputRow(
                        controller: _manualLightHexController,
                        color: _manualLight,
                        field: field,
                        border: border,
                        textMain: textMain,
                        textMuted: textMuted,
                        onChanged: (value) =>
                            _handleHexChanged(value, _updateManualLight),
                      ),
                      const SizedBox(height: 12),
                      SettingsSectionHeader(
                        title: context.t.strings.settings.preferences.surfaces,
                      ),
                      const SizedBox(height: 8),
                      _SurfaceColorRow(
                        label:
                            context.t.strings.settings.preferences.background,
                        controller: _surfaceLightBackgroundController,
                        color: _manualSurfacesLight.background,
                        field: field,
                        border: border,
                        textMain: textMain,
                        textMuted: textMuted,
                        onChanged: (value) => _handleHexChanged(
                          value,
                          (color) => _updateSurfaceColor(
                            isLight: true,
                            slot: _SurfaceSlot.background,
                            color: color,
                          ),
                        ),
                        onPick: () => _pickSurfaceColor(
                          title: context
                              .t
                              .strings
                              .settings
                              .preferences
                              .backgroundColor,
                          isLight: true,
                          slot: _SurfaceSlot.background,
                          color: _manualSurfacesLight.background,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SurfaceColorRow(
                        label: context.t.strings.settings.preferences.card,
                        controller: _surfaceLightCardController,
                        color: _manualSurfacesLight.card,
                        field: field,
                        border: border,
                        textMain: textMain,
                        textMuted: textMuted,
                        onChanged: (value) => _handleHexChanged(
                          value,
                          (color) => _updateSurfaceColor(
                            isLight: true,
                            slot: _SurfaceSlot.card,
                            color: color,
                          ),
                        ),
                        onPick: () => _pickSurfaceColor(
                          title:
                              context.t.strings.settings.preferences.cardColor,
                          isLight: true,
                          slot: _SurfaceSlot.card,
                          color: _manualSurfacesLight.card,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SurfaceColorRow(
                        label: context.t.strings.settings.preferences.border,
                        controller: _surfaceLightBorderController,
                        color: _manualSurfacesLight.border,
                        field: field,
                        border: border,
                        textMain: textMain,
                        textMuted: textMuted,
                        onChanged: (value) => _handleHexChanged(
                          value,
                          (color) => _updateSurfaceColor(
                            isLight: true,
                            slot: _SurfaceSlot.border,
                            color: color,
                          ),
                        ),
                        onPick: () => _pickSurfaceColor(
                          title: context
                              .t
                              .strings
                              .settings
                              .preferences
                              .borderColor,
                          isLight: true,
                          slot: _SurfaceSlot.border,
                          color: _manualSurfacesLight.border,
                        ),
                      ),
                      if (_history.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _HistoryRow(
                          title: context.t.strings.settings.preferences.history,
                          entries: _history,
                          border: border,
                          onTap: _applyHistory,
                        ),
                      ],
                      const SizedBox(height: 16),
                      SettingsSectionHeader(
                        title: context.t.strings.settings.preferences.darkMode,
                        caption: 'DARK MODE',
                      ),
                      const SizedBox(height: 8),
                      _ColorSquarePicker(
                        color: _manualDark,
                        height: 150,
                        border: border,
                        onChanged: _updateManualDark,
                      ),
                      const SizedBox(height: 10),
                      _HexInputRow(
                        controller: _manualDarkHexController,
                        color: _manualDark,
                        field: field,
                        border: border,
                        textMain: textMain,
                        textMuted: textMuted,
                        onChanged: (value) =>
                            _handleHexChanged(value, _updateManualDark),
                      ),
                      const SizedBox(height: 12),
                      SettingsSectionHeader(
                        title: context.t.strings.settings.preferences.surfaces,
                      ),
                      const SizedBox(height: 8),
                      _SurfaceColorRow(
                        label:
                            context.t.strings.settings.preferences.background,
                        controller: _surfaceDarkBackgroundController,
                        color: _manualSurfacesDark.background,
                        field: field,
                        border: border,
                        textMain: textMain,
                        textMuted: textMuted,
                        onChanged: (value) => _handleHexChanged(
                          value,
                          (color) => _updateSurfaceColor(
                            isLight: false,
                            slot: _SurfaceSlot.background,
                            color: color,
                          ),
                        ),
                        onPick: () => _pickSurfaceColor(
                          title: context
                              .t
                              .strings
                              .settings
                              .preferences
                              .backgroundColor,
                          isLight: false,
                          slot: _SurfaceSlot.background,
                          color: _manualSurfacesDark.background,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SurfaceColorRow(
                        label: context.t.strings.settings.preferences.card,
                        controller: _surfaceDarkCardController,
                        color: _manualSurfacesDark.card,
                        field: field,
                        border: border,
                        textMain: textMain,
                        textMuted: textMuted,
                        onChanged: (value) => _handleHexChanged(
                          value,
                          (color) => _updateSurfaceColor(
                            isLight: false,
                            slot: _SurfaceSlot.card,
                            color: color,
                          ),
                        ),
                        onPick: () => _pickSurfaceColor(
                          title:
                              context.t.strings.settings.preferences.cardColor,
                          isLight: false,
                          slot: _SurfaceSlot.card,
                          color: _manualSurfacesDark.card,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SurfaceColorRow(
                        label: context.t.strings.settings.preferences.border,
                        controller: _surfaceDarkBorderController,
                        color: _manualSurfacesDark.border,
                        field: field,
                        border: border,
                        textMain: textMain,
                        textMuted: textMuted,
                        onChanged: (value) => _handleHexChanged(
                          value,
                          (color) => _updateSurfaceColor(
                            isLight: false,
                            slot: _SurfaceSlot.border,
                            color: color,
                          ),
                        ),
                        onPick: () => _pickSurfaceColor(
                          title: context
                              .t
                              .strings
                              .settings
                              .preferences
                              .borderColor,
                          isLight: false,
                          slot: _SurfaceSlot.border,
                          color: _manualSurfacesDark.border,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: accent,
                              side: BorderSide(
                                color: accent.withValues(alpha: 0.7),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(context.t.strings.common.cancel),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            child: Text(
                              _mode == CustomThemeMode.manual
                                  ? context.t.strings.common.saveSettings
                                  : context.t.strings.common.save,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.mode,
    required this.accent,
    required this.field,
    required this.border,
    required this.textMuted,
    required this.onSelect,
  });

  final CustomThemeMode mode;
  final Color accent;
  final Color field;
  final Color border;
  final Color textMuted;
  final ValueChanged<CustomThemeMode> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: field,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          _ModeToggleButton(
            label: context.t.strings.common.auto,
            selected: mode == CustomThemeMode.auto,
            accent: accent,
            textMuted: textMuted,
            onTap: () => onSelect(CustomThemeMode.auto),
          ),
          _ModeToggleButton(
            label: context.t.strings.common.manual,
            selected: mode == CustomThemeMode.manual,
            accent: accent,
            textMuted: textMuted,
            onTap: () => onSelect(CustomThemeMode.manual),
          ),
        ],
      ),
    );
  }
}

class _ModeToggleButton extends StatelessWidget {
  const _ModeToggleButton({
    required this.label,
    required this.selected,
    required this.accent,
    required this.textMuted,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final Color textMuted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = selected
        ? (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white)
        : Colors.transparent;
    final shadow = isDark
        ? Colors.black.withValues(alpha: 0.32)
        : Colors.black.withValues(alpha: 0.08);
    return Expanded(
      child: AnimatedContainer(
        duration: AppMotion.effectiveDuration(context, AppMotion.fast),
        curve: AppMotion.standardCurve,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(999),
          boxShadow: selected
              ? [
                  BoxShadow(
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                    color: shadow,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? accent : textMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorSquarePicker extends StatelessWidget {
  const _ColorSquarePicker({
    required this.color,
    required this.height,
    required this.border,
    required this.onChanged,
  });

  final Color color;
  final double height;
  final Color border;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    final hsv = HSVColor.fromColor(color);
    return Column(
      children: [
        Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: _HslPalette(color: color, onChanged: onChanged),
          ),
        ),
        const SizedBox(height: 8),
        _HueSlider(
          hsv: hsv,
          border: border,
          onChanged: (next) => onChanged(next.toColor()),
        ),
      ],
    );
  }
}

class _HslPalette extends StatelessWidget {
  const _HslPalette({required this.color, required this.onChanged});

  final Color color;
  final ValueChanged<Color> onChanged;

  void _handleOffset(Offset localPosition, Size size, HSLColor hsl) {
    if (size.width <= 0 || size.height <= 0) return;
    final dx = localPosition.dx.clamp(0.0, size.width);
    final dy = localPosition.dy.clamp(0.0, size.height);
    final saturation = (dx / size.width).clamp(0.0, 1.0);
    final lightness = (1 - dy / size.height).clamp(0.0, 1.0);
    onChanged(
      hsl.withSaturation(saturation).withLightness(lightness).toColor(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(color);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 0.0;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 0.0;
        final size = Size(width, height);
        return GestureDetector(
          onPanDown: (details) =>
              _handleOffset(details.localPosition, size, hsl),
          onPanUpdate: (details) =>
              _handleOffset(details.localPosition, size, hsl),
          child: CustomPaint(size: size, painter: _HslPalettePainter(hsl)),
        );
      },
    );
  }
}

class _HslPalettePainter extends CustomPainter {
  _HslPalettePainter(this.hsl);

  final HSLColor hsl;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final rect = Offset.zero & size;
    final gradientH = LinearGradient(
      colors: [
        const Color(0xff808080),
        HSLColor.fromAHSL(1.0, hsl.hue, 1.0, 0.5).toColor(),
      ],
    );
    const gradientV = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: [0.0, 0.5, 0.5, 1],
      colors: [
        Colors.white,
        Color(0x00ffffff),
        Colors.transparent,
        Colors.black,
      ],
    );
    canvas.drawRect(rect, Paint()..shader = gradientH.createShader(rect));
    canvas.drawRect(rect, Paint()..shader = gradientV.createShader(rect));

    final pointer = Offset(
      size.width * hsl.saturation,
      size.height * (1 - hsl.lightness),
    );
    final pointerColor = useWhiteForeground(hsl.toColor())
        ? Colors.white
        : Colors.black;
    canvas.drawCircle(
      pointer,
      size.height * 0.04,
      Paint()
        ..color = pointerColor
        ..strokeWidth = 1.5
        ..blendMode = BlendMode.luminosity
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _HslPalettePainter oldDelegate) {
    return oldDelegate.hsl != hsl;
  }
}

class _HueSlider extends StatelessWidget {
  const _HueSlider({
    required this.hsv,
    required this.border,
    required this.onChanged,
  });

  final HSVColor hsv;
  final Color border;
  final ValueChanged<HSVColor> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: ColorPickerSlider(
          TrackType.hue,
          hsv,
          onChanged,
          displayThumbColor: true,
          fullThumbColor: true,
        ),
      ),
    );
  }
}

class _HexInputRow extends StatelessWidget {
  const _HexInputRow({
    required this.controller,
    required this.color,
    required this.field,
    required this.border,
    required this.textMain,
    required this.textMuted,
    required this.onChanged,
    this.onColorTap,
  });

  final TextEditingController controller;
  final Color color;
  final Color field;
  final Color border;
  final Color textMain;
  final Color textMuted;
  final ValueChanged<String> onChanged;
  final VoidCallback? onColorTap;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: border),
      ),
    );
    final dotWidget = onColorTap == null
        ? dot
        : InkWell(
            onTap: onColorTap,
            customBorder: const CircleBorder(),
            child: dot,
          );

    String formatHex(Color color) {
      final value = color.toARGB32() & 0x00FFFFFF;
      return value.toRadixString(16).padLeft(6, '0').toUpperCase();
    }

    Future<void> handleCopy() async {
      final text = '#${formatHex(color)}';
      await Clipboard.setData(ClipboardData(text: text));
      if (!context.mounted) return;
      showTopToast(context, context.t.strings.common.copiedToClipboard);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: field,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          dotWidget,
          const SizedBox(width: 8),
          Expanded(
            child: PlatformTextField(
              controller: controller,
              onChanged: onChanged,
              inputFormatters: [
                UpperCaseTextFormatter(),
                FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                prefixText: '#',
                prefixStyle: TextStyle(
                  color: textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: TextStyle(color: textMain, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: handleCopy,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.copy_rounded, size: 16, color: textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

enum _SurfaceSlot { background, card, border }

class _SurfaceColorRow extends StatelessWidget {
  const _SurfaceColorRow({
    required this.label,
    required this.controller,
    required this.color,
    required this.field,
    required this.border,
    required this.textMain,
    required this.textMuted,
    required this.onChanged,
    required this.onPick,
  });

  final String label;
  final TextEditingController controller;
  final Color color;
  final Color field;
  final Color border;
  final Color textMain;
  final Color textMuted;
  final ValueChanged<String> onChanged;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
          ),
        ),
        SizedBox(
          width: 150,
          child: _HexInputRow(
            controller: controller,
            color: color,
            field: field,
            border: border,
            textMain: textMain,
            textMuted: textMuted,
            onChanged: onChanged,
            onColorTap: onPick,
          ),
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.title,
    required this.entries,
    required this.border,
    required this.onTap,
  });

  final String title;
  final List<CustomThemeColorPair> entries;
  final Color border;
  final ValueChanged<CustomThemeColorPair> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionHeader(title: title),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in entries)
              _HistoryDot(
                pair: entry,
                border: border,
                onTap: () => onTap(entry),
              ),
          ],
        ),
      ],
    );
  }
}

class _HistoryDot extends StatelessWidget {
  const _HistoryDot({
    required this.pair,
    required this.border,
    required this.onTap,
  });

  final CustomThemeColorPair pair;
  final Color border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [pair.light, pair.dark]),
          border: Border.all(color: border),
        ),
      ),
    );
  }
}

class _SurfaceColorDialog extends StatefulWidget {
  const _SurfaceColorDialog({required this.title, required this.initial});

  final String title;
  final Color initial;

  static Future<Color?> show({
    required BuildContext context,
    required String title,
    required Color initial,
  }) {
    return showPlatformDialog<Color>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _SurfaceColorDialog(title: title, initial: initial),
    );
  }

  @override
  State<_SurfaceColorDialog> createState() => _SurfaceColorDialogState();
}

class _SurfaceColorDialogState extends State<_SurfaceColorDialog> {
  late Color _color;
  late TextEditingController _hexController;
  bool _suppressHexUpdate = false;

  @override
  void initState() {
    super.initState();
    _color = widget.initial;
    _hexController = TextEditingController(text: _formatHex(_color));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _formatHex(Color color) {
    final value = color.toARGB32() & 0x00FFFFFF;
    return value.toRadixString(16).padLeft(6, '0').toUpperCase();
  }

  Color? _parseHex(String raw) {
    if (raw.length != 6) return null;
    final parsed = int.tryParse(raw, radix: 16);
    if (parsed == null) return null;
    return Color(0xFF000000 | parsed);
  }

  void _syncHex(Color color) {
    final next = _formatHex(color);
    if (_hexController.text.toUpperCase() == next) return;
    _suppressHexUpdate = true;
    _hexController.text = next;
    _hexController.selection = TextSelection.collapsed(offset: next.length);
    _suppressHexUpdate = false;
  }

  void _updateColor(Color color) {
    setState(() => _color = color);
    _syncHex(color);
  }

  void _handleHexChanged(String value) {
    if (_suppressHexUpdate) return;
    final color = _parseHex(value);
    if (color == null) return;
    _updateColor(color);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? MemoFlowPalette.cardDark : Colors.white;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.6 : 0.55);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final field = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final accent = MemoFlowPalette.primary;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SettingsContentHeader(
              title: widget.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            _ColorSquarePicker(
              color: _color,
              height: 140,
              border: border,
              onChanged: _updateColor,
            ),
            const SizedBox(height: 10),
            _HexInputRow(
              controller: _hexController,
              color: _color,
              field: field,
              border: border,
              textMain: textMain,
              textMuted: textMuted,
              onChanged: _handleHexChanged,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      side: BorderSide(color: accent.withValues(alpha: 0.7)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text(context.t.strings.common.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(_color),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                    ),
                    child: Text(context.t.strings.common.save),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
