import '../../core/log_sanitizer.dart';
import 'ai_provider_models.dart';
import 'ai_provider_templates.dart';
import 'ai_settings_models.dart';

Map<String, Object?> buildAiServiceLogContext(
  AiServiceInstance service, {
  AiProviderTemplate? template,
  AiModelEntry? model,
  AiTaskRouteBinding? binding,
  int? discoveredCount,
  int? routeCount,
  String? endpoint,
  bool? reusedExistingService,
}) {
  final resolvedTemplate =
      template ?? findAiProviderTemplate(service.templateId);
  final headers = service.customHeaders;
  return <String, Object?>{
    'service_id': service.serviceId,
    'service_name': service.displayName,
    'template_id': service.templateId,
    'template_name': resolvedTemplate?.displayName,
    'adapter_kind': service.adapterKind.name,
    'enabled': service.enabled,
    'uses_shared_proxy': service.usesSharedProxy,
    'base_url': LogSanitizer.maskUrl(service.baseUrl),
    'credentials_present': service.apiKey.trim().isNotEmpty,
    'header_count': headers.length,
    if (headers.isNotEmpty) 'headers': LogSanitizer.sanitizeHeaders(headers),
    'model_count': service.models.length,
    if (model != null) 'model_id': model.modelId,
    if (model != null) 'model_code': model.modelKey,
    if (model != null) 'model_name': model.displayName,
    if (model != null)
      'model_capabilities': model.capabilities
          .map((capability) => capability.name)
          .toList(growable: false),
    if (binding != null) 'route_id': binding.routeId.name,
    if (binding != null) 'route_capability': binding.capability.name,
    if (discoveredCount != null) 'discovered_count': discoveredCount,
    if (routeCount != null) 'route_count': routeCount,
    if (endpoint != null && endpoint.trim().isNotEmpty)
      'endpoint': LogSanitizer.maskUrl(endpoint),
    if (reusedExistingService != null)
      'reused_existing_service': reusedExistingService,
  };
}

Map<String, Object?> buildAiProxySettingsLogContext(AiProxySettings settings) {
  return <String, Object?>{
    'proxy_protocol': settings.protocol.name,
    'proxy_host': LogSanitizer.maskHost(settings.host),
    'proxy_port': settings.port,
    'proxy_auth_present':
        settings.username.trim().isNotEmpty || settings.password.trim().isNotEmpty,
    'bypass_local_addresses': settings.bypassLocalAddresses,
    'proxy_configured': settings.isConfigured,
  };
}
