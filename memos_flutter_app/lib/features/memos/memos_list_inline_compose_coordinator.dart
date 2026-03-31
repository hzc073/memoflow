import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/memo_template_renderer.dart';
import '../../core/tags.dart';
import '../../core/top_toast.dart';
import '../../core/uid.dart';
import '../../data/models/attachment.dart';
import '../../data/models/memo.dart';
import '../../data/models/memo_location.dart';
import '../../data/models/memo_template_settings.dart';
import '../../i18n/strings.g.dart';
import '../../state/attachments/queued_attachment_stager_provider.dart';
import '../../state/memos/memo_composer_controller.dart';
import '../../state/memos/memo_composer_state.dart';
import '../../state/settings/location_settings_provider.dart';
import '../../state/settings/memo_template_settings_provider.dart';
import '../../state/settings/user_settings_provider.dart';
import '../../state/system/session_provider.dart';
import '../location_picker/show_location_picker.dart';
import '../voice/voice_record_screen.dart';
import 'attachment_gallery_screen.dart';
import 'compose_toolbar_shared.dart';
import 'gallery_attachment_picker.dart' as gallery_picker;
import 'link_memo_sheet.dart';
import 'windows_camera_capture_screen.dart';

typedef InlineComposeLocationPicker =
    Future<MemoLocation?> Function(
      BuildContext context,
      MemoLocation? initialLocation,
    );
typedef InlineComposeGalleryPicker =
    Future<gallery_picker.GalleryAttachmentPickResult?> Function(
      BuildContext context,
    );
typedef InlineComposeFilesPicker = Future<FilePickerResult?> Function();
typedef InlineComposeVoiceRecorder =
    Future<VoiceRecordResult?> Function(BuildContext context);
typedef InlineComposeLinkedMemoSelector =
    Future<Memo?> Function(BuildContext context, Set<String> existingNames);
typedef InlineComposeAttachmentViewer =
    Future<void> Function(
      BuildContext context,
      List<AttachmentImageSource> images,
      int initialIndex,
      Future<void> Function(EditedImageResult result) onReplace,
    );
typedef InlineComposeWindowsCapture = Future<XFile?> Function();
typedef InlineComposeToastPresenter =
    void Function(BuildContext context, String message, {Duration duration});
typedef InlineComposeSnackBarPresenter =
    void Function(BuildContext context, SnackBar snackBar);

@immutable
class InlineComposeSubmissionDraft {
  const InlineComposeSubmissionDraft({
    required this.content,
    required this.visibility,
    required this.tags,
    required this.relations,
    required this.attachmentsPayload,
    required this.pendingAttachments,
    required this.location,
  });

  final String content;
  final String visibility;
  final List<String> tags;
  final List<Map<String, dynamic>> relations;
  final List<Map<String, dynamic>> attachmentsPayload;
  final List<MemoComposerPendingAttachment> pendingAttachments;
  final MemoLocation? location;
}

class MemosListInlineComposeCoordinator extends ChangeNotifier {
  MemosListInlineComposeCoordinator({
    required WidgetRef ref,
    required this.composer,
    required MemoTemplateRenderer templateRenderer,
    required ImagePicker imagePicker,
    this.pickLocationOverride,
    this.pickGalleryOverride,
    this.pickFilesOverride,
    this.recordVoiceOverride,
    this.selectLinkedMemoOverride,
    this.openAttachmentViewerOverride,
    this.captureWindowsPhotoOverride,
    this.showToastOverride,
    this.showSnackBarOverride,
  }) : _ref = ref,
       _templateRenderer = templateRenderer,
       _imagePicker = imagePicker;

  final WidgetRef _ref;
  final MemoTemplateRenderer _templateRenderer;
  final ImagePicker _imagePicker;

