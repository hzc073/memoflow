import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/share/share_capture_engine.dart';
import 'package:memos_flutter_app/features/share/share_clip_models.dart';
import 'package:memos_flutter_app/features/share/share_clip_screen.dart';
import 'package:memos_flutter_app/features/share/share_handler.dart';
import 'package:memos_flutter_app/features/share/share_video_download_service.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';


void main() {
  late SharePayload payload;

  setUp(() {
    payload = const SharePayload(
      type: SharePayloadType.text,
      text: 'Interesting Article https://example.com/articles/1',
      title: 'Interesting Article',
    );
  });

  testWidgets('shows loading then returns compose request on save', (
    WidgetTester tester,
  ) async {
    final engine = _CompleterShareCaptureEngine(
      ShareCaptureResult.success(
        finalUrl: Uri.parse('https://example.com/articles/1'),
        articleTitle: 'Interesting Article',
        siteName: 'Example',
        excerpt: 'Summary',
        contentHtml: '<p>Hello world</p>',
        readabilitySucceeded: true,
        pageKind: SharePageKind.article,
      ),
    );
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_buildTestApp(navigatorKey: navigatorKey));

    final routeFuture = navigatorKey.currentState!.push<ShareComposeRequest>(
      MaterialPageRoute<ShareComposeRequest>(
        builder: (_) => ShareClipScreen(payload: payload, engine: engine),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Loading page'), findsWidgets);

    engine.complete();
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocale.en.build().strings.legacy.msg_save_memo));
    await tester.pumpAndSettle();

    final result = await routeFuture;
    expect(result, isNotNull);
    expect(result!.text, contains('# Interesting Article'));
    expect(result.text, contains('Hello world'));
    expect(result.text, isNot(contains('> Summary')));
    expect(result.clipMetadataDraft, isNotNull);
    expect(result.clipMetadataDraft!.sourceName, 'Example');
    expect(result.clipMetadataDraft!.authorName, isEmpty);
  });

  testWidgets('returns link-only compose request when capture fails', (
    WidgetTester tester,
  ) async {
    final engine = _FakeShareCaptureEngine(
      result: ShareCaptureResult.failure(
        finalUrl: Uri.parse('https://example.com/articles/1'),
        failure: ShareCaptureFailure.parserEmpty,
      ),
    );
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_buildTestApp(navigatorKey: navigatorKey));

    final routeFuture = navigatorKey.currentState!.push<ShareComposeRequest>(
      MaterialPageRoute<ShareComposeRequest>(
        builder: (_) => ShareClipScreen(payload: payload, engine: engine),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppLocale.en.build().strings.shareClip.linkOnlyLabel));
    await tester.pumpAndSettle();

    final result = await routeFuture;
    expect(result, isNotNull);
    expect(
      result!.text,
      '[Interesting Article](https://example.com/articles/1)',
    );
  });

  testWidgets('video page shows candidates in preview', (
    WidgetTester tester,
  ) async {
    final downloadService = ShareVideoDownloadService(
      client: _FakeShareVideoHttpClient(
        probeResult: const ShareVideoHttpProbeResult(
          contentLength: 2097152,
          mimeType: 'video/mp4',
        ),
      ),
      readCookieHeader: (_) async => null,
    );
    final engine = _FakeShareCaptureEngine(
      result: ShareCaptureResult.success(
        finalUrl: Uri.parse('https://www.bilibili.com/video/BV1xx'),
        articleTitle: 'Bilibili Video',
        excerpt: 'Video summary',
        leadImageUrl: 'https://cdn.example.com/poster.jpg',
        pageKind: SharePageKind.video,
        videoCandidates: const [
          ShareVideoCandidate(
            id: 'video-1',
            url: 'https://cdn.example.com/video.mp4',
            title: 'Candidate Video',
            source: ShareVideoSource.parser,
            isDirectDownloadable: true,
            parserTag: 'bilibili',
          ),
        ],
      ),
    );
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_buildTestApp(navigatorKey: navigatorKey));

    navigatorKey.currentState!.push<ShareComposeRequest>(
      MaterialPageRoute<ShareComposeRequest>(
        builder: (_) => ShareClipScreen(
          payload: payload,
          engine: engine,
          downloadService: downloadService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppLocale.en.build().strings.shareClip.videoCandidatesTitle), findsOneWidget);
    expect(find.text('Candidate Video'), findsOneWidget);
    expect(find.text(AppLocale.en.build().strings.shareClip.downloadAndAttach), findsOneWidget);
    expect(find.text('2.0 MB'), findsOneWidget);
    expect(find.text('https://cdn.example.com/video.mp4'), findsNothing);
  });
  testWidgets('video page without direct candidates auto falls back to link-only', (
    WidgetTester tester,
  ) async {
    final engine = _FakeShareCaptureEngine(
      result: ShareCaptureResult.success(
        finalUrl: Uri.parse('https://www.bilibili.com/video/BV1xx'),
        articleTitle: 'Bilibili Video',
        pageKind: SharePageKind.video,
        unsupportedVideoCandidates: const [
          ShareVideoCandidate(
            id: 'stream-1',
            url: 'https://cdn.example.com/video.m3u8',
            source: ShareVideoSource.parser,
            isDirectDownloadable: false,
            parserTag: 'bilibili',
          ),
        ],
      ),
    );
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_buildTestApp(navigatorKey: navigatorKey));

    ShareComposeRequest? fallbackRequest;
    navigatorKey.currentState!
        .push<ShareComposeRequest>(
          MaterialPageRoute<ShareComposeRequest>(
            builder: (_) => ShareClipScreen(payload: payload, engine: engine),
          ),
        )
        .then((value) => fallbackRequest = value);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(fallbackRequest, isNotNull);
    expect(fallbackRequest!.attachmentPaths, isEmpty);
    expect(
      fallbackRequest!.userMessage,
      AppLocale.en.build().strings.shareClip.fallbackParseFailed,
    );
  });
}

