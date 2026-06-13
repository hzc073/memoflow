import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_localization.dart';
import '../../core/top_toast.dart';
import '../../module_boundary/support_memo_flow_contribution.dart';
import '../../platform/platform_experience.dart';
import '../../private_hooks/private_extension_bundle.dart';
import '../../private_hooks/private_extension_bundle_provider.dart';
import '../../state/settings/device_preferences_provider.dart';
import '../../i18n/strings.g.dart';
import 'settings_ui.dart';

const supportMemoFlowExternalSupportUrl =
    'https://qr.alipay.com/tsx16856ygfke5rugz1ao4a';
const supportMemoFlowPublicGoodUrl = 'https://memoflow.app/support/public-good';
const supportMemoFlowCharityUrl = 'https://www.hhax.org/';

class SupportMemoFlowScreen extends ConsumerWidget {
  const SupportMemoFlowScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hapticsEnabled = ref.watch(
      devicePreferencesProvider.select((p) => p.hapticsEnabled),
    );
    final bundle = ref.watch(privateExtensionBundleProvider);
    final contributions = _resolvePrivateContributions(context, ref, bundle);
    final hasPrivateSupport = contributions.isNotEmpty;
    final showPublicSupportQr = resolvePlatformExperience(context).isDesktop;

    void haptic() {
      if (hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
    }

    Future<void> openExternal(String rawUrl) async {
      haptic();
      final uri = Uri.parse(rawUrl);
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched && context.mounted) {
          showTopToast(
            context,
            context.t.strings.legacy.msg_unable_open_browser_try,
          );
        }
      } catch (_) {
        if (!context.mounted) return;
        showTopToast(context, context.t.strings.legacy.msg_failed_open_try);
      }
    }

    return SettingsPage(
      showBackButton: showBackButton,
      title: Text(_supportTitle(context)),
      desktopMaxWidth: 720,
      tabletMaxWidth: 640,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        const _SupportHero(),
        const SizedBox(height: 14),
        if (hasPrivateSupport) ...[
          for (final contribution in contributions) ...[
            contribution.builder(context),
            const SizedBox(height: 14),
          ],
          const _BaseCapabilityPromise(),
        ] else ...[
          const _WhySupportSection(),
          const SizedBox(height: 14),
          _PublicGoodSection(
            onOpenPublicGood: () => openExternal(supportMemoFlowPublicGoodUrl),
            onOpenCharity: () => openExternal(supportMemoFlowCharityUrl),
          ),
          const SizedBox(height: 14),
          _PublicAppreciationSection(
            showQr: showPublicSupportQr,
            onOpenSupport: () =>
                openExternal(supportMemoFlowExternalSupportUrl),
          ),
          const SizedBox(height: 22),
          const _SupportFooter(),
        ],
      ],
    );
  }

  List<SupportMemoFlowContribution> _resolvePrivateContributions(
    BuildContext context,
    WidgetRef ref,
    PrivateExtensionBundle bundle,
  ) {
    if (bundle is! SupportMemoFlowExtension) {
      return const <SupportMemoFlowContribution>[];
    }
    final extension = bundle as SupportMemoFlowExtension;
    final contributions = [
      ...extension.supportMemoFlowContributions(context, ref),
    ]..sort((a, b) => a.order.compareTo(b.order));
    return contributions;
  }
}

