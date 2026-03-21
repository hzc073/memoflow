import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../core/version_probe_gate.dart';
import '../../data/models/account.dart';
import '../../state/memos/laboratory_providers.dart';
import '../../state/system/session_provider.dart';
import 'customize_drawer_screen.dart';
import 'shortcuts_settings_screen.dart';
import 'webhooks_settings_screen.dart';
import '../../i18n/strings.g.dart';

class LaboratoryScreen extends ConsumerStatefulWidget {
  const LaboratoryScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  static final Future<PackageInfo> _packageInfoFuture =
      PackageInfo.fromPlatform();

  @override
  ConsumerState<LaboratoryScreen> createState() => _LaboratoryScreenState();
}

class _LaboratoryScreenState extends ConsumerState<LaboratoryScreen> {
  static const List<String> _presetServerVersions = <String>[
    '0.26.0',
    '0.25.0',
    '0.24.0',
    '0.23.0',
    '0.22.0',
    '0.21.0',
  ];

  bool _savingVersion = false;
  bool _probingVersion = false;

  Future<void> _showProbeFailureReport(String diagnostics) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.t.strings.legacy.msg_version_probe_failed),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(child: SelectableText(diagnostics)),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: diagnostics));
                if (!mounted) return;
                showTopToast(
                  context,
                  context.t.strings.legacy.msg_diagnostics_copied,
                );
              },
              child: Text(context.t.strings.legacy.msg_copy_diagnostics),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.t.strings.legacy.msg_close),
            ),
          ],
        );
      },
    );
  }

  Future<LaboratoryProbeResult?> _probeSingleVersion({
    required Account currentAccount,
    required LaboratoryVersion version,
  }) async {
    setState(() => _probingVersion = true);
    try {
      return await ref
          .read(laboratoryControllerProvider)
          .probeSingleVersion(
            account: currentAccount,
            version: version,
            probeMemoNotice: context.t.strings.legacy.msg_probe_memo_can_delete,
          );
    } catch (_) {
      return null;
    } finally {
      if (mounted) {
        setState(() => _probingVersion = false);
      }
    }
  }

  Future<void> _cleanupProbeArtifactsAfterSync({
    required Account account,
    required LaboratoryVersion version,
    required LaboratoryProbeCleanup cleanup,
  }) async {
    await ref
        .read(laboratoryControllerProvider)
        .cleanupProbeArtifactsAfterSync(
          account: account,
          version: version,
          cleanup: cleanup,
        );
  }

  Future<void> _selectServerVersion(Account? currentAccount) async {
    if (currentAccount == null || _savingVersion || _probingVersion) return;
    final selectedRaw =
        currentAccount.serverVersionOverride?.trim().isNotEmpty == true
        ? currentAccount.serverVersionOverride!.trim()
        : '';
    final controller = ref.read(laboratoryControllerProvider);
    final selectedVersion =
        controller.parseVersion(selectedRaw) ?? controller.defaultVersion;
    final detected = controller.normalizeServerVersion(
      currentAccount.instanceProfile.version,
    );
    final options = <String>{
      ..._presetServerVersions,
      if (detected.isNotEmpty) detected,
      if (selectedRaw.isNotEmpty) selectedRaw,
    }.toList(growable: false);
    options.sort((a, b) => b.compareTo(a));

    final result = await showDialog<String?>(
      context: context,
      builder: (context) {
        var pending = selectedVersion.versionString;
        return AlertDialog(
          title: Text(context.t.strings.common.serverVersion),
          content: StatefulBuilder(
            builder: (context, setLocalState) {
              return DropdownButtonFormField<String>(
                initialValue: pending,
                isExpanded: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: [
                  for (final v in options)
                    DropdownMenuItem<String>(value: v, child: Text(v)),
                ],
                onChanged: (value) {
                  final normalized = (value ?? '').trim();
                  if (normalized.isEmpty) return;
                  setLocalState(() => pending = normalized);
                },
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(context.t.strings.common.cancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(pending);
              },
              child: Text(context.t.strings.legacy.msg_apply),
            ),
          ],
        );
      },
    );
    if (result == null) return;
    final parsed = controller.parseVersion(result);
    if (parsed == null) {
      if (!mounted) return;
      showTopToast(
        context,
        context.t.strings.legacy.msg_unsupported_version_value(version: result),
      );
      return;
    }

    if (isVersionProbeEnabled) {
      final probeReport = await _probeSingleVersion(
        currentAccount: currentAccount,
        version: parsed,
      );
      if (!mounted || probeReport == null) return;
      if (!probeReport.passed) {
        await _showProbeFailureReport(probeReport.diagnostics);
        return;
      }
      await _cleanupProbeArtifactsAfterSync(
        account: currentAccount,
        version: parsed,
        cleanup: probeReport.cleanup,
      );
    }

    setState(() => _savingVersion = true);
    try {
      await ref
          .read(appSessionProvider.notifier)
          .setCurrentAccountServerVersionOverride(parsed.versionString);
      if (!mounted) return;
      showTopToast(
        context,
        context.t.strings.common.serverVersionValue(
          version: parsed.versionString,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showTopToast(context, context.t.strings.legacy.msg_failed_load_try);
    } finally {
      if (mounted) {
        setState(() => _savingVersion = false);
      }
    }
  }

  Future<void> _reprobeCurrentVersion(Account? currentAccount) async {
    if (!isVersionProbeEnabled) return;
    if (currentAccount == null || _savingVersion || _probingVersion) return;
    final controller = ref.read(laboratoryControllerProvider);
    final effectiveVersion = controller.normalizeServerVersion(
      currentAccount.serverVersionOverride ??
          currentAccount.instanceProfile.version,
    );
    final parsed = controller.parseVersion(effectiveVersion);
    if (parsed == null) {
      showTopToast(
        context,
        context.t.strings.common.selectServerVersionRange021To026,
      );
      return;
    }
    final report = await _probeSingleVersion(
      currentAccount: currentAccount,
      version: parsed,
    );
    if (!mounted || report == null) return;
    if (!report.passed) {
      await _showProbeFailureReport(report.diagnostics);
      return;
    }
    await _cleanupProbeArtifactsAfterSync(
      account: currentAccount,
      version: parsed,
      cleanup: report.cleanup,
    );
    if (!mounted) return;
    showTopToast(
      context,
      context.t.strings.legacy.msg_version_probe_passed_with_version(
        version: parsed.versionString,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(appSessionProvider).valueOrNull;
    final currentAccount = sessionState?.currentAccount;
    final sessionController = ref.read(appSessionProvider.notifier);
    final detectedVersion =
        currentAccount?.instanceProfile.version.trim() ?? '';
    final effectiveVersion = currentAccount == null
        ? ''
        : sessionController.resolveEffectiveServerVersionForAccount(
            account: currentAccount,
          );
    final manualVersion = currentAccount?.serverVersionOverride?.trim() ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: widget.showBackButton,
        leading: widget.showBackButton
            ? IconButton(
                tooltip: context.t.strings.legacy.msg_back,
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        title: Text(context.t.strings.legacy.msg_laboratory),
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
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    children: [
                      _CompatibilityCard(
                        card: card,
                        label: context.t.strings.common.serverVersion,
                        detectedVersion: detectedVersion,
                        effectiveVersion: effectiveVersion,
                        manualVersion: manualVersion,
                        busy: _savingVersion || _probingVersion,
                        textMain: textMain,
                        textMuted: textMuted,
                        allowVersionControl: currentAccount != null,
                        allowProbeControl: isVersionProbeEnabled,
                        onEditVersion: () =>
                            _selectServerVersion(currentAccount),
                        onReprobeVersion: () =>
                            _reprobeCurrentVersion(currentAccount),
                      ),
                      const SizedBox(height: 12),
                      _CardRow(
                        card: card,
                        label: context.t.strings.legacy.msg_customize_sidebar,
                        textMain: textMain,
                        textMuted: textMuted,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CustomizeDrawerScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _CardRow(
                        card: card,
                        label: context.t.strings.legacy.msg_shortcuts,
                        textMain: textMain,
                        textMuted: textMuted,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ShortcutsSettingsScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _CardRow(
                        card: card,
                        label: context.t.strings.legacy.msg_webhooks,
                        textMain: textMain,
                        textMuted: textMuted,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const WebhooksSettingsScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    children: [
                      Text(
                        'MemoFlow',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: MemoFlowPalette.primary.withValues(
                            alpha: isDark ? 0.85 : 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FutureBuilder<PackageInfo>(
                        future: LaboratoryScreen._packageInfoFuture,
                        builder: (context, snapshot) {
                          final version = snapshot.data?.version.trim() ?? '';
                          return Text(
                            version.isEmpty ? 'VERSION' : 'VERSION $version',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: MemoFlowPalette.primary.withValues(
                                alpha: isDark ? 0.55 : 0.7,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompatibilityCard extends StatelessWidget {
  const _CompatibilityCard({
    required this.card,
    required this.label,
    required this.detectedVersion,
    required this.effectiveVersion,
    required this.manualVersion,
    required this.busy,
    required this.textMain,
    required this.textMuted,
    required this.allowVersionControl,
    required this.allowProbeControl,
    required this.onEditVersion,
    required this.onReprobeVersion,
  });

  final Color card;
  final String label;
  final String detectedVersion;
  final String effectiveVersion;
  final String manualVersion;
  final bool busy;
  final Color textMain;
  final Color textMuted;
  final bool allowVersionControl;
  final bool allowProbeControl;
  final VoidCallback onEditVersion;
  final VoidCallback onReprobeVersion;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final detectedLabel = detectedVersion.trim().isEmpty
        ? '-'
        : detectedVersion.trim();
    final effectiveLabel = effectiveVersion.trim().isEmpty
        ? '-'
        : effectiveVersion.trim();
    final manualLabel = manualVersion.trim().isEmpty
        ? '-'
        : manualVersion.trim();
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(22),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                    color: Colors.black.withValues(alpha: 0.06),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w700, color: textMain),
            ),
            const SizedBox(height: 10),
            _CompatInfoLine(
              textMain: textMain,
              textMuted: textMuted,
              label: context.t.strings.legacy.msg_server,
              value: detectedLabel,
            ),
            const SizedBox(height: 4),
            _CompatInfoLine(
              textMain: textMain,
              textMuted: textMuted,
              label: context.t.strings.common.serverVersion,
              value: effectiveLabel,
            ),
            const SizedBox(height: 4),
            _CompatInfoLine(
              textMain: textMain,
              textMuted: textMuted,
              label: context.t.strings.common.manual,
              value: manualLabel,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: allowVersionControl && !busy
                        ? onEditVersion
                        : null,
                    icon: busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.tune, size: 16),
                    label: Text(context.t.strings.common.manual),
                  ),
                ),
                if (allowProbeControl)
                  Expanded(
                    child: TextButton.icon(
                      onPressed: allowVersionControl && !busy
                          ? onReprobeVersion
                          : null,
                      icon: const Icon(Icons.science_outlined, size: 16),
                      label: Text(context.t.strings.legacy.msg_retry),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompatInfoLine extends StatelessWidget {
  const _CompatInfoLine({
    required this.textMain,
    required this.textMuted,
    required this.label,
    required this.value,
  });

  final Color textMain;
  final Color textMuted;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 12, color: textMuted)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: textMain,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.card,
    required this.label,
    required this.textMain,
    required this.textMuted,
    required this.onTap,
  });

  final Color card;
  final String label;
  final Color textMain;
  final Color textMuted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(22),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                      color: Colors.black.withValues(alpha: 0.06),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: textMain,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
