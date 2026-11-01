// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsCategoryProfileTitle => 'Profile & account';

  @override
  String get settingsCategoryProfileSubtitle => 'Profile, cloud sync, sign in';

  @override
  String get settingsCategoryAddonsTitle => 'Addons';

  @override
  String get settingsCategoryAddonsSubtitle =>
      'Playback, IPTV, torrents, Stremio, debrid, LAN';

  @override
  String get settingsCategoryPacksTitle => 'Forja Packs';

  @override
  String get settingsCategoryPacksSubtitle => 'Install and manage plugin packs';

  @override
  String get settingsCategoryFeaturesTitle => 'Features';

  @override
  String get settingsCategoryFeaturesSubtitle => 'Tabs, order, default menu';

  @override
  String get settingsCategoryDownloadsTitle => 'Downloads';

  @override
  String get settingsCategoryDownloadsSubtitle =>
      'Offline library and download progress';

  @override
  String get settingsCategoryDataTitle => 'Data & backup';

  @override
  String get settingsCategoryDataSubtitle => 'Clear cache, export, import';

  @override
  String get settingsCategoryAboutTitle => 'About';

  @override
  String get settingsCategoryAboutSubtitle => 'Updates, version, developer';

  @override
  String get settingsLanguageGroupLabel => 'Language';

  @override
  String get settingsLanguageRowTitle => 'App language';

  @override
  String get settingsLanguageRowSubtitle =>
      'Menus and screens change right away. Titles, descriptions and pack text catch up fully after a restart.';

  @override
  String get settingsLanguageSystemDefault => 'System default';

  @override
  String get addonsHostDebridGroupLabel => 'Debrid';

  @override
  String get addonsHostDebridResolveTitle => 'Resolve magnets with debrid';

  @override
  String get addonsHostDebridResolveSubtitle =>
      'Use an installed debrid pack plugin for torrent magnets.';

  @override
  String get addonsHostDebridPluginTitle => 'Magnet resolve plugin';

  @override
  String get addonsHostDebridPluginSubtitle =>
      'Only one debrid plugin can be active.';

  @override
  String get addonsHostPlayTogglesGroupLabel => 'Forja addons';

  @override
  String get addonsHostPlayTogglesP2pAckedTitle =>
      'You are aware of P2P streaming';

  @override
  String get addonsHostPlayTogglesP2pConfirmTitle =>
      'Confirm you are aware of P2P streaming';

  @override
  String get addonsHostPlayTogglesP2pAckedSubtitle =>
      'Direct torrent, Stremio, and Nuvio can be used. Tap to review.';

  @override
  String get addonsHostPlayTogglesP2pConfirmSubtitle =>
      'Required once before turning on Direct torrent, Stremio, or Nuvio.';

  @override
  String get addonsHostPlayTogglesTorrentTitle => 'Direct torrent';

  @override
  String get addonsHostPlayTogglesTorrentNativeSubtitle =>
      'Search Forja indexers (Jackett / Prowlarr) below.';

  @override
  String get addonsHostPlayTogglesTorrentAtvSubtitle =>
      'Search torrents here. Playing a magnet needs a paired desktop (Settings → LAN).';

  @override
  String get addonsHostPlayTogglesStremioTitle => 'Stremio';

  @override
  String get addonsHostPlayTogglesStremioNativeSubtitle =>
      'Play from installed Stremio addon streams.';

  @override
  String get addonsHostPlayTogglesNuvioTitle => 'Nuvio';

  @override
  String get addonsHostPlayTogglesNuvioNativeSubtitle =>
      'Play from installed Nuvio scraper addons below.';

  @override
  String get addonsHostPlayTogglesDirectHttpAtvSubtitle =>
      'Direct HTTP plays on this TV. Magnets need a paired desktop (Settings → LAN).';

  @override
  String get addonsHostMdblistEnterKeyWarning => 'Please enter an API key';

  @override
  String get addonsHostMdblistConnectedToast => 'MDBlist connected!';

  @override
  String addonsHostMdblistConnectedAsToast(String username) {
    return 'MDBlist connected as $username!';
  }

  @override
  String get addonsHostMdblistInvalidKeyError => 'Invalid MDBlist API key';

  @override
  String get addonsHostMdblistKeyRemovedToast => 'MDBlist API key removed';

  @override
  String get addonsHostMdblistIntro =>
      'Aggregated ratings from IMDb, TMDB, Trakt, Letterboxd, RT, and more';

  @override
  String get addonsHostMdblistConnectedStatus => 'Connected';

  @override
  String addonsHostMdblistConnectedAsStatus(String username) {
    return 'Connected as $username';
  }

  @override
  String get addonsHostMdblistRemoveKeyButton => 'Remove API Key';

  @override
  String get addonsHostMdblistKeyLabel => 'MDBlist API Key';

  @override
  String get addonsHostMdblistKeyHint => 'Paste your API key from mdblist.com';

  @override
  String get addonsHostMdblistSaveKeyButton => 'Save API Key';

  @override
  String get addonsHostPlayerGroupLabel => 'Player';

  @override
  String get addonsHostPlaybackEngineTitle => 'Movies & series engine';

  @override
  String get addonsHostPlaybackEngineSubtitle =>
      'Used for Home, Search, Anime, Asian Drama, and IPTV Movies/Series. Live IPTV has its own setting under IPTV.';

  @override
  String get addonsHostPlaybackAudioLangTitle => 'Preferred Audio Language';

  @override
  String get addonsHostPlaybackAudioLangSubtitle =>
      'Switch to a matching audio track when playback starts. Pick \"None\" to keep the stream default.';

  @override
  String get addonsHostPlaybackSubtitleLangTitle =>
      'Preferred Subtitle Language';

  @override
  String get addonsHostPlaybackSubtitleLangSubtitle =>
      'Prefer this language for in-stream or online subtitles. In-stream tracks win when they match. Pick \"None\" to start with subs off.';

  @override
  String get addonsHostPlaybackAvoidAudioTitle =>
      'Avoid unsupported audio (Atmos / TrueHD / 7.1)';

  @override
  String get addonsHostPlaybackAvoidAudioSubtitle =>
      'Fall back to AC-3, E-AC-3, or AAC when Atmos, TrueHD, or 7.1 is not supported.';

  @override
  String get addonsHostPlaybackAutoNextTitle => 'Auto next episode';

  @override
  String get addonsHostPlaybackAutoNextSubtitle =>
      'Start the next episode when one ends. Also available in the player Episodes panel.';

  @override
  String get addonsHostPlaybackAutoSkipIntroTitle => 'Auto skip intro';

  @override
  String get addonsHostPlaybackAutoSkipIntroSubtitle =>
      'Skip intro and recap segments automatically when timestamps are available.';

  @override
  String get addonsHostPlaybackContentWarningsTitle => 'Content warnings';

  @override
  String get addonsHostPlaybackContentWarningsSubtitle =>
      'Show IMDb content ratings (nudity, violence, and similar) when playback starts.';

  @override
  String get addonsHostPlaybackBackgroundTitle => 'Play in background';

  @override
  String get addonsHostPlaybackBackgroundDesktopSubtitle =>
      'Keep movies, series, and IPTV playing when Forja is in the background.';

  @override
  String get addonsHostPlaybackBackgroundMobileSubtitle =>
      'Keep movies, series, and IPTV playing when Forja is in the background. (playback pauses until you return).';

  @override
  String get addonsHostPlaybackRemoteSoundsTitle => 'Remote click sounds';

  @override
  String get addonsHostPlaybackRemoteSoundsSubtitle =>
      'Play a short system click when you move D-pad focus or press OK. Off while a video is playing.';

  @override
  String get addonsHostPlaybackAutoPipTitle => 'Auto picture-in-picture';

  @override
  String get addonsHostPlaybackAutoPipSubtitle =>
      'Enter picture-in-picture when you switch Space (macOS) or virtual desktop (Windows) while playing. You can still use the player PiP button anytime.';

  @override
  String get addonsHostPlaybackMiniPlayerTitle => 'Escape to mini player';

  @override
  String get addonsHostPlaybackMiniPlayerSubtitle =>
      'When Escape would leave the player, demote to the in-app mini instead. Off by default. The top-right mini button always works. Distinct from picture-in-picture.';

  @override
  String get addonsHostPlaybackMaxQualityTitle => 'Max stream quality';

  @override
  String get addonsHostPlaybackMaxQualitySubtitle =>
      'Limit Auto stream quality and HLS start bitrate. Auto aims for a faster first frame. Pick 4K for the highest ladder.';

  @override
  String get addonsHostPortalEngineTitle => 'IPTV engine';

  @override
  String get addonsHostPortalEngineAndroidSubtitle =>
      'Live channels only. Does not change Movies & series or Live Sports.';

  @override
  String get addonsHostPortalEngineDesktopSubtitle =>
      'Live channels only. HLS prefers AVPlayer (Mac) or VLC (Windows) when available; MPEG-TS uses MediaKit.';

  @override
  String get addonsHostPortalEpgTitle => 'IPTV programme guide (EPG)';

  @override
  String get addonsHostPortalEpgSubtitle =>
      'Show NOW and NEXT programme info in the player and channel browser.';

  @override
  String get addonsHostPortalMaxQualityTitle => 'IPTV live max quality';

  @override
  String get addonsHostPortalMaxQualitySubtitle =>
      'ExoPlayer only. Auto uses the portal’s full quality. Cap at 1080p, 720p, or 480p only on weak devices.';

  @override
  String get addonsHostPortalRecoveryTitle => 'IPTV live recovery';

  @override
  String get addonsHostPortalRecoverySubtitle =>
      'ExoPlayer only. How live channels reconnect after a stall. Auto picks per source. Stable forces one policy. Classic uses freeze timers. MediaKit ignores this (ffmpeg reconnect). Applies the next time you open the player.';

  @override
  String get addonsHostPortalReopenStallTitle => 'Reopen on buffer stall';

  @override
  String get addonsHostPortalReopenStallSubtitle =>
      'ExoPlayer Stable mode only. Reconnect when the picture freezes even if cache still reports data. Leave off unless you need it. Applies the next time you open the player.';

  @override
  String get addonsHostPortalMatchRefreshTitle => 'IPTV match display refresh';

  @override
  String get addonsHostPortalMatchRefreshSubtitle =>
      'MediaKit only. Match the TV refresh rate to the channel (for example 50 Hz for 50 fps). Helps 4K stutter. May briefly blink HDMI after the first frame. Applies the next time you open the player.';

  @override
  String get addonsHostPortalLiveBufferTitle => 'IPTV live buffer';

  @override
  String get addonsHostPortalLiveBufferSubtitle =>
      'MediaKit only. Live buffer ahead of playback. Auto uses 30s (same as desktop). Manual 15–30s. Helps underruns, not frame judder. Applies the next time you open the player.';

  @override
  String get addonsHostTorrentSearchGroupLabel => 'Torrent search';

  @override
  String get addonsHostTorrentInstallPackHint =>
      'Install the ForjaHQ Torrent pack under Settings → Forja Packs and enable indexers per plugin.';

  @override
  String get addonsHostTorrentSortTitle => 'Default Sort Order';

  @override
  String get addonsHostTorrentSortSubtitle =>
      'How torrent results are sorted automatically.';

  @override
  String get addonsHostTorrentFlareSolverrNote =>
      'UIndex is behind Cloudflare. Point this at a local FlareSolverr or Byparr instance (same /v1 API as Prowlarr indexers).';

  @override
  String get addonsHostTorrentEngineGroupLabel => 'Torrent engine';

  @override
  String addonsHostTorrentDiskCacheTitle(int gb) {
    return 'Disk cache: $gb GB';
  }

  @override
  String get addonsHostTorrentDiskCacheSubtitle =>
      'Max torrent data on disk. The file playing now is never deleted. Oldest idle downloads are removed when over this size.';

  @override
  String addonsHostTorrentGbLabel(int gb) {
    return '$gb GB';
  }

  @override
  String addonsHostTorrentConnectionsTitle(int count) {
    return 'Connections per torrent: $count';
  }

  @override
  String get addonsHostTorrentConnectionsSubtitle =>
      'Lower (5–25) often streams better on high-seed swarms.';

  @override
  String get addonsHostSimklLoginUnavailableError =>
      'Simkl login isn’t available in this build';

  @override
  String get addonsHostSimklLoginStartFailedError =>
      'Failed to start Simkl login';

  @override
  String addonsHostSimklCodeCopiedToast(String code, String url) {
    return 'Code $code copied. Opening $url…';
  }

  @override
  String get addonsHostSimklLoggedInToast => 'Logged in to Simkl!';

  @override
  String addonsHostSimklLoggedInAsToast(String username) {
    return 'Logged in to Simkl as $username!';
  }

  @override
  String get addonsHostSimklLoggedOutToast => 'Logged out of Simkl';

  @override
  String get addonsHostSimklPickSyncModeError => 'Pick how lists sync first';

  @override
  String addonsHostSimklSyncError(String error) {
    return 'Simkl sync error: $error';
  }

  @override
  String get addonsHostSimklSyncedKeptLocal => 'Kept local';

  @override
  String get addonsHostSimklSyncedUsedSimkl => 'Used Simkl';

  @override
  String get addonsHostSimklSyncedMerged => 'Merged';

  @override
  String get addonsHostSimklSyncedMergedDeleted => 'Merged + deleted';

  @override
  String get addonsHostSimklSyncedGeneric => 'Synced';

  @override
  String addonsHostSimklSyncSummaryToast(
    String mode,
    int listExported,
    int listImported,
    String removed,
    int progress,
    int movies,
    int epsExported,
    int epsImported,
  ) {
    return '$mode · list ↑$listExported ↓$listImported$removed, progress $progress, movies $movies, eps ↑$epsExported ↓$epsImported';
  }

  @override
  String get addonsHostSimklIntro =>
      'Sync your watchlist and watch history with Simkl';

  @override
  String get addonsHostSimklConnectedStatus => 'Connected';

  @override
  String addonsHostSimklConnectedAsStatus(String username) {
    return 'Connected as $username';
  }

  @override
  String get addonsHostSimklSyncModeTitle => 'How should lists sync?';

  @override
  String get addonsHostSimklSyncModeSubtitleAuto =>
      'Saved for Sync Now and Auto sync on My List';

  @override
  String get addonsHostSimklSyncModeSubtitle => 'Saved for Sync Now';

  @override
  String get addonsHostSimklAutoSyncTitle => 'Auto sync lists on My List';

  @override
  String addonsHostSimklAutoSyncSubtitle(String mode) {
    return 'When you open My List, sync with $mode and refresh the cached library';
  }

  @override
  String get addonsHostSimklSyncingButton => 'Syncing...';

  @override
  String get addonsHostSimklSyncNowButton => 'Sync Now';

  @override
  String get addonsHostSimklLogoutButton => 'Logout from Simkl';

  @override
  String get addonsHostSimklEnterCodePrompt =>
      'Go to the URL below and enter this code:';

  @override
  String get addonsHostSimklWaitingAuth => 'Waiting for authorization...';

  @override
  String get addonsHostSimklLoginButton => 'Login with Simkl';

  @override
  String get addonsHostLanUnpairButton => 'Unpair';

  @override
  String get addonsHostLanRemoveTorrentError => 'Could not remove torrent';

  @override
  String get addonsHostLanRemoveTorrentToast => 'Removed torrent cache entry';

  @override
  String get addonsHostLanClearCacheError => 'Could not clear torrent cache';

  @override
  String get addonsHostLanClearCacheToast => 'Torrent cache cleared';

  @override
  String get addonsHostLanServerStartFailedError =>
      'Failed to start LAN server';

  @override
  String addonsHostLanServerStartFailedDetailError(String detail) {
    return 'Failed to start LAN server: $detail';
  }

  @override
  String get addonsHostLanNoDesktopFoundInfo =>
      'No desktop found. Enter the IP and port from Settings → LAN on the desktop.';

  @override
  String get addonsHostLanEnterPairDetailsInfo =>
      'Enter desktop address, port, and 6-digit code';

  @override
  String get addonsHostLanPairFailedError =>
      'Pairing failed. Check the code, IP, and that desktop LAN is on.';

  @override
  String get addonsHostLanPairedToast =>
      'Paired. Enable Direct torrent in Settings → Playback.';

  @override
  String get addonsHostLanCodeCopiedToast => 'Code copied';

  @override
  String get addonsHostLanAddressCopiedToast => 'Address copied';

  @override
  String addonsHostLanPortOnlyLabel(int port) {
    return 'port $port';
  }

  @override
  String addonsHostLanAddressMoreLabel(String address, int more) {
    return '$address (+$more more)';
  }

  @override
  String get addonsHostLanIntroDesktop =>
      'Turn this PC into a Forja LAN server. Pair TVs and phones once. They pick torrents; this desktop downloads and streams.';

  @override
  String get addonsHostLanIntroClient =>
      'Pair once with a desktop Forja on the same Wi‑Fi. After that, torrent sources on this device play through the desktop.';

  @override
  String get addonsHostLanEnableServerTitle => 'Enable LAN server';

  @override
  String addonsHostLanListeningSubtitle(String address) {
    return 'Listening · $address';
  }

  @override
  String get addonsHostLanServerOffSubtitle =>
      'Off. TVs cannot use this desktop for torrents';

  @override
  String get addonsHostLanDesktopAddressHeader => 'DESKTOP ADDRESS';

  @override
  String get addonsHostLanDesktopAddressHint =>
      'On the TV: Settings → LAN → enter this IP and port if Discover does not find this PC.';

  @override
  String addonsHostLanNoIpDetected(int port) {
    return 'Port $port. Could not detect a LAN IP. Check Wi‑Fi or Ethernet.';
  }

  @override
  String get addonsHostLanPairingCodeHeader => 'PAIRING CODE';

  @override
  String get addonsHostLanPairingCodeHint =>
      'On the TV: Settings → LAN → enter this code (valid ~5 minutes, one use).';

  @override
  String get addonsHostLanCopyTooltip => 'Copy';

  @override
  String get addonsHostLanNewCodeTooltip => 'New code';

  @override
  String get addonsHostLanPairedDevicesHeader => 'PAIRED DEVICES';

  @override
  String get addonsHostLanReloadDevicesTooltip => 'Reload paired devices';

  @override
  String get addonsHostLanNoDevicesPaired => 'No TVs or phones paired yet.';

  @override
  String get addonsHostLanRevokeHint =>
      'Revoke to force that device to pair again.';

  @override
  String get addonsHostLanWaitingForDevice =>
      'Waiting for a device to enter the code…';

  @override
  String get addonsHostLanDeviceFallback => 'Device';

  @override
  String get addonsHostLanRevokeButton => 'Revoke';

  @override
  String get addonsHostLanTorrentActivityHeader => 'TORRENT ACTIVITY';

  @override
  String get addonsHostLanClearAllButton => 'Clear all';

  @override
  String get addonsHostLanTorrentActivityHint =>
      'Torrents opened by paired TVs/phones. Delete removes the cached download.';

  @override
  String addonsHostLanCacheOnDisk(String size) {
    return 'Cache on disk: $size';
  }

  @override
  String get addonsHostLanActiveTorrentFallback => 'Active torrent';

  @override
  String get addonsHostLanNoTorrentsYet =>
      'No LAN torrents yet. Play one from a paired TV.';

  @override
  String get addonsHostLanServingNow => 'Serving now (not yet in history).';

  @override
  String addonsHostLanPeersChip(int count) {
    return '$count peers';
  }

  @override
  String get addonsHostLanDeleteCachedTooltip => 'Delete cached download';

  @override
  String get addonsHostLanPairedStatus => 'Paired';

  @override
  String get addonsHostLanNotPairedStatus => 'Not paired';

  @override
  String get addonsHostLanDesktopOnline => 'Desktop online';

  @override
  String get addonsHostLanDesktopOffline => 'Desktop offline';

  @override
  String get addonsHostLanPlayingStatus => 'playing';

  @override
  String addonsHostLanPairedAddressNote(String host, String port) {
    return '$host:$port. Torrents play via desktop.';
  }

  @override
  String get addonsHostLanPairOnceNote =>
      'Pair once. Then open Sources → Torrents on a title.';

  @override
  String get addonsHostLanReloadStatusTooltip => 'Reload desktop status';

  @override
  String get addonsHostLanFindDesktopHeader => 'FIND DESKTOP';

  @override
  String get addonsHostLanSearchingButton => 'Searching…';

  @override
  String get addonsHostLanDiscoverButton => 'Discover on Wi‑Fi';

  @override
  String addonsHostLanPortValue(int port) {
    return 'Port $port';
  }

  @override
  String get addonsHostLanUseButton => 'Use';

  @override
  String get addonsHostLanEnterManuallyHeader => 'OR ENTER MANUALLY';

  @override
  String get addonsHostLanDesktopIpLabel => 'Desktop IP';

  @override
  String get addonsHostLanPortLabel => 'Port';

  @override
  String get addonsHostLanPortHint =>
      'Shown under Enable LAN server on desktop';

  @override
  String get addonsHostLanCodeLabel => '6-digit code';

  @override
  String get addonsHostLanCodeHint => 'From desktop Settings → LAN';

  @override
  String get addonsHostLanPairButton => 'Pair with desktop';

  @override
  String get addonsHostLanLocalTorrentTitle =>
      'Allow local torrent on this device';

  @override
  String get addonsHostLanLocalTorrentSubtitle =>
      'Advanced. Use the on-device engine instead of the desktop. Leave off on TV.';

  @override
  String get addonsHostProvStremioGroupLabel => 'Stremio addons';

  @override
  String get addonsHostProvNuvioGroupLabel => 'Nuvio addons';

  @override
  String get addonsHostProvAddonInstalledToast => 'Addon installed';

  @override
  String get addonsHostProvInstallFailedError =>
      'Failed to install addon. Check URL.';

  @override
  String addonsHostProvGenericError(String error) {
    return 'Error: $error';
  }

  @override
  String get addonsHostProvAddonRemovedToast => 'Addon removed';

  @override
  String get addonsHostProvInstallStremioLabel => 'Install Stremio Addon';

  @override
  String get addonsHostProvInstallButton => 'Install';

  @override
  String get addonsHostProvInstalledAddonsLabel => 'Installed addons';

  @override
  String get addonsHostProvUntitledAddon => 'Untitled addon';

  @override
  String get addonsHostProvSourcesChip => 'Sources';

  @override
  String get addonsHostProvInstallNuvioLabel => 'Install Nuvio Addon';

  @override
  String addonsHostProvNuvioInstalledToast(String name, int count) {
    return 'Installed $name ($count scrapers)';
  }

  @override
  String addonsHostProvInstallFailedDetailError(String error) {
    return 'Install failed: $error';
  }

  @override
  String get addonsHostProvNuvioRemovedToast => 'Nuvio addon removed';

  @override
  String get addonsHostProvBaseUrlLabel => 'Base URL';

  @override
  String get addonsHostProvApiKeyLabel => 'API Key';

  @override
  String get addonsHostProvJackettApiKeyHint => 'Enter Jackett API Key';

  @override
  String get addonsHostProvProwlarrApiKeyHint => 'Enter Prowlarr API Key';

  @override
  String get addonsHostProvTestConnectionButton => 'Test Connection';

  @override
  String get addonsHostProvSaveButton => 'Save';

  @override
  String get addonsHostProvFilterByTagLabel => 'Filter by tag';

  @override
  String get addonsHostProvLoadTagsHint =>
      'Use the Test Connection button to load available tags.';

  @override
  String get addonsHostProvNoTagsFound =>
      'No tags found in Prowlarr. Add tags to your indexers to use this filter.';

  @override
  String get addonsHostProvTagFilterHint =>
      'Limit searches to indexers with the selected tags. Leave all unselected to search all indexers.';

  @override
  String get addonsHostProvAllIndexersSearched =>
      'All indexers will be searched.';

  @override
  String get addonsHostProvEnterUrlAndKeyResult =>
      '❌ Please enter both Base URL and API Key';

  @override
  String addonsHostProvTestErrorResult(String error) {
    return '❌ Error: $error';
  }

  @override
  String get addonsHostProvJackettSavedToast => 'Jackett settings saved';

  @override
  String get addonsHostProvProwlarrSavedToast => 'Prowlarr settings saved';

  @override
  String get addonsHostProvScraperFallback => 'Scraper';

  @override
  String addonsHostProvNuvioLeanSubtitle(String version) {
    return 'Expand to download scrapers · v$version';
  }

  @override
  String addonsHostProvNuvioScrapersSubtitle(int count, String version) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count scrapers · v$version',
      one: '1 scraper · v$version',
    );
    return '$_temp0';
  }

  @override
  String addonsHostProvNuvioLoadedToast(String name, int count) {
    return 'Loaded $name ($count scrapers)';
  }

  @override
  String get addonsHostProvDownloadingScrapers => 'Downloading scrapers…';

  @override
  String get addonsHostProvLoadScrapersFailed => 'Could not load scrapers';

  @override
  String get addonsHostProvRetryButton => 'Retry';

  @override
  String get addonsHostProvRemoveConfirmTitle => 'Remove this addon?';

  @override
  String get addonsHostProvYesTooltip => 'Yes';

  @override
  String get addonsHostProvNoTooltip => 'No';

  @override
  String get addonsHostProvRemoveAddonTooltip => 'Remove addon';

  @override
  String get aboutUpdatesGroupLabel => 'Updates';

  @override
  String get aboutPrivacyGroupLabel => 'Privacy';

  @override
  String get aboutDeveloperGroupLabel => 'Developer';

  @override
  String get aboutVerifySentryTitle => 'Verify Sentry';

  @override
  String get aboutVerifySentrySubtitleActive =>
      'Send a test exception to the Forja Flutter project';

  @override
  String get aboutVerifySentrySubtitleInactive =>
      'Enable Crash reporting first, then tap again';

  @override
  String get aboutVerifySentrySent => 'Test event sent - check Sentry Issues';

  @override
  String get aboutVerifyPostHogTitle => 'Verify PostHog';

  @override
  String get aboutVerifyPostHogSubtitleActive =>
      'Send analytics_verify to your PostHog project';

  @override
  String get aboutVerifyPostHogSubtitleInactive =>
      'Enable Product analytics first, then tap again';

  @override
  String get aboutVerifyPostHogSent =>
      'Test event sent - check PostHog → Activity';

  @override
  String get aboutCheckForUpdatesBlurb => 'Check for new versions of Forja';

  @override
  String get aboutCheckingButton => 'Checking...';

  @override
  String get aboutCheckForUpdatesButton => 'Check for Updates';

  @override
  String get aboutCheckForUpdatesFailed => 'Could not check for updates.';

  @override
  String get aboutUpToDate => 'You\'re on the latest version';

  @override
  String aboutCheckForUpdatesError(String error) {
    return 'Failed to check for updates: $error';
  }

  @override
  String get aboutCrashReportingTitle => 'Crash reporting';

  @override
  String get aboutTelemetryDebugSubtitle =>
      'Inactive in debug builds. Your choice is saved for release.';

  @override
  String get aboutTelemetryUnavailableSubtitle =>
      'Not available in this build. Your choice is still saved.';

  @override
  String get aboutCrashReportingSubtitle =>
      'Sends crash details so we can fix bugs. No passwords or stream links.';

  @override
  String get aboutCrashReportingSavedDebug =>
      'Saved. Crash reporting stays off in debug builds.';

  @override
  String get aboutCrashReportingUnavailable =>
      'Crash reporting is not available in this build yet.';

  @override
  String get aboutCrashReportingOn => 'Crash reporting on';

  @override
  String get aboutCrashReportingOff => 'Crash reporting off';

  @override
  String get aboutCrashReportingUpdateFailed =>
      'Could not update crash reporting';

  @override
  String get aboutProductAnalyticsTitle => 'Product analytics';

  @override
  String get aboutProductAnalyticsSubtitle =>
      'Shares how you use Forja so we can improve it.';

  @override
  String get aboutProductAnalyticsSavedDebug =>
      'Saved. Product analytics stays off in debug builds.';

  @override
  String get aboutProductAnalyticsUnavailable =>
      'Product analytics is not available in this build yet.';

  @override
  String get aboutProductAnalyticsOn => 'Product analytics on';

  @override
  String get aboutProductAnalyticsOff => 'Product analytics off';

  @override
  String get aboutProductAnalyticsUpdateFailed =>
      'Could not update product analytics';

  @override
  String get aboutKeychainRowTitle => 'Store secrets in Keychain';

  @override
  String get aboutKeychainRowSubtitle =>
      'Off by default (local app file). Turn on to use the macOS Keychain. Forja explains first; the system may ask for your password once.';

  @override
  String get aboutKeychainEnabled => 'Keychain enabled for secrets';

  @override
  String get aboutKeychainLocalStorage => 'Using local file storage';

  @override
  String get aboutKeychainConsentTitle => 'Use macOS Keychain?';

  @override
  String get aboutKeychainConsentBodyStore =>
      'Forja can store login tokens and API keys in the macOS Keychain instead of a local app file.';

  @override
  String get aboutKeychainConsentBodyPrompt =>
      'After you allow this, macOS may show its own password dialog once. It may mention \"flutter_secure_storage_service\". That name is Forja’s secure vault, not a separate app. Choose Always Allow if you trust Forja.';

  @override
  String get aboutKeychainConsentBodyLocal =>
      'You can keep using local file storage (default) with no Keychain prompts.';

  @override
  String get aboutKeychainConsentKeepLocal => 'Keep local file';

  @override
  String get aboutKeychainConsentUseKeychain => 'Use Keychain';

  @override
  String get addonsPlaybackTitle => 'Playback';

  @override
  String get addonsPlaybackSubtitle => 'Quality, audio, auto-play';

  @override
  String get addonsTorrentTitle => 'Direct torrent';

  @override
  String get addonsTorrentSubtitle => 'Jackett, Prowlarr, torrent engine';

  @override
  String get addonsStremioSubtitle => 'Stremio addons';

  @override
  String get addonsNuvioSubtitle => 'Nuvio scrapers';

  @override
  String get addonsConnectedServicesTitle => 'Connected services';

  @override
  String get addonsConnectedServicesSubtitle => 'Simkl; MDBlist (admin)';

  @override
  String get addonsLanSubtitle => 'Desktop server, pairing, torrent relay';

  @override
  String addonsPackSettingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pack settings',
      one: 'Pack settings',
    );
    return '$_temp0';
  }

  @override
  String get addonsBuiltInGroupLabel => 'Built-in addons';

  @override
  String get addonsPackSettingsGroupLabel => 'Pack settings';

  @override
  String get addonsNoPackSettings =>
      'No pack settings yet. Enable packs with Addon settings under Forja Packs.';

  @override
  String get addonsPackCancel => 'Cancel';

  @override
  String addonsPackActionFailed(String action, String title) {
    return 'Could not $action $title';
  }

  @override
  String get addonsPackSelectAll => 'All';

  @override
  String get addonsPackSelectNone => 'None';

  @override
  String get addonsPackAutoOption => 'Auto';

  @override
  String get addonsPackAuthBrowserOpenFailed => 'Could not open browser';

  @override
  String get addonsPackAuthBrowserTimedOut =>
      'Timed out waiting for Shahid session';

  @override
  String get addonsPackAuthBrowserScriptCopied =>
      'Copied — on the Shahid tab open Console (⌘⌥J), paste, Enter';

  @override
  String get addonsPackAuthBrowserDefaultHint =>
      'Sign in on Shahid in your browser (already signed in is fine).';

  @override
  String get addonsPackAuthBrowserStep1Open =>
      '1. Shahid is open in your browser.';

  @override
  String get addonsPackAuthBrowserStep1Opening => '1. Opening your browser…';

  @override
  String get addonsPackAuthBrowserStep2 =>
      '2. On that Shahid tab: open Console (⌘⌥J / Ctrl+Shift+J), paste, Enter.';

  @override
  String get addonsPackAuthBrowserStep3Waiting =>
      '3. Waiting for session… then Forja shows Connected (you can close the Shahid tab).';

  @override
  String get addonsPackAuthBrowserStep3Stopped =>
      '3. Waiting stopped — copy again or use password.';

  @override
  String get addonsPackAuthBrowserCopyScript => 'Copy connect script';

  @override
  String get addonsPackAuthBrowserOpenAgain => 'Open Shahid again';

  @override
  String get addonsPackAuthBrowserHidePassword => 'Hide email/password';

  @override
  String get addonsPackAuthBrowserUsePassword => 'Use email/password instead';

  @override
  String get addonsPackAuthBrowserConnect => 'Connect';

  @override
  String addonsPackAuthPinUnavailable(String label) {
    return 'PIN login for $label is not available in this build';
  }

  @override
  String addonsPackAuthNoMethods(String label) {
    return 'No login methods from $label';
  }

  @override
  String addonsPackAuthConnectedTo(String label) {
    return 'Connected to $label';
  }

  @override
  String addonsPackAuthNoUrl(String label) {
    return 'No login URL from $label';
  }

  @override
  String addonsPackAuthSignInTo(String label) {
    return 'Sign in to $label';
  }

  @override
  String addonsPackAuthSignedOutOf(String label) {
    return 'Signed out of $label';
  }

  @override
  String addonsPackAuthConnectedAs(String who) {
    return 'Connected as $who';
  }

  @override
  String get addonsPackAuthConnected => 'Connected';

  @override
  String addonsPackAuthLogoutFrom(String label) {
    return 'Logout from $label';
  }

  @override
  String addonsPackAuthLoginWith(String label) {
    return 'Login with $label';
  }

  @override
  String addonsPackAuthLoginDialogTitle(String title) {
    return 'Login · $title';
  }

  @override
  String get addonsPackAuthLoginButton => 'Login';

  @override
  String get addonsPackGreenPlayIntro =>
      'Preferred Forja providers for the green Play button. They are tried first; empty list races all enabled Forja providers.';

  @override
  String get addonsPackGreenPlayEmpty =>
      'No preferred providers — green Play races every enabled Forja plugin.';

  @override
  String get addonsPackGreenPlayRemove => 'Remove';

  @override
  String get addonsPackGreenPlayAddPreferred => 'Add preferred';

  @override
  String get addonsPackGreenPlayAddDialogTitle => 'Add preferred provider';

  @override
  String get addonsPackGreenPlaySearchLabel => 'Search';

  @override
  String get addonsPackGreenPlaySearchHint => 'Provider name';

  @override
  String get addonsPackGreenPlayNoProviders => 'No Forja providers enabled';

  @override
  String get addonsPackGreenPlayNoMatches => 'No matches';

  @override
  String get dataStreamSubtitleTorrent =>
      'Saved stream provider URLs, torrent temp files, and seek buffers. Next play re-resolves. Settings and watch history stay.';

  @override
  String get dataStreamSubtitle =>
      'Saved stream provider URLs and seek buffers. Next play re-resolves. Settings and watch history stay.';

  @override
  String get dataStreamBodyTorrent =>
      'Clears saved stream extracts, torrent download cache, and temporary seek buffers for the current profile (or Guest).\n\nWatch history, provider scores, and settings are not affected. Torrent temp files are shared on this device.';

  @override
  String get dataStreamBody =>
      'Clears saved stream extracts and temporary seek buffers for the current profile (or Guest).\n\nWatch history, provider scores, and settings are not affected.';

  @override
  String get dataGroupSafeToClear => 'Safe to clear';

  @override
  String get dataStreamCacheTitle => 'Stream cache';

  @override
  String get dataStreamClearTitle => 'Clear stream cache?';

  @override
  String get dataClear => 'Clear';

  @override
  String get dataStreamCleared => 'Stream cache cleared';

  @override
  String get dataImagesTitle => 'Images & WebView';

  @override
  String get dataImagesSubtitle =>
      'Poster thumbnails and extractor WebView caches. Frees disk; images download again when needed.';

  @override
  String get dataImagesClearTitle => 'Clear images & WebView?';

  @override
  String get dataImagesClearBody =>
      'Clears cached posters and WebView extract data on this device. Your lists and watch history are not affected.';

  @override
  String get dataImagesCleared => 'Images & WebView cache cleared';

  @override
  String get dataPortalTitle => 'IPTV portal cache';

  @override
  String get dataPortalSubtitle =>
      'Catalogs, alive checks, and channel scans. Portals and favorites stay. Re-fetches on next open.';

  @override
  String get dataPortalClearTitle => 'Clear IPTV portal cache?';

  @override
  String get dataPortalClearBody =>
      'Clears saved catalogs, alive-channel checks, and channel scan hits for IPTV portals on the current profile (or Guest).\n\nSaved portals, favorites, and M3U playlists are not affected.';

  @override
  String get dataPortalCleared => 'IPTV portal cache cleared';

  @override
  String get dataUpdatesTitle => 'Downloaded updates';

  @override
  String get dataUpdatesSubtitle =>
      'Installer files from in-app update (.dmg, .exe, AppImage). Safe to remove after you install.';

  @override
  String get dataUpdatesClearTitle => 'Clear downloaded updates?';

  @override
  String get dataUpdatesClearBody =>
      'Removes update installers Forja saved in Downloads, app storage, or temp while downloading.\n\nYour installed app version and settings are not affected.';

  @override
  String get dataUpdatesCleared => 'Downloaded update files cleared';

  @override
  String get dataGroupLearned => 'Learned';

  @override
  String get dataScoresTitle => 'Provider scores';

  @override
  String get dataScoresSubtitle =>
      'Reliability totals for Settings Score and Auto order. Drag order is kept; scores start over.';

  @override
  String get dataScoresResetTitle => 'Reset provider scores?';

  @override
  String get dataScoresResetBody =>
      'Clears learned reliability for all providers on the current profile (or Guest). Settings Score goes back to 0 and Auto re-learns from new checks.\n\nYour preferred drag order is not changed.';

  @override
  String get dataScoresResetConfirm => 'Reset scores';

  @override
  String get dataScoresReset => 'Provider scores reset';

  @override
  String get dataGroupWatchData => 'Watch data';

  @override
  String get dataContinueTitle => 'Continue watching';

  @override
  String get dataContinueSubtitle =>
      'Resume rows on Home, Anime, and Asian Drama. Cannot be undone for this profile.';

  @override
  String get dataContinueClearTitle => 'Clear continue watching?';

  @override
  String get dataContinueClearBody =>
      'Removes resume / continue-watching entries for movies, TV, anime, Asian drama, and anime Arabic on the current profile (or Guest).\n\nOther profiles are not affected. Trakt or Simkl cloud history is not deleted. My List and liked items are kept.';

  @override
  String get dataContinueClearConfirm => 'Clear history';

  @override
  String get dataContinueCleared => 'Continue watching cleared';

  @override
  String get dataWatchedTitle => 'Watched episode marks';

  @override
  String get dataWatchedSubtitle =>
      'Local watched checkmarks on TV episode lists. Trakt / Simkl online history stays.';

  @override
  String get dataWatchedClearTitle => 'Clear watched marks?';

  @override
  String get dataWatchedClearBody =>
      'Removes local episode watched checkmarks on the current profile (or Guest). Continue watching progress is kept unless you clear it separately.\n\nTrakt / Simkl may show episodes as watched again after sync.';

  @override
  String get dataWatchedClearConfirm => 'Clear marks';

  @override
  String get dataWatchedCleared => 'Watched marks cleared';

  @override
  String dataFailed(String error) {
    return 'Failed: $error';
  }

  @override
  String get dataExportDialogTitle => 'Export Settings';

  @override
  String get dataExported => 'Settings exported';

  @override
  String dataExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get dataImportDialogTitle => 'Import Settings';

  @override
  String get dataReadFileFailed => 'Could not read file.';

  @override
  String get dataImportConfirmBody =>
      'This overwrites your current settings, including addons, API keys, and preferences. Continue?';

  @override
  String get dataImport => 'Import';

  @override
  String get dataImported => 'Settings imported';

  @override
  String dataImportFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get dataBackupLabel => 'Backup';

  @override
  String get dataBackupHint =>
      'Export or import all your settings, addons, API keys, and preferences as a JSON file.';

  @override
  String get dataExport => 'Export';

  @override
  String packsUpdateAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count updates available',
      one: '1 update available',
    );
    return '$_temp0';
  }

  @override
  String get packsUpdateUpToDate => 'All plugins are up to date';

  @override
  String get packsUpdateMenuBadge => 'Update available';

  @override
  String get packsUpdateChecking => 'Checking for plugin updates…';

  @override
  String get packsUpdateUpdating => 'Updating…';

  @override
  String get packsUpdateAll => 'Update all';

  @override
  String get packsUpdateCheckAgain => 'Check again';

  @override
  String get packsPackDeprecatedTag => 'deprecated';

  @override
  String get packsPackUnavailableHereTag => 'not on this device';

  @override
  String get packsPluginsMiniLabel => 'Forja plugins';

  @override
  String packsPackMeta(String kind, int count, String version) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plugins',
      one: '1 plugin',
    );
    return '$kind · $_temp0 · v$version';
  }

  @override
  String get packsPluginUnavailableHere => 'Not available on this device';

  @override
  String get packsLiveTabCatalog => 'Catalog';

  @override
  String get packsLiveTabProvider => 'Provider';

  @override
  String get packsLiveCatalogSubtitle => 'Schedule feed for Live Sports';

  @override
  String get packsLiveProviderSubtitle => 'Stream resolve for Forja Live';

  @override
  String get featuresDefaultMenu => 'Default menu';

  @override
  String get featuresSetDefaultMenu => 'Set as default menu';

  @override
  String get featuresHintLeanback =>
      'OK toggles a tab. Star sets the default menu. ↑/↓ on arrows reorder. ↓ stays in the same column.';

  @override
  String get featuresHint =>
      'Show, hide, and reorder tabs. Drag to reorder. Settings stays visible.';

  @override
  String get featuresAlwaysVisible => 'Always visible';

  @override
  String get packsChoiceOfficialTitle => 'Official packs';

  @override
  String get packsChoiceOfficialSubtitle =>
      'Choose which ForjaHQ packs to install';

  @override
  String get packsChoiceCommunityTitle => 'Community Packs';

  @override
  String get packsChoiceCommunitySubtitleCompact => 'Browse packs on the web';

  @override
  String get packsChoiceCommunitySubtitle => 'Browse and pick packs on the web';

  @override
  String get packsPromptTitleSync => 'Sync packs';

  @override
  String get packsPromptTitleUninstall => 'Uninstall packs';

  @override
  String get packsPromptTitleInstall => 'Install packs';

  @override
  String packsPromptInstalledCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count packs installed',
      one: '1 pack installed',
    );
    return '$_temp0';
  }

  @override
  String packsPromptRemovedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count packs removed',
      one: '1 pack removed',
    );
    return '$_temp0';
  }

  @override
  String packsPromptFailedToast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count packs failed — see details above',
      one: 'Pack install failed — see details above',
    );
    return '$_temp0';
  }

  @override
  String get packsPromptBodyRemote =>
      'These packs changed on your profile from another device. Choose what to apply here. The rest can wait in Forja Packs.';

  @override
  String get packsPromptBodyLocal =>
      'Choose which packs to download on this device. You can install the rest later from this page.';

  @override
  String get packsPromptWorking => 'Working…';

  @override
  String packsPromptApply(int install, int uninstall) {
    return 'Apply ($install install · $uninstall uninstall)';
  }

  @override
  String packsPromptUninstallCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count packs',
      one: '1 pack',
    );
    return 'Uninstall $_temp0';
  }

  @override
  String packsPromptInstallCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count packs',
      one: '1 pack',
    );
    return 'Install $_temp0';
  }

  @override
  String get packsPromptSelectAll => 'Select all';

  @override
  String get packsPromptClear => 'Clear';

  @override
  String packsPromptSelected(int count) {
    return '$count selected';
  }

  @override
  String get packsPromptLocalFolder => 'Local folder';

  @override
  String packsPromptCommunitySource(String host) {
    return '$host · Community source';
  }

  @override
  String get packsPromptDefaultTitle => 'Plugin pack';

  @override
  String get packsPromptActionUninstall => 'Uninstall';

  @override
  String get packsPromptActionInstall => 'Install';

  @override
  String get packsPromptAlreadyRemoved => 'Already removed';

  @override
  String get packsPromptAlreadyOnDevice => 'Already on device';

  @override
  String get packsPromptNotOnDevice => 'Not on this device';

  @override
  String get packsPromptCommunity => 'Community';

  @override
  String get packsPromptRecommended => 'Recommended';

  @override
  String get packsGroupLabel => 'Forja packs';

  @override
  String get packsEmptyNone =>
      'No packs installed. Paste a manifest URL below, or sign in to sync from your profile.';

  @override
  String packsInstallFailed(String error) {
    return 'Pack install failed: $error';
  }

  @override
  String get packsRetryInstall => 'Retry install';

  @override
  String get packsManifestHint =>
      'Each pack is a manifest.json URL. Forja downloads the manifest, then every plugin script, before the pack is fully usable.';

  @override
  String get packsAddPackLabel => 'Add pack';

  @override
  String get packsAddPackHint =>
      'Paste one or more manifest URLs / local paths';

  @override
  String get packsDownloadAll => 'Download all';

  @override
  String get packsReloadingTooltip => 'Reloading packs…';

  @override
  String get packsReload => 'Reload';

  @override
  String get packsInstall => 'Install';

  @override
  String get packsPendingDownloads => 'Pending downloads';

  @override
  String get packsInstalledPacks => 'Installed packs';

  @override
  String get packsBadgeRemovedFromProfile => 'Removed from profile';

  @override
  String get packsActionUninstallNow => 'Uninstall now';

  @override
  String get packsBadgeInstallLater => 'Install later';

  @override
  String get packsBadgeInstallFailed => 'Install failed';

  @override
  String get packsBadgeDownloading => 'Downloading';

  @override
  String get packsBadgePendingDownload => 'Pending download';

  @override
  String get packsRetryDownload => 'Retry download';

  @override
  String get packsToastRefreshed => 'Packs refreshed';

  @override
  String get packsToastRecommendedInstalled =>
      'Recommended packs already installed';

  @override
  String get packsToastFinishPrompt => 'Finish the current pack prompt first';

  @override
  String packsToastOfficialInstallFailed(String error) {
    return 'Official pack install failed: $error';
  }

  @override
  String packsToastUpdatedTo(String name, String version) {
    return 'Updated $name to v$version';
  }

  @override
  String packsToastRefreshedPack(String name, String version) {
    return 'Refreshed $name v$version';
  }

  @override
  String packsToastRefreshFailed(String error) {
    return 'Refresh failed: $error';
  }

  @override
  String packsToastReloadFailed(String name, String error) {
    return '$name reload failed: $error';
  }

  @override
  String packsToastReloaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count packs reloaded',
      one: '1 pack reloaded',
    );
    return '$_temp0';
  }

  @override
  String packsToastDownloadFailed(String name, String error) {
    return '$name download failed: $error';
  }

  @override
  String packsToastDownloaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count packs downloaded',
      one: '1 pack downloaded',
    );
    return '$_temp0';
  }

  @override
  String packsToastUpdateFailed(String name, String error) {
    return '$name update failed: $error';
  }

  @override
  String packsToastUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count packs updated',
      one: '1 pack updated',
    );
    return '$_temp0';
  }

  @override
  String get packsToastInstallFailedDetails =>
      'Install failed — see details above';

  @override
  String packsToastInstalled(String name, int count) {
    return 'Installed $name ($count plugins)';
  }

  @override
  String get packsToastPackUninstalled => 'Pack uninstalled';

  @override
  String get packsToastPackRemoved => 'Pack removed';

  @override
  String get packsOfficialBadge => 'Official';

  @override
  String packsActionUpdateTo(String version) {
    return 'Update to v$version';
  }

  @override
  String get packsActionRefresh => 'Refresh';

  @override
  String packsFailuresTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count packs failed to install',
      one: 'Pack install failed',
    );
    return '$_temp0';
  }

  @override
  String get packsDismiss => 'Dismiss';

  @override
  String get packsPendingReady => 'Ready';

  @override
  String get packsPendingWaiting => 'Waiting';

  @override
  String get packsPendingDownload => 'Download';

  @override
  String get packsPendingYes => 'Yes';

  @override
  String get packsPendingNo => 'No';

  @override
  String get packsPendingRemovePack => 'Remove pack';

  @override
  String packsInstallUpdateAvailable(String version) {
    return 'Update available: v$version';
  }

  @override
  String get packsInstallBannerUpdating => 'Updating plugins…';

  @override
  String get packsInstallBannerDownloading => 'Downloading plugins…';

  @override
  String get profileLoadFailed =>
      'Could not load profile. Check your connection and retry.';

  @override
  String get profileToastProfileReady => 'Profile ready';

  @override
  String get profileToastAccountReady => 'Account ready';

  @override
  String get profileSignInFailed =>
      'Sign-in failed. Check email/password or Supabase config.';

  @override
  String get profileWebLoginIncomplete => 'Web login did not complete.';

  @override
  String get profileWebLoginFailed =>
      'Could not finish web login. Check that the portal is reachable.';

  @override
  String get profileSignupOpenFailed => 'Could not open the signup page.';

  @override
  String get profileCloudNotConfigured =>
      'Cloud account is not configured in this build. Pass SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY via --dart-define.';

  @override
  String get profileAccountLabel => 'Account';

  @override
  String get profileSignedIn => 'Signed in';

  @override
  String get profileCloudProfileLoading => 'Loading cloud profile…';

  @override
  String get profileCloudProfileLoadFailed =>
      'Cloud profile could not load. Retry, or sign out to clear this session on the device.';

  @override
  String get profileRetryTitle => 'Retry';

  @override
  String get profileRetrySubtitle => 'Reload profiles from the cloud';

  @override
  String get profileSignOutTitle => 'Sign out';

  @override
  String get profileSignOutSubtitle =>
      'Clear the session on this device even if the network is down';

  @override
  String get profileSyncNoneYet =>
      'No cloud settings synced yet - changes will upload as you use Forja';

  @override
  String profileSyncSections(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count setting sections synced to this profile',
      one: '1 setting section synced to this profile',
    );
    return '$_temp0';
  }

  @override
  String get profileCloudSyncLabel => 'Cloud sync';

  @override
  String get profileSignedInWaitingSync => 'Signed in · waiting for sync';

  @override
  String get profileSynced => 'Synced';

  @override
  String get profileAccountActiveHint => 'Active Forja cloud account';

  @override
  String get profileAccountSwitchHint => 'Tap to switch or add accounts';

  @override
  String get profileWatchingNow => 'Watching now';

  @override
  String get profileActiveHint => 'Active profile on this device';

  @override
  String get profileSwitchHint => 'Tap to switch who’s watching';

  @override
  String get profileSignIn => 'Sign in';

  @override
  String get profileNewHere => 'New here?';

  @override
  String get profileCreateAccountWeb => 'Create an account on the web';

  @override
  String get profileOpensPortal => 'Opens the Forja portal in your browser';

  @override
  String get profileLinkIntroTv =>
      'Link your Forja account with a code or QR on the portal. You can keep using Forja without an account.';

  @override
  String get profileLinkWithCodeOrQr => 'Link with code or QR';

  @override
  String get profileCreateAccountTvHint =>
      'Use a phone or computer - then link this TV';

  @override
  String get profileSignInIntro =>
      'Sign in to sync profiles and settings across devices. You can keep using Forja without an account.';

  @override
  String get profileSignInQuick =>
      'Sign in with your phone or computer in under a minute.';

  @override
  String get profileEmailLabel => 'Email';

  @override
  String get profilePasswordLabel => 'Password';

  @override
  String get profileSigningIn => 'Signing in…';

  @override
  String get profileCancelWebLogin => 'Cancel web login';

  @override
  String get profileWebLogin => 'Web login';

  @override
  String get downloadsChooseFolder => 'Choose download folder';

  @override
  String get downloadsFolderNotWritable => 'Can’t write to that folder';

  @override
  String get downloadsFolderChanged => 'New downloads will save here';

  @override
  String get downloadsFolderReset => 'Using the default download folder';

  @override
  String get downloadsDeleteAllCompletedTitle => 'Delete all completed?';

  @override
  String get downloadsDeleteAllCompletedBody =>
      'Removes every finished download from this device and frees the disk space.';

  @override
  String get downloadsDeleteAll => 'Delete all';

  @override
  String get downloadsCompletedDeleted => 'Completed downloads deleted';

  @override
  String downloadsTabActive(int count) {
    return 'Active ($count)';
  }

  @override
  String downloadsTabCompleted(int count) {
    return 'Completed ($count)';
  }

  @override
  String get downloadsActiveEmptyTitle => 'No active downloads';

  @override
  String get downloadsActiveEmptyHint =>
      'Start one from details, Sources, or the player.';

  @override
  String get downloadsCompletedEmptyTitle => 'No offline downloads yet';

  @override
  String get downloadsCompletedEmptyHint =>
      'Finished titles show up here — play anytime without a network.';

  @override
  String get downloadsStorageTitle => 'Storage';

  @override
  String get downloadsStorageSubtitle => 'Offline library for this profile.';

  @override
  String get downloadsRefresh => 'Refresh';

  @override
  String get downloadsUsedOf => ' used of ';

  @override
  String downloadsFreeSuffix(String free) {
    return '  ·  $free free';
  }

  @override
  String get downloadsLegendOffline => 'Offline';

  @override
  String get downloadsLegendOther => 'Other';

  @override
  String get downloadsLegendAvailable => 'Available';

  @override
  String get downloadsChange => 'Change';

  @override
  String get downloadsDefault => 'Default';

  @override
  String get downloadsStatusQueued => 'Queued';

  @override
  String get downloadsStatusPaused => 'Paused';

  @override
  String get downloadsStatusFailed => 'Failed';

  @override
  String downloadsEta(String eta) {
    return 'ETA $eta';
  }

  @override
  String get downloadsPause => 'Pause';

  @override
  String get downloadsResume => 'Resume';

  @override
  String get downloadsRetry => 'Retry';

  @override
  String get downloadsCancel => 'Cancel';

  @override
  String get downloadsPlayOffline => 'Play offline';

  @override
  String get downloadsDelete => 'Delete';

  @override
  String get downloadsDeleteOneTitle => 'Delete download?';

  @override
  String downloadsDeleteOneBody(String title) {
    return 'Removes “$title” from this device.';
  }

  @override
  String get settingsUiAuto => 'Auto';

  @override
  String get settingsUiCancel => 'Cancel';

  @override
  String get settingsUiClose => 'Close';

  @override
  String get settingsUiLanP2pPairTitle => 'Pair a desktop';

  @override
  String get settingsUiLanP2pOfflineTitle => 'Desktop offline';

  @override
  String get settingsUiLanP2pPairBody =>
      'Torrents and other P2P streams play on a desktop Forja server, not on this TV. Direct HTTP streams still play here. Pair once in Settings → LAN.';

  @override
  String get settingsUiLanP2pOfflineBody =>
      'Torrents and other P2P streams need your paired desktop Forja server on the same Wi-Fi. Direct HTTP streams still play on this TV.';

  @override
  String get settingsUiLanP2pOpenLan => 'Open LAN';

  @override
  String get settingsUiP2pAckTitle => 'P2P Streaming';

  @override
  String get settingsUiP2pAckAware => 'I am aware';

  @override
  String get settingsUiP2pAckIntro =>
      'This stream uses peer-to-peer (P2P) technology. By continuing, you confirm you are aware that:';

  @override
  String get settingsUiP2pAckBulletIp =>
      'Your IP address will be visible to other peers in the network';

  @override
  String get settingsUiP2pAckBulletResponsible =>
      'You are solely responsible for the content you access';

  @override
  String get settingsUiP2pAckBulletLegalRight =>
      'You confirm you have the legal right to stream this content in your jurisdiction';

  @override
  String get settingsUiP2pAckBulletNoHosting =>
      'Forja does not host, distribute, or control any P2P content';

  @override
  String get settingsUiP2pAckBulletNoLiability =>
      'Forja bears no liability for any legal consequences arising from your use of P2P streaming';

  @override
  String get settingsUiP2pAckOutro =>
      'You use this feature entirely at your own risk. Direct torrent, Stremio, and Nuvio can be turned off anytime in Settings.';

  @override
  String get settingsUiP2pAckVpnBanner =>
      'For better privacy, use a VPN. Your IP address is visible to other peers.';

  @override
  String get settingsUiMadeWith => 'Made with ';

  @override
  String get settingsUiMadeWithBy => ' by ';

  @override
  String get playerScreenTryingNextStream => 'Trying next stream…';

  @override
  String get playerScreenFindingAnotherStream => 'Finding another stream…';

  @override
  String get playerScreenFindingServers => 'Finding servers…';

  @override
  String get playerScreenFailedToStream => 'Failed to stream';

  @override
  String get playerScreenExoSeparateAudioUnsupported =>
      'Separate audio track not supported in ExoPlayer - use MediaKit in Settings.';

  @override
  String get playerScreenReconnecting => 'Reconnecting…';

  @override
  String get playerScreenReconnectFailed => 'Reconnect failed';

  @override
  String playerScreenEpisodeNumber(String number) {
    return 'Episode $number';
  }

  @override
  String get playerScreenPreviousEpisodeButton => 'Previous Episode';

  @override
  String get playerScreenNextEpisodeButton => 'Next Episode';

  @override
  String get playerScreenAudio => 'Audio';

  @override
  String get playerScreenQuality => 'Quality';

  @override
  String get playerScreenLoadingSources => 'Loading sources…';

  @override
  String get playerScreenFailedToLoadSources => 'Failed to load sources';

  @override
  String get playerScreenCheckingSources => 'Checking sources';

  @override
  String get playerScreenNoStreamsFound => 'No streams found';

  @override
  String get playerScreenStream => 'Stream';

  @override
  String get playerScreenStremioStream => 'Stremio stream';

  @override
  String get playerScreenFailedToResolveStream => 'Failed to resolve stream';

  @override
  String get playerScreenTorrentStreamFailedToStart =>
      'Torrent stream failed to start';

  @override
  String get playerScreenOpeningStream => 'Opening stream…';

  @override
  String get playerScreenSources => 'Sources';

  @override
  String get playerScreenSubtitle => 'Subtitle';

  @override
  String get playerScreenSubtitleFailed => 'Subtitle failed';

  @override
  String get playerScreenBack10s => 'Back 10s';

  @override
  String get playerScreenForward10s => 'Forward 10s';

  @override
  String get playerScreenNoMoreEpisodes => 'No more episodes';

  @override
  String get playerScreenCouldNotFindStreamForEpisode =>
      'Could not find a stream for this episode';

  @override
  String get playerScreenLoadingEpisodeInfo => 'Loading episode info…';

  @override
  String playerScreenSeasonEpisode(int season, int episode) {
    return 'Season $season · Episode $episode';
  }

  @override
  String get playerScreenCheckingSourcesProgress => 'Checking sources…';

  @override
  String get playerScreenResolvingTorrent => 'Resolving torrent…';

  @override
  String get playerScreenCheckingStremio => 'Checking Stremio…';

  @override
  String get playerScreenAutoSelection => 'Auto selection';

  @override
  String get playerScreenAutoSelectionSubtitle => 'Servers, tracks, skip intro';

  @override
  String get playerScreenAutoServer => 'Auto server';

  @override
  String get playerScreenAutoSource => 'Auto source';

  @override
  String get playerScreenAutoAudio => 'Auto audio';

  @override
  String get playerScreenAutoSubtitles => 'Auto subtitles';

  @override
  String get playerScreenAutoSkipIntro => 'Auto skip intro';

  @override
  String get playerScreenAutoNextEpisode => 'Auto next episode';

  @override
  String get playerScreenVideoDecode => 'Video decode';

  @override
  String get playerScreenHwDecGpuSafe => 'Hardware Decoding: ON (GPU, safe)';

  @override
  String get playerScreenHwDecCopyBack => 'Hardware Decoding: ON (copy-back)';

  @override
  String get playerScreenHwDecOffCpu => 'Hardware Decoding: OFF (CPU)';

  @override
  String get playerScreenSwDecodeSoftDisplay =>
      'Software decode + soft display (CPU)';

  @override
  String get playerScreenPlaybackSpeed => 'Playback speed';

  @override
  String get playerScreenPlaybackSpeedSubtitle => 'How fast playback runs';

  @override
  String get playerScreenSpeedNormal => 'Normal';

  @override
  String get playerScreenAspectRatio => 'Aspect ratio';

  @override
  String get playerScreenAspectRatioSubtitle => 'Fit video in the frame';

  @override
  String get playerScreenFitFit => 'FIT';

  @override
  String get playerScreenFitCrop => 'CROP';

  @override
  String get playerScreenFitFill => 'FILL';

  @override
  String get playerScreenLoop => 'Loop';

  @override
  String get playerScreenLoopSubtitle => 'Repeat the current title';

  @override
  String get playerScreenOn => 'On';

  @override
  String get playerScreenOff => 'Off';

  @override
  String get playerScreenTorrentStats => 'Torrent stats';

  @override
  String get playerScreenTorrentStatsSubtitle => 'Show live transfer overlay';

  @override
  String get playerScreenSkipRecap => 'Skip Recap';

  @override
  String get playerScreenSkipIntro => 'Skip Intro';

  @override
  String get playerScreenSkipCredits => 'Skip Credits';

  @override
  String get playerScreenSkipPreview => 'Skip Preview';

  @override
  String get playerScreenPlay => 'Play';

  @override
  String get playerScreenEpisodes => 'Episodes';

  @override
  String get playerScreenSubtitles => 'Subtitles';

  @override
  String get playerScreenFullscreen => 'Fullscreen';

  @override
  String get playerScreenStreamFailed => 'Stream failed';

  @override
  String get playerScreenPlaybackFailedOpenSources =>
      'Playback failed. Open Sources and choose another stream.';

  @override
  String get playerScreenNoWorkingStream =>
      'Could not find any working stream from any provider.';

  @override
  String get playerScreenTorrentStreamFailedToOpen =>
      'Torrent stream failed to open.';

  @override
  String get playerScreenDownloadedFileCantPlay =>
      'Downloaded file can’t be played';

  @override
  String get playerScreenPlaybackFailed => 'Playback failed.';

  @override
  String get playerScreenUnlock => 'Unlock';

  @override
  String get playerScreenCouldNotOpenStream => 'Could not open stream';

  @override
  String get playerScreenSwitchingToMediaKit => 'Switching to MediaKit…';

  @override
  String get playerScreenPressEscAgain => 'Press Esc again to exit';

  @override
  String get playerScreenNextEpisodeTooltip => 'Next episode';

  @override
  String get playerScreenPlayer => 'Player';

  @override
  String playerScreenSourceFailed(String title) {
    return 'Failed: $title';
  }

  @override
  String get playerControlAirPlayEnded => 'AirPlay ended';

  @override
  String get playerControlAirPlayOpenFailed => 'Couldn\'t open AirPlay';

  @override
  String get playerControlAirPlaySubtitlesUnavailable =>
      'Subtitles can\'t play on AirPlay for this stream';

  @override
  String get playerControlAllProviders => 'All';

  @override
  String get playerControlAspectRatio => 'Aspect ratio';

  @override
  String get playerControlAspectRatioSubtitle => 'How video fills the frame';

  @override
  String get playerControlAudio => 'Audio';

  @override
  String get playerControlAutoAudio => 'Auto audio';

  @override
  String get playerControlAutoNext => 'AutoNext';

  @override
  String get playerControlAutoSelection => 'Auto selection';

  @override
  String get playerControlAutoSelectionSubtitle =>
      'Servers, tracks, skip intro';

  @override
  String get playerControlAutoServer => 'Auto server';

  @override
  String get playerControlAutoSource => 'Auto source';

  @override
  String get playerControlAutoSubtitles => 'Auto subtitles';

  @override
  String get playerControlAvPlayerMacOnly => 'AVPlayer is macOS-only';

  @override
  String get playerControlBack => 'Back';

  @override
  String get playerControlBack10s => 'Back 10s';

  @override
  String get playerControlBuffering => 'Buffering';

  @override
  String get playerControlBufferingEllipsis => 'Buffering…';

  @override
  String get playerControlBuiltIn => 'Built-in';

  @override
  String get playerControlCast => 'Cast';

  @override
  String playerControlCastStarting(String label) {
    return 'Starting $label…';
  }

  @override
  String playerControlCastTargetUnavailable(String label) {
    return '$label is not available yet';
  }

  @override
  String get playerControlCastTo => 'Cast to';

  @override
  String get playerControlCastUnsupported =>
      'Casting is not supported on this device';

  @override
  String playerControlCastingTo(String label) {
    return 'Casting to $label';
  }

  @override
  String get playerControlChangePlayer => 'Change player';

  @override
  String get playerControlCheck => 'Check';

  @override
  String playerControlCheckingOrdinal(int ordinal, int total) {
    return 'Checking $ordinal/$total…';
  }

  @override
  String get playerControlCheckingServer => 'Checking server…';

  @override
  String get playerControlCheckingSources => 'Checking sources';

  @override
  String get playerControlCheckingStream => 'Checking stream…';

  @override
  String get playerControlChoosePlayer => 'Choose player';

  @override
  String get playerControlCrop => 'Crop';

  @override
  String get playerControlDetails => 'Details';

  @override
  String get playerControlEngineDrmNeedsExo => 'DRM needs ExoPlayer';

  @override
  String get playerControlEngineSeparateAudioNeedsMediaKit =>
      'Separate audio needs MediaKit';

  @override
  String get playerControlEngineTorrentNeedsMediaKit =>
      'Torrent streams need MediaKit';

  @override
  String playerControlEpisodeNumber(int number) {
    return 'Episode $number';
  }

  @override
  String get playerControlEpisodes => 'Episodes';

  @override
  String get playerControlExpand => 'Expand';

  @override
  String get playerControlExternalApp => 'External app';

  @override
  String get playerControlFailedToStream => 'Failed to stream';

  @override
  String get playerControlFile => 'File';

  @override
  String get playerControlFill => 'Fill';

  @override
  String get playerControlFit => 'Fit';

  @override
  String get playerControlForward10s => 'Forward 10s';

  @override
  String get playerControlInAppMiniPlayer => 'In-app mini player';

  @override
  String get playerControlInStream => 'In-stream';

  @override
  String get playerControlJackettNotConfigured => 'Jackett is not configured';

  @override
  String get playerControlKeepsStreamAlive =>
      'Forja keeps the stream alive while you watch externally.';

  @override
  String get playerControlLanguages => 'Languages';

  @override
  String playerControlLaunchFailed(String type) {
    return 'Launch failed ($type). See console for details.';
  }

  @override
  String get playerControlMinimize => 'Minimize';

  @override
  String get playerControlMute => 'Mute';

  @override
  String get playerControlNext => 'Next';

  @override
  String get playerControlNextEpisode => 'Next Episode';

  @override
  String get playerControlNoAudioTracks => 'No audio tracks found';

  @override
  String get playerControlNoEpisodesFound => 'No episodes found';

  @override
  String get playerControlNoExternalPlayers => 'No external players installed';

  @override
  String playerControlNoFilterSources(String filter) {
    return 'No $filter sources';
  }

  @override
  String get playerControlNoForjaPlugins => 'No Forja plugins installed';

  @override
  String get playerControlNoMatchingEpisodes => 'No matching episodes';

  @override
  String get playerControlNoMatchingSources => 'No matching sources';

  @override
  String get playerControlNoMatchingStremioId =>
      'No matching id for this Stremio addon';

  @override
  String get playerControlNoNuvioScrapers =>
      'No Nuvio scrapers. Add them in Settings → Addons → Nuvio';

  @override
  String get playerControlNoOnlineSubtitles =>
      'No online subtitles yet. Tap Search to type the film or series name.';

  @override
  String get playerControlNoSavedFiles => 'No saved files';

  @override
  String get playerControlNoServers => 'No servers';

  @override
  String get playerControlNoSourcesAvailable => 'No sources available';

  @override
  String get playerControlNoStreamToCast => 'No stream to cast';

  @override
  String get playerControlNoStreamsAvailable => 'No streams available';

  @override
  String get playerControlNoStreamsForjaPlugins =>
      'No streams found from selected Forja plugins';

  @override
  String playerControlNoStreamsInAddon(String addon) {
    return 'No streams found in $addon';
  }

  @override
  String get playerControlNoStreamsNuvio =>
      'No streams found from selected Nuvio providers';

  @override
  String get playerControlNoStremioAddons =>
      'No Stremio stream addons. Add them in Settings → Addons → Stremio';

  @override
  String get playerControlNoSubtitles => 'No subtitles';

  @override
  String get playerControlNoTmdbIdForNuvio => 'No TMDB id for Nuvio streams';

  @override
  String get playerControlNoTorrentFiles => 'No files found in this torrent.';

  @override
  String get playerControlNoTorrentsFound => 'No torrents found';

  @override
  String get playerControlNoTracks => 'No tracks';

  @override
  String get playerControlNoneAvailable => 'None available';

  @override
  String get playerControlNormal => 'Normal';

  @override
  String get playerControlOff => 'Off';

  @override
  String get playerControlOn => 'On';

  @override
  String playerControlOpeningInPlayer(String player) {
    return 'Opening in $player…';
  }

  @override
  String get playerControlParentalAlcoholDrugs => 'Alcohol/Drugs';

  @override
  String get playerControlParentalFrightening => 'Frightening';

  @override
  String get playerControlParentalNudity => 'Nudity';

  @override
  String get playerControlParentalProfanity => 'Profanity';

  @override
  String get playerControlParentalViolence => 'Violence';

  @override
  String get playerControlPause => 'Pause';

  @override
  String get playerControlPictureInPicture => 'Picture in Picture';

  @override
  String get playerControlPlay => 'Play';

  @override
  String get playerControlPlaybackSpeed => 'Playback speed';

  @override
  String get playerControlPlayer => 'Player';

  @override
  String playerControlPlayerCouldNotLaunch(String player) {
    return '$player could not be launched. Is it installed?';
  }

  @override
  String playerControlPlayerNotFound(String player) {
    return '$player not found. Using built-in player.';
  }

  @override
  String get playerControlPlayingInPip => 'Playing in picture-in-picture';

  @override
  String get playerControlPlayingNow => 'Playing now';

  @override
  String get playerControlPlayingOnAirPlay => 'Playing on AirPlay';

  @override
  String get playerControlPreparingStream => 'Preparing stream…';

  @override
  String get playerControlPressBackAgainToExit => 'Press Back again to exit';

  @override
  String get playerControlPressBackToLeave => 'Press Back to leave';

  @override
  String get playerControlPressEscAgainToExit => 'Press Esc again to exit';

  @override
  String get playerControlPrevious => 'Previous';

  @override
  String get playerControlPreviousEpisode => 'Previous Episode';

  @override
  String playerControlProviderUnavailable(String name) {
    return '$name is unavailable';
  }

  @override
  String get playerControlProwlarrNotConfigured => 'Prowlarr is not configured';

  @override
  String get playerControlQuality => 'Quality';

  @override
  String get playerControlQualityNotAvailable => 'Quality not available yet';

  @override
  String playerControlRelaunchInPlayer(String player) {
    return 'Re-launch in $player';
  }

  @override
  String get playerControlSearch => 'Search';

  @override
  String playerControlSearchingHint(String hint) {
    return 'Searching: $hint';
  }

  @override
  String get playerControlSearchingSubtitles => 'Searching subtitles…';

  @override
  String playerControlSeasonNumber(int number) {
    return 'Season $number';
  }

  @override
  String get playerControlSelectProvider => 'Select at least one provider';

  @override
  String get playerControlSelectServer => 'Select a server';

  @override
  String get playerControlServers => 'Servers';

  @override
  String get playerControlShuffle => 'Shuffle';

  @override
  String get playerControlSource => 'Source';

  @override
  String playerControlSourceTip(String label) {
    return 'Source: $label';
  }

  @override
  String playerControlSourceTipWithServer(String label, String server) {
    return 'Source: $label · $server';
  }

  @override
  String playerControlSourcesTip(String label) {
    return 'Sources: $label';
  }

  @override
  String playerControlSourcesTipWithServer(String label, String server) {
    return 'Sources: $label · $server';
  }

  @override
  String get playerControlStatusChecking => 'Checking…';

  @override
  String get playerControlStatusPlaying => 'Playing';

  @override
  String get playerControlStatusUnavailable => 'Unavailable';

  @override
  String get playerControlStream => 'Stream';

  @override
  String get playerControlStreamActive => 'Stream active';

  @override
  String playerControlStreamCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count streams',
      one: '1 stream',
    );
    return '$_temp0';
  }

  @override
  String playerControlStreamNumber(int number) {
    return 'Stream $number';
  }

  @override
  String get playerControlStreams => 'Streams';

  @override
  String playerControlStreamsServer(String server) {
    return 'Streams · $server';
  }

  @override
  String get playerControlSubBgOpacity => 'BG Opacity';

  @override
  String get playerControlSubBold => 'Bold';

  @override
  String get playerControlSubDecreaseDelay => 'Decrease delay';

  @override
  String get playerControlSubDelay => 'Delay';

  @override
  String get playerControlSubFont => 'Font';

  @override
  String get playerControlSubIncreaseDelay => 'Increase delay';

  @override
  String get playerControlSubPosition => 'Position';

  @override
  String get playerControlSubSize => 'Size';

  @override
  String get playerControlSubTextColor => 'Text Color';

  @override
  String get playerControlSubtitleSettings => 'Subtitle settings';

  @override
  String get playerControlSubtitleSettingsTitle => 'Subtitle Settings';

  @override
  String get playerControlSubtitles => 'Subtitles';

  @override
  String get playerControlSwitchingPlayer => 'Switching player…';

  @override
  String get playerControlTapServerToCheck => 'Tap the server to check';

  @override
  String playerControlTipOffline(String base) {
    return '$base · Offline';
  }

  @override
  String playerControlTorrentEta(String eta) {
    return 'ETA $eta';
  }

  @override
  String get playerControlTorrentFiles => 'Torrent files';

  @override
  String playerControlTorrentPeers(int active, int total) {
    return '$active live · $total seen';
  }

  @override
  String playerControlTorrentSeeders(String seeders) {
    return '$seeders seeders';
  }

  @override
  String get playerControlTracks => 'Tracks';

  @override
  String playerControlTracksGroup(String group) {
    return 'Tracks · $group';
  }

  @override
  String playerControlTranslatedFrom(String source) {
    return 'Translated · $source';
  }

  @override
  String get playerControlUnknownStream => 'Unknown Stream';

  @override
  String get playerControlUnmute => 'Unmute';

  @override
  String playerControlViaPlayer(String player) {
    return 'via $player';
  }

  @override
  String get playerControlVlcNotInstalled => 'VLC (libVLC) is not installed';

  @override
  String get playerControlWatchInForja => 'Watch in Forja instead';

  @override
  String get playerControlWatchParty => 'Watch Party';

  @override
  String get playerControlWatchPartySoon => 'Watch Party - coming soon';

  @override
  String get playerSourcePortalNotFound => 'Portal not found';

  @override
  String get playerSourceOpenStreamFailed => 'Could not open stream';

  @override
  String get playerSourceNoEpisodeSelected => 'No episode selected';

  @override
  String get playerSourceOpenEpisodeFailed => 'Could not open episode';

  @override
  String playerSourceVodEpisodeTitle(int number, String title) {
    return 'Ep $number · $title';
  }

  @override
  String get playerSourceStreamsTitle => 'Streams';

  @override
  String get playerSourcePlaybackFailedTitle => 'Couldn’t start playback';

  @override
  String get playerSourceResolvingLink => 'Resolving download link…';

  @override
  String get playerSourceResolvingLinkHint =>
      'Fetching the magnet from the torrent page.';

  @override
  String get playerSourceMagnetResolveFailed =>
      'Could not resolve a magnet link for this torrent.';

  @override
  String get playerSourceTorrentStartFailed =>
      'Torrent stream failed to start.';

  @override
  String get playerSourceStreamStartFailed =>
      'Couldn\'t start this stream. Try again or pick another source.';

  @override
  String get playerSourceNoMatches => 'No matches';

  @override
  String get playerSourceNoChannelsMatch => 'No channels match';

  @override
  String get playerSourceSearchChannelsHint => 'Search channels…';

  @override
  String get playerSourcePeers => 'peers';

  @override
  String playerSourcePeersOf(int seen) {
    return 'of $seen peers';
  }

  @override
  String playerSourcePeersSeen(int seen) {
    return '$seen seen';
  }

  @override
  String get playerSourceStatDownload => 'Download';

  @override
  String get playerSourceStatFileCached => 'File cached';

  @override
  String get playerSourceFilterAll => 'All';

  @override
  String get playerSourceFilterAudio => 'Audio';

  @override
  String get playerSourceAvailableSources => 'Available Sources';

  @override
  String get playerSourceSortSeedersHigh => 'Seeders (High to Low)';

  @override
  String get playerSourceSortSeedersLow => 'Seeders (Low to High)';

  @override
  String get playerSourceSortQualityHigh => 'Quality (High to Low)';

  @override
  String get playerSourceSortQualityLow => 'Quality (Low to High)';

  @override
  String get playerSourceSortSizeHigh => 'Size (High to Low)';

  @override
  String get playerSourceSortSizeLow => 'Size (Low to High)';

  @override
  String get playerSourceStoppedActiveDownload => 'Stopped active download';

  @override
  String get playerSourceDownloadsCleared => 'Downloads cleared';

  @override
  String get playerSourceStopClearFailed =>
      'Could not stop or clear torrent downloads';

  @override
  String get playerSourceStopAndClear => 'Stop & clear';

  @override
  String get playerSourceSearchHint => 'Search';

  @override
  String get playerSourceFiltersTitle => 'Filters';

  @override
  String get playerSourceFilterCategory => 'Category';

  @override
  String get playerSourceFilterSort => 'Sort';

  @override
  String get playerSourceFilterQuality => 'Quality';

  @override
  String get playerSourceFilterSize => 'Size';

  @override
  String get playerSourceFilterLanguage => 'Language';

  @override
  String get playerSourceFilterTech => 'Tech';

  @override
  String get playerSourceFilterOnline => 'Online';

  @override
  String get playerSourcePlaying => 'Playing';

  @override
  String get playerSourceCheckingSize => 'Checking size…';

  @override
  String get playerSourceSizeUnknown => 'Size unknown';

  @override
  String get playerSourceNotEnoughSpace => 'Not enough free space';

  @override
  String get playerSourceDownloadHeading => 'DOWNLOAD';

  @override
  String get playerSourceDownloadOfflineHeading => 'DOWNLOAD OFFLINE?';

  @override
  String get playerSourceDownloadTooltip => 'Download';

  @override
  String get playerSourcePlayOnline => 'Play online';

  @override
  String get playerSourceCopyMagnet => 'Copy magnet';

  @override
  String get playerSourceMagnetCopied => 'Magnet copied';

  @override
  String get playerSourceSourcesTitle => 'Sources';

  @override
  String get playerSourceDownloadedChip => 'Downloaded';

  @override
  String get playerTrailerLoadFailed => 'Could not load this trailer';

  @override
  String get playerTrailerOpenInYouTube => 'Open in YouTube';

  @override
  String get playerTrailerBack => 'Back';

  @override
  String get playerTrailerMute => 'Mute';

  @override
  String get playerTrailerReplay => 'Replay';

  @override
  String get playerTrailerPause => 'Pause';

  @override
  String get playerTrailerPlay => 'Play';

  @override
  String get playerTrailerBack10 => 'Back 10s';

  @override
  String get playerTrailerForward10 => 'Forward 10s';

  @override
  String get playerTrailerSubtitles => 'Subtitles';

  @override
  String get playerTrailerQuality => 'Quality';

  @override
  String get playerTrailerPlaybackSpeed => 'Playback speed';

  @override
  String get playerTrailerFullscreen => 'Fullscreen';

  @override
  String get playerTrailerLoading => 'Loading…';

  @override
  String playerTrailerNextIn(int seconds) {
    return 'Next trailer · ${seconds}s';
  }

  @override
  String get playerTrailerUpNext => 'Up next';

  @override
  String get playerTrailerSubtitlesOff => 'Off';

  @override
  String get playerTrailerNoSubtitles =>
      'No subtitles available for this trailer.';

  @override
  String playerTrailerCaptionAuto(String name) {
    return '$name (auto)';
  }

  @override
  String get playerTrailerNoQuality => 'No quality options for this trailer.';

  @override
  String get playerTrailerPlayerMenuTitle => 'Player';

  @override
  String get playerTrailerBuiltIn => 'Built-in';

  @override
  String get playerTrailerForjaTrailer => 'Forja trailer';

  @override
  String get playerTrailerExternalApp => 'External app';

  @override
  String get playerTrailerOpenYouTubeFailed => 'Could not open YouTube';

  @override
  String get playerLiveStreamEnded => 'Stream ended';

  @override
  String get playerLiveReconnecting => 'Reconnecting…';

  @override
  String get playerLivePreparingPlayback => 'Preparing playback…';

  @override
  String get playerLiveRefreshingStream => 'Refreshing stream…';

  @override
  String get playerLiveUnlockingSource => 'Unlocking source…';

  @override
  String get playerLiveStreamOffline => 'Stream offline';

  @override
  String get playerLivePlaybackFailed => 'Playback failed';

  @override
  String get playerLiveSwitchingPlayer => 'Switching player…';

  @override
  String get playerLiveSwitchingSoftwareDecode =>
      'Switching to software decode…';

  @override
  String get playerLiveBuffering => 'Buffering…';

  @override
  String playerLiveSwitchingTo(String name) {
    return 'Switching to $name…';
  }

  @override
  String playerLiveTrying(String name) {
    return 'Trying $name…';
  }

  @override
  String playerLiveOfflineRetrying(int seconds) {
    return 'Stream offline - retrying every ${seconds}s…';
  }

  @override
  String playerLiveReconnectingAttempt(int attempt, int max) {
    return 'Reconnecting… (attempt $attempt/$max)';
  }

  @override
  String get playerLiveSubtitleFailed => 'Subtitle failed';

  @override
  String get playerLiveSearchSubtitles => 'Search subtitles';

  @override
  String get playerLiveFilmOrSeriesName => 'Film or series name';

  @override
  String get playerLiveYearOptional => 'Year (optional)';

  @override
  String get playerLiveSeasonLabel => 'Season';

  @override
  String get playerLiveEpisodeLabel => 'Episode';

  @override
  String playerLiveExternalPlayerNotFound(String player) {
    return '$player not found.';
  }

  @override
  String get playerLiveStreamStats => 'Stream stats';

  @override
  String get playerLiveInAppMiniPlayer => 'In-app mini player';

  @override
  String get playerLivePictureInPicture => 'Picture in Picture';

  @override
  String get playerLiveBadge => 'LIVE';

  @override
  String playerLiveEpisodeFallback(int number) {
    return 'Episode $number';
  }

  @override
  String playerLiveSeasonTitle(int number) {
    return 'Season $number';
  }

  @override
  String playerLiveShowSeasonTitle(String show, int number) {
    return '$show · Season $number';
  }

  @override
  String get playerLiveSourceTitle => 'Source';

  @override
  String get playerLiveVlcNotFound =>
      'VLC not found. Install VLC or use MediaKit.';

  @override
  String get playerLiveStatsStatus => 'Status';

  @override
  String get playerLiveStatsBuffering => 'Buffering';

  @override
  String get playerLiveStatsPaused => 'Paused';

  @override
  String get playerLiveStatsEngine => 'Engine';

  @override
  String get playerLiveStatsRecoveries => 'Recoveries';

  @override
  String get playerLiveStatsResolution => 'Resolution';

  @override
  String get playerLiveStatsVideo => 'Video';

  @override
  String get playerLiveStatsVideoBitrate => 'Video bitrate';

  @override
  String get playerLiveStatsDisplayFps => 'Display FPS';

  @override
  String get playerLiveStatsAudioTrack => 'Audio track';

  @override
  String get playerLiveStatsAudioBitrate => 'Audio bitrate';

  @override
  String get playerLiveStatsSubtitle => 'Subtitle';

  @override
  String get playerLiveStatsOff => 'Off';

  @override
  String get playerLiveStatsCache => 'Cache';

  @override
  String get playerLiveStatsCacheUsed => 'Cache used';

  @override
  String get playerLiveStatsBufferedAhead => 'Buffered ahead';

  @override
  String get playerLiveStatsVolume => 'Volume';

  @override
  String get playerLiveStatsSpeed => 'Speed';

  @override
  String get playerLiveStatsDroppedFrames => 'Dropped frames';

  @override
  String get playerLiveStatsDecoderDrops => 'Decoder drops';

  @override
  String get playerLiveStatsVideoTrack => 'Video track';

  @override
  String get playerLiveStatsRetries => 'Retries';

  @override
  String get playerLiveStatsYes => 'yes';

  @override
  String get playerLiveStatsNo => 'no';

  @override
  String get playerLivePlayingOnAirPlay => 'Playing on AirPlay';

  @override
  String get playerLiveCast => 'Cast';

  @override
  String get engineModelsHubs => 'Hubs';

  @override
  String get engineModelsLive => 'Live';

  @override
  String get engineModelsMovie => 'Movie';

  @override
  String get engineModelsMovieAndTv => 'Movie & TV';

  @override
  String get engineModelsPlugins => 'Plugins';

  @override
  String get engineModelsLanguageItalian => 'Italian';

  @override
  String get engineModelsLanguageGerman => 'German';

  @override
  String get engineModelsLanguagePortuguese => 'Portuguese';

  @override
  String get engineModelsLanguageArabic => 'Arabic';

  @override
  String get engineModelsLanguageHindi => 'Hindi';

  @override
  String get engineModelsLanguageTurkish => 'Turkish';

  @override
  String get engineModelsLanguageJapanese => 'Japanese';

  @override
  String get engineModelsLanguageKorean => 'Korean';

  @override
  String get engineModelsLanguageChinese => 'Chinese';

  @override
  String get engineModelsLanguageDutch => 'Dutch';

  @override
  String get engineModelsLanguagePolish => 'Polish';

  @override
  String get engineModelsLanguageRussian => 'Russian';

  @override
  String get engineRuntimeActionFailed => 'Action failed';

  @override
  String get engineRuntimeAddToMyList => 'Add to My List';

  @override
  String get engineRuntimeAddedToMyList => 'Added to My List';

  @override
  String engineRuntimeAllKind(String kind) {
    return 'All $kind';
  }

  @override
  String get engineRuntimeCast => 'Cast';

  @override
  String engineRuntimeClearKind(String kind) {
    return 'Clear $kind';
  }

  @override
  String get engineRuntimeContinueWatching => 'Continue Watching';

  @override
  String engineRuntimeCreditsShort(int credits) {
    return '$credits cr';
  }

  @override
  String get engineRuntimeDealDisabled => 'Deal is not enabled on this account';

  @override
  String engineRuntimeDealDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dealt $count portals',
      one: 'Dealt 1 portal',
    );
    return '$_temp0';
  }

  @override
  String get engineRuntimeDealNone => 'No portals dealt — pool may be empty';

  @override
  String engineRuntimeDealRefreshFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Dealt $count portals but the list could not refresh — reopen Portals',
      one: 'Dealt 1 portal but the list could not refresh — reopen Portals',
    );
    return '$_temp0';
  }

  @override
  String get engineRuntimeDealSignIn => 'Sign in and pick a profile to Deal';

  @override
  String engineRuntimeDealTooltipCredits(String label, int credits) {
    return '$label ($credits credits)';
  }

  @override
  String engineRuntimeDealTooltipNoCredits(String label) {
    return '$label (no credits)';
  }

  @override
  String get engineRuntimeDetails => 'Details';

  @override
  String get engineRuntimeFetchingCatalog => 'Fetching catalog…';

  @override
  String get engineRuntimeFilms => 'Films';

  @override
  String get engineRuntimeFilters => 'Filters';

  @override
  String get engineRuntimeHome => 'Home';

  @override
  String get engineRuntimeHubLayoutInvalid => 'This hub’s layout is invalid.';

  @override
  String get engineRuntimeHubLoadFailed => 'Couldn’t load this hub. Try again.';

  @override
  String get engineRuntimeHubPluginOff =>
      'This hub plugin is off. Enable it under Settings → Sources → Forja (Hubs).';

  @override
  String get engineRuntimeListEmpty => 'Your list is empty';

  @override
  String get engineRuntimeLoading => 'Loading…';

  @override
  String get engineRuntimeMyList => 'My List';

  @override
  String get engineRuntimeNoChannelsInView => 'No channels in this view';

  @override
  String get engineRuntimeNoFavorites => 'No favorites';

  @override
  String get engineRuntimeNoFavoritesHint =>
      'Star a live channel to keep it here.';

  @override
  String get engineRuntimeNoHubPack => 'No hub pack for this tab.';

  @override
  String get engineRuntimeNoPlayableStream => 'No playable stream';

  @override
  String get engineRuntimeNoResults => 'No results found';

  @override
  String get engineRuntimeNothingHere => 'Nothing here';

  @override
  String get engineRuntimeNothingHereYet => 'Nothing here yet.';

  @override
  String get engineRuntimeNothingWatched => 'Nothing watched yet';

  @override
  String get engineRuntimeNothingWatchedHint =>
      'Channels you play on Live land here (last 30).';

  @override
  String get engineRuntimeOpen => 'Open';

  @override
  String get engineRuntimeOptions => 'Options';

  @override
  String get engineRuntimePlay => 'Play';

  @override
  String get engineRuntimePortalNotFound => 'Portal not found';

  @override
  String get engineRuntimePortalSelectFailed => 'Could not select portal';

  @override
  String get engineRuntimePortals => 'Portals';

  @override
  String get engineRuntimePortalsNoPack => 'No portals pack installed';

  @override
  String get engineRuntimePortalsUnavailable => 'Portals unavailable';

  @override
  String get engineRuntimeRecommendations => 'Recommendations';

  @override
  String get engineRuntimeRemoveFromMyList => 'Remove from My List';

  @override
  String get engineRuntimeRemoved => 'Removed';

  @override
  String get engineRuntimeRemovedFromMyList => 'Removed from My List';

  @override
  String get engineRuntimeRemovedLocallySimklFailed =>
      'Removed locally · Simkl failed';

  @override
  String engineRuntimeResumeFailed(String error) {
    return 'Resume failed: $error';
  }

  @override
  String get engineRuntimeSavedLocallySimklFailed =>
      'Saved locally · Simkl failed';

  @override
  String get engineRuntimeSchedule => 'Schedule';

  @override
  String get engineRuntimeScheduleAiring => 'Airing';

  @override
  String get engineRuntimeScheduleAiringHint =>
      'In-play and 24/7 — including rows without streams yet';

  @override
  String get engineRuntimeScheduleAiringUpcoming => 'Airing + upcoming';

  @override
  String get engineRuntimeScheduleBothHint =>
      'Airing + 24/7, plus upcoming within the horizon';

  @override
  String get engineRuntimeScheduleHorizon => 'Horizon';

  @override
  String engineRuntimeScheduleHorizonHint(int hours) {
    return 'Upcoming kickoffs in the next ${hours}h';
  }

  @override
  String get engineRuntimeScheduleIntro =>
      'What to show, and how far ahead to load upcoming:';

  @override
  String engineRuntimeScheduleNext(String horizon) {
    return 'Next · $horizon';
  }

  @override
  String get engineRuntimeScheduleStatus => 'Status';

  @override
  String get engineRuntimeScheduleUpcoming => 'Upcoming';

  @override
  String get engineRuntimeScheduleUpcomingHint =>
      'Not started yet, within the horizon below';

  @override
  String get engineRuntimeSearchFailed => 'Search failed';

  @override
  String get engineRuntimeSearchHint => 'Search…';

  @override
  String get engineRuntimeSearchHintEnter => 'Press Enter to search';

  @override
  String get engineRuntimeSearchHintFilters => 'Set filters, then tap Search';

  @override
  String get engineRuntimeSearchHintOk => 'Press OK to search';

  @override
  String get engineRuntimeSearchPrompt => 'Search for your favorite content';

  @override
  String get engineRuntimeSectionLoadFailed => 'Could not load this section.';

  @override
  String get engineRuntimeSeries => 'Series';

  @override
  String get engineRuntimeShareCodeCopied => 'Share code copied';

  @override
  String get engineRuntimeShareCodeFailed => 'Could not create share code';

  @override
  String engineRuntimeSimklSavedAs(String saved, String requested) {
    return 'Simkl saved as $saved (not $requested)';
  }

  @override
  String engineRuntimeSimklStillAiring(String status) {
    return 'Still airing on Simkl · kept as $status';
  }

  @override
  String get engineRuntimeSomethingWrong => 'Something went wrong';

  @override
  String get engineRuntimeSort => 'Sort';

  @override
  String get engineRuntimeSortCategories => 'Categories';

  @override
  String get engineRuntimeSortChannels => 'Channels';

  @override
  String get engineRuntimeSortNameAsc => 'Name (A–Z)';

  @override
  String get engineRuntimeSortNameDesc => 'Name (Z–A)';

  @override
  String get engineRuntimeSortPlaylistOrder => 'Playlist Order';

  @override
  String get engineRuntimeStream => 'Stream';

  @override
  String get engineRuntimeTrailers => 'Trailers';

  @override
  String get engineRuntimeUpdating => 'Updating';

  @override
  String get engineRuntimeViewDetails => 'View details';

  @override
  String enginePacksUpdatedToast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plugin packs updated',
      one: '1 plugin pack updated',
    );
    return '$_temp0';
  }

  @override
  String enginePacksUpdateTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Update $count plugin packs?',
      one: 'Update plugin pack?',
    );
    return '$_temp0';
  }

  @override
  String enginePacksUpdateBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Download and install newer versions of these packs.',
      one: 'Download and install the newer version of this pack.',
    );
    return '$_temp0';
  }

  @override
  String get enginePacksUpdateButton => 'Update';

  @override
  String get enginePacksKindProviders => 'Providers';

  @override
  String get enginePacksKindLive => 'Live';

  @override
  String get enginePacksKindTorrent => 'Torrent';

  @override
  String get enginePacksKindHubs => 'Hubs';

  @override
  String get enginePortalsShareCodeInvalid => 'Share code invalid';

  @override
  String get enginePortalsShareCodeNotFound =>
      'Share code not found or invalid';

  @override
  String get enginePortalsShareUnavailable =>
      'Share service temporarily unavailable. Try again later.';

  @override
  String get enginePortalsShareLoadFailed => 'Could not load share code';

  @override
  String get enginePortalsErrM3uNameRequired =>
      'Portal name required for M3U playlists';

  @override
  String get enginePortalsErrUrlRequired => 'URL required';

  @override
  String get enginePortalsErrXtreamRequired =>
      'URL, username, and password required';

  @override
  String get enginePortalsErrMacRequired => 'MAC (username) required';

  @override
  String get enginePortalsActionFailed => 'Action failed';

  @override
  String get enginePortalsDefaultName => 'Portal';

  @override
  String get enginePortalsAdded => 'Portal added';

  @override
  String get enginePortalsSaving => 'Saving…';

  @override
  String get enginePortalsAdding => 'Adding portal…';

  @override
  String get enginePortalsEditTitle => 'Edit Portal';

  @override
  String get enginePortalsAddTitle => 'Add Portal';

  @override
  String get enginePortalsNameLabel => 'Portal name';

  @override
  String get enginePortalsNameHint => 'My provider';

  @override
  String get enginePortalsNameRandom => 'Random name';

  @override
  String get enginePortalsAddAction => 'Add';

  @override
  String get enginePortalsShareCodeTitle => 'Share code';

  @override
  String get enginePortalsNameRequiredLabel => 'Portal name (required)';

  @override
  String get enginePortalsPlaylistUrl => 'Playlist URL';

  @override
  String get enginePortalsChooseFile => 'Choose local file';

  @override
  String get enginePortalsMacLabel => 'MAC address';

  @override
  String get enginePortalsUsernameLabel => 'Username';

  @override
  String get enginePortalsUsernameHint => 'username';

  @override
  String get enginePortalsGenerateMac => 'Generate MAC';

  @override
  String get enginePortalsSerialLabel => 'Serial (optional)';

  @override
  String get enginePortalsSerialHint => 'device serial';

  @override
  String get enginePortalsPasswordHint => 'password';

  @override
  String get enginePortalsShowPassword => 'Show password';

  @override
  String get enginePortalsHidePassword => 'Hide password';

  @override
  String get enginePortalsUserAgentLabel => 'User-Agent (optional)';

  @override
  String get enginePortalsHideManual => 'Hide manual entry';

  @override
  String get enginePortalsEnterUrlManually => 'Enter URL manually';

  @override
  String get enginePortalsLoadingShareCode => 'Loading share code…';

  @override
  String get engineDetailsFallbackTitle => 'Details';

  @override
  String get engineDetailsMatchLive => 'Live';

  @override
  String engineDetailsMatchViewers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count viewers',
      one: '1 viewer',
    );
    return '$_temp0';
  }

  @override
  String get engineDetailsMatchingLiveTv => 'Matching Live TV…';

  @override
  String get engineDetailsFetchingStreams => 'Fetching streams…';

  @override
  String get engineDetailsPlay => 'Play';

  @override
  String get engineDetailsLoading => 'Loading';

  @override
  String get engineDetailsClearTooltip => 'Clear progress & stream cache';

  @override
  String get engineDetailsTrailer => 'Trailer';

  @override
  String get engineDetailsMore => 'More';

  @override
  String engineDetailsSimklRating(int rating) {
    return 'Simkl rating: $rating';
  }

  @override
  String get engineDetailsRateOnSimkl => 'Rate on Simkl';

  @override
  String get engineDetailsSimklLoginFirst => 'Login to Simkl first in Settings';

  @override
  String get engineDetailsRate => 'Rate';

  @override
  String get engineDetailsLoadFailed => 'Couldn’t load details. Try again.';

  @override
  String get engineDetailsNoSavedFile => 'No saved file';

  @override
  String engineDetailsResumeEpisode(int episode) {
    return 'Resume Ep $episode';
  }

  @override
  String engineDetailsPlayEpisode(int episode) {
    return 'Play Ep $episode';
  }

  @override
  String get engineDetailsCast => 'Cast';

  @override
  String get engineDetailsCharacters => 'Characters';

  @override
  String get engineDetailsCrew => 'Crew';

  @override
  String engineStoreNoSearch(String hub) {
    return '$hub has no search';
  }

  @override
  String get engineStoreTypeToSearch => 'Type a title to search';

  @override
  String engineStoreNoMatches(String hub) {
    return 'No matches in $hub';
  }

  @override
  String get engineStoreUntitled => 'Untitled';

  @override
  String get engineStoreHubLabel => 'Hub';

  @override
  String engineStoreSearchHub(String name) {
    return 'Search $name';
  }

  @override
  String engineStoreOpenInHub(String hub) {
    return 'Open in $hub';
  }

  @override
  String get engineStoreSearchTitle => 'Search title';

  @override
  String get engineStoreSearchTitleTv => 'Search title — OK to type';

  @override
  String get engineStoreBestMatch => 'Best match';

  @override
  String get engineStoreRemovedFromList => 'Removed from My List';

  @override
  String get engineStoreRemovedLocalFailed => 'Removed locally · Simkl failed';

  @override
  String get engineStoreSavedLocalFailed => 'Saved locally · Simkl failed';

  @override
  String get engineStoreNoHub => 'No hub available to open this title';

  @override
  String get engineStoreNoHandoff => 'That match has no open handoff';

  @override
  String engineStoreNoHandoffFor(String name) {
    return 'No open handoff for $name';
  }

  @override
  String get accountBack => 'Back';

  @override
  String get accountChooserLoadFailed => 'Could not load saved accounts.';

  @override
  String get accountChooserSwitchFailed =>
      'Could not switch account. Sign in again for that user.';

  @override
  String accountChooserMaxAccounts(int count) {
    return 'Maximum of $count accounts on this device.';
  }

  @override
  String get accountChooserAddFailed => 'Could not add account. Try again.';

  @override
  String get accountChooserTitle => 'Accounts';

  @override
  String get accountChooserHeading => 'Who’s signed in?';

  @override
  String get accountChooserSubtitle =>
      'Switch accounts on this device, or add another with QR / code.';

  @override
  String get accountChooserActiveGroup => 'Active';

  @override
  String get accountChooserActiveNow => 'Active now';

  @override
  String get accountChooserOtherGroup => 'Other accounts';

  @override
  String get accountChooserAdd => 'Add account';

  @override
  String get accountChooserRemoveQuestion => 'Remove this account?';

  @override
  String get accountChooserTapToSwitch => 'Tap to switch';

  @override
  String get accountChooserRemoveTooltip => 'Remove from this device';

  @override
  String get accountEntryMfaRequired =>
      'Authenticator required. Finish MFA on the web portal, then use Web login.';

  @override
  String get accountEntryMfaPrompt =>
      'Enter the 6-digit code from your authenticator app.';

  @override
  String get accountEntryMfaShortCode =>
      'Enter the 6-digit authenticator code.';

  @override
  String get accountEntryMfaVerifyFailed =>
      'Could not verify the code. Try again.';

  @override
  String get accountEntryMissingCredentials => 'Enter your email and password.';

  @override
  String get accountEntryConfirmEmail =>
      'Check your email and open the confirmation link, then come back to sign in.';

  @override
  String get accountEntryConnectFailed =>
      'Could not connect to Forja. Check your connection and retry.';

  @override
  String get accountEntryWebOpening =>
      'Opening browser - sign in on the web, then return here. Tap Cancel if the browser does not open.';

  @override
  String get accountEntryWebIncomplete =>
      'Web login did not complete. Try again.';

  @override
  String get accountEntrySignupOpenFailed =>
      'Could not open the signup page in your browser.';

  @override
  String get accountEntryTagline => 'CREATIVE PLAYER';

  @override
  String get accountEntryHeadline => 'One player.\nYour sources.\nEvery ';

  @override
  String get accountEntryWordStream => 'stream';

  @override
  String get accountEntryWordSync => 'sync';

  @override
  String get accountEntryWordLive => 'live';

  @override
  String get accountEntryWordPlay => 'play';

  @override
  String get accountEntryIntro =>
      'Sign in to sync settings and profiles across every screen. New accounts live on the web - not in the app.';

  @override
  String get accountEntryChipIptvGuides => 'IPTV guides';

  @override
  String get accountEntryChipProfiles => 'Profiles';

  @override
  String get accountEntryChipDeskTv => 'Desk → TV';

  @override
  String get accountEntryWelcome => 'Welcome back';

  @override
  String get accountEntryMfaSubtitle =>
      'Enter the code from your authenticator app to finish sign-in.';

  @override
  String get accountEntrySubtitle =>
      'Use your Forja account, or open the browser to sign in on the web.';

  @override
  String get accountEntryAuthCodeLabel => 'Authenticator code';

  @override
  String get accountEntryShowPassword => 'Show password';

  @override
  String get accountEntryHidePassword => 'Hide password';

  @override
  String get accountEntryVerifying => 'Verifying…';

  @override
  String get accountEntryVerifyCode => 'Verify code';

  @override
  String get accountEntryConnecting => 'Connecting…';

  @override
  String get accountEntryCreateOnWeb => 'Create an account on the web →';

  @override
  String get accountEntryContinueNoAccount => 'Continue without an account';

  @override
  String get accountEntryGuestNote =>
      'Guest mode keeps everything on this device. You can sign in later from Settings.';

  @override
  String get accountLinkExpired =>
      'This code expired. Start again to get a new one.';

  @override
  String get accountLinkCancelled =>
      'Linking was cancelled. Start again to get a new code.';

  @override
  String get accountLinkSigningIn => 'Signing you in';

  @override
  String get accountLinkCreatingSession =>
      'Creating a secure session for this device.';

  @override
  String get accountLinkThisDevice => 'LINK THIS DEVICE';

  @override
  String get accountLinkOpen => 'Open ';

  @override
  String get accountLinkEnterCode =>
      'Enter the code or scan the QR from your phone.';

  @override
  String get accountGetNewCode => 'Get a new code';

  @override
  String get accountLinkThisTv => 'LINK THIS TV';

  @override
  String get accountLinkOpenInBrowser => 'Open link page in browser';

  @override
  String get accountPacksUrlCopied => 'URL copied — open on your phone';

  @override
  String get accountPacksOpenCommunityFailed =>
      'Could not open Community Packs.';

  @override
  String get accountPacksLoadingOfficial => 'Loading official packs…';

  @override
  String get accountPacksLoadOfficialFailed =>
      'Could not load official packs. Skip and add them later in Settings.';

  @override
  String get accountPacksPreparing => 'Preparing official packs…';

  @override
  String accountPacksInstalledWithErrors(int count, String details) {
    return 'Installed with $count error(s): $details';
  }

  @override
  String get accountPacksFinishing => 'Finishing…';

  @override
  String get accountPacksInstallFailed =>
      'Install failed. You can skip and add packs later in Settings.';

  @override
  String get accountPacksTitleChoose => 'Choose official packs';

  @override
  String get accountPacksTitleUnlock => 'Unlock the best experience';

  @override
  String get accountPacksBodyPicking =>
      'Recommended packs are checked. Add or remove any, then Install.';

  @override
  String get accountPacksBodyIntro =>
      'Packs add catalogs, stream sources, live sports, and more. Pick official ForjaHQ packs, or browse Community Packs and choose on the web.';

  @override
  String get accountPacksLoading => 'Loading…';

  @override
  String accountPacksTvCommunity(String url) {
    return 'Choose packs on your phone\n$url';
  }

  @override
  String get accountPacksSkip => 'Skip for now';

  @override
  String get accountProfileOpenFailed =>
      'Could not open this profile. Check your connection and retry.';

  @override
  String get accountProfileMaxProfiles => 'Maximum of 5 profiles per account.';

  @override
  String get accountProfileSaveFailed => 'Could not save profile.';

  @override
  String get accountProfileDeleteFailed => 'Could not delete profile.';

  @override
  String get accountProfileLoadFailed =>
      'Could not load profiles. Check your connection and retry.';

  @override
  String get accountProfileCreateTitle => 'Create your profile';

  @override
  String get accountProfileAdd => 'Add profile';

  @override
  String get accountProfileEditTitle => 'Edit profile';

  @override
  String get accountProfileAccountTag => 'ACCOUNT';

  @override
  String get accountProfileManage => 'Manage profiles';

  @override
  String get accountProfileWhosWatching => 'Who’s watching?';

  @override
  String get accountProfileLoadingProfiles => 'Loading profiles…';

  @override
  String get accountProfileLoadWhosWatchingFailed =>
      'Could not load who’s watching right now.';

  @override
  String get accountProfileCreateHint =>
      'Create a profile to sync settings on this device.';

  @override
  String get accountProfileManageHint => 'Edit a profile or add a new one.';

  @override
  String get accountProfileChooseHint =>
      'Choose the profile whose settings you want on this device.';

  @override
  String get accountProfileUseAnotherAccount => 'Use another account';

  @override
  String get accountProfileDone => 'Done';

  @override
  String get accountProfileAccountSettings => 'Account settings';

  @override
  String get accountProfileNewName => 'New profile';

  @override
  String get accountProfileNameLabel => 'Profile name';

  @override
  String get accountProfileChooseAvatar => 'CHOOSE AN AVATAR';

  @override
  String get accountProfileSaving => 'Saving…';

  @override
  String get accountProfileSave => 'Save profile';

  @override
  String get accountProfileDelete => 'Delete profile';

  @override
  String get accountSplashLoadingProfile => 'Loading profile…';

  @override
  String get accountSplashSavingCurrent => 'Saving current profile…';

  @override
  String accountSplashLoadingNamed(String name) {
    return 'Loading $name…';
  }

  @override
  String get accountSplashSyncing => 'Syncing settings…';

  @override
  String get accountSplashPulling => 'Pulling your tabs and sources…';

  @override
  String get accountSplashApplying => 'Applying playback preferences…';

  @override
  String get appBootAlmostReady => 'Almost ready…';

  @override
  String get accountSplashWarmingHome => 'Warming up Home…';

  @override
  String get accountSplashOpeningSyncing =>
      'Opening while settings finish syncing. IPTV portals load when ready.';

  @override
  String get appBootPluginsBackground =>
      'Plugins keep downloading in the background.';

  @override
  String get appBootOpeningLiveIptv => 'Opening Live & IPTV…';

  @override
  String appBootOpeningNamed(String label) {
    return 'Opening $label…';
  }

  @override
  String get appBootWarmingCatalog => 'Warming catalog…';

  @override
  String get appBootLoadingPlugins => 'Loading plugins…';

  @override
  String get appBootJustAMoment => 'Just a moment…';

  @override
  String get appBootStartingProxy => 'Starting stream proxy…';

  @override
  String get appBootStartingTorrent => 'Starting torrent engine…';

  @override
  String get accountLinkSomethingWrong => 'Something went wrong.';

  @override
  String get accountTvContinueGuest => 'Continue as guest';

  @override
  String get accountTvTitle => 'Your cinema.\nOn the big screen.';

  @override
  String get accountTvBody =>
      'The couch is ready. So is Forja. Open a film, chase a series, catch the match, or flip through live TV.';

  @override
  String get accountLinkCouldNot => 'COULD NOT LINK';

  @override
  String get syncPortalLimitUnlimited => 'Unlimited';

  @override
  String get syncPortalLimitReached => 'Portal limit reached.';

  @override
  String syncPortalLimitMax(int count) {
    return 'Maximum of $count portals per profile';
  }

  @override
  String get appBootGettingReady => 'Getting things ready…';

  @override
  String get appBootSlowCatalog =>
      'Loading catalog services is taking longer than expected.';

  @override
  String get appBootWarmingShell => 'Warming up the shell…';

  @override
  String get appBootLoadingProfile => 'Loading your profile…';

  @override
  String get appBootCheckingConnection => 'Checking connection…';

  @override
  String get sharedDownloadsNoSavedFile => 'No saved file';

  @override
  String get sharedDownloadsSaved => 'Saved';

  @override
  String sharedDownloadsSeasonNumber(int number) {
    return 'Season $number';
  }

  @override
  String get sharedDownloadsDownloading => 'Downloading';

  @override
  String sharedDownloadsDownloadingCount(int count) {
    return 'Downloading · $count';
  }

  @override
  String sharedDownloadsSavedCount(int count) {
    return 'Saved · $count';
  }

  @override
  String get sharedDownloadsPlayOnline => 'Play online';

  @override
  String get sharedDownloadsView => 'View';

  @override
  String get sharedDownloadsExternalNoOffline =>
      'External links can’t be saved offline';

  @override
  String get sharedDownloadsTorrentsNoOffline =>
      'Torrents aren\'t available for offline download yet';

  @override
  String get sharedDownloadsDashNoOffline =>
      'DASH streams can\'t be saved offline yet';

  @override
  String get sharedDownloadsStreamNoOffline =>
      'This stream can’t be saved offline';

  @override
  String sharedDownloadsFree(String size) {
    return 'Free $size';
  }

  @override
  String get sharedDownloadsAlreadySaved => 'Already saved offline';

  @override
  String sharedDownloadsAlreadyDownloading(String title) {
    return 'Already downloading $title';
  }

  @override
  String sharedDownloadsDownloadingTitle(String title) {
    return 'Downloading $title';
  }

  @override
  String get sharedDownloadsFailedToStart => 'Download failed to start';

  @override
  String get sharedDownloadsLinkExpired =>
      'Stream link expired — open Sources and download again';

  @override
  String get sharedDownloadsFileMissing => 'Download file is missing';

  @override
  String get sharedDownloadsFileUnplayableDelete =>
      'Downloaded file can’t be played — delete it and download again';

  @override
  String get sharedDownloadsFileUnplayable => 'Downloaded file can’t be played';

  @override
  String get sharedDownloadsNoOnlineStream => 'No online stream';

  @override
  String get sharedDownloadsFindingStream => 'Finding a stream…';

  @override
  String get sharedDownloadsSizeUnknown => 'Size unknown';

  @override
  String get sharedDownloadsFileMovedOrDeleted =>
      'File was moved or deleted from disk';

  @override
  String get sharedDownloadsEmptyUrl => 'Empty download URL';

  @override
  String sharedDownloadsServerHttp(int code, String phrase) {
    return 'Server returned HTTP $code: $phrase';
  }

  @override
  String get sharedDownloadsServerPlaylist =>
      'Server returned a playlist/page, not a video file';

  @override
  String sharedDownloadsReconnectingRemaining(int attempt) {
    return 'Reconnecting remaining data (attempt $attempt)...';
  }

  @override
  String sharedDownloadsReconnecting(int attempt) {
    return 'Reconnecting (attempt $attempt)...';
  }

  @override
  String get sharedDownloadsFileMissingShort => 'Download file missing';

  @override
  String get sharedDownloadsIncomplete =>
      'Download incomplete — delete and try again';

  @override
  String get sharedDownloadsNotPlayableVideo =>
      'Downloaded file is not a playable video';

  @override
  String get sharedDownloadsTooSmall => 'Download too small to be a video file';

  @override
  String sharedDownloadsSaveFinalFailed(String error) {
    return 'Failed to save final file: $error';
  }

  @override
  String sharedServicesUpdateReadyToInstall(String version) {
    return 'Forja $version is ready to install.';
  }

  @override
  String get sharedServicesOpenDownloadUrl => 'Open download URL';

  @override
  String get sharedServicesUpdateFileGone =>
      'The downloaded update file is no longer available.';

  @override
  String sharedServicesUpdateCheckFailed(String error) {
    return 'Could not check for updates: $error';
  }

  @override
  String get sharedServicesUpdateServerNotConfigured =>
      'Update server is not configured in this build.';

  @override
  String get sharedServicesUpdateServerUnreachable =>
      'Could not reach the update server. Check your connection.';

  @override
  String sharedServicesUpdateServerHttp(int code) {
    return 'Update server returned HTTP $code.';
  }

  @override
  String get sharedServicesUpdateManifestInvalid =>
      'Update manifest was invalid.';

  @override
  String get sharedServicesUpdateNoInstaller =>
      'No installer is published for this device architecture yet.';

  @override
  String sharedServicesUpdateNoAsset(String version) {
    return 'Found $version but no matching installer asset.';
  }

  @override
  String get sharedLanServerUp => 'Server up';

  @override
  String get sharedLanServerUnreachable => 'Server unreachable';

  @override
  String get sharedLanWaitingForPair => 'waiting for pair';

  @override
  String get sharedLanPaired => 'paired';

  @override
  String get sharedLanIdleLower => 'idle';

  @override
  String get sharedLanPlayingLower => 'playing';

  @override
  String get sharedLanIdle => 'Idle';

  @override
  String get sharedLanActive => 'Active';

  @override
  String get sharedLanPlaying => 'Playing';

  @override
  String get sharedLanDesktopOnline => 'Desktop online';

  @override
  String get sharedLanPairWithDesktop =>
      'Pair with a desktop Forja server in Settings → LAN.';

  @override
  String get sharedLanDesktopOffline =>
      'Desktop server is offline. Direct streams still work.';

  @override
  String get sharedMiscBack => 'Back';

  @override
  String get sharedMiscAirPlayCantPlay => 'AirPlay can\'t play this stream';

  @override
  String get sharedPlaybackOpeningPlayer => 'Opening player…';

  @override
  String get sharedPlaybackProbingStreams => 'Probing streams…';

  @override
  String sharedPlaybackProbingStreamsProgress(int done, int total) {
    return 'Probing streams ($done/$total)…';
  }

  @override
  String get sharedPlaybackCheckingServers => 'Checking servers…';

  @override
  String get sharedPlaybackFindingServers => 'Finding servers…';

  @override
  String get sharedPlaybackFindingForjaServers => 'Finding Forja servers…';

  @override
  String get sharedPlaybackStartingStream => 'Starting stream…';

  @override
  String get sharedPlaybackHintStarting => 'Starting playback';

  @override
  String get sharedPlaybackHintTesting => 'Testing which links play';

  @override
  String get sharedPlaybackHintAsking => 'Asking servers for streams';

  @override
  String get sharedPlaybackHintLookingUp => 'Looking up available providers';

  @override
  String sharedPlaybackProbeSummary(int checked, int total, int ready) {
    return '$checked / $total checked · $ready up';
  }

  @override
  String sharedPlaybackProbeSummarySkipped(
    int checked,
    int total,
    int ready,
    int skipped,
  ) {
    return '$checked / $total checked · $ready up · $skipped skipped on TV';
  }

  @override
  String get sharedPlaybackSearchAgain => 'Search again';

  @override
  String get sharedPlaybackSavedLinkBroken =>
      'That saved link is no longer working';

  @override
  String get sharedPlaybackProbeWaiting => 'Waiting';

  @override
  String get sharedPlaybackProbeChecking => 'Checking';

  @override
  String get sharedPlaybackProbeUp => 'Up';

  @override
  String get sharedPlaybackProbeDown => 'Down';

  @override
  String get sharedPlaybackProbeSkipped => 'Skipped';

  @override
  String get sharedPlaybackHideServers => 'Hide servers';

  @override
  String get sharedPlaybackShowServers => 'Show servers';

  @override
  String get sharedPlaybackTapServerFirst => 'Tap a server to check it first';

  @override
  String get sharedPlaybackPressBackToCancel => 'Press Back to cancel';

  @override
  String get sharedPlaybackTryAgain => 'Try again';

  @override
  String get sharedPlaybackCouldNotStart => 'Couldn’t start playback';

  @override
  String get sharedPlaybackNoPluginsOn =>
      'No Forja plugins are on for this title. Open Sources → Forja and turn on providers.';

  @override
  String get sharedPlaybackNoWorkingStream =>
      'None of the Forja plugins returned a working stream right now.';

  @override
  String get sharedPlaybackNoProvidersEnabled =>
      'No Forja providers are enabled for green Play';

  @override
  String get sharedPlaybackNoProvidersMatchLanguages =>
      'No Forja providers match the selected languages';

  @override
  String get sharedPlaybackUnableHandleLink => 'Unable to handle this link';

  @override
  String get sharedPlaybackFailedLoadVideo => 'Failed to load video';

  @override
  String sharedPlaybackErrorWith(String error) {
    return 'Error: $error';
  }

  @override
  String get sharedPlaybackDrmAndroidOnly =>
      'This title is DRM-protected — desktop playback is not available yet.';

  @override
  String sharedPlaybackEpisodeNumber(int number) {
    return 'Episode $number';
  }

  @override
  String sharedPlaybackLabelEpisode(String label, int episode) {
    return '$label · Episode $episode';
  }

  @override
  String sharedPlaybackSeasonEpisode(int season, int episode) {
    return 'Season $season · Episode $episode';
  }

  @override
  String get shellNavbarName => 'Navbar';

  @override
  String shellReloadingNamed(String name) {
    return 'Reloading $name…';
  }

  @override
  String shellNamedReloaded(String name) {
    return '$name reloaded';
  }

  @override
  String get shellSearchHint => 'Search…';

  @override
  String shellSearchHintNamed(String label) {
    return 'Search $label…';
  }

  @override
  String get shellUpdateDownloading => 'Downloading update…';

  @override
  String shellUpdateDownloadingVersion(String version) {
    return 'Downloading Forja $version…';
  }

  @override
  String get shellUpdateSoftwareUpdate => 'Software update';

  @override
  String get shellUpdateNewVersionReady => 'A new version is ready';

  @override
  String shellUpdateYouAreOn(String version) {
    return 'You’re on v$version';
  }

  @override
  String get shellUpdateWhatsNew => 'What’s new';

  @override
  String get shellUpdateHintOkBrowse => 'OK to browse';

  @override
  String get shellUpdateHintRailNotes =>
      '↑↓ versions  ·  → notes  ·  OK to exit';

  @override
  String get shellUpdateHintScrollVersions =>
      '↑↓ scroll  ·  ← versions  ·  OK to exit';

  @override
  String get shellUpdateHintScroll => '↑↓ scroll  ·  OK to exit';

  @override
  String get shellUpdateNoNotes =>
      'No release notes were published for this update.';

  @override
  String shellUpdateNoNotesVersion(String version) {
    return 'No release notes were published for v$version.';
  }

  @override
  String get shellUpdateContinueInBackground => 'Continue in background';

  @override
  String get shellUpdateReleasedToday => 'released today';

  @override
  String get shellUpdateReleasedYesterday => 'released yesterday';

  @override
  String shellUpdateReleasedDaysAgo(int days) {
    return 'released $days days ago';
  }

  @override
  String shellUpdateFailed(String error) {
    return 'Update failed: $error';
  }

  @override
  String shellUpdateDownloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String shellUpdateCouldNotOpen(String error) {
    return 'Could not open the update: $error';
  }

  @override
  String get shellUpdateInstall => 'Install update';

  @override
  String get shellUpdateSkipForNow => 'Skip for now';

  @override
  String get shellUpdateSeeFullChangelog => 'See full changelog on the web';

  @override
  String get shellUpdateViewFullChangelog => 'View full changelog';

  @override
  String get shellUpdateDownloadComplete => 'Download complete';

  @override
  String get shellUpdateDownloadCompleteTitle => 'Download\ncomplete';

  @override
  String get shellUpdateMustCloseWindows =>
      'Forja must close before you install the update. Choose Install to close Forja and launch the installer, or skip for now.';

  @override
  String get shellUpdateMustCloseMac =>
      'Forja must close before you install the update. Choose Install to close Forja and open the disk image, or skip for now.';

  @override
  String shellUpdateMakeExecutable(String fileName) {
    return 'Make the file executable, then run it:\nchmod +x \"$fileName\"\n./$fileName';
  }

  @override
  String get shellUpdateInstallAndClose => 'Install and close Forja';

  @override
  String get shellUpdateDone => 'Done';

  @override
  String get shellUpdateOpenDownloads => 'Open downloads folder';

  @override
  String get shellProfile => 'Profile';

  @override
  String get shellGuest => 'Guest';

  @override
  String get shellEmptyPluginsTitle => 'Plugins';

  @override
  String get shellEmptyPluginsBodyTv =>
      'Install hub and stream packs from a URL or profile.';

  @override
  String get shellEmptyPluginsBody =>
      'Install hub and stream packs from a manifest URL, or sync packs from your profile.';

  @override
  String get shellEmptyAddonsBodyTv =>
      'IPTV, Live Sports, torrent, Stremio, Nuvio, and more.';

  @override
  String get shellEmptyAddonsBody =>
      'Turn on IPTV, Live Sports, torrent, Stremio, Nuvio, and other playback surfaces.';

  @override
  String get shellEmptyFeaturesBodyTv =>
      'Choose which tabs appear in the rail.';

  @override
  String get shellEmptyFeaturesBody =>
      'Choose which tabs appear: Home, Anime, IPTV, Live Sports, Lists, and more.';

  @override
  String get shellEmptyTitle => 'Turn on a feature to get started';

  @override
  String get shellEmptyHint => 'Pick Plugins, Addons, or Features.';

  @override
  String get shellPressBackAgainToExit => 'Press Back again to exit';

  @override
  String get shellPressExitAgainToExit => 'Press Exit again to exit';

  @override
  String get shellDismissCategories => 'Dismiss categories';

  @override
  String get shellCategories => 'Categories';

  @override
  String get shellUpdating => 'Updating';

  @override
  String get accountAvatarCategoryCharacters => 'Characters';

  @override
  String get accountAvatarCategoryCreatures => 'Creatures';

  @override
  String get accountAvatarCategorySpace => 'Space';

  @override
  String get accountAvatarCategoryRetro => 'Retro';

  @override
  String get foundationReadMore => 'Read More';

  @override
  String get foundationReadLess => 'Read Less';

  @override
  String get foundationRetry => 'Retry';

  @override
  String get foundationBack => 'Back';

  @override
  String get foundationNothingHere => 'Nothing here';

  @override
  String get foundationNoCategories => 'No categories';

  @override
  String get foundationNoMatches => 'No matches';

  @override
  String get foundationSearch => 'Search';

  @override
  String get foundationAll => 'All';

  @override
  String get foundationFactName => 'Name';

  @override
  String get foundationFactStatus => 'Status';

  @override
  String get foundationFactLanguage => 'Language';

  @override
  String get foundationFactFirstAired => 'First Aired';

  @override
  String get foundationFactLastAired => 'Last Aired';

  @override
  String get foundationFactSeasons => 'Seasons';

  @override
  String get foundationFactEpisodes => 'Episodes';

  @override
  String get foundationFactNetwork => 'Network';

  @override
  String get foundationFactReleaseDate => 'Release Date';

  @override
  String get foundationFactRuntime => 'Runtime';

  @override
  String get foundationFactProduction => 'Production';

  @override
  String get foundationFactOrigin => 'Origin';

  @override
  String get foundationFactCreatedBy => 'Created by';

  @override
  String get foundationFactBudget => 'Budget';

  @override
  String get foundationFactRevenue => 'Revenue';

  @override
  String get foundationStatusReleased => 'Released';

  @override
  String get foundationStatusEnded => 'Ended';

  @override
  String get foundationStatusReturningSeries => 'Returning Series';

  @override
  String get foundationStatusInProduction => 'In Production';

  @override
  String get foundationStatusCanceled => 'Canceled';

  @override
  String get foundationStatusPlanned => 'Planned';

  @override
  String get foundationStatusPostProduction => 'Post Production';

  @override
  String get foundationStatusRumored => 'Rumored';

  @override
  String get foundationMonthJan => 'Jan';

  @override
  String get foundationMonthFeb => 'Feb';

  @override
  String get foundationMonthMar => 'Mar';

  @override
  String get foundationMonthApr => 'Apr';

  @override
  String get foundationMonthMay => 'May';

  @override
  String get foundationMonthJun => 'Jun';

  @override
  String get foundationMonthJul => 'Jul';

  @override
  String get foundationMonthAug => 'Aug';

  @override
  String get foundationMonthSep => 'Sep';

  @override
  String get foundationMonthOct => 'Oct';

  @override
  String get foundationMonthNov => 'Nov';

  @override
  String get foundationMonthDec => 'Dec';

  @override
  String foundationDatePattern(String month, String day, String year) {
    return '$month $day, $year';
  }

  @override
  String get foundationWordSeeAll => 'See all';

  @override
  String get foundationWordBecauseYouWatched => 'Because you watched';

  @override
  String get foundationWordPlanToWatch => 'Plan to Watch';

  @override
  String get foundationWordWatching => 'Watching';

  @override
  String get foundationWordOnHold => 'On Hold';

  @override
  String get foundationWordCompleted => 'Completed';

  @override
  String get foundationWordDropped => 'Dropped';

  @override
  String get foundationWordEpisodes => 'Episodes';

  @override
  String get foundationWordReload => 'Reload';

  @override
  String get foundationWordClose => 'Close';

  @override
  String get foundationWordComingSoon => 'Coming soon';

  @override
  String get foundationWordScore => 'Score';

  @override
  String get foundationWordAnyScore => 'Any score';

  @override
  String get foundationWordYear => 'Year';

  @override
  String get foundationWordAnyYear => 'Any year';

  @override
  String get foundationWordGenre => 'Genre';

  @override
  String get foundationWordCountry => 'Country';

  @override
  String get foundationWordLanguage => 'Language';

  @override
  String get foundationWordFilms => 'Films';

  @override
  String get foundationWordSeries => 'Series';

  @override
  String get foundationWordAction => 'Action';

  @override
  String get foundationWordAdventure => 'Adventure';

  @override
  String get foundationWordAnimation => 'Animation';

  @override
  String get foundationWordComedy => 'Comedy';

  @override
  String get foundationWordCrime => 'Crime';

  @override
  String get foundationWordDocumentary => 'Documentary';

  @override
  String get foundationWordDrama => 'Drama';

  @override
  String get foundationWordFamily => 'Family';

  @override
  String get foundationWordFantasy => 'Fantasy';

  @override
  String get foundationWordHistory => 'History';

  @override
  String get foundationWordHorror => 'Horror';

  @override
  String get foundationWordMusic => 'Music';

  @override
  String get foundationWordMystery => 'Mystery';

  @override
  String get foundationWordRomance => 'Romance';

  @override
  String get foundationWordSciFi => 'Sci-Fi';

  @override
  String get foundationWordThriller => 'Thriller';

  @override
  String get foundationWordWar => 'War';

  @override
  String get foundationWordWestern => 'Western';

  @override
  String get foundationWordKids => 'Kids';

  @override
  String get foundationWordUsa => 'USA';

  @override
  String get foundationWordUk => 'UK';

  @override
  String get foundationWordFrance => 'France';

  @override
  String get foundationWordGermany => 'Germany';

  @override
  String get foundationWordJapan => 'Japan';

  @override
  String get foundationWordKorea => 'Korea';

  @override
  String get foundationWordIndia => 'India';

  @override
  String get foundationWordItaly => 'Italy';

  @override
  String get foundationWordSpain => 'Spain';

  @override
  String get foundationWordCanada => 'Canada';

  @override
  String get foundationWordAustralia => 'Australia';

  @override
  String get foundationWordChina => 'China';

  @override
  String get foundationWordBrazil => 'Brazil';

  @override
  String get foundationWordMexico => 'Mexico';

  @override
  String get foundationWordSweden => 'Sweden';

  @override
  String get foundationWordNorway => 'Norway';

  @override
  String get foundationWordDenmark => 'Denmark';

  @override
  String get foundationWordTurkey => 'Turkey';

  @override
  String get foundationWordHongKong => 'Hong Kong';

  @override
  String get foundationWordTaiwan => 'Taiwan';

  @override
  String get foundationWordThailand => 'Thailand';

  @override
  String get foundationWordEnglish => 'English';

  @override
  String get foundationWordJapanese => 'Japanese';

  @override
  String get foundationWordKorean => 'Korean';

  @override
  String get foundationWordFrench => 'French';

  @override
  String get foundationWordSpanish => 'Spanish';

  @override
  String get foundationWordGerman => 'German';

  @override
  String get foundationWordItalian => 'Italian';

  @override
  String get foundationWordPortuguese => 'Portuguese';

  @override
  String get foundationWordChinese => 'Chinese';

  @override
  String get foundationWordHindi => 'Hindi';

  @override
  String get foundationWordArabic => 'Arabic';

  @override
  String get foundationWordTurkish => 'Turkish';

  @override
  String get foundationWordThai => 'Thai';

  @override
  String get foundationWordSwedish => 'Swedish';

  @override
  String get foundationWordNorwegian => 'Norwegian';

  @override
  String get foundationWordDanish => 'Danish';

  @override
  String get foundationWordSub => 'SUB';

  @override
  String get foundationWordDub => 'DUB';
}
