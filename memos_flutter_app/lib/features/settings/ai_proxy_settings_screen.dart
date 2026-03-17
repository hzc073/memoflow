import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../data/ai/adapters/_ai_provider_http.dart';
import '../../data/repositories/ai_settings_repository.dart';
import '../../i18n/strings.g.dart';
import '../../state/settings/ai_settings_provider.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.58 : 0.62);
    final t = context.t.strings.aiProxy;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(t.title),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(context.t.strings.common.save),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.description,
                    style: TextStyle(color: textMuted, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<AiProxyProtocol>(
                    initialValue: _protocol,
                    decoration: InputDecoration(labelText: t.protocol),
                    items: AiProxyProtocol.values
                        .map(
                          (value) => DropdownMenuItem<AiProxyProtocol>(
                            value: value,
                            child: Text(value == AiProxyProtocol.http ? 'HTTP' : 'SOCKS5'),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _protocol = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _hostController,
                    decoration: InputDecoration(labelText: t.host),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: t.port),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(labelText: t.username),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: t.password,
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _bypassLocalAddresses,
                    onChanged: (value) {
                      setState(() => _bypassLocalAddresses = value);
                    },
                    title: Text(t.bypassLocalAddresses),
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 20),
                  Text(
                    t.testSectionTitle,
                    style: TextStyle(
                      color: textMain,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.testSectionDescription,
                    style: TextStyle(color: textMuted, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _testUrlController,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: t.testUrl,
                      hintText: _defaultProxyTestUrl,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: _testing ? null : _testConnection,
                      icon: _testing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.network_check_rounded),
                      label: Text(_testing ? t.testing : t.testAction),
                    ),
                  ),
                  if (_testResult != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (_testSuccess ?? false)
                            ? Colors.green.withValues(alpha: 0.12)
                            : Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _testResult!,
                        style: TextStyle(
                          color: (_testSuccess ?? false)
                              ? Colors.green.shade700
                              : Colors.orange.shade800,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
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

      await ref.read(aiSettingsProvider.notifier).setProxySettings(
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
        _testResult = t.testFailure(message: message.isEmpty ? 'Unknown error.' : message);
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
