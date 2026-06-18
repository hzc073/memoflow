import 'package:flutter/cupertino.dart';
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
import 'support_memoflow_policy.dart';
import 'settings_ui.dart';

const supportMemoFlowExternalSupportUrl =
    'https://qr.alipay.com/tsx16856ygfke5rugz1ao4a';
const supportMemoFlowPublicGoodUrl = 'https://memoflow.app/support/public-good';
const supportMemoFlowCharityUrl = 'https://www.hhax.org/';
final _showPublicGoodSection = false;

class SupportMemoFlowScreen extends ConsumerWidget {
  const SupportMemoFlowScreen({super.key, this.showBackButton = true})
    : publicAppreciationOnly = false;

  const SupportMemoFlowScreen.publicAppreciation({
    super.key,
    this.showBackButton = true,
  }) : publicAppreciationOnly = true;

  final bool showBackButton;
  final bool publicAppreciationOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hapticsEnabled = ref.watch(
      devicePreferencesProvider.select((p) => p.hapticsEnabled),
    );
    final bundle = ref.watch(privateExtensionBundleProvider);
    final contributions = _resolvePrivateContributions(context, ref, bundle);
    final hasPrivateSupport =
        !publicAppreciationOnly && contributions.isNotEmpty;
    final experience = resolvePlatformExperience(context);
    final publicSupportPolicy = SupportMemoFlowPublicPolicy.forExperience(
      experience,
    );

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
        if (publicAppreciationOnly) ...[
          _PublicAppreciationSurface(
            policy: publicSupportPolicy,
            onOpenSupport: () =>
                openExternal(supportMemoFlowExternalSupportUrl),
            onOpenPublicGood: () => openExternal(supportMemoFlowPublicGoodUrl),
            onOpenCharity: () => openExternal(supportMemoFlowCharityUrl),
          ),
        ] else if (hasPrivateSupport) ...[
          for (final contribution in contributions) ...[
            contribution.builder(context),
            const SizedBox(height: 14),
          ],
        ] else ...[
          const _WhySupportSection(),
          if (_showPublicGoodSection) ...[
            const SizedBox(height: 14),
            _PublicGoodSection(
              onOpenPublicGood: () =>
                  openExternal(supportMemoFlowPublicGoodUrl),
              onOpenCharity: () => openExternal(supportMemoFlowCharityUrl),
            ),
          ],
          const SizedBox(height: 14),
          _PublicAppreciationSection(
            policy: publicSupportPolicy,
            onOpenSupport: () =>
                openExternal(supportMemoFlowExternalSupportUrl),
          ),
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

class _PublicAppreciationSurface extends StatelessWidget {
  const _PublicAppreciationSurface({
    required this.policy,
    required this.onOpenSupport,
    required this.onOpenPublicGood,
    required this.onOpenCharity,
  });

  final SupportMemoFlowPublicPolicy policy;
  final VoidCallback onOpenSupport;
  final VoidCallback onOpenPublicGood;
  final VoidCallback onOpenCharity;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _WhySupportSection(),
        if (_showPublicGoodSection) ...[
          const SizedBox(height: 14),
          _PublicGoodSection(
            onOpenPublicGood: onOpenPublicGood,
            onOpenCharity: onOpenCharity,
          ),
        ],
        const SizedBox(height: 14),
        _PublicAppreciationSection(
          policy: policy,
          onOpenSupport: onOpenSupport,
        ),
      ],
    );
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
                  zh: '让长期维护和平台体验继续向前',
                  en: 'Keep maintenance and platform polish moving forward.',
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
                  zh: 'MemoFlow 的基础记录、查看和本地数据管理会保持完整可用。你的支持会帮助项目维护、版本更新，以及各个平台体验的持续打磨。',
                  en: 'MemoFlow keeps core capture, reading, and local data workflows intact. Your support helps with maintenance, updates, and steady platform refinement.',
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
            title: context.tr(zh: '你的支持会带来什么', en: 'What your support brings'),
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
              zh: '项目盈利的一部分会投入公益或公共善意项目',
              en: 'Part of any project profit will support public-good or public-good-aligned work',
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
                        zh: '如项目产生盈利，MemoFlow 会将其中一部分投入公益事业或公共善意项目，并通过公开记录保持透明。',
                        en: 'If the project generates profit, MemoFlow will use part of it for public-good causes or public-good-aligned work and keep transparent records.',
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
    final row = Padding(
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
    );
    final experience = resolvePlatformExperience(context);
    if (experience.usesAppleVisuals && experience.isMobileLike) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        pressedOpacity: 0.72,
        onPressed: onTap,
        child: row,
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: row,
    );
  }
}

class _PublicAppreciationSection extends StatelessWidget {
  const _PublicAppreciationSection({
    required this.policy,
    required this.onOpenSupport,
  });

  final SupportMemoFlowPublicPolicy policy;
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
            context.tr(
              zh: '感谢你愿意支持 MemoFlow',
              en: 'Thanks for supporting MemoFlow',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: tokens.textMain,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _appreciationDescription(context),
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.45, color: tokens.textMuted),
          ),
          const SizedBox(height: 18),
          if (policy.showAppleExplanation)
            _AppleSupportExplanation(tokens: tokens)
          else if (policy.showDesktopQr)
            const _SupportQrCode(data: supportMemoFlowExternalSupportUrl)
          else if (policy.showExternalLinkAction)
            SettingsAction(
              key: const ValueKey<String>('supportMemoFlow.openSupportLink'),
              onPressed: onOpenSupport,
              icon: const Icon(Icons.open_in_new, size: 20),
              label: Text(
                context.tr(zh: '打开赞赏链接', en: 'Open support link'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            )
          else
            _AppleSupportExplanation(tokens: tokens),
          const SizedBox(height: 14),
          Text(
            _appreciationFootnote(context),
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

  String _appreciationDescription(BuildContext context) {
    if (policy.showAppleExplanation) {
      return context.tr(
        zh: '你的心意已经很重要。Apple 版本的支持方式会按照 App Store 流程提供；在准备好之前，这里先保留项目维护说明。',
        en: 'Your willingness to support MemoFlow already matters. On Apple platforms, support options will follow the App Store flow; until they are ready, this page keeps the project-maintenance notes.',
      );
    }
    return context.tr(
      zh: policy.showDesktopQr ? '使用手机支付宝扫码完成自愿支持。' : '点击下方按钮后，将在浏览器中打开赞赏链接。',
      en: policy.showDesktopQr
          ? 'Scan with Alipay on your phone to support MemoFlow.'
          : 'Tap the button below to open the support link in a browser.',
    );
  }

  String _appreciationFootnote(BuildContext context) {
    if (policy.showAppleExplanation) {
      return context.tr(
        zh: '这不会影响你继续使用 MemoFlow 的基础记录、查看和本地数据管理。',
        en: 'This does not affect core capture, reading, or local data workflows.',
      );
    }
    return context.tr(
      zh: policy.showDesktopQr ? '二维码仅用于自愿赞赏。' : '赞赏金额将在打开的页面中完成。',
      en: policy.showDesktopQr
          ? 'The QR code is only for voluntary support.'
          : 'The support amount is completed on the page that opens.',
    );
  }
}

class _AppleSupportExplanation extends StatelessWidget {
  const _AppleSupportExplanation({required this.tokens});

  final SettingsPageTokens tokens;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey<String>('supportMemoFlow.appleSupportExplanation'),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.border.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.tr(
                  zh: '当前 Apple 版本暂时没有可用的支持按钮。',
                  en: 'Support options are not available here yet in the Apple version.',
                ),
                style: TextStyle(
                  color: tokens.textMain,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
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
