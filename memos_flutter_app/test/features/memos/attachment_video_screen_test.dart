import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/memos/attachment_video_screen.dart';

void main() {
  testWidgets('desktop immersive video omits AppBar back chrome', (
    tester,
  ) async {
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AttachmentVideoScreen(
          title: 'Video',
          isDesktopOverride: true,
          immersiveDesktopChrome: true,
          showViewerCloseButton: true,
          onClose: () async {
            closed = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
    expect(find.text('Video'), findsOneWidget);
    expect(
      find.byKey(const Key('desktop_media_preview_close_button')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(closed, isTrue);
  });
}
