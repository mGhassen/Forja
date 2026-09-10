import 'package:flutter/material.dart';
import 'package:forja/shared/foundation/primitives/primitives.dart';
import 'package:url_launcher/url_launcher.dart';

/// Pack Connected Services `flow: "browser"` — opens the system browser only.
/// Optional [methods] let the user finish with a password after signing up via
/// Google on the website (Shahid does not hand a session back from Chrome).
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
  late String _methodId;
  final Map<String, TextEditingController> _controllers = {};
  var _opened = false;

  @override
  void initState() {
    super.initState();
    if (widget.methods.isNotEmpty) {
      _methodId = (widget.methods.first['id'] ?? 'email').toString();
      _ensureControllers();
    } else {
      _methodId = 'email';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _openBrowser());
  }

  @override
  void dispose() {
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
    if (!ok) {
      ForjaToast.error('Could not open browser');
    }
  }

  void _submit() {
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
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.hint.isNotEmpty
                  ? widget.hint
                  : 'Sign in in your browser, then finish below.',
              style: const TextStyle(
                fontSize: 13,
                color: ForjaShellColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _opened
                  ? 'Shahid opened in your browser.'
                  : 'Opening your browser…',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _openBrowser,
                icon: const Icon(Icons.open_in_browser, size: 18),
                label: const Text('Open Shahid again'),
              ),
            ),
            if (widget.methods.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Then connect in Forja with email/phone + password '
                '(Google-only accounts: use Forgot password on Shahid first).',
                style: TextStyle(
                  fontSize: 12,
                  color: ForjaShellColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
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
                const SizedBox(height: 12),
              ],
              for (final f in _fields) ...[
                TextField(
                  controller: _controllers[(f['id'] ?? '').toString()],
                  obscureText:
                      (f['type'] ?? '').toString().toLowerCase() ==
                          'password' ||
                      (f['type'] ?? '').toString().toLowerCase() == 'secret',
                  keyboardType:
                      (f['type'] ?? '').toString().toLowerCase() == 'phone'
                      ? TextInputType.phone
                      : TextInputType.text,
                  decoration: InputDecoration(
                    labelText: (f['label'] ?? f['id'] ?? '').toString(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (widget.methods.isNotEmpty)
          FilledButton(onPressed: _submit, child: const Text('Connect')),
      ],
    );
  }
}
