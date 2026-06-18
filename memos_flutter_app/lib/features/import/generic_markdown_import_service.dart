export '../../state/memos/flomo_import_models.dart';

import '../../core/tags.dart';
import '../../data/models/account.dart';
import '../../data/models/app_preferences.dart';
import '../../state/memos/flomo_import_models.dart';
import '../../state/memos/generic_markdown_import_controller.dart';

class GenericMarkdownImportService {
  GenericMarkdownImportService({
    required this.db,
    required this.language,
    this.account,
    this.importScopeKey,
    this.tagRecognitionPolicy = TagRecognitionPolicy.defaultPolicy,
  });

  final GenericMarkdownImportDatabase db;
  final Account? account;
  final String? importScopeKey;
  final AppLanguage language;
  final TagRecognitionPolicy tagRecognitionPolicy;

  Future<ImportResult> importFile({
    required String filePath,
    required ImportProgressCallback onProgress,
    required ImportCancelCheck isCancelled,
  }) async {
    return const GenericMarkdownImportController().importArchive(
      db: db,
      language: language,
      account: account,
      importScopeKey: importScopeKey,
      tagRecognitionPolicy: tagRecognitionPolicy,
      filePath: filePath,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
  }
}
