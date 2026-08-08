import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/lan/lan.dart';
import 'package:forja/shared/theme/app_theme.dart';

/// Settings → LAN — one-time desktop↔TV trust (RFC-022).
class LanSettingsSection extends StatefulWidget {
  const LanSettingsSection({super.key});

  @override
  State<LanSettingsSection> createState() => _LanSettingsSectionState();
}

class _LanSettingsSectionState extends State<LanSettingsSection> {
  final _manualHostController = TextEditingController();
  final _manualPortController = TextEditingController();
  final _pairCodeController = TextEditingController();

  bool _serverEnabled = false;
  bool _allowLocalTorrent = false;
  bool _paired = false;
  bool _serverOnline = false;
  bool _loading = true;
  bool _discovering = false;
  bool _pairing = false;
  String _pairingCode = '';
  int _serverPort = 0;
  List<String> _localIps = [];
  String? _pairedHost;
  int? _pairedPort;
  List<LanServerInfo> _discovered = [];
  List<Map<String, dynamic>> _devices = [];

  bool get _isDesktopServer => LanServerService.canRunServer;

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
    _pairedHost = await prefs.serverHost;
    _pairedPort = await prefs.serverPort;
    final host = _pairedHost;
    final port = _pairedPort;
    if (host != null && host.isNotEmpty) {
      _manualHostController.text = host;
    }
    if (port != null) {
      _manualPortController.text = '$port';
    }
    if (_isDesktopServer && LanServerService.instance.isRunning) {
      _pairingCode = LanServerService.instance.currentPairingCode();
      _serverPort = LanServerService.instance.port;
      _devices = LanServerService.instance.listDevices();
      _localIps = await LanServerService.instance.localIpv4Addresses();
      _serverEnabled = true;
    } else if (_isDesktopServer) {
      _pairingCode = '';
      _serverPort = 0;
      _localIps = const [];
      _devices = const [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleServer(bool enabled) async {
    if (enabled) {
      final ok = await LanServerService.instance.start();
      if (!ok && mounted) {
        final detail = LanServerService.instance.lastStartError();
        ForjaToast.error(
          detail.isEmpty
              ? 'Failed to start LAN server'
              : 'Failed to start LAN server: $detail',
        );
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
      if (found.isEmpty) {
        ForjaToast.info(
          'No desktop found — enter IP and port from Settings → LAN on desktop',
        );
      }
    }
  }

  Future<void> _pairWith({String? host, int? port}) async {
    final h = host ?? _manualHostController.text.trim();
    final p = port ?? int.tryParse(_manualPortController.text.trim()) ?? 0;
    final code = _pairCodeController.text.trim();
    if (h.isEmpty || p <= 0 || code.length < 6) {
      ForjaToast.info('Enter desktop address, port, and 6-digit code');
      return;
    }
    setState(() => _pairing = true);
    final token = await LanClientService.instance.pair(
      host: h,
      port: p,
      code: code,
      label: LanPrefs.defaultDeviceLabel(),
    );
    if (!mounted) return;
    setState(() => _pairing = false);
    if (token == null) {
      ForjaToast.error('Pairing failed — check code, IP, and that desktop LAN is on');
      return;
    }
    ForjaToast.success('Paired — torrents will play via this desktop');
    _pairCodeController.clear();
    await _load();
  }

  Future<void> _unpair() async {
    await LanPrefs.instance.clearServer();
    await _load();
  }

  Future<void> _revoke(String deviceId) async {
    LanServerService.instance.revokeDevice(deviceId);
    await _load();
  }

  void _copyCode() {
    if (_pairingCode.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _pairingCode));
    ForjaToast.success('Code copied');
  }

  void _copyAddress(String host) {
    if (_serverPort <= 0) return;
    Clipboard.setData(ClipboardData(text: '$host:$_serverPort'));
    ForjaToast.success('Address copied');
  }

  String get _primaryAddressLabel {
    if (_serverPort <= 0) return '';
    if (_localIps.isEmpty) return 'port $_serverPort';
    if (_localIps.length == 1) return '${_localIps.first}:$_serverPort';
    return '${_localIps.first}:$_serverPort (+${_localIps.length - 1} more)';
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
        _introCard(),
        const SizedBox(height: 16),
        if (_isDesktopServer) ..._desktopServerBody() else ..._clientBody(),
      ],
    );
  }

  Widget _introCard() {
    return Text(
      _isDesktopServer
          ? 'Turn this PC into a Forja LAN server. Pair TVs and phones once — they pick torrents; this desktop downloads and streams.'
          : 'Pair once with a desktop Forja on the same Wi‑Fi. After that, torrent sources on this device play through the desktop.',
      style: TextStyle(
        color: ForjaShellColors.textSecondary,
        fontSize: 13,
        height: 1.35,
      ),
    );
  }

