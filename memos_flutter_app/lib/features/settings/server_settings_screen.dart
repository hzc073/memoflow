import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../data/models/server_setting.dart';
import '../../state/settings/server_settings_provider.dart';

class ServerSettingsScreen extends ConsumerStatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  ConsumerState<ServerSettingsScreen> createState() =>
      _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends ConsumerState<ServerSettingsScreen> {
  final _memoController = TextEditingController();
  final _attachmentController = TextEditingController();
  final _memoFocus = FocusNode();
  final _attachmentFocus = FocusNode();
  String? _memoInputError;
  String? _attachmentInputError;

  @override
  void initState() {
    super.initState();
    _memoFocus.addListener(_restoreMemoValueOnBlur);
    _attachmentFocus.addListener(_restoreAttachmentValueOnBlur);
  }

  @override
  void dispose() {
    _memoFocus.removeListener(_restoreMemoValueOnBlur);
    _attachmentFocus.removeListener(_restoreAttachmentValueOnBlur);
    _memoController.dispose();
    _attachmentController.dispose();
    _memoFocus.dispose();
    _attachmentFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(serverSettingsProvider);
    final snapshot = state.snapshot.valueOrNull;
    if (snapshot != null) {
      _syncController(
        _memoController,
        _memoFocus,
        snapshot.memoContentLimitBytes.value,
      );
      _syncController(
        _attachmentController,
        _attachmentFocus,
        snapshot.attachmentUploadLimitMiB.value,
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.58 : 0.62);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(_serverSettingsLabel(context)),
        centerTitle: false,
        leading: IconButton(
          tooltip: context.tr(zh: '\u8FD4\u56DE', en: 'Back'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            tooltip: context.tr(zh: '\u5237\u65B0', en: 'Refresh'),
            icon: const Icon(Icons.refresh),
            onPressed: state.snapshot.isLoading
                ? null
                : () => ref.read(serverSettingsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: state.snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _LoadError(
          card: card,
          textMain: textMain,
          textMuted: textMuted,
          onRetry: () => ref.read(serverSettingsProvider.notifier).refresh(),
        ),
        data: (settings) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _LimitSection(
              card: card,
              textMain: textMain,
              textMuted: textMuted,
              icon: Icons.notes_outlined,
              title: context.tr(
                zh: '\u7B14\u8BB0\u6700\u5927\u5B57\u8282',
                en: 'Memo maximum bytes',
              ),
              unitLabel: context.tr(zh: '\u5B57\u8282', en: 'Bytes'),
              emptyHintText: _memoContentLimitRangeHint(context),
              setting: settings.memoContentLimitBytes,
              controller: _memoController,
              focusNode: _memoFocus,
              isSaving: state.isSavingMemoContentLimit,
              inputError: _memoInputError,
              saveResult: state.memoContentSaveResult,
              onChanged: () {
                if (_memoInputError != null) {
                  setState(() => _memoInputError = null);
                }
              },
              onSave: () => _saveMemoLimit(context),
            ),
            const SizedBox(height: 12),
            _LimitSection(
              card: card,
              textMain: textMain,
              textMuted: textMuted,
              icon: Icons.attach_file,
              title: context.tr(
                zh: '\u9644\u4EF6\u6700\u5927\u5BB9\u91CF',
                en: 'Attachment maximum capacity',
              ),
              unitLabel: 'MiB',
              emptyHintText: _currentServerLimitHint(
                context,
                value: settings.attachmentUploadLimitMiB.value,
                unitLabel: 'MiB',
              ),
              setting: settings.attachmentUploadLimitMiB,
              controller: _attachmentController,
              focusNode: _attachmentFocus,
              isSaving: state.isSavingAttachmentUploadLimit,
              inputError: _attachmentInputError,
              saveResult: state.attachmentUploadSaveResult,
              onChanged: () {
                if (_attachmentInputError != null) {
                  setState(() => _attachmentInputError = null);
                }
              },
              onSave: () => _saveAttachmentLimit(context),
            ),
          ],
        ),
      ),
    );
  }

  void _syncController(
    TextEditingController controller,
    FocusNode focusNode,
    int? value,
  ) {
    if (focusNode.hasFocus) return;
    final text = value?.toString() ?? '';
    if (controller.text != text) {
      controller.text = text;
    }
  }

  void _restoreMemoValueOnBlur() {
    if (!mounted || _memoFocus.hasFocus) return;
    final snapshot = ref.read(serverSettingsProvider).snapshot.valueOrNull;
    _syncController(
      _memoController,
      _memoFocus,
      snapshot?.memoContentLimitBytes.value,
    );
  }

  void _restoreAttachmentValueOnBlur() {
    if (!mounted || _attachmentFocus.hasFocus) return;
    final snapshot = ref.read(serverSettingsProvider).snapshot.valueOrNull;
    _syncController(
      _attachmentController,
      _attachmentFocus,
      snapshot?.attachmentUploadLimitMiB.value,
    );
  }

  Future<void> _saveMemoLimit(BuildContext context) async {
    final value = _positiveIntFrom(_memoController.text);
    if (value == null) {
      setState(() => _memoInputError = _positiveIntegerMessage(context));
      return;
    }
    setState(() => _memoInputError = null);
    await ref
        .read(serverSettingsProvider.notifier)
        .updateMemoContentLimitBytes(value);
  }

  Future<void> _saveAttachmentLimit(BuildContext context) async {
    final value = _positiveIntFrom(_attachmentController.text);
    if (value == null) {
      setState(() => _attachmentInputError = _positiveIntegerMessage(context));
      return;
    }
    setState(() => _attachmentInputError = null);
    await ref
        .read(serverSettingsProvider.notifier)
        .updateAttachmentUploadLimitMiB(value);
  }

  int? _positiveIntFrom(String raw) {
    final parsed = int.tryParse(raw.trim());
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  String _positiveIntegerMessage(BuildContext context) {
    return context.tr(
      zh: '\u8BF7\u8F93\u5165\u5927\u4E8E 0 \u7684\u6574\u6570\u3002',
      en: 'Enter an integer greater than 0.',
    );
  }

  String _memoContentLimitRangeHint(BuildContext context) {
    return context.tr(
      zh: '\u53EF\u8BBE\u7F6E\u8303\u56F4\uFF1A1-2147483647 \u5B57\u8282',
      en: 'Allowed range: 1-2147483647 bytes',
    );
  }

  String? _currentServerLimitHint(
    BuildContext context, {
    required int? value,
    required String unitLabel,
  }) {
    if (value == null) return null;
    return context.tr(
      zh: '\u5F53\u524D\u670D\u52A1\u5668\u9650\u5236\uFF1A$value $unitLabel',
      en: 'Current server limit: $value $unitLabel',
    );
  }
}

class _LimitSection extends StatelessWidget {
  const _LimitSection({
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.icon,
    required this.title,
    required this.unitLabel,
    this.emptyHintText,
    required this.setting,
    required this.controller,
    required this.focusNode,
    required this.isSaving,
    required this.inputError,
    required this.saveResult,
    required this.onChanged,
    required this.onSave,
  });

  final Color card;
  final Color textMain;
  final Color textMuted;
  final IconData icon;
  final String title;
  final String unitLabel;
  final String? emptyHintText;
  final ServerSettingValue<int> setting;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSaving;
  final String? inputError;
  final ServerSettingSaveResult? saveResult;
  final VoidCallback onChanged;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final editable = setting.isKnown && setting.editable && !isSaving;
    final message =
        inputError ??
        _saveMessage(context, saveResult) ??
        _availabilityMessage(context, setting);
    final isError =
        inputError != null ||
        (saveResult != null &&
            saveResult!.status != ServerSettingSaveStatus.saved);
    final isSaved = saveResult?.status == ServerSettingSaveStatus.saved;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: textMain,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: editable,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              labelText: unitLabel,
              hintText: editable ? emptyHintText : null,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(
                color: isError
                    ? Theme.of(context).colorScheme.error
                    : isSaved
                    ? Colors.green.shade600
                    : textMuted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: editable ? onSave : null,
              icon: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(context.tr(zh: '\u4FDD\u5B58', en: 'Save')),
            ),
          ),
        ],
      ),
    );
  }

  String _availabilityMessage(
    BuildContext context,
    ServerSettingValue<int> setting,
  ) {
    if (setting.isKnown && setting.editable) return '';
    if (setting.isKnown && !setting.editable) {
      return context.tr(
        zh: '\u5F53\u524D\u8D26\u53F7\u53EF\u4EE5\u67E5\u770B\uFF0C\u4F46\u4E0D\u80FD\u4FDD\u5B58\u6B64\u8BBE\u7F6E\u3002',
        en: 'The current account can read this value but cannot save it.',
      );
    }
    return switch (setting.unavailableReason) {
      ServerSettingUnavailableReason.localLibrary => context.tr(
        zh: '\u672C\u5730\u6587\u5E93\u6A21\u5F0F\u6CA1\u6709\u53EF\u7528\u7684\u670D\u52A1\u5668\u8BBE\u7F6E\u3002',
        en: 'Server settings are unavailable in local library mode.',
      ),
      ServerSettingUnavailableReason.unsupportedVersion => context.tr(
        zh: '\u5F53\u524D Memos \u7248\u672C\u4E0D\u652F\u6301\u6B64\u8BBE\u7F6E\u3002',
        en: 'This setting is not supported by the current Memos version.',
      ),
      ServerSettingUnavailableReason.permissionDenied => context.tr(
        zh: '\u5F53\u524D\u8D26\u53F7\u6CA1\u6709\u6743\u9650\u67E5\u770B\u6216\u4FEE\u6539\u6B64\u8BBE\u7F6E\u3002',
        en: 'The current account does not have permission for this setting.',
      ),
      ServerSettingUnavailableReason.endpointUnavailable => context.tr(
        zh: '\u5F53\u524D\u670D\u52A1\u5668\u672A\u63D0\u4F9B\u6B64\u8BBE\u7F6E\u63A5\u53E3\u3002',
        en: 'This server does not expose the setting endpoint.',
      ),
      ServerSettingUnavailableReason.invalidResponse => context.tr(
        zh: '\u670D\u52A1\u5668\u8FD4\u56DE\u7684\u8BBE\u7F6E\u683C\u5F0F\u65E0\u6548\u3002',
        en: 'The server returned an invalid setting response.',
      ),
      ServerSettingUnavailableReason.nonPositiveLimit => context.tr(
        zh: '\u670D\u52A1\u5668\u8FD4\u56DE\u7684\u9650\u5236\u503C\u4E0D\u662F\u6B63\u6574\u6570\u3002',
        en: 'The server returned a non-positive limit.',
      ),
      ServerSettingUnavailableReason.requestFailed || null => context.tr(
        zh: '\u6682\u65F6\u65E0\u6CD5\u8BFB\u53D6\u6B64\u8BBE\u7F6E\u3002',
        en: 'This setting could not be loaded right now.',
      ),
    };
  }

  String? _saveMessage(BuildContext context, ServerSettingSaveResult? result) {
    if (result == null) return null;
    return switch (result.status) {
      ServerSettingSaveStatus.saved => context.tr(
        zh: '\u5DF2\u4FDD\u5B58\u3002',
        en: 'Saved.',
      ),
      ServerSettingSaveStatus.invalidInput => context.tr(
        zh: '\u8BF7\u8F93\u5165\u5927\u4E8E 0 \u7684\u6574\u6570\u3002',
        en: 'Enter an integer greater than 0.',
      ),
      ServerSettingSaveStatus.unsupported => context.tr(
        zh: '\u5F53\u524D Memos \u7248\u672C\u4E0D\u652F\u6301\u4FDD\u5B58\u6B64\u8BBE\u7F6E\u3002',
        en: 'This Memos version cannot save this setting.',
      ),
      ServerSettingSaveStatus.permissionDenied => context.tr(
        zh: '\u5F53\u524D\u8D26\u53F7\u6CA1\u6709\u6743\u9650\u4FDD\u5B58\u6B64\u8BBE\u7F6E\u3002',
        en: 'The current account does not have permission to save this setting.',
      ),
      ServerSettingSaveStatus.unavailable => context.tr(
        zh: '\u670D\u52A1\u5668\u6682\u65F6\u65E0\u6CD5\u4FDD\u5B58\u6B64\u8BBE\u7F6E\u3002',
        en: 'The server could not save this setting.',
      ),
      ServerSettingSaveStatus.failed => context.tr(
        zh: '\u4FDD\u5B58\u5931\u8D25\u3002',
        en: 'Save failed.',
      ),
    };
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.onRetry,
  });

  final Color card;
  final Color textMain;
  final Color textMuted;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(20),
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
              Icon(Icons.error_outline, color: textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.tr(
                    zh: '\u670D\u52A1\u5668\u8BBE\u7F6E\u52A0\u8F7D\u5931\u8D25\u3002',
                    en: 'Server settings failed to load.',
                  ),
                  style: TextStyle(color: textMain),
                ),
              ),
              TextButton(
                onPressed: onRetry,
                child: Text(context.tr(zh: '\u91CD\u8BD5', en: 'Retry')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _serverSettingsLabel(BuildContext context) {
  return context.tr(
    zh: '\u670D\u52A1\u5668\u8BBE\u7F6E',
    en: 'Server Settings',
  );
}
