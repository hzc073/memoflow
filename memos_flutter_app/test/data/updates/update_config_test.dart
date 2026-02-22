import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/updates/update_config.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('UpdateAnnouncementConfig.fromJson', () {
    test('reads schema v2 platform-scoped version info', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final config = UpdateAnnouncementConfig.fromJson({
        'schema_version': 2,
        'version_info': {
          'android': {
            'latest_version': '1.1.0',
            'force_update': false,
            'update_source': 'google_play',
            'url':
                'https://play.google.com/store/apps/details?id=com.memoflow.hzc073',
            'publish_at': '2026-03-01T00:00:00Z',
          },
          'ios': {
            'latest_version': '1.0.9',
            'force_update': false,
            'update_source': 'app_store',
            'url': 'https://apps.apple.com/app/id1234567890',
          },
          'windows': {
            'latest_version': '1.0.8',
            'force_update': true,
            'update_source': 'windows_installer',
            'url': 'https://example.com/windows.exe',
          },
        },
        'announcement': {
          'id': 2026030101,
          'title': 'Release Notes',
          'show_when_up_to_date': false,
          'contents': {
            'zh': ['new feature'],
          },
        },
      });

      expect(config.schemaVersion, 2);
      expect(config.versionInfo.latestVersion, '1.1.0');
      expect(config.versionInfo.isForce, isFalse);
      expect(
        config.versionInfo.downloadUrl,
        'https://play.google.com/store/apps/details?id=com.memoflow.hzc073',
      );
      expect(config.versionInfo.updateSource, 'google_play');
      expect(
        config.versionInfo.publishAt,
        DateTime.parse('2026-03-01T00:00:00Z').toUtc(),
      );
      expect(config.announcement.showWhenUpToDate, isFalse);
    });

    test('uses platform-specific block for windows', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final config = UpdateAnnouncementConfig.fromJson({
        'schema_version': 2,
        'version_info': {
          'android': {
            'latest_version': '1.1.0',
            'force_update': false,
            'url': 'https://example.com/android.apk',
          },
          'windows': {
            'latest_version': '1.1.1',
            'force_update': true,
            'update_source': 'windows_installer',
            'url': 'https://example.com/windows.exe',
          },
        },
        'announcement': {
          'id': 2026030102,
          'title': 'Release',
          'contents': {
            'en': ['Update available'],
          },
        },
      });

      expect(config.versionInfo.latestVersion, '1.1.1');
      expect(config.versionInfo.isForce, isTrue);
      expect(config.versionInfo.updateSource, 'windows_installer');
      expect(config.versionInfo.downloadUrl, 'https://example.com/windows.exe');
      expect(config.announcement.showWhenUpToDate, isFalse);
    });

    test('keeps legacy version_info fields working', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final config = UpdateAnnouncementConfig.fromJson({
        'version_info': {
          'latest_version': '1.0.14',
          'is_force': true,
          'download_url': 'https://example.com/app-release.apk',
          'skip_update_version': '1.0.13',
          'debug_version': '999.0',
        },
        'announcement': {
          'id': 1,
          'title': 'Title',
          'showWhenUpToDate': true,
          'contents': ['line1'],
        },
      });

      expect(config.schemaVersion, 1);
      expect(config.versionInfo.latestVersion, '1.0.14');
      expect(config.versionInfo.isForce, isTrue);
      expect(
        config.versionInfo.downloadUrl,
        'https://example.com/app-release.apk',
      );
      expect(config.versionInfo.skipUpdateVersion, '1.0.13');
      expect(config.versionInfo.debugVersion, '999.0');
      expect(config.announcement.showWhenUpToDate, isTrue);
    });

    test('parses multilingual release note item contents', () {
      final config = UpdateAnnouncementConfig.fromJson({
        'version_info': {'latest_version': '1.0.15'},
        'announcement': {
          'id': 20260221,
          'title': 'Release',
          'contents': {
            'en': ['Summary'],
          },
        },
        'release_notes': [
          {
            'version': '1.0.15',
            'date': '2026-02-21',
            'items': [
              {
                'category': 'feature',
                'contents': {
                  'zh': ['新增功能A', '新增功能B'],
                  'en': ['Added feature A', 'Added feature B'],
                },
              },
            ],
          },
        ],
      });

      expect(config.releaseNotes, hasLength(1));
      final entry = config.releaseNotes.first;
      expect(entry.items, hasLength(2));
      expect(entry.items.first.localizedContents['zh'], '新增功能A');
      expect(entry.items.first.localizedContents['en'], 'Added feature A');
      expect(entry.items.first.contentForLanguageCode('de'), 'Added feature A');
      expect(entry.items.last.contentForLanguageCode('zh-CN'), '新增功能B');
    });
  });
}
