import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:saf_util/saf_util.dart';

import '../../data/logs/log_manager.dart';

class LocalModeSetupResult {
  const LocalModeSetupResult({
    required this.name,
    required this.treeUri,
    required this.rootPath,
    required this.encryptionEnabled,
    required this.password,
  });

  final String name;
  final String? treeUri;
  final String? rootPath;
  final bool encryptionEnabled;
  final String? password;
}

class LocalModeSetupScreen extends StatefulWidget {
  const LocalModeSetupScreen({
    super.key,
    required this.title,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.initialName,
    this.subtitle,
  });

  final String title;
  final String confirmLabel;
  final String cancelLabel;
  final String initialName;
  final String? subtitle;

  static Future<LocalModeSetupResult?> show(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    required String cancelLabel,
    required String initialName,
    String? subtitle,
  }) {
    return Navigator.of(context).push<LocalModeSetupResult>(
      MaterialPageRoute<LocalModeSetupResult>(
        builder: (_) => LocalModeSetupScreen(
          title: title,
          confirmLabel: confirmLabel,
          cancelLabel: cancelLabel,
          initialName: initialName,
          subtitle: subtitle,
        ),
      ),
    );
  }

  @override
  State<LocalModeSetupScreen> createState() => _LocalModeSetupScreenState();
}

class _LocalModeSetupScreenState extends State<LocalModeSetupScreen> {
  late final TextEditingController _nameController;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  String? _treeUri;
  String? _rootPath;
  bool _encryptionEnabled = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _submitting = false;

  String _locationDebugKey(_PickedLocation? picked) {
    final treeUri = (picked?.treeUri ?? '').trim();
    final rootPath = (picked?.rootPath ?? '').trim();
    if (treeUri.isNotEmpty) return 'tree:$treeUri';
    if (rootPath.isNotEmpty) return 'path:$rootPath';
    return '';
  }

  void _logFlow(
    String message, {
    Map<String, Object?>? context,
    bool warn = false,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode) return;
    if (warn) {
      LogManager.instance.warn(
        'LocalModeSetup: $message',
        context: context,
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }
    LogManager.instance.info(
      'LocalModeSetup: $message',
      context: context,
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _logFlow('screen_opened');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    _logFlow(
      'pick_location_start',
      context: {'platform': Platform.operatingSystem},
    );
    try {
      final picked = await _pickLocalLibraryLocation();
      _logFlow(
        'pick_location_result',
        context: <String, Object?>{
          'picked': picked != null,
          'hasTreeUri': (picked?.treeUri ?? '').trim().isNotEmpty,
          'hasRootPath': (picked?.rootPath ?? '').trim().isNotEmpty,
          'locationKey': _locationDebugKey(picked),
        },
      );
      if (picked == null || !mounted) return;
      setState(() {
        _treeUri = picked.treeUri;
        _rootPath = picked.rootPath;
        if (_nameController.text.trim().isEmpty) {
          _nameController.text = picked.defaultName;
        }
      });
    } catch (error, stackTrace) {
      _logFlow(
        'pick_location_failed',
        warn: true,
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      _showMessage('Failed to select folder. Please try again.');
    }
  }

  Future<_PickedLocation?> _pickLocalLibraryLocation() async {
    if (Platform.isAndroid) {
      final doc = await SafUtil().pickDirectory(
        writePermission: true,
        persistablePermission: true,
      );
      if (doc == null) return null;
      final name = doc.name.trim().isEmpty ? '本地仓库' : doc.name.trim();
      return _PickedLocation(
        treeUri: doc.uri,
        rootPath: null,
        defaultName: name,
      );
    }

    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null || path.trim().isEmpty) return null;
    final trimmed = path.trim();
    final name = p.basename(trimmed);
    return _PickedLocation(
      treeUri: null,
      rootPath: trimmed,
      defaultName: name.isEmpty ? '本地仓库' : name,
    );
  }

  String _locationLabel() {
    final rootPath = (_rootPath ?? '').trim();
    if (rootPath.isNotEmpty) return rootPath;
    final treeUri = (_treeUri ?? '').trim();
    if (treeUri.isNotEmpty) return treeUri;
    return '未选择';
  }

  bool _hasLocation() {
    return (_treeUri ?? '').trim().isNotEmpty ||
        (_rootPath ?? '').trim().isNotEmpty;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final name = _nameController.text.trim();
    _logFlow(
      'submit_start',
      context: <String, Object?>{
        'hasLocation': _hasLocation(),
        'nameLength': name.length,
        'encryptionEnabled': _encryptionEnabled,
        'hasTreeUri': (_treeUri ?? '').trim().isNotEmpty,
        'hasRootPath': (_rootPath ?? '').trim().isNotEmpty,
      },
    );
    if (!_hasLocation()) {
      _logFlow('submit_blocked_missing_location', warn: true);
      _showMessage('请选择文件保存位置。');
      return;
    }
    if (name.isEmpty) {
      _logFlow('submit_blocked_empty_name', warn: true);
      _showMessage('请输入仓库名称。');
      return;
    }

    String? password;
    if (_encryptionEnabled) {
      final pwd = _passwordController.text;
      final confirm = _confirmPasswordController.text;
      if (pwd.isEmpty || confirm.isEmpty) {
        _logFlow('submit_blocked_empty_password', warn: true);
        _showMessage('请输入并确认密码。');
        return;
      }
      if (pwd != confirm) {
        _logFlow('submit_blocked_password_mismatch', warn: true);
        _showMessage('两次输入的密码不一致。');
        return;
      }
      password = pwd;
    }

    setState(() => _submitting = true);
    _logFlow(
      'submit_success_pop',
      context: <String, Object?>{
        'nameLength': name.length,
        'hasTreeUri': (_treeUri ?? '').trim().isNotEmpty,
        'hasRootPath': (_rootPath ?? '').trim().isNotEmpty,
      },
    );
    Navigator.of(context).pop(
      LocalModeSetupResult(
        name: name,
        treeUri: (_treeUri ?? '').trim().isEmpty ? null : _treeUri!.trim(),
        rootPath: (_rootPath ?? '').trim().isEmpty ? null : _rootPath!.trim(),
        encryptionEnabled: _encryptionEnabled,
        password: password,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          if ((widget.subtitle ?? '').trim().isNotEmpty) ...[
            Text(
              widget.subtitle!.trim(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '文件保存位置',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _locationLabel(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _pickLocation,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('选择位置'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '仓库名称',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(hintText: '请输入仓库名称'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('加密保存（占位）'),
                    subtitle: const Text('密码功能当前仅占位，暂未真正生效。'),
                    value: _encryptionEnabled,
                    onChanged: (value) {
                      setState(() => _encryptionEnabled = value);
                    },
                  ),
                  if (_encryptionEnabled) ...[
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: '设置密码',
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: '确认密码',
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.confirmLabel),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _submitting
                ? null
                : () => Navigator.of(context).maybePop(),
            child: Text(widget.cancelLabel),
          ),
        ],
      ),
    );
  }
}

class _PickedLocation {
  const _PickedLocation({
    required this.treeUri,
    required this.rootPath,
    required this.defaultName,
  });

  final String? treeUri;
  final String? rootPath;
  final String defaultName;
}
