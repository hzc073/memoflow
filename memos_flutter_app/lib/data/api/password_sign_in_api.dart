import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/url.dart';
import '../models/user.dart';

enum MemoPasswordSignInEndpoint {
  signinV1,
  createSessionV1GrpcWeb,
  signinV1GrpcWeb,
  signinV2GrpcWeb,
}

extension MemoPasswordSignInEndpointLabel on MemoPasswordSignInEndpoint {
  String get label => switch (this) {
    MemoPasswordSignInEndpoint.signinV1 => 'v1/auth/signin',
    MemoPasswordSignInEndpoint.createSessionV1GrpcWeb =>
      'grpc-web/v1/AuthService/CreateSession',
    MemoPasswordSignInEndpoint.signinV1GrpcWeb =>
      'grpc-web/v1/AuthService/SignIn',
    MemoPasswordSignInEndpoint.signinV2GrpcWeb =>
      'grpc-web/v2/AuthService/SignIn',
  };
}

class MemoPasswordSignInResult {
  const MemoPasswordSignInResult({
    required this.user,
    required this.endpoint,
    this.accessToken,
    this.sessionCookie,
  });

  final User user;
  final MemoPasswordSignInEndpoint endpoint;
  final String? accessToken;
  final String? sessionCookie;
}

class MemoPasswordSignInApi {
  static Future<MemoPasswordSignInResult> signInV1Legacy({
    required Uri baseUrl,
    required String username,
    required String password,
    bool neverExpire = false,
  }) async {
    final dio = _newDio(baseUrl);
    final response = await dio.post(
      'api/v1/auth/signin',
      queryParameters: <String, Object?>{
        'username': username,
        'password': password,
        'neverExpire': neverExpire,
        'never_expire': neverExpire,
      },
      data: <String, Object?>{
        'username': username,
        'password': password,
        'neverExpire': neverExpire,
      },
    );
    final body = _expectJsonMap(response.data);
    final userJson = body['user'] is Map ? body['user'] as Map : body;
    final user = User.fromJson(userJson.cast<String, dynamic>());
    final token =
        _extractAccessToken(body) ??
        _extractCookieValue(response.headers, _kAccessTokenCookieName);
    if (token == null || token.isEmpty) {
      throw const FormatException('Access token missing in response');
    }
    return MemoPasswordSignInResult(
      user: user,
      endpoint: MemoPasswordSignInEndpoint.signinV1,
      accessToken: token,
    );
  }

  static Future<MemoPasswordSignInResult> signInV1Modern({
    required Uri baseUrl,
    required String username,
    required String password,
  }) async {
    final dio = _newDio(baseUrl);
    final response = await dio.post(
      'api/v1/auth/signin',
      data: <String, Object?>{
        'passwordCredentials': <String, Object?>{
          'username': username,
          'password': password,
        },
      },
    );
    final body = _expectJsonMap(response.data);
    final userJson = body['user'] is Map ? body['user'] as Map : body;
    final user = User.fromJson(userJson.cast<String, dynamic>());
    final token =
        _extractAccessToken(body) ??
        _extractCookieValue(response.headers, _kAccessTokenCookieName);
    if (token == null || token.isEmpty) {
      throw const FormatException('Access token missing in response');
    }
    return MemoPasswordSignInResult(
      user: user,
      endpoint: MemoPasswordSignInEndpoint.signinV1,
      accessToken: token,
    );
  }