Widget _buildTestApp({required GlobalKey<NavigatorState> navigatorKey}) {
  LocaleSettings.setLocale(AppLocale.en);
  return TranslationProvider(
    child: MaterialApp(
      navigatorKey: navigatorKey,
      locale: AppLocale.en.flutterLocale,
      supportedLocales: AppLocaleUtils.supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const Scaffold(body: SizedBox.shrink()),
    ),
  );
}

class _FakeShareCaptureEngine implements ShareCaptureEngine {
  _FakeShareCaptureEngine({required this.result});

  final ShareCaptureResult result;

  @override
  Future<ShareCaptureResult> capture(
    ShareCaptureRequest request, {
    void Function(ShareCaptureStage stage)? onStageChanged,
  }) async {
    onStageChanged?.call(ShareCaptureStage.loadingPage);
    await Future<void>.delayed(Duration.zero);
    onStageChanged?.call(ShareCaptureStage.buildingPreview);
    return result;
  }
}

class _CompleterShareCaptureEngine implements ShareCaptureEngine {
  _CompleterShareCaptureEngine(this.result);

  final ShareCaptureResult result;
  final Completer<void> _completer = Completer<void>();

  void complete() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  @override
  Future<ShareCaptureResult> capture(
    ShareCaptureRequest request, {
    void Function(ShareCaptureStage stage)? onStageChanged,
  }) async {
    onStageChanged?.call(ShareCaptureStage.loadingPage);
    await _completer.future;
    onStageChanged?.call(ShareCaptureStage.buildingPreview);
    return result;
  }
}

class _FakeShareVideoHttpClient implements ShareVideoHttpClient {
  _FakeShareVideoHttpClient({
    this.probeResult = const ShareVideoHttpProbeResult(),
  });

  final ShareVideoHttpProbeResult probeResult;

  @override
  Future<void> download(
    String url,
    String savePath, {
    required Map<String, String> headers,
    void Function(double progress)? onProgress,
  }) async {}

  @override
  Future<ShareVideoHttpProbeResult> probe(
    String url, {
    required Map<String, String> headers,
  }) async {
    return probeResult;
  }
}

