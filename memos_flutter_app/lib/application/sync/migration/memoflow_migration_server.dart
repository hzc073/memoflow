import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'memoflow_migration_import_service.dart';
import 'memoflow_migration_models.dart';
import 'memoflow_migration_protocol.dart';

class MemoFlowMigrationServerState {
  const MemoFlowMigrationServerState({
    required this.sessionDescriptor,
    required this.proposal,
    required this.status,
  });

  final MemoFlowMigrationSessionDescriptor? sessionDescriptor;
  final MemoFlowMigrationProposal? proposal;
  final MemoFlowMigrationStatusSnapshot status;
}

class MemoFlowMigrationServer {
  MemoFlowMigrationServer({
    required this.importService,
    this.sessionTimeout = const Duration(minutes: 10),
    this.uploadTimeout = const Duration(minutes: 5),
    this.enableBroadcast = true,
    Future<Directory> Function()? temporaryDirectoryResolver,
    Future<void> Function(MemoFlowMigrationSessionDescriptor descriptor)?
    broadcastStarter,
  }) : _temporaryDirectoryResolver = temporaryDirectoryResolver,
       _broadcastStarter = broadcastStarter;

  final MemoFlowMigrationImportService importService;
  final Duration sessionTimeout;
  final Duration uploadTimeout;
  final bool enableBroadcast;
  final Future<Directory> Function()? _temporaryDirectoryResolver;
  final Future<void> Function(MemoFlowMigrationSessionDescriptor descriptor)?
  _broadcastStarter;

  final StreamController<MemoFlowMigrationServerState> _events =
      StreamController<MemoFlowMigrationServerState>.broadcast();

  HttpServer? _server;
  BonsoirBroadcast? _broadcast;
  MemoFlowMigrationSessionDescriptor? _descriptor;
  MemoFlowMigrationProposal? _proposal;
  MemoFlowMigrationStatusSnapshot _status =
      const MemoFlowMigrationStatusSnapshot(
        sessionId: '',
        proposalId: '',
        stage: MemoFlowMigrationTransferStage.idle,
      );
  MemoFlowMigrationReceiveMode _receiveMode =
      MemoFlowMigrationReceiveMode.newWorkspace;
  Set<MemoFlowMigrationConfigType> _acceptedSensitiveConfigTypes =
      const <MemoFlowMigrationConfigType>{};
  String? _uploadToken;
  Timer? _sessionTimeoutTimer;
  Timer? _uploadTimeoutTimer;

  Stream<MemoFlowMigrationServerState> get events => _events.stream;

  MemoFlowMigrationServerState get currentState {
    return MemoFlowMigrationServerState(
      sessionDescriptor: _descriptor,
      proposal: _proposal,
      status: _status,
    );
  }

  Future<MemoFlowMigrationSessionDescriptor> startSession({
    required String receiverDeviceName,
    required String receiverPlatform,
  }) async {
    await stopSession();

    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _server = server;
    final host = await _resolveLocalIpv4Address();
    final descriptor = MemoFlowMigrationSessionDescriptor(
      sessionId: _randomId(24),
      pairingCode: _randomPairingCode(),
      host: host,
      port: server.port,
      receiverDeviceName: receiverDeviceName,
      receiverPlatform: receiverPlatform,
      protocolVersion: memoFlowMigrationProtocolVersion,
    );
    _descriptor = descriptor;
    _proposal = null;
    _uploadToken = null;
    _acceptedSensitiveConfigTypes = const <MemoFlowMigrationConfigType>{};
    _receiveMode = MemoFlowMigrationReceiveMode.newWorkspace;
    _updateStatus(
      MemoFlowMigrationTransferStage.waitingProposal,
      sessionId: descriptor.sessionId,
      proposalId: '',
      message: 'Waiting for sender proposal.',
    );

    _armSessionTimeout();
    unawaited(_listen(server));
    if (enableBroadcast) {
      try {
        await _startBroadcast(descriptor);
      } catch (_) {}
    }
    _emit();
    return descriptor;
  }

  Future<void> stopSession({bool preserveStatus = false}) async {
    _sessionTimeoutTimer?.cancel();
    _uploadTimeoutTimer?.cancel();
    _sessionTimeoutTimer = null;
    _uploadTimeoutTimer = null;
    if (_broadcast != null) {
      try {
        await _broadcast!.stop();
      } catch (_) {}
      _broadcast = null;
    }
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
    _descriptor = null;
    _proposal = null;
    _uploadToken = null;
    if (!preserveStatus) {
      _status = const MemoFlowMigrationStatusSnapshot(
        sessionId: '',
        proposalId: '',
        stage: MemoFlowMigrationTransferStage.idle,
      );
    }
    _emit();
  }