  static Future<MemoPasswordSignInResult> signInV1CreateSessionGrpcWeb({
    required Uri baseUrl,
    required String username,
    required String password,
  }) async {
    final dio = _newDio(
      baseUrl,
      headers: <String, Object?>{
        'Content-Type': _kGrpcWebContentType,
        'Accept': '*/*',
        'X-Grpc-Web': '1',
        'X-User-Agent': 'grpc-web-dart',
        'grpc-accept-encoding': 'identity',
        'accept-encoding': 'identity',
      },
    );
    final requestMessage = _encodeGrpcWebPasswordCreateSessionRequest(
      username: username,
      password: password,
    );
    final response = await dio.post(
      _kGrpcWebV1CreateSessionPath,
      data: _wrapGrpcWebDataFrame(requestMessage),
      options: Options(responseType: ResponseType.bytes),
    );

    final grpcStatus = _readGrpcStatusCode(response.headers);
    final grpcMessage = _readGrpcStatusMessage(response.headers) ?? '';
    if (grpcStatus != null && grpcStatus != 0) {
      throw _buildGrpcBadResponse(
        requestOptions: response.requestOptions,
        headers: response.headers,
        grpcStatus: grpcStatus,
        grpcMessage: grpcMessage,
      );
    }

    final responseBytes = _asUint8List(response.data);
    final decoded = _parseGrpcWebResponse(responseBytes);
    final trailerStatus =
        int.tryParse(decoded.trailers['grpc-status'] ?? '') ?? 0;
    final trailerMessage = decoded.trailers['grpc-message'] ?? '';
    if (trailerStatus != 0) {
      throw _buildGrpcBadResponse(
        requestOptions: response.requestOptions,
        headers: response.headers,
        grpcStatus: trailerStatus,
        grpcMessage: trailerMessage,
      );
    }

    final user = _parseV2SignInUser(decoded.messageBytes);
    final token = _extractCookieValue(
      response.headers,
      _kAccessTokenCookieName,
    );
    final session = _extractCookieValue(response.headers, _kSessionCookieName);
    return MemoPasswordSignInResult(
      user: user,
      endpoint: MemoPasswordSignInEndpoint.createSessionV1GrpcWeb,
      accessToken: token,
      sessionCookie: session == null || session.isEmpty
          ? null
          : '$_kSessionCookieName=$session',
    );
  }

  static Future<MemoPasswordSignInResult> signInV2GrpcWeb({
    required Uri baseUrl,
    required String username,
    required String password,
  }) async {
    final dio = _newDio(
      baseUrl,
      headers: <String, Object?>{
        'Content-Type': _kGrpcWebContentType,
        'Accept': _kGrpcWebContentType,
        'X-Grpc-Web': '1',
        'X-User-Agent': 'grpc-web-dart',
        'grpc-accept-encoding': 'identity',
        'accept-encoding': 'identity',
      },
    );
    final requestMessage = _encodeGrpcWebPasswordSignInRequest(
      username: username,
      password: password,
      neverExpire: true,
    );
    final response = await dio.post(
      _kGrpcWebV2SignInPath,
      data: _wrapGrpcWebDataFrame(requestMessage),
      options: Options(responseType: ResponseType.bytes),
    );

    final grpcStatus = _readGrpcStatusCode(response.headers);
    final grpcMessage = _readGrpcStatusMessage(response.headers) ?? '';
    if (grpcStatus != null && grpcStatus != 0) {
      throw _buildGrpcBadResponse(
        requestOptions: response.requestOptions,
        headers: response.headers,
        grpcStatus: grpcStatus,
        grpcMessage: grpcMessage,
      );
    }

    final responseBytes = _asUint8List(response.data);
    final decoded = _parseGrpcWebResponse(responseBytes);
    final trailerStatus =
        int.tryParse(decoded.trailers['grpc-status'] ?? '') ?? 0;
    final trailerMessage = decoded.trailers['grpc-message'] ?? '';
    if (trailerStatus != 0) {
      throw _buildGrpcBadResponse(
        requestOptions: response.requestOptions,
        headers: response.headers,
        grpcStatus: trailerStatus,
        grpcMessage: trailerMessage,
      );
    }

    final user = _parseV2SignInUser(decoded.messageBytes);
    final token = _extractCookieValue(
      response.headers,
      _kAccessTokenCookieName,
    );
    if (token == null || token.isEmpty) {
      throw const FormatException('Access token missing in response');
    }
    return MemoPasswordSignInResult(
      user: user,
      endpoint: MemoPasswordSignInEndpoint.signinV2GrpcWeb,
      accessToken: token,
    );
  }

