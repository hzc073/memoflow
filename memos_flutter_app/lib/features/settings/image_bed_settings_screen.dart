import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../core/image_bed_url.dart';
import '../../data/models/image_bed_settings.dart';
import '../../platform/widgets/platform_picker.dart';
import '../../state/settings/image_bed_settings_provider.dart';
import '../../i18n/strings.g.dart';
import 'settings_ui.dart';

class ImageBedSettingsScreen extends ConsumerStatefulWidget {
  const ImageBedSettingsScreen({super.key});

  @override
  ConsumerState<ImageBedSettingsScreen> createState() =>
      _ImageBedSettingsScreenState();
}

class _ImageBedSettingsScreenState
    extends ConsumerState<ImageBedSettingsScreen> {
  final _baseUrlController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _strategyController = TextEditingController();
  ProviderSubscription<ImageBedSettings>? _settingsSubscription;

  var _provider = ImageBedProvider.lskyPro;
  var _retryCount = ImageBedSettings.defaults.retryCount;
  var _dirty = false;

  static const int _minRetry = 0;
  static const int _maxRetry = 10;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(imageBedSettingsProvider);
    _applySettings(settings);
    _settingsSubscription = ref.listenManual<ImageBedSettings>(
      imageBedSettingsProvider,
      (prev, next) {
        if (_dirty || !mounted) return;
        _applySettings(next);
      },
    );
  }

  @override
  void dispose() {
    _settingsSubscription?.close();
    _baseUrlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _strategyController.dispose();
    super.dispose();
  }

  void _applySettings(ImageBedSettings settings) {
    _provider = settings.provider;
    _retryCount = settings.retryCount;
    _baseUrlController.text = settings.baseUrl;
    _emailController.text = settings.email;
    _passwordController.text = settings.password;
    _strategyController.text = settings.strategyId ?? '';
    setState(() {});
  }

  void _markDirty() {
    if (_dirty) return;
    setState(() => _dirty = true);
  }

  String _providerLabel(BuildContext context, ImageBedProvider provider) {
    return context.t.strings.legacy.msg_lsky_pro;
  }

  Future<void> _selectProvider() async {
    Widget buildProviderPicker(BuildContext surfaceContext) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(
                _providerLabel(surfaceContext, ImageBedProvider.lskyPro),
              ),
              trailing: _provider == ImageBedProvider.lskyPro
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => surfaceContext.safePop(ImageBedProvider.lskyPro),
            ),
          ],
        ),
      );
    }

    final selected = await _showProviderPicker(context, buildProviderPicker);
    if (!mounted || selected == null) return;
    setState(() => _provider = selected);
    _markDirty();
    ref.read(imageBedSettingsProvider.notifier).setProvider(selected);
  }

  Future<ImageBedProvider?> _showProviderPicker(
    BuildContext context,
    WidgetBuilder builder,
  ) {
    return showPlatformPicker<ImageBedProvider>(
      context: context,
      desktopMaxWidth: 420,
      builder: builder,
    );
  }

  void _updateRetry(int delta) {
    final next = (_retryCount + delta).clamp(_minRetry, _maxRetry);
    if (next == _retryCount) return;
    setState(() => _retryCount = next);
    _markDirty();
    ref.read(imageBedSettingsProvider.notifier).setRetryCount(next);
  }

  void _normalizeBaseUrl() {
    final raw = _baseUrlController.text.trim();
    if (raw.isEmpty) return;
    final parsed = Uri.tryParse(raw);
    if (parsed == null) return;
    final normalized = sanitizeImageBedBaseUrl(parsed).toString();
    if (normalized != raw) {
      _baseUrlController.text = normalized;
    }
    ref.read(imageBedSettingsProvider.notifier).setBaseUrl(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(imageBedSettingsProvider);
    return SettingsPage(
      title: Text(context.t.strings.legacy.msg_image_bed_3),
      children: [
        SettingsToggleCard(
          label: context.t.strings.legacy.msg_enable_image_bed,
          description: context
              .t
              .strings
              .legacy
              .msg_automatically_upload_images_append_links_memo,
          value: settings.enabled,
          onChanged: (value) =>
              ref.read(imageBedSettingsProvider.notifier).setEnabled(value),
        ),
        const SizedBox(height: 12),
        SettingsSection(
          header: Text(context.t.strings.legacy.msg_provider),
          children: [
            SettingsValueRow(
              label: context.t.strings.legacy.msg_image_bed,
              value: _providerLabel(context, _provider),
              onTap: _selectProvider,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsSection(
          header: Text(context.t.strings.legacy.msg_basics),
          children: [
            SettingsFormFieldRow(
              label: context.t.strings.legacy.msg_api_url,
              hint: 'https://lsky.example.com',
              controller: _baseUrlController,
              keyboardType: TextInputType.url,
              onChanged: (v) {
                _markDirty();
                ref.read(imageBedSettingsProvider.notifier).setBaseUrl(v);
              },
              onEditingComplete: _normalizeBaseUrl,
            ),
            SettingsInlineTextFieldRow(
              label: context.t.strings.legacy.msg_email,
              hint: context.t.strings.legacy.msg_enter_email,
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              onChanged: (v) {
                _markDirty();
                ref.read(imageBedSettingsProvider.notifier).setEmail(v);
              },
            ),
            SettingsFormFieldRow(
              label: context.t.strings.legacy.msg_password,
              hint: context.t.strings.legacy.msg_enter_password_2,
              controller: _passwordController,
              obscureText: true,
              onChanged: (v) {
                _markDirty();
                ref.read(imageBedSettingsProvider.notifier).setPassword(v);
              },
            ),
            SettingsNumericInlineFieldRow(
              label: context.t.strings.legacy.msg_strategy_id,
              hint: context.t.strings.legacy.msg_optional_leave_empty_default,
              controller: _strategyController,
              onChanged: (v) {
                _markDirty();
                ref.read(imageBedSettingsProvider.notifier).setStrategyId(v);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsSection(
          header: Text(context.t.strings.legacy.msg_policy),
          footer: Text(
            context.t.strings.legacy.msg_retry_count_controls_how_many_extra,
          ),
          children: [
            SettingsStepperRow(
              label: context.t.strings.legacy.msg_retry_count,
              value: _retryCount,
              unit: ' ${context.t.strings.legacy.msg_times_2}',
              onDecrease: () => _updateRetry(-1),
              onIncrease: () => _updateRetry(1),
            ),
          ],
        ),
      ],
    );
  }
}
