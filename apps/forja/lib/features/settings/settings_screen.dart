import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/nuvio/nuvio.dart';
import 'package:forja/shared/player/track_auto_select.dart';
import 'package:forja/shared/services/tracker/trakt_service.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:forja/shared/services/app_updater_service.dart';
import 'package:forja/shared/widgets/update_dialog.dart';
import 'package:forja/features/my_list/lists_screen.dart';
import 'webstreamr_settings_screen.dart';
import 'splash_preview_screen.dart';
import 'package:forja/shared/services/app_version.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shell/nav_config.dart';
import 'package:forja/features/anime/catalog/anime_stream_providers.dart';
import 'package:forja/features/settings/widgets/provider_priority_table.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';

/// Settings tab — RFC-024 R24-A13: local prefs only; no ShellTabRefresh / API stale policy.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settings = SettingsService();
  final StremioService _stremio = StremioService();
  final DebridApi _debrid = DebridApi();
  final JackettService _jackett = JackettService();
  final ProwlarrService _prowlarr = ProwlarrService();
  
  bool _playSourceTorrent = true;
  bool _playSourceStremio = true;
  bool _playSourceWebstreaming = true;
  BuiltInPlayerEngine _builtInEngine = BuiltInPlayerEngine.platformDefault();
  String _sortPreference = 'Seeders (High to Low)';
  // Track auto-select
  String _preferredAudioLang = 'None';
  bool _avoidUnsupportedAudio = true;
  bool _iptvEpgEnabled = true;
  String _maxPlaybackHeightLabel = 'Auto';
  List<Map<String, dynamic>> _installedAddons = [];
  bool _isInstalling = false;
  
  bool _useDebrid = false;
  String _debridService = 'None';
  final TextEditingController _addonController = TextEditingController();
  final TextEditingController _nuvioController = TextEditingController();
  bool _nuvioInstalling = false;
  List<NuvioAddon> _nuvioAddons = [];
  final TextEditingController _torboxController = TextEditingController();
  final TextEditingController _alldebridController = TextEditingController();
  final TextEditingController _premiumizeController = TextEditingController();
  final TextEditingController _debridlinkController = TextEditingController();
  
  // Jackett
  final TextEditingController _jackettUrlController = TextEditingController();
  final TextEditingController _jackettApiKeyController = TextEditingController();
  bool _isTestingJackett = false;
  String? _jackettTestResult;
  
  // Prowlarr
  final TextEditingController _prowlarrUrlController = TextEditingController();
  final TextEditingController _prowlarrApiKeyController = TextEditingController();
  bool _isTestingProwlarr = false;
  String? _prowlarrTestResult;
  List<ProwlarrTag> _prowlarrAvailableTags = [];
  Set<int> _prowlarrSelectedTagIds = {};
  bool _prowlarrTagsLoaded = false;
  
  bool _isRDLoggedIn = false;
  final TextEditingController _rdController = TextEditingController();
  bool _isVerifyingRD = false;
  
  // Trakt
  final TraktService _trakt = TraktService();
  bool _isTraktLoggedIn = false;
  String? _traktUserCode;
  String? _traktVerifyUrl;
  Timer? _traktPollTimer;
  bool _isTraktSyncing = false;
  String? _traktUsername;
  Map<String, dynamic>? _traktStats;

  // Simkl
  final SimklService _simkl = SimklService();
  bool _isSimklLoggedIn = false;
  String? _simklUserCode;
  String? _simklVerifyUrl;
  Timer? _simklPollTimer;
  bool _isSimklSyncing = false;
  String? _simklUsername;

  // MDBlist
  final MdblistService _mdblist = MdblistService();
  bool _isMdblistConfigured = false;
  final TextEditingController _mdblistApiKeyController = TextEditingController();
  String? _mdblistUsername;

  bool _isCheckingUpdate = false;
  final AppUpdaterService _updater = AppUpdaterService();

  // Torrent cache
  String _torrentCacheType = 'ram';
  int _torrentRamCacheMb = 200;
  int _torrentConnectionsLimit = 25;

  // Navbar config
  List<String> _navbarVisible = [];
  List<String> _navbarOrder = [];

  // Stream provider order (webstreaming extractors)
  List<String> _streamProviderOrder = [];
  Map<String, Map<String, dynamic>> _nuvioProviderEntries = {};

  // Anime stream provider order
  List<String> _animeProviderOrder = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadNuvioAddons();
    NuvioService.changeNotifier.addListener(_loadNuvioAddons);
  }

  Future<void> _loadNuvioAddons() async {
    final list = await NuvioService.instance.listUserAddons();
    if (!mounted) return;
    setState(() => _nuvioAddons = list);
  }

  Future<void> _loadSettings() async {
    final playSourceTorrent = await _settings.isPlaySourceTorrentEnabled();
    final playSourceStremio = await _settings.isPlaySourceStremioEnabled();
    final playSourceWebstreaming =
        await _settings.isPlaySourceWebstreamingEnabled();
    final builtInEngine = await _settings.getBuiltInPlayerEngine();
    final sort = await _settings.getSortPreference();
    final useDebrid = await _settings.useDebridForStreams();
    final service = await _settings.getDebridService();
    final addons = await _settings.getStremioAddons();
    final torboxKey = await _debrid.getTorBoxKey();
    final alldebridKey = await _debrid.getAllDebridKey();
    final premiumizeKey = await _debrid.getPremiumizeKey();
    final debridlinkKey = await _debrid.getDebridLinkKey();
    final rdToken = await _debrid.getRDAccessToken();
    
    // Load Trakt status
    final traktLoggedIn = await _trakt.isLoggedIn();
    String? traktUser;
    Map<String, dynamic>? traktStats;
    if (traktLoggedIn) {
      final profile = await _trakt.getUserProfile();
      traktUser = profile?['user']?['username']?.toString() ?? profile?['username']?.toString();
      traktStats = await _trakt.getUserStats();
    }

    // Load Simkl status
    final simklLoggedIn = await _simkl.isLoggedIn();
    String? simklUser;
    if (simklLoggedIn) {
      final profile = await _simkl.getUserProfile();
      simklUser = profile?['name']?.toString();
    }

    // Load MDBlist status
    final mdblistConfigured = await _mdblist.isConfigured();
    String? mdblistUser;
    final mdblistKey = await _mdblist.getApiKey();
    if (mdblistConfigured) {
      final info = await _mdblist.getUserInfo();
      mdblistUser = info?['name']?.toString();
    }

    // Load Jackett settings
    final jackettUrl = await _settings.getJackettBaseUrl();
    final jackettKey = await _settings.getJackettApiKey();
    
    // Load Prowlarr settings
    final prowlarrUrl = await _settings.getProwlarrBaseUrl();
    final prowlarrKey = await _settings.getProwlarrApiKey();
    final prowlarrTagIds = await _settings.getProwlarrTagIds();

    // Load torrent cache settings
    final cacheType = await _settings.getTorrentCacheType();
    final ramCacheMb = await _settings.getTorrentRamCacheMb();
    final connLimit = await _settings.getTorrentConnectionsLimit();

    // Load navbar config
    var navVisible = await _settings.getNavbarConfig();
    // Full order: visible items first, then hidden items
    final allIds = SettingsService.allNavIds;
    final hidden = allIds.where((id) => !navVisible.contains(id)).toList();
    var navOrder = [...navVisible, ...hidden];
    if (!PlatformPlayback.capabilities.builtinTorrentSearch) {
      navOrder = navOrder
          .where((id) => !PlatformPlayback.torrentNavIds.contains(id))
          .toList();
      navVisible.removeWhere((id) => PlatformPlayback.torrentNavIds.contains(id));
    }

    // Load stream provider order
    final streamOrder = await _settings.getStreamProviderOrder();
    final animeOrder = await _settings.getAnimeProviderOrder();

    // Load track auto-select preferences
    final preferredAudio = await _settings.getPreferredAudioLanguage();
    final avoidUnsupported = await _settings.getAvoidUnsupportedAudio();
    final iptvEpgEnabled = await _settings.isIptvEpgEnabled();
    SettingsService.iptvEpgEnabledNotifier.value = iptvEpgEnabled;
    final maxPlaybackHeight = await _settings.getMaxPlaybackHeight();

    if (mounted) {
      setState(() {
        _playSourceTorrent = playSourceTorrent;
        _playSourceStremio = playSourceStremio;
        _playSourceWebstreaming = playSourceWebstreaming;
        _builtInEngine = builtInEngine;
        _sortPreference = sort;
        _installedAddons = addons;
        _useDebrid = useDebrid;
        _debridService = service;
        _torboxController.text = torboxKey ?? '';
        _alldebridController.text = alldebridKey ?? '';
        _premiumizeController.text = premiumizeKey ?? '';
        _debridlinkController.text = debridlinkKey ?? '';
        _isRDLoggedIn = rdToken != null;
        _isTraktLoggedIn = traktLoggedIn;
        _traktUsername = traktUser;
        _traktStats = traktStats;
        _isSimklLoggedIn = simklLoggedIn;
        _simklUsername = simklUser;
        _isMdblistConfigured = mdblistConfigured;
        _mdblistUsername = mdblistUser;
        _mdblistApiKeyController.text = mdblistKey ?? '';
        
        _jackettUrlController.text = jackettUrl ?? '';
        _jackettApiKeyController.text = jackettKey ?? '';
        
        _prowlarrUrlController.text = prowlarrUrl ?? '';
        _prowlarrApiKeyController.text = prowlarrKey ?? '';
        _prowlarrSelectedTagIds = prowlarrTagIds.toSet();
        _torrentCacheType = cacheType;
        _torrentRamCacheMb = ramCacheMb;
        _torrentConnectionsLimit = connLimit;
        _navbarVisible = navVisible;
        _navbarOrder = navOrder;
        _streamProviderOrder = streamOrder;
        _animeProviderOrder = animeOrder;
        _preferredAudioLang = kTrackLanguageDisplayNames.contains(preferredAudio)
            ? preferredAudio
            : 'None';
        _avoidUnsupportedAudio = avoidUnsupported;
        _iptvEpgEnabled = iptvEpgEnabled;
        _maxPlaybackHeightLabel =
            SettingsService.maxPlaybackHeightLabel(maxPlaybackHeight);
      });
    }
    // Pull dynamic Nuvio scrapers (one entry per enabled scraper) so they
    // show up alongside the built-in providers in the priority list.
    try {
      final entries = await NuvioService.instance.getProviderEntries();
      if (mounted) setState(() => _nuvioProviderEntries = entries);
    } catch (_) {}
    if ((prowlarrUrl?.isNotEmpty ?? false) && (prowlarrKey?.isNotEmpty ?? false)) {
      _tryLoadProwlarrTags();
    }
  }

  Future<void> _installAddon() async {
    final url = _addonController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isInstalling = true);

    try {
      final addonData = await _stremio.fetchManifest(url);
      if (addonData != null) {
        await _settings.saveStremioAddon(addonData);
        _addonController.clear();
        await _loadSettings();
        if (mounted) ForjaToast.success('Addon installed successfully!');
      } else {
        if (mounted) ForjaToast.error('Failed to install addon. Check URL.');
      }
    } catch (e) {
      if (mounted) ForjaToast.error('Error: $e');
    } finally {
      if (mounted) setState(() => _isInstalling = false);
    }
  }

  void _removeAddon(String baseUrl) async {
    await _settings.removeStremioAddon(baseUrl);
    await _loadSettings();
    if (mounted) ForjaToast.success('Addon removed');
  }

  @override
  void dispose() {
    ShellTvFocusCoordinator.clearTab('settings');
    NuvioService.changeNotifier.removeListener(_loadNuvioAddons);
    _addonController.dispose();
    _nuvioController.dispose();
    _torboxController.dispose();
    _alldebridController.dispose();
    _premiumizeController.dispose();
    _debridlinkController.dispose();
    _jackettUrlController.dispose();
    _jackettApiKeyController.dispose();
    _prowlarrUrlController.dispose();
    _prowlarrApiKeyController.dispose();
    _mdblistApiKeyController.dispose();
    _rdController.dispose();
    _traktPollTimer?.cancel();
    _simklPollTimer?.cancel();
    _jackett.dispose();
    _prowlarr.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _saveRDApiKey() async {
    final key = _rdController.text.trim();
    if (key.isEmpty) {
      if (mounted) {
        ForjaToast.warning('Please enter an API key');
      }
      return;
    }

    // Just save the key — no verify round-trip. The verify call hangs forever
    // on macOS for some users, leaving the spinner stuck. If the key is wrong
    // they'll find out the first time they try to stream.
    await _debrid.saveRDApiKey(key);
    if (!mounted) return;
    setState(() {
      _isRDLoggedIn = true;
      _isVerifyingRD = false;
      _rdController.clear();
    });
    ForjaToast.success('Real-Debrid API key saved');
  }

  void _logoutRD() async {
    await _debrid.logoutRD();
    setState(() {
      _isRDLoggedIn = false;
      _rdController.clear();
    });
    if (mounted) {
      ForjaToast.success('Logged out of Real-Debrid');
    }
  }

  // Track which sections are expanded
  final Set<String> _expandedSections = {'backup'};

  // Owned scroll controller for the settings list. Without this the
  // Scrollbar attaches to the PrimaryScrollController, which on desktop
  // makes thumb-drag distance jump every time a section expands and the
  // scroll extent grows under your cursor.
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        interactive: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(
            ShellTokens.bodyHorizontalPadding,
            0,
            ShellTokens.bodyHorizontalPadding,
            12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ShellTabHeader(title: 'Settings'),

                    // ── Backup & Restore ──
                    _buildExpandableSection(
                      id: 'backup',
                      icon: Icons.backup_rounded,
                      title: 'Backup & Restore',
                      children: [_buildBackupRestore()],
                    ),

                    // ── Playback ──
                    _buildExpandableSection(
                      id: 'playback',
                      icon: Icons.play_circle_outline_rounded,
                      title: 'Playback',
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'PLAY SOURCES',
                            style: TextStyle(
                              color: AppTheme.current.primaryColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildFocusableToggle(
                          'Direct torrent',
                          'Search and play from built-in torrent indexers.',
                          _playSourceTorrent,
                          (val) async {
                            await _settings.setPlaySourceTorrentEnabled(val);
                            setState(() => _playSourceTorrent = val);
                          },
                        ),
                        _buildFocusableToggle(
                          'Stremio',
                          'Play from installed Stremio and Nuvio addon streams.',
                          _playSourceStremio,
                          (val) async {
                            await _settings.setPlaySourceStremioEnabled(val);
                            setState(() => _playSourceStremio = val);
                          },
                        ),
                        _buildFocusableToggle(
                          'Webstreaming',
                          'Play from web stream extractors (Videasy, WebStreamr, …).',
                          _playSourceWebstreaming,
                          (val) async {
                            await _settings
                                .setPlaySourceWebstreamingEnabled(val);
                            setState(() => _playSourceWebstreaming = val);
                          },
                        ),
                        _buildProviderScoringSection(),
                        if (Platform.isAndroid)
                          _buildFocusableDropdown(
                            'Built-in engine',
                            'Decoder when Video Player is Built-in.',
                            _builtInEngine.displayName,
                            builtInPlayerEngineOptions
                                .map((e) => e.displayName)
                                .toList(),
                            (val) async {
                              if (val == null) return;
                              final match = builtInPlayerEngineOptions
                                  .where((e) => e.displayName == val)
                                  .toList();
                              if (match.isEmpty) return;
                              await _settings.setBuiltInPlayerEngine(match.first);
                              setState(() => _builtInEngine = match.first);
                            },
                          ),
                        _buildFocusableDropdown(
                          'Preferred Audio Language',
                          'When a video starts, automatically switch to a matching audio track. Pick "None" to leave the default.',
                          _preferredAudioLang,
                          kTrackLanguageDisplayNames,
                          (val) async {
                            if (val != null) {
                              await _settings.setPreferredAudioLanguage(val);
                              setState(() => _preferredAudioLang = val);
                            }
                          },
                        ),
                        _buildFocusableToggle(
                          'Avoid unsupported audio (Atmos / TrueHD / 7.1)',
                          'Switch to AC-3 / E-AC-3 / AAC when the original track\'s codec or channel layout isn\'t supported.',
                          _avoidUnsupportedAudio,
                          (val) async {
                            await _settings.setAvoidUnsupportedAudio(val);
                            setState(() => _avoidUnsupportedAudio = val);
                          },
                        ),
                        _buildFocusableToggle(
                          'IPTV programme guide (EPG)',
                          'Load and show NOW / NEXT programme info in the IPTV player and channel browser.',
                          _iptvEpgEnabled,
                          (val) async {
                            await _settings.setIptvEpgEnabled(val);
                            setState(() => _iptvEpgEnabled = val);
                          },
                        ),
                        _buildFocusableDropdown(
                          'Max stream quality',
                          'Cap automatic stream selection. Auto uses the best your device supports.',
                          _maxPlaybackHeightLabel,
                          SettingsService.maxPlaybackHeightOptions.keys.toList(),
                          (val) async {
                            if (val == null) return;
                            final height =
                                SettingsService.maxPlaybackHeightOptions[val] ??
                                    0;
                            await _settings.setMaxPlaybackHeight(height);
                            setState(
                              () => _maxPlaybackHeightLabel = val,
                            );
                          },
                        ),
                      ],
                    ),

                    // ── Search & Torrents ──
                    _buildExpandableSection(
                      id: 'search',
                      icon: Icons.search_rounded,
                      title: PlatformPlayback.capabilities.builtinTorrentSearch
                          ? 'Search & Torrents'
                          : 'Stream Extractors',
                      children: [
                        if (PlatformPlayback.capabilities.builtinTorrentSearch) ...[
                        _buildFocusableDropdown(
                          'Default Sort Order',
                          'How torrent results are sorted automatically.',
                          _sortPreference,
                          [
                            'Seeders (High to Low)', 'Seeders (Low to High)',
                            'Quality (High to Low)', 'Quality (Low to High)',
                            'Size (High to Low)', 'Size (Low to High)',
                          ],
                          (val) {
                            if (val != null) {
                              _settings.setSortPreference(val);
                              setState(() => _sortPreference = val);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text('TORRENT ENGINE', style: TextStyle(color: AppTheme.current.primaryColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        ),
                        const SizedBox(height: 4),
                        _buildFocusableDropdown(
                          'Cache Type',
                          'Where torrent data is cached during streaming.',
                          _torrentCacheType == 'ram' ? 'RAM' : 'Disk',
                          ['RAM', 'Disk'],
                          (val) async {
                            if (val != null) {
                              final type = val == 'RAM' ? 'ram' : 'disk';
                              await _settings.setTorrentCacheType(type);
                              setState(() => _torrentCacheType = type);
                            }
                          },
                        ),
                        if (_torrentCacheType == 'ram')
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 4, top: 8, bottom: 4),
                                child: Text('RAM Cache Size: $_torrentRamCacheMb MB', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                              ),
                              Slider(
                                value: _torrentRamCacheMb.toDouble(),
                                min: 50, max: 2048, divisions: 39,
                                activeColor: Colors.deepPurpleAccent,
                                inactiveColor: Colors.white12,
                                label: '$_torrentRamCacheMb MB',
                                onChanged: (val) => setState(() => _torrentRamCacheMb = val.round()),
                                onChangeEnd: (val) async => await _settings.setTorrentRamCacheMb(val.round()),
                              ),
                            ],
                          ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 4, top: 8, bottom: 0),
                              child: Text(
                                'Connections per torrent: $_torrentConnectionsLimit',
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(left: 4, bottom: 4),
                              child: Text(
                                'Lower (5–25) often streams better on high-seed swarms.',
                                style: TextStyle(color: Colors.white38, fontSize: 11),
                              ),
                            ),
                            Slider(
                              value: _torrentConnectionsLimit.toDouble().clamp(5, 200),
                              min: 5, max: 200, divisions: 39,
                              activeColor: Colors.deepPurpleAccent,
                              inactiveColor: Colors.white12,
                              label: '$_torrentConnectionsLimit',
                              onChanged: (val) => setState(
                                  () => _torrentConnectionsLimit = val.round()),
                              onChangeEnd: (val) async {
                                await TorrentStreamService()
                                    .applyConnectionsLimit(val.round());
                              },
                            ),
                          ],
                        ),
                        ],
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text('WEBSTREAMR (LOCAL)', style: TextStyle(color: AppTheme.current.primaryColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.language),
                            title: const Text('WebStreamr Settings'),
                            subtitle: const Text('Country toggles, MFP, FlareSolverr, TMDB token'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => const WebStreamrSettingsScreen(),
                            )),
                          ),
                        ),
                      ],
                    ),

                    // ── Providers & Addons ──
                    _buildExpandableSection(
                      id: 'providers',
                      icon: Icons.extension_rounded,
                      title: 'Providers & Addons',
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text('STREMIO ADDONS', style: TextStyle(color: AppTheme.current.primaryColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        ),
                        const SizedBox(height: 8),
                        _buildAddonInput(),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text('NUVIO ADDONS', style: TextStyle(color: AppTheme.current.primaryColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        ),
                        const SizedBox(height: 8),
                        _buildNuvioAddonSection(),
                        if (PlatformPlayback.capabilities.builtinTorrentSearch) ...[
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text('JACKETT', style: TextStyle(color: AppTheme.current.primaryColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        ),
                        const SizedBox(height: 8),
                        _buildJackettConfig(),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text('PROWLARR', style: TextStyle(color: AppTheme.current.primaryColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        ),
                        const SizedBox(height: 8),
                        _buildProwlarrConfig(),
                        ],
                      ],
                    ),

                    // ── Debrid ──
                    _buildExpandableSection(
                      id: 'debrid',
                      icon: Icons.cloud_download_rounded,
                      title: 'Debrid',
                      children: [
                        _buildFocusableToggle(
                          'Use Debrid for Streams',
                          'Resolve torrents using your debrid account.',
                          _useDebrid,
                          (val) async {
                            await _settings.setUseDebridForStreams(val);
                            setState(() => _useDebrid = val);
                          },
                        ),
                        _buildFocusableDropdown(
                          'Debrid Service',
                          'Select your preferred provider.',
                          _debridService,
                          ['None', 'Real-Debrid', 'TorBox', 'AllDebrid', 'Premiumize', 'Debrid-Link'],
                          (val) async {
                            if (val != null) {
                              await _settings.setDebridService(val);
                              setState(() => _debridService = val);
                            }
                          },
                        ),
                        if (_debridService == 'Real-Debrid') _buildRDLogin(),
                        if (_debridService == 'TorBox') _buildTorBoxConfig(),
                        if (_debridService == 'AllDebrid') _buildAllDebridConfig(),
                        if (_debridService == 'Premiumize') _buildPremiumizeConfig(),
                        if (_debridService == 'Debrid-Link') _buildDebridLinkConfig(),
                      ],
                    ),

                    // ── Accounts & Sync ──
                    _buildExpandableSection(
                      id: 'accounts',
                      icon: Icons.sync_rounded,
                      title: 'Accounts & Sync',
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text('TRAKT', style: TextStyle(color: AppTheme.current.primaryColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        ),
                        const SizedBox(height: 8),
                        _buildTraktSection(),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text('SIMKL', style: TextStyle(color: AppTheme.current.primaryColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        ),
                        const SizedBox(height: 8),
                        _buildSimklSection(),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text('MDBLIST', style: TextStyle(color: AppTheme.current.primaryColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        ),
                        const SizedBox(height: 8),
                        _buildMdblistSection(),
                      ],
                    ),

                    // ── Lists ──
                    _buildExpandableSection(
                      id: 'lists',
                      icon: Icons.list_alt_rounded,
                      title: 'Lists',
                      children: [_buildListsSection()],
                    ),

                    // ── Navigation Bar ──
                    _buildExpandableSection(
                      id: 'navbar',
                      icon: Icons.tab_rounded,
                      title: 'Navigation Bar',
                      children: [_buildNavbarConfig()],
                    ),

                    // ── Developer (Rust engine status) ──
                    _buildExpandableSection(
                      id: 'developer',
                      icon: Icons.developer_mode_rounded,
                      title: 'Developer',
                      children: [
                        _buildRustEngineSection(),
                        if (kDebugMode && (Platform.isMacOS ||
                            Platform.isWindows ||
                            Platform.isLinux))
                            Card(
                              child: ListTile(
                                leading: const Icon(Icons.play_circle_outline),
                                title: const Text('Preview Splash Screen'),
                                subtitle: const Text(
                                  'Show the boot splash overlay without restarting',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const SplashPreviewScreen(),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),

                    // ── App Updates ──
                    _buildExpandableSection(
                      id: 'updates',
                      icon: Icons.system_update_rounded,
                      title: 'App Updates',
                      children: [_buildUpdateChecker()],
                    ),

                    const SizedBox(height: 40),
                    Center(
                      child: AppVersionLabel(
                        style: const TextStyle(
                          color: Colors.white24,
                          fontSize: 12,
                          letterSpacing: 2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Expandable Section Tile
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildRustEngineSection() {
    final loaded = Engine.isReady;
    final version = loaded
        ? RustLib.instance.version
        : 'not loaded (Dart fallback)';
    final statusColor = loaded ? Colors.greenAccent : Colors.orangeAccent;
    final platformNote = loaded
        ? ''
        : Platform.isAndroid || Platform.isIOS
            ? ' — run ./scripts/build_rust_mobile.sh and rebuild'
            : ' — run ./scripts/build_rust.sh';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Row(
            children: [
              Icon(Icons.memory_rounded, size: 16, color: statusColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  loaded
                      ? 'Rust engine active — v$version'
                      : 'Rust engine inactive — $version$platformNote',
                  style: TextStyle(color: statusColor, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildExpandableSection({
    required String id,
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    final isExpanded = _expandedSections.contains(id);
    return Padding(
      padding: const EdgeInsets.only(bottom: ShellTokens.settingsSectionBottomSpacing),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: isExpanded ? 0.04 : 0.02),
          borderRadius: BorderRadius.circular(ShellTokens.settingsSectionRadius),
          border: Border.all(
            color: isExpanded
                ? AppTheme.current.primaryColor.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          children: [
            // Header (always visible, tappable)
            InkWell(
              borderRadius: BorderRadius.circular(ShellTokens.settingsSectionRadius),
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedSections.remove(id);
                  } else {
                    _expandedSections.add(id);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: isExpanded ? AppTheme.current.primaryColor : Colors.white54),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: isExpanded ? Colors.white : Colors.white70,
                          fontSize: ShellTokens.settingsSectionTitleSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: isExpanded ? AppTheme.current.primaryColor : Colors.white30,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Content (animated)
            AnimatedCrossFade(
              firstChild: Padding(
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
              secondChild: const SizedBox.shrink(),
              crossFadeState: isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 200),
              sizeCurve: Curves.easeInOut,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Backup & Restore
  // ═══════════════════════════════════════════════════════════════════════════

  bool _isExporting = false;
  bool _isImporting = false;

  Future<void> _exportSettings() async {
    setState(() => _isExporting = true);
    try {
      final data = await _settings.exportAllSettings();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final fileName = 'forja_settings_$timestamp.json';

      // Write to a temp file first, then let the user pick where to save
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsString(jsonStr);

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Settings',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: Uint8List.fromList(utf8.encode(jsonStr)),
      );

      if (result != null) {
        // On desktop, saveFile() returns a path but doesn't write — we must do it ourselves
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          await File(result).writeAsString(jsonStr);
        }
      }

      await tempFile.delete();

      if (result != null && mounted) {
        ForjaToast.success('Settings exported successfully!');
      }
    } catch (e) {
      if (mounted) {
        ForjaToast.error('Export failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _importSettings() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import Settings',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final String jsonStr;
    if (file.bytes != null) {
      jsonStr = utf8.decode(file.bytes!);
    } else if (file.path != null) {
      jsonStr = await File(file.path!).readAsString();
    } else {
      if (mounted) {
        ForjaToast.error('Could not read file.');
      }
      return;
    }

    if (!mounted) return;

    // Confirm before overwriting
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('Import Settings', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will overwrite all your current settings, including addons, API keys, and preferences. Continue?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Import', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isImporting = true);
    try {
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      await _settings.importAllSettings(data);
      await _loadSettings(); // Refresh all UI state
      if (mounted) {
        ForjaToast.success('Settings imported successfully!');
      }
    } catch (e) {
      if (mounted) {
        ForjaToast.error('Import failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Widget _buildBackupRestore() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Export or import all your settings, addons, API keys, and preferences as a JSON file.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isExporting ? null : _exportSettings,
                  icon: _isExporting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.upload_rounded, size: 20),
                  label: const Text('Export'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isImporting ? null : _importSettings,
                  icon: _isImporting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.download_rounded, size: 20),
                  label: const Text('Import'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Navbar Configuration
  // ═══════════════════════════════════════════════════════════════════════════

  void _saveNavbarConfig() {
    final visible = _navbarOrder.where((id) => _navbarVisible.contains(id)).toList();
    _settings.setNavbarConfig(visible);
  }

  Widget _buildNavbarConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Show, hide, and reorder navigation tabs. Drag to reorder. Settings is always visible.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
          ),
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: _navbarOrder.length,
          proxyDecorator: (child, index, animation) {
            return Material(
              color: Colors.transparent,
              child: child,
            );
          },
          onReorderItem: (oldIndex, newIndex) {
            setState(() {
              final item = _navbarOrder.removeAt(oldIndex);
              _navbarOrder.insert(newIndex, item);
            });
            _saveNavbarConfig();
          },
          itemBuilder: (context, index) {
            final id = _navbarOrder[index];
            final dest = navDestinations[id]!;
            final isVisible = _navbarVisible.contains(id);

            return Container(
              key: ValueKey(id),
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                color: isVisible
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: NavDestinationIcon(
                  destination: dest,
                  selected: isVisible,
                  color: isVisible ? Colors.white : Colors.white24,
                  size: 22,
                ),
                title: Text(
                  dest.label,
                  style: TextStyle(
                    color: isVisible ? Colors.white : Colors.white38,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: isVisible,
                      activeTrackColor: AppTheme.primaryColor,
                      onChanged: (val) {
                        setState(() {
                          if (val) {
                            _navbarVisible.add(id);
                          } else {
                            _navbarVisible.remove(id);
                          }
                        });
                        _saveNavbarConfig();
                      },
                    ),
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.drag_handle, color: Colors.white24, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        // Settings row — always visible, not reorderable
        Container(
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
          ),
          child: ListTile(
            leading: const Icon(Icons.settings, color: AppTheme.primaryColor, size: 22),
            title: const Text(
              'Settings',
              style: TextStyle(color: AppTheme.primaryColor, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, color: Colors.white.withValues(alpha: 0.2), size: 16),
                const SizedBox(width: 8),
                Text('Always visible', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddonInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Install Stremio Addon', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addonController,
                  decoration: InputDecoration(
                    hintText: 'stremio://... or https://...',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isInstalling ? null : _installAddon,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isInstalling 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Install', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (_installedAddons.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('INSTALLED ADDONS', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            ..._installedAddons.map((addon) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: ListTile(
                leading: addon['icon'].toString().isNotEmpty 
                  ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(addon['icon'], width: 32, height: 32, errorBuilder: (c,e,s) => const Icon(Icons.extension)))
                  : const Icon(Icons.extension, color: AppTheme.primaryColor),
                title: Text(addon['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(addon['baseUrl'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.white38)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _removeAddon(addon['baseUrl']),
                ),
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildNuvioAddonSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Install Nuvio Addon',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Paste a Nuvio manifest URL (raw .../manifest.json)',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nuvioController,
                  decoration: InputDecoration(
                    hintText: 'https://.../manifest.json',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _nuvioInstalling ? null : _installNuvioAddon,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _nuvioInstalling
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Install', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (_nuvioAddons.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'INSTALLED NUVIO ADDONS',
              style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
            const SizedBox(height: 12),
            ..._nuvioAddons.map((addon) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                      leading: const Icon(Icons.code_rounded, color: AppTheme.primaryColor),
                      title: Text(addon.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(
                        '${addon.scrapers.length} scraper${addon.scrapers.length == 1 ? '' : 's'} \u00b7 v${addon.version}',
                        style: const TextStyle(fontSize: 11, color: Colors.white38),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        onPressed: () => _removeNuvioAddon(addon.manifestUrl),
                        tooltip: 'Remove addon',
                      ),
                      children: addon.scrapers.map((s) {
                        return SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          dense: true,
                          activeThumbColor: AppTheme.primaryColor,
                          value: s.enabled,
                          onChanged: (val) async {
                            await NuvioService.instance.setScraperEnabled(
                              manifestUrl: addon.manifestUrl,
                              scraperId: s.id,
                              enabled: val,
                            );
                          },
                          title: Text(s.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            [
                              if (s.description != null && s.description!.isNotEmpty) s.description!,
                              if (s.supportedTypes.isNotEmpty) s.supportedTypes.join(', '),
                            ].join(' \u00b7 '),
                            style: const TextStyle(fontSize: 11, color: Colors.white54),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Future<void> _installNuvioAddon() async {
    final url = _nuvioController.text.trim();
    if (url.isEmpty) return;
    setState(() => _nuvioInstalling = true);
    try {
      final addon = await NuvioService.instance.install(url);
      if (!mounted) return;
      _nuvioController.clear();
      ForjaToast.success('Installed ${addon.name} (${addon.scrapers.length} scrapers)');
      await _loadNuvioAddons();
    } catch (e) {
      if (!mounted) return;
      ForjaToast.error('Install failed: $e');
    } finally {
      if (mounted) setState(() => _nuvioInstalling = false);
    }
  }

  Future<void> _removeNuvioAddon(String manifestUrl) async {
    await NuvioService.instance.remove(manifestUrl);
    await _loadNuvioAddons();
    if (!mounted) return;
    ForjaToast.success('Nuvio addon removed');
  }

  Widget _buildRDLogin() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isRDLoggedIn)
            ElevatedButton.icon(
              onPressed: _logoutRD,
              icon: const Icon(Icons.logout),
              label: const Text('Logout from Real-Debrid'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                foregroundColor: Colors.redAccent,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )
          else ...[
            const Text('API Key', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _rdController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Enter Real-Debrid API Key',
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isVerifyingRD ? null : _saveRDApiKey,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isVerifyingRD
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final url = Uri.parse('https://real-debrid.com/apitoken');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text(
                'Get your API key at real-debrid.com/apitoken',
                style: TextStyle(color: AppTheme.primaryColor, fontSize: 12, decoration: TextDecoration.underline),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTorBoxConfig() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('API Key', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _torboxController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Enter TorBox API Key',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () async {
                  await _debrid.saveTorBoxKey(_torboxController.text);
                  if (mounted) {
                    ForjaToast.success('TorBox API Key Saved!');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAllDebridConfig() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('API Key', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _alldebridController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Enter AllDebrid API Key',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () async {
                  await _debrid.saveAllDebridKey(_alldebridController.text);
                  if (mounted) {
                    ForjaToast.success('AllDebrid API Key Saved!');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final url = Uri.parse('https://alldebrid.com/apikeys');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text(
              'Get your API key at alldebrid.com/apikeys',
              style: TextStyle(color: AppTheme.primaryColor, fontSize: 12, decoration: TextDecoration.underline),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumizeConfig() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('API Key', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _premiumizeController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Enter Premiumize API Key',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () async {
                  await _debrid.savePremiumizeKey(_premiumizeController.text);
                  if (mounted) {
                    ForjaToast.success('Premiumize API Key Saved!');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final url = Uri.parse('https://www.premiumize.me/account');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text(
              'Get your API key at premiumize.me/account',
              style: TextStyle(color: AppTheme.primaryColor, fontSize: 12, decoration: TextDecoration.underline),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebridLinkConfig() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('API Key', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _debridlinkController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Enter Debrid-Link API Key',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () async {
                  await _debrid.saveDebridLinkKey(_debridlinkController.text);
                  if (mounted) {
                    ForjaToast.success('Debrid-Link API Key Saved!');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final url = Uri.parse('https://debrid-link.com/webapp/apikey');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text(
              'Get your API key at debrid-link.com/webapp/apikey',
              style: TextStyle(color: AppTheme.primaryColor, fontSize: 12, decoration: TextDecoration.underline),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJackettConfig() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Base URL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _jackettUrlController,
            decoration: InputDecoration(
              hintText: 'http://localhost:9117',
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: (_) => setState(() => _jackettTestResult = null),
          ),
          const SizedBox(height: 16),
          const Text('API Key', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _jackettApiKeyController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'Enter Jackett API Key',
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: (_) => setState(() => _jackettTestResult = null),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isTestingJackett ? null : _testJackettConnection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isTestingJackett
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Test Connection', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveJackettSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          if (_jackettTestResult != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _jackettTestResult!.startsWith('✅')
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _jackettTestResult!.startsWith('✅')
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.red.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _jackettTestResult!,
                style: TextStyle(
                  color: _jackettTestResult!.startsWith('✅') ? Colors.green : Colors.red,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProwlarrConfig() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Base URL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _prowlarrUrlController,
            decoration: InputDecoration(
              hintText: 'http://localhost:9696',
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: (_) => setState(() {
              _prowlarrTestResult = null;
              _prowlarrTagsLoaded = false;
              _prowlarrAvailableTags = [];
            }),
          ),
          const SizedBox(height: 16),
          const Text('API Key', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _prowlarrApiKeyController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'Enter Prowlarr API Key',
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: (_) => setState(() {
              _prowlarrTestResult = null;
              _prowlarrTagsLoaded = false;
              _prowlarrAvailableTags = [];
            }),
          ),
          const SizedBox(height: 20),
          const Text('Filter by Tag', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          if (!_prowlarrTagsLoaded) ...[
            Text(
              'Use the Test Connection button to load available tags.',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4)),
            ),
          ] else if (_prowlarrAvailableTags.isEmpty) ...[
            Text(
              'No tags found in Prowlarr. Add tags to your indexers to use this filter.',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4)),
            ),
          ] else ...[
            Text(
              'Limit searches to indexers with the selected tags. Leave all unselected to search all indexers.',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _prowlarrAvailableTags.map((tag) {
                final isSelected = _prowlarrSelectedTagIds.contains(tag.id);
                return FilterChip(
                  label: Text(tag.label),
                  selected: isSelected,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        _prowlarrSelectedTagIds.add(tag.id);
                      } else {
                        _prowlarrSelectedTagIds.remove(tag.id);
                      }
                    });
                  },
                  selectedColor: AppTheme.primaryColor.withValues(alpha: 0.25),
                  checkmarkColor: AppTheme.primaryColor,
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.primaryColor : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : Colors.white.withValues(alpha: 0.2),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                );
              }).toList(),
            ),
            if (_prowlarrSelectedTagIds.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'All indexers will be searched.',
                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4)),
                ),
              ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isTestingProwlarr ? null : _testProwlarrConnection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isTestingProwlarr
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Test Connection', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveProwlarrSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          if (_prowlarrTestResult != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _prowlarrTestResult!.startsWith('✅')
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _prowlarrTestResult!.startsWith('✅')
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.red.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _prowlarrTestResult!,
                style: TextStyle(
                  color: _prowlarrTestResult!.startsWith('✅') ? Colors.green : Colors.red,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _testJackettConnection() async {
    final url = _jackettUrlController.text.trim();
    final apiKey = _jackettApiKeyController.text.trim();

    if (url.isEmpty || apiKey.isEmpty) {
      setState(() => _jackettTestResult = '❌ Please enter both Base URL and API Key');
      return;
    }

    setState(() {
      _isTestingJackett = true;
      _jackettTestResult = null;
    });

    try {
      final result = await _jackett.testConnection(url, apiKey);
      if (mounted) {
        setState(() {
          _jackettTestResult = result.message;
          _isTestingJackett = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _jackettTestResult = '❌ Error: $e';
          _isTestingJackett = false;
        });
      }
    }
  }

  Future<void> _saveJackettSettings() async {
    final url = _jackettUrlController.text.trim();
    final apiKey = _jackettApiKeyController.text.trim();

    await _settings.setJackettBaseUrl(url);
    await _settings.setJackettApiKey(apiKey);

    if (mounted) {
      ForjaToast.success('Jackett settings saved!');
    }
  }

  Future<void> _testProwlarrConnection() async {
    final url = _prowlarrUrlController.text.trim();
    final apiKey = _prowlarrApiKeyController.text.trim();

    if (url.isEmpty || apiKey.isEmpty) {
      setState(() => _prowlarrTestResult = '❌ Please enter both Base URL and API Key');
      return;
    }

    setState(() {
      _isTestingProwlarr = true;
      _prowlarrTestResult = null;
    });

    try {
      final result = await _prowlarr.testConnection(url, apiKey);
      if (result.success) {
        _tryLoadProwlarrTags();
      }
      if (mounted) {
        setState(() {
          _prowlarrTestResult = result.message;
          _isTestingProwlarr = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _prowlarrTestResult = '❌ Error: $e';
          _isTestingProwlarr = false;
        });
      }
    }
  }

  Future<void> _saveProwlarrSettings() async {
    final url = _prowlarrUrlController.text.trim();
    final apiKey = _prowlarrApiKeyController.text.trim();

    await _settings.setProwlarrBaseUrl(url);
    await _settings.setProwlarrApiKey(apiKey);
    await _settings.setProwlarrTagIds(_prowlarrSelectedTagIds.toList());

    if (mounted) {
      ForjaToast.success('Prowlarr settings saved!');
    }
  }

  /// Silently fetch Prowlarr tags; used on init and after a successful test.
  Future<void> _tryLoadProwlarrTags() async {
    final url = _prowlarrUrlController.text.trim();
    final apiKey = _prowlarrApiKeyController.text.trim();
    if (url.isEmpty || apiKey.isEmpty) return;
    try {
      final tags = await _prowlarr.fetchTags(url, apiKey);
      if (mounted) {
        setState(() {
          _prowlarrAvailableTags = tags;
          _prowlarrTagsLoaded = true;
        });
      }
    } catch (_) {
      // Non-fatal — tags section simply not shown until explicit test
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Trakt
  // ═══════════════════════════════════════════════════════════════════════

  void _startTraktLogin() async {
    final data = await _trakt.startDeviceAuth();
    if (data == null) {
      if (mounted) {
        ForjaToast.error('Failed to start Trakt login');
      }
      return;
    }

    final userCode = data['user_code'] as String;
    final verifyUrl = data['verification_url'] as String;
    final interval = (data['interval'] as int?) ?? 5;
    final expiresIn = (data['expires_in'] as int?) ?? 600;
    final deviceCode = data['device_code'] as String;

    setState(() {
      _traktUserCode = userCode;
      _traktVerifyUrl = verifyUrl;
    });

    await Clipboard.setData(ClipboardData(text: userCode));

    // Auto-open the verification URL in the default browser
    final uri = Uri.parse(verifyUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    if (mounted) {
      ForjaToast.success('Code $userCode copied! Opening $verifyUrl...');
    }

    _traktPollTimer?.cancel();
    _traktPollTimer = Timer.periodic(Duration(seconds: interval), (timer) async {
      final result = await _trakt.pollForToken(deviceCode);
      if (result == 'success') {
        timer.cancel();
        // Fetch username
        final profile = await _trakt.getUserProfile();
        final username = profile?['user']?['username']?.toString() ?? profile?['username']?.toString();
        if (mounted) {
          setState(() {
            _traktUserCode = null;
            _traktVerifyUrl = null;
            _isTraktLoggedIn = true;
            _traktUsername = username;
          });
          ForjaToast.success('Logged in to Trakt${username != null ? " as $username" : ""}!');
        }
        // Auto-sync after login
        _syncTrakt();
      } else if (result == 'expired' || result == 'denied') {
        timer.cancel();
        if (mounted) {
          setState(() {
            _traktUserCode = null;
            _traktVerifyUrl = null;
          });
          ForjaToast.error(result == 'denied' ? 'Trakt login denied' : 'Code expired, try again');
        }
      }
      // 'pending' → keep polling
    });

    // Expire timer
    Future.delayed(Duration(seconds: expiresIn), () {
      if (_traktPollTimer?.isActive ?? false) {
        _traktPollTimer?.cancel();
        if (mounted) {
          setState(() {
            _traktUserCode = null;
            _traktVerifyUrl = null;
          });
        }
      }
    });
  }

  void _logoutTrakt() async {
    await _trakt.logout();
    if (mounted) {
      setState(() {
        _isTraktLoggedIn = false;
        _traktUsername = null;
      });
      ForjaToast.success('Logged out of Trakt');
    }
  }

  Future<void> _syncTrakt() async {
    if (_isTraktSyncing) return;
    setState(() => _isTraktSyncing = true);

    try {
      final watchlistCount = await _trakt.importWatchlistToMyList();
      final playbackCount = await _trakt.importPlaybackToWatchHistory();
      final episodesImported = await _trakt.importWatchedEpisodes();
      final exportedCount = await _trakt.exportMyListToWatchlist();
      final episodesExported = await _trakt.exportWatchedEpisodes();

      if (mounted) {
        ForjaToast.success(
          'Trakt sync done! Imported $watchlistCount watchlist, '
          '$playbackCount playback, $episodesImported episodes. '
          'Exported $exportedCount watchlist, $episodesExported episodes.',
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      if (mounted) {
        ForjaToast.error('Trakt sync error: $e');
      }
    } finally {
      if (mounted) setState(() => _isTraktSyncing = false);
    }
  }

  Widget _buildTraktStatsWidget() {
    final stats = _traktStats!;
    final movies = stats['movies'] as Map<String, dynamic>? ?? {};
    final episodes = stats['episodes'] as Map<String, dynamic>? ?? {};
    final moviesWatched = movies['watched'] as int? ?? 0;
    final moviesMinutes = movies['minutes'] as int? ?? 0;
    final epsWatched = episodes['watched'] as int? ?? 0;
    final epsMinutes = episodes['minutes'] as int? ?? 0;
    final totalHours = ((moviesMinutes + epsMinutes) / 60).round();

    Widget stat(IconData icon, String label, String value) {
      return Column(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          stat(Icons.movie_rounded, 'Movies', '$moviesWatched'),
          stat(Icons.tv_rounded, 'Episodes', '$epsWatched'),
          stat(Icons.schedule_rounded, 'Hours', '$totalHours'),
        ],
      ),
    );
  }

  Widget _buildTraktSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sync your watchlist and watch history with Trakt.tv',
            style: TextStyle(fontSize: 13, color: Colors.white54),
          ),
          const SizedBox(height: 16),

          if (_isTraktLoggedIn) ...[
            // ── Logged in ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connected${_traktUsername != null ? " as $_traktUsername" : ""}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const Text('Trakt.tv', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.sync, color: AppTheme.primaryColor, size: 18),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Stats
            if (_traktStats != null) ...[
              _buildTraktStatsWidget(),
              const SizedBox(height: 12),
            ],

            // Sync button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isTraktSyncing ? null : _syncTrakt,
                icon: _isTraktSyncing
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.sync),
                label: Text(_isTraktSyncing ? 'Syncing...' : 'Sync Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Logout button
            ElevatedButton.icon(
              onPressed: _logoutTrakt,
              icon: const Icon(Icons.logout),
              label: const Text('Logout from Trakt'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                foregroundColor: Colors.redAccent,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ] else if (_traktUserCode != null) ...[
            // ── Polling — show code ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'Go to the URL below and enter this code:',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _traktUserCode!,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _traktVerifyUrl ?? 'https://trakt.tv/activate',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(
                    color: AppTheme.primaryColor,
                    backgroundColor: Colors.white10,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Waiting for authorization...',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ] else ...[
            // ── Not logged in ──
            ElevatedButton.icon(
              onPressed: _startTraktLogin,
              icon: const Icon(Icons.login),
              label: const Text('Login with Trakt'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white10,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Simkl
  // ═══════════════════════════════════════════════════════════════════════

  void _startSimklLogin() async {
    final data = await _simkl.requestPin();
    if (data == null) {
      if (mounted) {
        ForjaToast.error('Failed to start Simkl login');
      }
      return;
    }

    final userCode = data['user_code'] as String;
    final verifyUrl = data['verification_url']?.toString() ?? 'https://simkl.com/pin/$userCode';
    final interval = (data['interval'] as int?) ?? 5;
    final expiresIn = (data['expires_in'] as int?) ?? 900;

    setState(() {
      _simklUserCode = userCode;
      _simklVerifyUrl = verifyUrl;
    });

    await Clipboard.setData(ClipboardData(text: userCode));

    final uri = Uri.parse(verifyUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    if (mounted) {
      ForjaToast.success('Code $userCode copied! Opening $verifyUrl...');
    }

    _simklPollTimer?.cancel();
    _simklPollTimer = Timer.periodic(Duration(seconds: interval), (timer) async {
      final token = await _simkl.pollForToken(userCode);
      if (token != null) {
        timer.cancel();
        final profile = await _simkl.getUserProfile();
        final username = profile?['name']?.toString();
        if (mounted) {
          setState(() {
            _simklUserCode = null;
            _simklVerifyUrl = null;
            _isSimklLoggedIn = true;
            _simklUsername = username;
          });
          ForjaToast.success('Logged in to Simkl${username != null ? " as $username" : ""}!');
        }
        _syncSimkl();
      }
    });

    Future.delayed(Duration(seconds: expiresIn), () {
      if (_simklPollTimer?.isActive ?? false) {
        _simklPollTimer?.cancel();
        if (mounted) {
          setState(() {
            _simklUserCode = null;
            _simklVerifyUrl = null;
          });
        }
      }
    });
  }

  void _logoutSimkl() async {
    await _simkl.logout();
    if (mounted) {
      setState(() {
        _isSimklLoggedIn = false;
        _simklUsername = null;
      });
      ForjaToast.success('Logged out of Simkl');
    }
  }

  Future<void> _syncSimkl() async {
    if (_isSimklSyncing) return;
    setState(() => _isSimklSyncing = true);

    try {
      final watchlistCount = await _simkl.importWatchlistToMyList();
      final episodesImported = await _simkl.importWatchedEpisodes();
      final exportedCount = await _simkl.exportMyListToWatchlist();
      final episodesExported = await _simkl.exportWatchedEpisodes();

      if (mounted) {
        ForjaToast.success(
          'Simkl sync done! Imported $watchlistCount watchlist, '
          '$episodesImported episodes. '
          'Exported $exportedCount watchlist, $episodesExported episodes.',
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      if (mounted) {
        ForjaToast.error('Simkl sync error: $e');
      }
    } finally {
      if (mounted) setState(() => _isSimklSyncing = false);
    }
  }

  Widget _buildSimklSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sync your watchlist and watch history with Simkl',
            style: TextStyle(fontSize: 13, color: Colors.white54),
          ),
          const SizedBox(height: 16),

          if (_isSimklLoggedIn) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connected${_simklUsername != null ? " as $_simklUsername" : ""}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const Text('Simkl', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.sync, color: AppTheme.primaryColor, size: 18),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSimklSyncing ? null : _syncSimkl,
                icon: _isSimklSyncing
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.sync),
                label: Text(_isSimklSyncing ? 'Syncing...' : 'Sync Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _logoutSimkl,
              icon: const Icon(Icons.logout),
              label: const Text('Logout from Simkl'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                foregroundColor: Colors.redAccent,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ] else if (_simklUserCode != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'Go to the URL below and enter this code:',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _simklUserCode!,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _simklVerifyUrl ?? 'https://simkl.com/pin',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(
                    color: AppTheme.primaryColor,
                    backgroundColor: Colors.white10,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Waiting for authorization...',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ] else ...[
            ElevatedButton.icon(
              onPressed: _startSimklLogin,
              icon: const Icon(Icons.login),
              label: const Text('Login with Simkl'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white10,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // MDBlist
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _saveMdblistApiKey() async {
    final key = _mdblistApiKeyController.text.trim();
    if (key.isEmpty) {
      if (mounted) {
        ForjaToast.warning('Please enter an API key');
      }
      return;
    }

    await _mdblist.setApiKey(key);

    // Validate by fetching user info
    final info = await _mdblist.getUserInfo();
    if (info != null) {
      if (mounted) {
        setState(() {
          _isMdblistConfigured = true;
          _mdblistUsername = info['name']?.toString();
        });
        ForjaToast.success('MDBlist connected${_mdblistUsername != null ? " as $_mdblistUsername" : ""}!');
      }
    } else {
      await _mdblist.logout();
      if (mounted) {
        setState(() {
          _isMdblistConfigured = false;
          _mdblistUsername = null;
        });
        ForjaToast.error('Invalid MDBlist API key');
      }
    }
  }

  void _logoutMdblist() async {
    await _mdblist.logout();
    if (mounted) {
      setState(() {
        _isMdblistConfigured = false;
        _mdblistUsername = null;
        _mdblistApiKeyController.clear();
      });
      ForjaToast.success('MDBlist API key removed');
    }
  }

  Widget _buildMdblistSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aggregated ratings from IMDb, TMDB, Trakt, Letterboxd, RT, and more',
            style: TextStyle(fontSize: 13, color: Colors.white54),
          ),
          const SizedBox(height: 16),

          if (_isMdblistConfigured) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connected${_mdblistUsername != null ? " as $_mdblistUsername" : ""}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const Text('MDBlist', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _logoutMdblist,
              icon: const Icon(Icons.logout),
              label: const Text('Remove API Key'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                foregroundColor: Colors.redAccent,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ] else ...[
            TextField(
              controller: _mdblistApiKeyController,
              decoration: InputDecoration(
                labelText: 'MDBlist API Key',
                hintText: 'Paste your API key from mdblist.com',
                labelStyle: const TextStyle(color: Colors.white54),
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: Colors.white),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _saveMdblistApiKey,
              icon: const Icon(Icons.save),
              label: const Text('Save API Key'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildListsSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Browse and manage your Trakt and MDBlist custom lists',
            style: TextStyle(fontSize: 13, color: Colors.white54),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const ListsScreen(),
              )),
              icon: const Icon(Icons.list_alt_rounded),
              label: const Text('Manage Lists'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateChecker() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Check for new versions of Forja',
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isCheckingUpdate ? null : _checkForUpdates,
              icon: _isCheckingUpdate
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.system_update_rounded),
              label: Text(
                _isCheckingUpdate ? 'Checking...' : 'Check for Updates',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _checkForUpdates() async {
    setState(() => _isCheckingUpdate = true);
    
    try {
      final updateInfo = await _updater.checkForUpdates();
      
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
        
        if (updateInfo != null) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => UpdateDialog(updateInfo: updateInfo),
          );
        } else {
          ForjaToast.success("You're running the latest version!");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
        ForjaToast.error('Failed to check for updates: $e');
      }
    }
  }

  Widget _buildProviderScoringSection() {
    final streamCatalog = <String, String>{
      for (final entry in {
        ...StreamProviders.providers,
        ..._nuvioProviderEntries,
      }.entries)
        entry.key: (entry.value['name'] as String?) ?? entry.key,
    };
    final streamOrder = <String>[
      ..._streamProviderOrder.where(streamCatalog.containsKey),
      ...streamCatalog.keys.where((k) => !_streamProviderOrder.contains(k)),
    ];
    final animeCatalog = AnimeStreamProviders.catalog;
    final animeOrder = SettingsService.mergeProviderOrder(
      _animeProviderOrder,
      animeCatalog.keys,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Source scoring',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Drag to set baseline order. Domain scores may adjust each provider '
            'by up to ±2 positions before checking. Stream quality is scored '
            'after resolve.',
            style: TextStyle(fontSize: 13, color: Colors.white54),
          ),
          const SizedBox(height: 16),
          ProviderPriorityTable(
            domain: SourceDomain.movies,
            title: 'Films',
            subtitle: 'Webstreaming providers for movies.',
            catalog: streamCatalog,
            order: streamOrder,
            onOrderChanged: (next) async {
              setState(() => _streamProviderOrder = next);
              await _settings.setStreamProviderOrder(next);
            },
            onReset: () async {
              final defaults =
                  List<String>.from(SettingsService.defaultStreamProviderOrder);
              await _settings.setStreamProviderOrder(defaults);
              setState(() => _streamProviderOrder = defaults);
            },
          ),
          const SizedBox(height: 20),
          ProviderPriorityTable(
            domain: SourceDomain.series,
            title: 'Series',
            subtitle: 'Same baseline list as films; series domain scores differ.',
            catalog: streamCatalog,
            order: streamOrder,
            onOrderChanged: (next) async {
              setState(() => _streamProviderOrder = next);
              await _settings.setStreamProviderOrder(next);
            },
            onReset: () async {
              final defaults =
                  List<String>.from(SettingsService.defaultStreamProviderOrder);
              await _settings.setStreamProviderOrder(defaults);
              setState(() => _streamProviderOrder = defaults);
            },
          ),
          const SizedBox(height: 20),
          ProviderPriorityTable(
            domain: SourceDomain.anime,
            title: 'Anime',
            subtitle: 'Anime player source baseline and effective order.',
            catalog: animeCatalog,
            order: animeOrder,
            onOrderChanged: (next) async {
              setState(() => _animeProviderOrder = next);
              await _settings.setAnimeProviderOrder(next);
            },
            onReset: () async {
              final defaults =
                  List<String>.from(SettingsService.defaultAnimeProviderOrder);
              await _settings.setAnimeProviderOrder(defaults);
              setState(() => _animeProviderOrder = defaults);
            },
          ),
          const SizedBox(height: 20),
          ProviderPriorityTable(
            domain: SourceDomain.asianDrama,
            title: 'Asian Drama',
            subtitle: 'Single KissKH source today — same pipeline as other types.',
            catalog: const {'kisskh': 'KissKH'},
            order: const ['kisskh'],
            onOrderChanged: (_) {},
            onReset: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildFocusableToggle(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.white54)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppTheme.current.primaryColor,
          ),
        ],
      ),
    );
    return shellFocusableTap(
      context: context,
      onTap: () => onChanged(!value),
      scaleOnFocus: 1.0,
      navLeftAlways: true,
      tvTabId: 'settings',
      tvZone: ShellTvZone.settings,
      child: content,
    );
  }

  Widget _buildFocusableDropdown(String title, String subtitle, String value, List<String> options, ValueChanged<String?> onChanged) {
    final content = Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.white54)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButton<String>(
                value: value,
                dropdownColor: Color.lerp(AppTheme.current.bgDark, AppTheme.current.primaryColor, 0.08),
                underline: const SizedBox.shrink(),
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.current.primaryColor),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                selectedItemBuilder: (BuildContext context) {
                  return options.map<Widget>((String item) {
                    return Container(
                      alignment: Alignment.centerLeft,
                      child: Text(item, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    );
                  }).toList();
                },
                items: options.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(color: Colors.white)))).toList(),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
    );
    return shellFocusableTap(
      context: context,
      onTap: () {},
      scaleOnFocus: 1.0,
      navLeftAlways: true,
      tvTabId: 'settings',
      tvZone: ShellTvZone.settings,
      child: content,
    );
  }
}