  final MemoComposerController composer;
  final InlineComposeLocationPicker? pickLocationOverride;
  final InlineComposeGalleryPicker? pickGalleryOverride;
  final InlineComposeFilesPicker? pickFilesOverride;
  final InlineComposeVoiceRecorder? recordVoiceOverride;
  final InlineComposeLinkedMemoSelector? selectLinkedMemoOverride;
  final InlineComposeAttachmentViewer? openAttachmentViewerOverride;
  final InlineComposeWindowsCapture? captureWindowsPhotoOverride;
  final InlineComposeToastPresenter? showToastOverride;
  final InlineComposeSnackBarPresenter? showSnackBarOverride;

  String _visibility = 'PRIVATE';
  bool _visibilityTouched = false;
  MemoLocation? _location;
  bool _locating = false;

  String resolveDefaultVisibility() {
    final settings = _ref.read(userGeneralSettingProvider).valueOrNull;
    final value = (settings?.memoVisibility ?? '').trim().toUpperCase();
    if (value == 'PUBLIC' || value == 'PROTECTED' || value == 'PRIVATE') {
      return value;
    }
    return 'PRIVATE';
  }

  String normalizeVisibility(String raw) {
    final value = raw.trim().toUpperCase();
    if (value == 'PUBLIC' || value == 'PROTECTED' || value == 'PRIVATE') {
      return value;
    }
    return 'PRIVATE';
  }

  String currentVisibility() {
    if (_visibilityTouched) {
      return normalizeVisibility(_visibility);
    }
    return resolveDefaultVisibility();
  }

  String get visibility => normalizeVisibility(_visibility);
  bool get visibilityTouched => _visibilityTouched;
  MemoLocation? get location => _location;
  bool get locating => _locating;
  Set<String> get linkedMemoNames => composer.linkedMemoNames;

  void setVisibility(String raw) {
    final next = normalizeVisibility(raw);
    if (_visibilityTouched && _visibility == next) return;
    _visibility = next;
    _visibilityTouched = true;
    notifyListeners();
  }

  void resetVisibilityToDefaultTouchState() {
    final next = resolveDefaultVisibility();
    final changed = _visibilityTouched || _visibility != next;
    _visibility = next;
    _visibilityTouched = false;
    if (changed) {
      notifyListeners();
    }
  }

  Future<void> requestLocation(BuildContext context) async {
    if (_locating) return;
    _locating = true;
    notifyListeners();
    try {
      final next = await (pickLocationOverride != null
          ? pickLocationOverride!(context, _location)
          : showLocationPickerSheetOrDialog(
              context: context,
              ref: _ref,
              initialLocation: _location,
            ));
      if (!context.mounted || next == null) return;
      _location = next;
      _showToast(
        context,
        context.t.strings.legacy.msg_location_updated(
          next_displayText_fractionDigits_6: next.displayText(
            fractionDigits: 6,
          ),
        ),
        duration: const Duration(seconds: 2),
      );
    } finally {
      _locating = false;
      if (context.mounted) {
        notifyListeners();
      }
    }
  }

  void clearLocation() {
    if (_location == null && !_locating) return;
    _location = null;
    _locating = false;
    notifyListeners();
  }

