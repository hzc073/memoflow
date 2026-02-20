import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:multicast_dns/multicast_dns.dart';

import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../data/models/memoflow_bridge_settings.dart';
import '../../state/memoflow_bridge_settings_provider.dart';
import '../../state/preferences_provider.dart';
import '../../i18n/strings.g.dart';

bool _supportsBridgeQrScannerOnCurrentPlatform() {
  return Platform.isAndroid || Platform.isIOS;
}

void _showBridgeQrUnsupportedSnack(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'QR scan is not supported on this platform. Please pair manually with Host, Port, and Pair Code.',
      ),
    ),
  );
}

Future<void> startMemoFlowQuickQrPair({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  if (!_supportsBridgeQrScannerOnCurrentPlatform()) {
    _showBridgeQrUnsupportedSnack(context);
    return;
  }
  final tr = context.t.strings.legacy;
  final raw = await Navigator.of(context, rootNavigator: true).push<String>(
    MaterialPageRoute<String>(builder: (_) => const MemoFlowPairQrScanScreen()),
  );
  if (raw == null || raw.trim().isEmpty) return;

  final payload = _PairingPayload.tryParse(raw);
  if (payload == null) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(tr.msg_bridge_qr_invalid)));
    return;
  }

  final deviceName = await _resolveMemoFlowDeviceName();
  try {
    final dio = Dio(
      BaseOptions(
        baseUrl: 'http://${payload.host}:${payload.port}',
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 12),
        sendTimeout: const Duration(seconds: 12),
      ),
    );
    final response = await dio.post(
      '/bridge/v1/pair/confirm',
      data: <String, dynamic>{
        'pairCode': payload.pairCode,
        'deviceName': deviceName,
      },
    );
    final data = _expectMap(response.data);
    final token = _readString(data, 'token');
    if (token.isEmpty) {
      throw FormatException(tr.msg_bridge_pair_response_missing_token);
    }

    final serverName = _readString(data, 'serverName').isNotEmpty
        ? _readString(data, 'serverName')
        : payload.serverName;
    final apiVersion = _readString(data, 'apiVersion').isNotEmpty
        ? _readString(data, 'apiVersion')
        : payload.apiVersion;

    ref
        .read(memoFlowBridgeSettingsProvider.notifier)
        .savePairing(
          host: payload.host,
          port: payload.port,
          token: token,
          serverName: serverName,
          deviceName: deviceName,
          apiVersion: apiVersion,
        );
    if (!context.mounted) return;
    showTopToast(context, tr.msg_bridge_pair_success);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(tr.msg_bridge_pair_failed(e: e))));
  }
}

Future<String> _resolveMemoFlowDeviceName() async {
  try {
    final plugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      final brand = info.brand.trim();
      final model = info.model.trim();
      final next = [brand, model].where((it) => it.isNotEmpty).join(' ');
      if (next.isNotEmpty) return next;
    }
    if (Platform.isIOS) {
      final info = await plugin.iosInfo;
      final model = info.utsname.machine.trim();
      if (model.isNotEmpty) return model;
    }
  } catch (_) {}
  return 'MemoFlow Mobile';
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

String _readString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is String) return value.trim();
  return '';
}

class MemoFlowBridgeScreen extends ConsumerStatefulWidget {
  const MemoFlowBridgeScreen({super.key});

  @override
  ConsumerState<MemoFlowBridgeScreen> createState() =>
      _MemoFlowBridgeScreenState();
}