  Future<MemoFlowMigrationAcceptance> acceptProposal({
    required MemoFlowMigrationReceiveMode receiveMode,
    required Set<MemoFlowMigrationConfigType> acceptedSensitiveConfigTypes,
  }) async {
    final proposal = _proposal;
    final descriptor = _descriptor;
    if (proposal == null || descriptor == null) {
      throw StateError('No active proposal to accept.');
    }
    _receiveMode = receiveMode;
    _acceptedSensitiveConfigTypes = acceptedSensitiveConfigTypes;
    _uploadToken = _randomId(32);
    _clearSessionTimeout();
    _updateStatus(
      MemoFlowMigrationTransferStage.awaitingUpload,
      sessionId: descriptor.sessionId,
      proposalId: proposal.proposalId,
      message: 'Waiting for sender upload.',
      uploadToken: _uploadToken,
    );
    _touchUploadTimeout();
    return MemoFlowMigrationAcceptance(
      proposalId: proposal.proposalId,
      receiveMode: receiveMode,
      acceptedSensitiveConfigTypes: acceptedSensitiveConfigTypes,
      uploadToken: _uploadToken!,
    );
  }

  Future<void> cancelCurrentProposal({String? message}) async {
    if (_descriptor == null) return;
    _updateStatus(
      MemoFlowMigrationTransferStage.cancelled,
      sessionId: _descriptor!.sessionId,
      proposalId: _proposal?.proposalId ?? '',
      message: message ?? 'Migration was cancelled.',
    );
    await stopSession(preserveStatus: true);
  }

  Future<void> dispose() async {
    await stopSession();
    await _events.close();
  }

  Future<void> _listen(HttpServer server) async {
    await for (final request in server) {
      unawaited(_handleRequest(request));
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final path = request.uri.path;
      final method = request.method.toUpperCase();

      if (method == 'GET' && path == '/migration/v1/health') {
        await _writeJson(request.response, HttpStatus.ok, <String, dynamic>{
          'ok': true,
          'sessionId': _descriptor?.sessionId ?? '',
          'receiverDeviceName': _descriptor?.receiverDeviceName ?? '',
          'platform': _descriptor?.receiverPlatform ?? '',
          'protocolVersion': memoFlowMigrationProtocolVersion,
        });
        return;
      }

      if (method == 'POST' && path == '/migration/v1/proposal') {
        final body = await _readJsonBody(request);
        final response = _handleProposalRequest(body);
        await _writeJson(request.response, HttpStatus.ok, response);
        return;
      }

      if (method == 'GET' && path == '/migration/v1/status') {
        final proposalId =
            request.uri.queryParameters['proposalId']?.trim() ?? '';
        if (_proposal != null &&
            proposalId.isNotEmpty &&
            _proposal!.proposalId != proposalId) {
          await _writeJson(
            request.response,
            HttpStatus.notFound,
            <String, dynamic>{'ok': false, 'error': 'Proposal not found.'},
          );
          return;
        }
        await _writeJson(request.response, HttpStatus.ok, _status.toJson());
        return;
      }

      if (method == 'PUT' && path == '/migration/v1/upload') {
        await _handleUploadRequest(request);
        return;
      }

      await _writeJson(request.response, HttpStatus.notFound, <String, dynamic>{
        'ok': false,
        'error': 'Not found.',
      });
    } catch (error) {
      await _writeJson(
        request.response,
        HttpStatus.internalServerError,
        <String, dynamic>{'ok': false, 'error': error.toString()},
      );
    }
  }

  Map<String, dynamic> _handleProposalRequest(Map<String, dynamic> body) {
    final descriptor = _descriptor;
    if (descriptor == null) {
      throw StateError('Receiver session is not running.');
    }
    if (_status.stage != MemoFlowMigrationTransferStage.waitingProposal ||
        _proposal != null) {
      throw StateError('Receiver is not accepting proposals.');
    }
    final sessionId = (body['sessionId'] as String? ?? '').trim();
    final pairingCode = (body['pairingCode'] as String? ?? '').trim();
    if (sessionId != descriptor.sessionId) {
      throw StateError('Session id does not match.');
    }
    if (pairingCode != descriptor.pairingCode) {
      throw StateError('Pairing code does not match.');
    }

    final manifestRaw = body['manifest'];
    final proposal = MemoFlowMigrationProposal(
      proposalId: _randomId(16),
      sessionId: sessionId,
      pairingCode: pairingCode,
      senderDeviceName: (body['senderDeviceName'] as String? ?? '').trim(),
      senderPlatform: (body['senderPlatform'] as String? ?? '').trim(),
      manifest: manifestRaw is Map<String, dynamic>
          ? MemoFlowMigrationPackageManifest.fromJson(manifestRaw)
          : manifestRaw is Map
          ? MemoFlowMigrationPackageManifest.fromJson(
              manifestRaw.cast<String, dynamic>(),
            )
          : throw StateError('Manifest is missing.'),
    );

    _proposal = proposal;
    _updateStatus(
      MemoFlowMigrationTransferStage.awaitingAccept,
      sessionId: descriptor.sessionId,
      proposalId: proposal.proposalId,
      message: 'Waiting for receiver confirmation.',
    );
    _armSessionTimeout();
    return <String, dynamic>{'ok': true, 'proposalId': proposal.proposalId};
  }

