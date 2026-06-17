import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../core/app_theme.dart';
import '../../core/desktop_quick_input_channel.dart';
import '../../core/memoflow_palette.dart';
import '../../i18n/strings.g.dart';
import '../../state/settings/device_preferences_provider.dart';
import '../../state/settings/resolved_preferences_provider.dart';
import '../image_preview/widgets/image_preview_gallery_screen.dart';
import '../memos/attachment_gallery_screen.dart';
import '../memos/attachment_video_screen.dart';
import 'desktop_media_preview_request.dart';

class DesktopMediaPreviewWindowApp extends ConsumerWidget {
  const DesktopMediaPreviewWindowApp({
    super.key,
    required this.windowId,
    required this.request,
  });

  final int windowId;
  final DesktopMediaPreviewRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicePrefs = ref.watch(devicePreferencesProvider);
    final resolvedSettings = ref.watch(resolvedAppSettingsProvider);
    final appLocale = appLocaleForLanguage(devicePrefs.language);
    LocaleSettings.setLocale(appLocale);
    final legacyThemePrefs = resolvedSettings.toLegacyAppPreferences();
    MemoFlowPalette.applyThemeColor(
      resolvedSettings.resolvedThemeColor,
      customTheme: resolvedSettings.resolvedCustomTheme,
    );

    return TranslationProvider(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'MemoFlow Media',
        theme: applyPreferencesToTheme(
          buildAppTheme(Brightness.light),
          legacyThemePrefs,
        ),
        darkTheme: applyPreferencesToTheme(
          buildAppTheme(Brightness.dark),
          legacyThemePrefs,
        ),
        themeMode: themeModeFor(devicePrefs.themeMode),
        locale: appLocale.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: TextScaler.linear(textScaleFor(devicePrefs.fontSize)),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: DesktopMediaPreviewWindowScreen(
          windowId: windowId,
          request: request,
        ),
      ),
    );
  }
}

class DesktopMediaPreviewWindowScreen extends StatefulWidget {
  const DesktopMediaPreviewWindowScreen({
    super.key,
    required this.windowId,
    required this.request,
  });

  final int windowId;
  final DesktopMediaPreviewRequest request;

  @override
  State<DesktopMediaPreviewWindowScreen> createState() =>
      _DesktopMediaPreviewWindowScreenState();
}

class _DesktopMediaPreviewWindowScreenState
    extends State<DesktopMediaPreviewWindowScreen> {
  bool _windowVisible = true;

  @override
  void initState() {
    super.initState();
    DesktopMultiWindow.setMethodHandler(_handleMethodCall);
  }

  @override
  void dispose() {
    _windowVisible = false;
    DesktopMultiWindow.setMethodHandler(null);
    super.dispose();
  }

  Future<dynamic> _handleMethodCall(MethodCall call, int _) async {
    if (call.method == desktopMediaPreviewPingMethod) {
      return true;
    }
    if (call.method == desktopSubWindowExitMethod) {
      unawaited(_closeWindow());
      return true;
    }
    if (call.method == desktopSubWindowIsVisibleMethod) {
      return _windowVisible;
    }
    return null;
  }

  Future<void> _closeWindow() async {
    _windowVisible = false;
    try {
      await WindowController.fromWindowId(widget.windowId).close();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    if (request.items.isEmpty) {
      return ImagePreviewGalleryScreen(
        request: request.toImagePreviewOpenRequest(),
        isDesktopOverride: true,
        immersiveDesktopChrome: true,
        onClose: _closeWindow,
      );
    }
    if (request.isSingleVideo) {
      final entry = request.items.single.toVideoEntry();
      return AttachmentVideoScreen(
        title: entry.title,
        localFile: entry.localFile,
        videoUrl: entry.videoUrl,
        thumbnailUrl: entry.thumbnailUrl,
        headers: entry.headers,
        cacheId: entry.id,
        cacheSize: entry.size,
        isDesktopOverride: true,
        immersiveDesktopChrome: true,
        onClose: _closeWindow,
      );
    }
    if (request.isImageOnly) {
      return ImagePreviewGalleryScreen(
        request: request.toImagePreviewOpenRequest(),
        isDesktopOverride: true,
        immersiveDesktopChrome: true,
        onClose: _closeWindow,
      );
    }
    return AttachmentGalleryScreen(
      images: const [],
      items: request.toAttachmentGalleryItems(),
      initialIndex: request.safeInitialIndex,
      enableDownload: request.enableDownload,
      albumName: request.albumName,
      isDesktopOverride: true,
      immersiveDesktopChrome: true,
      onClose: _closeWindow,
    );
  }
}
