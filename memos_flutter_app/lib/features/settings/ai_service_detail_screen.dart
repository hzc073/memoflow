import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/memoflow_palette.dart';
import '../../data/ai/ai_settings_log.dart';
import '../../data/logs/log_manager.dart';
import '../../core/top_toast.dart';
import '../../data/repositories/ai_settings_repository.dart';
import '../../i18n/strings.g.dart';
import '../../state/settings/ai_settings_provider.dart';
import 'ai_provider_logo.dart';
import 'ai_proxy_settings_screen.dart';
import 'ai_service_model_screen.dart';

class AiServiceDetailScreen extends ConsumerStatefulWidget {
  const AiServiceDetailScreen({super.key, required this.serviceId});

  final String serviceId;

  @override
  ConsumerState<AiServiceDetailScreen> createState() =>
      _AiServiceDetailScreenState();
}

class _AiServiceDetailScreenState extends ConsumerState<AiServiceDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _headersController;
  bool _enabled = true;
  bool _usesSharedProxy = false;
  bool _obscureApiKey = true;
  bool _isCheckingConnection = false;

  @override
  void initState() {
    super.initState();
    final service = ref
        .read(aiSettingsProvider)
        .services
        .firstById(widget.serviceId);
    _nameController = TextEditingController(text: service?.displayName ?? '');
    _baseUrlController = TextEditingController(text: service?.baseUrl ?? '');
    _apiKeyController = TextEditingController(text: service?.apiKey ?? '');
    _headersController = TextEditingController(
      text: _encodeHeaders(service?.customHeaders ?? const <String, String>{}),
    );
    _enabled = service?.enabled ?? true;
    _usesSharedProxy = service?.usesSharedProxy ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _headersController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(aiSettingsProvider);
    final service = settings.services.firstById(widget.serviceId);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.58 : 0.62);

    if (service == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          title: Text(isZh ? '服务详情' : 'Service Details'),
        ),
        body: Center(child: Text(isZh ? '服务不存在。' : 'Service not found.')),
      );
    }

    final template = findAiProviderTemplate(service.templateId);
    final impactedRoutes = settings.taskRouteBindings
        .where((binding) => binding.serviceId == widget.serviceId)
        .map((binding) => _routeLabel(binding.routeId, isZh))
        .toList(growable: false);
    final proxyConfigured = settings.proxySettings.isConfigured;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(isZh ? '服务详情' : 'Service Details'),
        actions: [
          TextButton(
            onPressed: () => _save(showSavedToast: true),
            child: Text(isZh ? '保存' : 'Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _SectionCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AiProviderLogo(
                        template: template,
                        size: 48,
                        iconSize: 26,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service.displayName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: textMain,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              template == null
                                  ? service.templateId
                                  : localizedAiProviderTemplateDisplayName(
                                      template,
                                      isZh: isZh,
                                    ),
                              style: TextStyle(color: textMuted),
                            ),
                          ],
                        ),
                      ),
                      _StatusBadge(
                        label: _validationLabel(
                          service.lastValidationStatus,
                          isZh,
                        ),
                        status: service.lastValidationStatus,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: isZh ? '服务名称' : 'Service Name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _baseUrlController,
                    decoration: InputDecoration(
                      labelText: 'Base URL',
                      helperText: _endpointPreview(service),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (template?.requiresApiKey ?? true)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _apiKeyController,
                            obscureText: _obscureApiKey,
                            decoration: InputDecoration(
                              labelText: 'API Key',
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _ValidationIcon(
                                    status: service.lastValidationStatus,
                                    checking: _isCheckingConnection,
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _obscureApiKey = !_obscureApiKey;
                                      });
                                    },
                                    icon: Icon(
                                      _obscureApiKey
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: FilledButton.tonalIcon(
                            onPressed: _isCheckingConnection
                                ? null
                                : _checkConnection,
                            icon: _isCheckingConnection
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    service.lastValidationStatus ==
                                            AiValidationStatus.success
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.bolt_rounded,
                                  ),
                            label: Text(
                              _isCheckingConnection
                                  ? (isZh ? '检查中' : 'Checking')
                                  : (isZh ? '检查' : 'Check'),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isZh
                                ? '该服务通常不需要 API Key。'
                                : 'This service usually does not require an API key.',
                            style: TextStyle(color: textMuted),
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _isCheckingConnection
                              ? null
                              : _checkConnection,
                          icon: _isCheckingConnection
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  service.lastValidationStatus ==
                                          AiValidationStatus.success
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.bolt_rounded,
                                ),
                          label: Text(isZh ? '检查连接' : 'Check Connection'),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _headersController,
                    minLines: 3,
                    maxLines: 6,
                    decoration: InputDecoration(
                      labelText: isZh ? '额外 Headers' : 'Extra Headers',
                      helperText: isZh
                          ? '\u6bcf\u884c\u4e00\u4e2a\uff0c\u683c\u5f0f key:value\uff0c\u9ed8\u8ba4\u4e3a\u7a7a\u53ef\u4e0d\u586b\u5199'
                          : 'One header per line, formatted as key:value. Optional; leave empty if unused.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _enabled,
                    onChanged: (value) => setState(() => _enabled = value),
                    title: Text(isZh ? '启用服务' : 'Enable Service'),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _usesSharedProxy,
                    onChanged: (value) {
                      setState(() => _usesSharedProxy = value);
                    },
                    title: Text(context.t.strings.aiProxy.useSharedProxy),
                    subtitle: Text(
                      context.t.strings.aiProxy.useSharedProxyDescription,
                    ),
                  ),
                  if (_usesSharedProxy && !proxyConfigured) ...[
                    const SizedBox(height: 8),
                    _ProxyWarningCard(
                      message: context.t.strings.aiProxy.incompleteWarning,
                      actionLabel: context.t.strings.aiProxy.openSettings,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const AiProxySettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                  if (template?.docsUrl.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _openDocs(template!.docsUrl),
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: Text(isZh ? '打开官方文档' : 'Open documentation'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox.shrink(),
          Offstage(offstage: true, child: _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isZh ? '连接状态' : 'Connection Status',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: textMain,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _ValidationIcon(
                      status: service.lastValidationStatus,
                      checking: _isCheckingConnection,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        service.lastValidationMessage?.trim().isNotEmpty == true
                            ? service.lastValidationMessage!.trim()
                            : _validationDescription(
                                service.lastValidationStatus,
                                isZh,
                              ),
                        style: TextStyle(color: textMain),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  service.lastValidatedAt == null
                      ? (isZh ? '最近校验：从未检查' : 'Last checked: never')
                      : '${isZh ? '最近校验' : 'Last checked'}: ${service.lastValidatedAt}',
                  style: TextStyle(fontSize: 12, color: textMuted),
                ),
              ],
            ),
          )),
          const SizedBox(height: 12),
          AiServiceModelScreen(serviceId: service.serviceId, embedded: true),
          const SizedBox(height: 12),
          _ActionTile(
            title: isZh ? '复制服务' : 'Duplicate Service',
            subtitle: isZh
                ? '复制配置和模型，不会改动默认用途绑定。'
                : 'Copy the service and models without changing route bindings.',
            onTap: () async {
              await ref
                  .read(aiSettingsProvider.notifier)
                  .duplicateService(service.serviceId);
              if (!context.mounted) return;
              showTopToast(context, isZh ? '服务已复制。' : 'Service duplicated.');
            },
          ),
          const SizedBox(height: 12),
          _ActionTile(
            title: isZh ? '删除服务' : 'Delete Service',
            subtitle: impactedRoutes.isEmpty
                ? (isZh ? '此操作不可撤销。' : 'This cannot be undone.')
                : (isZh
                      ? '会影响：${impactedRoutes.join('、')}'
                      : 'Impacts: ${impactedRoutes.join(', ')}'),
            destructive: true,
            onTap: _delete,
          ),
        ],
      ),
    );
  }

  String _encodeHeaders(Map<String, String> headers) {
    if (headers.isEmpty) return '';
    return headers.entries
        .map((entry) => '${entry.key}:${entry.value}')
        .join('\n');
  }

  Map<String, String> _parseHeaders() {
    final next = <String, String>{};
    for (final line in _headersController.text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final separator = trimmed.indexOf(':');
      if (separator <= 0) continue;
      final key = trimmed.substring(0, separator).trim();
      final value = trimmed.substring(separator + 1).trim();
      if (key.isEmpty || value.isEmpty) continue;
      next[key] = value;
    }
    return next;
  }

  AiServiceInstance? _buildDraftService(
    AiServiceInstance? current,
    AiProviderTemplate? template,
  ) {
    if (current == null) return null;
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    final displayName = _nameController.text.trim().isEmpty
        ? (template == null
              ? current.displayName
              : localizedAiProviderTemplateDisplayName(template, isZh: isZh))
        : _nameController.text.trim();
    final mergedHeaders = <String, String>{
      ...?template?.defaultHeaders,
      ..._parseHeaders(),
    };
    return current.copyWith(
      displayName: displayName,
      enabled: _enabled,
      usesSharedProxy: _usesSharedProxy,
      baseUrl: _baseUrlController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      customHeaders: Map<String, String>.unmodifiable(mergedHeaders),
    );
  }

  Future<void> _checkConnection() async {
    final current = ref
        .read(aiSettingsProvider)
        .services
        .firstById(widget.serviceId);
    final template = current == null
        ? null
        : findAiProviderTemplate(current.templateId);
    final draft = _buildDraftService(current, template);
    if (draft == null) return;

    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    final stopwatch = Stopwatch()..start();
    LogManager.instance.info(
      'AI settings connection check started',
      context: buildAiServiceLogContext(draft, template: template),
    );
    setState(() => _isCheckingConnection = true);
    try {
      final registry = ref.read(aiProviderRegistryProvider);
      final adapter = registry.adapterFor(draft.adapterKind);
      final result = await adapter.validateConfig(
        draft,
        proxySettings: ref.read(aiSettingsProvider).proxySettings,
      );
      await ref
          .read(aiSettingsProvider.notifier)
          .upsertService(
            draft.copyWith(
              lastValidatedAt: DateTime.now(),
              lastValidationStatus: result.status,
              lastValidationMessage: result.message,
            ),
          );
      LogManager.instance.info(
        'AI settings connection check finished',
        context: <String, Object?>{
          ...buildAiServiceLogContext(draft, template: template),
          'validation_status': result.status.name,
          'elapsed_ms': stopwatch.elapsedMilliseconds,
          if (result.message?.trim().isNotEmpty == true)
            'validation_message': result.message!.trim(),
        },
      );
      if (!mounted) return;
      showTopToast(
        context,
        result.status == AiValidationStatus.success
            ? (isZh ? '连接检查成功。' : 'Connection check succeeded.')
            : (result.message?.trim().isNotEmpty == true
                  ? result.message!.trim()
                  : (isZh ? '连接检查失败。' : 'Connection check failed.')),
      );
    } catch (error, stackTrace) {
      LogManager.instance.warn(
        'AI settings connection check failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          ...buildAiServiceLogContext(draft, template: template),
          'elapsed_ms': stopwatch.elapsedMilliseconds,
        },
      );
      if (!mounted) return;
      showTopToast(context, isZh ? '连接检查失败。' : 'Connection check failed.');
    } finally {
      stopwatch.stop();
      if (mounted) {
        setState(() => _isCheckingConnection = false);
      }
    }
  }

  Future<void> _openDocs(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      final isZh =
          Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
      showTopToast(context, isZh ? '无法打开链接。' : 'Unable to open link.');
    }
  }

  Future<void> _save({required bool showSavedToast}) async {
    if (!(_formKey.currentState?.validate() ?? true)) return;
    final service = ref
        .read(aiSettingsProvider)
        .services
        .firstById(widget.serviceId);
    final template = service == null
        ? null
        : findAiProviderTemplate(service.templateId);
    final draft = _buildDraftService(service, template);
    if (draft == null) return;
    await ref.read(aiSettingsProvider.notifier).upsertService(draft);
    if (!mounted || !showSavedToast) return;
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    showTopToast(context, isZh ? '服务已保存。' : 'Service saved.');
  }

  Future<void> _delete() async {
    final settings = ref.read(aiSettingsProvider);
    final impactedRoutes = settings.taskRouteBindings
        .where((binding) => binding.serviceId == widget.serviceId)
        .map(
          (binding) => _routeLabel(
            binding.routeId,
            Localizations.localeOf(context).languageCode.toLowerCase() == 'zh',
          ),
        )
        .toList(growable: false);
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isZh ? '删除服务？' : 'Delete service?'),
        content: Text(
          impactedRoutes.isEmpty
              ? (isZh ? '此操作不可撤销。' : 'This cannot be undone.')
              : (isZh
                    ? '会影响以下默认用途：${impactedRoutes.join('、')}'
                    : 'This will affect routes: ${impactedRoutes.join(', ')}'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(isZh ? '取消' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(isZh ? '删除' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(aiSettingsProvider.notifier).deleteService(widget.serviceId);
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  String _routeLabel(AiTaskRouteId routeId, bool isZh) {
    return switch (routeId) {
      AiTaskRouteId.summary => isZh ? 'AI 总结' : 'AI Summary',
      AiTaskRouteId.analysisReport => isZh ? '分析报告' : 'Analysis Report',
      AiTaskRouteId.quickPrompt => isZh ? '快速提示词' : 'Quick Prompt',
      AiTaskRouteId.embeddingRetrieval =>
        isZh ? 'Embedding 检索' : 'Embedding Retrieval',
    };
  }

  String _validationLabel(AiValidationStatus status, bool isZh) {
    return switch (status) {
      AiValidationStatus.success => isZh ? '可用' : 'Ready',
      AiValidationStatus.failed => isZh ? '失败' : 'Failed',
      AiValidationStatus.unknown => isZh ? '未检查' : 'Not checked',
    };
  }

  String _validationDescription(AiValidationStatus status, bool isZh) {
    return switch (status) {
      AiValidationStatus.success =>
        isZh ? '最近一次检查通过，服务可正常访问。' : 'The last connectivity check passed.',
      AiValidationStatus.failed =>
        isZh
            ? '最近一次检查失败，请确认地址、密钥和模型。'
            : 'The last connectivity check failed. Verify the URL, key, and model.',
      AiValidationStatus.unknown =>
        isZh ? '还没有执行过检查。' : 'Connection has not been checked yet.',
    };
  }

  String _endpointPreview(AiServiceInstance service) {
    final baseUrl = _baseUrlController.text.trim().isEmpty
        ? service.baseUrl
        : _baseUrlController.text.trim();
    final normalized = baseUrl.replaceAll(RegExp(r'/+$'), '');
    if (normalized.isEmpty) return '';
    return switch (service.adapterKind) {
      AiProviderAdapterKind.openAiCompatible =>
        '$normalized/v1/chat/completions',
      AiProviderAdapterKind.anthropic => '$normalized/v1/messages',
      AiProviderAdapterKind.gemini => '$normalized/v1beta/models',
      AiProviderAdapterKind.azureOpenAi =>
        '$normalized/openai/models?api-version=...',
      AiProviderAdapterKind.ollama => '$normalized/api/tags',
    };
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight,
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }
}

class _ProxyWarningCard extends StatelessWidget {
  const _ProxyWarningCard({
    required this.message,
    required this.actionLabel,
    required this.onTap,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: colorScheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                const SizedBox(height: 8),
                TextButton(onPressed: onTap, child: Text(actionLabel)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.status});

  final String label;
  final AiValidationStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AiValidationStatus.success => Colors.green,
      AiValidationStatus.failed => Colors.redAccent,
      AiValidationStatus.unknown => Colors.orange,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ValidationIcon extends StatelessWidget {
  const _ValidationIcon({
    required this.status,
    required this.checking,
    this.size = 18,
  });

  final AiValidationStatus status;
  final bool checking;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (checking) {
      return SizedBox(
        width: size,
        height: size,
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Icon(
      switch (status) {
        AiValidationStatus.success => Icons.check_circle_rounded,
        AiValidationStatus.failed => Icons.error_rounded,
        AiValidationStatus.unknown => Icons.help_outline_rounded,
      },
      size: size,
      color: switch (status) {
        AiValidationStatus.success => Colors.green,
        AiValidationStatus.failed => Colors.redAccent,
        AiValidationStatus.unknown => Colors.orange,
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? MemoFlowPalette.cardDark
                : MemoFlowPalette.cardLight,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: destructive
                            ? Colors.redAccent
                            : (isDark
                                  ? MemoFlowPalette.textDark
                                  : MemoFlowPalette.textLight),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            (isDark
                                    ? MemoFlowPalette.textDark
                                    : MemoFlowPalette.textLight)
                                .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color:
                    (isDark
                            ? MemoFlowPalette.textDark
                            : MemoFlowPalette.textLight)
                        .withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