  List<Widget> _desktopServerBody() {
    final running =
        _serverEnabled && LanServerService.instance.isRunning && _serverPort > 0;
    return [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Enable LAN server'),
        subtitle: Text(
          running
              ? 'Listening · $_primaryAddressLabel'
              : 'Off — TVs cannot use this desktop for torrents',
        ),
        value: running,
        onChanged: _toggleServer,
      ),
      if (running) ...[
        const SizedBox(height: 8),
        _sectionLabel('DESKTOP ADDRESS'),
        const SizedBox(height: 4),
        Text(
          'On the TV: Settings → LAN → enter this IP and port if Discover does not find this PC.',
          style: TextStyle(
            color: ForjaShellColors.textSecondary,
            fontSize: 12,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        if (_localIps.isEmpty)
          Text(
            'Port $_serverPort — could not detect a LAN IP; check Wi‑Fi / Ethernet.',
            style: TextStyle(
              color: ForjaShellColors.textSecondary,
              fontSize: 13,
            ),
          )
        else
          ..._localIps.map(
            (ip) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                '$ip:$_serverPort',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              trailing: IconButton(
                tooltip: 'Copy address',
                onPressed: () => _copyAddress(ip),
                icon: const Icon(Icons.copy_rounded),
              ),
            ),
          ),
        const SizedBox(height: 16),
        _sectionLabel('PAIRING CODE'),
        const SizedBox(height: 4),
        Text(
          'On the TV: Settings → LAN → enter this code (valid ~5 minutes, one use).',
          style: TextStyle(
            color: ForjaShellColors.textSecondary,
            fontSize: 12,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: ForjaShellColors.inkHover,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _pairingCode.isEmpty ? '————' : _pairingCode,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 8,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy',
                onPressed: _copyCode,
                icon: const Icon(Icons.copy_rounded),
              ),
              IconButton(
                tooltip: 'New code',
                onPressed: () {
                  setState(() {
                    _pairingCode =
                        LanServerService.instance.refreshPairingCode();
                  });
                },
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _sectionLabel('PAIRED DEVICES'),
        const SizedBox(height: 4),
        Text(
          _devices.isEmpty
              ? 'No TVs or phones paired yet.'
              : 'Revoke to force that device to pair again.',
          style: TextStyle(
            color: ForjaShellColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        if (_devices.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Waiting for a device to enter the code…',
              style: TextStyle(
                color: ForjaShellColors.textSecondary.withValues(alpha: 0.8),
                fontSize: 13,
              ),
            ),
          )
        else
          ..._devices.map((d) {
            final id = d['device_id']?.toString() ?? '';
            final label = (d['label'] as String?)?.trim();
            final title = (label != null && label.isNotEmpty) ? label : 'Device';
            final when = _formatPairedAt(d['paired_at']);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _iconForLabel(label),
                color: ForjaShellColors.brandGreen,
              ),
              title: Text(title),
              subtitle: Text(
                when == null ? id : '$when · $id',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: TextButton(
                onPressed: id.isEmpty ? null : () => _revoke(id),
                child: const Text('Revoke'),
              ),
            );
          }),
      ],
    ];
  }

  List<Widget> _clientBody() {
    return [
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          _paired
              ? (_serverOnline
                  ? Icons.tv_rounded
                  : Icons.cloud_off_rounded)
              : Icons.link_rounded,
          color: _paired && _serverOnline
              ? Colors.greenAccent
              : ForjaShellColors.textSecondary,
        ),
        title: Text(
          _paired
              ? (_serverOnline ? 'Paired · desktop online' : 'Paired · desktop offline')
              : 'Not paired',
        ),
        subtitle: Text(
          _paired
              ? '${_pairedHost ?? '?'}:${_pairedPort ?? '?'} — torrents play via desktop'
              : 'Pair once. Then open Sources → Torrents on a title.',
        ),
        trailing: _paired
            ? TextButton(onPressed: _unpair, child: const Text('Unpair'))
            : null,
      ),
      if (!_paired) ...[
        const SizedBox(height: 8),
        _sectionLabel('FIND DESKTOP'),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _discovering ? null : _discover,
          icon: _discovering
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.wifi_find_rounded),
          label: Text(_discovering ? 'Searching…' : 'Discover on Wi‑Fi'),
        ),
        if (_discovered.isNotEmpty) ...[
          const SizedBox(height: 8),
          ..._discovered.map(
            (s) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.host),
              subtitle: Text('Port ${s.port}'),
              trailing: TextButton(
                onPressed: () {
                  setState(() {
                    _manualHostController.text = s.host;
                    _manualPortController.text = '${s.port}';
                  });
                },
                child: const Text('Use'),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _sectionLabel('OR ENTER MANUALLY'),
        const SizedBox(height: 8),
        SettingsTextField(
          controller: _manualHostController,
          label: 'Desktop IP',
          hint: '192.168.1.10',
        ),
        const SizedBox(height: 8),
        SettingsTextField(
          controller: _manualPortController,
          label: 'Port',
          hint: 'Shown under Enable LAN server on desktop',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        SettingsTextField(
          controller: _pairCodeController,
          label: '6-digit code',
          hint: 'From desktop Settings → LAN',
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _pairing ? null : () => _pairWith(),
          child: _pairing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Pair with desktop'),
        ),
      ],
      if (defaultTargetPlatform == TargetPlatform.android) ...[
        const SizedBox(height: 20),
        const Divider(),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Allow local torrent on this device'),
          subtitle: const Text(
            'Advanced — use the on-device engine instead of the desktop. Leave off for TV.',
          ),
          value: _allowLocalTorrent,
          onChanged: (v) async {
            await LanPrefs.instance.setAllowLocalTorrentOnDevice(v);
            setState(() => _allowLocalTorrent = v);
          },
        ),
      ],
    ];
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: AppTheme.current.primaryColor,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  static String? _formatPairedAt(Object? raw) {
    final secs = (raw as num?)?.toInt();
    if (secs == null || secs <= 0) return null;
    final dt = DateTime.fromMillisecondsSinceEpoch(secs * 1000);
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  static IconData _iconForLabel(String? label) {
    final l = (label ?? '').toLowerCase();
    if (l.contains('tv')) return Icons.tv_rounded;
    if (l.contains('iphone') || l.contains('ios')) return Icons.phone_iphone;
    if (l.contains('ipad')) return Icons.tablet_mac;
    if (l.contains('android')) return Icons.phone_android;
    return Icons.devices_rounded;
  }
}