class _MemoFlowBridgeScreenState extends ConsumerState<MemoFlowBridgeScreen> {
  static const _serviceName = '_memoflow._tcp.local';

  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '3000');
  final _pairCodeController = TextEditingController();

  bool _pairing = false;
  bool _discovering = false;
  bool _checkingHealth = false;
  String _deviceName = 'MemoFlow Mobile';
  String? _statusMessage;
  List<_DiscoveredServer> _servers = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settings = ref.read(memoFlowBridgeSettingsProvider);
      _hostController.text = settings.host;
      _portController.text = settings.port.toString();
      unawaited(_resolveDeviceName());
    });
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _pairCodeController.dispose();
    super.dispose();
  }

  Future<void> _resolveDeviceName() async {
    final next = await _resolveMemoFlowDeviceName();
    if (!mounted) return;
    setState(() => _deviceName = next);
  }

  Future<void> _discoverServers() async {
    if (_discovering) return;
    FocusScope.of(context).unfocus();
    final tr = context.t.strings.legacy;
    setState(() {
      _discovering = true;
      _statusMessage = tr.msg_bridge_mdns_searching;
    });

    final client = MDnsClient();
    final found = <String, _DiscoveredServer>{};
    try {
      await client.start();
      final ptrStream = client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer(_serviceName),
      );
      await for (final ptr in ptrStream.timeout(
        const Duration(seconds: 4),
        onTimeout: (sink) => sink.close(),
      )) {
        final srv = await _firstRecord<SrvResourceRecord>(
          client.lookup<SrvResourceRecord>(
            ResourceRecordQuery.service(ptr.domainName),
          ),
        );
        if (srv == null) continue;

        final addressRecord = await _firstRecord<IPAddressResourceRecord>(
          client.lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(srv.target),
          ),
        );
        if (addressRecord == null) continue;
        final host = addressRecord.address.address.trim();
        if (host.isEmpty) continue;

        found['$host:${srv.port}'] = _DiscoveredServer(
          host: host,
          port: srv.port,
          serviceDomain: ptr.domainName,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = tr.msg_bridge_mdns_failed(e: e);
      });
    } finally {
      client.stop();
    }

    if (!mounted) return;
    final next = found.values.toList()
      ..sort((a, b) {
        final aKey = '${a.host}:${a.port}';
        final bKey = '${b.host}:${b.port}';
        return aKey.compareTo(bKey);
      });
    setState(() {
      _discovering = false;
      _servers = next;
      _statusMessage = next.isEmpty
          ? tr.msg_bridge_mdns_not_found
          : tr.msg_bridge_mdns_found_count(count: next.length);
    });
  }

  Future<T?> _firstRecord<T>(Stream<T> stream) async {
    try {
      return await stream
          .timeout(
            const Duration(seconds: 2),
            onTimeout: (sink) => sink.close(),
          )
          .first;
    } catch (_) {
      return null;
    }
  }

  Future<void> _scanQrAndPair() async {
    FocusScope.of(context).unfocus();
    if (!_supportsBridgeQrScannerOnCurrentPlatform()) {
      _showBridgeQrUnsupportedSnack(context);
      return;
    }
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => const MemoFlowPairQrScanScreen(),
      ),
    );
    if (!mounted || raw == null || raw.trim().isEmpty) return;

    final payload = _PairingPayload.tryParse(raw);
    final tr = context.t.strings.legacy;
    if (payload == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr.msg_bridge_qr_invalid)));
      return;
    }

    _hostController.text = payload.host;
    _portController.text = payload.port.toString();
    _pairCodeController.text = payload.pairCode;
    await _pairWithBridge(
      host: payload.host,
      port: payload.port,
      pairCode: payload.pairCode,
      serverName: payload.serverName,
      apiVersion: payload.apiVersion,
    );
  }

  Future<void> _pairFromForm() async {
    FocusScope.of(context).unfocus();
    final tr = context.t.strings.legacy;
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim());
    final pairCode = _pairCodeController.text.trim();

    if (host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr.msg_bridge_input_host_required)),
      );
      return;
    }
    if (port == null || port <= 0 || port > 65535) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr.msg_bridge_input_port_invalid)));
      return;
    }
    if (pairCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr.msg_bridge_input_pair_code_required)),
      );
      return;
    }

    await _pairWithBridge(
      host: host,
      port: port,
      pairCode: pairCode,
      serverName: '',
      apiVersion: 'bridge-v1',
    );
  }

  Future<void> _pairWithBridge({
    required String host,
    required int port,
    required String pairCode,
    required String serverName,
    required String apiVersion,
  }) async {
    if (_pairing) return;
    final tr = context.t.strings.legacy;
    setState(() {
      _pairing = true;
      _statusMessage = tr.msg_bridge_status_pairing;
    });

    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: 'http://$host:$port',
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 12),
          sendTimeout: const Duration(seconds: 12),
        ),
      );

      final response = await dio.post(
        '/bridge/v1/pair/confirm',
        data: <String, dynamic>{
          'pairCode': pairCode,
          'deviceName': _deviceName,
        },
      );
      final payload = _expectMap(response.data);
      final token = _readString(payload, 'token');
      if (token.isEmpty) {
        throw FormatException(tr.msg_bridge_pair_response_missing_token);
      }
      final normalizedServerName = _readString(payload, 'serverName').isNotEmpty
          ? _readString(payload, 'serverName')
          : serverName;
      final normalizedApiVersion = _readString(payload, 'apiVersion').isNotEmpty
          ? _readString(payload, 'apiVersion')
          : apiVersion;

      ref
          .read(memoFlowBridgeSettingsProvider.notifier)
          .savePairing(
            host: host,
            port: port,
            token: token,
            serverName: normalizedServerName,
            deviceName: _deviceName,
            apiVersion: normalizedApiVersion,
          );

      if (!mounted) return;
      setState(() {
        _statusMessage = tr.msg_bridge_paired_target(target: '$host:$port');
      });
      showTopToast(context, tr.msg_bridge_pair_success);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = tr.msg_bridge_pair_failed(e: e);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr.msg_bridge_pair_failed(e: e))));
    } finally {
      if (mounted) {
        setState(() => _pairing = false);
      }
    }
  }

  Future<void> _checkHealth(MemoFlowBridgeSettings settings) async {
    if (_checkingHealth) return;
    final tr = context.t.strings.legacy;
    if (!settings.isPaired) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr.msg_bridge_need_pair_first)));
      return;
    }

    setState(() {
      _checkingHealth = true;
      _statusMessage = tr.msg_bridge_status_health_checking;
    });

    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: 'http://${settings.host}:${settings.port}',
          connectTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      await dio.get(
        '/bridge/v1/health',
        options: Options(
          headers: <String, String>{
            'Authorization': 'Bearer ${settings.token}',
          },
        ),
      );

      if (!mounted) return;
      setState(() {
        _statusMessage = tr.msg_bridge_status_health_ok;
      });
      showTopToast(context, tr.msg_bridge_status_health_ok);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = tr.msg_bridge_status_health_failed(e: e);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr.msg_bridge_status_health_failed(e: e))),
      );
    } finally {
      if (mounted) {
        setState(() => _checkingHealth = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.t.strings.legacy;
    final settings = ref.watch(memoFlowBridgeSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final divider = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final hapticsEnabled = ref.watch(
      appPreferencesProvider.select((p) => p.hapticsEnabled),
    );

    void haptic() {
      if (hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: tr.msg_back,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(tr.msg_bridge_title),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          if (isDark)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [const Color(0xFF0B0B0B), bg, bg],
                  ),
                ),
              ),
            ),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            children: [
              _SectionCard(
                card: card,
                border: divider,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr.msg_bridge_local_mode_only,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      settings.isPaired
                          ? tr.msg_bridge_paired_target(
                              target: '${settings.host}:${settings.port}',
                            )
                          : tr.msg_bridge_unpaired,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textMain,
                      ),
                    ),
                    if (settings.serverName.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        tr.msg_bridge_server(server: settings.serverName),
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      tr.msg_bridge_device(device: _deviceName),
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                    if (_statusMessage != null &&
                        _statusMessage!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _statusMessage!,
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _pairing ? null : _scanQrAndPair,
                            icon: const Icon(Icons.qr_code_scanner),
                            label: Text(
                              _pairing
                                  ? tr.msg_bridge_processing
                                  : tr.msg_bridge_action_scan_pair,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _discovering ? null : _discoverServers,
                            icon: const Icon(Icons.wifi_tethering),
                            label: Text(
                              _discovering
                                  ? tr.msg_bridge_action_searching
                                  : tr.msg_bridge_action_mdns_discover,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                card: card,
                border: divider,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _hostController,
                      decoration: const InputDecoration(
                        labelText: 'Host',
                        hintText: '192.168.1.10',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _portController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Port',
                        hintText: '3000',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _pairCodeController,
                      decoration: InputDecoration(
                        labelText: tr.msg_bridge_pair_code_label,
                        hintText: tr.msg_bridge_pair_code_hint,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: _pairing
                                ? null
                                : () {
                                    haptic();
                                    unawaited(_pairFromForm());
                                  },
                            child: Text(
                              _pairing
                                  ? tr.msg_bridge_action_pairing
                                  : tr.msg_bridge_action_confirm_pair,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _checkingHealth
                                ? null
                                : () {
                                    haptic();
                                    unawaited(_checkHealth(settings));
                                  },
                            child: Text(
                              _checkingHealth
                                  ? tr.msg_bridge_action_checking
                                  : tr.msg_bridge_action_health_check,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(tr.msg_bridge_enable),
                      value: settings.enabled,
                      onChanged: (value) {
                        haptic();
                        ref
                            .read(memoFlowBridgeSettingsProvider.notifier)
                            .setEnabled(value);
                      },
                    ),
                    if (settings.isPaired)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            haptic();
                            ref
                                .read(memoFlowBridgeSettingsProvider.notifier)
                                .clearPairing();
                            _pairCodeController.clear();
                            showTopToast(context, tr.msg_bridge_pair_cleared);
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: Text(tr.msg_bridge_clear_pair),
                        ),
                      ),
                  ],
                ),
              ),
              if (_servers.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SectionCard(
                  card: card,
                  border: divider,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr.msg_bridge_discovery_results,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (var i = 0; i < _servers.length; i++) ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${_servers[i].host}:${_servers[i].port}',
                            style: TextStyle(
                              color: textMain,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            _servers[i].serviceDomain,
                            style: TextStyle(color: textMuted, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            haptic();
                            _hostController.text = _servers[i].host;
                            _portController.text = _servers[i].port.toString();
                          },
                        ),
                        if (i != _servers.length - 1)
                          Divider(height: 1, color: divider),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.card,
    required this.border,
    required this.child,
  });

  final Color card;
  final Color border;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: isDark
            ? [
                BoxShadow(
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                  color: Colors.black.withValues(alpha: 0.35),
                ),
              ]
            : [
                BoxShadow(
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  color: Colors.black.withValues(alpha: 0.06),
                ),
              ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: child,
    );
  }
}

class MemoFlowPairQrScanScreen extends StatefulWidget {
  const MemoFlowPairQrScanScreen({super.key});

  @override
  State<MemoFlowPairQrScanScreen> createState() =>
      _MemoFlowPairQrScanScreenState();
}

class _MemoFlowPairQrScanScreenState extends State<MemoFlowPairQrScanScreen> {
  MobileScannerController? _controller;
  bool _handled = false;
  bool get _supportsScanner => _supportsBridgeQrScannerOnCurrentPlatform();

  @override
  void initState() {
    super.initState();
    if (_supportsScanner) {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final controller = _controller;
    if (_handled || controller == null) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim() ?? '';
      if (raw.isEmpty) continue;
      _handled = true;
      await controller.stop();
      if (!mounted) return;
      Navigator.of(context).pop(raw);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.t.strings.legacy;
    if (!_supportsScanner) {
      return Scaffold(
        appBar: AppBar(title: Text(tr.msg_bridge_scan_title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.qr_code_scanner, size: 40),
                const SizedBox(height: 12),
                const Text(
                  'QR scan is not supported on this platform.\nUse manual pairing instead.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr.msg_bridge_scan_title)),
      body: Stack(
        children: [
          MobileScanner(controller: _controller!, onDetect: _onDetect),
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                tr.msg_bridge_scan_hint,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PairingPayload {
  static const _defaultPort = 3000;

  const _PairingPayload({
    required this.host,
    required this.port,
    required this.pairCode,
    required this.serverName,
    required this.apiVersion,
  });

  final String host;
  final int port;
  final String pairCode;
  final String serverName;
  final String apiVersion;

  static _PairingPayload? tryParse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('{')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          final map = decoded.cast<String, dynamic>();
          final host = _readString(map, 'host');
          final pairCode = _readString(map, 'pairCode');
          final port = _readPort(
            _readString(map, 'port'),
            fallback: _defaultPort,
          );
          if (host.isEmpty || pairCode.isEmpty) return null;
          return _PairingPayload(
            host: host,
            port: port,
            pairCode: pairCode,
            serverName: _readString(map, 'name'),
            apiVersion: _readString(map, 'api').isEmpty
                ? 'bridge-v1'
                : _readString(map, 'api'),
          );
        }
      } catch (_) {
        return null;
      }
      return null;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    final scheme = uri.scheme.toLowerCase();
    final query = uri.queryParameters;

    if (scheme == 'memoflow') {
      final host = (query['host'] ?? '').trim();
      final pairCode = (query['pairCode'] ?? query['code'] ?? '').trim();
      if (host.isEmpty || pairCode.isEmpty) return null;
      return _PairingPayload(
        host: host,
        port: _readPort(query['port'] ?? '', fallback: _defaultPort),
        pairCode: pairCode,
        serverName: (query['name'] ?? '').trim(),
        apiVersion: (query['api'] ?? 'bridge-v1').trim(),
      );
    }

    if (scheme == 'http' || scheme == 'https') {
      final host = uri.host.trim();
      final pairCode = (query['pairCode'] ?? query['code'] ?? '').trim();
      if (host.isEmpty || pairCode.isEmpty) return null;
      return _PairingPayload(
        host: host,
        port: uri.hasPort ? uri.port : _defaultPort,
        pairCode: pairCode,
        serverName: (query['name'] ?? '').trim(),
        apiVersion: (query['api'] ?? 'bridge-v1').trim(),
      );
    }

    return null;
  }

  static int _readPort(String raw, {required int fallback}) {
    final parsed = int.tryParse(raw.trim());
    if (parsed == null || parsed <= 0 || parsed > 65535) return fallback;
    return parsed;
  }
}

class _DiscoveredServer {
  const _DiscoveredServer({
    required this.host,
    required this.port,
    required this.serviceDomain,
  });

  final String host;
  final int port;
  final String serviceDomain;
}