  Future<void> _handleUploadRequest(HttpRequest request) async {
    final descriptor = _descriptor;
    final proposal = _proposal;
    if (descriptor == null || proposal == null) {
      await _writeJson(request.response, HttpStatus.conflict, <String, dynamic>{
        'ok': false,
        'error': 'No active proposal.',
      });
      return;
    }
    if (_status.stage != MemoFlowMigrationTransferStage.awaitingUpload) {
      await _writeJson(request.response, HttpStatus.conflict, <String, dynamic>{
        'ok': false,
        'error': 'Receiver is not ready for upload.',
      });
      return;
    }
    final authHeader = request.headers.value(HttpHeaders.authorizationHeader);
    final token = authHeader?.replaceFirst('Bearer ', '').trim() ?? '';
    if (_uploadToken == null || token != _uploadToken) {
      await _writeJson(
        request.response,
        HttpStatus.unauthorized,
        <String, dynamic>{'ok': false, 'error': 'Upload token is invalid.'},
      );
      return;
    }

    final tempRoot = await _resolveTemporaryDirectory();
    final uploadFile = File(
      p.join(
        tempRoot.path,
        'memoflow_migration_upload_${DateTime.now().millisecondsSinceEpoch}.zip',
      ),
    );
    final sink = uploadFile.openWrite();
    var receivedBytes = 0;
    var uploadStarted = false;
    try {
      uploadStarted = true;
      _touchUploadTimeout();
      _updateStatus(
        MemoFlowMigrationTransferStage.receiving,
        sessionId: descriptor.sessionId,
        proposalId: proposal.proposalId,
        message: 'Receiving package.',
        receivedBytes: 0,
        uploadToken: _uploadToken,
      );
      await for (final chunk in request) {
        _touchUploadTimeout();
        receivedBytes += chunk.length;
        sink.add(chunk);
        _updateStatus(
          MemoFlowMigrationTransferStage.receiving,
          sessionId: descriptor.sessionId,
          proposalId: proposal.proposalId,
          message: 'Receiving package.',
          receivedBytes: receivedBytes,
          uploadToken: _uploadToken,
        );
      }
      await sink.flush();
      await sink.close();
      _clearUploadTimeout();

      await _validateUpload(uploadFile, proposal);
      final result = await importService.importPackage(
        packageFile: uploadFile,
        proposal: proposal,
        receiveMode: _receiveMode,
        allowedConfigTypes: _resolvedAllowedConfigTypes(proposal.manifest),
        activateImportedWorkspace: false,
        onProgress: (stage, {message}) {
          _updateStatus(
            stage,
            sessionId: descriptor.sessionId,
            proposalId: proposal.proposalId,
            message: message,
            receivedBytes: receivedBytes,
            uploadToken: _uploadToken,
          );
        },
      );
      _updateStatus(
        MemoFlowMigrationTransferStage.completed,
        sessionId: descriptor.sessionId,
        proposalId: proposal.proposalId,
        message: 'Migration completed.',
        receivedBytes: receivedBytes,
        result: result,
      );
      await _writeJson(request.response, HttpStatus.ok, <String, dynamic>{
        'ok': true,
        'receivedBytes': receivedBytes,
        'result': result.toJson(),
      });
      final workspaceKey = result.workspaceKey?.trim() ?? '';
      if (_receiveMode == MemoFlowMigrationReceiveMode.newWorkspace &&
          workspaceKey.isNotEmpty) {
        unawaited(_activateImportedWorkspaceAfterResponse(workspaceKey));
      }
      _uploadToken = null;
    } catch (error) {
      if (uploadStarted) {
        _clearUploadTimeout();
      }
      _updateStatus(
        MemoFlowMigrationTransferStage.failed,
        sessionId: descriptor.sessionId,
        proposalId: proposal.proposalId,
        message: 'Migration failed.',
        receivedBytes: receivedBytes,
        error: error.toString(),
      );
      await _writeJson(
        request.response,
        HttpStatus.internalServerError,
        <String, dynamic>{'ok': false, 'error': error.toString()},
      );
    } finally {
      if (await uploadFile.exists()) {
        await uploadFile.delete();
      }
    }
  }

  Future<void> _activateImportedWorkspaceAfterResponse(
    String workspaceKey,
  ) async {
    try {
      await importService.activateImportedWorkspace(workspaceKey);
    } catch (_) {}
  }

