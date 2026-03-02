import 'webdav_export_signature.dart';

class WebDavExportStatus {
  const WebDavExportStatus({
    required this.webDavConfigured,
    required this.encSignature,
    required this.plainSignature,
    required this.plainDetected,
    required this.plainDeprecated,
    required this.plainDetectedAt,
    required this.plainRemindAfter,
    required this.lastExportSuccessAt,
    required this.lastUploadSuccessAt,
  });

  final bool webDavConfigured;
  final WebDavExportSignature? encSignature;
  final WebDavExportSignature? plainSignature;
  final bool plainDetected;
  final bool plainDeprecated;
  final String? plainDetectedAt;
  final String? plainRemindAfter;
  final String? lastExportSuccessAt;
  final String? lastUploadSuccessAt;
}
