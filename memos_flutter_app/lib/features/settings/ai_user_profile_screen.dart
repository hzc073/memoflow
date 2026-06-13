import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/top_toast.dart';
import '../../data/repositories/ai_settings_repository.dart';
import '../../i18n/strings.g.dart';
import '../../state/settings/ai_settings_provider.dart';
import 'settings_ui.dart';

class AiUserProfileScreen extends ConsumerStatefulWidget {
  const AiUserProfileScreen({super.key});

  @override
  ConsumerState<AiUserProfileScreen> createState() =>
      _AiUserProfileScreenState();
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

    _settingsSubscription = ref.listenManual<AiSettings>(aiSettingsProvider, (
      prev,
      next,
    ) {
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
      await ref
          .read(aiSettingsProvider.notifier)
          .setUserProfile(_controller.text);
      if (!mounted) return;
      showTopToast(context, context.t.strings.legacy.msg_saved_2);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_save_failed_3(e: e)),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPage(
      title: Text(context.t.strings.legacy.msg_my_profile),
      children: [
        SettingsSection(
          children: [
            SettingsMultilineFieldRow(
              label: context.t.strings.legacy.msg_my_profile,
              controller: _controller,
              enabled: !_saving,
              minLines: 6,
              maxLines: 12,
              hint: context.t.strings.legacy.msg_e_g_my_role_topics_interest,
            ),
            SettingsInfoRow(
              description: context
                  .t
                  .strings
                  .legacy
                  .msg_info_only_used_background_ai_summaries,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: SettingsAction(
            onPressed: _saving ? null : _save,
            label: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.t.strings.legacy.msg_save_settings),
          ),
        ),
      ],
    );
  }
}
