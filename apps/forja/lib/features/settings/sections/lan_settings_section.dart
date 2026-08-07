import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/lan/lan.dart';
import 'package:forja/shared/theme/app_theme.dart';

/// Settings → LAN server/client (RFC-022).
class LanSettingsSection extends StatefulWidget {
  const LanSettingsSection({super.key});

  @override
  State<LanSettingsSection> createState() => _LanSettingsSectionState();
}

class _LanSettingsSectionState extends State<LanSettingsSection> {
  final _manualHostController = TextEditingController();
  final _manualPortController = TextEditingController(text: '8765');
  final _pairCodeController = TextEditingController();

  bool _serverEnabled = false;
  bool _allowLocalTorrent = false;
  bool _paired = false;
  bool _serverOnline = false;
  bool _loading = true;
  bool _discovering = false;
  String _pairingCode = '';
  int _serverPort = 0;
  List<LanServerInfo> _discovered = [];
  List<Map<String, dynamic>> _devices = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _manualHostController.dispose();
    _manualPortController.dispose();
    _pairCodeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = LanPrefs.instance;
    _serverEnabled = await prefs.isLanServerEnabled();
    _allowLocalTorrent = await prefs.allowLocalTorrentOnDevice();
    _paired = await prefs.isPaired;
    _serverOnline = await LanClientService.instance.verifyPairedConnection();
    final host = await prefs.serverHost;
    final port = await prefs.serverPort;
    if (host != null && host.isNotEmpty) {
      _manualHostController.text = host;
    }
    if (port != null) {
      _manualPortController.text = '$port';
    }
    if (LanServerService.canRunServer && LanServerService.instance.isRunning) {
      _pairingCode = LanServerService.instance.refreshPairingCode();
      _serverPort = LanServerService.instance.port;
      _devices = LanServerService.instance.listDevices();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleServer(bool enabled) async {
    if (enabled) {
      final ok = await LanServerService.instance.start();
      if (!ok && mounted) {
        ForjaToast.error('Failed to start LAN server');
        return;
      }
    } else {
      await LanServerService.instance.stop();
    }
    await _load();
  }

  Future<void> _discover() async {
    setState(() => _discovering = true);
    final found = await LanDiscoveryService.instance.discover();
    if (mounted) {
      setState(() {
        _discovered = found;
        _discovering = false;
      });
    }
  }

  Future<void> _pairWith({String? host, int? port}) async {
    final h = host ?? _manualHostController.text.trim();
    final p = port ?? int.tryParse(_manualPortController.text.trim()) ?? 0;
    final code = _pairCodeController.text.trim();
    if (h.isEmpty || p <= 0 || code.length < 6) {
      ForjaToast.info('Enter server address and 6-digit code');
      return;
    }
    final token = await LanClientService.instance.pair(
      host: h,
      port: p,
      code: code,
    );
    if (!mounted) return;
    if (token == null) {
      ForjaToast.error('Pairing failed — check code and address');
      return;
    }
    ForjaToast.success('Paired with desktop server');
    _pairCodeController.clear();
    await _load();
  }

  Future<void> _unpair() async {
    await LanPrefs.instance.clearServer();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (LanServerService.canRunServer) ...[
          SwitchListTile(
            title: const Text('Enable LAN server'),
            subtitle: Text(
              _serverEnabled && _serverPort > 0
                  ? 'Listening on port $_serverPort'
                  : 'Desktop serves torrent/proxy streams to paired devices',
            ),
            value: _serverEnabled && LanServerService.instance.isRunning,
            onChanged: _toggleServer,
          ),
          if (_serverEnabled && _pairingCode.isNotEmpty) ...[
            ListTile(
              title: const Text('Pairing code'),
              subtitle: Text(
                _pairingCode,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () {
                  setState(() {
                    _pairingCode =
                        LanServerService.instance.refreshPairingCode();
                  });
                },
              ),
            ),
            if (_devices.isNotEmpty)
              ..._devices.map(
                (d) => ListTile(
                  title: Text(d['device_id']?.toString() ?? 'Device'),
                  subtitle: Text('Paired'),
                  trailing: IconButton(
                    icon: const Icon(Icons.link_off_rounded),
                    onPressed: () {
                      final id = d['device_id']?.toString();
                      if (id != null) {
                        LanServerService.instance.revokeDevice(id);
                        _load();
                      }
                    },
                  ),
                ),
              ),
            const Divider(),
          ],
        ],
        if (!LanServerService.canRunServer) ...[
          Text(
            'LAN client',
            style: TextStyle(
              color: AppTheme.current.primaryColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(
              _paired
                  ? (_serverOnline
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded)
                  : Icons.link_rounded,
              color: _serverOnline
                  ? Colors.greenAccent
                  : ForjaShellColors.textSecondary,
            ),
            title: Text(_paired ? 'Paired server' : 'Not paired'),
            subtitle: Text(
              _paired
                  ? (_serverOnline ? 'Server online' : 'Server offline')
                  : 'Pair once to play torrent/proxy streams from desktop',
            ),
            trailing: _paired
                ? TextButton(onPressed: _unpair, child: const Text('Unpair'))
                : null,
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _discovering ? null : _discover,
                  icon: _discovering
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_find_rounded),
                  label: const Text('Discover'),
                ),
              ),
            ],
          ),
          if (_discovered.isNotEmpty) ...[
            const SizedBox(height: 8),
            ..._discovered.map(
              (s) => ListTile(
                title: Text(s.host),
                subtitle: Text('${s.serverId} · port ${s.port}'),
                trailing: TextButton(
                  onPressed: () {
                    _manualHostController.text = s.host;
                    _manualPortController.text = '${s.port}';
                  },
                  child: const Text('Use'),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _manualHostController,
            decoration: const InputDecoration(
              labelText: 'Server address',
              hintText: '192.168.1.10',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _manualPortController,
            decoration: const InputDecoration(labelText: 'Port'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _pairCodeController,
            decoration: const InputDecoration(
              labelText: 'Pairing code',
              hintText: '6 digits from desktop',
            ),
            keyboardType: TextInputType.number,
            maxLength: 6,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => _pairWith(),
            child: const Text('Pair'),
          ),
          if (defaultTargetPlatform == TargetPlatform.android) ...[
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Allow local torrent on this device'),
              subtitle: const Text(
                'Android TV: play torrents locally instead of via desktop',
              ),
              value: _allowLocalTorrent,
              onChanged: (v) async {
                await LanPrefs.instance.setAllowLocalTorrentOnDevice(v);
                setState(() => _allowLocalTorrent = v);
              },
            ),
          ],
        ],
      ],
    );
  }
}
