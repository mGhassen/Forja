import 'package:flutter/material.dart';
import 'package:forja/features/settings/addons/pack_auth_browser_dialog.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';

import 'package:forja/shared/host/packs/services/pack_connected_auth_service.dart';
import 'package:forja/shared/host/packs/services/pack_connected_auth_spec.dart';
import 'package:forja/shared/shell/forja_toast.dart';
import 'package:forja/shared/shell/forja_shell_layout.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
/// Generic Connected Services rows for packs that declare `settings.auth`
/// (RFC-102). No pack-id hardcoding — Simkl stays a separate host panel.
class PackConnectedAuthSection extends StatefulWidget {
  const PackConnectedAuthSection({super.key});

  @override
  State<PackConnectedAuthSection> createState() =>
      _PackConnectedAuthSectionState();
}

class _PackConnectedAuthSectionState extends State<PackConnectedAuthSection> {
  List<PackConnectedAuthSpec> _specs = const [];
  final Map<String, ({bool connected, String? label})> _status = {};
  final Set<String> _busy = {};
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final specs = await PackConnectedAuthService.listEnabled();
    final status = <String, ({bool connected, String? label})>{};
    for (final s in specs) {
      status[s.pluginId] = await PackConnectedAuthService.status(s);
    }
    if (!mounted) return;
    setState(() {
      _specs = specs;
      _status
        ..clear()
        ..addAll(status);
      _loading = false;
    });
  }

  Future<void> _login(PackConnectedAuthSpec spec) async {
    setState(() => _busy.add(spec.pluginId));
    try {
      final begin = await PackConnectedAuthService.begin(spec);
      if (!mounted) return;
      final flow = (begin?['flow'] ?? 'form').toString();
      if (flow == 'pin') {
        ForjaToast.error(
          'PIN login for ${spec.label} is not available in this build',
        );
        return;
      }
      final methods = _methodsFromBegin(begin);
      // TV cannot paste a browser console script — prefer pack form methods.
      if (flow == 'browser' && !(isTvProfile(context) && methods.isNotEmpty)) {
        await _loginBrowser(spec, begin ?? const {});
        return;
      }
      if (methods.isEmpty) {
        ForjaToast.error('No login methods from ${spec.label}');
        return;
      }
      final submitted =
          await showDialog<({String method, Map<String, String> fields})>(
            context: context,
            builder: (ctx) =>
                _PackAuthLoginDialog(title: spec.label, methods: methods),
          );
      if (submitted == null || !mounted) return;
      await PackConnectedAuthService.login(
        spec,
        method: submitted.method,
        fields: submitted.fields,
      );
      if (!mounted) return;
      ForjaToast.success('Connected to ${spec.label}');
      await _reload();
    } catch (e) {
      if (mounted) {
        ForjaToast.error('$e'.replaceFirst(RegExp(r'^Exception:\s*'), ''));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(spec.pluginId));
    }
  }

  List<Map<String, dynamic>> _methodsFromBegin(Map<String, dynamic>? begin) {
    final methodsRaw = begin?['methods'];
    if (methodsRaw is! List) return const [];
    return [
      for (final m in methodsRaw)
        if (m is Map) Map<String, dynamic>.from(m),
    ];
  }

  Future<void> _loginBrowser(
    PackConnectedAuthSpec spec,
    Map<String, dynamic> begin,
  ) async {
    final url = (begin['url'] ?? '').toString().trim();
    if (url.isEmpty) {
      ForjaToast.error('No login URL from ${spec.label}');
      return;
    }
    final methodsRaw = begin['methods'];
    final methods = <Map<String, dynamic>>[
      if (methodsRaw is List)
        for (final m in methodsRaw)
          if (m is Map) Map<String, dynamic>.from(m),
    ];
    final submitted =
        await showDialog<({String method, Map<String, String> fields})>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => PackAuthBrowserDialog(
            title: (begin['title'] ?? 'Sign in to ${spec.label}').toString(),
            url: url,
            hint: (begin['hint'] ?? '').toString(),
            methods: methods,
          ),
        );
    if (submitted == null || !mounted) return;
    await PackConnectedAuthService.login(
      spec,
      method: submitted.method,
      fields: submitted.fields,
    );
    if (!mounted) return;
    ForjaToast.success('Connected to ${spec.label}');
    await _reload();
  }

  Future<void> _logout(PackConnectedAuthSpec spec) async {
    setState(() => _busy.add(spec.pluginId));
    try {
      await PackConnectedAuthService.logout(spec);
      if (!mounted) return;
      ForjaToast.success('Signed out of ${spec.label}');
      await _reload();
    } catch (e) {
      if (mounted) {
        ForjaToast.error('$e'.replaceFirst(RegExp(r'^Exception:\s*'), ''));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(spec.pluginId));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _specs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final spec in _specs) ...[
          SettingsGroup(
            label: spec.label,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (spec.subtitle.isNotEmpty) ...[
                      Text(
                        spec.subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: ForjaShellColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_status[spec.pluginId]?.connected == true) ...[
                      SettingsStatusRow(
                        title: () {
                          final who = _status[spec.pluginId]?.label?.trim();
                          if (who != null && who.isNotEmpty) {
                            return 'Connected as $who';
                          }
                          return 'Connected';
                        }(),
                        subtitle: spec.label,
                      ),
                      const SizedBox(height: 10),
                      SettingsFilledButton(
                        label: 'Logout from ${spec.label}',
                        icon: Icons.logout,
                        secondary: true,
                        busy: _busy.contains(spec.pluginId),
                        onPressed: _busy.contains(spec.pluginId)
                            ? null
                            : () => _logout(spec),
                      ),
                    ] else
                      SettingsFilledButton(
                        label: 'Login with ${spec.label}',
                        icon: Icons.login,
                        busy: _busy.contains(spec.pluginId),
                        onPressed: _busy.contains(spec.pluginId)
                            ? null
                            : () => _login(spec),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PackAuthLoginDialog extends StatefulWidget {
  const _PackAuthLoginDialog({required this.title, required this.methods});

  final String title;
  final List<Map<String, dynamic>> methods;

  @override
  State<_PackAuthLoginDialog> createState() => _PackAuthLoginDialogState();
}

class _PackAuthLoginDialogState extends State<_PackAuthLoginDialog> {
  late String _methodId;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _methodId = (widget.methods.first['id'] ?? 'email').toString();
    _ensureControllers();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> get _method {
    for (final m in widget.methods) {
      if ((m['id'] ?? '').toString() == _methodId) return m;
    }
    return widget.methods.first;
  }

  List<Map<String, dynamic>> get _fields {
    final raw = _method['fields'];
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

  @override
  Widget build(BuildContext context) {
    _ensureControllers();
    final methodChips = widget.methods.length > 1;
    return AlertDialog(
      title: Text('Login · ${widget.title}'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              SettingsTextField(
                controller: _controllers[(f['id'] ?? '').toString()]!,
                label: (f['label'] ?? f['id'] ?? '').toString(),
                obscureText:
                    (f['type'] ?? '').toString().toLowerCase() == 'password' ||
                    (f['type'] ?? '').toString().toLowerCase() == 'secret',
                keyboardType:
                    (f['type'] ?? '').toString().toLowerCase() == 'phone'
                    ? TextInputType.phone
                    : TextInputType.text,
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final fields = <String, String>{};
            for (final f in _fields) {
              final id = (f['id'] ?? '').toString();
              if (id.isEmpty) continue;
              fields[id] = _controllers[id]?.text.trim() ?? '';
            }
            Navigator.pop(context, (method: _methodId, fields: fields));
          },
          child: const Text('Login'),
        ),
      ],
    );
  }
}
