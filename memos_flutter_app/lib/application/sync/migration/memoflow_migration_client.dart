import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import 'memoflow_migration_models.dart';
import 'memoflow_migration_protocol.dart';

class MemoFlowMigrationClient {
  MemoFlowMigrationClient({Dio Function()? dioFactory})
    : _dioFactory = dioFactory;

  final Dio Function()? _dioFactory;

  Future<String> submitProposal({
    required MemoFlowMigrationSessionDescriptor descriptor,
    required MemoFlowMigrationPackageManifest manifest,
    required String senderDeviceName,
    required String senderPlatform,
  }) async {
    final dio = _buildDio(descriptor);
    final response = await dio.post(
      '/migration/v1/proposal',
      data: <String, dynamic>{
        'sessionId': descriptor.sessionId,
        'pairingCode': descriptor.pairingCode,
        'senderDeviceName': senderDeviceName,
        'senderPlatform': senderPlatform,
        'manifest': manifest.toJson(),
      },
    );
    final data = _expectMap(response.data);
    return (data['proposalId'] as String? ?? '').trim();
  }

  Future<MemoFlowMigrationStatusSnapshot> getStatus({
    required MemoFlowMigrationSessionDescriptor descriptor,
    required String proposalId,
  }) async {
    final dio = _buildDio(descriptor);
    final response = await dio.get(
      '/migration/v1/status',
      queryParameters: <String, dynamic>{'proposalId': proposalId},
    );
    return MemoFlowMigrationStatusSnapshot.fromJson(_expectMap(response.data));
  }

  Future<MemoFlowMigrationUploadResponse> uploadPackage({
    required MemoFlowMigrationSessionDescriptor descriptor,
    required String uploadToken,
    required File packageFile,
    void Function(int sentBytes, int totalBytes)? onSendProgress,
  }) async {
    final dio = _buildDio(descriptor);
    final length = await packageFile.length();
    final response = await dio.put(
      '/migration/v1/upload',
      data: packageFile.openRead(),
      options: Options(
        headers: <String, Object>{
          HttpHeaders.authorizationHeader: 'Bearer $uploadToken',
          HttpHeaders.contentTypeHeader: 'application/zip',
          HttpHeaders.contentLengthHeader: length,
        },
      ),
      onSendProgress: onSendProgress,
    );
    return MemoFlowMigrationUploadResponse.fromJson(_expectMap(response.data));
  }

  Future<MemoFlowMigrationSessionDescriptor> resolveManualDescriptor({
    required String host,
    required int port,
    required String pairingCode,
  }) async {
    final dio = _buildDioForHost(host: host, port: port);
    final response = await dio.get('/migration/v1/health');
    final data = _expectMap(response.data);
    final sessionId = (data['sessionId'] as String? ?? '').trim();
    if (sessionId.isEmpty) {
      throw const FormatException('Receiver session is not ready.');
    }
    return MemoFlowMigrationSessionDescriptor(
      sessionId: sessionId,
      pairingCode: pairingCode.trim(),
      host: host.trim(),
      port: port,
      receiverDeviceName: (data['receiverDeviceName'] as String? ?? '').trim(),
      receiverPlatform: (data['platform'] as String? ?? '').trim(),
      protocolVersion:
          (data['protocolVersion'] as String? ?? '').trim().isNotEmpty
          ? (data['protocolVersion'] as String).trim()
          : memoFlowMigrationProtocolVersion,
    );
  }

  Dio _buildDio(MemoFlowMigrationSessionDescriptor descriptor) {
    return _buildDioForHost(host: descriptor.host, port: descriptor.port);
  }

  Dio _buildDioForHost({required String host, required int port}) {
    if (_dioFactory != null) {
      return _dioFactory();
    }
    return Dio(
      BaseOptions(
        baseUrl: Uri(scheme: 'http', host: host, port: port).toString(),
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 12),
        sendTimeout: const Duration(minutes: 10),
        responseType: ResponseType.json,
      ),
    );
  }

  Map<String, dynamic> _expectMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    }
    throw const FormatException('Invalid JSON response');
  }
}
