import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/features/settings/providers/settings_visibility_provider.dart';
import 'package:forja/features/settings/widgets/p2p_streaming_ack_dialog.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/lan/lan.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:rust/rust.dart';

/// Settings → LAN — one-time desktop↔TV trust (RFC-022).
class LanSettingsSection extends ConsumerStatefulWidget {
  const LanSettingsSection({super.key});

  @override
  ConsumerState<LanSettingsSection> createState() => _LanSettingsSectionState();
}

class _LanSettingsSectionState extends ConsumerState<LanSettingsSection> {
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
  List<Map<String, dynamic>> _torrentHistory = [];
  Map<String, dynamic>? _activeTorrent;
  int _torrentCacheBytes = 0;
  Timer? _statusTimer;

  bool get _isDesktopServer => LanServerService.canRunServer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _manualHostController.dispose();
    _manualPortController.dispose();
    _pairCodeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prevPaired = _paired;
    final prevOnline = _serverOnline;
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
    if (_isDesktopServer) {
      _torrentHistory = LanServerService.instance.listTorrentHistory();
      _activeTorrent = LanServerService.instance.activeTorrentStatus();
      try {
        _torrentCacheBytes =
            await TorrentStreamService().cacheDirectoryBytes();
      } catch (_) {
        _torrentCacheBytes = 0;
      }
    }
    _ensureStatusPolling();
    if (mounted) setState(() => _loading = false);
    LanPairingPresence.instance.notifyChanged();
    if (prevPaired != _paired || prevOnline != _serverOnline) {
      _refreshPlaySourceGates();
    }
  }

  void _ensureStatusPolling() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      if (_isDesktopServer) {
        setState(() {
          _devices = LanServerService.instance.listDevices();
          _activeTorrent = LanServerService.instance.activeTorrentStatus();
          _torrentHistory = LanServerService.instance.listTorrentHistory();
          if (LanServerService.instance.isRunning) {
            _serverPort = LanServerService.instance.port;
          }
        });
        LanPairingPresence.instance.notifyChanged();
        return;
      }
      unawaited(_pollClientStatus());
    });
  }

  Future<void> _pollClientStatus() async {
    final prevOnline = _serverOnline;
    final online = await LanClientService.instance.verifyPairedConnection();
    final host = await LanPrefs.instance.serverHost;
    final port = await LanPrefs.instance.serverPort;
    final paired = await LanPrefs.instance.isPaired;
    if (!mounted) return;
    setState(() {
      _paired = paired;
      _serverOnline = online;
      _pairedHost = host;
      _pairedPort = port;
    });
    if (prevOnline != online || (!_paired && prevOnline)) {
      _refreshPlaySourceGates();
    }
  }

  /// Manual refresh — does not blank the page with [_loading].
  Future<void> _reloadClientStatus() async {
    await _pollClientStatus();
  }

  /// IconButton on touch/desktop; [shellFocusableTap] on TV so D-pad owns focus.
  Widget _reloadControl({
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    final icon = const Icon(Icons.refresh_rounded);
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    if (tv) {
      return shellFocusableTap(
        context: context,
        onTap: onPressed,
        borderRadius: 8,
        scaleOnFocus: 1.0,
        showFocusRail: true,
        tvTabId: 'settings',
        tvZone: ShellTvZone.settings,
        child: SizedBox(width: 40, height: 40, child: Center(child: icon)),
      );
    }
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: icon,
    );
  }

  Widget _unpairControl() {
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    if (tv) {
      return shellFocusableTap(
        context: context,
        onTap: () => unawaited(_unpair()),
        borderRadius: 8,
        scaleOnFocus: 1.0,
        showFocusRail: true,
        tvTabId: 'settings',
        tvZone: ShellTvZone.settings,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text('Unpair'),
        ),
      );
    }
    return TextButton(
      onPressed: () => unawaited(_unpair()),
      child: const Text('Unpair'),
    );
  }

  Future<void> _refreshTorrentPanel() async {
    if (!_isDesktopServer) return;
    var cacheBytes = _torrentCacheBytes;
    try {
      cacheBytes = await TorrentStreamService().cacheDirectoryBytes();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _activeTorrent = LanServerService.instance.activeTorrentStatus();
      _torrentHistory = LanServerService.instance.listTorrentHistory();
      _torrentCacheBytes = cacheBytes;
    });
  }

  Future<void> _removeHistory(String infoHash) async {
    final ok = LanServerService.instance.removeTorrentHistory(infoHash);
    if (!ok) {
      ForjaToast.error('Could not remove torrent');
      return;
    }
    ForjaToast.success('Removed torrent cache entry');
    await _refreshTorrentPanel();
  }

  Future<void> _clearAllTorrents() async {
    final ok = LanServerService.instance.clearTorrentHistory();
    if (!ok) {
      ForjaToast.error('Could not clear torrent cache');
      return;
    }
    ForjaToast.success('Torrent cache cleared');
    await _refreshTorrentPanel();
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
    ForjaToast.success(
      'Paired — enable Direct torrent in Settings → Playback',
    );
    _pairCodeController.clear();
    await _load();
    _refreshPlaySourceGates();
    await _maybeAckP2pAfterPair();
  }

  /// Pairing can honor stored torrent/Stremio/Nuvio — prompt once if that
  /// would turn P2P on and this device has no native play-source caps (ATV).
  Future<void> _maybeAckP2pAfterPair() async {
    final caps = PlatformPlayback.capabilities;
    if (caps.playSourceTorrent ||
        caps.playSourceStremio ||
        caps.playSourceNuvio) {
      return;
    }
    final settings = SettingsService();
    if (await settings.isP2pStreamingAcknowledged()) return;
    final wouldActivate = await settings.isPlaySourceTorrentStored() ||
        await settings.isPlaySourceStremioStored() ||
        await settings.isPlaySourceNuvioStored();
    if (!wouldActivate || !mounted) return;
    final ok = await ensureP2pStreamingAcknowledged(context);
    if (!mounted) return;
    if (ok) {
      ref.invalidate(settingsPlaybackProvider);
      return;
    }
    await settings.setPlaySourceTorrentEnabled(false);
    await settings.setPlaySourceStremioEnabled(false);
    await settings.setPlaySourceNuvioEnabled(false);
    _refreshPlaySourceGates();
  }

  Future<void> _unpair() async {
    await LanPrefs.instance.clearServer();
    LanPairingPresence.instance.notifyChanged();
    await _load();
    _refreshPlaySourceGates();
  }

  /// Pairing unlocks Playback torrent/Stremio/Nuvio toggles on ATV.
  void _refreshPlaySourceGates() {
    SettingsService.playSourceChangeNotifier.value++;
    ref.invalidate(settingsVisibilityProvider);
    ref.invalidate(settingsPlaybackProvider);
  }

  Future<void> _revoke(String deviceId) async {
    LanServerService.instance.revokeDevice(deviceId);
    LanPairingPresence.instance.notifyChanged();
    await _load();
  }

  void _refreshPairedDevices() {
    if (!_isDesktopServer || !LanServerService.instance.isRunning) return;
    setState(() {
      _devices = LanServerService.instance.listDevices();
      _pairingCode = LanServerService.instance.currentPairingCode();
    });
    LanPairingPresence.instance.notifyChanged();
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
        Row(
          children: [
            Expanded(child: _sectionLabel('PAIRED DEVICES')),
            _reloadControl(
              tooltip: 'Reload paired devices',
              onPressed: _refreshPairedDevices,
            ),
          ],
        ),
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
            final online = _deviceOnline(d['last_seen']);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              isThreeLine: true,
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    _iconForLabel(label),
                    color: ForjaShellColors.brandGreen,
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: _statusDot(online),
                  ),
                ],
              ),
              title: Text(title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    online ? 'Online' : 'Idle',
                    style: TextStyle(
                      color: online
                          ? Colors.greenAccent.withValues(alpha: 0.9)
                          : ForjaShellColors.textSecondary,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                  if (when != null)
                    Text(
                      when,
                      style: TextStyle(
                        color: ForjaShellColors.textSecondary
                            .withValues(alpha: 0.85),
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                  if (id.isNotEmpty)
                    Text(
                      id,
                      style: TextStyle(
                        color: ForjaShellColors.textSecondary
                            .withValues(alpha: 0.7),
                        fontSize: 11,
                        height: 1.25,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
              trailing: TextButton(
                onPressed: id.isEmpty ? null : () => _revoke(id),
                child: const Text('Revoke'),
              ),
            );
          }),
      ],
      const SizedBox(height: 20),
      ..._torrentActivitySection(),
    ];
  }

  List<Widget> _torrentActivitySection() {
    final active = _activeTorrent;
    final activeHash = active?['info_hash']?.toString().toLowerCase();
    final activeInHistory = activeHash != null &&
        _torrentHistory.any(
          (e) => (e['info_hash']?.toString() ?? '').toLowerCase() == activeHash,
        );
    final cacheLabel =
        TorrentStreamService.formatStorageBytes(_torrentCacheBytes);
    return [
      Row(
        children: [
          Expanded(child: _sectionLabel('TORRENT ACTIVITY')),
          if (_torrentHistory.isNotEmpty || _torrentCacheBytes > 0)
            TextButton(
              onPressed: _clearAllTorrents,
              child: const Text('Clear all'),
            ),
        ],
      ),
      Text(
        'Torrents opened by paired TVs/phones. Delete removes the cached download.',
        style: TextStyle(
          color: ForjaShellColors.textSecondary,
          fontSize: 12,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Cache on disk: $cacheLabel',
        style: TextStyle(
          color: ForjaShellColors.textSecondary.withValues(alpha: 0.85),
          fontSize: 12,
        ),
      ),
      const SizedBox(height: 8),
      if (active != null && !activeInHistory) ...[
        _torrentActivityTile(
          title: active['name']?.toString().isNotEmpty == true
              ? active['name'].toString()
              : 'Active torrent',
          live: active,
        ),
        const SizedBox(height: 4),
      ],
      if (_torrentHistory.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            active == null
                ? 'No LAN torrents yet — play one from a paired TV.'
                : 'Serving now (not yet in history).',
            style: TextStyle(
              color: ForjaShellColors.textSecondary.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
        )
      else
        ..._torrentHistory.map((e) {
          final hash = e['info_hash']?.toString() ?? '';
          final name = e['name']?.toString().trim();
          final label = (e['device_label'] as String?)?.trim();
          final device = (label != null && label.isNotEmpty)
              ? label
              : (e['device_id']?.toString() ?? 'Device');
          final when = _formatPairedAt(e['opened_at']);
          final bytes = (e['total_bytes'] as num?)?.toInt() ?? 0;
          final size = bytes > 0
              ? TorrentStreamService.formatStorageBytes(bytes)
              : null;
          final live = (activeHash != null &&
                  hash.isNotEmpty &&
                  activeHash == hash.toLowerCase())
              ? active
              : null;
          return _torrentActivityTile(
            title: (name != null && name.isNotEmpty) ? name : hash,
            device: device,
            when: when,
            size: size,
            live: live,
            onDelete: hash.isEmpty ? null : () => _removeHistory(hash),
          );
        }),
    ];
  }

  Widget _torrentActivityTile({
    required String title,
    String? device,
    String? when,
    String? size,
    Map<String, dynamic>? live,
    VoidCallback? onDelete,
  }) {
    final isActive = live != null;
    final progress = ((live?['progress'] as num?)?.toDouble() ?? 0)
        .clamp(0.0, 1.0);
    final pct = (progress * 100).toStringAsFixed(0);
    final state = live?['state']?.toString() ?? '';
    final down = (live?['download_rate'] as num?)?.toInt() ?? 0;
    final peers = (live?['num_peers'] as num?)?.toInt() ?? 0;
    final rate = TorrentStreamService.formatStorageBytes(down);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              isActive
                  ? Icons.play_circle_fill_rounded
                  : Icons.video_file_outlined,
              color: isActive
                  ? ForjaShellColors.brandGreen
                  : ForjaShellColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ForjaShellColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 4,
                            color: ForjaShellColors.brandGreen,
                            backgroundColor: ForjaShellColors.borderSubtle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$pct%',
                        style: const TextStyle(
                          color: ForjaShellColors.brandGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (state.isNotEmpty) _torrentChip(state, accent: true),
                      _torrentMeta(
                        Icons.download_rounded,
                        '$rate/s',
                      ),
                      _torrentMeta(
                        Icons.group_outlined,
                        '$peers peers',
                      ),
                    ],
                  ),
                ],
                if (device != null || when != null || size != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (device != null)
                        _torrentMeta(Icons.tv_outlined, device),
                      if (when != null)
                        _torrentMeta(Icons.event_outlined, when),
                      if (size != null)
                        _torrentMeta(Icons.sd_storage_outlined, size),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              tooltip: 'Delete cached download',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
    );
  }

  static Widget _torrentChip(String label, {bool accent = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent
            ? ForjaShellColors.brandGreen.withValues(alpha: 0.14)
            : ForjaShellColors.surfaceElevated,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: accent
              ? ForjaShellColors.brandGreen.withValues(alpha: 0.35)
              : ForjaShellColors.borderSubtle,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent
              ? ForjaShellColors.brandGreen
              : ForjaShellColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static Widget _torrentMeta(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ForjaShellColors.surfaceElevated,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: ForjaShellColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: ForjaShellColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: ForjaShellColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _clientBody() {
    return [
      ListTile(
        contentPadding: EdgeInsets.zero,
        isThreeLine: _paired,
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              _paired
                  ? (_serverOnline
                      ? Icons.tv_rounded
                      : Icons.cloud_off_rounded)
                  : Icons.link_rounded,
              color: _paired && _serverOnline
                  ? Colors.greenAccent
                  : ForjaShellColors.textSecondary,
            ),
            if (_paired)
              Positioned(
                right: -2,
                bottom: -2,
                child: _statusDot(_serverOnline),
              ),
          ],
        ),
        title: Text(_paired ? 'Paired' : 'Not paired'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_paired)
              Text(
                _serverOnline ? 'Desktop online' : 'Desktop offline',
                style: TextStyle(
                  color: _serverOnline
                      ? Colors.greenAccent.withValues(alpha: 0.9)
                      : ForjaShellColors.textSecondary,
                  fontSize: 12,
                  height: 1.25,
                ),
              ),
            Text(
              _paired
                  ? '${_pairedHost ?? '?'}:${_pairedPort ?? '?'} — torrents play via desktop'
                  : 'Pair once. Then open Sources → Torrents on a title.',
              style: TextStyle(
                color: ForjaShellColors.textSecondary.withValues(alpha: 0.85),
                fontSize: 11,
                height: 1.25,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _reloadControl(
              tooltip: 'Reload desktop status',
              onPressed: () => unawaited(_reloadClientStatus()),
            ),
            if (_paired) _unpairControl(),
          ],
        ),
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

  /// Green = seen in the last 2 minutes; grey = paired but idle.
  static bool _deviceOnline(Object? lastSeenRaw) {
    final secs = (lastSeenRaw as num?)?.toInt() ?? 0;
    if (secs <= 0) return false;
    final age = DateTime.now().millisecondsSinceEpoch ~/ 1000 - secs;
    return age >= 0 && age <= 120;
  }

  static Widget _statusDot(bool online) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: online
            ? Colors.greenAccent
            : ForjaShellColors.textSecondary.withValues(alpha: 0.55),
        border: Border.all(color: ForjaShellColors.surfaceElevated, width: 1.5),
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
