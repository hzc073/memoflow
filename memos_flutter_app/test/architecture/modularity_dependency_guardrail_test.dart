import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('modularity phase is declared and uses a quantified gate', () async {
    final config = await File('../openspec/config.yaml').readAsString();

    expect(
      _readArchitecturePhase(config),
      isNotNull,
      reason:
          'Expected `openspec/config.yaml` to declare an architecture '
          'phase as `Architecture phase: evolve_modularity` or '
          '`Architecture phase: preserve_modularity`.',
    );
    expect(
      config.contains(
        'Preserve-phase gate: score >= 8/10 and all critical items satisfied.',
      ),
      isTrue,
      reason:
          'Expected `openspec/config.yaml` to quantify the preserve-phase '
          'gate instead of relying on a vague 80% statement.',
    );
  });

  test(
    'state to features reverse dependencies stay inside the evolve allowlist',
    () async {
      const evolveAllowlist = <String>{
        'lib/state/memos/desktop_memo_preview_session.dart -> lib/features/memos/memo_detail_screen.dart',
        'lib/state/memos/memo_mutation_service.dart -> lib/features/share/share_clip_models.dart',
        'lib/state/memos/memos_providers.dart -> lib/features/share/share_inline_image_content.dart',
        'lib/state/memos/note_input_controller.dart -> lib/features/share/share_clip_models.dart',
        'lib/state/settings/workspace_preferences_provider.dart -> lib/features/home/home_navigation_resolver.dart',
      };

      final config = await File('../openspec/config.yaml').readAsString();
      final phase = _readArchitecturePhase(config);
      expect(phase, isNotNull);

      final violations = await _findLayerImports('state', {'features'});
      final unexpected = _unexpectedViolations(
        found: violations,
        phase: phase!,
        evolveAllowlist: evolveAllowlist,
      );

      expect(
        unexpected,
        isEmpty,
        reason: unexpected.isEmpty
            ? null
            : 'Unexpected `state -> features` imports detected:\n'
                  '${unexpected.join('\n')}',
      );
    },
  );

  test('application to features dependencies stay inside the evolve allowlist', () async {
    const evolveAllowlist = <String>{
      'lib/application/desktop/desktop_quick_input_controller.dart -> lib/features/memos/link_memo_sheet.dart',
      'lib/application/startup/startup_coordinator.dart -> lib/features/memos/memo_detail_screen.dart',
      'lib/application/startup/startup_coordinator.dart -> lib/features/memos/note_input_sheet.dart',
      'lib/application/startup/startup_coordinator.dart -> lib/features/share/share_clip_models.dart',
      'lib/application/startup/startup_coordinator.dart -> lib/features/share/share_clip_screen.dart',
      'lib/application/startup/startup_coordinator.dart -> lib/features/share/share_handler.dart',
      'lib/application/startup/startup_coordinator.dart -> lib/features/share/share_quick_clip_models.dart',
      'lib/application/startup/startup_coordinator.dart -> lib/features/share/share_quick_clip_service.dart',
      'lib/application/startup/startup_coordinator.dart -> lib/features/share/share_quick_clip_sheet.dart',
      'lib/application/widgets/home_widget_snapshot_builder.dart -> lib/features/review/random_walk_display.dart',
      'lib/application/widgets/home_widget_snapshot_builder.dart -> lib/features/review/random_walk_models.dart',
      'lib/application/widgets/home_widget_snapshot_builder.dart -> lib/features/review/random_walk_providers.dart',
    };

    final config = await File('../openspec/config.yaml').readAsString();
    final phase = _readArchitecturePhase(config);
    expect(phase, isNotNull);

    final violations = await _findLayerImports('application', {'features'});
    final unexpected = _unexpectedViolations(
      found: violations,
      phase: phase!,
      evolveAllowlist: evolveAllowlist,
    );

    expect(
      unexpected,
      isEmpty,
      reason: unexpected.isEmpty
          ? null
          : 'Unexpected `application -> features` imports detected:\n'
                '${unexpected.join('\n')}',
    );
  });

  test('core upward dependencies stay inside the evolve allowlist', () async {
    const evolveAllowlist = <String>{
      'lib/core/desktop_window_controls.dart -> lib/application/desktop/desktop_exit_coordinator.dart',
      'lib/core/drawer_navigation.dart -> lib/application/desktop/desktop_settings_window.dart',
      'lib/core/sync_error_presenter.dart -> lib/application/sync/sync_error.dart',
      'lib/core/sync_error_presenter.dart -> lib/state/settings/preferences_provider.dart',
    };

    final config = await File('../openspec/config.yaml').readAsString();
    final phase = _readArchitecturePhase(config);
    expect(phase, isNotNull);

    final violations = await _findLayerImports('core', {
      'state',
      'application',
      'features',
    });
    final unexpected = _unexpectedViolations(
      found: violations,
      phase: phase!,
      evolveAllowlist: evolveAllowlist,
    );

    expect(
      unexpected,
      isEmpty,
      reason: unexpected.isEmpty
          ? null
          : 'Unexpected upward imports from `core` detected:\n'
                '${unexpected.join('\n')}',
    );
  });

  test('focused DB persistence files stay in the data layer', () async {
    final files = <File>[
      File('lib/data/db/ai_db_persistence.dart'),
      File('lib/data/db/collection_db_persistence.dart'),
      File('lib/data/db/memo_auxiliary_db_persistence.dart'),
      File('lib/data/db/memo_core_db_persistence.dart'),
      File('lib/data/db/memo_query_db_persistence.dart'),
      File('lib/data/db/memo_tag_reconciler.dart'),
      File('lib/data/db/memo_search_db_persistence.dart'),
      File('lib/data/db/outbox_db_persistence.dart'),
      File('lib/data/db/quick_clip_recovery_db_persistence.dart'),
      File('lib/data/db/rss_db_persistence.dart'),
      File('lib/data/db/stats_cache_db_persistence.dart'),
      File('lib/data/db/tag_db_persistence.dart'),
      File('lib/data/db/memo_lifecycle_db_persistence.dart'),
      File('lib/data/db/memo_write_db_persistence.dart'),
    ];

    final violations = <String>[];
    for (final file in files) {
      final contents = await file.readAsString();
      for (final match in RegExp(
        r"^import '([^']+)';",
        multiLine: true,
      ).allMatches(contents)) {
        final importPath = match.group(1)!;
        if (importPath.startsWith('dart:')) {
          continue;
        }
        final normalized = importPath.replaceAll('\\', '/');
        if (normalized.startsWith('package:memos_flutter_app/features/') ||
            normalized.startsWith('package:memos_flutter_app/state/') ||
            normalized.startsWith('package:memos_flutter_app/application/') ||
            normalized.startsWith('../features/') ||
            normalized.startsWith('../../features/') ||
            normalized.startsWith('../state/') ||
            normalized.startsWith('../../state/') ||
            normalized.startsWith('../application/') ||
            normalized.startsWith('../../application/')) {
          violations.add('${file.path}: $importPath');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'Focused DB persistence files must not import higher layers:\n'
                '${violations.join('\n')}',
    );
  });

  test('state search code uses the pure memo search document helper', () async {
    const forbiddenPatterns = <String>{
      'AppDatabase.buildMemoSearchDocument(',
      'AppDatabase.buildCanonicalMemoSearchDocument(',
    };

    final violations = <String>[];
    final dir = Directory('lib/state/memos');
    await for (final entry in dir.list(recursive: true, followLinks: false)) {
      if (entry is! File || p.extension(entry.path) != '.dart') continue;
      final relative = p
          .relative(entry.path, from: Directory.current.path)
          .replaceAll('\\', '/');
      final contents = await entry.readAsString();
      for (final pattern in forbiddenPatterns) {
        if (contents.contains(pattern)) {
          violations.add('$relative: $pattern');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'State search code must use MemoSearchDocumentBuilder instead of '
                'AppDatabase pure search-document helpers:\n'
                '${violations.join('\n')}',
    );
  });

  test(
    'self repair UI does not import focused DB persistence helpers',
    () async {
      final files = <File>[
        File('lib/features/settings/feedback_screen.dart'),
        File('lib/features/settings/self_repair_screen.dart'),
      ];
      final forbiddenImports = <String>{
        'memo_search_db_persistence.dart',
        'tag_db_persistence.dart',
        'stats_cache_db_persistence.dart',
        'memo_tag_reconciler.dart',
      };
      final violations = <String>[];

      for (final file in files) {
        final contents = await file.readAsString();
        for (final match in RegExp(
          r"^import '([^']+)';",
          multiLine: true,
        ).allMatches(contents)) {
          final importPath = match.group(1)!.replaceAll('\\', '/');
          if (forbiddenImports.any(importPath.endsWith)) {
            violations.add('${file.path}: $importPath');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: violations.isEmpty
            ? null
            : 'Self-repair UI must route through service/facade seams:\n'
                  '${violations.join('\n')}',
      );
    },
  );

  test(
    'self repair service keeps maintenance behind AppDatabase facade',
    () async {
      final file = File(
        'lib/state/maintenance/self_repair_mutation_service.dart',
      );
      final contents = await file.readAsString();
      final violations = <String>[];

      for (final match in RegExp(
        r"^import '([^']+)';",
        multiLine: true,
      ).allMatches(contents)) {
        final importPath = match.group(1)!.replaceAll('\\', '/');
        if (importPath.contains('/features/') ||
            importPath.endsWith('memo_search_db_persistence.dart') ||
            importPath.endsWith('tag_db_persistence.dart') ||
            importPath.endsWith('stats_cache_db_persistence.dart') ||
            importPath.endsWith('memo_tag_reconciler.dart')) {
          violations.add(importPath);
        }
      }

      expect(
        violations,
        isEmpty,
        reason: violations.isEmpty
            ? null
            : 'Self-repair service must avoid feature and persistence-helper '
                  'imports:\n${violations.join('\n')}',
      );
    },
  );

  test(
    'AppDatabase does not re-own pure memo search document builders',
    () async {
      final contents = await File(
        'lib/data/db/app_database.dart',
      ).readAsString();

      const forbiddenPatterns = <String>{
        'static String buildMemoSearchDocument(',
        'static String buildCanonicalMemoSearchDocument(',
      };
      final violations = forbiddenPatterns
          .where(contents.contains)
          .toList(growable: false);

      expect(
        violations,
        isEmpty,
        reason: violations.isEmpty
            ? null
            : 'Pure memo search document builders should stay outside '
                  'AppDatabase:\n${violations.join('\n')}',
      );
    },
  );

  test('AppDatabase does not re-own outbox persistence details', () async {
    final contents = await File('lib/data/db/app_database.dart').readAsString();

    const forbiddenPatterns = <String>{
      'CREATE TABLE IF NOT EXISTS outbox',
      '_decodeOutboxPayload',
      '_extractOutboxMemoUid',
      '_withDerivedOutboxAttentionFields',
      '_migrateLegacyOutboxErrors',
      'UPDATE outbox SET state',
    };
    final violations = forbiddenPatterns
        .where(contents.contains)
        .toList(growable: false);

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'Outbox SQLite details should stay outside AppDatabase:\n'
                '${violations.join('\n')}',
    );
  });

  test('AppDatabase does not re-own tag persistence details', () async {
    final contents = await File('lib/data/db/app_database.dart').readAsString();

    const forbiddenPatterns = <String>{
      'CREATE TABLE IF NOT EXISTS tags (',
      'CREATE TABLE IF NOT EXISTS tag_aliases (',
      'CREATE TABLE IF NOT EXISTS memo_tags (',
      'static Future<void> _ensureTagTables(',
      'static Future<ResolvedTag?> _resolveTagPath(',
      'static Future<void> _updateMemoTagsMapping(',
    };
    final violations = forbiddenPatterns
        .where(contents.contains)
        .toList(growable: false);

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'Tag SQLite details should stay outside AppDatabase:\n'
                '${violations.join('\n')}',
    );
  });

  test(
    'AppDatabase does not re-own memo lifecycle persistence details',
    () async {
      final contents = await File(
        'lib/data/db/app_database.dart',
      ).readAsString();

      const forbiddenPatterns = <String>{
        'CREATE TABLE IF NOT EXISTS memo_relations_cache (',
        'CREATE TABLE IF NOT EXISTS memo_versions (',
        'CREATE TABLE IF NOT EXISTS recycle_bin_items (',
        'CREATE TABLE IF NOT EXISTS memo_delete_tombstones (',
        'CREATE TABLE IF NOT EXISTS memo_inline_image_sources (',
        'CREATE INDEX IF NOT EXISTS idx_memo_versions_memo_time',
        'CREATE INDEX IF NOT EXISTS idx_recycle_bin_items_deleted_time',
        'CREATE INDEX IF NOT EXISTS idx_recycle_bin_items_expire_time',
        'CREATE INDEX IF NOT EXISTS idx_memo_delete_tombstones_state_updated',
        'CREATE INDEX IF NOT EXISTS idx_memo_inline_image_sources_memo',
      };
      final violations = forbiddenPatterns
          .where(contents.contains)
          .toList(growable: false);

      expect(
        violations,
        isEmpty,
        reason: violations.isEmpty
            ? null
            : 'Memo lifecycle SQLite details should stay outside AppDatabase:\n'
                  '${violations.join('\n')}',
      );
    },
  );

  test(
    'AppDatabaseWriteDao does not re-own memo lifecycle table-local helpers',
    () async {
      final contents = await File(
        'lib/data/db/app_database_write_dao.dart',
      ).readAsString();

      const forbiddenPatterns = <String>{
        '_upsertMemoRelationsCache(',
        '_deleteMemoRelationsCache(',
        '_upsertMemoDeleteTombstone(',
        "insert('memo_versions'",
        "insert('recycle_bin_items'",
        "insert('memo_inline_image_sources'",
        "insert('memo_delete_tombstones'",
        "delete('recycle_bin_items'",
        "delete('memo_versions'",
        "delete('memo_relations_cache'",
        "delete('memo_inline_image_sources'",
        "delete('memo_delete_tombstones'",
      };
      final violations = forbiddenPatterns
          .where(contents.contains)
          .toList(growable: false);

      expect(
        violations,
        isEmpty,
        reason: violations.isEmpty
            ? null
            : 'Memo lifecycle table primitives should stay outside '
                  'AppDatabaseWriteDao:\n${violations.join('\n')}',
      );
    },
  );

  test('AppDatabase does not re-own AI persistence details', () async {
    final contents = await File('lib/data/db/app_database.dart').readAsString();

    const forbiddenPatterns = <String>{
      'CREATE TABLE IF NOT EXISTS ai_memo_policy (',
      'CREATE TABLE IF NOT EXISTS ai_chunks (',
      'CREATE TABLE IF NOT EXISTS ai_embeddings (',
      'CREATE TABLE IF NOT EXISTS ai_index_jobs (',
      'CREATE TABLE IF NOT EXISTS ai_analysis_tasks (',
      'CREATE TABLE IF NOT EXISTS ai_analysis_results (',
      'CREATE TABLE IF NOT EXISTS ai_analysis_sections (',
      'CREATE TABLE IF NOT EXISTS ai_analysis_evidences (',
      'CREATE INDEX IF NOT EXISTS idx_ai_chunks_memo_active_idx',
      'CREATE INDEX IF NOT EXISTS idx_ai_chunks_time_active',
      'CREATE INDEX IF NOT EXISTS idx_ai_chunks_content_hash',
      'CREATE INDEX IF NOT EXISTS idx_ai_embeddings_chunk_status',
      'CREATE INDEX IF NOT EXISTS idx_ai_embeddings_model_status',
      'CREATE INDEX IF NOT EXISTS idx_ai_embeddings_profile',
      'CREATE INDEX IF NOT EXISTS idx_ai_index_jobs_status_priority',
      'CREATE INDEX IF NOT EXISTS idx_ai_index_jobs_memo_profile_hash',
      'CREATE INDEX IF NOT EXISTS idx_ai_analysis_tasks_status_time',
      'CREATE INDEX IF NOT EXISTS idx_ai_analysis_tasks_type_time',
      'CREATE INDEX IF NOT EXISTS idx_ai_analysis_sections_result_order',
      'CREATE INDEX IF NOT EXISTS idx_ai_analysis_evidences_result_section_order',
      'CREATE INDEX IF NOT EXISTS idx_ai_analysis_evidences_memo_uid',
      'CREATE INDEX IF NOT EXISTS idx_ai_analysis_evidences_chunk_id',
      "table: 'ai_analysis_tasks'",
    };
    final violations = forbiddenPatterns
        .where(contents.contains)
        .toList(growable: false);

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'AI SQLite details should stay outside AppDatabase:\n'
                '${violations.join('\n')}',
    );
  });

  test(
    'AppDatabaseWriteDao does not re-own AI table-local write SQL',
    () async {
      final contents = await File(
        'lib/data/db/app_database_write_dao.dart',
      ).readAsString();

      const forbiddenPatterns = <String>{
        "insert('ai_memo_policy'",
        "insert('ai_index_jobs'",
        "insert('ai_chunks'",
        "insert('ai_embeddings'",
        "insert('ai_analysis_tasks'",
        "insert('ai_analysis_results'",
        "insert('ai_analysis_sections'",
        "insert('ai_analysis_evidences'",
        "update('ai_index_jobs'",
        "update('ai_chunks'",
        "update('ai_analysis_tasks'",
        'UPDATE ai_embeddings SET',
        'UPDATE ai_analysis_results',
        '_backendKindToStorage(',
        '_providerKindToStorage(',
      };
      final violations = forbiddenPatterns
          .where(contents.contains)
          .toList(growable: false);

      expect(
        violations,
        isEmpty,
        reason: violations.isEmpty
            ? null
            : 'AI table primitives should stay outside AppDatabaseWriteDao:\n'
                  '${violations.join('\n')}',
      );
    },
  );

  test('AppDatabase does not re-own collection persistence details', () async {
    final contents = await File('lib/data/db/app_database.dart').readAsString();

    const forbiddenPatterns = <String>{
      'CREATE TABLE IF NOT EXISTS memo_collections (',
      'CREATE TABLE IF NOT EXISTS memo_collection_items (',
      'CREATE TABLE IF NOT EXISTS collection_read_progress (',
      'CREATE INDEX IF NOT EXISTS idx_memo_collections_archived_pinned_order',
      'CREATE INDEX IF NOT EXISTS idx_memo_collections_updated_time',
      'CREATE INDEX IF NOT EXISTS idx_memo_collection_items_collection_order',
      'CREATE INDEX IF NOT EXISTS idx_collection_read_progress_updated',
      "table: 'collection_read_progress'",
      "query('collection_read_progress'",
    };
    final violations = forbiddenPatterns
        .where(contents.contains)
        .toList(growable: false);

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'Collection SQLite details should stay outside AppDatabase:\n'
                '${violations.join('\n')}',
    );
  });

  test('AppDatabase does not re-own RSS persistence details', () async {
    final contents = await File('lib/data/db/app_database.dart').readAsString();

    const forbiddenPatterns = <String>{
      'CREATE TABLE IF NOT EXISTS rss_feeds (',
      'CREATE TABLE IF NOT EXISTS rss_articles (',
      'CREATE TABLE IF NOT EXISTS collection_rss_sources (',
      'CREATE INDEX IF NOT EXISTS idx_rss_feeds_feed_url',
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_rss_articles_feed_guid',
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_rss_articles_feed_link',
      'CREATE INDEX IF NOT EXISTS idx_rss_articles_feed_time',
      'CREATE INDEX IF NOT EXISTS idx_collection_rss_sources_collection_order',
    };
    final violations = forbiddenPatterns
        .where(contents.contains)
        .toList(growable: false);

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'RSS SQLite details should stay outside AppDatabase:\n'
                '${violations.join('\n')}',
    );
  });

  test('RSS lower layers do not import collection or share UI modules', () async {
    final files = <File>[
      File('lib/application/rss/rss_feed_discovery.dart'),
      File('lib/application/rss/rss_feed_fetch_service.dart'),
      File('lib/application/rss/rss_feed_parser.dart'),
      File('lib/application/rss/rss_full_content_extractor.dart'),
      File('lib/application/rss/rss_full_content_service.dart'),
      File('lib/application/rss/rss_html_sanitizer.dart'),
      File('lib/application/rss/rss_http.dart'),
      File('lib/application/rss/rss_refresh_coordinator.dart'),
      File('lib/data/db/rss_db_persistence.dart'),
      File('lib/data/repositories/rss_repository.dart'),
      File('lib/data/models/rss_article.dart'),
      File('lib/data/models/rss_feed.dart'),
      File('lib/data/models/rss_feed_preview.dart'),
    ];

    final violations = <String>[];
    for (final file in files) {
      final contents = await file.readAsString();
      for (final match in RegExp(
        r"^import '([^']+)';",
        multiLine: true,
      ).allMatches(contents)) {
        final importPath = match.group(1)!.replaceAll('\\', '/');
        if (importPath.startsWith('package:memos_flutter_app/features/') ||
            importPath.startsWith('../../features/') ||
            importPath.startsWith('../features/')) {
          violations.add('${file.path}: $importPath');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'RSS data/application layers must not import collection/share UI:\n'
                '${violations.join('\n')}',
    );
  });

  test(
    'collection RSS widgets do not own RSS parsing or fetching primitives',
    () async {
      final files = Directory('lib/features/collections')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList(growable: false);

      const forbiddenPatterns = <String>{
        'RssFeedParser(',
        'RssFeedDiscovery(',
        'RssFullContentExtractor(',
        'RssHtmlSanitizer(',
        'package:http/',
        'HttpClient(',
      };
      final violations = <String>[];
      for (final file in files) {
        final contents = await file.readAsString();
        for (final pattern in forbiddenPatterns) {
          if (contents.contains(pattern)) {
            violations.add('${file.path}: $pattern');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: violations.isEmpty
            ? null
            : 'Collection RSS UI must use RSS service/repository seams, not '
                  'parser/fetch primitives:\n${violations.join('\n')}',
      );
    },
  );

  test(
    'RSS collection-open refresh does not move scheduling into app roots or platform background dependencies',
    () async {
      final rootFiles = <File>[File('lib/app.dart'), File('lib/main.dart')];
      const rootForbiddenPatterns = <String>{
        'rssRefreshCoordinatorProvider',
        'RssRefreshCoordinator',
        'refreshCollectionOnOpen',
        'rssFeedFetchServiceProvider',
      };
      final violations = <String>[];
      for (final file in rootFiles) {
        final contents = await file.readAsString();
        for (final pattern in rootForbiddenPatterns) {
          if (contents.contains(pattern)) {
            violations.add('${file.path}: $pattern');
          }
        }
      }

      final pubspec = await File('pubspec.yaml').readAsString();
      const backgroundSchedulerDeps = <String>{
        'workmanager:',
        'background_fetch:',
        'android_alarm_manager_plus:',
      };
      for (final dependency in backgroundSchedulerDeps) {
        if (pubspec.contains(dependency)) {
          violations.add('pubspec.yaml: $dependency');
        }
      }

      final platformFiles = <File>[
        ...Directory('android').existsSync()
            ? Directory('android')
                  .listSync(recursive: true)
                  .whereType<File>()
                  .where(_isPlatformRefreshGuardrailFile)
            : const <File>[],
        ...Directory('ios').existsSync()
            ? Directory('ios')
                  .listSync(recursive: true)
                  .whereType<File>()
                  .where(_isPlatformRefreshGuardrailFile)
            : const <File>[],
      ];
      const platformForbiddenPatterns = <String>{
        'SCHEDULE_EXACT_ALARM',
        'RECEIVE_BOOT_COMPLETED',
        'BGTaskSchedulerPermittedIdentifiers',
        'Workmanager',
        'BackgroundFetch',
      };
      for (final file in platformFiles) {
        final contents = await file.readAsString();
        if (!contents.toLowerCase().contains('rss')) continue;
        for (final pattern in platformForbiddenPatterns) {
          if (contents.contains(pattern)) {
            violations.add('${file.path}: $pattern');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: violations.isEmpty
            ? null
            : 'RSS collection-open refresh must stay out of app roots and '
                  'must not add platform background scheduling hooks:\n'
                  '${violations.join('\n')}',
      );
    },
  );

  test('lower layers do not import collection article-flow widgets', () async {
    final roots = <Directory>[
      Directory('lib/state/collections'),
      Directory('lib/application/rss'),
      Directory('lib/data'),
      Directory('lib/core'),
    ];
    const forbiddenTargets = <String>{
      'lib/features/collections/collection_article_flow_screen.dart',
      'lib/features/collections/collection_detail_screen.dart',
      'lib/features/collections/collection_reader_screen.dart',
      'lib/features/collections/collection_reader_shell.dart',
    };

    final violations = <String>[];
    for (final root in roots) {
      if (!root.existsSync()) continue;
      await for (final entry in root.list(recursive: true)) {
        if (entry is! File || p.extension(entry.path) != '.dart') continue;
        final source = p
            .relative(entry.path, from: Directory.current.path)
            .replaceAll('\\', '/');
        final contents = await entry.readAsString();
        for (final match in RegExp(
          r"^import '([^']+)';",
          multiLine: true,
        ).allMatches(contents)) {
          final target = _resolveLocalImport(source, match.group(1)!);
          if (target != null && forbiddenTargets.contains(target)) {
            violations.add('$source -> $target');
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'Collection article-flow widgets must remain above state, '
                'application, data, and core layers:\n'
                '${violations.join('\n')}',
    );
  });

  test(
    'public collection RSS flow does not introduce commercial hooks',
    () async {
      final files = <File>[
        File('lib/features/collections/collection_article_flow_screen.dart'),
        File('lib/features/collections/collection_detail_screen.dart'),
        File('lib/features/collections/collection_reader_screen.dart'),
        File('lib/features/collections/collection_reader_shell.dart'),
        File('lib/features/collections/collection_reader_vertical_view.dart'),
        File('lib/state/collections/collection_article_flow.dart'),
        File(
          'lib/state/collections/collection_article_flow_progress_provider.dart',
        ),
        File('lib/state/collections/collection_rss_providers.dart'),
        File('lib/application/rss/rss_feed_fetch_service.dart'),
        File('lib/application/rss/rss_full_content_service.dart'),
        File('lib/data/repositories/rss_repository.dart'),
        File('lib/data/models/memo_collection.dart'),
        File('lib/data/models/rss_article.dart'),
      ];

      const forbiddenPatterns = <String>{
        'private_hooks',
        'active_private_extension_bundle',
        'AccessDecision',
        'paywall',
        'entitlement',
        'Store'
            'Kit',
        'billing',
        'receipt',
        'premium',
      };

      final violations = <String>[];
      for (final file in files) {
        final contents = await file.readAsString();
        for (final pattern in forbiddenPatterns) {
          if (contents.contains(pattern)) {
            violations.add('${file.path}: $pattern');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: violations.isEmpty
            ? null
            : 'Public collection/RSS flow must not add private or commercial '
                  'hooks:\n${violations.join('\n')}',
      );
    },
  );

  test(
    'AppDatabaseWriteDao does not re-own collection reader-progress SQL',
    () async {
      final contents = await File(
        'lib/data/db/app_database_write_dao.dart',
      ).readAsString();

      const forbiddenPatterns = <String>{
        "insert('collection_read_progress'",
        "delete('collection_read_progress'",
      };
      final violations = forbiddenPatterns
          .where(contents.contains)
          .toList(growable: false);

      expect(
        violations,
        isEmpty,
        reason: violations.isEmpty
            ? null
            : 'Collection reader-progress primitives should stay outside '
                  'AppDatabaseWriteDao:\n${violations.join('\n')}',
      );
    },
  );

  test(
    'AppDatabase does not re-own core memo schema persistence details',
    () async {
      final contents = await File(
        'lib/data/db/app_database.dart',
      ).readAsString();

      const forbiddenPatterns = <String>{
        'CREATE TABLE IF NOT EXISTS memos (',
        'CREATE TABLE IF NOT EXISTS attachments (',
        'ALTER TABLE memos ADD COLUMN relation_count',
        'ALTER TABLE memos ADD COLUMN location_placeholder',
        'ALTER TABLE memos ADD COLUMN location_lat',
        'ALTER TABLE memos ADD COLUMN location_lng',
        'ALTER TABLE memos ADD COLUMN display_time',
        'UPDATE memos SET display_time = create_time',
        'SELECT COUNT(*) AS count FROM memos',
        '_ensureColumnExists(',
        '_tableHasColumn(',
        '_quoteIdentifier(',
      };
      final violations = forbiddenPatterns
          .where(contents.contains)
          .toList(growable: false);

      expect(
        violations,
        isEmpty,
        reason: violations.isEmpty
            ? null
            : 'Core memo schema details should stay outside AppDatabase:\n'
                  '${violations.join('\n')}',
      );
    },
  );

  test(
    'AppDatabaseWriteDao does not re-own legacy attachment table primitives',
    () async {
      final contents = await File(
        'lib/data/db/app_database_write_dao.dart',
      ).readAsString();

      final forbiddenPatterns = <RegExp>[
        RegExp(r"\.update\(\s*'attachments'"),
        RegExp(r"\.insert\(\s*'attachments'"),
        RegExp(r"\.delete\(\s*'attachments'"),
      ];
      final violations = <String>[
        for (final pattern in forbiddenPatterns)
          if (pattern.hasMatch(contents)) pattern.pattern,
      ];

      expect(
        violations,
        isEmpty,
        reason: violations.isEmpty
            ? null
            : 'Legacy attachment table primitives should stay outside '
                  'AppDatabaseWriteDao:\n${violations.join('\n')}',
      );
    },
  );

  test('AppDatabase does not re-own memo query persistence details', () async {
    final contents = await File('lib/data/db/app_database.dart').readAsString();

    final forbiddenPatterns = <RegExp>[
      RegExp(r"\.query\(\s*'memos'"),
      RegExp(r"\.rawQuery\([\s\S]*FROM memos"),
      RegExp(r"attachments_json\s*<>\s*'\[\]'"),
      RegExp(r"COALESCE\(display_time,\s*create_time\)"),
      RegExp(r"COALESCE\(m\.display_time,\s*m\.create_time\)"),
      RegExp(r"LEFT JOIN memo_relations_cache"),
      RegExp(
        r"columns:\s*const\s*\['uid',\s*'update_time',\s*'attachments_json'\]",
      ),
      RegExp(r"columns:\s*const\s*\['uid',\s*'sync_state',\s*'visibility'\]"),
    ];
    final violations = <String>[
      for (final pattern in forbiddenPatterns)
        if (pattern.hasMatch(contents)) pattern.pattern,
    ];

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'Memo query SQL should stay outside AppDatabase:\n'
                '${violations.join('\n')}',
    );
  });

  test('AppDatabaseWriteDao does not re-own memo tag row query SQL', () async {
    final contents = await File(
      'lib/data/db/app_database_write_dao.dart',
    ).readAsString();

    final forbiddenPatterns = <RegExp>[
      RegExp(
        r"\.query\(\s*'memos'\s*,\s*columns:\s*const\s*\['uid',\s*'tags'\]",
      ),
    ];
    final violations = <String>[
      for (final pattern in forbiddenPatterns)
        if (pattern.hasMatch(contents)) pattern.pattern,
    ];

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'Memo tag row reads should stay outside AppDatabaseWriteDao:\n'
                '${violations.join('\n')}',
    );
  });

  test('memo facades do not re-own memo write table primitives', () async {
    final files = <File>[
      File('lib/data/db/app_database.dart'),
      File('lib/data/db/app_database_write_dao.dart'),
    ];

    final forbiddenPatterns = <RegExp>[
      RegExp(r"\.update\(\s*'memos'"),
      RegExp(r"\.insert\(\s*'memos'"),
      RegExp(r"\.delete\(\s*'memos'"),
      RegExp(r"\.query\(\s*'memos'"),
    ];
    final violations = <String>[];
    for (final file in files) {
      final contents = await file.readAsString();
      for (final pattern in forbiddenPatterns) {
        if (pattern.hasMatch(contents)) {
          violations.add('${file.path}: ${pattern.pattern}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'Memo write table primitives should stay outside facades:\n'
                '${violations.join('\n')}',
    );
  });

  test('AppDatabase does not re-own stats cache persistence details', () async {
    final contents = await File('lib/data/db/app_database.dart').readAsString();

    const forbiddenPatterns = <String>{
      'CREATE TABLE IF NOT EXISTS stats_cache (',
      'CREATE TABLE IF NOT EXISTS daily_counts_cache (',
      'CREATE TABLE IF NOT EXISTS tag_stats_cache (',
      "delete('stats_cache'",
      "delete('daily_counts_cache'",
      "delete('tag_stats_cache'",
      "insert('stats_cache'",
      "insert('daily_counts_cache'",
      "insert('tag_stats_cache'",
      'UPDATE stats_cache',
    };
    final violations = forbiddenPatterns
        .where(contents.contains)
        .toList(growable: false);

    final queryViolations = <String>[];
    for (final pattern in <RegExp>[
      RegExp(r"\.query\(\s*'stats_cache'"),
      RegExp(r"\.query\(\s*'daily_counts_cache'"),
      RegExp(r"\.query\(\s*'tag_stats_cache'"),
    ]) {
      if (pattern.hasMatch(contents)) {
        queryViolations.add(pattern.pattern);
      }
    }

    expect(
      [...violations, ...queryViolations],
      isEmpty,
      reason: violations.isEmpty && queryViolations.isEmpty
          ? null
          : 'Stats cache SQLite details should stay outside AppDatabase:\n'
                '${[...violations, ...queryViolations].join('\n')}',
    );
  });

  test('state providers do not query stats cache tables directly', () async {
    final files = <File>[
      File('lib/state/memos/stats_providers.dart'),
      File('lib/state/memos/memos_tag_stats_provider.part.dart'),
    ];

    final violations = <String>[];
    final forbiddenPatterns = <RegExp>[
      RegExp(r"\.query\(\s*'stats_cache'"),
      RegExp(r"\.query\(\s*'daily_counts_cache'"),
      RegExp(r"\.query\(\s*'tag_stats_cache'"),
      RegExp(r"LEFT\s+JOIN\s+tag_stats_cache"),
      RegExp(r"FROM\s+tag_stats_cache"),
    ];
    for (final file in files) {
      final contents = await file.readAsString();
      for (final pattern in forbiddenPatterns) {
        if (pattern.hasMatch(contents)) {
          violations.add('${file.path}: ${pattern.pattern}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'State providers should read stats cache tables through '
                'AppDatabase facades:\n${violations.join('\n')}',
    );
  });

  test(
    'AppDatabase does not re-own memo auxiliary persistence details',
    () async {
      final contents = await File(
        'lib/data/db/app_database.dart',
      ).readAsString();

      const forbiddenPatterns = <String>{
        'CREATE TABLE IF NOT EXISTS memo_reminders (',
        'CREATE TABLE IF NOT EXISTS import_history (',
        'CREATE TABLE IF NOT EXISTS memo_clip_cards (',
        'CREATE INDEX IF NOT EXISTS idx_memo_clip_cards_platform',
        'CREATE INDEX IF NOT EXISTS idx_memo_clip_cards_updated_time',
        "query('memo_reminders'",
        "query('import_history'",
        "query('memo_clip_cards'",
      };
      final violations = forbiddenPatterns
          .where(contents.contains)
          .toList(growable: false);

      expect(
        violations,
        isEmpty,
        reason: violations.isEmpty
            ? null
            : 'Memo auxiliary SQLite details should stay outside AppDatabase:\n'
                  '${violations.join('\n')}',
      );
    },
  );

  test(
    'AppDatabaseWriteDao does not re-own memo auxiliary table primitives',
    () async {
      final contents = await File(
        'lib/data/db/app_database_write_dao.dart',
      ).readAsString();

      const forbiddenPatterns = <String>{
        "insert('memo_reminders'",
        "insert('import_history'",
        "insert('memo_clip_cards'",
        "update('memo_reminders'",
        "update('import_history'",
        "delete('memo_reminders'",
        "delete('memo_clip_cards'",
      };
      final violations = forbiddenPatterns
          .where(contents.contains)
          .toList(growable: false);

      expect(
        violations,
        isEmpty,
        reason: violations.isEmpty
            ? null
            : 'Memo auxiliary table primitives should stay outside '
                  'AppDatabaseWriteDao:\n${violations.join('\n')}',
      );
    },
  );
}

String? _readArchitecturePhase(String config) {
  final match = RegExp(
    r'Architecture phase:\s*(evolve_modularity|preserve_modularity)',
  ).firstMatch(config);
  return match?.group(1);
}

bool _isPlatformRefreshGuardrailFile(File file) {
  final relativePath = p
      .relative(file.path, from: Directory.current.path)
      .replaceAll('\\', '/');
  final segments = p.url.split(relativePath);
  const ignoredSegments = <String>{
    '.gradle',
    '.dart_tool',
    'build',
    'Pods',
    '.symlinks',
  };
  if (segments.any(ignoredSegments.contains)) return false;

  const textExtensions = <String>{
    '.gradle',
    '.h',
    '.java',
    '.kt',
    '.kts',
    '.m',
    '.mm',
    '.pbxproj',
    '.plist',
    '.swift',
    '.xml',
  };
  return textExtensions.contains(p.extension(file.path));
}

Future<List<String>> _findLayerImports(
  String sourceLayer,
  Set<String> targetLayers,
) async {
  final libDir = Directory('lib');
  final violations = <String>[];

  await for (final entry in libDir.list(recursive: true, followLinks: false)) {
    if (entry is! File || p.extension(entry.path) != '.dart') continue;

    final source = p
        .relative(entry.path, from: Directory.current.path)
        .replaceAll('\\', '/');
    if (!source.startsWith('lib/$sourceLayer/')) continue;

    final contents = await entry.readAsString();
    for (final match in RegExp(
      r"^import '([^']+)';",
      multiLine: true,
    ).allMatches(contents)) {
      final target = _resolveLocalImport(source, match.group(1)!);
      if (target == null) continue;

      for (final targetLayer in targetLayers) {
        if (target.startsWith('lib/$targetLayer/')) {
          violations.add('$source -> $target');
          break;
        }
      }
    }
  }

  violations.sort();
  return violations;
}

String? _resolveLocalImport(String source, String importPath) {
  if (importPath.startsWith('package:memos_flutter_app/')) {
    return 'lib/${importPath.substring('package:memos_flutter_app/'.length)}';
  }
  if (importPath.startsWith('dart:') || importPath.startsWith('package:')) {
    return null;
  }
  if (importPath.startsWith('./') || importPath.startsWith('../')) {
    final resolved = p
        .normalize(p.join(p.dirname(source), importPath))
        .replaceAll('\\', '/');
    return resolved.startsWith('lib/') ? resolved : null;
  }

  const localRoots = <String>{
    'access_boundary',
    'application',
    'core',
    'data',
    'features',
    'i18n',
    'module_boundary',
    'platform_capabilities',
    'presentation',
    'private_hooks',
    'state',
  };
  for (final root in localRoots) {
    if (importPath.startsWith('$root/')) {
      return 'lib/$importPath';
    }
  }

  return null;
}

List<String> _unexpectedViolations({
  required List<String> found,
  required String phase,
  required Set<String> evolveAllowlist,
}) {
  final allowlist = switch (phase) {
    'evolve_modularity' => evolveAllowlist,
    'preserve_modularity' => const <String>{},
    _ => throw StateError('Unsupported architecture phase: $phase'),
  };

  return found
      .where((violation) => !allowlist.contains(violation))
      .toList(growable: false);
}
