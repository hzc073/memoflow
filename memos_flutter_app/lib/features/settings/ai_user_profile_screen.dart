import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../data/settings/ai_settings_repository.dart';
import '../../state/ai_settings_provider.dart';

class AiUserProfileScreen extends ConsumerStatefulWidget {
  const AiUserProfileScreen({super.key});

  @override
  ConsumerState<AiUserProfileScreen> createState() => _AiUserProfileScreenState();
}

class _AiUserProfileScreenState extends ConsumerState<AiUserProfileScreen> {
  late final TextEditingController _controller;
  var _saving = false;
  ProviderSubscription<AiSettings>? _settingsSubscription;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(aiSettingsProvider);
    _controller = TextEditingController(text: settings.userProfile);

    _settingsSubscription = ref.listenManual<AiSettings>(aiSettingsProvider, (prev, next) {
      if (!mounted) return;
      if (_saving) return;
      if (_controller.text.trim() == (prev?.userProfile.trim() ?? '')) {
        _controller.text = next.userProfile;
      }
    });
  }

  @override
  void dispose() {
    _settingsSubscription?.close();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(aiSettingsProvider.notifier).setUserProfile(_controller.text);
      if (!mounted) return;
        showTopToast(
          context,
          context.tr(zh: '已保存', en: 'Saved'),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '保存失败：$e', en: 'Save failed: $e'))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final border = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);

    Widget body() {
      return Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: border),
                  boxShadow: isDark
                      ? [
                          BoxShadow(
                            blurRadius: 28,
                            offset: const Offset(0, 16),
                            color: Colors.black.withValues(alpha: 0.45),
                          ),
                        ]
                      : [
                          BoxShadow(
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                            color: Colors.black.withValues(alpha: 0.06),
                          ),
                        ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(zh: '我的资料', en: 'My Profile'),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _controller,
                      enabled: !_saving,
                      minLines: 6,
                      maxLines: 12,
                      style: TextStyle(fontWeight: FontWeight.w600, color: textMain, height: 1.35),
                      decoration: InputDecoration(
                        hintText: context.tr(
                          zh: '例如：我的角色 / 兴趣主题 / 写作风格偏好',
                          en: 'e.g., my role / topics of interest / writing style preferences?',
                        ),
                        hintStyle: TextStyle(color: textMuted),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                context.tr(
                  zh: '这些信息仅用于 AI 总结/报告的背景，不会同步到后端。',
                  en: 'This info is only used as background for AI summaries/reports and is not synced to the backend.',
                ),
                style: TextStyle(fontSize: 12, height: 1.35, color: textMuted),
              ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MemoFlowPalette.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    elevation: isDark ? 0 : 4,
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(context.tr(zh: '保存设置', en: 'Save Settings'), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: context.tr(zh: '返回', en: 'Back'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(context.tr(zh: '我的资料', en: 'My Profile')),
        centerTitle: false,
      ),
      body: isDark
          ? Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF0B0B0B),
                          bg,
                          bg,
                        ],
                      ),
                    ),
                  ),
                ),
                body(),
              ],
            )
          : body(),
    );
  }
}
