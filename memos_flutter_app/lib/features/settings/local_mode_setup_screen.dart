import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/app_localization.dart';
import '../../data/logs/log_manager.dart';
import '../../i18n/strings.g.dart';

class LocalModeSetupResult {
  const LocalModeSetupResult({required this.name});

  final String name;
}

class LocalModeSetupScreen extends StatefulWidget {
  const LocalModeSetupScreen({
    super.key,
    required this.title,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.initialName,
    this.subtitle,
    this.showStorageInfoCard = true,
  });

  final String title;
  final String confirmLabel;
  final String cancelLabel;
  final String initialName;
  final String? subtitle;
  final bool showStorageInfoCard;

  static Future<LocalModeSetupResult?> show(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    required String cancelLabel,
    required String initialName,
    String? subtitle,
    bool showStorageInfoCard = true,
  }) {
    return Navigator.of(context).push<LocalModeSetupResult>(
      MaterialPageRoute<LocalModeSetupResult>(
        builder: (_) => LocalModeSetupScreen(
          title: title,
          confirmLabel: confirmLabel,
          cancelLabel: cancelLabel,
          initialName: initialName,
          subtitle: subtitle,
          showStorageInfoCard: showStorageInfoCard,
        ),
      ),
    );
  }

  @override
  State<LocalModeSetupScreen> createState() => _LocalModeSetupScreenState();
}

class _LocalModeSetupScreenState extends State<LocalModeSetupScreen> {
  late final TextEditingController _nameController;
  bool _submitting = false;

  void _logFlow(
    String message, {
    Map<String, Object?>? context,
    bool warn = false,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode) return;
    if (warn) {
      LogManager.instance.warn(
        'LocalModeSetup: $message',
        context: context,
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }
    LogManager.instance.info(
      'LocalModeSetup: $message',
      context: context,
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _logFlow('screen_opened');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _logFlow('submit_blocked_empty_name', warn: true);
      _showMessage(context.t.strings.legacy.msg_enter_repository_name_prompt);
      return;
    }

    setState(() => _submitting = true);
    _logFlow(
      'submit_success_pop',
      context: <String, Object?>{'nameLength': name.length},
    );
    Navigator.of(context).pop(LocalModeSetupResult(name: name));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          if ((widget.subtitle ?? '').trim().isNotEmpty) ...[
            Text(
              widget.subtitle!.trim(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (widget.showStorageInfoCard) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  context.tr(
                    zh: '\u672c\u5730\u6a21\u5f0f\u6570\u636e\u5c06\u9ed8\u8ba4\u4fdd\u5b58\u5728\u5e94\u7528\u5185\u90e8\u6587\u4ef6\u5939\u3002',
                    en: 'Local mode data is stored in the app\'s private files by default.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t.strings.legacy.msg_repository_name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      hintText: context
                          .t
                          .strings
                          .legacy
                          .msg_enter_repository_name_hint,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.confirmLabel),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _submitting
                ? null
                : () => Navigator.of(context).maybePop(),
            child: Text(widget.cancelLabel),
          ),
        ],
      ),
    );
  }
}
