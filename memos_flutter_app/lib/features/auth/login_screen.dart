import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/url.dart';
import '../../state/login_draft_provider.dart';
import '../../state/session_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.initialError});

  final String? initialError;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _baseUrlController = TextEditingController();
  final _tokenController = TextEditingController();
  var _shownInitialError = false;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(loginBaseUrlDraftProvider).trim();
    if (draft.isNotEmpty) {
      _baseUrlController.text = draft;
    }
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final baseUrlRaw = _baseUrlController.text.trim();
    final token = _tokenController.text.trim();
    final baseUrl = Uri.tryParse(baseUrlRaw);
    if (baseUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('服务器地址不合法')));
      return;
    }

    final sanitizedBaseUrl = sanitizeUserBaseUrl(baseUrl);
    if (sanitizedBaseUrl.toString() != baseUrl.toString()) {
      _baseUrlController.text = sanitizedBaseUrl.toString();
      ref.read(loginBaseUrlDraftProvider.notifier).state = _baseUrlController.text;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已自动修正服务器地址（移除多余路径）')),
      );
    }

    await ref.read(appSessionProvider.notifier).addAccountWithPat(
          baseUrl: sanitizedBaseUrl,
          personalAccessToken: token,
        );

    final sessionAsync = ref.read(appSessionProvider);
    if (sessionAsync.hasError) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('连接失败：${sessionAsync.error}')),
      );
      return;
    }

    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(appSessionProvider);
    final isBusy = sessionAsync.isLoading;

    if (!_shownInitialError) {
      _shownInitialError = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final error = widget.initialError;
        if (error != null && error.isNotEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
        }
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('连接 Memos')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 8),
            Text(
              '使用 Personal Access Token 登录（推荐给移动端）。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _baseUrlController,
                    enabled: !isBusy,
                    decoration: const InputDecoration(
                      labelText: '服务器地址',
                      hintText: 'http://192.168.1.10:5230',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                    onChanged: (v) => ref.read(loginBaseUrlDraftProvider.notifier).state = v,
                    validator: (v) {
                      final raw = (v ?? '').trim();
                      if (raw.isEmpty) return '请输入服务器地址';
                      final uri = Uri.tryParse(raw);
                      if (uri == null || !(uri.hasScheme && uri.hasAuthority)) {
                        return '请输入完整地址（含 http/https 和端口）';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _tokenController,
                    enabled: !isBusy,
                    decoration: const InputDecoration(
                      labelText: 'Token (PAT)',
                      hintText: 'memos_pat_...',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (v) {
                      if ((v ?? '').trim().isEmpty) return '请输入 Token';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: isBusy ? null : _connect,
                      icon: isBusy
                          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.link),
                      label: Text(isBusy ? '连接中…' : '连接'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
