import '../../platform/platform_experience.dart';

class SupportMemoFlowPublicPolicy {
  const SupportMemoFlowPublicPolicy._({
    required this.allowsExternalSupport,
    required this.showExternalLinkAction,
    required this.showDesktopQr,
    required this.showAppleExplanation,
  });

  final bool allowsExternalSupport;
  final bool showExternalLinkAction;
  final bool showDesktopQr;
  final bool showAppleExplanation;

  factory SupportMemoFlowPublicPolicy.forExperience(
    PlatformExperience experience,
  ) {
    return SupportMemoFlowPublicPolicy._(
      allowsExternalSupport: !experience.isApple,
      showExternalLinkAction: !experience.isApple && !experience.isDesktop,
      showDesktopQr: !experience.isApple && experience.isDesktop,
      showAppleExplanation: experience.isApple,
    );
  }
}
