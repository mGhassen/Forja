import 'dart:io';
import 'package:flutter/material.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/services/android_player_launcher.dart';
import 'package:forja/shared/design/design.dart';
import 'package:rust/rust.dart' as site111477_proxy;

// ─────────────────────────────────────────────────────────────────────────────
//  EXTERNAL PLAYER SERVICE
//
//  Handles launching video URLs in external players on all platforms.
//  On Android: uses ACTION_VIEW intents with package targeting.
//  On Desktop: uses Process.start with known install paths / PATH lookup.
// ─────────────────────────────────────────────────────────────────────────────

class ExternalPlayerService {
  static final ExternalPlayerService _instance =
      ExternalPlayerService._internal();
  factory ExternalPlayerService() => _instance;
  ExternalPlayerService._internal();

  // ═════════════════════════════════════════════════════════════════════════
  //  PLAYER DEFINITIONS
  // ═════════════════════════════════════════════════════════════════════════

  /// All known external players per platform, in display order.
  static List<ExternalPlayer> get availablePlayers {
    if (Platform.isAndroid || Platform.isIOS) {
      return _mobilePlayers;
    } else if (Platform.isWindows) {
      return _windowsPlayers;
    } else if (Platform.isLinux) {
      return _linuxPlayers;
    } else if (Platform.isMacOS) {
      return _macPlayers;
    }
    return [];
  }

  /// The full list including "Built-in Player" as first option.
  static List<String> get playerNames =>
      ['Built-in Player', ...availablePlayers.map((p) => p.displayName)];

  /// External players that are actually installed on this device.
  ///
  /// Desktop: probes known paths and PATH (`which` / `where`).
  /// Mobile: returns the full platform list (Android intents fail gracefully).
  static Future<List<ExternalPlayer>> getInstalledPlayers() async {
    final players = availablePlayers;
    if (players.isEmpty) return const [];

    if (Platform.isAndroid || Platform.isIOS) {
      return players;
    }

    final installed = <ExternalPlayer>[];
    await Future.wait(
      players.map((player) async {
        if (await _findDesktopExecutable(player) != null) {
          installed.add(player);
        }
      }),
    );
    return installed;
  }

  // ── Mobile (Android / iOS) ─────────────────────────────────────────────

  static final List<ExternalPlayer> _mobilePlayers = [
    ExternalPlayer(
      displayName: 'VLC',
      androidPackage: 'org.videolan.vlc',
      androidExtras: {'title': true},
    ),
    ExternalPlayer(
      displayName: 'MX Player',
      androidPackage: 'com.mxtech.videoplayer.ad',
      androidAltPackages: ['com.mxtech.videoplayer.pro'],
      androidExtras: {'title': true, 'return_result': true},
    ),
    ExternalPlayer(
      displayName: 'mpv-android',
      androidPackage: 'is.xyz.mpv',
    ),
    ExternalPlayer(
      displayName: 'mpv-kt',
      androidPackage: 'live.mehiz.mpvkt',
    ),
    ExternalPlayer(
      displayName: 'Just Player',
      androidPackage: 'com.brouken.player',
    ),
    ExternalPlayer(
      displayName: 'Nova Player',
      androidPackage: 'org.courville.nova',
    ),
    ExternalPlayer(
      displayName: 'KMPlayer',
      androidPackage: 'com.kmplayer',
    ),
    ExternalPlayer(
      displayName: 'nPlayer',
      androidPackage: 'com.newin.nplayer.pro',
    ),
    ExternalPlayer(
      displayName: 'Kodi',
      androidPackage: 'org.xbmc.kodi',
    ),
    ExternalPlayer(
      displayName: 'System Default',
      androidPackage: null, // Shows system chooser
    ),
  ];

  // ── Windows ────────────────────────────────────────────────────────────

