import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/memoflow_palette.dart';
import '../../i18n/strings.g.dart';
import '../../state/settings/preferences_provider.dart';
import '../import/import_flow_screens.dart';
import 'export_memos_screen.dart';
import 'import_export_shared_widgets.dart';
import 'local_network_migration_screen.dart';

class ImportExportScreen extends ConsumerWidget {
  const ImportExportScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final divider = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);
    final hapticsEnabled = ref.watch(
      appPreferencesProvider.select((p) => p.hapticsEnabled),
    );

    void haptic() {
      if (hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: showBackButton,
        leading: showBackButton
            ? IconButton(
                tooltip: context.t.strings.legacy.msg_back,
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        title: Text(context.t.strings.legacy.msg_import_export),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          if (isDark)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [const Color(0xFF0B0B0B), bg, bg],
                  ),
                ),
              ),
            ),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              Text(
                context.t.strings.legacy.msg_export,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: textMuted,
                ),
              ),
              const SizedBox(height: 10),
              ImportExportCardGroup(
                card: card,
                divider: divider,
                children: [
                  ImportExportSelectRow(
                    icon: Icons.download_outlined,
                    label: context.t.strings.legacy.msg_export,
                    value: 'Markdown + ZIP',
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () {
                      haptic();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ExportMemosScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                context.t.strings.legacy.msg_import,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: textMuted,
                ),
              ),
              const SizedBox(height: 10),
              ImportExportCardGroup(
                card: card,
                divider: divider,
                children: [
                  ImportExportSelectRow(
                    icon: Icons.file_upload_outlined,
                    label: context.t.strings.legacy.msg_import_file_2,
                    value: context.t.strings.legacy.msg_html_zip,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () {
                      haptic();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ImportSourceScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                context.t.strings.legacy.msg_local_network_migration,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: textMuted,
                ),
              ),
              const SizedBox(height: 10),
              ImportExportCardGroup(
                card: card,
                divider: divider,
                children: [
                  ImportExportSelectRow(
                    icon: Icons.devices_outlined,
                    label: context.t.strings.legacy.msg_local_network_migration,
                    value: context
                        .t
                        .strings
                        .legacy
                        .msg_memoflow_migration_targets_summary,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () {
                      haptic();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LocalNetworkMigrationScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
