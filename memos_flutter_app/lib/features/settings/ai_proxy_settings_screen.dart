import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/top_toast.dart';
import '../../data/ai/adapters/_ai_provider_http.dart';
import '../../data/repositories/ai_settings_repository.dart';
import '../../i18n/strings.g.dart';
import '../../platform/widgets/platform_primary_action.dart';
import '../../state/settings/ai_settings_provider.dart';
import 'settings_ui.dart';

const _defaultProxyTestUrl = 'https://www.google.com';

class AiProxySettingsScreen extends ConsumerStatefulWidget {
  const AiProxySettingsScreen({super.key});

  @override
  ConsumerState<AiProxySettingsScreen> createState() =>
      _AiProxySettingsScreenState();
}

class _AiProxySettingsScreenState extends ConsumerState<AiProxySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _testUrlController;

  late AiProxyProtocol _protocol;
  late bool _bypassLocalAddresses;
  var _obscurePassword = true;
  var _saving = false;
  var _testing = false;
  String? _testResult;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(aiSettingsProvider).proxySettings;
    _protocol = settings.protocol;
    _bypassLocalAddresses = settings.bypassLocalAddresses;
    _hostController = TextEditingController(text: settings.host);
    _portController = TextEditingController(
      text: settings.port > 0 ? settings.port.toString() : '',
    );
    _usernameController = TextEditingController(text: settings.username);
    _passwordController = TextEditingController(text: settings.password);
    _testUrlController = TextEditingController(text: _defaultProxyTestUrl);
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _testUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.strings.aiProxy;

    return SettingsPage(
      title: Text(t.title),
      actions: [
        TextButton(
          onPressed: _saving ? null : _save,
          child: Text(context.t.strings.common.save),
        ),
      ],
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsSection(
                children: [
                  SettingsInfoRow(description: t.description),
                  SettingsMenuRow<AiProxyProtocol>(
                    label: t.protocol,
                    value: _protocol,
                    values: AiProxyProtocol.values,
                    labelFor: (value) =>
                        value == AiProxyProtocol.http ? 'HTTP' : 'SOCKS5',
                    onChanged: (value) => setState(() => _protocol = value),
                  ),
                  SettingsInlineTextFieldRow(
                    label: t.host,
                    controller: _hostController,
                  ),
                  SettingsNumericInlineFieldRow(
                    label: t.port,
                    controller: _portController,
                  ),
                  SettingsInlineTextFieldRow(
                    label: t.username,
                    controller: _usernameController,
                  ),
                  SettingsFormFieldRow(
                    label: t.password,
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  SettingsToggleRow(
                    label: t.bypassLocalAddresses,
                    value: _bypassLocalAddresses,
                    onChanged: (value) {
                      setState(() => _bypassLocalAddresses = value);
                    },
                    onTap: () {
                      setState(
                        () => _bypassLocalAddresses = !_bypassLocalAddresses,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SettingsSection(
                header: Text(t.testSectionTitle),
                children: [
                  SettingsInfoRow(description: t.testSectionDescription),
                  SettingsFormFieldRow(
                    label: t.testUrl,
                    controller: _testUrlController,
                    hint: _defaultProxyTestUrl,
                    keyboardType: TextInputType.url,
                  ),
                  if (_testResult != null)
                    _ProxyTestResultRow(
                      message: _testResult!,
                      success: _testSuccess ?? false,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SettingsAction(
                    onPressed: _testing ? null : _testConnection,
                    icon: _testing
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.network_check_rounded),
                    label: Text(_testing ? t.testing : t.testAction),
                    variant: PlatformPrimaryActionVariant.tonal,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final t = context.t.strings.aiProxy;
    try {
      final host = _hostController.text.trim();
      final portText = _portController.text.trim();
      final port = int.tryParse(portText) ?? 0;
      final shouldClear = host.isEmpty && (portText.isEmpty || port == 0);
      if (shouldClear) {
        await ref
            .read(aiSettingsProvider.notifier)
            .setProxySettings(AiProxySettings.defaults);
        if (!mounted) return;
        showTopToast(context, t.clearSuccess);
        Navigator.of(context).maybePop();
        return;
      }
      if (host.isEmpty) {
        showTopToast(context, t.invalidHost);
        return;
      }
      if (port <= 0 || port > 65535) {
        showTopToast(context, t.invalidPort);
        return;
      }

      await ref
          .read(aiSettingsProvider.notifier)
          .setProxySettings(
            AiProxySettings(
              protocol: _protocol,
              host: host,
              port: port,
              username: _usernameController.text.trim(),
              password: _passwordController.text.trim(),
              bypassLocalAddresses: _bypassLocalAddresses,
            ),
          );
      if (!mounted) return;
      showTopToast(context, t.saveSuccess);
      Navigator.of(context).maybePop();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _testConnection() async {
    if (_testing) return;
    final t = context.t.strings.aiProxy;
    final proxySettings = _buildDraftProxySettings();
    if (proxySettings == null) return;

    final rawUrl = _testUrlController.text.trim();
    final uri = Uri.tryParse(rawUrl);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.trim().isEmpty) {
      showTopToast(context, t.invalidTestUrl);
      return;
    }

    setState(() {
      _testing = true;
      _testResult = null;
      _testSuccess = null;
    });

    final origin = uri.hasPort
        ? '${uri.scheme}://${uri.host}:${uri.port}'
        : '${uri.scheme}://${uri.host}';
    final service = AiServiceInstance(
      serviceId: 'svc_proxy_test_preview',
      templateId: aiTemplateOpenAi,
      adapterKind: AiProviderAdapterKind.openAiCompatible,
      displayName: 'Proxy Preview',
      enabled: true,
      usesSharedProxy: true,
      baseUrl: origin,
      apiKey: '',
      customHeaders: const <String, String>{},
      models: const <AiModelEntry>[],
      lastValidatedAt: null,
      lastValidationStatus: AiValidationStatus.unknown,
      lastValidationMessage: null,
    );

    final stopwatch = Stopwatch()..start();
    Dio? dio;
    try {
      dio = await buildAiProviderDio(service, proxySettings: proxySettings);
      final response = await dio.getUri<Object>(
        uri,
        options: Options(responseType: ResponseType.plain),
      );
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _testSuccess = true;
        _testResult = t.testSuccess(
          statusCode: response.statusCode ?? 0,
          elapsedMs: stopwatch.elapsedMilliseconds,
        );
      });
    } catch (error) {
      stopwatch.stop();
      if (!mounted) return;
      final message = error is DioException
          ? (error.message?.trim().isNotEmpty == true
                ? error.message!.trim()
                : error.toString())
          : error.toString().replaceFirst('Exception: ', '').trim();
      setState(() {
        _testSuccess = false;
        _testResult = t.testFailure(
          message: message.isEmpty ? 'Unknown error.' : message,
        );
      });
    } finally {
      dio?.close(force: true);
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  AiProxySettings? _buildDraftProxySettings() {
    final t = context.t.strings.aiProxy;
    final host = _hostController.text.trim();
    final portText = _portController.text.trim();
    final port = int.tryParse(portText) ?? 0;
    final shouldClear = host.isEmpty && (portText.isEmpty || port == 0);
    if (shouldClear) {
      showTopToast(context, t.invalidHost);
      return null;
    }
    if (host.isEmpty) {
      showTopToast(context, t.invalidHost);
      return null;
    }
    if (port <= 0 || port > 65535) {
      showTopToast(context, t.invalidPort);
      return null;
    }
    return AiProxySettings(
      protocol: _protocol,
      host: host,
      port: port,
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
      bypassLocalAddresses: _bypassLocalAddresses,
    );
  }
}

class _ProxyTestResultRow extends StatelessWidget {
  const _ProxyTestResultRow({required this.message, required this.success});

  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final color = success ? Colors.green : Colors.orange;
    return SettingsWarningRow(message: message, iconColor: color);
  }
}
