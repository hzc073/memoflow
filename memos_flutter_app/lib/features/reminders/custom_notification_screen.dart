import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';

class CustomNotificationScreen extends StatefulWidget {
  const CustomNotificationScreen({
    super.key,
    required this.initialTitle,
    required this.initialBody,
  });

  final String initialTitle;
  final String initialBody;

  @override
  State<CustomNotificationScreen> createState() => _CustomNotificationScreenState();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);

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
        title: Text(context.tr(zh: '自定义通知', en: 'Customize Notification')),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(context.tr(zh: '确定', en: 'Done')),
          ),
        ],
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _InputCard(
                card: card,
                textMain: textMain,
                textMuted: textMuted,
                title: context.tr(zh: '通知标题', en: 'Title'),
                controller: _titleController,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              _InputCard(
                card: card,
                textMain: textMain,
                textMuted: textMuted,
                title: context.tr(zh: '通知正文', en: 'Body'),
                controller: _bodyController,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 18),
              Text(
                context.tr(zh: '预览效果', en: 'Preview'),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted),
              ),
              const SizedBox(height: 8),
              _PreviewCard(
                card: card,
                title: _titleController.text.trim().isEmpty ? widget.initialTitle : _titleController.text.trim(),
                body: _bodyController.text.trim().isEmpty ? widget.initialBody : _bodyController.text.trim(),
                textMain: textMain,
                textMuted: textMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  const _InputCard({
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.title,
    required this.controller,
    required this.onChanged,
  });

  final Color card;
  final Color textMain;
  final Color textMuted;
  final String title;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted)),
          TextField(
            controller: controller,
            maxLength: 15,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textMain),
            onChanged: onChanged,
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.card,
    required this.title,
    required this.body,
    required this.textMain,
    required this.textMuted,
  });

  final Color card;
  final String title;
  final String body;
  final Color textMain;
  final Color textMuted;

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
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: MemoFlowPalette.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.notifications_active_outlined, color: MemoFlowPalette.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MemoFlow',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, color: textMain),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: textMuted),
                ),
              ],
            ),
          ),
          Text(
            context.tr(zh: '现在', en: 'Now'),
            style: TextStyle(fontSize: 11, color: textMuted),
          ),
        ],
      ),
    );
  }
}