  Future<void> openTemplateMenuFromKey(
    BuildContext context,
    GlobalKey key,
    List<MemoTemplate> templates,
  ) async {
    final position = _resolveMenuPosition(context, key);
    if (position == null) return;
    final items = templates.isEmpty
        ? <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              enabled: false,
              child: Text(context.t.strings.legacy.msg_no_templates_yet),
            ),
          ]
        : templates
              .map(
                (template) => PopupMenuItem<String>(
                  value: template.id,
                  child: Text(template.name),
                ),
              )
              .toList(growable: false);

    final selectedId = await showMenu<String>(
      context: context,
      position: position,
      items: items,
    );
    if (!context.mounted || selectedId == null) return;
    MemoTemplate? selected;
    for (final template in templates) {
      if (template.id == selectedId) {
        selected = template;
        break;
      }
    }
    if (selected == null) return;

    final templateSettings = _ref.read(memoTemplateSettingsProvider);
    final locationSettings = _ref.read(locationSettingsProvider);
    final rendered = await _templateRenderer.render(
      templateContent: selected.content,
      variableSettings: templateSettings.variables,
      locationSettings: locationSettings,
    );
    if (!context.mounted) return;
    composer.replaceText(rendered, clearHistory: false);
  }

  Future<void> openTodoShortcutMenuFromKey(
    BuildContext context,
    GlobalKey key,
  ) async {
    final position = _resolveMenuPosition(context, key);
    if (position == null) return;
    final action = await showMenu<MemoComposeTodoShortcutAction>(
      context: context,
      position: position,
      items: [
        PopupMenuItem(
          value: MemoComposeTodoShortcutAction.checkbox,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_box_outlined, size: 18),
              const SizedBox(width: 8),
              Text(context.t.strings.legacy.msg_checkbox),
            ],
          ),
        ),
        PopupMenuItem(
          value: MemoComposeTodoShortcutAction.codeBlock,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.code, size: 18),
              const SizedBox(width: 8),
              Text(context.t.strings.legacy.msg_code_block),
            ],
          ),
        ),
      ],
    );
    if (action == null) return;
    switch (action) {
      case MemoComposeTodoShortcutAction.checkbox:
        composer.toggleTaskList();
        break;
      case MemoComposeTodoShortcutAction.codeBlock:
        composer.insertCodeBlock();
        break;
    }
  }

  Future<void> openVisibilityMenuFromKey(
    BuildContext context,
    GlobalKey key,
  ) async {
    final position = _resolveMenuPosition(context, key);
    if (position == null) return;
    final selection = await showMenu<String>(
      context: context,
      position: position,
      items: [
        PopupMenuItem(
          value: 'PRIVATE',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 18),
              const SizedBox(width: 8),
              Text(context.t.strings.legacy.msg_private_2),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'PROTECTED',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_user, size: 18),
              const SizedBox(width: 8),
              Text(context.t.strings.legacy.msg_protected),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'PUBLIC',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.public, size: 18),
              const SizedBox(width: 8),
              Text(context.t.strings.legacy.msg_public),
            ],
          ),
        ),
      ],
    );
    if (selection == null) return;
    setVisibility(selection);
  }

  Future<void> openLinkMemoSheet(BuildContext context) async {
    final selection = await (selectLinkedMemoOverride != null
        ? selectLinkedMemoOverride!(context, linkedMemoNames)
        : LinkMemoSheet.show(context, existingNames: linkedMemoNames));
    if (!context.mounted || selection == null) return;
    final name = selection.name.trim();
    if (name.isEmpty) return;
    final raw = selection.content.replaceAll(RegExp(r'\s+'), ' ').trim();
    final label = raw.isNotEmpty
        ? _truncateInlineLabel(raw)
        : _truncateInlineLabel(
            name.startsWith('memos/') ? name.substring('memos/'.length) : name,
          );
    composer.addLinkedMemo(MemoComposerLinkedMemo(name: name, label: label));
  }

  void removeLinkedMemo(String name) {
    composer.removeLinkedMemo(name);
  }

  Future<MemoComposerPendingAttachment> _stagePendingAttachment(
    MemoComposerPendingAttachment attachment,
  ) async {
    final workspaceKey =
        _ref.read(appSessionProvider).valueOrNull?.currentKey ?? 'default';
    final staged = await _ref
        .read(queuedAttachmentStagerProvider)
        .stageDraftAttachment(
          uid: attachment.uid,
          filePath: attachment.filePath,
          filename: attachment.filename,
          mimeType: attachment.mimeType,
          size: attachment.size,
          scopeKey: workspaceKey,
        );
    return attachment.copyWith(
      filePath: staged.filePath,
      filename: staged.filename,
      mimeType: staged.mimeType,
      size: staged.size,
    );
  }

  Future<List<MemoComposerPendingAttachment>> _stagePendingAttachments(
    Iterable<MemoComposerPendingAttachment> attachments,
  ) async {
    final staged = <MemoComposerPendingAttachment>[];
    for (final attachment in attachments) {
      staged.add(await _stagePendingAttachment(attachment));
    }
    return staged;
  }

  Future<void> _addPendingAttachmentsStaged(
    Iterable<MemoComposerPendingAttachment> attachments,
  ) async {
    final staged = await _stagePendingAttachments(attachments);
    if (staged.isEmpty) return;
    composer.addPendingAttachments(staged);
  }

  void restoreDraftState({
    required String visibility,
    required MemoLocation? location,
  }) {
    final nextVisibility = normalizeVisibility(visibility);
    final changed =
        _visibility != nextVisibility ||
        !_visibilityTouched ||
        _location?.placeholder != location?.placeholder ||
        _location?.latitude != location?.latitude ||
        _location?.longitude != location?.longitude ||
        _locating;
    _visibility = nextVisibility;
    _visibilityTouched = true;
    _location = location;
    _locating = false;
    if (changed) {
      notifyListeners();
    }
  }

  void resetDraftStateToDefault() {
    final nextVisibility = resolveDefaultVisibility();
    final changed =
        _visibility != nextVisibility ||
        _visibilityTouched ||
        _location != null ||
        _locating;
    _visibility = nextVisibility;
    _visibilityTouched = false;
    _location = null;
    _locating = false;
    if (changed) {
      notifyListeners();
    }
  }

  Future<void> pickGalleryAttachments(BuildContext context) async {
    if (pickGalleryOverride == null &&
        !gallery_picker.isMemoGalleryToolbarSupportedPlatform) {
      _showToast(context, context.t.strings.legacy.msg_gallery_mobile_only);
      return;
    }

    try {
      final result = await (pickGalleryOverride != null
          ? pickGalleryOverride!(context)
          : gallery_picker.pickGalleryAttachments(context));
      if (!context.mounted || result == null) return;
      if (result.attachments.isEmpty) {
        final message = result.skippedCount > 0
            ? context.t.strings.legacy.msg_files_unavailable_from_picker
            : context.t.strings.legacy.msg_no_files_selected;
        _showToast(context, message);
        return;
      }

      await _addPendingAttachmentsStaged(
        result.attachments
            .map(
              (attachment) => MemoComposerPendingAttachment(
                uid: generateUid(),
                filePath: attachment.filePath,
                filename: attachment.filename,
                mimeType: attachment.mimeType,
                size: attachment.size,
                skipCompression: attachment.skipCompression,
              ),
            )
            .toList(growable: false),
      );

      final skipped = [
        if (result.skippedCount > 0)
          context.t.strings.legacy.msg_unavailable_file_count(
            count: result.skippedCount,
          ),
      ];
      final summary = skipped.isEmpty
          ? context.t.strings.legacy.msg_added_files(
              count: result.attachments.length,
            )
          : context.t.strings.legacy.msg_added_files_with_skipped(
              count: result.attachments.length,
              details: skipped.join(', '),
            );
      _showToast(context, summary);
    } catch (error) {
      if (!context.mounted) return;
      _showSnackBar(
        context,
        SnackBar(
          content: Text(
            context.t.strings.legacy.msg_file_selection_failed(error: error),
          ),
        ),
      );
    }
  }

  Future<void> pickAttachments(BuildContext context) async {
    try {
      final result = await (pickFilesOverride != null
          ? pickFilesOverride!()
          : FilePicker.platform.pickFiles(
              allowMultiple: true,
              type: FileType.any,
              withReadStream: true,
            ));
      if (!context.mounted) return;
      final files = result?.files ?? const <PlatformFile>[];
      if (files.isEmpty) return;

      final added = <MemoComposerPendingAttachment>[];
      var missingPathCount = 0;
      Directory? tempDir;
      for (final file in files) {
        String path = (file.path ?? '').trim();
        if (path.isEmpty) {
          final stream = file.readStream;
          final bytes = file.bytes;
          if (stream == null && bytes == null) {
            missingPathCount++;
            continue;
          }
          tempDir ??= await getTemporaryDirectory();
          final name = file.name.trim().isNotEmpty
              ? file.name.trim()
              : 'attachment_${generateUid()}';
          final tempFile = File(
            '${tempDir.path}${Platform.pathSeparator}${generateUid()}_$name',
          );
          if (bytes != null) {
            await tempFile.writeAsBytes(bytes, flush: true);
          } else if (stream != null) {
            final sink = tempFile.openWrite();
            await sink.addStream(stream);
            await sink.close();
          }
          path = tempFile.path;
        }

        if (path.trim().isEmpty) {
          missingPathCount++;
          continue;
        }

        final handle = File(path);
        if (!handle.existsSync()) {
          missingPathCount++;
          continue;
        }
        final size = handle.lengthSync();
        final filename = file.name.trim().isNotEmpty
            ? file.name.trim()
            : path.split(Platform.pathSeparator).last;
        final mimeType = gallery_picker.guessLocalAttachmentMimeType(filename);
        added.add(
          MemoComposerPendingAttachment(
            uid: generateUid(),
            filePath: path,
            filename: filename,
            mimeType: mimeType,
            size: size,
          ),
        );
      }

      if (!context.mounted) return;
      if (added.isEmpty) {
        final message = missingPathCount > 0
            ? context.t.strings.legacy.msg_files_unavailable_from_picker
            : context.t.strings.legacy.msg_no_files_selected;
        _showToast(context, message);
        return;
      }

      await _addPendingAttachmentsStaged(added);
      final skipped = [
        if (missingPathCount > 0)
          context.t.strings.legacy.msg_unavailable_file_count(
            count: missingPathCount,
          ),
      ];
      final summary = skipped.isEmpty
          ? context.t.strings.legacy.msg_added_files(count: added.length)
          : context.t.strings.legacy.msg_added_files_with_skipped(
              count: added.length,
              details: skipped.join(', '),
            );
      _showToast(context, summary);
    } catch (error) {
      if (!context.mounted) return;
      _showSnackBar(
        context,
        SnackBar(
          content: Text(
            context.t.strings.legacy.msg_file_selection_failed(error: error),
          ),
        ),
      );
    }
  }

  Future<void> capturePhoto(BuildContext context) async {
    try {
      final navigator = Navigator.of(context);
      final photo = Platform.isWindows
          ? await (captureWindowsPhotoOverride != null
                ? captureWindowsPhotoOverride!()
                : WindowsCameraCaptureScreen.captureWithNavigator(navigator))
          : await _imagePicker.pickImage(source: ImageSource.camera);
      if (!context.mounted || photo == null) return;
      final path = photo.path.trim();
      if (path.isEmpty) {
        _showSnackBar(
          context,
          SnackBar(
            content: Text(context.t.strings.legacy.msg_camera_file_missing),
          ),
        );
        return;
      }
      final file = File(path);
      if (!file.existsSync()) {
        _showSnackBar(
          context,
          SnackBar(
            content: Text(context.t.strings.legacy.msg_camera_file_missing),
          ),
        );
        return;
      }
      final size = file.lengthSync();
      if (!context.mounted) return;
      final filename = path.split(Platform.pathSeparator).last;
      final mimeType = gallery_picker.guessLocalAttachmentMimeType(filename);
      await _addPendingAttachmentsStaged([
        MemoComposerPendingAttachment(
          uid: generateUid(),
          filePath: path,
          filename: filename,
          mimeType: mimeType,
          size: size,
        ),
      ]);
      _showToast(context, context.t.strings.legacy.msg_added_photo_attachment);
    } catch (error) {
      if (!context.mounted) return;
      if (_isWindowsNoCameraError(error)) {
        _showSnackBar(
          context,
          SnackBar(
            content: Text(context.t.strings.legacy.msg_no_camera_detected),
          ),
        );
        return;
      }
      if (_isWindowsCameraPermissionError(error)) {
        _showSnackBar(
          context,
          SnackBar(
            content: Text(
              context.t.strings.legacy.msg_camera_permission_denied_windows,
            ),
            action: SnackBarAction(
              label: context.t.strings.legacy.msg_settings,
              onPressed: () {
                unawaited(_openWindowsCameraSettings());
              },
            ),
          ),
        );
        return;
      }
      _showSnackBar(
        context,
        SnackBar(
          content: Text(
            context.t.strings.legacy.msg_camera_failed(error: error),
          ),
        ),
      );
    }
  }

  void removePendingAttachment(String uid) {
    final existing = composer.pendingAttachments
        .where((attachment) => attachment.uid == uid)
        .firstOrNull;
    composer.removePendingAttachment(uid);
    if (existing != null) {
      unawaited(
        _ref
            .read(queuedAttachmentStagerProvider)
            .deleteManagedFile(existing.filePath),
      );
    }
  }

  Future<void> openAttachmentViewer(
    BuildContext context,
    MemoComposerPendingAttachment attachment,
  ) async {
    final items = _pendingImageSources();
    if (items.isEmpty) return;
    final index = items.indexWhere(
      (item) => item.attachment.uid == attachment.uid,
    );
    if (index < 0) return;
    final sources = items.map((item) => item.source).toList(growable: false);
    if (openAttachmentViewerOverride != null) {
      await openAttachmentViewerOverride!(
        context,
        sources,
        index,
        replacePendingAttachment,
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AttachmentGalleryScreen(
          images: sources,
          initialIndex: index,
          onReplace: replacePendingAttachment,
          enableDownload: true,
        ),
      ),
    );
  }

  Future<void> replacePendingAttachment(EditedImageResult result) async {
    final sourceId = result.sourceId;
    if (!sourceId.startsWith('inline-pending:')) return;
    final uid = sourceId.substring('inline-pending:'.length);
    final existing = composer.pendingAttachments
        .where((attachment) => attachment.uid == uid)
        .firstOrNull;
    final staged = await _stagePendingAttachment(
      MemoComposerPendingAttachment(
        uid: uid,
        filePath: result.filePath,
        filename: result.filename,
        mimeType: result.mimeType,
        size: result.size,
      ),
    );
    composer.replacePendingAttachment(uid, staged);
    if (existing != null && existing.filePath != staged.filePath) {
      unawaited(
        _ref
            .read(queuedAttachmentStagerProvider)
            .deleteManagedFile(existing.filePath),
      );
    }
  }

  Future<void> addVoiceAttachment(
    BuildContext context,
    VoiceRecordResult result,
  ) async {
    final path = result.filePath.trim();
    if (path.isEmpty) {
      _showSnackBar(
        context,
        SnackBar(
          content: Text(context.t.strings.legacy.msg_recording_path_missing),
        ),
      );
      return;
    }

    final file = File(path);
    if (!file.existsSync()) {
      _showSnackBar(
        context,
        SnackBar(
          content: Text(
            context.t.strings.legacy.msg_recording_file_not_found_2,
          ),
        ),
      );
      return;
    }

    final size = result.size > 0 ? result.size : file.lengthSync();
    final filename = result.fileName.trim().isNotEmpty
        ? result.fileName.trim()
        : path.split(Platform.pathSeparator).last;
    final mimeType = gallery_picker.guessLocalAttachmentMimeType(filename);
    await _addPendingAttachmentsStaged([
      MemoComposerPendingAttachment(
        uid: generateUid(),
        filePath: path,
        filename: filename,
        mimeType: mimeType,
        size: size,
      ),
    ]);
    _showToast(context, context.t.strings.legacy.msg_added_voice_attachment);
  }

  Future<InlineComposeSubmissionDraft?> prepareSubmissionDraft(
    BuildContext context,
  ) async {
    final content = composer.textController.text.trimRight();
    final relations = composer.linkedMemos
        .map((memo) => memo.toRelationJson())
        .toList(growable: false);
    final pendingAttachments = List<MemoComposerPendingAttachment>.from(
      composer.pendingAttachments,
    );
    final hasAttachments = pendingAttachments.isNotEmpty;
    if (content.trim().isEmpty && !hasAttachments) {
      if (relations.isNotEmpty) {
        _showSnackBar(
          context,
          SnackBar(
            content: Text(
              context.t.strings.legacy.msg_enter_content_before_creating_link,
            ),
          ),
        );
        return null;
      }

      final result = await (recordVoiceOverride != null
          ? recordVoiceOverride!(context)
          : Navigator.of(context).push<VoiceRecordResult>(
              MaterialPageRoute(builder: (_) => const VoiceRecordScreen()),
            ));
      if (!context.mounted || result == null) return null;
      await addVoiceAttachment(context, result);
      return null;
    }

    final attachmentsPayload = pendingAttachments
        .map((attachment) {
          final rawPath = attachment.filePath.trim();
          final externalLink = rawPath.isEmpty
              ? ''
              : rawPath.startsWith('content://')
              ? rawPath
              : Uri.file(rawPath).toString();
          return Attachment(
            name: 'attachments/${attachment.uid}',
            filename: attachment.filename,
            type: attachment.mimeType,
            size: attachment.size,
            externalLink: externalLink,
          ).toJson();
        })
        .toList(growable: false);

    return InlineComposeSubmissionDraft(
      content: content,
      visibility: currentVisibility(),
      tags: extractTags(content),
      relations: relations,
      attachmentsPayload: attachmentsPayload,
      pendingAttachments: pendingAttachments,
      location: _location,
    );
  }

  void resetAfterSuccessfulSubmit() {
    composer.replaceText('', clearHistory: true);
    composer.clearPendingAttachments();
    composer.clearLinkedMemos();
    final changed = _location != null || _locating;
    _location = null;
    _locating = false;
    if (changed) {
      notifyListeners();
    }
  }

  RelativeRect? _resolveMenuPosition(BuildContext context, GlobalKey key) {
    final target = key.currentContext;
    if (target == null) return null;
    final overlay = Overlay.of(context).context.findRenderObject();
    final box = target.findRenderObject();
    if (overlay is! RenderBox || box is! RenderBox) return null;
    final rect = Rect.fromPoints(
      box.localToGlobal(Offset.zero, ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    );
    return RelativeRect.fromRect(rect, Offset.zero & overlay.size);
  }

  String _truncateInlineLabel(String text, {int maxLength = 24}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  bool _isImageMimeType(String mimeType) {
    return mimeType.trim().toLowerCase().startsWith('image/');
  }

  File? _resolvePendingAttachmentFile(
    MemoComposerPendingAttachment attachment,
  ) {
    final path = attachment.filePath.trim();
    if (path.isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return file;
  }

  String _pendingSourceId(String uid) => 'inline-pending:$uid';

  List<
    ({AttachmentImageSource source, MemoComposerPendingAttachment attachment})
  >
  _pendingImageSources() {
    final items =
        <
          ({
            AttachmentImageSource source,
            MemoComposerPendingAttachment attachment,
          })
        >[];
    for (final attachment in composer.pendingAttachments) {
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
      ));
    }
    return items;
  }

  Future<void> _openWindowsCameraSettings() async {
    if (!Platform.isWindows) return;
    try {
      await Process.start('cmd', <String>[
        '/c',
        'start',
        '',
        'ms-settings:privacy-webcam',
      ]);
    } catch (_) {}
  }

  bool _isWindowsCameraPermissionError(Object error) {
    if (!Platform.isWindows) return false;
    final message = error.toString().toLowerCase();
    return message.contains('permission') ||
        message.contains('access denied') ||
        message.contains('cameraaccessdenied') ||
        message.contains('privacy');
  }

  bool _isWindowsNoCameraError(Object error) {
    if (!Platform.isWindows) return false;
    final message = error.toString().toLowerCase();
    return message.contains('no camera') ||
        message.contains('no available camera') ||
        message.contains('no device') ||
        message.contains('camera_not_found') ||
        message.contains('camera not found') ||
        message.contains('capture device') ||
        message.contains('cameradelegate') ||
        message.contains('no capture devices') ||
        message.contains('unavailable');
  }

  void _showToast(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    final override = showToastOverride;
    if (override != null) {
      override(context, message, duration: duration);
      return;
    }
    showTopToast(context, message, duration: duration);
  }

  void _showSnackBar(BuildContext context, SnackBar snackBar) {
    final override = showSnackBarOverride;
    if (override != null) {
      override(context, snackBar);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}