  static Future<MemoPasswordSignInResult> signInV1GrpcWeb({
    required Uri baseUrl,
    required String username,
    required String password,
  }) async {
    final dio = _newDio(
      baseUrl,
      headers: <String, Object?>{
        'Content-Type': _kGrpcWebContentType,
        'Accept': _kGrpcWebContentType,
        'X-Grpc-Web': '1',
        'X-User-Agent': 'grpc-web-dart',
        'grpc-accept-encoding': 'identity',
        'accept-encoding': 'identity',
      },
    );
    final requestMessage = _encodeGrpcWebPasswordSignInRequest(
      username: username,
      password: password,
      neverExpire: true,
    );
    final response = await dio.post(
      _kGrpcWebV1SignInPath,
      data: _wrapGrpcWebDataFrame(requestMessage),
      options: Options(responseType: ResponseType.bytes),
    );

    final grpcStatus = _readGrpcStatusCode(response.headers);
    final grpcMessage = _readGrpcStatusMessage(response.headers) ?? '';
    if (grpcStatus != null && grpcStatus != 0) {
      throw _buildGrpcBadResponse(
        requestOptions: response.requestOptions,
        headers: response.headers,
        grpcStatus: grpcStatus,
        grpcMessage: grpcMessage,
      );
    }

    final responseBytes = _asUint8List(response.data);
    final decoded = _parseGrpcWebResponse(responseBytes);
    final trailerStatus =
        int.tryParse(decoded.trailers['grpc-status'] ?? '') ?? 0;
    final trailerMessage = decoded.trailers['grpc-message'] ?? '';
    if (trailerStatus != 0) {
      throw _buildGrpcBadResponse(
        requestOptions: response.requestOptions,
        headers: response.headers,
        grpcStatus: trailerStatus,
        grpcMessage: trailerMessage,
      );
    }

    final user = _parseV1SignInUser(decoded.messageBytes);
    final token = _extractCookieValue(
      response.headers,
      _kAccessTokenCookieName,
    );
    if (token == null || token.isEmpty) {
      throw const FormatException('Access token missing in response');
    }
    return MemoPasswordSignInResult(
      user: user,
      endpoint: MemoPasswordSignInEndpoint.signinV1GrpcWeb,
      accessToken: token,
    );
  }
}

DioException _buildGrpcBadResponse({
  required RequestOptions requestOptions,
  required Headers headers,
  required int grpcStatus,
  required String grpcMessage,
}) {
  final synthetic = Response(
    requestOptions: requestOptions,
    statusCode: _grpcStatusToHttpStatus(grpcStatus),
    data: <String, Object?>{
      'message': grpcMessage.isNotEmpty
          ? grpcMessage
          : 'grpc status $grpcStatus',
      'grpcStatus': grpcStatus,
    },
    headers: headers,
  );
  return DioException.badResponse(
    statusCode: synthetic.statusCode ?? 500,
    requestOptions: requestOptions,
    response: synthetic,
  );
}

const String _kAccessTokenCookieName = 'memos.access-token';
const String _kSessionCookieName = 'user_session';
const String _kGrpcWebContentType = 'application/grpc-web+proto';
const String _kGrpcWebV1CreateSessionPath =
    '/memos.api.v1.AuthService/CreateSession';
const String _kGrpcWebV1SignInPath = '/memos.api.v1.AuthService/SignIn';
const String _kGrpcWebV2SignInPath = '/memos.api.v2.AuthService/SignIn';
const Duration _kLoginConnectTimeout = Duration(seconds: 20);
const Duration _kLoginReceiveTimeout = Duration(seconds: 30);

Dio _newDio(Uri baseUrl, {Map<String, Object?>? headers}) {
  return Dio(
    BaseOptions(
      baseUrl: dioBaseUrlString(baseUrl),
      connectTimeout: _kLoginConnectTimeout,
      receiveTimeout: _kLoginReceiveTimeout,
      headers: headers,
    ),
  );
}

String? _extractCookieValue(Headers headers, String name) {
  final values = <String>[
    ...?headers.map['set-cookie'],
    ...?headers.map['grpc-metadata-set-cookie'],
  ];
  if (values.isEmpty) return null;
  for (final entry in values) {
    final parts = entry.split(';');
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.startsWith('$name=')) {
        return trimmed.substring(name.length + 1).trim();
      }
    }
  }
  return null;
}

String? _extractAccessToken(Map<String, dynamic> body) {
  final raw = body['accessToken'] ?? body['access_token'] ?? body['token'];
  if (raw is String && raw.trim().isNotEmpty) return raw.trim();
  if (raw != null) return raw.toString().trim();
  return null;
}

Map<String, dynamic> _expectJsonMap(dynamic data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return data.cast<String, dynamic>();
  if (data is String) {
    final decoded = jsonDecode(data);
    if (decoded is Map<String, dynamic>) return decoded;
  }
  throw const FormatException('Expected JSON object');
}

Uint8List _encodeGrpcWebPasswordSignInRequest({
  required String username,
  required String password,
  required bool neverExpire,
}) {
  final buffer = BytesBuilder();
  _writeProtoStringField(buffer, 1, username);
  _writeProtoStringField(buffer, 2, password);
  _writeProtoBoolField(buffer, 3, neverExpire);
  return buffer.toBytes();
}

