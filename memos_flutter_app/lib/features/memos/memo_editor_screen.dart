import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../core/tags.dart';
import '../../core/uid.dart';
import '../../data/models/local_memo.dart';
import '../../state/database_provider.dart';
import '../../state/memos_providers.dart';

class MemoEditorScreen extends ConsumerStatefulWidget {
  const MemoEditorScreen({super.key, this.existing});

  final LocalMemo? existing;

  @override
  ConsumerState<MemoEditorScreen> createState() => _MemoEditorScreenState();
}

class _MemoEditorScreenState extends ConsumerState<MemoEditorScreen> {
  late final TextEditingController _contentController;
  late String _visibility;
  late bool _pinned;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _contentController = TextEditingController(text: existing?.content ?? '');
    _visibility = existing?.visibility ?? 'PRIVATE';
    _pinned = existing?.pinned ?? false;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  int _countNonWhitespaceChars(String s) {
    final stripped = s.replaceAll(RegExp(r'\s+'), '');
    return stripped.runes.length;
  }

  Future<void> _save() async {
    if (_saving) return;
    final content = _contentController.text.trimRight();
    if (content.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '内容不能为空', en: 'Content cannot be empty'))),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final existing = widget.existing;
      final now = DateTime.now();
      final uid = existing?.uid ?? generateUid();
      final createTime = existing?.createTime ?? now;
      final state = existing?.state ?? 'NORMAL';
      final attachments = existing?.attachments.map((a) => a.toJson()).toList(growable: false) ?? const <Map<String, dynamic>>[];
      final tags = extractTags(content);

      final db = ref.read(databaseProvider);
      await db.upsertMemo(
        uid: uid,
        content: content,
        visibility: _visibility,
        pinned: _pinned,
        state: state,
        createTimeSec: createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
        updateTimeSec: now.toUtc().millisecondsSinceEpoch ~/ 1000,
        tags: tags,
        attachments: attachments,
        syncState: 1,
        lastError: null,
      );

      if (existing == null) {
        await db.enqueueOutbox(type: 'create_memo', payload: {
          'uid': uid,
          'content': content,
          'visibility': _visibility,
          'pinned': _pinned,
          'has_attachments': attachments.isNotEmpty,
        });
      } else {
        await db.enqueueOutbox(type: 'update_memo', payload: {
          'uid': uid,
          'content': content,
          'visibility': _visibility,
          'pinned': _pinned,
        });
      }

      unawaited(ref.read(syncControllerProvider.notifier).syncNow());

      if (!mounted) return;
      context.safePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '保存失败：$e', en: 'Save failed: $e'))),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    final content = _contentController.text;
    final count = _countNonWhitespaceChars(content);

    return Scaffold(
      appBar: AppBar(
        title: Text(existing == null ? context.tr(zh: '新建 Memo', en: 'New Memo') : context.tr(zh: '编辑 Memo', en: 'Edit Memo')),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(context.tr(zh: '保存', en: 'Save')),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _visibility,
                      items: [
                        DropdownMenuItem(value: 'PRIVATE', child: Text(context.tr(zh: '私密', en: 'Private'))),
                        DropdownMenuItem(value: 'PROTECTED', child: Text(context.tr(zh: '受保护', en: 'Protected'))),
                        DropdownMenuItem(value: 'PUBLIC', child: Text(context.tr(zh: '公开', en: 'Public'))),
                      ],
                      onChanged: _saving ? null : (v) => _visibility = v ?? 'PRIVATE',
                      decoration: InputDecoration(
                        labelText: context.tr(zh: '可见性', en: 'Visibility'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    children: [
                      Text(context.tr(zh: '置顶', en: 'Pin')),
                      Switch(
                        value: _pinned,
                        onChanged: _saving ? null : (v) => setState(() => _pinned = v),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: _contentController,
                  enabled: !_saving,
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  expands: true,
                  decoration: InputDecoration(
                    hintText: context.tr(
                      zh: '写点什么… 支持 #tag 和待办 [ ] / [x]',
                      en: 'Write something... Supports #tag and tasks [ ] / [x]',
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(context.tr(zh: '字数：$count', en: 'Count: $count')),
                  const Spacer(),
                  if (existing != null) Text('ID：${existing.uid}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
