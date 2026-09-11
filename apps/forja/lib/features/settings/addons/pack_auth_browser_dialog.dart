import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/features/settings/addons/pack_auth_session_handoff.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/shell/forja_toast.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Pack Connected Services `flow: "browser"` — system browser + deep-link handoff.
///
/// Opens [url] externally. User signs in on Shahid (or is already signed in),
/// pastes a one-shot bookmarklet that sends `token` via `forja://…`, then this
/// dialog completes with session fields for pack `auth_login`.
class PackAuthBrowserDialog extends StatefulWidget {
  const PackAuthBrowserDialog({
    super.key,
    required this.title,
    required this.url,
    this.hint = '',
    this.methods = const [],
  });

  final String title;
  final String url;
  final String hint;
  final List<Map<String, dynamic>> methods;

  @override
  State<PackAuthBrowserDialog> createState() => _PackAuthBrowserDialogState();
}

class _PackAuthBrowserDialogState extends State<PackAuthBrowserDialog> {
  late final String _state;
  late final String _consoleScript;
  final _cancel = Completer<void>();
  var _opened = false;
  var _waiting = true;
  var _showPassword = false;
  late String _methodId;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _state = PackAuthSessionHandoff.newState();
    _consoleScript = PackAuthSessionHandoff.consoleScript(_state);
    if (widget.methods.isNotEmpty) {
      _methodId = (widget.methods.first['id'] ?? 'email').toString();
      _ensureControllers();
    } else {
      _methodId = 'email';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_openBrowser());
      unawaited(_waitHandoff());
    });
  }

  @override
  void dispose() {
    if (!_cancel.isCompleted) _cancel.complete();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic>? get _method {
    if (widget.methods.isEmpty) return null;
    for (final m in widget.methods) {
      if ((m['id'] ?? '').toString() == _methodId) return m;
    }
    return widget.methods.first;
  }

  List<Map<String, dynamic>> get _fields {
    final raw = _method?['fields'];
    if (raw is! List) return const [];
    return [
      for (final f in raw)
        if (f is Map) Map<String, dynamic>.from(f),
    ];
  }

  void _ensureControllers() {
    for (final f in _fields) {
      final id = (f['id'] ?? '').toString();
      if (id.isEmpty) continue;
      _controllers.putIfAbsent(id, TextEditingController.new);
    }
  }

  Future<void> _openBrowser() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    setState(() => _opened = ok);
    if (!ok) ForjaToast.error('Could not open browser');
  }

  Future<void> _waitHandoff() async {
    try {
      final fields = await PackAuthSessionHandoff.waitForSession(
        state: _state,
        cancel: _cancel.future,
      );
      if (!mounted) return;
      Navigator.pop(context, (method: 'browser', fields: fields));
    } catch (e) {
      if (!mounted) return;
      if (e is StateError && e.message == 'cancelled') return;
      if (e is TimeoutException) {
        setState(() => _waiting = false);
        ForjaToast.error('Timed out waiting for Shahid session');
        return;
      }
      debugPrint('[PackAuthBrowser] handoff: $e');
    }
  }

  Future<void> _copyConnectScript() async {
    await Clipboard.setData(ClipboardData(text: _consoleScript));
    if (!mounted) return;
    ForjaToast.success(
      'Copied — on the Shahid tab open Console (⌘⌥J), paste, Enter',
    );
  }

  void _submitPassword() {
    final fields = <String, String>{};
    for (final f in _fields) {
      final id = (f['id'] ?? '').toString();
      if (id.isEmpty) continue;
      fields[id] = _controllers[id]?.text.trim() ?? '';
    }
    Navigator.pop(context, (method: _methodId, fields: fields));
  }

  @override
  Widget build(BuildContext context) {
    _ensureControllers();
    final methodChips = widget.methods.length > 1;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.hint.isNotEmpty
                  ? widget.hint
                  : 'Sign in on Shahid in your browser (already signed in is fine).',
              style: const TextStyle(
                fontSize: 13,
                color: ForjaShellColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _opened
                  ? '1. Shahid is open in your browser.'
                  : '1. Opening your browser…',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 6),
            const Text(
              '2. On that Shahid tab: open Console (⌘⌥J / Ctrl+Shift+J), paste, Enter.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              _waiting
                  ? '3. Waiting for session… then Forja shows Connected (you can close the Shahid tab).'
                  : '3. Waiting stopped — copy again or use password.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _copyConnectScript,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy connect script'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Open Shahid again',
                  onPressed: _openBrowser,
                  icon: const Icon(Icons.open_in_browser),
                ),
              ],
            ),
            if (_waiting) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(
                color: ForjaShellColors.brandGreen,
                backgroundColor: ForjaShellColors.borderSubtle,
              ),
            ],
            if (widget.methods.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _showPassword = !_showPassword),
                child: Text(
                  _showPassword
                      ? 'Hide email/password'
                      : 'Use email/password instead',
                ),
              ),
            ],
            if (_showPassword && widget.methods.isNotEmpty) ...[
              if (methodChips) ...[
                Wrap(
                  spacing: 8,
                  children: [
                    for (final m in widget.methods)
                      ChoiceChip(
                        label: Text((m['label'] ?? m['id'] ?? '').toString()),
                        selected: (m['id'] ?? '').toString() == _methodId,
                        onSelected: (_) {
                          setState(() {
                            _methodId = (m['id'] ?? '').toString();
                            _ensureControllers();
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              for (final f in _fields) ...[
                SettingsTextField(
                  controller: _controllers[(f['id'] ?? '').toString()]!,
                  label: (f['label'] ?? f['id'] ?? '').toString(),
                  obscureText:
                      (f['type'] ?? '').toString().toLowerCase() ==
                          'password' ||
                      (f['type'] ?? '').toString().toLowerCase() == 'secret',
                  keyboardType:
                      (f['type'] ?? '').toString().toLowerCase() == 'phone'
                      ? TextInputType.phone
                      : TextInputType.text,
                ),
                const SizedBox(height: 8),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _submitPassword,
                  child: const Text('Connect'),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