Uint8List _encodeGrpcWebPasswordCreateSessionRequest({
  required String username,
  required String password,
}) {
  final credentialsBuffer = BytesBuilder();
  _writeProtoStringField(credentialsBuffer, 1, username);
  _writeProtoStringField(credentialsBuffer, 2, password);
  final credentials = credentialsBuffer.toBytes();

  final buffer = BytesBuilder();
  _writeProtoTag(buffer, 1, 2);
  _writeProtoVarint(buffer, credentials.length);
  buffer.add(credentials);
  return buffer.toBytes();
}

void _writeProtoStringField(
  BytesBuilder buffer,
  int fieldNumber,
  String value,
) {
  final bytes = utf8.encode(value);
  _writeProtoTag(buffer, fieldNumber, 2);
  _writeProtoVarint(buffer, bytes.length);
  buffer.add(bytes);
}

void _writeProtoBoolField(BytesBuilder buffer, int fieldNumber, bool value) {
  _writeProtoTag(buffer, fieldNumber, 0);
  _writeProtoVarint(buffer, value ? 1 : 0);
}

void _writeProtoTag(BytesBuilder buffer, int fieldNumber, int wireType) {
  _writeProtoVarint(buffer, (fieldNumber << 3) | wireType);
}

void _writeProtoVarint(BytesBuilder buffer, int value) {
  var current = value;
  while (current >= 0x80) {
    buffer.addByte((current & 0x7F) | 0x80);
    current >>= 7;
  }
  buffer.addByte(current);
}

Uint8List _wrapGrpcWebDataFrame(Uint8List message) {
  final buffer = BytesBuilder();
  buffer.addByte(0x00);
  buffer.add(_uint32BigEndian(message.length));
  buffer.add(message);
  return buffer.toBytes();
}

Uint8List _uint32BigEndian(int value) {
  return Uint8List.fromList(<int>[
    (value >> 24) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  ]);
}

int? _readGrpcStatusCode(Headers headers) {
  final raw =
      _firstHeaderValue(headers, 'grpc-status') ??
      _firstHeaderValue(headers, 'Grpc-Status');
  if (raw == null) return null;
  return int.tryParse(raw.trim());
}

String? _readGrpcStatusMessage(Headers headers) {
  final raw =
      _firstHeaderValue(headers, 'grpc-message') ??
      _firstHeaderValue(headers, 'Grpc-Message');
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  return Uri.decodeComponent(trimmed);
}

String? _firstHeaderValue(Headers headers, String name) {
  final lowerName = name.toLowerCase();
  for (final entry in headers.map.entries) {
    if (entry.key.toLowerCase() != lowerName) continue;
    if (entry.value.isEmpty) return null;
    return entry.value.first;
  }
  return null;
}

int _grpcStatusToHttpStatus(int grpcStatus) {
  return switch (grpcStatus) {
    3 => 400,
    16 => 401,
    7 => 403,
    5 => 404,
    14 => 503,
    _ => 500,
  };
}

Uint8List _asUint8List(dynamic data) {
  if (data is Uint8List) return data;
  if (data is List<int>) return Uint8List.fromList(data);
  if (data is List) return Uint8List.fromList(data.cast<int>());
  throw const FormatException('Expected binary grpc-web response');
}

class _GrpcWebDecoded {
  const _GrpcWebDecoded({required this.messageBytes, required this.trailers});

  final Uint8List messageBytes;
  final Map<String, String> trailers;
}

_GrpcWebDecoded _parseGrpcWebResponse(Uint8List bytes) {
  final message = BytesBuilder();
  final trailers = <String, String>{};
  var offset = 0;
  while (offset + 5 <= bytes.length) {
    final flag = bytes[offset];
    final length =
        (bytes[offset + 1] << 24) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 8) |
        bytes[offset + 4];
    offset += 5;
    if (length < 0 || offset + length > bytes.length) {
      throw const FormatException('Invalid grpc-web frame length');
    }
    final frame = Uint8List.sublistView(bytes, offset, offset + length);
    offset += length;
    if ((flag & 0x80) != 0) {
      _parseGrpcWebTrailers(frame, trailers);
    } else {
      message.add(frame);
    }
  }
  return _GrpcWebDecoded(messageBytes: message.toBytes(), trailers: trailers);
}