  Future<void> _validateUpload(
    File uploadFile,
    MemoFlowMigrationProposal proposal,
  ) async {
    _updateStatus(
      MemoFlowMigrationTransferStage.validating,
      sessionId: proposal.sessionId,
      proposalId: proposal.proposalId,
      message: 'Validating package.',
      uploadToken: _uploadToken,
    );
    final actualSize = await uploadFile.length();
    if (proposal.manifest.totalBytes > 0 &&
        proposal.manifest.totalBytes != actualSize) {
      throw StateError('Uploaded file size does not match proposal.');
    }
    if (proposal.manifest.sha256.trim().isNotEmpty) {
      final actualSha = await crypto.sha256.bind(uploadFile.openRead()).first;
      if (actualSha.toString() != proposal.manifest.sha256) {
        throw StateError('Uploaded package checksum does not match.');
      }
    }
  }

  Future<void> _startBroadcast(
    MemoFlowMigrationSessionDescriptor descriptor,
  ) async {
    if (_broadcastStarter != null) {
      await _broadcastStarter(descriptor);
      return;
    }
    final service = BonsoirService(
      name: descriptor.receiverDeviceName,
      type: memoFlowMigrationServiceType,
      port: descriptor.port,
      attributes: <String, String>{
        'sid': descriptor.sessionId,
        'code': descriptor.pairingCode,
        'ver': descriptor.protocolVersion,
        'plat': descriptor.receiverPlatform,
        'name': descriptor.receiverDeviceName,
        'host': descriptor.host,
      },
    );
    final broadcast = BonsoirBroadcast(service: service);
    await broadcast.initialize();
    try {
      await broadcast.start();
    } catch (_) {
      try {
        await broadcast.stop();
      } catch (_) {}
      rethrow;
    }
    _broadcast = broadcast;
  }

  Set<MemoFlowMigrationConfigType> _resolvedAllowedConfigTypes(
    MemoFlowMigrationPackageManifest manifest,
  ) {
    final allowed = <MemoFlowMigrationConfigType>{};
    for (final type in manifest.configTypes) {
      if (!type.isSensitive || _acceptedSensitiveConfigTypes.contains(type)) {
        allowed.add(type);
      }
    }
    return allowed;
  }

  Future<Map<String, dynamic>> _readJsonBody(HttpRequest request) async {
    final content = await utf8.decoder.bind(request).join();
    if (content.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(content);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();
    throw const FormatException('Invalid JSON payload.');
  }

  Future<void> _writeJson(
    HttpResponse response,
    int statusCode,
    Map<String, dynamic> payload,
  ) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(payload));
    await response.close();
  }

  void _updateStatus(
    MemoFlowMigrationTransferStage stage, {
    required String sessionId,
    required String proposalId,
    String? message,
    String? uploadToken,
    int? receivedBytes,
    String? error,
    MemoFlowMigrationResult? result,
  }) {
    _status = MemoFlowMigrationStatusSnapshot(
      sessionId: sessionId,
      proposalId: proposalId,
      stage: stage,
      message: message,
      uploadToken: uploadToken,
      receivedBytes: receivedBytes,
      error: error,
      result: result,
    );
    _emit();
  }

  void _emit() {
    if (_events.isClosed) return;
    _events.add(currentState);
  }

  void _armSessionTimeout() {
    _clearSessionTimeout();
    _sessionTimeoutTimer = Timer(sessionTimeout, () async {
      await cancelCurrentProposal(message: 'Receiver session timed out.');
    });
  }

  void _touchUploadTimeout() {
    _clearUploadTimeout();
    _uploadTimeoutTimer = Timer(uploadTimeout, () async {
      await cancelCurrentProposal(message: 'Upload timed out.');
    });
  }

  void _clearSessionTimeout() {
    _sessionTimeoutTimer?.cancel();
    _sessionTimeoutTimer = null;
  }

  void _clearUploadTimeout() {
    _uploadTimeoutTimer?.cancel();
    _uploadTimeoutTimer = null;
  }

  Future<Directory> _resolveTemporaryDirectory() async {
    if (_temporaryDirectoryResolver != null) {
      return _temporaryDirectoryResolver();
    }
    return getTemporaryDirectory();
  }

  Future<String> _resolveLocalIpv4Address() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        final value = address.address.trim();
        if (value.startsWith('169.254.')) continue;
        if (value.isNotEmpty) return value;
      }
    }
    return InternetAddress.loopbackIPv4.address;
  }

  String _randomPairingCode() {
    final value = DateTime.now().microsecondsSinceEpoch % 1000000;
    return value.toString().padLeft(6, '0');
  }

  String _randomId(int length) {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final buffer = StringBuffer();
    var seed = DateTime.now().microsecondsSinceEpoch;
    for (var i = 0; i < length; i++) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      buffer.write(alphabet[seed % alphabet.length]);
    }
    return buffer.toString();
  }
}