class _SupportHero extends StatelessWidget {
  const _SupportHero();

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    return _SupportCard(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final art = _CoffeeMark(color: Theme.of(context).colorScheme.primary);
          final copy = Column(
            crossAxisAlignment: compact
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text(
                _supportTitle(context),
                textAlign: compact ? TextAlign.center : TextAlign.start,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: tokens.textMain,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                context.tr(
                  zh: '如果你愿意，可以请开发者喝一杯咖啡',
                  en: 'If you want, you can buy the developer a coffee.',
                ),
                textAlign: compact ? TextAlign.center : TextAlign.start,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.38,
                  color: tokens.textMain.withValues(alpha: 0.82),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                context.tr(
                  zh: 'MemoFlow 会尽量保持核心体验的完整。你的赞赏会用于项目维护、版本更新，以及未来体验的持续打磨。',
                  en: 'MemoFlow will keep its core experience intact. Your support helps with maintenance, updates, and steady product refinement.',
                ),
                textAlign: compact ? TextAlign.center : TextAlign.start,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: tokens.textMuted,
                ),
              ),
            ],
          );

          if (compact) {
            return Column(children: [art, const SizedBox(height: 18), copy]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              art,
              const SizedBox(width: 28),
              Expanded(child: copy),
            ],
          );
        },
      ),
    );
  }
}

class _WhySupportSection extends StatelessWidget {
  const _WhySupportSection();

  @override
  Widget build(BuildContext context) {
    return _SupportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SupportSectionTitle(
            title: context.tr(zh: '为什么赞赏', en: 'Why support'),
          ),
          const SizedBox(height: 12),
          _ReasonRow(
            icon: Icons.person_outline,
            label: context.tr(
              zh: '支持独立开发与后续维护',
              en: 'Support independent development and maintenance',
            ),
          ),
          _ReasonRow(
            icon: Icons.sync_rounded,
            label: context.tr(
              zh: '帮助项目持续更新',
              en: 'Help the project keep improving',
            ),
          ),
          _ReasonRow(
            icon: Icons.favorite_border,
            label: context.tr(
              zh: '部分盈利将用于公益并公示',
              en: 'Part of any profit will support public-good causes with records',
            ),
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _PublicGoodSection extends StatelessWidget {
  const _PublicGoodSection({
    required this.onOpenPublicGood,
    required this.onOpenCharity,
  });

  final VoidCallback onOpenPublicGood;
  final VoidCallback onOpenCharity;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    final accent = Theme.of(context).colorScheme.primary;
    return _SupportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBubble(icon: Icons.volunteer_activism_outlined),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SupportSectionTitle(
                      title: context.tr(zh: '公益说明', en: 'Public-good note'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr(
                        zh: '如项目产生盈利，MemoFlow 会将其中一部分捐赠给北京韩红爱心慈善基金会并公示。',
                        en: 'If the project generates profit, MemoFlow will donate part of it to the Beijing Han Hong Love Charity Foundation and publish records.',
                      ),
                      style: TextStyle(
                        height: 1.48,
                        fontSize: 14,
                        color: tokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(height: 1, color: tokens.divider),
          _PublicGoodLinkRow(
            label: context.tr(zh: '查看基金会官网', en: 'View foundation website'),
            onTap: onOpenCharity,
            accent: accent,
            tokens: tokens,
          ),
          Divider(height: 1, color: tokens.divider),
          _PublicGoodLinkRow(
            label: context.tr(zh: '查看公益公示', en: 'View public-good records'),
            onTap: onOpenPublicGood,
            accent: accent,
            tokens: tokens,
          ),
        ],
      ),
    );
  }
}

class _PublicGoodLinkRow extends StatelessWidget {
  const _PublicGoodLinkRow({
    required this.label,
    required this.onTap,
    required this.accent,
    required this.tokens,
  });

  final String label;
  final VoidCallback onTap;
  final Color accent;
  final SettingsPageTokens tokens;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: tokens.textMain,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: accent),
          ],
        ),
      ),
    );
  }
}

class _PublicAppreciationSection extends StatelessWidget {
  const _PublicAppreciationSection({
    required this.showQr,
    required this.onOpenSupport,
  });