void _parseGrpcWebTrailers(Uint8List frame, Map<String, String> trailers) {
  final text = utf8.decode(frame, allowMalformed: true);
  for (final line in text.split('\r\n')) {
    if (line.isEmpty) continue;
    final separator = line.indexOf(':');
    if (separator <= 0) continue;
    final key = line.substring(0, separator).trim().toLowerCase();
    final value = line.substring(separator + 1).trim();
    trailers[key] = value;
  }
}

User _parseV2SignInUser(Uint8List responseBytes) {
  final responseReader = _ProtoReader(responseBytes);
  Uint8List? userBytes;
  while (!responseReader.isAtEnd) {
    final tag = responseReader.readTag();
    final field = tag >> 3;
    final wireType = tag & 0x07;
    if (field == 1 && wireType == 2) {
      userBytes = responseReader.readBytes();
      break;
    }
    responseReader.skipField(wireType);
  }
  if (userBytes == null || userBytes.isEmpty) {
    throw const FormatException('Missing user in grpc-web SignIn response');
  }
  return _parseV2User(userBytes);
}

User _parseV1SignInUser(Uint8List responseBytes) {
  if (responseBytes.isEmpty) {
    throw const FormatException('Missing user in grpc-web SignIn response');
  }
  return _parseV2User(responseBytes);
}

User _parseV2User(Uint8List userBytes) {
  final reader = _ProtoReader(userBytes);
  String name = '';
  int? id;
  String username = '';
  String email = '';
  String nickname = '';
  String avatarUrl = '';
  String description = '';

  while (!reader.isAtEnd) {
    final tag = reader.readTag();
    final field = tag >> 3;
    final wireType = tag & 0x07;
    switch (field) {
      case 1:
        if (wireType == 2) {
          name = reader.readString();
        } else {
          reader.skipField(wireType);
        }
      case 2:
        if (wireType == 0) {
          id = reader.readVarint();
        } else {
          reader.skipField(wireType);
        }
      case 4:
        if (wireType == 2) {
          username = reader.readString();
        } else {
          reader.skipField(wireType);
        }
      case 5:
        if (wireType == 2) {
          email = reader.readString();
        } else {
          reader.skipField(wireType);
        }
      case 6:
        if (wireType == 2) {
          nickname = reader.readString();
        } else {
          reader.skipField(wireType);
        }
      case 7:
        if (wireType == 2) {
          avatarUrl = reader.readString();
        } else {
          reader.skipField(wireType);
        }
      case 8:
        if (wireType == 2) {
          description = reader.readString();
        } else {
          reader.skipField(wireType);
        }
      default:
        reader.skipField(wireType);
    }
  }

  return User.fromJson(<String, dynamic>{
    'name': name,
    if (id != null) 'id': id,
    'username': username,
    'email': email,
    'nickname': nickname,
    'avatarUrl': avatarUrl,
    'description': description,
  });
}

class _ProtoReader {
  _ProtoReader(this._bytes);

  final Uint8List _bytes;
  int _offset = 0;

  bool get isAtEnd => _offset >= _bytes.length;

  int readTag() => readVarint();

  int readVarint() {
    var shift = 0;
    var result = 0;
    while (_offset < _bytes.length) {
      final byte = _bytes[_offset++];
      result |= (byte & 0x7F) << shift;
      if ((byte & 0x80) == 0) return result;
      shift += 7;
      if (shift > 63) {
        throw const FormatException('Invalid varint');
      }
    }
    throw const FormatException('Unexpected EOF while reading varint');
  }

  Uint8List readBytes() {
    final length = readVarint();
    if (length < 0 || _offset + length > _bytes.length) {
      throw const FormatException('Invalid bytes length');
    }
    final value = Uint8List.sublistView(_bytes, _offset, _offset + length);
    _offset += length;
    return value;
  }

  String readString() => utf8.decode(readBytes(), allowMalformed: true);

  void skipField(int wireType) {
    switch (wireType) {
      case 0:
        readVarint();
      case 1:
        _skipBytes(8);
      case 2:
        _skipBytes(readVarint());
      case 5:
        _skipBytes(4);
      default:
        throw FormatException('Unsupported wire type: $wireType');
    }
  }

  void _skipBytes(int length) {
    if (length < 0 || _offset + length > _bytes.length) {
      throw const FormatException('Invalid skip length');
    }
    _offset += length;
  }
}