  static final List<ExternalPlayer> _windowsPlayers = [
    ExternalPlayer(
      displayName: 'mpv',
      windowsBinary: 'mpv.exe',
      windowsPaths: [
        r'C:\Program Files\mpv\mpv.exe',
        r'C:\Program Files (x86)\mpv\mpv.exe',
        r'C:\ProgramData\chocolatey\bin\mpv.exe',
      ],
      desktopArgs: (url, title, headers) => [
        if (title != null) '--force-media-title=$title',
        ..._mpvStreamArgs(prefix: '--'),
        ..._mpvHeaderArgs(headers, prefix: '--'),
        url,
      ],
    ),
    ExternalPlayer(
      displayName: 'VLC',
      windowsBinary: 'vlc.exe',
      windowsPaths: [
        r'C:\Program Files\VideoLAN\VLC\vlc.exe',
        r'C:\Program Files (x86)\VideoLAN\VLC\vlc.exe',
      ],
      windowsRegistryKey: r'HKLM\SOFTWARE\VideoLAN\VLC',
      windowsRegistryValue: 'InstallDir',
      windowsRegistryBinary: 'vlc.exe',
      desktopArgs: (url, title, headers) => [
        if (title != null) '--meta-title=$title',
        ..._vlcHeaderArgs(headers),
        url,
      ],
    ),
    ExternalPlayer(
      displayName: 'PotPlayer',
      windowsBinary: 'PotPlayerMini64.exe',
      windowsPaths: [
        r'C:\Program Files\DAUM\PotPlayer\PotPlayerMini64.exe',
        r'C:\Program Files (x86)\DAUM\PotPlayer\PotPlayerMini.exe',
        r'C:\Program Files\PotPlayer\PotPlayerMini64.exe',
      ],
      desktopArgs: (url, title, headers) => [url],
    ),
    ExternalPlayer(
      displayName: 'MPC-HC',
      windowsBinary: 'mpc-hc64.exe',
      windowsPaths: [
        r'C:\Program Files\MPC-HC\mpc-hc64.exe',
        r'C:\Program Files (x86)\MPC-HC\mpc-hc.exe',
        r'C:\Program Files\MPC-HC x64\mpc-hc64.exe',
      ],
      desktopArgs: (url, title, headers) => [url],
    ),
    ExternalPlayer(
      displayName: 'MPC-BE',
      windowsBinary: 'mpc-be64.exe',
      windowsPaths: [
        r'C:\Program Files\MPC-BE x64\mpc-be64.exe',
        r'C:\Program Files (x86)\MPC-BE\mpc-be.exe',
      ],
      desktopArgs: (url, title, headers) => [url],
    ),
    ExternalPlayer(
      displayName: 'SMPlayer',
      windowsBinary: 'smplayer.exe',
      windowsPaths: [
        r'C:\Program Files\SMPlayer\smplayer.exe',
        r'C:\Program Files (x86)\SMPlayer\smplayer.exe',
      ],
      desktopArgs: (url, title, headers) => [url],
    ),
  ];

  // ── Linux ──────────────────────────────────────────────────────────────

  static final List<ExternalPlayer> _linuxPlayers = [
    ExternalPlayer(
      displayName: 'mpv',
      linuxBinary: 'mpv',
      desktopArgs: (url, title, headers) => [
        if (title != null) '--force-media-title=$title',
        ..._mpvStreamArgs(prefix: '--'),
        ..._mpvHeaderArgs(headers, prefix: '--'),
        url,
      ],
    ),
    ExternalPlayer(
      displayName: 'VLC',
      linuxBinary: 'vlc',
      desktopArgs: (url, title, headers) => [
        if (title != null) '--meta-title=$title',
        ..._vlcHeaderArgs(headers),
        url,
      ],
    ),
    ExternalPlayer(
      displayName: 'Celluloid',
      linuxBinary: 'celluloid',
      desktopArgs: (url, title, headers) => [url],
    ),
    ExternalPlayer(
      displayName: 'Haruna',
      linuxBinary: 'haruna',
      desktopArgs: (url, title, headers) => [url],
    ),
    ExternalPlayer(
      displayName: 'SMPlayer',
      linuxBinary: 'smplayer',
      desktopArgs: (url, title, headers) => [url],
    ),
  ];

  // ── macOS ──────────────────────────────────────────────────────────────

  static final List<ExternalPlayer> _macPlayers = [
    ExternalPlayer(
      displayName: 'IINA',
      macAppPath: '/Applications/IINA.app',
      macCliBinary: 'iina-cli',
      macBinary: 'iina',
      // Sandboxed Forja cannot exec iina-cli directly — the child inherits the
      // sandbox and cannot IPC to IINA.app. Launch via `/usr/bin/open` instead.
      macPreferOpenLauncher: true,
    ),
    ExternalPlayer(
      displayName: 'VLC',
      macAppPath: '/Applications/VLC.app',
      macCliBinary: 'VLC',
      macBinary: 'vlc',
      desktopArgs: (url, title, headers) => [
        if (title != null) '--meta-title=$title',
        ..._vlcHeaderArgs(headers),
        url,
      ],
    ),
    ExternalPlayer(
      displayName: 'mpv',
      macBinary: 'mpv',
      desktopArgs: (url, title, headers) => [
        if (title != null) '--force-media-title=$title',
        ..._mpvStreamArgs(prefix: '--'),
        ..._mpvHeaderArgs(headers, prefix: '--'),
        url,
      ],
    ),
  ];

