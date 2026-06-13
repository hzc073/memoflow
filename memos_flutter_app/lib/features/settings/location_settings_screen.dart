import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/location_settings.dart';
import '../../state/settings/location_settings_provider.dart';
import '../../i18n/strings.g.dart';
import 'settings_ui.dart';

class LocationSettingsScreen extends ConsumerStatefulWidget {
  const LocationSettingsScreen({super.key});

  @override
  ConsumerState<LocationSettingsScreen> createState() =>
      _LocationSettingsScreenState();
}

class _LocationSettingsScreenState
    extends ConsumerState<LocationSettingsScreen> {
  final _webKeyController = TextEditingController();
  final _securityKeyController = TextEditingController();
  final _baiduWebKeyController = TextEditingController();
  final _googleApiKeyController = TextEditingController();
  ProviderSubscription<LocationSettings>? _settingsSubscription;
  var _dirty = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(locationSettingsProvider);
    _applySettings(settings);
    _settingsSubscription = ref.listenManual<LocationSettings>(
      locationSettingsProvider,
      (prev, next) {
        if (_dirty || !mounted) return;
        _applySettings(next);
      },
    );
  }

  @override
  void dispose() {
    _settingsSubscription?.close();
    _webKeyController.dispose();
    _securityKeyController.dispose();
    _baiduWebKeyController.dispose();
    _googleApiKeyController.dispose();
    super.dispose();
  }

  void _applySettings(LocationSettings settings) {
    _webKeyController.text = settings.amapWebKey;
    _securityKeyController.text = settings.amapSecurityKey;
    _baiduWebKeyController.text = settings.baiduWebKey;
    _googleApiKeyController.text = settings.googleApiKey;
    setState(() {});
  }

  void _markDirty() {
    if (_dirty) return;
    setState(() => _dirty = true);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(locationSettingsProvider);

    return SettingsPage(
      title: Text(context.t.strings.legacy.msg_location),
      children: [
        SettingsSection(
          children: [
            SettingsToggleRow(
              label: context.t.strings.legacy.msg_enable_memo_location,
              description: context
                  .t
                  .strings
                  .legacy
                  .msg_show_location_metadata_memos_not_configured,
              value: settings.enabled,
              onChanged: (value) =>
                  ref.read(locationSettingsProvider.notifier).setEnabled(value),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsSection(
          header: Text(context.t.strings.legacy.msg_provider),
          footer: Text(
            context
                .t
                .strings
                .legacy
                .msg_memoflow_uses_system_location_permission_get,
          ),
          children: [
            SettingsMenuRow<LocationServiceProvider>(
              label: context.t.strings.legacy.msg_provider,
              value: settings.provider,
              values: const [
                LocationServiceProvider.amap,
                LocationServiceProvider.baidu,
                LocationServiceProvider.google,
              ],
              labelFor: (value) => _providerLabel(context, value),
              onChanged: (value) {
                _markDirty();
                ref.read(locationSettingsProvider.notifier).setProvider(value);
              },
            ),
            if (settings.provider == LocationServiceProvider.amap) ...[
              SettingsFormFieldRow(
                label: context.t.strings.legacy.msg_web_api_key,
                hint: context.t.strings.legacy.msg_enter_amap_web_api_key,
                controller: _webKeyController,
                onChanged: (v) {
                  _markDirty();
                  ref.read(locationSettingsProvider.notifier).setAmapWebKey(v);
                },
              ),
              SettingsFormFieldRow(
                label: context.t.strings.legacy.msg_security_key_sig,
                hint: context.t.strings.legacy.msg_optional_used_sign_requests,
                controller: _securityKeyController,
                onChanged: (v) {
                  _markDirty();
                  ref
                      .read(locationSettingsProvider.notifier)
                      .setAmapSecurityKey(v);
                },
              ),
            ],
            if (settings.provider == LocationServiceProvider.baidu)
              SettingsFormFieldRow(
                label: 'Baidu AK',
                hint: 'Enter your Baidu AK',
                controller: _baiduWebKeyController,
                onChanged: (v) {
                  _markDirty();
                  ref.read(locationSettingsProvider.notifier).setBaiduWebKey(v);
                },
              ),
            if (settings.provider == LocationServiceProvider.google)
              SettingsFormFieldRow(
                label: 'Google API Key',
                hint: 'Enter your Google Maps API Key',
                controller: _googleApiKeyController,
                onChanged: (v) {
                  _markDirty();
                  ref
                      .read(locationSettingsProvider.notifier)
                      .setGoogleApiKey(v);
                },
              ),
            _PrecisionRow(
              label: context.t.strings.legacy.msg_location_precision,
              value: settings.precision,
              onChanged: (value) {
                _markDirty();
                ref.read(locationSettingsProvider.notifier).setPrecision(value);
              },
            ),
          ],
        ),
      ],
    );
  }

  String _providerLabel(BuildContext context, LocationServiceProvider value) {
    return switch (value) {
      LocationServiceProvider.amap => context.t.strings.legacy.msg_amap_web_api,
      LocationServiceProvider.baidu => 'Baidu Map API',
      LocationServiceProvider.google => 'Google Maps API',
    };
  }
}

class _PrecisionRow extends StatelessWidget {
  const _PrecisionRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final LocationPrecision value;
  final ValueChanged<LocationPrecision> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = <SettingsChoiceOption<LocationPrecision>>[
      SettingsChoiceOption(
        value: LocationPrecision.province,
        label: context.t.strings.legacy.msg_province,
      ),
      SettingsChoiceOption(
        value: LocationPrecision.city,
        label: context.t.strings.legacy.msg_city,
      ),
      SettingsChoiceOption(
        value: LocationPrecision.district,
        label: context.t.strings.legacy.msg_district,
      ),
      SettingsChoiceOption(
        value: LocationPrecision.street,
        label: context.t.strings.legacy.msg_street,
      ),
    ];

    return SettingsOptionChoiceRow<LocationPrecision>(
      label: label,
      value: value,
      options: options,
      onChanged: onChanged,
    );
  }
}
