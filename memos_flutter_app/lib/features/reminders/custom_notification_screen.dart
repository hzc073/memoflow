import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../i18n/strings.g.dart';
import '../../platform/widgets/platform_list_section.dart';
import '../settings/settings_ui.dart';

class CustomNotificationScreen extends StatefulWidget {
  const CustomNotificationScreen({
    super.key,
    required this.initialTitle,
    required this.initialBody,
  });

  final String initialTitle;
  final String initialBody;

  @override
  State<CustomNotificationScreen> createState() =>
      _CustomNotificationScreenState();
}

class _CustomNotificationScreenState extends State<CustomNotificationScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _bodyController = TextEditingController(text: widget.initialBody);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _save() {
    final rawTitle = _titleController.text.trim();
    final rawBody = _bodyController.text.trim();
    final title = rawTitle.isEmpty ? widget.initialTitle : rawTitle;
    final body = rawBody.isEmpty ? widget.initialBody : rawBody;
    Navigator.of(context).pop((title, body));
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPage(
      title: Text(context.t.strings.legacy.msg_customize_notification),
      actions: [
        TextButton(
          onPressed: _save,
          child: Text(context.t.strings.legacy.msg_done_2),
        ),
      ],
      children: [
        SettingsSection(
          header: Text(context.t.strings.legacy.msg_notification_content),
          children: [
            SettingsInlineTextFieldRow(
              label: context.t.strings.legacy.msg_title,
              controller: _titleController,
              maxLength: 15,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              onChanged: (_) => setState(() {}),
            ),
            SettingsMultilineFieldRow(
              label: context.t.strings.legacy.msg_body,
              controller: _bodyController,
              minLines: 2,
              maxLines: 3,
              maxLength: 15,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        SettingsSection(
          header: Text(context.t.strings.legacy.msg_preview_2),
          children: [
            _PreviewRow(
              title: _titleController.text.trim().isEmpty
                  ? widget.initialTitle
                  : _titleController.text.trim(),
              body: _bodyController.text.trim().isEmpty
                  ? widget.initialBody
                  : _bodyController.text.trim(),
            ),
          ],
        ),
      ],
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    final colorScheme = Theme.of(context).colorScheme;
    return PlatformListSectionRow(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.notifications_active_outlined,
          color: colorScheme.primary,
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MemoFlow',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: tokens.textMuted,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 4),
          SettingsRowTitle(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
      subtitle: Text(
        body,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: tokens.textMuted,
          height: 1.3,
          decoration: TextDecoration.none,
        ),
      ),
      additionalInfo: Text(
        context.t.strings.legacy.msg_now,
        style: TextStyle(fontSize: 11, color: tokens.textMuted),
      ),
      denseOnDesktop: false,
    );
  }
}
