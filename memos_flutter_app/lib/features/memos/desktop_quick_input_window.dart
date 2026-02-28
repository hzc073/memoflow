import 'dart:async';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:window_manager/window_manager.dart';

import '../../i18n/strings.g.dart';
import '../../core/desktop_shortcuts.dart';
import '../../core/desktop_quick_input_channel.dart';
import '../../core/memo_template_renderer.dart';
import '../../core/memoflow_palette.dart';
import '../../core/tags.dart';
import '../../core/uid.dart';
import '../../data/location/location_geocoder.dart';
import '../../data/location/device_location_service.dart';
import '../../data/models/location_settings.dart';
import '../../data/models/memo_location.dart';
import '../../data/models/memo_template_settings.dart';
import '../../state/location_settings_provider.dart';
import '../../state/logging_provider.dart';
import '../../state/memo_template_settings_provider.dart';
import '../../state/network_log_provider.dart';
import 'attachment_gallery_screen.dart';
import 'compose_toolbar_shared.dart';
import 'link_memo_sheet.dart';
import 'memo_video_grid.dart';
import 'windows_camera_capture_screen.dart';

class DesktopQuickInputWindowApp extends StatelessWidget {
  const DesktopQuickInputWindowApp({super.key, required this.windowId});

  final int windowId;

  @override
  Widget build(BuildContext context) {
    return TranslationProvider(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'MemoFlow',
        home: DesktopQuickInputWindowScreen(windowId: windowId),
      ),
    );
  }
}

class DesktopQuickInputWindowScreen extends ConsumerStatefulWidget {
  const DesktopQuickInputWindowScreen({super.key, required this.windowId});

  final int windowId;

  @override
  ConsumerState<DesktopQuickInputWindowScreen> createState() =>
      _DesktopQuickInputWindowScreenState();
}

