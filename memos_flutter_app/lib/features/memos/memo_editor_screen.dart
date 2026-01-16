import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('内容不能为空')));
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
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e')));
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
        title: Text(existing == null ? '新建 Memo' : '编辑 Memo'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('保存'),
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
                      items: const [
                        DropdownMenuItem(value: 'PRIVATE', child: Text('私密')),
                        DropdownMenuItem(value: 'PROTECTED', child: Text('受保护')),
                        DropdownMenuItem(value: 'PUBLIC', child: Text('公开')),
                      ],
                      onChanged: _saving ? null : (v) => _visibility = v ?? 'PRIVATE',
                      decoration: const InputDecoration(
                        labelText: '可见性',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    children: [
                      const Text('置顶'),
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
                  decoration: const InputDecoration(
                    hintText: '写点什么… 支持 #tag 和待办 [ ] / [x]',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('字数：$count'),
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