  // ═════════════════════════════════════════════════════════════════════════
  //  CHECK IF SELECTED PLAYER IS EXTERNAL
  // ═════════════════════════════════════════════════════════════════════════

  static Future<bool> isExternalPlayerSelected() async {
    final player = await SettingsService().getExternalPlayer();
    return player != 'Built-in Player';
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  LAUNCH EXTERNAL PLAYER
  // ═════════════════════════════════════════════════════════════════════════

  /// Launch an external player with the given URL.
  /// Returns true if launch was successful, false if player not found.
  static Future<bool> launch({
    required String url,
    required String title,
    Map<String, String>? headers,
    BuildContext? context,
    String? playerName,
  }) async {
    final selectedName = playerName ?? await SettingsService().getExternalPlayer();
    if (selectedName == 'Built-in Player') return false;

    final players = availablePlayers;
    if (players.isEmpty) return false;

    final player = players.firstWhere(
      (p) => p.displayName == selectedName,
      orElse: () => players.first,
    );

    if (player.displayName == 'IINA') {
      debugPrint(
        '[ExternalPlayer] IINA handoff input url (${url.length} chars): $url',
      );
      _logHeaderMap('IINA handoff input', headers);
    }

    final target = await _resolveLaunchTarget(
      url: url,
      headers: headers,
      desktop: Platform.isWindows || Platform.isMacOS || Platform.isLinux,
    );

    debugPrint(
      '[ExternalPlayer] target url=${target.url} '
      'headers=${target.headers?.length ?? 0}',
    );
    if (player.displayName == 'IINA') {
      _logHeaderMap('IINA pre-launch target', target.headers);
    }

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        return await _launchAndroid(
          player,
          target.url,
          title,
          target.headers,
        );
      } else {
        return await _launchDesktop(
          player,
          target.url,
          title,
          target.headers,
        );
      }
    } catch (e) {
      debugPrint('[ExternalPlayer] Error launching ${player.displayName}: $e');
      if (context != null && context.mounted) {
        final hint = e is IOException || e is FileSystemException
            ? 'Launch failed (${e.runtimeType}). See console for details.'
            : '${player.displayName} could not be launched. Is it installed?';
        ForjaToast.error(hint);
      }
      return false;
    }
  }

  /// Resolves the URL/headers external players should open.
  ///
  /// Desktop: direct URL + player CLI headers (VLC and IINA use the same URL).
  /// Android: hls-proxy when headers are required. 111477 uses seek proxy.
  static Future<({String url, Map<String, String>? headers})>
      _resolveLaunchTarget({
    required String url,
    required Map<String, String>? headers,
    required bool desktop,
  }) async {
    if (site111477_proxy.is111477LocalProxyUrl(url)) {
      site111477_proxy.retainForExternalHandoff = true;
      debugPrint('[ExternalPlayer] Using active 111477 seek proxy');
      return (url: url, headers: null);
    }

    if (site111477_proxy.is111477UpstreamUrl(url)) {
      final proxied = await site111477_proxy.start111477Proxy(
        url,
        headers: headers,
      );
      site111477_proxy.retainForExternalHandoff = true;
      debugPrint('[ExternalPlayer] Proxying 111477 stream for external player');
      return (url: proxied, headers: null);
    }

    if (_isLocalProxyUrl(url)) {
      debugPrint('[ExternalPlayer] Using existing local proxy URL');
      return (url: url, headers: null);
    }

    if (headers == null || headers.isEmpty) {
      return (url: url, headers: null);
    }

    if (desktop) {
      debugPrint('[ExternalPlayer] Direct URL — player CLI headers');
      return (url: url, headers: headers);
    }

    final proxy = LocalServerService();
    if (proxy.port <= 0) {
      await proxy.start();
    }
    if (proxy.port > 0) {
      final proxied = proxy.getHlsProxyUrl(url, headers);
      debugPrint(
        '[ExternalPlayer] Proxying stream for external player '
        '(127.0.0.1:${proxy.port})',
      );
      return (url: proxied, headers: null);
    }

    debugPrint('[ExternalPlayer] Local proxy unavailable — passing headers');
    return (url: url, headers: headers);
  }

  /// Match built-in [applyMediaHttpHeaders] mpv network/HLS tuning.
  static List<String> _mpvStreamArgs({required String prefix}) => [
        '${prefix}network-timeout=30',
        '${prefix}tls-verify=no',
        '${prefix}hls-bitrate=no',
        '${prefix}cache=yes',
        '${prefix}demuxer-readahead-secs=120',
        '${prefix}ytdl=no',
      ];

  static bool _isLocalProxyUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (uri.host != '127.0.0.1' && uri.host != 'localhost') return false;
    return uri.path.contains('/hls-proxy') ||
        uri.path.contains('/jellyfin-stream') ||
        uri.path.contains('/toky-proxy') ||
        uri.path.contains('/comic-proxy');
  }

  /// IINA headers via discrete `iina-cli` argv entries (sandbox cannot write
  /// `/tmp`). [Process.start] passes each value as one arg — `&` in Referer is
  /// safe (unlike shell). Mirrors VLC's direct URL + header flags.
  static void _logHeaderMap(String label, Map<String, String>? headers) {
    if (headers == null || headers.isEmpty) {
      debugPrint('[ExternalPlayer] $label headers: (none)');
      return;
    }
    debugPrint('[ExternalPlayer] $label headers (${headers.length}):');
    for (final entry in headers.entries) {
      debugPrint(
        '[ExternalPlayer]   ${entry.key} (${entry.value.length} chars): '
        '${entry.value}',
      );
    }
  }

  /// Full argv dump for IINA debugging (no truncation).
  static void _logIinaLaunch({
    required String executable,
    required List<String> args,
    required String streamUrl,
    required Map<String, String>? headers,
    required String title,
  }) {
    debugPrint('[ExternalPlayer] ── IINA launch payload ──');
    debugPrint('[ExternalPlayer] IINA executable: $executable');
    debugPrint('[ExternalPlayer] IINA title: $title');
    debugPrint(
      '[ExternalPlayer] IINA stream url (${streamUrl.length} chars): $streamUrl',
    );
    _logHeaderMap('IINA', headers);
    debugPrint('[ExternalPlayer] IINA argv count: ${args.length}');
    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      debugPrint(
        '[ExternalPlayer] IINA argv[$i] (${arg.length} chars): $arg',
      );
    }
    final quoted = args.map(_quoteForShellLog).join(' ');
    debugPrint(
      '[ExternalPlayer] IINA shell (manual test): $executable $quoted',
    );
    debugPrint('[ExternalPlayer] ── end IINA payload ──');
  }

  static String _quoteForShellLog(String value) {
    if (value.isEmpty) return "''";
    if (!RegExp(r'''[\s'"\\$`!&|;<>(){}[\]*?~#]''').hasMatch(value)) {
      return value;
    }
    return "'${value.replaceAll("'", r"'\''")}'";
  }

  static List<String> _iinaHeaderArgs(Map<String, String>? headers) {
    return _mpvHeaderArgs(headers, prefix: '--mpv-');
  }

  static List<String> _desktopLaunchArgs({
    required ExternalPlayer player,
    required String url,
    required String title,
    Map<String, String>? headers,
    bool viaOpenLauncher = false,
  }) {
    if (Platform.isMacOS && player.displayName == 'IINA') {
      return [
        // Direct iina-cli only: Process.start inherits stdin and iina-cli may
        // treat that as a pipe feed. Not used with `open -a` (IINA rejects it).
        if (!viaOpenLauncher) '--no-stdin',
        if (title.isNotEmpty) '--mpv-force-media-title=$title',
        ..._mpvStreamArgs(prefix: '--mpv-'),
        ..._iinaHeaderArgs(headers),
        url,
      ];
    }

    return player.desktopArgs?.call(url, title, headers) ?? [url];
  }

  /// mpv header flags — one [http-header-fields] per header so User-Agent commas
  /// (e.g. "KHTML, like Gecko") do not break parsing.
  static List<String> _mpvHeaderArgs(
    Map<String, String>? headers, {
    required String prefix,
  }) {
    if (headers == null || headers.isEmpty) return [];
    final args = <String>[];
    final referer = headers['Referer'] ?? headers['referer'];
    if (referer != null) args.add('${prefix}referrer=$referer');
    final ua = headers['User-Agent'] ?? headers['user-agent'];
    if (ua != null) args.add('${prefix}user-agent=$ua');

    final emitted = <String>{};
    void addField(String key, String value) {
      final line = '$key: $value';
      if (!emitted.add(line)) return;
      args.add('${prefix}http-header-fields=$line');
    }

    if (referer != null) addField('Referer', referer);
    final origin = headers['Origin'] ?? headers['origin'];
    if (origin != null) addField('Origin', origin);
    if (ua != null) addField('User-Agent', ua);
    for (final entry in headers.entries) {
      final key = entry.key.toLowerCase();
      if (key == 'referer' || key == 'user-agent' || key == 'origin') {
        continue;
      }
      addField(entry.key, entry.value);
    }
    return args;
  }

  static List<String> _vlcHeaderArgs(Map<String, String>? headers) {
    if (headers == null || headers.isEmpty) return [];
    final args = <String>[];
    final referer = headers['Referer'] ?? headers['referer'];
    if (referer != null) args.add('--http-referrer=$referer');
    final ua = headers['User-Agent'] ?? headers['user-agent'];
    if (ua != null) args.add('--http-user-agent=$ua');
    return args;
  }

  // ── Android Launch ─────────────────────────────────────────────────────

  static Future<bool> _launchAndroid(
    ExternalPlayer player,
    String url,
    String title,
    Map<String, String>? headers,
  ) async {
    final Map<String, dynamic> extras = {};
    if (player.androidExtras?.containsKey('title') == true) {
      extras['title'] = title;
    }
    if (player.androidExtras?.containsKey('return_result') == true) {
      extras['return_result'] = true;
    }
    // MX Player supports headers as alternating key/value array
    if (headers != null &&
        headers.isNotEmpty &&
        (player.androidPackage == 'com.mxtech.videoplayer.ad' ||
            player.androidPackage == 'com.mxtech.videoplayer.pro')) {
      final headerList = <String>[];
      headers.forEach((k, v) {
        headerList.add(k);
        headerList.add(v);
      });
      extras['headers'] = headerList;
    }

    // Try main package first, then alternate packages
    final packagesToTry = [
      player.androidPackage,
      ...(player.androidAltPackages ?? []),
    ];

    for (final pkg in packagesToTry) {
      try {
        final success = await AndroidPlayerLauncher.launch(
          url: url,
          packageName: pkg,
          title: title,
          extras: extras.isNotEmpty ? extras : null,
        );
        if (success) return true;
      } catch (e) {
        debugPrint('[ExternalPlayer] Failed with package $pkg: $e');
      }
    }
    return false;
  }

  // ── Desktop Launch ─────────────────────────────────────────────────────

  static Future<bool> _launchDesktop(
    ExternalPlayer player,
    String url,
    String title,
    Map<String, String>? headers,
  ) async {
    final executable = await _findDesktopExecutable(player);
    if (executable == null) {
      debugPrint(
          '[ExternalPlayer] ${player.displayName} not found on this system');
      return false;
    }

    final viaOpen =
        Platform.isMacOS && executable == 'open' && player.macAppPath != null;

    final playerArgs = _desktopLaunchArgs(
      player: player,
      url: url,
      title: title,
      headers: headers,
      viaOpenLauncher: viaOpen,
    );

    // macOS: `open` only accepts its own flags; player args need `--args`.
    final List<String> args;
    if (viaOpen) {
      args = ['-a', player.macAppPath!, '--args', ...playerArgs];
    } else {
      args = playerArgs;
    }

    debugPrint(
      '[ExternalPlayer] Launching ${player.displayName}: $executable '
      '(${args.length} args) → $url',
    );
    if (player.displayName == 'IINA') {
      _logIinaLaunch(
        executable: executable,
        args: args,
        streamUrl: url,
        headers: headers,
        title: title,
      );
    } else {
      for (var i = 0; i < args.length; i++) {
        final arg = args[i];
        debugPrint(
          '[ExternalPlayer] argv[$i]=${arg.length > 120 ? '${arg.substring(0, 120)}…' : arg}',
        );
      }
    }
    await Process.start(executable, args, mode: ProcessStartMode.detached);
    return true;
  }

  /// Tries to find the executable for a desktop player.
  static Future<String?> _findDesktopExecutable(ExternalPlayer player) async {
    // 1. Check known install paths
    if (Platform.isWindows && player.windowsPaths != null) {
      for (final path in player.windowsPaths!) {
        if (await File(path).exists()) return path;
      }
      // Also check scoop user directory
      final home = Platform.environment['USERPROFILE'];
      if (home != null && player.windowsBinary != null) {
        final scoopPath =
            '$home\\scoop\\apps\\${player.displayName.toLowerCase()}\\current\\${player.windowsBinary}';
        if (await File(scoopPath).exists()) return scoopPath;
      }
    }

    if (Platform.isLinux && player.linuxBinary != null) {
      // Use 'which' to check PATH
      try {
        final result = await Process.run('which', [player.linuxBinary!]);
        if (result.exitCode == 0) {
          return result.stdout.toString().trim();
        }
      } catch (_) {}
    }

    if (Platform.isMacOS) {
      if (player.macAppPath != null &&
          await Directory(player.macAppPath!).exists()) {
        if (player.macPreferOpenLauncher) {
          return 'open'; // Caller prepends [-a, appPath, --args]
        }
      }
      // Non-sandboxed hosts: app-bundled CLI (e.g. iina-cli) forwards args reliably.
      if (player.macAppPath != null && player.macCliBinary != null) {
        final cliPath =
            '${player.macAppPath}/Contents/MacOS/${player.macCliBinary}';
        if (await File(cliPath).exists()) return cliPath;
      }
      // Fallback: open the .app bundle.
      if (player.macAppPath != null &&
          await Directory(player.macAppPath!).exists()) {
        return 'open'; // Caller must prepend [-a, appPath, --args] to args
      }
      // Check PATH binary
      if (player.macBinary != null) {
        try {
          final result = await Process.run('which', [player.macBinary!]);
          if (result.exitCode == 0) {
            return result.stdout.toString().trim();
          }
        } catch (_) {}
      }
    }

    // 2. Check Windows registry
    if (Platform.isWindows && player.windowsRegistryKey != null) {
      try {
        final result = await Process.run('reg', [
          'query',
          player.windowsRegistryKey!,
          '/v',
          player.windowsRegistryValue ?? '',
        ]);
        if (result.exitCode == 0) {
          final match = RegExp(r'REG_SZ\s+(.+)')
              .firstMatch(result.stdout.toString());
          if (match != null) {
            final dir = match.group(1)!.trim();
            final fullPath = '$dir\\${player.windowsRegistryBinary ?? player.windowsBinary}';
            if (await File(fullPath).exists()) return fullPath;
          }
        }
      } catch (_) {}
    }

    // 3. Check if binary is in PATH (Windows: where, others: which)
    if (Platform.isWindows && player.windowsBinary != null) {
      try {
        final result = await Process.run('where', [player.windowsBinary!]);
        if (result.exitCode == 0) {
          return result.stdout.toString().trim().split('\n').first.trim();
        }
      } catch (_) {}
    }

    return null;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  EXTERNAL PLAYER MODEL
// ═══════════════════════════════════════════════════════════════════════════════

class ExternalPlayer {
  final String displayName;

  // Android
  final String? androidPackage;
  final List<String>? androidAltPackages;
  final Map<String, dynamic>? androidExtras;

  // Windows
  final String? windowsBinary;
  final List<String>? windowsPaths;
  final String? windowsRegistryKey;
  final String? windowsRegistryValue;
  final String? windowsRegistryBinary;

  // Linux
  final String? linuxBinary;

  // macOS
  final String? macAppPath;
  final String? macCliBinary;
  final String? macBinary;
  /// When true, launch with `/usr/bin/open -a <app> --args …` (required for
  /// sandboxed hosts — direct CLI exec inherits the sandbox and breaks IINA IPC).
  final bool macPreferOpenLauncher;

  // Desktop args builder
  final List<String> Function(
      String url, String? title, Map<String, String>? headers)? desktopArgs;

  const ExternalPlayer({
    required this.displayName,
    this.androidPackage,
    this.androidAltPackages,
    this.androidExtras,
    this.windowsBinary,
    this.windowsPaths,
    this.windowsRegistryKey,
    this.windowsRegistryValue,
    this.windowsRegistryBinary,
    this.linuxBinary,
    this.macAppPath,
    this.macCliBinary,
    this.macBinary,
    this.macPreferOpenLauncher = false,
    this.desktopArgs,
  });
}