class _DesktopQuickInputWindowScreenState
    extends ConsumerState<DesktopQuickInputWindowScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  final _tagMenuKey = GlobalKey();
  final _templateMenuKey = GlobalKey();
  final _todoMenuKey = GlobalKey();
  final _visibilityMenuKey = GlobalKey();

  final List<_PendingAttachment> _pendingAttachments = <_PendingAttachment>[];
  final List<_LinkedMemo> _linkedMemos = <_LinkedMemo>[];
  final _imagePicker = ImagePicker();
  final _templateRenderer = MemoTemplateRenderer();

  bool _submitting = false;
  bool _moreToolbarOpen = false;
  bool _alwaysOnTop = false;
  bool _alwaysOnTopSupported = false;
  bool _pinning = false;
  bool _locating = false;
  Future<bool>? _mainWindowChannelProbe;

  MemoLocation? _location;
  String _visibility = 'PRIVATE';

  @override
  void initState() {
    super.initState();
    DesktopMultiWindow.setMethodHandler(_handleMethodCall);
    if (isDesktopShortcutEnabled()) {
      HardwareKeyboard.instance.addHandler(_handleDesktopEditorShortcuts);
    }
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _requestInputFocus();
    unawaited(_initializeWindowManager());
    unawaited(_ensureMainWindowChannelReady());
  }

  @override
  void dispose() {
    DesktopMultiWindow.setMethodHandler(null);
    if (isDesktopShortcutEnabled()) {
      HardwareKeyboard.instance.removeHandler(_handleDesktopEditorShortcuts);
    }
    _controller.dispose();
    _focusNode.dispose();
    unawaited(_notifyMainWindowVisibility(false));
    unawaited(_notifyMainWindowClosed());
    super.dispose();
  }

  bool get _canSubmit =>
      !_submitting &&
      (_controller.text.trim().isNotEmpty || _pendingAttachments.isNotEmpty);

  Future<void> _initializeWindowManager() async {
    try {
      await windowManager.ensureInitialized();
      if (Platform.isWindows) {
        await windowManager.setAsFrameless();
        await windowManager.setHasShadow(false);
        await windowManager.setBackgroundColor(const Color(0x00000000));
      }
      if (!mounted) return;
      await _syncAlwaysOnTop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _alwaysOnTopSupported = false);
    }
  }

  Future<void> _syncAlwaysOnTop() async {
    try {
      final value = await windowManager.isAlwaysOnTop();
      if (!mounted) return;
      setState(() {
        _alwaysOnTop = value;
        _alwaysOnTopSupported = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _alwaysOnTopSupported = false);
    }
  }

  Future<void> _toggleAlwaysOnTop() async {
    if (_pinning || !_alwaysOnTopSupported) return;
    setState(() => _pinning = true);
    try {
      final next = !_alwaysOnTop;
      await windowManager.setAlwaysOnTop(next);
      if (!mounted) return;
      setState(() => _alwaysOnTop = next);
    } catch (_) {
      if (!mounted) return;
      setState(() => _alwaysOnTopSupported = false);
      _showSnack('当前窗口暂不支持置顶。');
    } finally {
      if (mounted) {
        setState(() => _pinning = false);
      }
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call, int _) async {
    if (!mounted) return null;
    if (call.method == desktopQuickInputFocusMethod) {
      await _bringWindowToFront();
      return true;
    }
    if (call.method == desktopSubWindowIsVisibleMethod) {
      try {
        await windowManager.ensureInitialized();
        return await windowManager.isVisible();
      } catch (_) {
        return true;
      }
    }
    return null;
  }

  Future<void> _bringWindowToFront() async {
    try {
      await windowManager.ensureInitialized();
      if (await windowManager.isMinimized()) {
        await windowManager.restore();
      }
      if (!await windowManager.isVisible()) {
        await windowManager.show();
      } else {
        // On Windows a visible window may still sit behind others.
        await windowManager.show();
      }
      await windowManager.focus();
    } catch (_) {
      // Ignore platform/channel failures and still try to focus input field.
    }
    _requestInputFocus();
  }

  void _requestInputFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    });
  }

  void _resetComposerStateForReuse() {
    _controller.clear();
    _pendingAttachments.clear();
    _linkedMemos.clear();
    _location = null;
    _visibility = 'PRIVATE';
    _moreToolbarOpen = false;
    _submitting = false;
    _locating = false;
  }

  Future<void> _closeWindow() async {
    await _notifyMainWindowVisibility(false);
    if (mounted) {
      setState(_resetComposerStateForReuse);
    } else {
      _resetComposerStateForReuse();
    }
    final controller = WindowController.fromWindowId(widget.windowId);
    try {
      await controller.hide();
    } catch (_) {
      await controller.close();
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isMainWindowChannelMissing(PlatformException error) {
    if (error.code.trim() == '-1') return true;
    final message = (error.message ?? '').toLowerCase();
    return message.contains('target window not found') ||
        message.contains('target window channel not found');
  }

  Future<void> _wakeMainWindow() async {
    try {
      final controller = WindowController.main();
      await controller.show();
    } catch (_) {}
  }

  Future<bool> _probeMainWindowChannel() async {
    const maxAttempts = 10;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        await DesktopMultiWindow.invokeMethod(0, desktopQuickInputPingMethod);
        return true;
      } on MissingPluginException {
        // Main window handler not ready yet. Retry shortly.
      } on PlatformException catch (error) {
        if (!_isMainWindowChannelMissing(error)) {
          return false;
        }
      }
      if (attempt == 1 || attempt == 3 || attempt == 6) {
        await _wakeMainWindow();
      }
      await Future<void>.delayed(Duration(milliseconds: 120 + (attempt * 100)));
    }
    return false;
  }

  Future<bool> _ensureMainWindowChannelReady({bool force = false}) {
    if (!force) {
      final pending = _mainWindowChannelProbe;
      if (pending != null) return pending;
    }
    final future = _probeMainWindowChannel().then((ready) {
      if (!ready) {
        _mainWindowChannelProbe = null;
      }
      return ready;
    });
    _mainWindowChannelProbe = future;
    return future;
  }

  Future<dynamic> _invokeMainWindowMethod(
    String method, [
    dynamic arguments,
  ]) async {
    var ready = await _ensureMainWindowChannelReady();
    if (!ready) {
      ready = await _ensureMainWindowChannelReady(force: true);
    }
    if (!ready) {
      throw MissingPluginException('Main window channel is not ready.');
    }
    return DesktopMultiWindow.invokeMethod(0, method, arguments);
  }

  Future<void> _notifyMainWindowVisibility(bool visible) async {
    try {
      await DesktopMultiWindow.invokeMethod(
        0,
        desktopSubWindowVisibilityMethod,
        <String, dynamic>{'visible': visible},
      );
    } catch (_) {}
  }

  Future<void> _notifyMainWindowClosed() async {
    try {
      await DesktopMultiWindow.invokeMethod(0, desktopQuickInputClosedMethod);
    } catch (_) {}
  }

  void _insertText(String value, {int? caretOffset}) {
    final current = _controller.value;
    final selection = current.selection;
    final start = selection.isValid ? selection.start : current.text.length;
    final end = selection.isValid ? selection.end : current.text.length;
    final nextText = current.text.replaceRange(start, end, value);
    _controller.value = current.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(
        offset: start + (caretOffset ?? value.length),
      ),
      composing: TextRange.empty,
    );
  }

  void _replaceText(String value) {
    _controller.value = _controller.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
  }

  void _toggleBold() {
    final value = _controller.value;
    final selection = value.selection;
    if (!selection.isValid || selection.isCollapsed) {
      _insertText('****', caretOffset: 2);
      return;
    }
    final selected = value.text.substring(selection.start, selection.end);
    final wrapped = '**$selected**';
    _controller.value = value.copyWith(
      text: value.text.replaceRange(selection.start, selection.end, wrapped),
      selection: TextSelection(
        baseOffset: selection.start,
        extentOffset: selection.start + wrapped.length,
      ),
      composing: TextRange.empty,
    );
  }

  void _toggleHighlight() {
    final value = _controller.value;
    final selection = value.selection;
    if (!selection.isValid || selection.isCollapsed) {
      _insertText('====', caretOffset: 2);
      return;
    }
    final selected = value.text.substring(selection.start, selection.end);
    final wrapped = '==$selected==';
    _controller.value = value.copyWith(
      text: value.text.replaceRange(selection.start, selection.end, wrapped),
      selection: TextSelection(
        baseOffset: selection.start,
        extentOffset: selection.start + wrapped.length,
      ),
      composing: TextRange.empty,
    );
  }

  void _toggleMoreToolbar() {
    if (_submitting) return;
    setState(() => _moreToolbarOpen = !_moreToolbarOpen);
  }

  void _closeMoreToolbar() {
    if (!_moreToolbarOpen) return;
    setState(() => _moreToolbarOpen = false);
  }

  Future<List<String>> _loadTagCandidates() async {
    try {
      final result = await _invokeMainWindowMethod(
        desktopQuickInputListTagsMethod,
        <String, dynamic>{'existingTags': extractTags(_controller.text)},
      );
      if (result is! List) return const <String>[];
      final values = <String>{};
      for (final item in result) {
        final tag = (item as String? ?? '').trim();
        if (tag.isEmpty) continue;
        final normalized = tag.startsWith('#') ? tag.substring(1) : tag;
        if (normalized.isEmpty) continue;
        values.add(normalized);
      }
      final tags = values.toList(growable: false);
      tags.sort();
      return tags;
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _openTagMenuFromKey(GlobalKey key) async {
    if (_submitting) return;
    final target = key.currentContext;
    if (target == null) return;

    final overlay = Overlay.of(context).context.findRenderObject();
    final box = target.findRenderObject();
    if (overlay is! RenderBox || box is! RenderBox) return;

    final tags = await _loadTagCandidates();
    if (!mounted) return;

    final items = tags.isEmpty
        ? const <PopupMenuEntry<String>>[
            PopupMenuItem<String>(enabled: false, child: Text('No tags yet')),
          ]
        : tags
              .map(
                (tag) =>
                    PopupMenuItem<String>(value: tag, child: Text('#$tag')),
              )
              .toList(growable: false);

    final rect = Rect.fromPoints(
      box.localToGlobal(Offset.zero, ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    );

    final selection = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      items: items,
    );
    if (!mounted || selection == null) return;

    final normalized = selection.startsWith('#')
        ? selection.substring(1)
        : selection;
    if (normalized.isEmpty) return;
    _insertText('$normalized ');
  }

  Future<void> _openTemplateMenuFromKey(
    GlobalKey key,
    List<MemoTemplate> templates,
  ) async {
    if (_submitting) return;
    final target = key.currentContext;
    if (target == null) return;

    final overlay = Overlay.of(context).context.findRenderObject();
    final box = target.findRenderObject();
    if (overlay is! RenderBox || box is! RenderBox) return;

    final items = templates.isEmpty
        ? const <PopupMenuEntry<String>>[
            PopupMenuItem<String>(enabled: false, child: Text('暂无模板')),
          ]
        : templates
              .map(
                (template) => PopupMenuItem<String>(
                  value: template.id,
                  child: Text(template.name),
                ),
              )
              .toList(growable: false);

    final rect = Rect.fromPoints(
      box.localToGlobal(Offset.zero, ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    );

    final selectedId = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      items: items,
    );
    if (!mounted || selectedId == null) return;
    MemoTemplate? selected;
    for (final item in templates) {
      if (item.id == selectedId) {
        selected = item;
        break;
      }
    }
    if (selected == null) return;
    await _applyTemplate(selected);
  }

  Future<void> _applyTemplate(MemoTemplate template) async {
    final templateSettings = ref.read(memoTemplateSettingsProvider);
    final locationSettings = ref.read(locationSettingsProvider);
    final rendered = await _templateRenderer.render(
      templateContent: template.content,
      variableSettings: templateSettings.variables,
      locationSettings: locationSettings,
    );
    if (!mounted) return;
    _replaceText(rendered);
  }

  bool _handleDesktopEditorShortcuts(KeyEvent event) {
    if (!mounted || !isDesktopShortcutEnabled()) return false;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    if (event is! KeyDownEvent) return false;

    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final primaryPressed = isPrimaryShortcutModifierPressed(pressed);
    final shiftPressed = isShiftModifierPressed(pressed);
    final altPressed = isAltModifierPressed(pressed);
    final key = event.logicalKey;

    bool matches(DesktopShortcutAction action) {
      final binding = desktopShortcutDefaultBindings[action];
      if (binding == null) return false;
      return matchesDesktopShortcut(
        event: event,
        pressedKeys: pressed,
        binding: binding,
      );
    }

    if (_focusNode.hasFocus) {
      if (matches(DesktopShortcutAction.publishMemo)) {
        unawaited(_submit());
        return true;
      }
      if (matches(DesktopShortcutAction.bold)) {
        _toggleBold();
        return true;
      }
      if (matches(DesktopShortcutAction.highlight) ||
          matches(DesktopShortcutAction.underline)) {
        _toggleHighlight();
        return true;
      }
      if (matches(DesktopShortcutAction.unorderedList)) {
        _insertText('- ');
        return true;
      }
      if (matches(DesktopShortcutAction.orderedList)) {
        _insertText('1. ');
        return true;
      }
    }

    if (!primaryPressed && !shiftPressed && !altPressed) {
      if (key == LogicalKeyboardKey.escape) {
        unawaited(_closeWindow());
        return true;
      }
    }

    if (primaryPressed && !shiftPressed && !altPressed) {
      if (key == LogicalKeyboardKey.keyW) {
        unawaited(_closeWindow());
        return true;
      }
    }

    if (primaryPressed && shiftPressed && !altPressed) {
      if (key == LogicalKeyboardKey.keyP &&
          _alwaysOnTopSupported &&
          !_pinning) {
        unawaited(_toggleAlwaysOnTop());
        return true;
      }
    }

    return false;
  }

  Future<void> _openTodoShortcutMenuFromKey(GlobalKey key) async {
    if (_submitting) return;
    final target = key.currentContext;
    if (target == null) return;

    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final box = target.findRenderObject() as RenderBox?;
    if (overlay == null || box == null) return;

    final rect = Rect.fromPoints(
      box.localToGlobal(Offset.zero, ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    );

    final action = await showMenu<MemoComposeTodoShortcutAction>(
      context: context,
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      items: const [
        PopupMenuItem(
          value: MemoComposeTodoShortcutAction.checkbox,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_box_outlined, size: 18),
              SizedBox(width: 8),
              Text('待办复选框'),
            ],
          ),
        ),
        PopupMenuItem(
          value: MemoComposeTodoShortcutAction.codeBlock,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.code, size: 18),
              SizedBox(width: 8),
              Text('代码块'),
            ],
          ),
        ),
      ],
    );

    if (!mounted || action == null) return;
    switch (action) {
      case MemoComposeTodoShortcutAction.checkbox:
        _insertText('- [ ] ');
        break;
      case MemoComposeTodoShortcutAction.codeBlock:
        _insertText('```\n\n```', caretOffset: 4);
        break;
    }
  }

  Future<void> _openVisibilityMenuFromKey(GlobalKey key) async {
    if (_submitting) return;
    final target = key.currentContext;
    if (target == null) return;

    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final box = target.findRenderObject() as RenderBox?;
    if (overlay == null || box == null) return;

    final rect = Rect.fromPoints(
      box.localToGlobal(Offset.zero, ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    );

    final selection = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      items: const [
        PopupMenuItem(value: 'PRIVATE', child: Text('私密')),
        PopupMenuItem(value: 'PROTECTED', child: Text('工作区')),
        PopupMenuItem(value: 'PUBLIC', child: Text('公开')),
      ],
    );

    if (!mounted || selection == null) return;
    setState(() => _visibility = selection);
  }

  Future<void> _pickLinkMemo() async {
    if (_submitting) return;
    try {
      final selection = await LinkMemoSheet.show(
        context,
        existingNames: _linkedMemos.map((e) => e.name).toSet(),
      );
      if (!mounted || selection == null) return;
      final name = selection.name.trim();
      if (name.isEmpty || _linkedMemos.any((e) => e.name == name)) return;

      final raw = selection.content.replaceAll(RegExp(r'\s+'), ' ').trim();
      final fallback = name.startsWith('memos/')
          ? name.substring('memos/'.length)
          : name;
      final label = _truncateLinkMemoLabel(raw.isNotEmpty ? raw : fallback);

      setState(() {
        _linkedMemos.add(_LinkedMemo(name: name, label: label));
      });
    } catch (error) {
      _showSnack('Link memo failed: $error');
    }
  }

  String _truncateLinkMemoLabel(String text, {int maxLength = 24}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  String _guessMimeType(String filename) {
    final lower = filename.toLowerCase();
    final dot = lower.lastIndexOf('.');
    final ext = dot == -1 ? '' : lower.substring(dot + 1);
    return switch (ext) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'bmp' => 'image/bmp',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      'mp3' => 'audio/mpeg',
      'm4a' => 'audio/mp4',
      'aac' => 'audio/aac',
      'wav' => 'audio/wav',
      'flac' => 'audio/flac',
      'ogg' => 'audio/ogg',
      'opus' => 'audio/opus',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'mkv' => 'video/x-matroska',
      'webm' => 'video/webm',
      'avi' => 'video/x-msvideo',
      'pdf' => 'application/pdf',
      'zip' => 'application/zip',
      'rar' => 'application/vnd.rar',
      '7z' => 'application/x-7z-compressed',
      'txt' => 'text/plain',
      'md' => 'text/markdown',
      'json' => 'application/json',
      'csv' => 'text/csv',
      'log' => 'text/plain',
      _ => 'application/octet-stream',
    };
  }

  Future<void> _pickAttachments() async {
    if (_submitting) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );
      if (!mounted) return;

      final files = result?.files ?? const <PlatformFile>[];
      if (files.isEmpty) return;

      final added = <_PendingAttachment>[];
      for (final file in files) {
        final path = (file.path ?? '').trim();
        if (path.isEmpty) continue;
        final handle = File(path);
        if (!handle.existsSync()) continue;

        final filename = file.name.trim().isNotEmpty
            ? file.name.trim()
            : path.split(Platform.pathSeparator).last;

        added.add(
          _PendingAttachment(
            uid: generateUid(),
            filePath: path,
            filename: filename,
            mimeType: _guessMimeType(filename),
            size: handle.lengthSync(),
          ),
        );
      }

      if (added.isEmpty) {
        _showSnack('未选择有效文件。');
        return;
      }

      setState(() => _pendingAttachments.addAll(added));
      _showSnack('已添加 ${added.length} 个附件。');
    } catch (error) {
      _showSnack('选择文件失败：$error');
    }
  }

  void _removePendingAttachment(String uid) {
    final index = _pendingAttachments.indexWhere(
      (attachment) => attachment.uid == uid,
    );
    if (index < 0) return;
    setState(() => _pendingAttachments.removeAt(index));
  }

  bool _isImageMimeType(String mimeType) {
    return mimeType.trim().toLowerCase().startsWith('image/');
  }

  bool _isVideoMimeType(String mimeType) {
    return mimeType.trim().toLowerCase().startsWith('video');
  }

  File? _resolvePendingAttachmentFile(_PendingAttachment attachment) {
    final path = attachment.filePath.trim();
    if (path.isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return file;
  }

  String _pendingSourceId(String uid) => 'pending:$uid';

  List<
    ({AttachmentImageSource source, _PendingAttachment attachment, File file})
  >
  _pendingImageSources() {
    final items =
        <
          ({
            AttachmentImageSource source,
            _PendingAttachment attachment,
            File file,
          })
        >[];
    for (final attachment in _pendingAttachments) {
      if (!_isImageMimeType(attachment.mimeType)) continue;
      final file = _resolvePendingAttachmentFile(attachment);
      if (file == null) continue;
      items.add((
        source: AttachmentImageSource(
          id: _pendingSourceId(attachment.uid),
          title: attachment.filename,
          mimeType: attachment.mimeType,
          localFile: file,
        ),
        attachment: attachment,
        file: file,
      ));
    }
    return items;
  }

  Future<void> _openAttachmentViewer(_PendingAttachment attachment) async {
    final items = _pendingImageSources();
    if (items.isEmpty) return;
    final index = items.indexWhere(
      (item) => item.attachment.uid == attachment.uid,
    );
    if (index < 0) return;
    final sources = items.map((item) => item.source).toList(growable: false);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AttachmentGalleryScreen(
          images: sources,
          initialIndex: index,
          onReplace: _replacePendingAttachment,
          enableDownload: true,
        ),
      ),
    );
  }

  Future<void> _replacePendingAttachment(EditedImageResult result) async {
    final id = result.sourceId;
    if (!id.startsWith('pending:')) return;
    final uid = id.substring('pending:'.length);
    final index = _pendingAttachments.indexWhere(
      (attachment) => attachment.uid == uid,
    );
    if (index < 0) return;
    setState(() {
      _pendingAttachments[index] = _PendingAttachment(
        uid: uid,
        filePath: result.filePath,
        filename: result.filename,
        mimeType: result.mimeType,
        size: result.size,
      );
    });
  }

  Widget _buildAttachmentPreview(bool isDark) {
    if (_pendingAttachments.isEmpty) return const SizedBox.shrink();
    const tileSize = 62.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        height: tileSize,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (var i = 0; i < _pendingAttachments.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                _buildAttachmentTile(
                  _pendingAttachments[i],
                  isDark: isDark,
                  size: tileSize,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentTile(
    _PendingAttachment attachment, {
    required bool isDark,
    required double size,
  }) {
    final borderColor = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final surfaceColor = isDark
        ? MemoFlowPalette.audioSurfaceDark
        : MemoFlowPalette.audioSurfaceLight;
    final iconColor =
        (isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight)
            .withValues(alpha: 0.6);
    final removeBg = isDark
        ? Colors.black.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.5);
    final shadowColor = Colors.black.withValues(alpha: isDark ? 0.35 : 0.12);
    final isImage = _isImageMimeType(attachment.mimeType);
    final isVideo = _isVideoMimeType(attachment.mimeType);
    final file = _resolvePendingAttachmentFile(attachment);

    Widget content;
    if (isImage && file != null) {
      content = Image.file(
        file,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _attachmentFallback(
            iconColor: iconColor,
            surfaceColor: surfaceColor,
            isImage: true,
          );
        },
      );
    } else if (isVideo && file != null) {
      final entry = MemoVideoEntry(
        id: attachment.uid,
        title: attachment.filename.isNotEmpty ? attachment.filename : 'video',
        mimeType: attachment.mimeType,
        size: attachment.size,
        localFile: file,
        videoUrl: null,
        headers: null,
      );
      content = AttachmentVideoThumbnail(
        entry: entry,
        width: size,
        height: size,
        borderRadius: 14,
        fit: BoxFit.cover,
        showPlayIcon: false,
      );
    } else {
      content = _attachmentFallback(
        iconColor: iconColor,
        surfaceColor: surfaceColor,
        isImage: isImage,
        isVideo: isVideo,
      );
    }

    final tile = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(14), child: content),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: (isImage && file != null)
              ? () => _openAttachmentViewer(attachment)
              : null,
          child: tile,
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: _submitting
                ? null
                : () => _removePendingAttachment(attachment.uid),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: removeBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _attachmentFallback({
    required Color iconColor,
    required Color surfaceColor,
    required bool isImage,
    bool isVideo = false,
  }) {
    return Container(
      color: surfaceColor,
      alignment: Alignment.center,
      child: Icon(
        isImage
            ? Icons.image_outlined
            : (isVideo
                  ? Icons.videocam_outlined
                  : Icons.insert_drive_file_outlined),
        size: 22,
        color: iconColor,
      ),
    );
  }

  Future<void> _capturePhoto() async {
    if (_submitting) return;
    try {
      XFile? photo;
      if (Platform.isWindows) {
        if (!mounted) return;
        final currentContext = context;
        photo = await WindowsCameraCaptureScreen.capture(currentContext);
      } else {
        photo = await _imagePicker.pickImage(source: ImageSource.camera);
      }
      if (!mounted || photo == null) return;

      final path = photo.path.trim();
      if (path.isEmpty) {
        _showSnack('未找到拍照文件。');
        return;
      }

      final file = File(path);
      if (!file.existsSync()) {
        _showSnack('未找到拍照文件。');
        return;
      }

      final filename = path.split(Platform.pathSeparator).last;
      setState(() {
        _pendingAttachments.add(
          _PendingAttachment(
            uid: generateUid(),
            filePath: path,
            filename: filename,
            mimeType: _guessMimeType(filename),
            size: file.lengthSync(),
          ),
        );
      });

      _showSnack('已添加照片附件。');
    } catch (error) {
      _showSnack('拍照失败：$error');
    }
  }

  Future<LocationSettings> _resolveLocationSettings() async {
    final current = ref.read(locationSettingsProvider);
    if (current.enabled) return current;
    final stored = await ref.read(locationSettingsRepositoryProvider).read();
    if (!mounted) return stored;
    await ref
        .read(locationSettingsProvider.notifier)
        .setAll(stored, triggerSync: false);
    return stored;
  }

  String _locationErrorText(Object error) {
    if (error is LocationException) {
      return switch (error.code) {
        'service_disabled' => '定位服务未开启。',
        'permission_denied' => '定位权限被拒绝。',
        'permission_denied_forever' => '定位权限被永久拒绝。',
        'timeout' => '定位超时，请重试。',
        _ => '获取定位失败。',
      };
    }
    if (error is TimeoutException) {
      return '定位超时，请重试。';
    }
    return '获取定位失败。';
  }

  Future<void> _requestLocation() async {
    if (_submitting || _locating) return;
    setState(() => _locating = true);
    try {
      final position = await DeviceLocationService().getCurrentPosition();
      final settings = await _resolveLocationSettings();
      String placeholder = '';
      if (settings.enabled) {
        final geocoder = LocationGeocoder(
          logStore: ref.read(networkLogStoreProvider),
          logBuffer: ref.read(networkLogBufferProvider),
          logManager: ref.read(logManagerProvider),
        );
        placeholder =
            await geocoder.reverseGeocode(
              latitude: position.latitude,
              longitude: position.longitude,
              settings: settings,
            ) ??
            '';
      }
      final next = MemoLocation(
        placeholder: placeholder,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted) return;
      setState(() => _location = next);
      _showSnack('定位已更新：${next.displayText(fractionDigits: 6)}');
    } catch (error) {
      _showSnack(_locationErrorText(error));
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  Future<void> _submit() async {
    final content = _controller.text.trimRight();
    if ((content.trim().isEmpty && _pendingAttachments.isEmpty) ||
        _submitting) {
      return;
    }

    setState(() => _submitting = true);
    try {
      final payload = <String, dynamic>{
        'content': content,
        'attachments': _pendingAttachments.map((e) => e.toPayload()).toList(),
        if (_location != null) 'location': _location!.toJson(),
        if (_linkedMemos.isNotEmpty)
          'relations': _linkedMemos.map((e) => e.toRelationJson()).toList(),
      };
      final result = await _invokeSubmitToMainWindow(payload);

      if (result is bool && !result) {
        _showSnack('保存失败，请检查内容后重试。');
        return;
      }

      await _closeWindow();
    } on MissingPluginException {
      _showSnack('快速输入通道未就绪，请重新打开主窗口后重试。');
    } on PlatformException catch (error) {
      if (_isMainWindowChannelMissing(error)) {
        _showSnack('快速输入通道未就绪，请重新打开主窗口后重试。');
      } else {
        _showSnack('保存失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<dynamic> _invokeSubmitToMainWindow(
    Map<String, dynamic> payload, {
    bool allowRetry = true,
  }) async {
    try {
      return await _invokeMainWindowMethod(
        desktopQuickInputSubmitMethod,
        payload,
      );
    } on MissingPluginException {
      if (!allowRetry) rethrow;
      _mainWindowChannelProbe = null;
      await _wakeMainWindow();
      await Future<void>.delayed(const Duration(milliseconds: 180));
      return _invokeSubmitToMainWindow(payload, allowRetry: false);
    } on PlatformException catch (error) {
      if (!_isMainWindowChannelMissing(error) || !allowRetry) rethrow;
      _mainWindowChannelProbe = null;
      await _wakeMainWindow();
      await Future<void>.delayed(const Duration(milliseconds: 180));
      return _invokeSubmitToMainWindow(payload, allowRetry: false);
    }
  }

  (String label, IconData icon, Color color) _visibilityStyle() {
    return switch (_visibility) {
      'PUBLIC' => ('公开', Icons.public, const Color(0xFF2E8B57)),
      'PROTECTED' => ('工作区', Icons.verified_user, const Color(0xFF4C7CC8)),
      _ => ('私密', Icons.lock_outline, const Color(0xFFB26A2B)),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF171717) : const Color(0xFFF4F4F4);
    final border = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE6E6E6);
    final textMain = isDark ? const Color(0xFFF1F1F1) : const Color(0xFF222222);
    final textMuted = isDark
        ? const Color(0xFF8F8F8F)
        : const Color(0xFF9C9C9C);
    final chipBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : MemoFlowPalette.audioSurfaceLight;
    final chipText = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final chipDelete = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : Colors.grey.shade500;

    final (visibilityLabel, visibilityIcon, visibilityColor) =
        _visibilityStyle();
    final templateSettings = ref.watch(memoTemplateSettingsProvider);
    final availableTemplates = templateSettings.enabled
        ? templateSettings.templates
        : const <MemoTemplate>[];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 4, 2),
                  child: Row(
                    children: [
                      const Expanded(
                        child: DragToMoveArea(child: SizedBox(height: 28)),
                      ),
                      if (_alwaysOnTopSupported)
                        IconButton(
                          tooltip: 'Pin',
                          onPressed: (_pinning || !_alwaysOnTopSupported)
                              ? null
                              : _toggleAlwaysOnTop,
                          icon: _pinning
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: textMuted,
                                  ),
                                )
                              : Icon(
                                  _alwaysOnTop
                                      ? Icons.push_pin
                                      : Icons.push_pin_outlined,
                                  color: _alwaysOnTopSupported
                                      ? textMuted
                                      : textMuted.withValues(alpha: 0.4),
                                ),
                        ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: _submitting ? null : _closeWindow,
                        icon: Icon(Icons.close, color: textMuted),
                      ),
                    ],
                  ),
                ),
                if (_pendingAttachments.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: _buildAttachmentPreview(isDark),
                  ),
                if (_linkedMemos.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _linkedMemos
                          .map(
                            (memo) => InputChip(
                              label: Text(
                                memo.label,
                                style: TextStyle(fontSize: 12, color: chipText),
                              ),
                              backgroundColor: chipBg,
                              deleteIconColor: chipDelete,
                              onDeleted: _submitting
                                  ? null
                                  : () => setState(
                                      () => _linkedMemos.removeWhere(
                                        (entry) => entry.name == memo.name,
                                      ),
                                    ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                if (_locating)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '正在定位...',
                          style: TextStyle(fontSize: 12, color: chipText),
                        ),
                      ],
                    ),
                  ),
                if (_location != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: InputChip(
                        avatar: Icon(
                          Icons.place_outlined,
                          size: 16,
                          color: chipText,
                        ),
                        label: Text(
                          _location!.displayText(fractionDigits: 6),
                          style: TextStyle(fontSize: 12, color: chipText),
                        ),
                        backgroundColor: chipBg,
                        deleteIconColor: chipDelete,
                        onDeleted: _submitting
                            ? null
                            : () => setState(() => _location = null),
                      ),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      autofocus: true,
                      expands: true,
                      maxLines: null,
                      minLines: null,
                      style: TextStyle(
                        fontSize: 17,
                        color: textMain,
                        height: 1.45,
                      ),
                      decoration: InputDecoration(
                        hintText: '写下此刻想法...',
                        hintStyle: TextStyle(color: textMuted),
                        border: InputBorder.none,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _moreToolbarOpen
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: MemoComposeMoreToolbar(
                              isDark: isDark,
                              busy: _submitting,
                              locationBusy: _locating,
                              onBoldPressed: _toggleBold,
                              onListPressed: () => _insertText('- '),
                              onUnderlinePressed: _toggleHighlight,
                              onCameraPressed: () {
                                _closeMoreToolbar();
                                unawaited(_capturePhoto());
                              },
                              onLocationPressed: () {
                                _closeMoreToolbar();
                                unawaited(_requestLocation());
                              },
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: MemoComposePrimaryToolbar(
                          isDark: isDark,
                          busy: _submitting,
                          moreOpen: _moreToolbarOpen,
                          visibilityMessage: '可见性：$visibilityLabel',
                          visibilityIcon: visibilityIcon,
                          visibilityColor: visibilityColor,
                          tagButtonKey: _tagMenuKey,
                          templateButtonKey: _templateMenuKey,
                          todoButtonKey: _todoMenuKey,
                          visibilityButtonKey: _visibilityMenuKey,
                          onTagPressed: () {
                            _closeMoreToolbar();
                            _insertText('#');
                            unawaited(_openTagMenuFromKey(_tagMenuKey));
                          },
                          onTemplatePressed: () {
                            _closeMoreToolbar();
                            unawaited(
                              _openTemplateMenuFromKey(
                                _templateMenuKey,
                                availableTemplates,
                              ),
                            );
                          },
                          onAttachmentPressed: () {
                            _closeMoreToolbar();
                            unawaited(_pickAttachments());
                          },
                          onTodoPressed: () {
                            _closeMoreToolbar();
                            unawaited(
                              _openTodoShortcutMenuFromKey(_todoMenuKey),
                            );
                          },
                          onLinkPressed: () {
                            _closeMoreToolbar();
                            unawaited(_pickLinkMemo());
                          },
                          onToggleMorePressed: _toggleMoreToolbar,
                          onVisibilityPressed: () {
                            _closeMoreToolbar();
                            unawaited(
                              _openVisibilityMenuFromKey(_visibilityMenuKey),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _canSubmit ? _submit : null,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(52, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          backgroundColor: isDark
                              ? MemoFlowPalette.primaryDark
                              : MemoFlowPalette.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: _submitting
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingAttachment {
  const _PendingAttachment({
    required this.uid,
    required this.filePath,
    required this.filename,
    required this.mimeType,
    required this.size,
  });

  final String uid;
  final String filePath;
  final String filename;
  final String mimeType;
  final int size;

  Map<String, dynamic> toPayload() {
    return {
      'uid': uid,
      'file_path': filePath,
      'filename': filename,
      'mime_type': mimeType,
      'file_size': size,
    };
  }
}

class _LinkedMemo {
  const _LinkedMemo({required this.name, required this.label});

  final String name;
  final String label;

  Map<String, dynamic> toRelationJson() {
    return {
      'relatedMemo': {'name': name},
      'type': 'REFERENCE',
    };
  }
}
