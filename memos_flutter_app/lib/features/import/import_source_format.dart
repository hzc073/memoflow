import 'package:flutter/widgets.dart';

import '../../core/app_localization.dart';
import 'import_source_kind.dart';

class ImportSourceFormatDescription {
  const ImportSourceFormatDescription({
    required this.title,
    required this.help,
    required this.structure,
  });

  final String title;
  final String help;
  final String structure;
}

ImportSourceFormatDescription importSourceFormatDescription(
  BuildContext context,
  ImportSourceKind kind,
) {
  final language = context.appLanguage;

  String tr(String key) {
    return trByLanguageKey(language: language, key: 'legacy.$key');
  }

  return switch (kind) {
    ImportSourceKind.flomo => ImportSourceFormatDescription(
      title: tr('msg_import_source_flomo_package'),
      help: tr('msg_import_flomo_format_help'),
      structure: tr('msg_import_flomo_structure'),
    ),
    ImportSourceKind.swashbucklerDiary => ImportSourceFormatDescription(
      title: tr('msg_import_source_swashbuckler_diary_package'),
      help: tr('msg_import_swashbuckler_format_help'),
      structure: tr('msg_import_swashbuckler_structure'),
    ),
    ImportSourceKind.memoFlowMarkdown => ImportSourceFormatDescription(
      title: tr('msg_import_source_memoflow_markdown_package'),
      help: tr('msg_import_memoflow_markdown_format_help'),
      structure: tr('msg_import_memoflow_markdown_structure'),
    ),
    ImportSourceKind.genericMarkdown => ImportSourceFormatDescription(
      title: tr('msg_import_source_generic_markdown_package'),
      help: tr('msg_import_generic_markdown_format_help'),
      structure: tr('msg_import_generic_markdown_structure'),
    ),
  };
}