  final bool showQr;
  final VoidCallback onOpenSupport;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    return _SupportCard(
      key: const ValueKey<String>('supportMemoFlow.publicAppreciationSection'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            context.tr(zh: '赞赏开发者', en: 'Support the developer'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: tokens.textMain,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.tr(
              zh: showQr ? '使用手机支付宝扫码完成赞赏。' : '点击下方按钮后，将在浏览器中打开赞赏链接。',
              en: showQr
                  ? 'Scan with Alipay on your phone to support MemoFlow.'
                  : 'Tap the button below to open the support link in a browser.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.45, color: tokens.textMuted),
          ),
          const SizedBox(height: 18),
          if (showQr)
            const _SupportQrCode(data: supportMemoFlowExternalSupportUrl)
          else
            SettingsAction(
              key: const ValueKey<String>('supportMemoFlow.openSupportLink'),
              onPressed: onOpenSupport,
              icon: const Icon(Icons.open_in_new, size: 20),
              label: Text(
                context.tr(zh: '打开赞赏链接', en: 'Open support link'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          const SizedBox(height: 14),
          Text(
            context.tr(
              zh: showQr ? '二维码仅用于自愿赞赏，不影响基础功能使用。' : '赞赏金额将在打开的页面中完成。',
              en: showQr
                  ? 'The QR code is only for voluntary support and does not affect basic features.'
                  : 'The support amount is completed on the page that opens.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: tokens.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportQrCode extends StatelessWidget {
  const _SupportQrCode({required this.data});

  static const double _maxSize = 240;

  final String data;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxSize),
        child: AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(
            key: const ValueKey<String>('supportMemoFlow.supportQr'),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: tokens.border.withValues(alpha: 0.6)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: PrettyQrView.data(
                data: data,
                decoration: const PrettyQrDecoration(),
                errorCorrectLevel: QrErrorCorrectLevel.M,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BaseCapabilityPromise extends StatelessWidget {
  const _BaseCapabilityPromise();

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    return _SupportCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBubble(icon: Icons.all_inclusive_rounded),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              context.tr(
                zh: '无论是否成为支持者，MemoFlow 的基础记录、整理和数据管理能力都会继续保持可用。',
                en: 'Whether or not you become a supporter, MemoFlow will keep its basic recording, organizing, and data management capabilities available.',
              ),
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: tokens.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportFooter extends StatelessWidget {
  const _SupportFooter();

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    return Column(
      children: [
        Icon(
          Icons.favorite_border,
          color: Theme.of(context).colorScheme.primary,
          size: 22,
        ),
        const SizedBox(height: 8),
        Text(
          context.tr(
            zh: '感谢你愿意支持 MemoFlow。',
            en: 'Thank you for supporting MemoFlow.',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.4, color: tokens.textMuted),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr(
            zh: '赞赏完全自愿，不会影响 MemoFlow 基础功能的正常使用。',
            en: 'Support is fully voluntary and does not affect normal use of MemoFlow basics.',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, height: 1.4, color: tokens.textMuted),
        ),
      ],
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.icon,
    required this.label,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    final accent = Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 28, color: accent),
              const SizedBox(width: 22),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    color: tokens.textMain,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, indent: 50, color: tokens.divider),
      ],
    );
  }
}

class _SupportSectionTitle extends StatelessWidget {
  const _SupportSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    return Text(
      title,
      style: TextStyle(
        color: tokens.textMain,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    final shadowColor = tokens.isDark
        ? Colors.transparent
        : Colors.black.withValues(alpha: 0.08);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tokens.border.withValues(alpha: 0.66)),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 26,
            spreadRadius: -12,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, size: 24, color: colorScheme.primary),
    );
  }
}

class _CoffeeMark extends StatelessWidget {
  const _CoffeeMark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final cupColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 16,
            child: Container(
              width: 92,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Positioned(
            top: 30,
            child: Icon(Icons.local_cafe_rounded, size: 86, color: cupColor),
          ),
          Positioned(
            top: 67,
            child: Icon(Icons.favorite_rounded, size: 30, color: color),
          ),
          Positioned(
            top: 10,
            child: Icon(
              Icons.favorite_border_rounded,
              size: 44,
              color: color.withValues(alpha: 0.42),
            ),
          ),
        ],
      ),
    );
  }
}

String _supportTitle(BuildContext context) {
  return context.tr(zh: '支持 MemoFlow', en: 'Support MemoFlow');
}
