import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// Title of the Settings screen, shown when no category is selected.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsCategoryProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile & account'**
  String get settingsCategoryProfileTitle;

  /// No description provided for @settingsCategoryProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Profile, cloud sync, sign in'**
  String get settingsCategoryProfileSubtitle;

  /// Name of the Addons settings category. Product name, keep it consistent with the other Settings screens.
  ///
  /// In en, this message translates to:
  /// **'Addons'**
  String get settingsCategoryAddonsTitle;

  /// No description provided for @settingsCategoryAddonsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Playback, IPTV, torrents, Stremio, debrid, LAN'**
  String get settingsCategoryAddonsSubtitle;

  /// Name of the plugin packs settings category. 'Forja Packs' is a product name.
  ///
  /// In en, this message translates to:
  /// **'Forja Packs'**
  String get settingsCategoryPacksTitle;

  /// No description provided for @settingsCategoryPacksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Install and manage plugin packs'**
  String get settingsCategoryPacksSubtitle;

  /// No description provided for @settingsCategoryFeaturesTitle.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get settingsCategoryFeaturesTitle;

  /// No description provided for @settingsCategoryFeaturesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tabs, order, default menu'**
  String get settingsCategoryFeaturesSubtitle;

  /// No description provided for @settingsCategoryDownloadsTitle.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get settingsCategoryDownloadsTitle;

  /// No description provided for @settingsCategoryDownloadsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Offline library and download progress'**
  String get settingsCategoryDownloadsSubtitle;

  /// No description provided for @settingsCategoryDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Data & backup'**
  String get settingsCategoryDataTitle;

  /// No description provided for @settingsCategoryDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clear cache, export, import'**
  String get settingsCategoryDataSubtitle;

  /// No description provided for @settingsCategoryAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsCategoryAboutTitle;

  /// No description provided for @settingsCategoryAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Updates, version, developer'**
  String get settingsCategoryAboutSubtitle;

  /// No description provided for @settingsLanguageGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageGroupLabel;

  /// No description provided for @settingsLanguageRowTitle.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get settingsLanguageRowTitle;

  /// Subtitle under the app language picker. The app's own screens switch at once; titles, descriptions and text written by packs finish updating after a restart.
  ///
  /// In en, this message translates to:
  /// **'Menus and screens change right away. Titles, descriptions and pack text catch up fully after a restart.'**
  String get settingsLanguageRowSubtitle;

  /// Picker option that follows the device language.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystemDefault;

  /// No description provided for @addonsHostDebridGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Debrid'**
  String get addonsHostDebridGroupLabel;

  /// No description provided for @addonsHostDebridResolveTitle.
  ///
  /// In en, this message translates to:
  /// **'Resolve magnets with debrid'**
  String get addonsHostDebridResolveTitle;

  /// No description provided for @addonsHostDebridResolveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use an installed debrid pack plugin for torrent magnets.'**
  String get addonsHostDebridResolveSubtitle;

  /// No description provided for @addonsHostDebridPluginTitle.
  ///
  /// In en, this message translates to:
  /// **'Magnet resolve plugin'**
  String get addonsHostDebridPluginTitle;

  /// No description provided for @addonsHostDebridPluginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only one debrid plugin can be active.'**
  String get addonsHostDebridPluginSubtitle;

  /// No description provided for @addonsHostPlayTogglesGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Forja addons'**
  String get addonsHostPlayTogglesGroupLabel;

  /// No description provided for @addonsHostPlayTogglesP2pAckedTitle.
  ///
  /// In en, this message translates to:
  /// **'You are aware of P2P streaming'**
  String get addonsHostPlayTogglesP2pAckedTitle;

  /// No description provided for @addonsHostPlayTogglesP2pConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm you are aware of P2P streaming'**
  String get addonsHostPlayTogglesP2pConfirmTitle;

  /// No description provided for @addonsHostPlayTogglesP2pAckedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Direct torrent, Stremio, and Nuvio can be used. Tap to review.'**
  String get addonsHostPlayTogglesP2pAckedSubtitle;

  /// No description provided for @addonsHostPlayTogglesP2pConfirmSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Required once before turning on Direct torrent, Stremio, or Nuvio.'**
  String get addonsHostPlayTogglesP2pConfirmSubtitle;

  /// No description provided for @addonsHostPlayTogglesTorrentTitle.
  ///
  /// In en, this message translates to:
  /// **'Direct torrent'**
  String get addonsHostPlayTogglesTorrentTitle;

  /// No description provided for @addonsHostPlayTogglesTorrentNativeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Search Forja indexers (Jackett / Prowlarr) below.'**
  String get addonsHostPlayTogglesTorrentNativeSubtitle;

  /// No description provided for @addonsHostPlayTogglesTorrentAtvSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Search torrents here. Playing a magnet needs a paired desktop (Settings → LAN).'**
  String get addonsHostPlayTogglesTorrentAtvSubtitle;

  /// No description provided for @addonsHostPlayTogglesStremioTitle.
  ///
  /// In en, this message translates to:
  /// **'Stremio'**
  String get addonsHostPlayTogglesStremioTitle;

  /// No description provided for @addonsHostPlayTogglesStremioNativeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Play from installed Stremio addon streams.'**
  String get addonsHostPlayTogglesStremioNativeSubtitle;

  /// No description provided for @addonsHostPlayTogglesNuvioTitle.
  ///
  /// In en, this message translates to:
  /// **'Nuvio'**
  String get addonsHostPlayTogglesNuvioTitle;

  /// No description provided for @addonsHostPlayTogglesNuvioNativeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Play from installed Nuvio scraper addons below.'**
  String get addonsHostPlayTogglesNuvioNativeSubtitle;

  /// No description provided for @addonsHostPlayTogglesDirectHttpAtvSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Direct HTTP plays on this TV. Magnets need a paired desktop (Settings → LAN).'**
  String get addonsHostPlayTogglesDirectHttpAtvSubtitle;

  /// No description provided for @addonsHostMdblistEnterKeyWarning.
  ///
  /// In en, this message translates to:
  /// **'Please enter an API key'**
  String get addonsHostMdblistEnterKeyWarning;

  /// No description provided for @addonsHostMdblistConnectedToast.
  ///
  /// In en, this message translates to:
  /// **'MDBlist connected!'**
  String get addonsHostMdblistConnectedToast;

  /// No description provided for @addonsHostMdblistConnectedAsToast.
  ///
  /// In en, this message translates to:
  /// **'MDBlist connected as {username}!'**
  String addonsHostMdblistConnectedAsToast(String username);

  /// No description provided for @addonsHostMdblistInvalidKeyError.
  ///
  /// In en, this message translates to:
  /// **'Invalid MDBlist API key'**
  String get addonsHostMdblistInvalidKeyError;

  /// No description provided for @addonsHostMdblistKeyRemovedToast.
  ///
  /// In en, this message translates to:
  /// **'MDBlist API key removed'**
  String get addonsHostMdblistKeyRemovedToast;

  /// No description provided for @addonsHostMdblistIntro.
  ///
  /// In en, this message translates to:
  /// **'Aggregated ratings from IMDb, TMDB, Trakt, Letterboxd, RT, and more'**
  String get addonsHostMdblistIntro;

  /// No description provided for @addonsHostMdblistConnectedStatus.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get addonsHostMdblistConnectedStatus;

  /// No description provided for @addonsHostMdblistConnectedAsStatus.
  ///
  /// In en, this message translates to:
  /// **'Connected as {username}'**
  String addonsHostMdblistConnectedAsStatus(String username);

  /// No description provided for @addonsHostMdblistRemoveKeyButton.
  ///
  /// In en, this message translates to:
  /// **'Remove API Key'**
  String get addonsHostMdblistRemoveKeyButton;

  /// No description provided for @addonsHostMdblistKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'MDBlist API Key'**
  String get addonsHostMdblistKeyLabel;

  /// No description provided for @addonsHostMdblistKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Paste your API key from mdblist.com'**
  String get addonsHostMdblistKeyHint;

  /// No description provided for @addonsHostMdblistSaveKeyButton.
  ///
  /// In en, this message translates to:
  /// **'Save API Key'**
  String get addonsHostMdblistSaveKeyButton;

  /// No description provided for @addonsHostPlayerGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get addonsHostPlayerGroupLabel;

  /// No description provided for @addonsHostPlaybackEngineTitle.
  ///
  /// In en, this message translates to:
  /// **'Movies & series engine'**
  String get addonsHostPlaybackEngineTitle;

  /// No description provided for @addonsHostPlaybackEngineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Used for Home, Search, Anime, Asian Drama, and IPTV Movies/Series. Live IPTV has its own setting under IPTV.'**
  String get addonsHostPlaybackEngineSubtitle;

  /// No description provided for @addonsHostPlaybackAudioLangTitle.
  ///
  /// In en, this message translates to:
  /// **'Preferred Audio Language'**
  String get addonsHostPlaybackAudioLangTitle;

  /// No description provided for @addonsHostPlaybackAudioLangSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Switch to a matching audio track when playback starts. Pick \"None\" to keep the stream default.'**
  String get addonsHostPlaybackAudioLangSubtitle;

  /// No description provided for @addonsHostPlaybackSubtitleLangTitle.
  ///
  /// In en, this message translates to:
  /// **'Preferred Subtitle Language'**
  String get addonsHostPlaybackSubtitleLangTitle;

  /// No description provided for @addonsHostPlaybackSubtitleLangSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Prefer this language for in-stream or online subtitles. In-stream tracks win when they match. Pick \"None\" to start with subs off.'**
  String get addonsHostPlaybackSubtitleLangSubtitle;

  /// No description provided for @addonsHostPlaybackAvoidAudioTitle.
  ///
  /// In en, this message translates to:
  /// **'Avoid unsupported audio (Atmos / TrueHD / 7.1)'**
  String get addonsHostPlaybackAvoidAudioTitle;

  /// No description provided for @addonsHostPlaybackAvoidAudioSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fall back to AC-3, E-AC-3, or AAC when Atmos, TrueHD, or 7.1 is not supported.'**
  String get addonsHostPlaybackAvoidAudioSubtitle;

  /// No description provided for @addonsHostPlaybackAutoNextTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto next episode'**
  String get addonsHostPlaybackAutoNextTitle;

  /// No description provided for @addonsHostPlaybackAutoNextSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start the next episode when one ends. Also available in the player Episodes panel.'**
  String get addonsHostPlaybackAutoNextSubtitle;

  /// No description provided for @addonsHostPlaybackAutoSkipIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto skip intro'**
  String get addonsHostPlaybackAutoSkipIntroTitle;

  /// No description provided for @addonsHostPlaybackAutoSkipIntroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Skip intro and recap segments automatically when timestamps are available.'**
  String get addonsHostPlaybackAutoSkipIntroSubtitle;

  /// No description provided for @addonsHostPlaybackContentWarningsTitle.
  ///
  /// In en, this message translates to:
  /// **'Content warnings'**
  String get addonsHostPlaybackContentWarningsTitle;

  /// No description provided for @addonsHostPlaybackContentWarningsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show IMDb content ratings (nudity, violence, and similar) when playback starts.'**
  String get addonsHostPlaybackContentWarningsSubtitle;

  /// No description provided for @addonsHostPlaybackBackgroundTitle.
  ///
  /// In en, this message translates to:
  /// **'Play in background'**
  String get addonsHostPlaybackBackgroundTitle;

  /// No description provided for @addonsHostPlaybackBackgroundDesktopSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep movies, series, and IPTV playing when Forja is in the background.'**
  String get addonsHostPlaybackBackgroundDesktopSubtitle;

  /// No description provided for @addonsHostPlaybackBackgroundMobileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep movies, series, and IPTV playing when Forja is in the background. (playback pauses until you return).'**
  String get addonsHostPlaybackBackgroundMobileSubtitle;

  /// No description provided for @addonsHostPlaybackRemoteSoundsTitle.
  ///
  /// In en, this message translates to:
  /// **'Remote click sounds'**
  String get addonsHostPlaybackRemoteSoundsTitle;

  /// No description provided for @addonsHostPlaybackRemoteSoundsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Play a short system click when you move D-pad focus or press OK. Off while a video is playing.'**
  String get addonsHostPlaybackRemoteSoundsSubtitle;

  /// No description provided for @addonsHostPlaybackAutoPipTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto picture-in-picture'**
  String get addonsHostPlaybackAutoPipTitle;

  /// No description provided for @addonsHostPlaybackAutoPipSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter picture-in-picture when you switch Space (macOS) or virtual desktop (Windows) while playing. You can still use the player PiP button anytime.'**
  String get addonsHostPlaybackAutoPipSubtitle;

  /// No description provided for @addonsHostPlaybackMiniPlayerTitle.
  ///
  /// In en, this message translates to:
  /// **'Escape to mini player'**
  String get addonsHostPlaybackMiniPlayerTitle;

  /// No description provided for @addonsHostPlaybackMiniPlayerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When Escape would leave the player, demote to the in-app mini instead. Off by default. The top-right mini button always works. Distinct from picture-in-picture.'**
  String get addonsHostPlaybackMiniPlayerSubtitle;

  /// No description provided for @addonsHostPlaybackMaxQualityTitle.
  ///
  /// In en, this message translates to:
  /// **'Max stream quality'**
  String get addonsHostPlaybackMaxQualityTitle;

  /// No description provided for @addonsHostPlaybackMaxQualitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Limit Auto stream quality and HLS start bitrate. Auto aims for a faster first frame. Pick 4K for the highest ladder.'**
  String get addonsHostPlaybackMaxQualitySubtitle;

  /// No description provided for @addonsHostPortalEngineTitle.
  ///
  /// In en, this message translates to:
  /// **'IPTV engine'**
  String get addonsHostPortalEngineTitle;

  /// No description provided for @addonsHostPortalEngineAndroidSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Live channels only. Does not change Movies & series or Live Sports.'**
  String get addonsHostPortalEngineAndroidSubtitle;

  /// No description provided for @addonsHostPortalEngineDesktopSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Live channels only. HLS prefers AVPlayer (Mac) or VLC (Windows) when available; MPEG-TS uses MediaKit.'**
  String get addonsHostPortalEngineDesktopSubtitle;

  /// No description provided for @addonsHostPortalEpgTitle.
  ///
  /// In en, this message translates to:
  /// **'IPTV programme guide (EPG)'**
  String get addonsHostPortalEpgTitle;

  /// No description provided for @addonsHostPortalEpgSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show NOW and NEXT programme info in the player and channel browser.'**
  String get addonsHostPortalEpgSubtitle;

  /// No description provided for @addonsHostPortalMaxQualityTitle.
  ///
  /// In en, this message translates to:
  /// **'IPTV live max quality'**
  String get addonsHostPortalMaxQualityTitle;

  /// No description provided for @addonsHostPortalMaxQualitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'ExoPlayer only. Auto uses the portal’s full quality. Cap at 1080p, 720p, or 480p only on weak devices.'**
  String get addonsHostPortalMaxQualitySubtitle;

  /// No description provided for @addonsHostPortalRecoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'IPTV live recovery'**
  String get addonsHostPortalRecoveryTitle;

  /// No description provided for @addonsHostPortalRecoverySubtitle.
  ///
  /// In en, this message translates to:
  /// **'ExoPlayer only. How live channels reconnect after a stall. Auto picks per source. Stable forces one policy. Classic uses freeze timers. MediaKit ignores this (ffmpeg reconnect). Applies the next time you open the player.'**
  String get addonsHostPortalRecoverySubtitle;

  /// No description provided for @addonsHostPortalReopenStallTitle.
  ///
  /// In en, this message translates to:
  /// **'Reopen on buffer stall'**
  String get addonsHostPortalReopenStallTitle;

  /// No description provided for @addonsHostPortalReopenStallSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ExoPlayer Stable mode only. Reconnect when the picture freezes even if cache still reports data. Leave off unless you need it. Applies the next time you open the player.'**
  String get addonsHostPortalReopenStallSubtitle;

  /// No description provided for @addonsHostPortalMatchRefreshTitle.
  ///
  /// In en, this message translates to:
  /// **'IPTV match display refresh'**
  String get addonsHostPortalMatchRefreshTitle;

  /// No description provided for @addonsHostPortalMatchRefreshSubtitle.
  ///
  /// In en, this message translates to:
  /// **'MediaKit only. Match the TV refresh rate to the channel (for example 50 Hz for 50 fps). Helps 4K stutter. May briefly blink HDMI after the first frame. Applies the next time you open the player.'**
  String get addonsHostPortalMatchRefreshSubtitle;

  /// No description provided for @addonsHostPortalLiveBufferTitle.
  ///
  /// In en, this message translates to:
  /// **'IPTV live buffer'**
  String get addonsHostPortalLiveBufferTitle;

  /// No description provided for @addonsHostPortalLiveBufferSubtitle.
  ///
  /// In en, this message translates to:
  /// **'MediaKit only. Live buffer ahead of playback. Auto uses 30s (same as desktop). Manual 15–30s. Helps underruns, not frame judder. Applies the next time you open the player.'**
  String get addonsHostPortalLiveBufferSubtitle;

  /// No description provided for @addonsHostTorrentSearchGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Torrent search'**
  String get addonsHostTorrentSearchGroupLabel;

  /// No description provided for @addonsHostTorrentInstallPackHint.
  ///
  /// In en, this message translates to:
  /// **'Install the ForjaHQ Torrent pack under Settings → Forja Packs and enable indexers per plugin.'**
  String get addonsHostTorrentInstallPackHint;

  /// No description provided for @addonsHostTorrentSortTitle.
  ///
  /// In en, this message translates to:
  /// **'Default Sort Order'**
  String get addonsHostTorrentSortTitle;

  /// No description provided for @addonsHostTorrentSortSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How torrent results are sorted automatically.'**
  String get addonsHostTorrentSortSubtitle;

  /// No description provided for @addonsHostTorrentFlareSolverrNote.
  ///
  /// In en, this message translates to:
  /// **'UIndex is behind Cloudflare. Point this at a local FlareSolverr or Byparr instance (same /v1 API as Prowlarr indexers).'**
  String get addonsHostTorrentFlareSolverrNote;

  /// No description provided for @addonsHostTorrentEngineGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Torrent engine'**
  String get addonsHostTorrentEngineGroupLabel;

  /// No description provided for @addonsHostTorrentDiskCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Disk cache: {gb} GB'**
  String addonsHostTorrentDiskCacheTitle(int gb);

  /// No description provided for @addonsHostTorrentDiskCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Max torrent data on disk. The file playing now is never deleted. Oldest idle downloads are removed when over this size.'**
  String get addonsHostTorrentDiskCacheSubtitle;

  /// No description provided for @addonsHostTorrentGbLabel.
  ///
  /// In en, this message translates to:
  /// **'{gb} GB'**
  String addonsHostTorrentGbLabel(int gb);

  /// No description provided for @addonsHostTorrentConnectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Connections per torrent: {count}'**
  String addonsHostTorrentConnectionsTitle(int count);

  /// No description provided for @addonsHostTorrentConnectionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Lower (5–25) often streams better on high-seed swarms.'**
  String get addonsHostTorrentConnectionsSubtitle;

  /// No description provided for @addonsHostSimklLoginUnavailableError.
  ///
  /// In en, this message translates to:
  /// **'Simkl login isn’t available in this build'**
  String get addonsHostSimklLoginUnavailableError;

  /// No description provided for @addonsHostSimklLoginStartFailedError.
  ///
  /// In en, this message translates to:
  /// **'Failed to start Simkl login'**
  String get addonsHostSimklLoginStartFailedError;

  /// No description provided for @addonsHostSimklCodeCopiedToast.
  ///
  /// In en, this message translates to:
  /// **'Code {code} copied. Opening {url}…'**
  String addonsHostSimklCodeCopiedToast(String code, String url);

  /// No description provided for @addonsHostSimklLoggedInToast.
  ///
  /// In en, this message translates to:
  /// **'Logged in to Simkl!'**
  String get addonsHostSimklLoggedInToast;

  /// No description provided for @addonsHostSimklLoggedInAsToast.
  ///
  /// In en, this message translates to:
  /// **'Logged in to Simkl as {username}!'**
  String addonsHostSimklLoggedInAsToast(String username);

  /// No description provided for @addonsHostSimklLoggedOutToast.
  ///
  /// In en, this message translates to:
  /// **'Logged out of Simkl'**
  String get addonsHostSimklLoggedOutToast;

  /// No description provided for @addonsHostSimklPickSyncModeError.
  ///
  /// In en, this message translates to:
  /// **'Pick how lists sync first'**
  String get addonsHostSimklPickSyncModeError;

  /// No description provided for @addonsHostSimklSyncError.
  ///
  /// In en, this message translates to:
  /// **'Simkl sync error: {error}'**
  String addonsHostSimklSyncError(String error);

  /// No description provided for @addonsHostSimklSyncedKeptLocal.
  ///
  /// In en, this message translates to:
  /// **'Kept local'**
  String get addonsHostSimklSyncedKeptLocal;

  /// No description provided for @addonsHostSimklSyncedUsedSimkl.
  ///
  /// In en, this message translates to:
  /// **'Used Simkl'**
  String get addonsHostSimklSyncedUsedSimkl;

  /// No description provided for @addonsHostSimklSyncedMerged.
  ///
  /// In en, this message translates to:
  /// **'Merged'**
  String get addonsHostSimklSyncedMerged;

  /// No description provided for @addonsHostSimklSyncedMergedDeleted.
  ///
  /// In en, this message translates to:
  /// **'Merged + deleted'**
  String get addonsHostSimklSyncedMergedDeleted;

  /// No description provided for @addonsHostSimklSyncedGeneric.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get addonsHostSimklSyncedGeneric;

  /// No description provided for @addonsHostSimklSyncSummaryToast.
  ///
  /// In en, this message translates to:
  /// **'{mode} · list ↑{listExported} ↓{listImported}{removed}, progress {progress}, movies {movies}, eps ↑{epsExported} ↓{epsImported}'**
  String addonsHostSimklSyncSummaryToast(
    String mode,
    int listExported,
    int listImported,
    String removed,
    int progress,
    int movies,
    int epsExported,
    int epsImported,
  );

  /// No description provided for @addonsHostSimklIntro.
  ///
  /// In en, this message translates to:
  /// **'Sync your watchlist and watch history with Simkl'**
  String get addonsHostSimklIntro;

  /// No description provided for @addonsHostSimklConnectedStatus.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get addonsHostSimklConnectedStatus;

  /// No description provided for @addonsHostSimklConnectedAsStatus.
  ///
  /// In en, this message translates to:
  /// **'Connected as {username}'**
  String addonsHostSimklConnectedAsStatus(String username);

  /// No description provided for @addonsHostSimklSyncModeTitle.
  ///
  /// In en, this message translates to:
  /// **'How should lists sync?'**
  String get addonsHostSimklSyncModeTitle;

  /// No description provided for @addonsHostSimklSyncModeSubtitleAuto.
  ///
  /// In en, this message translates to:
  /// **'Saved for Sync Now and Auto sync on My List'**
  String get addonsHostSimklSyncModeSubtitleAuto;

  /// No description provided for @addonsHostSimklSyncModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Saved for Sync Now'**
  String get addonsHostSimklSyncModeSubtitle;

  /// No description provided for @addonsHostSimklAutoSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto sync lists on My List'**
  String get addonsHostSimklAutoSyncTitle;

  /// No description provided for @addonsHostSimklAutoSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When you open My List, sync with {mode} and refresh the cached library'**
  String addonsHostSimklAutoSyncSubtitle(String mode);

  /// No description provided for @addonsHostSimklSyncingButton.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get addonsHostSimklSyncingButton;

  /// No description provided for @addonsHostSimklSyncNowButton.
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get addonsHostSimklSyncNowButton;

  /// No description provided for @addonsHostSimklLogoutButton.
  ///
  /// In en, this message translates to:
  /// **'Logout from Simkl'**
  String get addonsHostSimklLogoutButton;

  /// No description provided for @addonsHostSimklEnterCodePrompt.
  ///
  /// In en, this message translates to:
  /// **'Go to the URL below and enter this code:'**
  String get addonsHostSimklEnterCodePrompt;

  /// No description provided for @addonsHostSimklWaitingAuth.
  ///
  /// In en, this message translates to:
  /// **'Waiting for authorization...'**
  String get addonsHostSimklWaitingAuth;

  /// No description provided for @addonsHostSimklLoginButton.
  ///
  /// In en, this message translates to:
  /// **'Login with Simkl'**
  String get addonsHostSimklLoginButton;

  /// No description provided for @addonsHostLanUnpairButton.
  ///
  /// In en, this message translates to:
  /// **'Unpair'**
  String get addonsHostLanUnpairButton;

  /// No description provided for @addonsHostLanRemoveTorrentError.
  ///
  /// In en, this message translates to:
  /// **'Could not remove torrent'**
  String get addonsHostLanRemoveTorrentError;

  /// No description provided for @addonsHostLanRemoveTorrentToast.
  ///
  /// In en, this message translates to:
  /// **'Removed torrent cache entry'**
  String get addonsHostLanRemoveTorrentToast;

  /// No description provided for @addonsHostLanClearCacheError.
  ///
  /// In en, this message translates to:
  /// **'Could not clear torrent cache'**
  String get addonsHostLanClearCacheError;

  /// No description provided for @addonsHostLanClearCacheToast.
  ///
  /// In en, this message translates to:
  /// **'Torrent cache cleared'**
  String get addonsHostLanClearCacheToast;

  /// No description provided for @addonsHostLanServerStartFailedError.
  ///
  /// In en, this message translates to:
  /// **'Failed to start LAN server'**
  String get addonsHostLanServerStartFailedError;

  /// No description provided for @addonsHostLanServerStartFailedDetailError.
  ///
  /// In en, this message translates to:
  /// **'Failed to start LAN server: {detail}'**
  String addonsHostLanServerStartFailedDetailError(String detail);

  /// No description provided for @addonsHostLanNoDesktopFoundInfo.
  ///
  /// In en, this message translates to:
  /// **'No desktop found. Enter the IP and port from Settings → LAN on the desktop.'**
  String get addonsHostLanNoDesktopFoundInfo;

  /// No description provided for @addonsHostLanEnterPairDetailsInfo.
  ///
  /// In en, this message translates to:
  /// **'Enter desktop address, port, and 6-digit code'**
  String get addonsHostLanEnterPairDetailsInfo;

  /// No description provided for @addonsHostLanPairFailedError.
  ///
  /// In en, this message translates to:
  /// **'Pairing failed. Check the code, IP, and that desktop LAN is on.'**
  String get addonsHostLanPairFailedError;

  /// No description provided for @addonsHostLanPairedToast.
  ///
  /// In en, this message translates to:
  /// **'Paired. Enable Direct torrent in Settings → Playback.'**
  String get addonsHostLanPairedToast;

  /// No description provided for @addonsHostLanCodeCopiedToast.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get addonsHostLanCodeCopiedToast;

  /// No description provided for @addonsHostLanAddressCopiedToast.
  ///
  /// In en, this message translates to:
  /// **'Address copied'**
  String get addonsHostLanAddressCopiedToast;

  /// No description provided for @addonsHostLanPortOnlyLabel.
  ///
  /// In en, this message translates to:
  /// **'port {port}'**
  String addonsHostLanPortOnlyLabel(int port);

  /// No description provided for @addonsHostLanAddressMoreLabel.
  ///
  /// In en, this message translates to:
  /// **'{address} (+{more} more)'**
  String addonsHostLanAddressMoreLabel(String address, int more);

  /// No description provided for @addonsHostLanIntroDesktop.
  ///
  /// In en, this message translates to:
  /// **'Turn this PC into a Forja LAN server. Pair TVs and phones once. They pick torrents; this desktop downloads and streams.'**
  String get addonsHostLanIntroDesktop;

  /// No description provided for @addonsHostLanIntroClient.
  ///
  /// In en, this message translates to:
  /// **'Pair once with a desktop Forja on the same Wi‑Fi. After that, torrent sources on this device play through the desktop.'**
  String get addonsHostLanIntroClient;

  /// No description provided for @addonsHostLanEnableServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable LAN server'**
  String get addonsHostLanEnableServerTitle;

  /// No description provided for @addonsHostLanListeningSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Listening · {address}'**
  String addonsHostLanListeningSubtitle(String address);

  /// No description provided for @addonsHostLanServerOffSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Off. TVs cannot use this desktop for torrents'**
  String get addonsHostLanServerOffSubtitle;

  /// No description provided for @addonsHostLanDesktopAddressHeader.
  ///
  /// In en, this message translates to:
  /// **'DESKTOP ADDRESS'**
  String get addonsHostLanDesktopAddressHeader;

  /// No description provided for @addonsHostLanDesktopAddressHint.
  ///
  /// In en, this message translates to:
  /// **'On the TV: Settings → LAN → enter this IP and port if Discover does not find this PC.'**
  String get addonsHostLanDesktopAddressHint;

  /// No description provided for @addonsHostLanNoIpDetected.
  ///
  /// In en, this message translates to:
  /// **'Port {port}. Could not detect a LAN IP. Check Wi‑Fi or Ethernet.'**
  String addonsHostLanNoIpDetected(int port);

  /// No description provided for @addonsHostLanPairingCodeHeader.
  ///
  /// In en, this message translates to:
  /// **'PAIRING CODE'**
  String get addonsHostLanPairingCodeHeader;

  /// No description provided for @addonsHostLanPairingCodeHint.
  ///
  /// In en, this message translates to:
  /// **'On the TV: Settings → LAN → enter this code (valid ~5 minutes, one use).'**
  String get addonsHostLanPairingCodeHint;

  /// No description provided for @addonsHostLanCopyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get addonsHostLanCopyTooltip;

  /// No description provided for @addonsHostLanNewCodeTooltip.
  ///
  /// In en, this message translates to:
  /// **'New code'**
  String get addonsHostLanNewCodeTooltip;

  /// No description provided for @addonsHostLanPairedDevicesHeader.
  ///
  /// In en, this message translates to:
  /// **'PAIRED DEVICES'**
  String get addonsHostLanPairedDevicesHeader;

  /// No description provided for @addonsHostLanReloadDevicesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reload paired devices'**
  String get addonsHostLanReloadDevicesTooltip;

  /// No description provided for @addonsHostLanNoDevicesPaired.
  ///
  /// In en, this message translates to:
  /// **'No TVs or phones paired yet.'**
  String get addonsHostLanNoDevicesPaired;

  /// No description provided for @addonsHostLanRevokeHint.
  ///
  /// In en, this message translates to:
  /// **'Revoke to force that device to pair again.'**
  String get addonsHostLanRevokeHint;

  /// No description provided for @addonsHostLanWaitingForDevice.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a device to enter the code…'**
  String get addonsHostLanWaitingForDevice;

  /// No description provided for @addonsHostLanDeviceFallback.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get addonsHostLanDeviceFallback;

  /// No description provided for @addonsHostLanRevokeButton.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get addonsHostLanRevokeButton;

  /// No description provided for @addonsHostLanTorrentActivityHeader.
  ///
  /// In en, this message translates to:
  /// **'TORRENT ACTIVITY'**
  String get addonsHostLanTorrentActivityHeader;

  /// No description provided for @addonsHostLanClearAllButton.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get addonsHostLanClearAllButton;

  /// No description provided for @addonsHostLanTorrentActivityHint.
  ///
  /// In en, this message translates to:
  /// **'Torrents opened by paired TVs/phones. Delete removes the cached download.'**
  String get addonsHostLanTorrentActivityHint;

  /// No description provided for @addonsHostLanCacheOnDisk.
  ///
  /// In en, this message translates to:
  /// **'Cache on disk: {size}'**
  String addonsHostLanCacheOnDisk(String size);

  /// No description provided for @addonsHostLanActiveTorrentFallback.
  ///
  /// In en, this message translates to:
  /// **'Active torrent'**
  String get addonsHostLanActiveTorrentFallback;

  /// No description provided for @addonsHostLanNoTorrentsYet.
  ///
  /// In en, this message translates to:
  /// **'No LAN torrents yet. Play one from a paired TV.'**
  String get addonsHostLanNoTorrentsYet;

  /// No description provided for @addonsHostLanServingNow.
  ///
  /// In en, this message translates to:
  /// **'Serving now (not yet in history).'**
  String get addonsHostLanServingNow;

  /// No description provided for @addonsHostLanPeersChip.
  ///
  /// In en, this message translates to:
  /// **'{count} peers'**
  String addonsHostLanPeersChip(int count);

  /// No description provided for @addonsHostLanDeleteCachedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete cached download'**
  String get addonsHostLanDeleteCachedTooltip;

  /// No description provided for @addonsHostLanPairedStatus.
  ///
  /// In en, this message translates to:
  /// **'Paired'**
  String get addonsHostLanPairedStatus;

  /// No description provided for @addonsHostLanNotPairedStatus.
  ///
  /// In en, this message translates to:
  /// **'Not paired'**
  String get addonsHostLanNotPairedStatus;

  /// No description provided for @addonsHostLanDesktopOnline.
  ///
  /// In en, this message translates to:
  /// **'Desktop online'**
  String get addonsHostLanDesktopOnline;

  /// No description provided for @addonsHostLanDesktopOffline.
  ///
  /// In en, this message translates to:
  /// **'Desktop offline'**
  String get addonsHostLanDesktopOffline;

  /// No description provided for @addonsHostLanPlayingStatus.
  ///
  /// In en, this message translates to:
  /// **'playing'**
  String get addonsHostLanPlayingStatus;

  /// No description provided for @addonsHostLanPairedAddressNote.
  ///
  /// In en, this message translates to:
  /// **'{host}:{port}. Torrents play via desktop.'**
  String addonsHostLanPairedAddressNote(String host, String port);

  /// No description provided for @addonsHostLanPairOnceNote.
  ///
  /// In en, this message translates to:
  /// **'Pair once. Then open Sources → Torrents on a title.'**
  String get addonsHostLanPairOnceNote;

  /// No description provided for @addonsHostLanReloadStatusTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reload desktop status'**
  String get addonsHostLanReloadStatusTooltip;

  /// No description provided for @addonsHostLanFindDesktopHeader.
  ///
  /// In en, this message translates to:
  /// **'FIND DESKTOP'**
  String get addonsHostLanFindDesktopHeader;

  /// No description provided for @addonsHostLanSearchingButton.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get addonsHostLanSearchingButton;

  /// No description provided for @addonsHostLanDiscoverButton.
  ///
  /// In en, this message translates to:
  /// **'Discover on Wi‑Fi'**
  String get addonsHostLanDiscoverButton;

  /// No description provided for @addonsHostLanPortValue.
  ///
  /// In en, this message translates to:
  /// **'Port {port}'**
  String addonsHostLanPortValue(int port);

  /// No description provided for @addonsHostLanUseButton.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get addonsHostLanUseButton;

  /// No description provided for @addonsHostLanEnterManuallyHeader.
  ///
  /// In en, this message translates to:
  /// **'OR ENTER MANUALLY'**
  String get addonsHostLanEnterManuallyHeader;

  /// No description provided for @addonsHostLanDesktopIpLabel.
  ///
  /// In en, this message translates to:
  /// **'Desktop IP'**
  String get addonsHostLanDesktopIpLabel;

  /// No description provided for @addonsHostLanPortLabel.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get addonsHostLanPortLabel;

  /// No description provided for @addonsHostLanPortHint.
  ///
  /// In en, this message translates to:
  /// **'Shown under Enable LAN server on desktop'**
  String get addonsHostLanPortHint;

  /// No description provided for @addonsHostLanCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get addonsHostLanCodeLabel;

  /// No description provided for @addonsHostLanCodeHint.
  ///
  /// In en, this message translates to:
  /// **'From desktop Settings → LAN'**
  String get addonsHostLanCodeHint;

  /// No description provided for @addonsHostLanPairButton.
  ///
  /// In en, this message translates to:
  /// **'Pair with desktop'**
  String get addonsHostLanPairButton;

  /// No description provided for @addonsHostLanLocalTorrentTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow local torrent on this device'**
  String get addonsHostLanLocalTorrentTitle;

  /// No description provided for @addonsHostLanLocalTorrentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced. Use the on-device engine instead of the desktop. Leave off on TV.'**
  String get addonsHostLanLocalTorrentSubtitle;

  /// No description provided for @addonsHostProvStremioGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Stremio addons'**
  String get addonsHostProvStremioGroupLabel;

  /// No description provided for @addonsHostProvNuvioGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Nuvio addons'**
  String get addonsHostProvNuvioGroupLabel;

  /// No description provided for @addonsHostProvAddonInstalledToast.
  ///
  /// In en, this message translates to:
  /// **'Addon installed'**
  String get addonsHostProvAddonInstalledToast;

  /// No description provided for @addonsHostProvInstallFailedError.
  ///
  /// In en, this message translates to:
  /// **'Failed to install addon. Check URL.'**
  String get addonsHostProvInstallFailedError;

  /// No description provided for @addonsHostProvGenericError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String addonsHostProvGenericError(String error);

  /// No description provided for @addonsHostProvAddonRemovedToast.
  ///
  /// In en, this message translates to:
  /// **'Addon removed'**
  String get addonsHostProvAddonRemovedToast;

  /// No description provided for @addonsHostProvInstallStremioLabel.
  ///
  /// In en, this message translates to:
  /// **'Install Stremio Addon'**
  String get addonsHostProvInstallStremioLabel;

  /// No description provided for @addonsHostProvInstallButton.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get addonsHostProvInstallButton;

  /// No description provided for @addonsHostProvInstalledAddonsLabel.
  ///
  /// In en, this message translates to:
  /// **'Installed addons'**
  String get addonsHostProvInstalledAddonsLabel;

  /// No description provided for @addonsHostProvUntitledAddon.
  ///
  /// In en, this message translates to:
  /// **'Untitled addon'**
  String get addonsHostProvUntitledAddon;

  /// No description provided for @addonsHostProvSourcesChip.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get addonsHostProvSourcesChip;

  /// No description provided for @addonsHostProvInstallNuvioLabel.
  ///
  /// In en, this message translates to:
  /// **'Install Nuvio Addon'**
  String get addonsHostProvInstallNuvioLabel;

  /// No description provided for @addonsHostProvNuvioInstalledToast.
  ///
  /// In en, this message translates to:
  /// **'Installed {name} ({count} scrapers)'**
  String addonsHostProvNuvioInstalledToast(String name, int count);

  /// No description provided for @addonsHostProvInstallFailedDetailError.
  ///
  /// In en, this message translates to:
  /// **'Install failed: {error}'**
  String addonsHostProvInstallFailedDetailError(String error);

  /// No description provided for @addonsHostProvNuvioRemovedToast.
  ///
  /// In en, this message translates to:
  /// **'Nuvio addon removed'**
  String get addonsHostProvNuvioRemovedToast;

  /// No description provided for @addonsHostProvBaseUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get addonsHostProvBaseUrlLabel;

  /// No description provided for @addonsHostProvApiKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get addonsHostProvApiKeyLabel;

  /// No description provided for @addonsHostProvJackettApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Enter Jackett API Key'**
  String get addonsHostProvJackettApiKeyHint;

  /// No description provided for @addonsHostProvProwlarrApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Enter Prowlarr API Key'**
  String get addonsHostProvProwlarrApiKeyHint;

  /// No description provided for @addonsHostProvTestConnectionButton.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get addonsHostProvTestConnectionButton;

  /// No description provided for @addonsHostProvSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get addonsHostProvSaveButton;

  /// No description provided for @addonsHostProvFilterByTagLabel.
  ///
  /// In en, this message translates to:
  /// **'Filter by tag'**
  String get addonsHostProvFilterByTagLabel;

  /// No description provided for @addonsHostProvLoadTagsHint.
  ///
  /// In en, this message translates to:
  /// **'Use the Test Connection button to load available tags.'**
  String get addonsHostProvLoadTagsHint;

  /// No description provided for @addonsHostProvNoTagsFound.
  ///
  /// In en, this message translates to:
  /// **'No tags found in Prowlarr. Add tags to your indexers to use this filter.'**
  String get addonsHostProvNoTagsFound;

  /// No description provided for @addonsHostProvTagFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Limit searches to indexers with the selected tags. Leave all unselected to search all indexers.'**
  String get addonsHostProvTagFilterHint;

  /// No description provided for @addonsHostProvAllIndexersSearched.
  ///
  /// In en, this message translates to:
  /// **'All indexers will be searched.'**
  String get addonsHostProvAllIndexersSearched;

  /// No description provided for @addonsHostProvEnterUrlAndKeyResult.
  ///
  /// In en, this message translates to:
  /// **'❌ Please enter both Base URL and API Key'**
  String get addonsHostProvEnterUrlAndKeyResult;

  /// No description provided for @addonsHostProvTestErrorResult.
  ///
  /// In en, this message translates to:
  /// **'❌ Error: {error}'**
  String addonsHostProvTestErrorResult(String error);

  /// No description provided for @addonsHostProvJackettSavedToast.
  ///
  /// In en, this message translates to:
  /// **'Jackett settings saved'**
  String get addonsHostProvJackettSavedToast;

  /// No description provided for @addonsHostProvProwlarrSavedToast.
  ///
  /// In en, this message translates to:
  /// **'Prowlarr settings saved'**
  String get addonsHostProvProwlarrSavedToast;

  /// No description provided for @addonsHostProvScraperFallback.
  ///
  /// In en, this message translates to:
  /// **'Scraper'**
  String get addonsHostProvScraperFallback;

  /// No description provided for @addonsHostProvNuvioLeanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Expand to download scrapers · v{version}'**
  String addonsHostProvNuvioLeanSubtitle(String version);

  /// No description provided for @addonsHostProvNuvioScrapersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 scraper · v{version}} other{{count} scrapers · v{version}}}'**
  String addonsHostProvNuvioScrapersSubtitle(int count, String version);

  /// No description provided for @addonsHostProvNuvioLoadedToast.
  ///
  /// In en, this message translates to:
  /// **'Loaded {name} ({count} scrapers)'**
  String addonsHostProvNuvioLoadedToast(String name, int count);

  /// No description provided for @addonsHostProvDownloadingScrapers.
  ///
  /// In en, this message translates to:
  /// **'Downloading scrapers…'**
  String get addonsHostProvDownloadingScrapers;

  /// No description provided for @addonsHostProvLoadScrapersFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load scrapers'**
  String get addonsHostProvLoadScrapersFailed;

  /// No description provided for @addonsHostProvRetryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get addonsHostProvRetryButton;

  /// No description provided for @addonsHostProvRemoveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this addon?'**
  String get addonsHostProvRemoveConfirmTitle;

  /// No description provided for @addonsHostProvYesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get addonsHostProvYesTooltip;

  /// No description provided for @addonsHostProvNoTooltip.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get addonsHostProvNoTooltip;

  /// No description provided for @addonsHostProvRemoveAddonTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove addon'**
  String get addonsHostProvRemoveAddonTooltip;

  /// No description provided for @aboutUpdatesGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get aboutUpdatesGroupLabel;

  /// No description provided for @aboutPrivacyGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get aboutPrivacyGroupLabel;

  /// No description provided for @aboutDeveloperGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get aboutDeveloperGroupLabel;

  /// No description provided for @aboutVerifySentryTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify Sentry'**
  String get aboutVerifySentryTitle;

  /// No description provided for @aboutVerifySentrySubtitleActive.
  ///
  /// In en, this message translates to:
  /// **'Send a test exception to the Forja Flutter project'**
  String get aboutVerifySentrySubtitleActive;

  /// No description provided for @aboutVerifySentrySubtitleInactive.
  ///
  /// In en, this message translates to:
  /// **'Enable Crash reporting first, then tap again'**
  String get aboutVerifySentrySubtitleInactive;

  /// No description provided for @aboutVerifySentrySent.
  ///
  /// In en, this message translates to:
  /// **'Test event sent - check Sentry Issues'**
  String get aboutVerifySentrySent;

  /// No description provided for @aboutVerifyPostHogTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify PostHog'**
  String get aboutVerifyPostHogTitle;

  /// No description provided for @aboutVerifyPostHogSubtitleActive.
  ///
  /// In en, this message translates to:
  /// **'Send analytics_verify to your PostHog project'**
  String get aboutVerifyPostHogSubtitleActive;

  /// No description provided for @aboutVerifyPostHogSubtitleInactive.
  ///
  /// In en, this message translates to:
  /// **'Enable Product analytics first, then tap again'**
  String get aboutVerifyPostHogSubtitleInactive;

  /// No description provided for @aboutVerifyPostHogSent.
  ///
  /// In en, this message translates to:
  /// **'Test event sent - check PostHog → Activity'**
  String get aboutVerifyPostHogSent;

  /// No description provided for @aboutCheckForUpdatesBlurb.
  ///
  /// In en, this message translates to:
  /// **'Check for new versions of Forja'**
  String get aboutCheckForUpdatesBlurb;

  /// No description provided for @aboutCheckingButton.
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get aboutCheckingButton;

  /// No description provided for @aboutCheckForUpdatesButton.
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get aboutCheckForUpdatesButton;

  /// No description provided for @aboutCheckForUpdatesFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check for updates.'**
  String get aboutCheckForUpdatesFailed;

  /// No description provided for @aboutUpToDate.
  ///
  /// In en, this message translates to:
  /// **'You\'re on the latest version'**
  String get aboutUpToDate;

  /// No description provided for @aboutCheckForUpdatesError.
  ///
  /// In en, this message translates to:
  /// **'Failed to check for updates: {error}'**
  String aboutCheckForUpdatesError(String error);

  /// No description provided for @aboutCrashReportingTitle.
  ///
  /// In en, this message translates to:
  /// **'Crash reporting'**
  String get aboutCrashReportingTitle;

  /// Shared by the Crash reporting and Product analytics rows.
  ///
  /// In en, this message translates to:
  /// **'Inactive in debug builds. Your choice is saved for release.'**
  String get aboutTelemetryDebugSubtitle;

  /// Shared by the Crash reporting and Product analytics rows.
  ///
  /// In en, this message translates to:
  /// **'Not available in this build. Your choice is still saved.'**
  String get aboutTelemetryUnavailableSubtitle;

  /// No description provided for @aboutCrashReportingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sends crash details so we can fix bugs. No passwords or stream links.'**
  String get aboutCrashReportingSubtitle;

  /// No description provided for @aboutCrashReportingSavedDebug.
  ///
  /// In en, this message translates to:
  /// **'Saved. Crash reporting stays off in debug builds.'**
  String get aboutCrashReportingSavedDebug;

  /// No description provided for @aboutCrashReportingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Crash reporting is not available in this build yet.'**
  String get aboutCrashReportingUnavailable;

  /// No description provided for @aboutCrashReportingOn.
  ///
  /// In en, this message translates to:
  /// **'Crash reporting on'**
  String get aboutCrashReportingOn;

  /// No description provided for @aboutCrashReportingOff.
  ///
  /// In en, this message translates to:
  /// **'Crash reporting off'**
  String get aboutCrashReportingOff;

  /// No description provided for @aboutCrashReportingUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update crash reporting'**
  String get aboutCrashReportingUpdateFailed;

  /// No description provided for @aboutProductAnalyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Product analytics'**
  String get aboutProductAnalyticsTitle;

  /// No description provided for @aboutProductAnalyticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Shares how you use Forja so we can improve it.'**
  String get aboutProductAnalyticsSubtitle;

  /// No description provided for @aboutProductAnalyticsSavedDebug.
  ///
  /// In en, this message translates to:
  /// **'Saved. Product analytics stays off in debug builds.'**
  String get aboutProductAnalyticsSavedDebug;

  /// No description provided for @aboutProductAnalyticsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Product analytics is not available in this build yet.'**
  String get aboutProductAnalyticsUnavailable;

  /// No description provided for @aboutProductAnalyticsOn.
  ///
  /// In en, this message translates to:
  /// **'Product analytics on'**
  String get aboutProductAnalyticsOn;

  /// No description provided for @aboutProductAnalyticsOff.
  ///
  /// In en, this message translates to:
  /// **'Product analytics off'**
  String get aboutProductAnalyticsOff;

  /// No description provided for @aboutProductAnalyticsUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update product analytics'**
  String get aboutProductAnalyticsUpdateFailed;

  /// Keychain is the macOS Keychain (Trousseau d'accès in French macOS).
  ///
  /// In en, this message translates to:
  /// **'Store secrets in Keychain'**
  String get aboutKeychainRowTitle;

  /// No description provided for @aboutKeychainRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Off by default (local app file). Turn on to use the macOS Keychain. Forja explains first; the system may ask for your password once.'**
  String get aboutKeychainRowSubtitle;

  /// No description provided for @aboutKeychainEnabled.
  ///
  /// In en, this message translates to:
  /// **'Keychain enabled for secrets'**
  String get aboutKeychainEnabled;

  /// No description provided for @aboutKeychainLocalStorage.
  ///
  /// In en, this message translates to:
  /// **'Using local file storage'**
  String get aboutKeychainLocalStorage;

  /// No description provided for @aboutKeychainConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Use macOS Keychain?'**
  String get aboutKeychainConsentTitle;

  /// No description provided for @aboutKeychainConsentBodyStore.
  ///
  /// In en, this message translates to:
  /// **'Forja can store login tokens and API keys in the macOS Keychain instead of a local app file.'**
  String get aboutKeychainConsentBodyStore;

  /// No description provided for @aboutKeychainConsentBodyPrompt.
  ///
  /// In en, this message translates to:
  /// **'After you allow this, macOS may show its own password dialog once. It may mention \"flutter_secure_storage_service\". That name is Forja’s secure vault, not a separate app. Choose Always Allow if you trust Forja.'**
  String get aboutKeychainConsentBodyPrompt;

  /// No description provided for @aboutKeychainConsentBodyLocal.
  ///
  /// In en, this message translates to:
  /// **'You can keep using local file storage (default) with no Keychain prompts.'**
  String get aboutKeychainConsentBodyLocal;

  /// No description provided for @aboutKeychainConsentKeepLocal.
  ///
  /// In en, this message translates to:
  /// **'Keep local file'**
  String get aboutKeychainConsentKeepLocal;

  /// No description provided for @aboutKeychainConsentUseKeychain.
  ///
  /// In en, this message translates to:
  /// **'Use Keychain'**
  String get aboutKeychainConsentUseKeychain;

  /// No description provided for @addonsPlaybackTitle.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get addonsPlaybackTitle;

  /// No description provided for @addonsPlaybackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Quality, audio, auto-play'**
  String get addonsPlaybackSubtitle;

  /// No description provided for @addonsTorrentTitle.
  ///
  /// In en, this message translates to:
  /// **'Direct torrent'**
  String get addonsTorrentTitle;

  /// No description provided for @addonsTorrentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Jackett, Prowlarr, torrent engine'**
  String get addonsTorrentSubtitle;

  /// No description provided for @addonsStremioSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stremio addons'**
  String get addonsStremioSubtitle;

  /// No description provided for @addonsNuvioSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Nuvio scrapers'**
  String get addonsNuvioSubtitle;

  /// No description provided for @addonsConnectedServicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Connected services'**
  String get addonsConnectedServicesTitle;

  /// No description provided for @addonsConnectedServicesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Simkl; MDBlist (admin)'**
  String get addonsConnectedServicesSubtitle;

  /// No description provided for @addonsLanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Desktop server, pairing, torrent relay'**
  String get addonsLanSubtitle;

  /// No description provided for @addonsPackSettingsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Pack settings} other{{count} pack settings}}'**
  String addonsPackSettingsCount(int count);

  /// No description provided for @addonsBuiltInGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Built-in addons'**
  String get addonsBuiltInGroupLabel;

  /// No description provided for @addonsPackSettingsGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Pack settings'**
  String get addonsPackSettingsGroupLabel;

  /// No description provided for @addonsNoPackSettings.
  ///
  /// In en, this message translates to:
  /// **'No pack settings yet. Enable packs with Addon settings under Forja Packs.'**
  String get addonsNoPackSettings;

  /// No description provided for @addonsPackCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get addonsPackCancel;

  /// {action} is a pack-supplied action id (e.g. a verb), {title} the row title.
  ///
  /// In en, this message translates to:
  /// **'Could not {action} {title}'**
  String addonsPackActionFailed(String action, String title);

  /// No description provided for @addonsPackSelectAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get addonsPackSelectAll;

  /// No description provided for @addonsPackSelectNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get addonsPackSelectNone;

  /// No description provided for @addonsPackAutoOption.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get addonsPackAutoOption;

  /// No description provided for @addonsPackAuthBrowserOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open browser'**
  String get addonsPackAuthBrowserOpenFailed;

  /// No description provided for @addonsPackAuthBrowserTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Timed out waiting for Shahid session'**
  String get addonsPackAuthBrowserTimedOut;

  /// No description provided for @addonsPackAuthBrowserScriptCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied — on the Shahid tab open Console (⌘⌥J), paste, Enter'**
  String get addonsPackAuthBrowserScriptCopied;

  /// No description provided for @addonsPackAuthBrowserDefaultHint.
  ///
  /// In en, this message translates to:
  /// **'Sign in on Shahid in your browser (already signed in is fine).'**
  String get addonsPackAuthBrowserDefaultHint;

  /// No description provided for @addonsPackAuthBrowserStep1Open.
  ///
  /// In en, this message translates to:
  /// **'1. Shahid is open in your browser.'**
  String get addonsPackAuthBrowserStep1Open;

  /// No description provided for @addonsPackAuthBrowserStep1Opening.
  ///
  /// In en, this message translates to:
  /// **'1. Opening your browser…'**
  String get addonsPackAuthBrowserStep1Opening;

  /// No description provided for @addonsPackAuthBrowserStep2.
  ///
  /// In en, this message translates to:
  /// **'2. On that Shahid tab: open Console (⌘⌥J / Ctrl+Shift+J), paste, Enter.'**
  String get addonsPackAuthBrowserStep2;

  /// No description provided for @addonsPackAuthBrowserStep3Waiting.
  ///
  /// In en, this message translates to:
  /// **'3. Waiting for session… then Forja shows Connected (you can close the Shahid tab).'**
  String get addonsPackAuthBrowserStep3Waiting;

  /// No description provided for @addonsPackAuthBrowserStep3Stopped.
  ///
  /// In en, this message translates to:
  /// **'3. Waiting stopped — copy again or use password.'**
  String get addonsPackAuthBrowserStep3Stopped;

  /// No description provided for @addonsPackAuthBrowserCopyScript.
  ///
  /// In en, this message translates to:
  /// **'Copy connect script'**
  String get addonsPackAuthBrowserCopyScript;

  /// No description provided for @addonsPackAuthBrowserOpenAgain.
  ///
  /// In en, this message translates to:
  /// **'Open Shahid again'**
  String get addonsPackAuthBrowserOpenAgain;

  /// No description provided for @addonsPackAuthBrowserHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide email/password'**
  String get addonsPackAuthBrowserHidePassword;

  /// No description provided for @addonsPackAuthBrowserUsePassword.
  ///
  /// In en, this message translates to:
  /// **'Use email/password instead'**
  String get addonsPackAuthBrowserUsePassword;

  /// No description provided for @addonsPackAuthBrowserConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get addonsPackAuthBrowserConnect;

  /// No description provided for @addonsPackAuthPinUnavailable.
  ///
  /// In en, this message translates to:
  /// **'PIN login for {label} is not available in this build'**
  String addonsPackAuthPinUnavailable(String label);

  /// No description provided for @addonsPackAuthNoMethods.
  ///
  /// In en, this message translates to:
  /// **'No login methods from {label}'**
  String addonsPackAuthNoMethods(String label);

  /// No description provided for @addonsPackAuthConnectedTo.
  ///
  /// In en, this message translates to:
  /// **'Connected to {label}'**
  String addonsPackAuthConnectedTo(String label);

  /// No description provided for @addonsPackAuthNoUrl.
  ///
  /// In en, this message translates to:
  /// **'No login URL from {label}'**
  String addonsPackAuthNoUrl(String label);

  /// No description provided for @addonsPackAuthSignInTo.
  ///
  /// In en, this message translates to:
  /// **'Sign in to {label}'**
  String addonsPackAuthSignInTo(String label);

  /// No description provided for @addonsPackAuthSignedOutOf.
  ///
  /// In en, this message translates to:
  /// **'Signed out of {label}'**
  String addonsPackAuthSignedOutOf(String label);

  /// No description provided for @addonsPackAuthConnectedAs.
  ///
  /// In en, this message translates to:
  /// **'Connected as {who}'**
  String addonsPackAuthConnectedAs(String who);

  /// No description provided for @addonsPackAuthConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get addonsPackAuthConnected;

  /// No description provided for @addonsPackAuthLogoutFrom.
  ///
  /// In en, this message translates to:
  /// **'Logout from {label}'**
  String addonsPackAuthLogoutFrom(String label);

  /// No description provided for @addonsPackAuthLoginWith.
  ///
  /// In en, this message translates to:
  /// **'Login with {label}'**
  String addonsPackAuthLoginWith(String label);

  /// No description provided for @addonsPackAuthLoginDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Login · {title}'**
  String addonsPackAuthLoginDialogTitle(String title);

  /// No description provided for @addonsPackAuthLoginButton.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get addonsPackAuthLoginButton;

  /// No description provided for @addonsPackGreenPlayIntro.
  ///
  /// In en, this message translates to:
  /// **'Preferred Forja providers for the green Play button. They are tried first; empty list races all enabled Forja providers.'**
  String get addonsPackGreenPlayIntro;

  /// No description provided for @addonsPackGreenPlayEmpty.
  ///
  /// In en, this message translates to:
  /// **'No preferred providers — green Play races every enabled Forja plugin.'**
  String get addonsPackGreenPlayEmpty;

  /// No description provided for @addonsPackGreenPlayRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get addonsPackGreenPlayRemove;

  /// No description provided for @addonsPackGreenPlayAddPreferred.
  ///
  /// In en, this message translates to:
  /// **'Add preferred'**
  String get addonsPackGreenPlayAddPreferred;

  /// No description provided for @addonsPackGreenPlayAddDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add preferred provider'**
  String get addonsPackGreenPlayAddDialogTitle;

  /// No description provided for @addonsPackGreenPlaySearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get addonsPackGreenPlaySearchLabel;

  /// No description provided for @addonsPackGreenPlaySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Provider name'**
  String get addonsPackGreenPlaySearchHint;

  /// No description provided for @addonsPackGreenPlayNoProviders.
  ///
  /// In en, this message translates to:
  /// **'No Forja providers enabled'**
  String get addonsPackGreenPlayNoProviders;

  /// No description provided for @addonsPackGreenPlayNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get addonsPackGreenPlayNoMatches;

  /// No description provided for @dataStreamSubtitleTorrent.
  ///
  /// In en, this message translates to:
  /// **'Saved stream provider URLs, torrent temp files, and seek buffers. Next play re-resolves. Settings and watch history stay.'**
  String get dataStreamSubtitleTorrent;

  /// No description provided for @dataStreamSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Saved stream provider URLs and seek buffers. Next play re-resolves. Settings and watch history stay.'**
  String get dataStreamSubtitle;

  /// No description provided for @dataStreamBodyTorrent.
  ///
  /// In en, this message translates to:
  /// **'Clears saved stream extracts, torrent download cache, and temporary seek buffers for the current profile (or Guest).\n\nWatch history, provider scores, and settings are not affected. Torrent temp files are shared on this device.'**
  String get dataStreamBodyTorrent;

  /// No description provided for @dataStreamBody.
  ///
  /// In en, this message translates to:
  /// **'Clears saved stream extracts and temporary seek buffers for the current profile (or Guest).\n\nWatch history, provider scores, and settings are not affected.'**
  String get dataStreamBody;

  /// No description provided for @dataGroupSafeToClear.
  ///
  /// In en, this message translates to:
  /// **'Safe to clear'**
  String get dataGroupSafeToClear;

  /// No description provided for @dataStreamCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Stream cache'**
  String get dataStreamCacheTitle;

  /// No description provided for @dataStreamClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear stream cache?'**
  String get dataStreamClearTitle;

  /// No description provided for @dataClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get dataClear;

  /// No description provided for @dataStreamCleared.
  ///
  /// In en, this message translates to:
  /// **'Stream cache cleared'**
  String get dataStreamCleared;

  /// No description provided for @dataImagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Images & WebView'**
  String get dataImagesTitle;

  /// No description provided for @dataImagesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Poster thumbnails and extractor WebView caches. Frees disk; images download again when needed.'**
  String get dataImagesSubtitle;

  /// No description provided for @dataImagesClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear images & WebView?'**
  String get dataImagesClearTitle;

  /// No description provided for @dataImagesClearBody.
  ///
  /// In en, this message translates to:
  /// **'Clears cached posters and WebView extract data on this device. Your lists and watch history are not affected.'**
  String get dataImagesClearBody;

  /// No description provided for @dataImagesCleared.
  ///
  /// In en, this message translates to:
  /// **'Images & WebView cache cleared'**
  String get dataImagesCleared;

  /// No description provided for @dataPortalTitle.
  ///
  /// In en, this message translates to:
  /// **'IPTV portal cache'**
  String get dataPortalTitle;

  /// No description provided for @dataPortalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Catalogs, alive checks, and channel scans. Portals and favorites stay. Re-fetches on next open.'**
  String get dataPortalSubtitle;

  /// No description provided for @dataPortalClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear IPTV portal cache?'**
  String get dataPortalClearTitle;

  /// No description provided for @dataPortalClearBody.
  ///
  /// In en, this message translates to:
  /// **'Clears saved catalogs, alive-channel checks, and channel scan hits for IPTV portals on the current profile (or Guest).\n\nSaved portals, favorites, and M3U playlists are not affected.'**
  String get dataPortalClearBody;

  /// No description provided for @dataPortalCleared.
  ///
  /// In en, this message translates to:
  /// **'IPTV portal cache cleared'**
  String get dataPortalCleared;

  /// No description provided for @dataUpdatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Downloaded updates'**
  String get dataUpdatesTitle;

  /// No description provided for @dataUpdatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Installer files from in-app update (.dmg, .exe, AppImage). Safe to remove after you install.'**
  String get dataUpdatesSubtitle;

  /// No description provided for @dataUpdatesClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear downloaded updates?'**
  String get dataUpdatesClearTitle;

  /// No description provided for @dataUpdatesClearBody.
  ///
  /// In en, this message translates to:
  /// **'Removes update installers Forja saved in Downloads, app storage, or temp while downloading.\n\nYour installed app version and settings are not affected.'**
  String get dataUpdatesClearBody;

  /// No description provided for @dataUpdatesCleared.
  ///
  /// In en, this message translates to:
  /// **'Downloaded update files cleared'**
  String get dataUpdatesCleared;

  /// No description provided for @dataGroupLearned.
  ///
  /// In en, this message translates to:
  /// **'Learned'**
  String get dataGroupLearned;

  /// No description provided for @dataScoresTitle.
  ///
  /// In en, this message translates to:
  /// **'Provider scores'**
  String get dataScoresTitle;

  /// No description provided for @dataScoresSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reliability totals for Settings Score and Auto order. Drag order is kept; scores start over.'**
  String get dataScoresSubtitle;

  /// No description provided for @dataScoresResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset provider scores?'**
  String get dataScoresResetTitle;

  /// No description provided for @dataScoresResetBody.
  ///
  /// In en, this message translates to:
  /// **'Clears learned reliability for all providers on the current profile (or Guest). Settings Score goes back to 0 and Auto re-learns from new checks.\n\nYour preferred drag order is not changed.'**
  String get dataScoresResetBody;

  /// No description provided for @dataScoresResetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Reset scores'**
  String get dataScoresResetConfirm;

  /// No description provided for @dataScoresReset.
  ///
  /// In en, this message translates to:
  /// **'Provider scores reset'**
  String get dataScoresReset;

  /// No description provided for @dataGroupWatchData.
  ///
  /// In en, this message translates to:
  /// **'Watch data'**
  String get dataGroupWatchData;

  /// No description provided for @dataContinueTitle.
  ///
  /// In en, this message translates to:
  /// **'Continue watching'**
  String get dataContinueTitle;

  /// No description provided for @dataContinueSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Resume rows on Home, Anime, and Asian Drama. Cannot be undone for this profile.'**
  String get dataContinueSubtitle;

  /// No description provided for @dataContinueClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear continue watching?'**
  String get dataContinueClearTitle;

  /// No description provided for @dataContinueClearBody.
  ///
  /// In en, this message translates to:
  /// **'Removes resume / continue-watching entries for movies, TV, anime, Asian drama, and anime Arabic on the current profile (or Guest).\n\nOther profiles are not affected. Trakt or Simkl cloud history is not deleted. My List and liked items are kept.'**
  String get dataContinueClearBody;

  /// No description provided for @dataContinueClearConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get dataContinueClearConfirm;

  /// No description provided for @dataContinueCleared.
  ///
  /// In en, this message translates to:
  /// **'Continue watching cleared'**
  String get dataContinueCleared;

  /// No description provided for @dataWatchedTitle.
  ///
  /// In en, this message translates to:
  /// **'Watched episode marks'**
  String get dataWatchedTitle;

  /// No description provided for @dataWatchedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Local watched checkmarks on TV episode lists. Trakt / Simkl online history stays.'**
  String get dataWatchedSubtitle;

  /// No description provided for @dataWatchedClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear watched marks?'**
  String get dataWatchedClearTitle;

  /// No description provided for @dataWatchedClearBody.
  ///
  /// In en, this message translates to:
  /// **'Removes local episode watched checkmarks on the current profile (or Guest). Continue watching progress is kept unless you clear it separately.\n\nTrakt / Simkl may show episodes as watched again after sync.'**
  String get dataWatchedClearBody;

  /// No description provided for @dataWatchedClearConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear marks'**
  String get dataWatchedClearConfirm;

  /// No description provided for @dataWatchedCleared.
  ///
  /// In en, this message translates to:
  /// **'Watched marks cleared'**
  String get dataWatchedCleared;

  /// No description provided for @dataFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String dataFailed(String error);

  /// No description provided for @dataExportDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Export Settings'**
  String get dataExportDialogTitle;

  /// No description provided for @dataExported.
  ///
  /// In en, this message translates to:
  /// **'Settings exported'**
  String get dataExported;

  /// No description provided for @dataExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String dataExportFailed(String error);

  /// No description provided for @dataImportDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Settings'**
  String get dataImportDialogTitle;

  /// No description provided for @dataReadFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read file.'**
  String get dataReadFileFailed;

  /// No description provided for @dataImportConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This overwrites your current settings, including addons, API keys, and preferences. Continue?'**
  String get dataImportConfirmBody;

  /// No description provided for @dataImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get dataImport;

  /// No description provided for @dataImported.
  ///
  /// In en, this message translates to:
  /// **'Settings imported'**
  String get dataImported;

  /// No description provided for @dataImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String dataImportFailed(String error);

  /// No description provided for @dataBackupLabel.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get dataBackupLabel;

  /// No description provided for @dataBackupHint.
  ///
  /// In en, this message translates to:
  /// **'Export or import all your settings, addons, API keys, and preferences as a JSON file.'**
  String get dataBackupHint;

  /// No description provided for @dataExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get dataExport;

  /// No description provided for @packsUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 update available} other{{count} updates available}}'**
  String packsUpdateAvailable(int count);

  /// No description provided for @packsUpdateUpToDate.
  ///
  /// In en, this message translates to:
  /// **'All plugins are up to date'**
  String get packsUpdateUpToDate;

  /// No description provided for @packsUpdateMenuBadge.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get packsUpdateMenuBadge;

  /// No description provided for @packsUpdateChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking for plugin updates…'**
  String get packsUpdateChecking;

  /// No description provided for @packsUpdateUpdating.
  ///
  /// In en, this message translates to:
  /// **'Updating…'**
  String get packsUpdateUpdating;

  /// No description provided for @packsUpdateAll.
  ///
  /// In en, this message translates to:
  /// **'Update all'**
  String get packsUpdateAll;

  /// No description provided for @packsUpdateCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get packsUpdateCheckAgain;

  /// No description provided for @packsPackDeprecatedTag.
  ///
  /// In en, this message translates to:
  /// **'deprecated'**
  String get packsPackDeprecatedTag;

  /// No description provided for @packsPackUnavailableHereTag.
  ///
  /// In en, this message translates to:
  /// **'not on this device'**
  String get packsPackUnavailableHereTag;

  /// No description provided for @packsPluginsMiniLabel.
  ///
  /// In en, this message translates to:
  /// **'Forja plugins'**
  String get packsPluginsMiniLabel;

  /// No description provided for @packsPackMeta.
  ///
  /// In en, this message translates to:
  /// **'{kind} · {count, plural, =1{1 plugin} other{{count} plugins}} · v{version}'**
  String packsPackMeta(String kind, int count, String version);

  /// No description provided for @packsPluginUnavailableHere.
  ///
  /// In en, this message translates to:
  /// **'Not available on this device'**
  String get packsPluginUnavailableHere;

  /// No description provided for @packsLiveTabCatalog.
  ///
  /// In en, this message translates to:
  /// **'Catalog'**
  String get packsLiveTabCatalog;

  /// No description provided for @packsLiveTabProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get packsLiveTabProvider;

  /// No description provided for @packsLiveCatalogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule feed for Live Sports'**
  String get packsLiveCatalogSubtitle;

  /// No description provided for @packsLiveProviderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stream resolve for Forja Live'**
  String get packsLiveProviderSubtitle;

  /// No description provided for @featuresDefaultMenu.
  ///
  /// In en, this message translates to:
  /// **'Default menu'**
  String get featuresDefaultMenu;

  /// No description provided for @featuresSetDefaultMenu.
  ///
  /// In en, this message translates to:
  /// **'Set as default menu'**
  String get featuresSetDefaultMenu;

  /// No description provided for @featuresHintLeanback.
  ///
  /// In en, this message translates to:
  /// **'OK toggles a tab. Star sets the default menu. ↑/↓ on arrows reorder. ↓ stays in the same column.'**
  String get featuresHintLeanback;

  /// No description provided for @featuresHint.
  ///
  /// In en, this message translates to:
  /// **'Show, hide, and reorder tabs. Drag to reorder. Settings stays visible.'**
  String get featuresHint;

  /// No description provided for @featuresAlwaysVisible.
  ///
  /// In en, this message translates to:
  /// **'Always visible'**
  String get featuresAlwaysVisible;

  /// No description provided for @packsChoiceOfficialTitle.
  ///
  /// In en, this message translates to:
  /// **'Official packs'**
  String get packsChoiceOfficialTitle;

  /// No description provided for @packsChoiceOfficialSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose which ForjaHQ packs to install'**
  String get packsChoiceOfficialSubtitle;

  /// No description provided for @packsChoiceCommunityTitle.
  ///
  /// In en, this message translates to:
  /// **'Community Packs'**
  String get packsChoiceCommunityTitle;

  /// No description provided for @packsChoiceCommunitySubtitleCompact.
  ///
  /// In en, this message translates to:
  /// **'Browse packs on the web'**
  String get packsChoiceCommunitySubtitleCompact;

  /// No description provided for @packsChoiceCommunitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse and pick packs on the web'**
  String get packsChoiceCommunitySubtitle;

  /// No description provided for @packsPromptTitleSync.
  ///
  /// In en, this message translates to:
  /// **'Sync packs'**
  String get packsPromptTitleSync;

  /// No description provided for @packsPromptTitleUninstall.
  ///
  /// In en, this message translates to:
  /// **'Uninstall packs'**
  String get packsPromptTitleUninstall;

  /// No description provided for @packsPromptTitleInstall.
  ///
  /// In en, this message translates to:
  /// **'Install packs'**
  String get packsPromptTitleInstall;

  /// No description provided for @packsPromptInstalledCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 pack installed} other{{count} packs installed}}'**
  String packsPromptInstalledCount(int count);

  /// No description provided for @packsPromptRemovedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 pack removed} other{{count} packs removed}}'**
  String packsPromptRemovedCount(int count);

  /// No description provided for @packsPromptFailedToast.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Pack install failed — see details above} other{{count} packs failed — see details above}}'**
  String packsPromptFailedToast(int count);

  /// No description provided for @packsPromptBodyRemote.
  ///
  /// In en, this message translates to:
  /// **'These packs changed on your profile from another device. Choose what to apply here. The rest can wait in Forja Packs.'**
  String get packsPromptBodyRemote;

  /// No description provided for @packsPromptBodyLocal.
  ///
  /// In en, this message translates to:
  /// **'Choose which packs to download on this device. You can install the rest later from this page.'**
  String get packsPromptBodyLocal;

  /// No description provided for @packsPromptWorking.
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get packsPromptWorking;

  /// No description provided for @packsPromptApply.
  ///
  /// In en, this message translates to:
  /// **'Apply ({install} install · {uninstall} uninstall)'**
  String packsPromptApply(int install, int uninstall);

  /// No description provided for @packsPromptUninstallCount.
  ///
  /// In en, this message translates to:
  /// **'Uninstall {count, plural, =1{1 pack} other{{count} packs}}'**
  String packsPromptUninstallCount(int count);

  /// No description provided for @packsPromptInstallCount.
  ///
  /// In en, this message translates to:
  /// **'Install {count, plural, =1{1 pack} other{{count} packs}}'**
  String packsPromptInstallCount(int count);

  /// No description provided for @packsPromptSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get packsPromptSelectAll;

  /// No description provided for @packsPromptClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get packsPromptClear;

  /// No description provided for @packsPromptSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String packsPromptSelected(int count);

  /// No description provided for @packsPromptLocalFolder.
  ///
  /// In en, this message translates to:
  /// **'Local folder'**
  String get packsPromptLocalFolder;

  /// No description provided for @packsPromptCommunitySource.
  ///
  /// In en, this message translates to:
  /// **'{host} · Community source'**
  String packsPromptCommunitySource(String host);

  /// No description provided for @packsPromptDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Plugin pack'**
  String get packsPromptDefaultTitle;

  /// No description provided for @packsPromptActionUninstall.
  ///
  /// In en, this message translates to:
  /// **'Uninstall'**
  String get packsPromptActionUninstall;

  /// No description provided for @packsPromptActionInstall.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get packsPromptActionInstall;

  /// No description provided for @packsPromptAlreadyRemoved.
  ///
  /// In en, this message translates to:
  /// **'Already removed'**
  String get packsPromptAlreadyRemoved;

  /// No description provided for @packsPromptAlreadyOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Already on device'**
  String get packsPromptAlreadyOnDevice;

  /// No description provided for @packsPromptNotOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Not on this device'**
  String get packsPromptNotOnDevice;

  /// No description provided for @packsPromptCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get packsPromptCommunity;

  /// No description provided for @packsPromptRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get packsPromptRecommended;

  /// No description provided for @packsGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Forja packs'**
  String get packsGroupLabel;

  /// No description provided for @packsEmptyNone.
  ///
  /// In en, this message translates to:
  /// **'No packs installed. Paste a manifest URL below, or sign in to sync from your profile.'**
  String get packsEmptyNone;

  /// No description provided for @packsInstallFailed.
  ///
  /// In en, this message translates to:
  /// **'Pack install failed: {error}'**
  String packsInstallFailed(String error);

  /// No description provided for @packsRetryInstall.
  ///
  /// In en, this message translates to:
  /// **'Retry install'**
  String get packsRetryInstall;

  /// No description provided for @packsManifestHint.
  ///
  /// In en, this message translates to:
  /// **'Each pack is a manifest.json URL. Forja downloads the manifest, then every plugin script, before the pack is fully usable.'**
  String get packsManifestHint;

  /// No description provided for @packsAddPackLabel.
  ///
  /// In en, this message translates to:
  /// **'Add pack'**
  String get packsAddPackLabel;

  /// No description provided for @packsAddPackHint.
  ///
  /// In en, this message translates to:
  /// **'Paste one or more manifest URLs / local paths'**
  String get packsAddPackHint;

  /// No description provided for @packsDownloadAll.
  ///
  /// In en, this message translates to:
  /// **'Download all'**
  String get packsDownloadAll;

  /// No description provided for @packsReloadingTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reloading packs…'**
  String get packsReloadingTooltip;

  /// No description provided for @packsReload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get packsReload;

  /// No description provided for @packsInstall.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get packsInstall;

  /// No description provided for @packsPendingDownloads.
  ///
  /// In en, this message translates to:
  /// **'Pending downloads'**
  String get packsPendingDownloads;

  /// No description provided for @packsInstalledPacks.
  ///
  /// In en, this message translates to:
  /// **'Installed packs'**
  String get packsInstalledPacks;

  /// No description provided for @packsBadgeRemovedFromProfile.
  ///
  /// In en, this message translates to:
  /// **'Removed from profile'**
  String get packsBadgeRemovedFromProfile;

  /// No description provided for @packsActionUninstallNow.
  ///
  /// In en, this message translates to:
  /// **'Uninstall now'**
  String get packsActionUninstallNow;

  /// No description provided for @packsBadgeInstallLater.
  ///
  /// In en, this message translates to:
  /// **'Install later'**
  String get packsBadgeInstallLater;

  /// No description provided for @packsBadgeInstallFailed.
  ///
  /// In en, this message translates to:
  /// **'Install failed'**
  String get packsBadgeInstallFailed;

  /// No description provided for @packsBadgeDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get packsBadgeDownloading;

  /// No description provided for @packsBadgePendingDownload.
  ///
  /// In en, this message translates to:
  /// **'Pending download'**
  String get packsBadgePendingDownload;

  /// No description provided for @packsRetryDownload.
  ///
  /// In en, this message translates to:
  /// **'Retry download'**
  String get packsRetryDownload;

  /// No description provided for @packsToastRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Packs refreshed'**
  String get packsToastRefreshed;

  /// No description provided for @packsToastRecommendedInstalled.
  ///
  /// In en, this message translates to:
  /// **'Recommended packs already installed'**
  String get packsToastRecommendedInstalled;

  /// No description provided for @packsToastFinishPrompt.
  ///
  /// In en, this message translates to:
  /// **'Finish the current pack prompt first'**
  String get packsToastFinishPrompt;

  /// No description provided for @packsToastOfficialInstallFailed.
  ///
  /// In en, this message translates to:
  /// **'Official pack install failed: {error}'**
  String packsToastOfficialInstallFailed(String error);

  /// No description provided for @packsToastUpdatedTo.
  ///
  /// In en, this message translates to:
  /// **'Updated {name} to v{version}'**
  String packsToastUpdatedTo(String name, String version);

  /// No description provided for @packsToastRefreshedPack.
  ///
  /// In en, this message translates to:
  /// **'Refreshed {name} v{version}'**
  String packsToastRefreshedPack(String name, String version);

  /// No description provided for @packsToastRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Refresh failed: {error}'**
  String packsToastRefreshFailed(String error);

  /// No description provided for @packsToastReloadFailed.
  ///
  /// In en, this message translates to:
  /// **'{name} reload failed: {error}'**
  String packsToastReloadFailed(String name, String error);

  /// No description provided for @packsToastReloaded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 pack reloaded} other{{count} packs reloaded}}'**
  String packsToastReloaded(int count);

  /// No description provided for @packsToastDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'{name} download failed: {error}'**
  String packsToastDownloadFailed(String name, String error);

  /// No description provided for @packsToastDownloaded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 pack downloaded} other{{count} packs downloaded}}'**
  String packsToastDownloaded(int count);

  /// No description provided for @packsToastUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'{name} update failed: {error}'**
  String packsToastUpdateFailed(String name, String error);

  /// No description provided for @packsToastUpdated.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 pack updated} other{{count} packs updated}}'**
  String packsToastUpdated(int count);

  /// No description provided for @packsToastInstallFailedDetails.
  ///
  /// In en, this message translates to:
  /// **'Install failed — see details above'**
  String get packsToastInstallFailedDetails;

  /// No description provided for @packsToastInstalled.
  ///
  /// In en, this message translates to:
  /// **'Installed {name} ({count} plugins)'**
  String packsToastInstalled(String name, int count);

  /// No description provided for @packsToastPackUninstalled.
  ///
  /// In en, this message translates to:
  /// **'Pack uninstalled'**
  String get packsToastPackUninstalled;

  /// No description provided for @packsToastPackRemoved.
  ///
  /// In en, this message translates to:
  /// **'Pack removed'**
  String get packsToastPackRemoved;

  /// No description provided for @packsOfficialBadge.
  ///
  /// In en, this message translates to:
  /// **'Official'**
  String get packsOfficialBadge;

  /// No description provided for @packsActionUpdateTo.
  ///
  /// In en, this message translates to:
  /// **'Update to v{version}'**
  String packsActionUpdateTo(String version);

  /// No description provided for @packsActionRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get packsActionRefresh;

  /// No description provided for @packsFailuresTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Pack install failed} other{{count} packs failed to install}}'**
  String packsFailuresTitle(int count);

  /// No description provided for @packsDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get packsDismiss;

  /// No description provided for @packsPendingReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get packsPendingReady;

  /// No description provided for @packsPendingWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get packsPendingWaiting;

  /// No description provided for @packsPendingDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get packsPendingDownload;

  /// No description provided for @packsPendingYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get packsPendingYes;

  /// No description provided for @packsPendingNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get packsPendingNo;

  /// No description provided for @packsPendingRemovePack.
  ///
  /// In en, this message translates to:
  /// **'Remove pack'**
  String get packsPendingRemovePack;

  /// No description provided for @packsInstallUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update available: v{version}'**
  String packsInstallUpdateAvailable(String version);

  /// No description provided for @packsInstallBannerUpdating.
  ///
  /// In en, this message translates to:
  /// **'Updating plugins…'**
  String get packsInstallBannerUpdating;

  /// No description provided for @packsInstallBannerDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading plugins…'**
  String get packsInstallBannerDownloading;

  /// No description provided for @profileLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load profile. Check your connection and retry.'**
  String get profileLoadFailed;

  /// No description provided for @profileToastProfileReady.
  ///
  /// In en, this message translates to:
  /// **'Profile ready'**
  String get profileToastProfileReady;

  /// No description provided for @profileToastAccountReady.
  ///
  /// In en, this message translates to:
  /// **'Account ready'**
  String get profileToastAccountReady;

  /// No description provided for @profileSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Check email/password or Supabase config.'**
  String get profileSignInFailed;

  /// No description provided for @profileWebLoginIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Web login did not complete.'**
  String get profileWebLoginIncomplete;

  /// No description provided for @profileWebLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not finish web login. Check that the portal is reachable.'**
  String get profileWebLoginFailed;

  /// No description provided for @profileSignupOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the signup page.'**
  String get profileSignupOpenFailed;

  /// No description provided for @profileCloudNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Cloud account is not configured in this build. Pass SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY via --dart-define.'**
  String get profileCloudNotConfigured;

  /// No description provided for @profileAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get profileAccountLabel;

  /// No description provided for @profileSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get profileSignedIn;

  /// No description provided for @profileCloudProfileLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading cloud profile…'**
  String get profileCloudProfileLoading;

  /// No description provided for @profileCloudProfileLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Cloud profile could not load. Retry, or sign out to clear this session on the device.'**
  String get profileCloudProfileLoadFailed;

  /// No description provided for @profileRetryTitle.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get profileRetryTitle;

  /// No description provided for @profileRetrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reload profiles from the cloud'**
  String get profileRetrySubtitle;

  /// No description provided for @profileSignOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get profileSignOutTitle;

  /// No description provided for @profileSignOutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clear the session on this device even if the network is down'**
  String get profileSignOutSubtitle;

  /// No description provided for @profileSyncNoneYet.
  ///
  /// In en, this message translates to:
  /// **'No cloud settings synced yet - changes will upload as you use Forja'**
  String get profileSyncNoneYet;

  /// No description provided for @profileSyncSections.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 setting section synced to this profile} other{{count} setting sections synced to this profile}}'**
  String profileSyncSections(int count);

  /// No description provided for @profileCloudSyncLabel.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync'**
  String get profileCloudSyncLabel;

  /// No description provided for @profileSignedInWaitingSync.
  ///
  /// In en, this message translates to:
  /// **'Signed in · waiting for sync'**
  String get profileSignedInWaitingSync;

  /// No description provided for @profileSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get profileSynced;

  /// No description provided for @profileAccountActiveHint.
  ///
  /// In en, this message translates to:
  /// **'Active Forja cloud account'**
  String get profileAccountActiveHint;

  /// No description provided for @profileAccountSwitchHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to switch or add accounts'**
  String get profileAccountSwitchHint;

  /// Badge on the active profile card. Shown in capitals by the app, so translate it as a short phrase.
  ///
  /// In en, this message translates to:
  /// **'Watching now'**
  String get profileWatchingNow;

  /// No description provided for @profileActiveHint.
  ///
  /// In en, this message translates to:
  /// **'Active profile on this device'**
  String get profileActiveHint;

  /// No description provided for @profileSwitchHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to switch who’s watching'**
  String get profileSwitchHint;

  /// No description provided for @profileSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get profileSignIn;

  /// No description provided for @profileNewHere.
  ///
  /// In en, this message translates to:
  /// **'New here?'**
  String get profileNewHere;

  /// No description provided for @profileCreateAccountWeb.
  ///
  /// In en, this message translates to:
  /// **'Create an account on the web'**
  String get profileCreateAccountWeb;

  /// No description provided for @profileOpensPortal.
  ///
  /// In en, this message translates to:
  /// **'Opens the Forja portal in your browser'**
  String get profileOpensPortal;

  /// No description provided for @profileLinkIntroTv.
  ///
  /// In en, this message translates to:
  /// **'Link your Forja account with a code or QR on the portal. You can keep using Forja without an account.'**
  String get profileLinkIntroTv;

  /// No description provided for @profileLinkWithCodeOrQr.
  ///
  /// In en, this message translates to:
  /// **'Link with code or QR'**
  String get profileLinkWithCodeOrQr;

  /// No description provided for @profileCreateAccountTvHint.
  ///
  /// In en, this message translates to:
  /// **'Use a phone or computer - then link this TV'**
  String get profileCreateAccountTvHint;

  /// No description provided for @profileSignInIntro.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync profiles and settings across devices. You can keep using Forja without an account.'**
  String get profileSignInIntro;

  /// No description provided for @profileSignInQuick.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your phone or computer in under a minute.'**
  String get profileSignInQuick;

  /// No description provided for @profileEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get profileEmailLabel;

  /// No description provided for @profilePasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get profilePasswordLabel;

  /// No description provided for @profileSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get profileSigningIn;

  /// No description provided for @profileCancelWebLogin.
  ///
  /// In en, this message translates to:
  /// **'Cancel web login'**
  String get profileCancelWebLogin;

  /// No description provided for @profileWebLogin.
  ///
  /// In en, this message translates to:
  /// **'Web login'**
  String get profileWebLogin;

  /// No description provided for @downloadsChooseFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose download folder'**
  String get downloadsChooseFolder;

  /// No description provided for @downloadsFolderNotWritable.
  ///
  /// In en, this message translates to:
  /// **'Can’t write to that folder'**
  String get downloadsFolderNotWritable;

  /// No description provided for @downloadsFolderChanged.
  ///
  /// In en, this message translates to:
  /// **'New downloads will save here'**
  String get downloadsFolderChanged;

  /// No description provided for @downloadsFolderReset.
  ///
  /// In en, this message translates to:
  /// **'Using the default download folder'**
  String get downloadsFolderReset;

  /// No description provided for @downloadsDeleteAllCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all completed?'**
  String get downloadsDeleteAllCompletedTitle;

  /// No description provided for @downloadsDeleteAllCompletedBody.
  ///
  /// In en, this message translates to:
  /// **'Removes every finished download from this device and frees the disk space.'**
  String get downloadsDeleteAllCompletedBody;

  /// No description provided for @downloadsDeleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete all'**
  String get downloadsDeleteAll;

  /// No description provided for @downloadsCompletedDeleted.
  ///
  /// In en, this message translates to:
  /// **'Completed downloads deleted'**
  String get downloadsCompletedDeleted;

  /// No description provided for @downloadsTabActive.
  ///
  /// In en, this message translates to:
  /// **'Active ({count})'**
  String downloadsTabActive(int count);

  /// No description provided for @downloadsTabCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed ({count})'**
  String downloadsTabCompleted(int count);

  /// No description provided for @downloadsActiveEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No active downloads'**
  String get downloadsActiveEmptyTitle;

  /// No description provided for @downloadsActiveEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Start one from details, Sources, or the player.'**
  String get downloadsActiveEmptyHint;

  /// No description provided for @downloadsCompletedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No offline downloads yet'**
  String get downloadsCompletedEmptyTitle;

  /// No description provided for @downloadsCompletedEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Finished titles show up here — play anytime without a network.'**
  String get downloadsCompletedEmptyHint;

  /// No description provided for @downloadsStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get downloadsStorageTitle;

  /// No description provided for @downloadsStorageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Offline library for this profile.'**
  String get downloadsStorageSubtitle;

  /// No description provided for @downloadsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get downloadsRefresh;

  /// Sits between two bold sizes, as in '12 GB used of 256 GB'. Keep the leading and trailing space.
  ///
  /// In en, this message translates to:
  /// **' used of '**
  String get downloadsUsedOf;

  /// Follows the 'used of' line, as in '  ·  100 GB free'. Keep the leading spaces.
  ///
  /// In en, this message translates to:
  /// **'  ·  {free} free'**
  String downloadsFreeSuffix(String free);

  /// No description provided for @downloadsLegendOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get downloadsLegendOffline;

  /// No description provided for @downloadsLegendOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get downloadsLegendOther;

  /// No description provided for @downloadsLegendAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get downloadsLegendAvailable;

  /// No description provided for @downloadsChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get downloadsChange;

  /// No description provided for @downloadsDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get downloadsDefault;

  /// No description provided for @downloadsStatusQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get downloadsStatusQueued;

  /// No description provided for @downloadsStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get downloadsStatusPaused;

  /// No description provided for @downloadsStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get downloadsStatusFailed;

  /// Estimated time left for a download. ETA = estimated time of arrival.
  ///
  /// In en, this message translates to:
  /// **'ETA {eta}'**
  String downloadsEta(String eta);

  /// No description provided for @downloadsPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get downloadsPause;

  /// No description provided for @downloadsResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get downloadsResume;

  /// No description provided for @downloadsRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get downloadsRetry;

  /// No description provided for @downloadsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get downloadsCancel;

  /// No description provided for @downloadsPlayOffline.
  ///
  /// In en, this message translates to:
  /// **'Play offline'**
  String get downloadsPlayOffline;

  /// No description provided for @downloadsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get downloadsDelete;

  /// No description provided for @downloadsDeleteOneTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete download?'**
  String get downloadsDeleteOneTitle;

  /// No description provided for @downloadsDeleteOneBody.
  ///
  /// In en, this message translates to:
  /// **'Removes “{title}” from this device.'**
  String downloadsDeleteOneBody(String title);

  /// No description provided for @settingsUiAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get settingsUiAuto;

  /// No description provided for @settingsUiCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsUiCancel;

  /// No description provided for @settingsUiClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get settingsUiClose;

  /// No description provided for @settingsUiLanP2pPairTitle.
  ///
  /// In en, this message translates to:
  /// **'Pair a desktop'**
  String get settingsUiLanP2pPairTitle;

  /// No description provided for @settingsUiLanP2pOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Desktop offline'**
  String get settingsUiLanP2pOfflineTitle;

  /// No description provided for @settingsUiLanP2pPairBody.
  ///
  /// In en, this message translates to:
  /// **'Torrents and other P2P streams play on a desktop Forja server, not on this TV. Direct HTTP streams still play here. Pair once in Settings → LAN.'**
  String get settingsUiLanP2pPairBody;

  /// No description provided for @settingsUiLanP2pOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'Torrents and other P2P streams need your paired desktop Forja server on the same Wi-Fi. Direct HTTP streams still play on this TV.'**
  String get settingsUiLanP2pOfflineBody;

  /// No description provided for @settingsUiLanP2pOpenLan.
  ///
  /// In en, this message translates to:
  /// **'Open LAN'**
  String get settingsUiLanP2pOpenLan;

  /// No description provided for @settingsUiP2pAckTitle.
  ///
  /// In en, this message translates to:
  /// **'P2P Streaming'**
  String get settingsUiP2pAckTitle;

  /// No description provided for @settingsUiP2pAckAware.
  ///
  /// In en, this message translates to:
  /// **'I am aware'**
  String get settingsUiP2pAckAware;

  /// No description provided for @settingsUiP2pAckIntro.
  ///
  /// In en, this message translates to:
  /// **'This stream uses peer-to-peer (P2P) technology. By continuing, you confirm you are aware that:'**
  String get settingsUiP2pAckIntro;

  /// No description provided for @settingsUiP2pAckBulletIp.
  ///
  /// In en, this message translates to:
  /// **'Your IP address will be visible to other peers in the network'**
  String get settingsUiP2pAckBulletIp;

  /// No description provided for @settingsUiP2pAckBulletResponsible.
  ///
  /// In en, this message translates to:
  /// **'You are solely responsible for the content you access'**
  String get settingsUiP2pAckBulletResponsible;

  /// No description provided for @settingsUiP2pAckBulletLegalRight.
  ///
  /// In en, this message translates to:
  /// **'You confirm you have the legal right to stream this content in your jurisdiction'**
  String get settingsUiP2pAckBulletLegalRight;

  /// No description provided for @settingsUiP2pAckBulletNoHosting.
  ///
  /// In en, this message translates to:
  /// **'Forja does not host, distribute, or control any P2P content'**
  String get settingsUiP2pAckBulletNoHosting;

  /// No description provided for @settingsUiP2pAckBulletNoLiability.
  ///
  /// In en, this message translates to:
  /// **'Forja bears no liability for any legal consequences arising from your use of P2P streaming'**
  String get settingsUiP2pAckBulletNoLiability;

  /// No description provided for @settingsUiP2pAckOutro.
  ///
  /// In en, this message translates to:
  /// **'You use this feature entirely at your own risk. Direct torrent, Stremio, and Nuvio can be turned off anytime in Settings.'**
  String get settingsUiP2pAckOutro;

  /// No description provided for @settingsUiP2pAckVpnBanner.
  ///
  /// In en, this message translates to:
  /// **'For better privacy, use a VPN. Your IP address is visible to other peers.'**
  String get settingsUiP2pAckVpnBanner;

  /// Sidebar credit line 'Made with <heart icon> by Schmenka'. Keep the trailing space; the heart icon follows.
  ///
  /// In en, this message translates to:
  /// **'Made with '**
  String get settingsUiMadeWith;

  /// Sidebar credit line, between the heart icon and the author name. Keep the leading and trailing spaces.
  ///
  /// In en, this message translates to:
  /// **' by '**
  String get settingsUiMadeWithBy;

  /// No description provided for @playerScreenTryingNextStream.
  ///
  /// In en, this message translates to:
  /// **'Trying next stream…'**
  String get playerScreenTryingNextStream;

  /// No description provided for @playerScreenFindingAnotherStream.
  ///
  /// In en, this message translates to:
  /// **'Finding another stream…'**
  String get playerScreenFindingAnotherStream;

  /// No description provided for @playerScreenFindingServers.
  ///
  /// In en, this message translates to:
  /// **'Finding servers…'**
  String get playerScreenFindingServers;

  /// No description provided for @playerScreenFailedToStream.
  ///
  /// In en, this message translates to:
  /// **'Failed to stream'**
  String get playerScreenFailedToStream;

  /// No description provided for @playerScreenExoSeparateAudioUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Separate audio track not supported in ExoPlayer - use MediaKit in Settings.'**
  String get playerScreenExoSeparateAudioUnsupported;

  /// No description provided for @playerScreenReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get playerScreenReconnecting;

  /// No description provided for @playerScreenReconnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Reconnect failed'**
  String get playerScreenReconnectFailed;

  /// No description provided for @playerScreenEpisodeNumber.
  ///
  /// In en, this message translates to:
  /// **'Episode {number}'**
  String playerScreenEpisodeNumber(String number);

  /// No description provided for @playerScreenPreviousEpisodeButton.
  ///
  /// In en, this message translates to:
  /// **'Previous Episode'**
  String get playerScreenPreviousEpisodeButton;

  /// No description provided for @playerScreenNextEpisodeButton.
  ///
  /// In en, this message translates to:
  /// **'Next Episode'**
  String get playerScreenNextEpisodeButton;

  /// No description provided for @playerScreenAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get playerScreenAudio;

  /// No description provided for @playerScreenQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get playerScreenQuality;

  /// No description provided for @playerScreenLoadingSources.
  ///
  /// In en, this message translates to:
  /// **'Loading sources…'**
  String get playerScreenLoadingSources;

  /// No description provided for @playerScreenFailedToLoadSources.
  ///
  /// In en, this message translates to:
  /// **'Failed to load sources'**
  String get playerScreenFailedToLoadSources;

  /// No description provided for @playerScreenCheckingSources.
  ///
  /// In en, this message translates to:
  /// **'Checking sources'**
  String get playerScreenCheckingSources;

  /// No description provided for @playerScreenNoStreamsFound.
  ///
  /// In en, this message translates to:
  /// **'No streams found'**
  String get playerScreenNoStreamsFound;

  /// No description provided for @playerScreenStream.
  ///
  /// In en, this message translates to:
  /// **'Stream'**
  String get playerScreenStream;

  /// No description provided for @playerScreenStremioStream.
  ///
  /// In en, this message translates to:
  /// **'Stremio stream'**
  String get playerScreenStremioStream;

  /// No description provided for @playerScreenFailedToResolveStream.
  ///
  /// In en, this message translates to:
  /// **'Failed to resolve stream'**
  String get playerScreenFailedToResolveStream;

  /// No description provided for @playerScreenTorrentStreamFailedToStart.
  ///
  /// In en, this message translates to:
  /// **'Torrent stream failed to start'**
  String get playerScreenTorrentStreamFailedToStart;

  /// No description provided for @playerScreenOpeningStream.
  ///
  /// In en, this message translates to:
  /// **'Opening stream…'**
  String get playerScreenOpeningStream;

  /// No description provided for @playerScreenSources.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get playerScreenSources;

  /// No description provided for @playerScreenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Subtitle'**
  String get playerScreenSubtitle;

  /// No description provided for @playerScreenSubtitleFailed.
  ///
  /// In en, this message translates to:
  /// **'Subtitle failed'**
  String get playerScreenSubtitleFailed;

  /// No description provided for @playerScreenBack10s.
  ///
  /// In en, this message translates to:
  /// **'Back 10s'**
  String get playerScreenBack10s;

  /// No description provided for @playerScreenForward10s.
  ///
  /// In en, this message translates to:
  /// **'Forward 10s'**
  String get playerScreenForward10s;

  /// No description provided for @playerScreenNoMoreEpisodes.
  ///
  /// In en, this message translates to:
  /// **'No more episodes'**
  String get playerScreenNoMoreEpisodes;

  /// No description provided for @playerScreenCouldNotFindStreamForEpisode.
  ///
  /// In en, this message translates to:
  /// **'Could not find a stream for this episode'**
  String get playerScreenCouldNotFindStreamForEpisode;

  /// No description provided for @playerScreenLoadingEpisodeInfo.
  ///
  /// In en, this message translates to:
  /// **'Loading episode info…'**
  String get playerScreenLoadingEpisodeInfo;

  /// No description provided for @playerScreenSeasonEpisode.
  ///
  /// In en, this message translates to:
  /// **'Season {season} · Episode {episode}'**
  String playerScreenSeasonEpisode(int season, int episode);

  /// No description provided for @playerScreenCheckingSourcesProgress.
  ///
  /// In en, this message translates to:
  /// **'Checking sources…'**
  String get playerScreenCheckingSourcesProgress;

  /// No description provided for @playerScreenResolvingTorrent.
  ///
  /// In en, this message translates to:
  /// **'Resolving torrent…'**
  String get playerScreenResolvingTorrent;

  /// No description provided for @playerScreenCheckingStremio.
  ///
  /// In en, this message translates to:
  /// **'Checking Stremio…'**
  String get playerScreenCheckingStremio;

  /// No description provided for @playerScreenAutoSelection.
  ///
  /// In en, this message translates to:
  /// **'Auto selection'**
  String get playerScreenAutoSelection;

  /// No description provided for @playerScreenAutoSelectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Servers, tracks, skip intro'**
  String get playerScreenAutoSelectionSubtitle;

  /// No description provided for @playerScreenAutoServer.
  ///
  /// In en, this message translates to:
  /// **'Auto server'**
  String get playerScreenAutoServer;

  /// No description provided for @playerScreenAutoSource.
  ///
  /// In en, this message translates to:
  /// **'Auto source'**
  String get playerScreenAutoSource;

  /// No description provided for @playerScreenAutoAudio.
  ///
  /// In en, this message translates to:
  /// **'Auto audio'**
  String get playerScreenAutoAudio;

  /// No description provided for @playerScreenAutoSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Auto subtitles'**
  String get playerScreenAutoSubtitles;

  /// No description provided for @playerScreenAutoSkipIntro.
  ///
  /// In en, this message translates to:
  /// **'Auto skip intro'**
  String get playerScreenAutoSkipIntro;

  /// No description provided for @playerScreenAutoNextEpisode.
  ///
  /// In en, this message translates to:
  /// **'Auto next episode'**
  String get playerScreenAutoNextEpisode;

  /// No description provided for @playerScreenVideoDecode.
  ///
  /// In en, this message translates to:
  /// **'Video decode'**
  String get playerScreenVideoDecode;

  /// No description provided for @playerScreenHwDecGpuSafe.
  ///
  /// In en, this message translates to:
  /// **'Hardware Decoding: ON (GPU, safe)'**
  String get playerScreenHwDecGpuSafe;

  /// No description provided for @playerScreenHwDecCopyBack.
  ///
  /// In en, this message translates to:
  /// **'Hardware Decoding: ON (copy-back)'**
  String get playerScreenHwDecCopyBack;

  /// No description provided for @playerScreenHwDecOffCpu.
  ///
  /// In en, this message translates to:
  /// **'Hardware Decoding: OFF (CPU)'**
  String get playerScreenHwDecOffCpu;

  /// No description provided for @playerScreenSwDecodeSoftDisplay.
  ///
  /// In en, this message translates to:
  /// **'Software decode + soft display (CPU)'**
  String get playerScreenSwDecodeSoftDisplay;

  /// No description provided for @playerScreenPlaybackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get playerScreenPlaybackSpeed;

  /// No description provided for @playerScreenPlaybackSpeedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How fast playback runs'**
  String get playerScreenPlaybackSpeedSubtitle;

  /// No description provided for @playerScreenSpeedNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get playerScreenSpeedNormal;

  /// No description provided for @playerScreenAspectRatio.
  ///
  /// In en, this message translates to:
  /// **'Aspect ratio'**
  String get playerScreenAspectRatio;

  /// No description provided for @playerScreenAspectRatioSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fit video in the frame'**
  String get playerScreenAspectRatioSubtitle;

  /// No description provided for @playerScreenFitFit.
  ///
  /// In en, this message translates to:
  /// **'FIT'**
  String get playerScreenFitFit;

  /// No description provided for @playerScreenFitCrop.
  ///
  /// In en, this message translates to:
  /// **'CROP'**
  String get playerScreenFitCrop;

  /// No description provided for @playerScreenFitFill.
  ///
  /// In en, this message translates to:
  /// **'FILL'**
  String get playerScreenFitFill;

  /// No description provided for @playerScreenLoop.
  ///
  /// In en, this message translates to:
  /// **'Loop'**
  String get playerScreenLoop;

  /// No description provided for @playerScreenLoopSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Repeat the current title'**
  String get playerScreenLoopSubtitle;

  /// No description provided for @playerScreenOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get playerScreenOn;

  /// No description provided for @playerScreenOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get playerScreenOff;

  /// No description provided for @playerScreenTorrentStats.
  ///
  /// In en, this message translates to:
  /// **'Torrent stats'**
  String get playerScreenTorrentStats;

  /// No description provided for @playerScreenTorrentStatsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show live transfer overlay'**
  String get playerScreenTorrentStatsSubtitle;

  /// No description provided for @playerScreenSkipRecap.
  ///
  /// In en, this message translates to:
  /// **'Skip Recap'**
  String get playerScreenSkipRecap;

  /// No description provided for @playerScreenSkipIntro.
  ///
  /// In en, this message translates to:
  /// **'Skip Intro'**
  String get playerScreenSkipIntro;

  /// No description provided for @playerScreenSkipCredits.
  ///
  /// In en, this message translates to:
  /// **'Skip Credits'**
  String get playerScreenSkipCredits;

  /// No description provided for @playerScreenSkipPreview.
  ///
  /// In en, this message translates to:
  /// **'Skip Preview'**
  String get playerScreenSkipPreview;

  /// No description provided for @playerScreenPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playerScreenPlay;

  /// No description provided for @playerScreenEpisodes.
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get playerScreenEpisodes;

  /// No description provided for @playerScreenSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get playerScreenSubtitles;

  /// No description provided for @playerScreenFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen'**
  String get playerScreenFullscreen;

  /// No description provided for @playerScreenStreamFailed.
  ///
  /// In en, this message translates to:
  /// **'Stream failed'**
  String get playerScreenStreamFailed;

  /// No description provided for @playerScreenPlaybackFailedOpenSources.
  ///
  /// In en, this message translates to:
  /// **'Playback failed. Open Sources and choose another stream.'**
  String get playerScreenPlaybackFailedOpenSources;

  /// No description provided for @playerScreenNoWorkingStream.
  ///
  /// In en, this message translates to:
  /// **'Could not find any working stream from any provider.'**
  String get playerScreenNoWorkingStream;

  /// No description provided for @playerScreenTorrentStreamFailedToOpen.
  ///
  /// In en, this message translates to:
  /// **'Torrent stream failed to open.'**
  String get playerScreenTorrentStreamFailedToOpen;

  /// No description provided for @playerScreenDownloadedFileCantPlay.
  ///
  /// In en, this message translates to:
  /// **'Downloaded file can’t be played'**
  String get playerScreenDownloadedFileCantPlay;

  /// No description provided for @playerScreenPlaybackFailed.
  ///
  /// In en, this message translates to:
  /// **'Playback failed.'**
  String get playerScreenPlaybackFailed;

  /// No description provided for @playerScreenUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get playerScreenUnlock;

  /// No description provided for @playerScreenCouldNotOpenStream.
  ///
  /// In en, this message translates to:
  /// **'Could not open stream'**
  String get playerScreenCouldNotOpenStream;

  /// No description provided for @playerScreenSwitchingToMediaKit.
  ///
  /// In en, this message translates to:
  /// **'Switching to MediaKit…'**
  String get playerScreenSwitchingToMediaKit;

  /// No description provided for @playerScreenPressEscAgain.
  ///
  /// In en, this message translates to:
  /// **'Press Esc again to exit'**
  String get playerScreenPressEscAgain;

  /// No description provided for @playerScreenNextEpisodeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Next episode'**
  String get playerScreenNextEpisodeTooltip;

  /// No description provided for @playerScreenPlayer.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get playerScreenPlayer;

  /// No description provided for @playerScreenSourceFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed: {title}'**
  String playerScreenSourceFailed(String title);

  /// No description provided for @playerControlAirPlayEnded.
  ///
  /// In en, this message translates to:
  /// **'AirPlay ended'**
  String get playerControlAirPlayEnded;

  /// No description provided for @playerControlAirPlayOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open AirPlay'**
  String get playerControlAirPlayOpenFailed;

  /// No description provided for @playerControlAirPlaySubtitlesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Subtitles can\'t play on AirPlay for this stream'**
  String get playerControlAirPlaySubtitlesUnavailable;

  /// No description provided for @playerControlAllProviders.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get playerControlAllProviders;

  /// No description provided for @playerControlAspectRatio.
  ///
  /// In en, this message translates to:
  /// **'Aspect ratio'**
  String get playerControlAspectRatio;

  /// No description provided for @playerControlAspectRatioSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How video fills the frame'**
  String get playerControlAspectRatioSubtitle;

  /// No description provided for @playerControlAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get playerControlAudio;

  /// No description provided for @playerControlAutoAudio.
  ///
  /// In en, this message translates to:
  /// **'Auto audio'**
  String get playerControlAutoAudio;

  /// No description provided for @playerControlAutoNext.
  ///
  /// In en, this message translates to:
  /// **'AutoNext'**
  String get playerControlAutoNext;

  /// No description provided for @playerControlAutoSelection.
  ///
  /// In en, this message translates to:
  /// **'Auto selection'**
  String get playerControlAutoSelection;

  /// No description provided for @playerControlAutoSelectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Servers, tracks, skip intro'**
  String get playerControlAutoSelectionSubtitle;

  /// No description provided for @playerControlAutoServer.
  ///
  /// In en, this message translates to:
  /// **'Auto server'**
  String get playerControlAutoServer;

  /// No description provided for @playerControlAutoSource.
  ///
  /// In en, this message translates to:
  /// **'Auto source'**
  String get playerControlAutoSource;

  /// No description provided for @playerControlAutoSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Auto subtitles'**
  String get playerControlAutoSubtitles;

  /// No description provided for @playerControlAvPlayerMacOnly.
  ///
  /// In en, this message translates to:
  /// **'AVPlayer is macOS-only'**
  String get playerControlAvPlayerMacOnly;

  /// No description provided for @playerControlBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get playerControlBack;

  /// No description provided for @playerControlBack10s.
  ///
  /// In en, this message translates to:
  /// **'Back 10s'**
  String get playerControlBack10s;

  /// No description provided for @playerControlBuffering.
  ///
  /// In en, this message translates to:
  /// **'Buffering'**
  String get playerControlBuffering;

  /// No description provided for @playerControlBufferingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Buffering…'**
  String get playerControlBufferingEllipsis;

  /// No description provided for @playerControlBuiltIn.
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get playerControlBuiltIn;

  /// No description provided for @playerControlCast.
  ///
  /// In en, this message translates to:
  /// **'Cast'**
  String get playerControlCast;

  /// No description provided for @playerControlCastStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting {label}…'**
  String playerControlCastStarting(String label);

  /// No description provided for @playerControlCastTargetUnavailable.
  ///
  /// In en, this message translates to:
  /// **'{label} is not available yet'**
  String playerControlCastTargetUnavailable(String label);

  /// No description provided for @playerControlCastTo.
  ///
  /// In en, this message translates to:
  /// **'Cast to'**
  String get playerControlCastTo;

  /// No description provided for @playerControlCastUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Casting is not supported on this device'**
  String get playerControlCastUnsupported;

  /// No description provided for @playerControlCastingTo.
  ///
  /// In en, this message translates to:
  /// **'Casting to {label}'**
  String playerControlCastingTo(String label);

  /// No description provided for @playerControlChangePlayer.
  ///
  /// In en, this message translates to:
  /// **'Change player'**
  String get playerControlChangePlayer;

  /// No description provided for @playerControlCheck.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get playerControlCheck;

  /// No description provided for @playerControlCheckingOrdinal.
  ///
  /// In en, this message translates to:
  /// **'Checking {ordinal}/{total}…'**
  String playerControlCheckingOrdinal(int ordinal, int total);

  /// No description provided for @playerControlCheckingServer.
  ///
  /// In en, this message translates to:
  /// **'Checking server…'**
  String get playerControlCheckingServer;

  /// No description provided for @playerControlCheckingSources.
  ///
  /// In en, this message translates to:
  /// **'Checking sources'**
  String get playerControlCheckingSources;

  /// No description provided for @playerControlCheckingStream.
  ///
  /// In en, this message translates to:
  /// **'Checking stream…'**
  String get playerControlCheckingStream;

  /// No description provided for @playerControlChoosePlayer.
  ///
  /// In en, this message translates to:
  /// **'Choose player'**
  String get playerControlChoosePlayer;

  /// No description provided for @playerControlCrop.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get playerControlCrop;

  /// No description provided for @playerControlDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get playerControlDetails;

  /// No description provided for @playerControlEngineDrmNeedsExo.
  ///
  /// In en, this message translates to:
  /// **'DRM needs ExoPlayer'**
  String get playerControlEngineDrmNeedsExo;

  /// No description provided for @playerControlEngineSeparateAudioNeedsMediaKit.
  ///
  /// In en, this message translates to:
  /// **'Separate audio needs MediaKit'**
  String get playerControlEngineSeparateAudioNeedsMediaKit;

  /// No description provided for @playerControlEngineTorrentNeedsMediaKit.
  ///
  /// In en, this message translates to:
  /// **'Torrent streams need MediaKit'**
  String get playerControlEngineTorrentNeedsMediaKit;

  /// No description provided for @playerControlEpisodeNumber.
  ///
  /// In en, this message translates to:
  /// **'Episode {number}'**
  String playerControlEpisodeNumber(int number);

  /// No description provided for @playerControlEpisodes.
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get playerControlEpisodes;

  /// No description provided for @playerControlExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get playerControlExpand;

  /// No description provided for @playerControlExternalApp.
  ///
  /// In en, this message translates to:
  /// **'External app'**
  String get playerControlExternalApp;

  /// No description provided for @playerControlFailedToStream.
  ///
  /// In en, this message translates to:
  /// **'Failed to stream'**
  String get playerControlFailedToStream;

  /// No description provided for @playerControlFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get playerControlFile;

  /// No description provided for @playerControlFill.
  ///
  /// In en, this message translates to:
  /// **'Fill'**
  String get playerControlFill;

  /// No description provided for @playerControlFit.
  ///
  /// In en, this message translates to:
  /// **'Fit'**
  String get playerControlFit;

  /// No description provided for @playerControlForward10s.
  ///
  /// In en, this message translates to:
  /// **'Forward 10s'**
  String get playerControlForward10s;

  /// No description provided for @playerControlInAppMiniPlayer.
  ///
  /// In en, this message translates to:
  /// **'In-app mini player'**
  String get playerControlInAppMiniPlayer;

  /// No description provided for @playerControlInStream.
  ///
  /// In en, this message translates to:
  /// **'In-stream'**
  String get playerControlInStream;

  /// No description provided for @playerControlJackettNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Jackett is not configured'**
  String get playerControlJackettNotConfigured;

  /// No description provided for @playerControlKeepsStreamAlive.
  ///
  /// In en, this message translates to:
  /// **'Forja keeps the stream alive while you watch externally.'**
  String get playerControlKeepsStreamAlive;

  /// No description provided for @playerControlLanguages.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get playerControlLanguages;

  /// No description provided for @playerControlLaunchFailed.
  ///
  /// In en, this message translates to:
  /// **'Launch failed ({type}). See console for details.'**
  String playerControlLaunchFailed(String type);

  /// No description provided for @playerControlMinimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get playerControlMinimize;

  /// No description provided for @playerControlMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get playerControlMute;

  /// No description provided for @playerControlNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get playerControlNext;

  /// No description provided for @playerControlNextEpisode.
  ///
  /// In en, this message translates to:
  /// **'Next Episode'**
  String get playerControlNextEpisode;

  /// No description provided for @playerControlNoAudioTracks.
  ///
  /// In en, this message translates to:
  /// **'No audio tracks found'**
  String get playerControlNoAudioTracks;

  /// No description provided for @playerControlNoEpisodesFound.
  ///
  /// In en, this message translates to:
  /// **'No episodes found'**
  String get playerControlNoEpisodesFound;

  /// No description provided for @playerControlNoExternalPlayers.
  ///
  /// In en, this message translates to:
  /// **'No external players installed'**
  String get playerControlNoExternalPlayers;

  /// No description provided for @playerControlNoFilterSources.
  ///
  /// In en, this message translates to:
  /// **'No {filter} sources'**
  String playerControlNoFilterSources(String filter);

  /// No description provided for @playerControlNoForjaPlugins.
  ///
  /// In en, this message translates to:
  /// **'No Forja plugins installed'**
  String get playerControlNoForjaPlugins;

  /// No description provided for @playerControlNoMatchingEpisodes.
  ///
  /// In en, this message translates to:
  /// **'No matching episodes'**
  String get playerControlNoMatchingEpisodes;

  /// No description provided for @playerControlNoMatchingSources.
  ///
  /// In en, this message translates to:
  /// **'No matching sources'**
  String get playerControlNoMatchingSources;

  /// No description provided for @playerControlNoMatchingStremioId.
  ///
  /// In en, this message translates to:
  /// **'No matching id for this Stremio addon'**
  String get playerControlNoMatchingStremioId;

  /// No description provided for @playerControlNoNuvioScrapers.
  ///
  /// In en, this message translates to:
  /// **'No Nuvio scrapers. Add them in Settings → Addons → Nuvio'**
  String get playerControlNoNuvioScrapers;

  /// No description provided for @playerControlNoOnlineSubtitles.
  ///
  /// In en, this message translates to:
  /// **'No online subtitles yet. Tap Search to type the film or series name.'**
  String get playerControlNoOnlineSubtitles;

  /// No description provided for @playerControlNoSavedFiles.
  ///
  /// In en, this message translates to:
  /// **'No saved files'**
  String get playerControlNoSavedFiles;

  /// No description provided for @playerControlNoServers.
  ///
  /// In en, this message translates to:
  /// **'No servers'**
  String get playerControlNoServers;

  /// No description provided for @playerControlNoSourcesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No sources available'**
  String get playerControlNoSourcesAvailable;

  /// No description provided for @playerControlNoStreamToCast.
  ///
  /// In en, this message translates to:
  /// **'No stream to cast'**
  String get playerControlNoStreamToCast;

  /// No description provided for @playerControlNoStreamsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No streams available'**
  String get playerControlNoStreamsAvailable;

  /// No description provided for @playerControlNoStreamsForjaPlugins.
  ///
  /// In en, this message translates to:
  /// **'No streams found from selected Forja plugins'**
  String get playerControlNoStreamsForjaPlugins;

  /// No description provided for @playerControlNoStreamsInAddon.
  ///
  /// In en, this message translates to:
  /// **'No streams found in {addon}'**
  String playerControlNoStreamsInAddon(String addon);

  /// No description provided for @playerControlNoStreamsNuvio.
  ///
  /// In en, this message translates to:
  /// **'No streams found from selected Nuvio providers'**
  String get playerControlNoStreamsNuvio;

  /// No description provided for @playerControlNoStremioAddons.
  ///
  /// In en, this message translates to:
  /// **'No Stremio stream addons. Add them in Settings → Addons → Stremio'**
  String get playerControlNoStremioAddons;

  /// No description provided for @playerControlNoSubtitles.
  ///
  /// In en, this message translates to:
  /// **'No subtitles'**
  String get playerControlNoSubtitles;

  /// No description provided for @playerControlNoTmdbIdForNuvio.
  ///
  /// In en, this message translates to:
  /// **'No TMDB id for Nuvio streams'**
  String get playerControlNoTmdbIdForNuvio;

  /// No description provided for @playerControlNoTorrentFiles.
  ///
  /// In en, this message translates to:
  /// **'No files found in this torrent.'**
  String get playerControlNoTorrentFiles;

  /// No description provided for @playerControlNoTorrentsFound.
  ///
  /// In en, this message translates to:
  /// **'No torrents found'**
  String get playerControlNoTorrentsFound;

  /// No description provided for @playerControlNoTracks.
  ///
  /// In en, this message translates to:
  /// **'No tracks'**
  String get playerControlNoTracks;

  /// No description provided for @playerControlNoneAvailable.
  ///
  /// In en, this message translates to:
  /// **'None available'**
  String get playerControlNoneAvailable;

  /// No description provided for @playerControlNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get playerControlNormal;

  /// No description provided for @playerControlOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get playerControlOff;

  /// No description provided for @playerControlOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get playerControlOn;

  /// No description provided for @playerControlOpeningInPlayer.
  ///
  /// In en, this message translates to:
  /// **'Opening in {player}…'**
  String playerControlOpeningInPlayer(String player);

  /// No description provided for @playerControlParentalAlcoholDrugs.
  ///
  /// In en, this message translates to:
  /// **'Alcohol/Drugs'**
  String get playerControlParentalAlcoholDrugs;

  /// No description provided for @playerControlParentalFrightening.
  ///
  /// In en, this message translates to:
  /// **'Frightening'**
  String get playerControlParentalFrightening;

  /// No description provided for @playerControlParentalNudity.
  ///
  /// In en, this message translates to:
  /// **'Nudity'**
  String get playerControlParentalNudity;

  /// No description provided for @playerControlParentalProfanity.
  ///
  /// In en, this message translates to:
  /// **'Profanity'**
  String get playerControlParentalProfanity;

  /// No description provided for @playerControlParentalViolence.
  ///
  /// In en, this message translates to:
  /// **'Violence'**
  String get playerControlParentalViolence;

  /// No description provided for @playerControlPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get playerControlPause;

  /// No description provided for @playerControlPictureInPicture.
  ///
  /// In en, this message translates to:
  /// **'Picture in Picture'**
  String get playerControlPictureInPicture;

  /// No description provided for @playerControlPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playerControlPlay;

  /// No description provided for @playerControlPlaybackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get playerControlPlaybackSpeed;

  /// No description provided for @playerControlPlayer.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get playerControlPlayer;

  /// No description provided for @playerControlPlayerCouldNotLaunch.
  ///
  /// In en, this message translates to:
  /// **'{player} could not be launched. Is it installed?'**
  String playerControlPlayerCouldNotLaunch(String player);

  /// No description provided for @playerControlPlayerNotFound.
  ///
  /// In en, this message translates to:
  /// **'{player} not found. Using built-in player.'**
  String playerControlPlayerNotFound(String player);

  /// No description provided for @playerControlPlayingInPip.
  ///
  /// In en, this message translates to:
  /// **'Playing in picture-in-picture'**
  String get playerControlPlayingInPip;

  /// No description provided for @playerControlPlayingNow.
  ///
  /// In en, this message translates to:
  /// **'Playing now'**
  String get playerControlPlayingNow;

  /// No description provided for @playerControlPlayingOnAirPlay.
  ///
  /// In en, this message translates to:
  /// **'Playing on AirPlay'**
  String get playerControlPlayingOnAirPlay;

  /// No description provided for @playerControlPreparingStream.
  ///
  /// In en, this message translates to:
  /// **'Preparing stream…'**
  String get playerControlPreparingStream;

  /// No description provided for @playerControlPressBackAgainToExit.
  ///
  /// In en, this message translates to:
  /// **'Press Back again to exit'**
  String get playerControlPressBackAgainToExit;

  /// No description provided for @playerControlPressBackToLeave.
  ///
  /// In en, this message translates to:
  /// **'Press Back to leave'**
  String get playerControlPressBackToLeave;

  /// No description provided for @playerControlPressEscAgainToExit.
  ///
  /// In en, this message translates to:
  /// **'Press Esc again to exit'**
  String get playerControlPressEscAgainToExit;

  /// No description provided for @playerControlPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get playerControlPrevious;

  /// No description provided for @playerControlPreviousEpisode.
  ///
  /// In en, this message translates to:
  /// **'Previous Episode'**
  String get playerControlPreviousEpisode;

  /// No description provided for @playerControlProviderUnavailable.
  ///
  /// In en, this message translates to:
  /// **'{name} is unavailable'**
  String playerControlProviderUnavailable(String name);

  /// No description provided for @playerControlProwlarrNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Prowlarr is not configured'**
  String get playerControlProwlarrNotConfigured;

  /// No description provided for @playerControlQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get playerControlQuality;

  /// No description provided for @playerControlQualityNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Quality not available yet'**
  String get playerControlQualityNotAvailable;

  /// No description provided for @playerControlRelaunchInPlayer.
  ///
  /// In en, this message translates to:
  /// **'Re-launch in {player}'**
  String playerControlRelaunchInPlayer(String player);

  /// No description provided for @playerControlSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get playerControlSearch;

  /// No description provided for @playerControlSearchingHint.
  ///
  /// In en, this message translates to:
  /// **'Searching: {hint}'**
  String playerControlSearchingHint(String hint);

  /// No description provided for @playerControlSearchingSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Searching subtitles…'**
  String get playerControlSearchingSubtitles;

  /// No description provided for @playerControlSeasonNumber.
  ///
  /// In en, this message translates to:
  /// **'Season {number}'**
  String playerControlSeasonNumber(int number);

  /// No description provided for @playerControlSelectProvider.
  ///
  /// In en, this message translates to:
  /// **'Select at least one provider'**
  String get playerControlSelectProvider;

  /// No description provided for @playerControlSelectServer.
  ///
  /// In en, this message translates to:
  /// **'Select a server'**
  String get playerControlSelectServer;

  /// No description provided for @playerControlServers.
  ///
  /// In en, this message translates to:
  /// **'Servers'**
  String get playerControlServers;

  /// No description provided for @playerControlShuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get playerControlShuffle;

  /// No description provided for @playerControlSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get playerControlSource;

  /// No description provided for @playerControlSourceTip.
  ///
  /// In en, this message translates to:
  /// **'Source: {label}'**
  String playerControlSourceTip(String label);

  /// No description provided for @playerControlSourceTipWithServer.
  ///
  /// In en, this message translates to:
  /// **'Source: {label} · {server}'**
  String playerControlSourceTipWithServer(String label, String server);

  /// No description provided for @playerControlSourcesTip.
  ///
  /// In en, this message translates to:
  /// **'Sources: {label}'**
  String playerControlSourcesTip(String label);

  /// No description provided for @playerControlSourcesTipWithServer.
  ///
  /// In en, this message translates to:
  /// **'Sources: {label} · {server}'**
  String playerControlSourcesTipWithServer(String label, String server);

  /// No description provided for @playerControlStatusChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get playerControlStatusChecking;

  /// No description provided for @playerControlStatusPlaying.
  ///
  /// In en, this message translates to:
  /// **'Playing'**
  String get playerControlStatusPlaying;

  /// No description provided for @playerControlStatusUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get playerControlStatusUnavailable;

  /// No description provided for @playerControlStream.
  ///
  /// In en, this message translates to:
  /// **'Stream'**
  String get playerControlStream;

  /// No description provided for @playerControlStreamActive.
  ///
  /// In en, this message translates to:
  /// **'Stream active'**
  String get playerControlStreamActive;

  /// No description provided for @playerControlStreamCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 stream} other{{count} streams}}'**
  String playerControlStreamCount(int count);

  /// No description provided for @playerControlStreamNumber.
  ///
  /// In en, this message translates to:
  /// **'Stream {number}'**
  String playerControlStreamNumber(int number);

  /// No description provided for @playerControlStreams.
  ///
  /// In en, this message translates to:
  /// **'Streams'**
  String get playerControlStreams;

  /// No description provided for @playerControlStreamsServer.
  ///
  /// In en, this message translates to:
  /// **'Streams · {server}'**
  String playerControlStreamsServer(String server);

  /// No description provided for @playerControlSubBgOpacity.
  ///
  /// In en, this message translates to:
  /// **'BG Opacity'**
  String get playerControlSubBgOpacity;

  /// No description provided for @playerControlSubBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get playerControlSubBold;

  /// No description provided for @playerControlSubDecreaseDelay.
  ///
  /// In en, this message translates to:
  /// **'Decrease delay'**
  String get playerControlSubDecreaseDelay;

  /// No description provided for @playerControlSubDelay.
  ///
  /// In en, this message translates to:
  /// **'Delay'**
  String get playerControlSubDelay;

  /// No description provided for @playerControlSubFont.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get playerControlSubFont;

  /// No description provided for @playerControlSubIncreaseDelay.
  ///
  /// In en, this message translates to:
  /// **'Increase delay'**
  String get playerControlSubIncreaseDelay;

  /// No description provided for @playerControlSubPosition.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get playerControlSubPosition;

  /// No description provided for @playerControlSubSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get playerControlSubSize;

  /// No description provided for @playerControlSubTextColor.
  ///
  /// In en, this message translates to:
  /// **'Text Color'**
  String get playerControlSubTextColor;

  /// No description provided for @playerControlSubtitleSettings.
  ///
  /// In en, this message translates to:
  /// **'Subtitle settings'**
  String get playerControlSubtitleSettings;

  /// No description provided for @playerControlSubtitleSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Subtitle Settings'**
  String get playerControlSubtitleSettingsTitle;

  /// No description provided for @playerControlSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get playerControlSubtitles;

  /// No description provided for @playerControlSwitchingPlayer.
  ///
  /// In en, this message translates to:
  /// **'Switching player…'**
  String get playerControlSwitchingPlayer;

  /// No description provided for @playerControlTapServerToCheck.
  ///
  /// In en, this message translates to:
  /// **'Tap the server to check'**
  String get playerControlTapServerToCheck;

  /// No description provided for @playerControlTipOffline.
  ///
  /// In en, this message translates to:
  /// **'{base} · Offline'**
  String playerControlTipOffline(String base);

  /// No description provided for @playerControlTorrentEta.
  ///
  /// In en, this message translates to:
  /// **'ETA {eta}'**
  String playerControlTorrentEta(String eta);

  /// No description provided for @playerControlTorrentFiles.
  ///
  /// In en, this message translates to:
  /// **'Torrent files'**
  String get playerControlTorrentFiles;

  /// No description provided for @playerControlTorrentPeers.
  ///
  /// In en, this message translates to:
  /// **'{active} live · {total} seen'**
  String playerControlTorrentPeers(int active, int total);

  /// No description provided for @playerControlTorrentSeeders.
  ///
  /// In en, this message translates to:
  /// **'{seeders} seeders'**
  String playerControlTorrentSeeders(String seeders);

  /// No description provided for @playerControlTracks.
  ///
  /// In en, this message translates to:
  /// **'Tracks'**
  String get playerControlTracks;

  /// No description provided for @playerControlTracksGroup.
  ///
  /// In en, this message translates to:
  /// **'Tracks · {group}'**
  String playerControlTracksGroup(String group);

  /// No description provided for @playerControlTranslatedFrom.
  ///
  /// In en, this message translates to:
  /// **'Translated · {source}'**
  String playerControlTranslatedFrom(String source);

  /// No description provided for @playerControlUnknownStream.
  ///
  /// In en, this message translates to:
  /// **'Unknown Stream'**
  String get playerControlUnknownStream;

  /// No description provided for @playerControlUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get playerControlUnmute;

  /// No description provided for @playerControlViaPlayer.
  ///
  /// In en, this message translates to:
  /// **'via {player}'**
  String playerControlViaPlayer(String player);

  /// No description provided for @playerControlVlcNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'VLC (libVLC) is not installed'**
  String get playerControlVlcNotInstalled;

  /// No description provided for @playerControlWatchInForja.
  ///
  /// In en, this message translates to:
  /// **'Watch in Forja instead'**
  String get playerControlWatchInForja;

  /// No description provided for @playerControlWatchParty.
  ///
  /// In en, this message translates to:
  /// **'Watch Party'**
  String get playerControlWatchParty;

  /// No description provided for @playerControlWatchPartySoon.
  ///
  /// In en, this message translates to:
  /// **'Watch Party - coming soon'**
  String get playerControlWatchPartySoon;

  /// No description provided for @playerSourcePortalNotFound.
  ///
  /// In en, this message translates to:
  /// **'Portal not found'**
  String get playerSourcePortalNotFound;

  /// No description provided for @playerSourceOpenStreamFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open stream'**
  String get playerSourceOpenStreamFailed;

  /// No description provided for @playerSourceNoEpisodeSelected.
  ///
  /// In en, this message translates to:
  /// **'No episode selected'**
  String get playerSourceNoEpisodeSelected;

  /// No description provided for @playerSourceOpenEpisodeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open episode'**
  String get playerSourceOpenEpisodeFailed;

  /// No description provided for @playerSourceVodEpisodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Ep {number} · {title}'**
  String playerSourceVodEpisodeTitle(int number, String title);

  /// No description provided for @playerSourceStreamsTitle.
  ///
  /// In en, this message translates to:
  /// **'Streams'**
  String get playerSourceStreamsTitle;

  /// No description provided for @playerSourcePlaybackFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t start playback'**
  String get playerSourcePlaybackFailedTitle;

  /// No description provided for @playerSourceResolvingLink.
  ///
  /// In en, this message translates to:
  /// **'Resolving download link…'**
  String get playerSourceResolvingLink;

  /// No description provided for @playerSourceResolvingLinkHint.
  ///
  /// In en, this message translates to:
  /// **'Fetching the magnet from the torrent page.'**
  String get playerSourceResolvingLinkHint;

  /// No description provided for @playerSourceMagnetResolveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not resolve a magnet link for this torrent.'**
  String get playerSourceMagnetResolveFailed;

  /// No description provided for @playerSourceTorrentStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Torrent stream failed to start.'**
  String get playerSourceTorrentStartFailed;

  /// No description provided for @playerSourceStreamStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start this stream. Try again or pick another source.'**
  String get playerSourceStreamStartFailed;

  /// No description provided for @playerSourceNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get playerSourceNoMatches;

  /// No description provided for @playerSourceNoChannelsMatch.
  ///
  /// In en, this message translates to:
  /// **'No channels match'**
  String get playerSourceNoChannelsMatch;

  /// No description provided for @playerSourceSearchChannelsHint.
  ///
  /// In en, this message translates to:
  /// **'Search channels…'**
  String get playerSourceSearchChannelsHint;

  /// No description provided for @playerSourcePeers.
  ///
  /// In en, this message translates to:
  /// **'peers'**
  String get playerSourcePeers;

  /// No description provided for @playerSourcePeersOf.
  ///
  /// In en, this message translates to:
  /// **'of {seen} peers'**
  String playerSourcePeersOf(int seen);

  /// No description provided for @playerSourcePeersSeen.
  ///
  /// In en, this message translates to:
  /// **'{seen} seen'**
  String playerSourcePeersSeen(int seen);

  /// No description provided for @playerSourceStatDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get playerSourceStatDownload;

  /// No description provided for @playerSourceStatFileCached.
  ///
  /// In en, this message translates to:
  /// **'File cached'**
  String get playerSourceStatFileCached;

  /// No description provided for @playerSourceFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get playerSourceFilterAll;

  /// No description provided for @playerSourceFilterAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get playerSourceFilterAudio;

  /// No description provided for @playerSourceAvailableSources.
  ///
  /// In en, this message translates to:
  /// **'Available Sources'**
  String get playerSourceAvailableSources;

  /// No description provided for @playerSourceSortSeedersHigh.
  ///
  /// In en, this message translates to:
  /// **'Seeders (High to Low)'**
  String get playerSourceSortSeedersHigh;

  /// No description provided for @playerSourceSortSeedersLow.
  ///
  /// In en, this message translates to:
  /// **'Seeders (Low to High)'**
  String get playerSourceSortSeedersLow;

  /// No description provided for @playerSourceSortQualityHigh.
  ///
  /// In en, this message translates to:
  /// **'Quality (High to Low)'**
  String get playerSourceSortQualityHigh;

  /// No description provided for @playerSourceSortQualityLow.
  ///
  /// In en, this message translates to:
  /// **'Quality (Low to High)'**
  String get playerSourceSortQualityLow;

  /// No description provided for @playerSourceSortSizeHigh.
  ///
  /// In en, this message translates to:
  /// **'Size (High to Low)'**
  String get playerSourceSortSizeHigh;

  /// No description provided for @playerSourceSortSizeLow.
  ///
  /// In en, this message translates to:
  /// **'Size (Low to High)'**
  String get playerSourceSortSizeLow;

  /// No description provided for @playerSourceStoppedActiveDownload.
  ///
  /// In en, this message translates to:
  /// **'Stopped active download'**
  String get playerSourceStoppedActiveDownload;

  /// No description provided for @playerSourceDownloadsCleared.
  ///
  /// In en, this message translates to:
  /// **'Downloads cleared'**
  String get playerSourceDownloadsCleared;

  /// No description provided for @playerSourceStopClearFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not stop or clear torrent downloads'**
  String get playerSourceStopClearFailed;

  /// No description provided for @playerSourceStopAndClear.
  ///
  /// In en, this message translates to:
  /// **'Stop & clear'**
  String get playerSourceStopAndClear;

  /// No description provided for @playerSourceSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get playerSourceSearchHint;

  /// No description provided for @playerSourceFiltersTitle.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get playerSourceFiltersTitle;

  /// No description provided for @playerSourceFilterCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get playerSourceFilterCategory;

  /// No description provided for @playerSourceFilterSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get playerSourceFilterSort;

  /// No description provided for @playerSourceFilterQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get playerSourceFilterQuality;

  /// No description provided for @playerSourceFilterSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get playerSourceFilterSize;

  /// No description provided for @playerSourceFilterLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get playerSourceFilterLanguage;

  /// No description provided for @playerSourceFilterTech.
  ///
  /// In en, this message translates to:
  /// **'Tech'**
  String get playerSourceFilterTech;

  /// No description provided for @playerSourceFilterOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get playerSourceFilterOnline;

  /// No description provided for @playerSourcePlaying.
  ///
  /// In en, this message translates to:
  /// **'Playing'**
  String get playerSourcePlaying;

  /// No description provided for @playerSourceCheckingSize.
  ///
  /// In en, this message translates to:
  /// **'Checking size…'**
  String get playerSourceCheckingSize;

  /// No description provided for @playerSourceSizeUnknown.
  ///
  /// In en, this message translates to:
  /// **'Size unknown'**
  String get playerSourceSizeUnknown;

  /// No description provided for @playerSourceNotEnoughSpace.
  ///
  /// In en, this message translates to:
  /// **'Not enough free space'**
  String get playerSourceNotEnoughSpace;

  /// No description provided for @playerSourceDownloadHeading.
  ///
  /// In en, this message translates to:
  /// **'DOWNLOAD'**
  String get playerSourceDownloadHeading;

  /// No description provided for @playerSourceDownloadOfflineHeading.
  ///
  /// In en, this message translates to:
  /// **'DOWNLOAD OFFLINE?'**
  String get playerSourceDownloadOfflineHeading;

  /// No description provided for @playerSourceDownloadTooltip.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get playerSourceDownloadTooltip;

  /// No description provided for @playerSourcePlayOnline.
  ///
  /// In en, this message translates to:
  /// **'Play online'**
  String get playerSourcePlayOnline;

  /// No description provided for @playerSourceCopyMagnet.
  ///
  /// In en, this message translates to:
  /// **'Copy magnet'**
  String get playerSourceCopyMagnet;

  /// No description provided for @playerSourceMagnetCopied.
  ///
  /// In en, this message translates to:
  /// **'Magnet copied'**
  String get playerSourceMagnetCopied;

  /// No description provided for @playerSourceSourcesTitle.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get playerSourceSourcesTitle;

  /// No description provided for @playerSourceDownloadedChip.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get playerSourceDownloadedChip;

  /// No description provided for @playerTrailerLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load this trailer'**
  String get playerTrailerLoadFailed;

  /// No description provided for @playerTrailerOpenInYouTube.
  ///
  /// In en, this message translates to:
  /// **'Open in YouTube'**
  String get playerTrailerOpenInYouTube;

  /// No description provided for @playerTrailerBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get playerTrailerBack;

  /// No description provided for @playerTrailerMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get playerTrailerMute;

  /// No description provided for @playerTrailerReplay.
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get playerTrailerReplay;

  /// No description provided for @playerTrailerPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get playerTrailerPause;

  /// No description provided for @playerTrailerPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playerTrailerPlay;

  /// No description provided for @playerTrailerBack10.
  ///
  /// In en, this message translates to:
  /// **'Back 10s'**
  String get playerTrailerBack10;

  /// No description provided for @playerTrailerForward10.
  ///
  /// In en, this message translates to:
  /// **'Forward 10s'**
  String get playerTrailerForward10;

  /// No description provided for @playerTrailerSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get playerTrailerSubtitles;

  /// No description provided for @playerTrailerQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get playerTrailerQuality;

  /// No description provided for @playerTrailerPlaybackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get playerTrailerPlaybackSpeed;

  /// No description provided for @playerTrailerFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen'**
  String get playerTrailerFullscreen;

  /// No description provided for @playerTrailerLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get playerTrailerLoading;

  /// No description provided for @playerTrailerNextIn.
  ///
  /// In en, this message translates to:
  /// **'Next trailer · {seconds}s'**
  String playerTrailerNextIn(int seconds);

  /// No description provided for @playerTrailerUpNext.
  ///
  /// In en, this message translates to:
  /// **'Up next'**
  String get playerTrailerUpNext;

  /// No description provided for @playerTrailerSubtitlesOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get playerTrailerSubtitlesOff;

  /// No description provided for @playerTrailerNoSubtitles.
  ///
  /// In en, this message translates to:
  /// **'No subtitles available for this trailer.'**
  String get playerTrailerNoSubtitles;

  /// No description provided for @playerTrailerCaptionAuto.
  ///
  /// In en, this message translates to:
  /// **'{name} (auto)'**
  String playerTrailerCaptionAuto(String name);

  /// No description provided for @playerTrailerNoQuality.
  ///
  /// In en, this message translates to:
  /// **'No quality options for this trailer.'**
  String get playerTrailerNoQuality;

  /// No description provided for @playerTrailerPlayerMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get playerTrailerPlayerMenuTitle;

  /// No description provided for @playerTrailerBuiltIn.
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get playerTrailerBuiltIn;

  /// No description provided for @playerTrailerForjaTrailer.
  ///
  /// In en, this message translates to:
  /// **'Forja trailer'**
  String get playerTrailerForjaTrailer;

  /// No description provided for @playerTrailerExternalApp.
  ///
  /// In en, this message translates to:
  /// **'External app'**
  String get playerTrailerExternalApp;

  /// No description provided for @playerTrailerOpenYouTubeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open YouTube'**
  String get playerTrailerOpenYouTubeFailed;

  /// No description provided for @playerLiveStreamEnded.
  ///
  /// In en, this message translates to:
  /// **'Stream ended'**
  String get playerLiveStreamEnded;

  /// No description provided for @playerLiveReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get playerLiveReconnecting;

  /// No description provided for @playerLivePreparingPlayback.
  ///
  /// In en, this message translates to:
  /// **'Preparing playback…'**
  String get playerLivePreparingPlayback;

  /// No description provided for @playerLiveRefreshingStream.
  ///
  /// In en, this message translates to:
  /// **'Refreshing stream…'**
  String get playerLiveRefreshingStream;

  /// No description provided for @playerLiveUnlockingSource.
  ///
  /// In en, this message translates to:
  /// **'Unlocking source…'**
  String get playerLiveUnlockingSource;

  /// No description provided for @playerLiveStreamOffline.
  ///
  /// In en, this message translates to:
  /// **'Stream offline'**
  String get playerLiveStreamOffline;

  /// No description provided for @playerLivePlaybackFailed.
  ///
  /// In en, this message translates to:
  /// **'Playback failed'**
  String get playerLivePlaybackFailed;

  /// No description provided for @playerLiveSwitchingPlayer.
  ///
  /// In en, this message translates to:
  /// **'Switching player…'**
  String get playerLiveSwitchingPlayer;

  /// No description provided for @playerLiveSwitchingSoftwareDecode.
  ///
  /// In en, this message translates to:
  /// **'Switching to software decode…'**
  String get playerLiveSwitchingSoftwareDecode;

  /// No description provided for @playerLiveBuffering.
  ///
  /// In en, this message translates to:
  /// **'Buffering…'**
  String get playerLiveBuffering;

  /// No description provided for @playerLiveSwitchingTo.
  ///
  /// In en, this message translates to:
  /// **'Switching to {name}…'**
  String playerLiveSwitchingTo(String name);

  /// No description provided for @playerLiveTrying.
  ///
  /// In en, this message translates to:
  /// **'Trying {name}…'**
  String playerLiveTrying(String name);

  /// No description provided for @playerLiveOfflineRetrying.
  ///
  /// In en, this message translates to:
  /// **'Stream offline - retrying every {seconds}s…'**
  String playerLiveOfflineRetrying(int seconds);

  /// No description provided for @playerLiveReconnectingAttempt.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting… (attempt {attempt}/{max})'**
  String playerLiveReconnectingAttempt(int attempt, int max);

  /// No description provided for @playerLiveSubtitleFailed.
  ///
  /// In en, this message translates to:
  /// **'Subtitle failed'**
  String get playerLiveSubtitleFailed;

  /// No description provided for @playerLiveSearchSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Search subtitles'**
  String get playerLiveSearchSubtitles;

  /// No description provided for @playerLiveFilmOrSeriesName.
  ///
  /// In en, this message translates to:
  /// **'Film or series name'**
  String get playerLiveFilmOrSeriesName;

  /// No description provided for @playerLiveYearOptional.
  ///
  /// In en, this message translates to:
  /// **'Year (optional)'**
  String get playerLiveYearOptional;

  /// No description provided for @playerLiveSeasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Season'**
  String get playerLiveSeasonLabel;

  /// No description provided for @playerLiveEpisodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Episode'**
  String get playerLiveEpisodeLabel;

  /// No description provided for @playerLiveExternalPlayerNotFound.
  ///
  /// In en, this message translates to:
  /// **'{player} not found.'**
  String playerLiveExternalPlayerNotFound(String player);

  /// No description provided for @playerLiveStreamStats.
  ///
  /// In en, this message translates to:
  /// **'Stream stats'**
  String get playerLiveStreamStats;

  /// No description provided for @playerLiveInAppMiniPlayer.
  ///
  /// In en, this message translates to:
  /// **'In-app mini player'**
  String get playerLiveInAppMiniPlayer;

  /// No description provided for @playerLivePictureInPicture.
  ///
  /// In en, this message translates to:
  /// **'Picture in Picture'**
  String get playerLivePictureInPicture;

  /// No description provided for @playerLiveBadge.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get playerLiveBadge;

  /// No description provided for @playerLiveEpisodeFallback.
  ///
  /// In en, this message translates to:
  /// **'Episode {number}'**
  String playerLiveEpisodeFallback(int number);

  /// No description provided for @playerLiveSeasonTitle.
  ///
  /// In en, this message translates to:
  /// **'Season {number}'**
  String playerLiveSeasonTitle(int number);

  /// No description provided for @playerLiveShowSeasonTitle.
  ///
  /// In en, this message translates to:
  /// **'{show} · Season {number}'**
  String playerLiveShowSeasonTitle(String show, int number);

  /// No description provided for @playerLiveSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get playerLiveSourceTitle;

  /// No description provided for @playerLiveVlcNotFound.
  ///
  /// In en, this message translates to:
  /// **'VLC not found. Install VLC or use MediaKit.'**
  String get playerLiveVlcNotFound;

  /// No description provided for @playerLiveStatsStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get playerLiveStatsStatus;

  /// No description provided for @playerLiveStatsBuffering.
  ///
  /// In en, this message translates to:
  /// **'Buffering'**
  String get playerLiveStatsBuffering;

  /// No description provided for @playerLiveStatsPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get playerLiveStatsPaused;

  /// No description provided for @playerLiveStatsEngine.
  ///
  /// In en, this message translates to:
  /// **'Engine'**
  String get playerLiveStatsEngine;

  /// No description provided for @playerLiveStatsRecoveries.
  ///
  /// In en, this message translates to:
  /// **'Recoveries'**
  String get playerLiveStatsRecoveries;

  /// No description provided for @playerLiveStatsResolution.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get playerLiveStatsResolution;

  /// No description provided for @playerLiveStatsVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get playerLiveStatsVideo;

  /// No description provided for @playerLiveStatsVideoBitrate.
  ///
  /// In en, this message translates to:
  /// **'Video bitrate'**
  String get playerLiveStatsVideoBitrate;

  /// No description provided for @playerLiveStatsDisplayFps.
  ///
  /// In en, this message translates to:
  /// **'Display FPS'**
  String get playerLiveStatsDisplayFps;

  /// No description provided for @playerLiveStatsAudioTrack.
  ///
  /// In en, this message translates to:
  /// **'Audio track'**
  String get playerLiveStatsAudioTrack;

  /// No description provided for @playerLiveStatsAudioBitrate.
  ///
  /// In en, this message translates to:
  /// **'Audio bitrate'**
  String get playerLiveStatsAudioBitrate;

  /// No description provided for @playerLiveStatsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Subtitle'**
  String get playerLiveStatsSubtitle;

  /// No description provided for @playerLiveStatsOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get playerLiveStatsOff;

  /// No description provided for @playerLiveStatsCache.
  ///
  /// In en, this message translates to:
  /// **'Cache'**
  String get playerLiveStatsCache;

  /// No description provided for @playerLiveStatsCacheUsed.
  ///
  /// In en, this message translates to:
  /// **'Cache used'**
  String get playerLiveStatsCacheUsed;

  /// No description provided for @playerLiveStatsBufferedAhead.
  ///
  /// In en, this message translates to:
  /// **'Buffered ahead'**
  String get playerLiveStatsBufferedAhead;

  /// No description provided for @playerLiveStatsVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get playerLiveStatsVolume;

  /// No description provided for @playerLiveStatsSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get playerLiveStatsSpeed;

  /// No description provided for @playerLiveStatsDroppedFrames.
  ///
  /// In en, this message translates to:
  /// **'Dropped frames'**
  String get playerLiveStatsDroppedFrames;

  /// No description provided for @playerLiveStatsDecoderDrops.
  ///
  /// In en, this message translates to:
  /// **'Decoder drops'**
  String get playerLiveStatsDecoderDrops;

  /// No description provided for @playerLiveStatsVideoTrack.
  ///
  /// In en, this message translates to:
  /// **'Video track'**
  String get playerLiveStatsVideoTrack;

  /// No description provided for @playerLiveStatsRetries.
  ///
  /// In en, this message translates to:
  /// **'Retries'**
  String get playerLiveStatsRetries;

  /// No description provided for @playerLiveStatsYes.
  ///
  /// In en, this message translates to:
  /// **'yes'**
  String get playerLiveStatsYes;

  /// No description provided for @playerLiveStatsNo.
  ///
  /// In en, this message translates to:
  /// **'no'**
  String get playerLiveStatsNo;

  /// No description provided for @playerLivePlayingOnAirPlay.
  ///
  /// In en, this message translates to:
  /// **'Playing on AirPlay'**
  String get playerLivePlayingOnAirPlay;

  /// No description provided for @playerLiveCast.
  ///
  /// In en, this message translates to:
  /// **'Cast'**
  String get playerLiveCast;

  /// No description provided for @engineModelsHubs.
  ///
  /// In en, this message translates to:
  /// **'Hubs'**
  String get engineModelsHubs;

  /// No description provided for @engineModelsLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get engineModelsLive;

  /// No description provided for @engineModelsMovie.
  ///
  /// In en, this message translates to:
  /// **'Movie'**
  String get engineModelsMovie;

  /// No description provided for @engineModelsMovieAndTv.
  ///
  /// In en, this message translates to:
  /// **'Movie & TV'**
  String get engineModelsMovieAndTv;

  /// No description provided for @engineModelsPlugins.
  ///
  /// In en, this message translates to:
  /// **'Plugins'**
  String get engineModelsPlugins;

  /// No description provided for @engineModelsLanguageItalian.
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get engineModelsLanguageItalian;

  /// No description provided for @engineModelsLanguageGerman.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get engineModelsLanguageGerman;

  /// No description provided for @engineModelsLanguagePortuguese.
  ///
  /// In en, this message translates to:
  /// **'Portuguese'**
  String get engineModelsLanguagePortuguese;

  /// No description provided for @engineModelsLanguageArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get engineModelsLanguageArabic;

  /// No description provided for @engineModelsLanguageHindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get engineModelsLanguageHindi;

  /// No description provided for @engineModelsLanguageTurkish.
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get engineModelsLanguageTurkish;

  /// No description provided for @engineModelsLanguageJapanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get engineModelsLanguageJapanese;

  /// No description provided for @engineModelsLanguageKorean.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get engineModelsLanguageKorean;

  /// No description provided for @engineModelsLanguageChinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get engineModelsLanguageChinese;

  /// No description provided for @engineModelsLanguageDutch.
  ///
  /// In en, this message translates to:
  /// **'Dutch'**
  String get engineModelsLanguageDutch;

  /// No description provided for @engineModelsLanguagePolish.
  ///
  /// In en, this message translates to:
  /// **'Polish'**
  String get engineModelsLanguagePolish;

  /// No description provided for @engineModelsLanguageRussian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get engineModelsLanguageRussian;

  /// No description provided for @engineRuntimeActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Action failed'**
  String get engineRuntimeActionFailed;

  /// No description provided for @engineRuntimeAddToMyList.
  ///
  /// In en, this message translates to:
  /// **'Add to My List'**
  String get engineRuntimeAddToMyList;

  /// No description provided for @engineRuntimeAddedToMyList.
  ///
  /// In en, this message translates to:
  /// **'Added to My List'**
  String get engineRuntimeAddedToMyList;

  /// No description provided for @engineRuntimeAllKind.
  ///
  /// In en, this message translates to:
  /// **'All {kind}'**
  String engineRuntimeAllKind(String kind);

  /// No description provided for @engineRuntimeCast.
  ///
  /// In en, this message translates to:
  /// **'Cast'**
  String get engineRuntimeCast;

  /// No description provided for @engineRuntimeClearKind.
  ///
  /// In en, this message translates to:
  /// **'Clear {kind}'**
  String engineRuntimeClearKind(String kind);

  /// No description provided for @engineRuntimeContinueWatching.
  ///
  /// In en, this message translates to:
  /// **'Continue Watching'**
  String get engineRuntimeContinueWatching;

  /// No description provided for @engineRuntimeCreditsShort.
  ///
  /// In en, this message translates to:
  /// **'{credits} cr'**
  String engineRuntimeCreditsShort(int credits);

  /// No description provided for @engineRuntimeDealDisabled.
  ///
  /// In en, this message translates to:
  /// **'Deal is not enabled on this account'**
  String get engineRuntimeDealDisabled;

  /// Toast after the Deal action hands out portals (Deal is a feature name).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Dealt 1 portal} other{Dealt {count} portals}}'**
  String engineRuntimeDealDone(int count);

  /// No description provided for @engineRuntimeDealNone.
  ///
  /// In en, this message translates to:
  /// **'No portals dealt — pool may be empty'**
  String get engineRuntimeDealNone;

  /// No description provided for @engineRuntimeDealRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Dealt 1 portal but the list could not refresh — reopen Portals} other{Dealt {count} portals but the list could not refresh — reopen Portals}}'**
  String engineRuntimeDealRefreshFailed(int count);

  /// No description provided for @engineRuntimeDealSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in and pick a profile to Deal'**
  String get engineRuntimeDealSignIn;

  /// No description provided for @engineRuntimeDealTooltipCredits.
  ///
  /// In en, this message translates to:
  /// **'{label} ({credits} credits)'**
  String engineRuntimeDealTooltipCredits(String label, int credits);

  /// No description provided for @engineRuntimeDealTooltipNoCredits.
  ///
  /// In en, this message translates to:
  /// **'{label} (no credits)'**
  String engineRuntimeDealTooltipNoCredits(String label);

  /// No description provided for @engineRuntimeDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get engineRuntimeDetails;

  /// No description provided for @engineRuntimeFetchingCatalog.
  ///
  /// In en, this message translates to:
  /// **'Fetching catalog…'**
  String get engineRuntimeFetchingCatalog;

  /// No description provided for @engineRuntimeFilms.
  ///
  /// In en, this message translates to:
  /// **'Films'**
  String get engineRuntimeFilms;

  /// No description provided for @engineRuntimeFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get engineRuntimeFilters;

  /// No description provided for @engineRuntimeHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get engineRuntimeHome;

  /// No description provided for @engineRuntimeHubLayoutInvalid.
  ///
  /// In en, this message translates to:
  /// **'This hub’s layout is invalid.'**
  String get engineRuntimeHubLayoutInvalid;

  /// No description provided for @engineRuntimeHubLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load this hub. Try again.'**
  String get engineRuntimeHubLoadFailed;

  /// No description provided for @engineRuntimeHubPluginOff.
  ///
  /// In en, this message translates to:
  /// **'This hub plugin is off. Enable it under Settings → Sources → Forja (Hubs).'**
  String get engineRuntimeHubPluginOff;

  /// No description provided for @engineRuntimeListEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your list is empty'**
  String get engineRuntimeListEmpty;

  /// No description provided for @engineRuntimeLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get engineRuntimeLoading;

  /// No description provided for @engineRuntimeMyList.
  ///
  /// In en, this message translates to:
  /// **'My List'**
  String get engineRuntimeMyList;

  /// No description provided for @engineRuntimeNoChannelsInView.
  ///
  /// In en, this message translates to:
  /// **'No channels in this view'**
  String get engineRuntimeNoChannelsInView;

  /// No description provided for @engineRuntimeNoFavorites.
  ///
  /// In en, this message translates to:
  /// **'No favorites'**
  String get engineRuntimeNoFavorites;

  /// No description provided for @engineRuntimeNoFavoritesHint.
  ///
  /// In en, this message translates to:
  /// **'Star a live channel to keep it here.'**
  String get engineRuntimeNoFavoritesHint;

  /// No description provided for @engineRuntimeNoHubPack.
  ///
  /// In en, this message translates to:
  /// **'No hub pack for this tab.'**
  String get engineRuntimeNoHubPack;

  /// No description provided for @engineRuntimeNoPlayableStream.
  ///
  /// In en, this message translates to:
  /// **'No playable stream'**
  String get engineRuntimeNoPlayableStream;

  /// No description provided for @engineRuntimeNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get engineRuntimeNoResults;

  /// No description provided for @engineRuntimeNothingHere.
  ///
  /// In en, this message translates to:
  /// **'Nothing here'**
  String get engineRuntimeNothingHere;

  /// No description provided for @engineRuntimeNothingHereYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet.'**
  String get engineRuntimeNothingHereYet;

  /// No description provided for @engineRuntimeNothingWatched.
  ///
  /// In en, this message translates to:
  /// **'Nothing watched yet'**
  String get engineRuntimeNothingWatched;

  /// No description provided for @engineRuntimeNothingWatchedHint.
  ///
  /// In en, this message translates to:
  /// **'Channels you play on Live land here (last 30).'**
  String get engineRuntimeNothingWatchedHint;

  /// No description provided for @engineRuntimeOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get engineRuntimeOpen;

  /// No description provided for @engineRuntimeOptions.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get engineRuntimeOptions;

  /// No description provided for @engineRuntimePlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get engineRuntimePlay;

  /// No description provided for @engineRuntimePortalNotFound.
  ///
  /// In en, this message translates to:
  /// **'Portal not found'**
  String get engineRuntimePortalNotFound;

  /// No description provided for @engineRuntimePortalSelectFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not select portal'**
  String get engineRuntimePortalSelectFailed;

  /// No description provided for @engineRuntimePortals.
  ///
  /// In en, this message translates to:
  /// **'Portals'**
  String get engineRuntimePortals;

  /// No description provided for @engineRuntimePortalsNoPack.
  ///
  /// In en, this message translates to:
  /// **'No portals pack installed'**
  String get engineRuntimePortalsNoPack;

  /// No description provided for @engineRuntimePortalsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Portals unavailable'**
  String get engineRuntimePortalsUnavailable;

  /// No description provided for @engineRuntimeRecommendations.
  ///
  /// In en, this message translates to:
  /// **'Recommendations'**
  String get engineRuntimeRecommendations;

  /// No description provided for @engineRuntimeRemoveFromMyList.
  ///
  /// In en, this message translates to:
  /// **'Remove from My List'**
  String get engineRuntimeRemoveFromMyList;

  /// No description provided for @engineRuntimeRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get engineRuntimeRemoved;

  /// No description provided for @engineRuntimeRemovedFromMyList.
  ///
  /// In en, this message translates to:
  /// **'Removed from My List'**
  String get engineRuntimeRemovedFromMyList;

  /// No description provided for @engineRuntimeRemovedLocallySimklFailed.
  ///
  /// In en, this message translates to:
  /// **'Removed locally · Simkl failed'**
  String get engineRuntimeRemovedLocallySimklFailed;

  /// No description provided for @engineRuntimeResumeFailed.
  ///
  /// In en, this message translates to:
  /// **'Resume failed: {error}'**
  String engineRuntimeResumeFailed(String error);

  /// No description provided for @engineRuntimeSavedLocallySimklFailed.
  ///
  /// In en, this message translates to:
  /// **'Saved locally · Simkl failed'**
  String get engineRuntimeSavedLocallySimklFailed;

  /// No description provided for @engineRuntimeSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get engineRuntimeSchedule;

  /// No description provided for @engineRuntimeScheduleAiring.
  ///
  /// In en, this message translates to:
  /// **'Airing'**
  String get engineRuntimeScheduleAiring;

  /// No description provided for @engineRuntimeScheduleAiringHint.
  ///
  /// In en, this message translates to:
  /// **'In-play and 24/7 — including rows without streams yet'**
  String get engineRuntimeScheduleAiringHint;

  /// No description provided for @engineRuntimeScheduleAiringUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Airing + upcoming'**
  String get engineRuntimeScheduleAiringUpcoming;

  /// No description provided for @engineRuntimeScheduleBothHint.
  ///
  /// In en, this message translates to:
  /// **'Airing + 24/7, plus upcoming within the horizon'**
  String get engineRuntimeScheduleBothHint;

  /// No description provided for @engineRuntimeScheduleHorizon.
  ///
  /// In en, this message translates to:
  /// **'Horizon'**
  String get engineRuntimeScheduleHorizon;

  /// No description provided for @engineRuntimeScheduleHorizonHint.
  ///
  /// In en, this message translates to:
  /// **'Upcoming kickoffs in the next {hours}h'**
  String engineRuntimeScheduleHorizonHint(int hours);

  /// No description provided for @engineRuntimeScheduleIntro.
  ///
  /// In en, this message translates to:
  /// **'What to show, and how far ahead to load upcoming:'**
  String get engineRuntimeScheduleIntro;

  /// No description provided for @engineRuntimeScheduleNext.
  ///
  /// In en, this message translates to:
  /// **'Next · {horizon}'**
  String engineRuntimeScheduleNext(String horizon);

  /// No description provided for @engineRuntimeScheduleStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get engineRuntimeScheduleStatus;

  /// No description provided for @engineRuntimeScheduleUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get engineRuntimeScheduleUpcoming;

  /// No description provided for @engineRuntimeScheduleUpcomingHint.
  ///
  /// In en, this message translates to:
  /// **'Not started yet, within the horizon below'**
  String get engineRuntimeScheduleUpcomingHint;

  /// No description provided for @engineRuntimeSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed'**
  String get engineRuntimeSearchFailed;

  /// No description provided for @engineRuntimeSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search…'**
  String get engineRuntimeSearchHint;

  /// No description provided for @engineRuntimeSearchHintEnter.
  ///
  /// In en, this message translates to:
  /// **'Press Enter to search'**
  String get engineRuntimeSearchHintEnter;

  /// No description provided for @engineRuntimeSearchHintFilters.
  ///
  /// In en, this message translates to:
  /// **'Set filters, then tap Search'**
  String get engineRuntimeSearchHintFilters;

  /// No description provided for @engineRuntimeSearchHintOk.
  ///
  /// In en, this message translates to:
  /// **'Press OK to search'**
  String get engineRuntimeSearchHintOk;

  /// No description provided for @engineRuntimeSearchPrompt.
  ///
  /// In en, this message translates to:
  /// **'Search for your favorite content'**
  String get engineRuntimeSearchPrompt;

  /// No description provided for @engineRuntimeSectionLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load this section.'**
  String get engineRuntimeSectionLoadFailed;

  /// No description provided for @engineRuntimeSeries.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get engineRuntimeSeries;

  /// No description provided for @engineRuntimeShareCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Share code copied'**
  String get engineRuntimeShareCodeCopied;

  /// No description provided for @engineRuntimeShareCodeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create share code'**
  String get engineRuntimeShareCodeFailed;

  /// No description provided for @engineRuntimeSimklSavedAs.
  ///
  /// In en, this message translates to:
  /// **'Simkl saved as {saved} (not {requested})'**
  String engineRuntimeSimklSavedAs(String saved, String requested);

  /// No description provided for @engineRuntimeSimklStillAiring.
  ///
  /// In en, this message translates to:
  /// **'Still airing on Simkl · kept as {status}'**
  String engineRuntimeSimklStillAiring(String status);

  /// No description provided for @engineRuntimeSomethingWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get engineRuntimeSomethingWrong;

  /// No description provided for @engineRuntimeSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get engineRuntimeSort;

  /// No description provided for @engineRuntimeSortCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get engineRuntimeSortCategories;

  /// No description provided for @engineRuntimeSortChannels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get engineRuntimeSortChannels;

  /// No description provided for @engineRuntimeSortNameAsc.
  ///
  /// In en, this message translates to:
  /// **'Name (A–Z)'**
  String get engineRuntimeSortNameAsc;

  /// No description provided for @engineRuntimeSortNameDesc.
  ///
  /// In en, this message translates to:
  /// **'Name (Z–A)'**
  String get engineRuntimeSortNameDesc;

  /// No description provided for @engineRuntimeSortPlaylistOrder.
  ///
  /// In en, this message translates to:
  /// **'Playlist Order'**
  String get engineRuntimeSortPlaylistOrder;

  /// Fallback title for a stream that has no name.
  ///
  /// In en, this message translates to:
  /// **'Stream'**
  String get engineRuntimeStream;

  /// No description provided for @engineRuntimeTrailers.
  ///
  /// In en, this message translates to:
  /// **'Trailers'**
  String get engineRuntimeTrailers;

  /// No description provided for @engineRuntimeUpdating.
  ///
  /// In en, this message translates to:
  /// **'Updating'**
  String get engineRuntimeUpdating;

  /// No description provided for @engineRuntimeViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get engineRuntimeViewDetails;

  /// No description provided for @enginePacksUpdatedToast.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 plugin pack updated} other{{count} plugin packs updated}}'**
  String enginePacksUpdatedToast(int count);

  /// No description provided for @enginePacksUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Update plugin pack?} other{Update {count} plugin packs?}}'**
  String enginePacksUpdateTitle(int count);

  /// No description provided for @enginePacksUpdateBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Download and install the newer version of this pack.} other{Download and install newer versions of these packs.}}'**
  String enginePacksUpdateBody(int count);

  /// No description provided for @enginePacksUpdateButton.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get enginePacksUpdateButton;

  /// No description provided for @enginePacksKindProviders.
  ///
  /// In en, this message translates to:
  /// **'Providers'**
  String get enginePacksKindProviders;

  /// No description provided for @enginePacksKindLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get enginePacksKindLive;

  /// No description provided for @enginePacksKindTorrent.
  ///
  /// In en, this message translates to:
  /// **'Torrent'**
  String get enginePacksKindTorrent;

  /// No description provided for @enginePacksKindHubs.
  ///
  /// In en, this message translates to:
  /// **'Hubs'**
  String get enginePacksKindHubs;

  /// No description provided for @enginePortalsShareCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Share code invalid'**
  String get enginePortalsShareCodeInvalid;

  /// No description provided for @enginePortalsShareCodeNotFound.
  ///
  /// In en, this message translates to:
  /// **'Share code not found or invalid'**
  String get enginePortalsShareCodeNotFound;

  /// No description provided for @enginePortalsShareUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Share service temporarily unavailable. Try again later.'**
  String get enginePortalsShareUnavailable;

  /// No description provided for @enginePortalsShareLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load share code'**
  String get enginePortalsShareLoadFailed;

  /// No description provided for @enginePortalsErrM3uNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Portal name required for M3U playlists'**
  String get enginePortalsErrM3uNameRequired;

  /// No description provided for @enginePortalsErrUrlRequired.
  ///
  /// In en, this message translates to:
  /// **'URL required'**
  String get enginePortalsErrUrlRequired;

  /// No description provided for @enginePortalsErrXtreamRequired.
  ///
  /// In en, this message translates to:
  /// **'URL, username, and password required'**
  String get enginePortalsErrXtreamRequired;

  /// No description provided for @enginePortalsErrMacRequired.
  ///
  /// In en, this message translates to:
  /// **'MAC (username) required'**
  String get enginePortalsErrMacRequired;

  /// No description provided for @enginePortalsActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Action failed'**
  String get enginePortalsActionFailed;

  /// No description provided for @enginePortalsDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Portal'**
  String get enginePortalsDefaultName;

  /// No description provided for @enginePortalsAdded.
  ///
  /// In en, this message translates to:
  /// **'Portal added'**
  String get enginePortalsAdded;

  /// No description provided for @enginePortalsSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get enginePortalsSaving;

  /// No description provided for @enginePortalsAdding.
  ///
  /// In en, this message translates to:
  /// **'Adding portal…'**
  String get enginePortalsAdding;

  /// No description provided for @enginePortalsEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Portal'**
  String get enginePortalsEditTitle;

  /// No description provided for @enginePortalsAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Portal'**
  String get enginePortalsAddTitle;

  /// No description provided for @enginePortalsNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Portal name'**
  String get enginePortalsNameLabel;

  /// No description provided for @enginePortalsNameHint.
  ///
  /// In en, this message translates to:
  /// **'My provider'**
  String get enginePortalsNameHint;

  /// No description provided for @enginePortalsNameRandom.
  ///
  /// In en, this message translates to:
  /// **'Random name'**
  String get enginePortalsNameRandom;

  /// No description provided for @enginePortalsAddAction.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get enginePortalsAddAction;

  /// No description provided for @enginePortalsShareCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Share code'**
  String get enginePortalsShareCodeTitle;

  /// No description provided for @enginePortalsNameRequiredLabel.
  ///
  /// In en, this message translates to:
  /// **'Portal name (required)'**
  String get enginePortalsNameRequiredLabel;

  /// No description provided for @enginePortalsPlaylistUrl.
  ///
  /// In en, this message translates to:
  /// **'Playlist URL'**
  String get enginePortalsPlaylistUrl;

  /// No description provided for @enginePortalsChooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose local file'**
  String get enginePortalsChooseFile;

  /// No description provided for @enginePortalsMacLabel.
  ///
  /// In en, this message translates to:
  /// **'MAC address'**
  String get enginePortalsMacLabel;

  /// No description provided for @enginePortalsUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get enginePortalsUsernameLabel;

  /// No description provided for @enginePortalsUsernameHint.
  ///
  /// In en, this message translates to:
  /// **'username'**
  String get enginePortalsUsernameHint;

  /// No description provided for @enginePortalsGenerateMac.
  ///
  /// In en, this message translates to:
  /// **'Generate MAC'**
  String get enginePortalsGenerateMac;

  /// No description provided for @enginePortalsSerialLabel.
  ///
  /// In en, this message translates to:
  /// **'Serial (optional)'**
  String get enginePortalsSerialLabel;

  /// No description provided for @enginePortalsSerialHint.
  ///
  /// In en, this message translates to:
  /// **'device serial'**
  String get enginePortalsSerialHint;

  /// No description provided for @enginePortalsPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'password'**
  String get enginePortalsPasswordHint;

  /// No description provided for @enginePortalsShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get enginePortalsShowPassword;

  /// No description provided for @enginePortalsHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get enginePortalsHidePassword;

  /// No description provided for @enginePortalsUserAgentLabel.
  ///
  /// In en, this message translates to:
  /// **'User-Agent (optional)'**
  String get enginePortalsUserAgentLabel;

  /// No description provided for @enginePortalsHideManual.
  ///
  /// In en, this message translates to:
  /// **'Hide manual entry'**
  String get enginePortalsHideManual;

  /// No description provided for @enginePortalsEnterUrlManually.
  ///
  /// In en, this message translates to:
  /// **'Enter URL manually'**
  String get enginePortalsEnterUrlManually;

  /// No description provided for @enginePortalsLoadingShareCode.
  ///
  /// In en, this message translates to:
  /// **'Loading share code…'**
  String get enginePortalsLoadingShareCode;

  /// No description provided for @engineDetailsFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get engineDetailsFallbackTitle;

  /// No description provided for @engineDetailsMatchLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get engineDetailsMatchLive;

  /// No description provided for @engineDetailsMatchViewers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 viewer} other{{count} viewers}}'**
  String engineDetailsMatchViewers(int count);

  /// No description provided for @engineDetailsMatchingLiveTv.
  ///
  /// In en, this message translates to:
  /// **'Matching Live TV…'**
  String get engineDetailsMatchingLiveTv;

  /// No description provided for @engineDetailsFetchingStreams.
  ///
  /// In en, this message translates to:
  /// **'Fetching streams…'**
  String get engineDetailsFetchingStreams;

  /// No description provided for @engineDetailsPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get engineDetailsPlay;

  /// No description provided for @engineDetailsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get engineDetailsLoading;

  /// No description provided for @engineDetailsClearTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear progress & stream cache'**
  String get engineDetailsClearTooltip;

  /// No description provided for @engineDetailsTrailer.
  ///
  /// In en, this message translates to:
  /// **'Trailer'**
  String get engineDetailsTrailer;

  /// No description provided for @engineDetailsMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get engineDetailsMore;

  /// No description provided for @engineDetailsSimklRating.
  ///
  /// In en, this message translates to:
  /// **'Simkl rating: {rating}'**
  String engineDetailsSimklRating(int rating);

  /// No description provided for @engineDetailsRateOnSimkl.
  ///
  /// In en, this message translates to:
  /// **'Rate on Simkl'**
  String get engineDetailsRateOnSimkl;

  /// No description provided for @engineDetailsSimklLoginFirst.
  ///
  /// In en, this message translates to:
  /// **'Login to Simkl first in Settings'**
  String get engineDetailsSimklLoginFirst;

  /// No description provided for @engineDetailsRate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get engineDetailsRate;

  /// No description provided for @engineDetailsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load details. Try again.'**
  String get engineDetailsLoadFailed;

  /// No description provided for @engineDetailsNoSavedFile.
  ///
  /// In en, this message translates to:
  /// **'No saved file'**
  String get engineDetailsNoSavedFile;

  /// No description provided for @engineDetailsResumeEpisode.
  ///
  /// In en, this message translates to:
  /// **'Resume Ep {episode}'**
  String engineDetailsResumeEpisode(int episode);

  /// No description provided for @engineDetailsPlayEpisode.
  ///
  /// In en, this message translates to:
  /// **'Play Ep {episode}'**
  String engineDetailsPlayEpisode(int episode);

  /// No description provided for @engineDetailsCast.
  ///
  /// In en, this message translates to:
  /// **'Cast'**
  String get engineDetailsCast;

  /// No description provided for @engineDetailsCharacters.
  ///
  /// In en, this message translates to:
  /// **'Characters'**
  String get engineDetailsCharacters;

  /// No description provided for @engineDetailsCrew.
  ///
  /// In en, this message translates to:
  /// **'Crew'**
  String get engineDetailsCrew;

  /// No description provided for @engineStoreNoSearch.
  ///
  /// In en, this message translates to:
  /// **'{hub} has no search'**
  String engineStoreNoSearch(String hub);

  /// No description provided for @engineStoreTypeToSearch.
  ///
  /// In en, this message translates to:
  /// **'Type a title to search'**
  String get engineStoreTypeToSearch;

  /// No description provided for @engineStoreNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches in {hub}'**
  String engineStoreNoMatches(String hub);

  /// No description provided for @engineStoreUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get engineStoreUntitled;

  /// No description provided for @engineStoreHubLabel.
  ///
  /// In en, this message translates to:
  /// **'Hub'**
  String get engineStoreHubLabel;

  /// No description provided for @engineStoreSearchHub.
  ///
  /// In en, this message translates to:
  /// **'Search {name}'**
  String engineStoreSearchHub(String name);

  /// No description provided for @engineStoreOpenInHub.
  ///
  /// In en, this message translates to:
  /// **'Open in {hub}'**
  String engineStoreOpenInHub(String hub);

  /// No description provided for @engineStoreSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search title'**
  String get engineStoreSearchTitle;

  /// No description provided for @engineStoreSearchTitleTv.
  ///
  /// In en, this message translates to:
  /// **'Search title — OK to type'**
  String get engineStoreSearchTitleTv;

  /// No description provided for @engineStoreBestMatch.
  ///
  /// In en, this message translates to:
  /// **'Best match'**
  String get engineStoreBestMatch;

  /// No description provided for @engineStoreRemovedFromList.
  ///
  /// In en, this message translates to:
  /// **'Removed from My List'**
  String get engineStoreRemovedFromList;

  /// No description provided for @engineStoreRemovedLocalFailed.
  ///
  /// In en, this message translates to:
  /// **'Removed locally · Simkl failed'**
  String get engineStoreRemovedLocalFailed;

  /// No description provided for @engineStoreSavedLocalFailed.
  ///
  /// In en, this message translates to:
  /// **'Saved locally · Simkl failed'**
  String get engineStoreSavedLocalFailed;

  /// No description provided for @engineStoreNoHub.
  ///
  /// In en, this message translates to:
  /// **'No hub available to open this title'**
  String get engineStoreNoHub;

  /// No description provided for @engineStoreNoHandoff.
  ///
  /// In en, this message translates to:
  /// **'That match has no open handoff'**
  String get engineStoreNoHandoff;

  /// No description provided for @engineStoreNoHandoffFor.
  ///
  /// In en, this message translates to:
  /// **'No open handoff for {name}'**
  String engineStoreNoHandoffFor(String name);

  /// No description provided for @accountBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get accountBack;

  /// No description provided for @accountChooserLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load saved accounts.'**
  String get accountChooserLoadFailed;

  /// No description provided for @accountChooserSwitchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not switch account. Sign in again for that user.'**
  String get accountChooserSwitchFailed;

  /// No description provided for @accountChooserMaxAccounts.
  ///
  /// In en, this message translates to:
  /// **'Maximum of {count} accounts on this device.'**
  String accountChooserMaxAccounts(int count);

  /// No description provided for @accountChooserAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not add account. Try again.'**
  String get accountChooserAddFailed;

  /// No description provided for @accountChooserTitle.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accountChooserTitle;

  /// No description provided for @accountChooserHeading.
  ///
  /// In en, this message translates to:
  /// **'Who’s signed in?'**
  String get accountChooserHeading;

  /// No description provided for @accountChooserSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Switch accounts on this device, or add another with QR / code.'**
  String get accountChooserSubtitle;

  /// No description provided for @accountChooserActiveGroup.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get accountChooserActiveGroup;

  /// No description provided for @accountChooserActiveNow.
  ///
  /// In en, this message translates to:
  /// **'Active now'**
  String get accountChooserActiveNow;

  /// No description provided for @accountChooserOtherGroup.
  ///
  /// In en, this message translates to:
  /// **'Other accounts'**
  String get accountChooserOtherGroup;

  /// No description provided for @accountChooserAdd.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get accountChooserAdd;

  /// No description provided for @accountChooserRemoveQuestion.
  ///
  /// In en, this message translates to:
  /// **'Remove this account?'**
  String get accountChooserRemoveQuestion;

  /// No description provided for @accountChooserTapToSwitch.
  ///
  /// In en, this message translates to:
  /// **'Tap to switch'**
  String get accountChooserTapToSwitch;

  /// No description provided for @accountChooserRemoveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove from this device'**
  String get accountChooserRemoveTooltip;

  /// No description provided for @accountEntryMfaRequired.
  ///
  /// In en, this message translates to:
  /// **'Authenticator required. Finish MFA on the web portal, then use Web login.'**
  String get accountEntryMfaRequired;

  /// No description provided for @accountEntryMfaPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code from your authenticator app.'**
  String get accountEntryMfaPrompt;

  /// No description provided for @accountEntryMfaShortCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit authenticator code.'**
  String get accountEntryMfaShortCode;

  /// No description provided for @accountEntryMfaVerifyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not verify the code. Try again.'**
  String get accountEntryMfaVerifyFailed;

  /// No description provided for @accountEntryMissingCredentials.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and password.'**
  String get accountEntryMissingCredentials;

  /// No description provided for @accountEntryConfirmEmail.
  ///
  /// In en, this message translates to:
  /// **'Check your email and open the confirmation link, then come back to sign in.'**
  String get accountEntryConfirmEmail;

  /// No description provided for @accountEntryConnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to Forja. Check your connection and retry.'**
  String get accountEntryConnectFailed;

  /// No description provided for @accountEntryWebOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening browser - sign in on the web, then return here. Tap Cancel if the browser does not open.'**
  String get accountEntryWebOpening;

  /// No description provided for @accountEntryWebIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Web login did not complete. Try again.'**
  String get accountEntryWebIncomplete;

  /// No description provided for @accountEntrySignupOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the signup page in your browser.'**
  String get accountEntrySignupOpenFailed;

  /// No description provided for @accountEntryTagline.
  ///
  /// In en, this message translates to:
  /// **'CREATIVE PLAYER'**
  String get accountEntryTagline;

  /// Followed directly by one rotating word (stream / sync / live / play) and a period.
  ///
  /// In en, this message translates to:
  /// **'One player.\nYour sources.\nEvery '**
  String get accountEntryHeadline;

  /// No description provided for @accountEntryWordStream.
  ///
  /// In en, this message translates to:
  /// **'stream'**
  String get accountEntryWordStream;

  /// No description provided for @accountEntryWordSync.
  ///
  /// In en, this message translates to:
  /// **'sync'**
  String get accountEntryWordSync;

  /// No description provided for @accountEntryWordLive.
  ///
  /// In en, this message translates to:
  /// **'live'**
  String get accountEntryWordLive;

  /// No description provided for @accountEntryWordPlay.
  ///
  /// In en, this message translates to:
  /// **'play'**
  String get accountEntryWordPlay;

  /// No description provided for @accountEntryIntro.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync settings and profiles across every screen. New accounts live on the web - not in the app.'**
  String get accountEntryIntro;

  /// No description provided for @accountEntryChipIptvGuides.
  ///
  /// In en, this message translates to:
  /// **'IPTV guides'**
  String get accountEntryChipIptvGuides;

  /// No description provided for @accountEntryChipProfiles.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get accountEntryChipProfiles;

  /// No description provided for @accountEntryChipDeskTv.
  ///
  /// In en, this message translates to:
  /// **'Desk → TV'**
  String get accountEntryChipDeskTv;

  /// No description provided for @accountEntryWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get accountEntryWelcome;

  /// No description provided for @accountEntryMfaSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the code from your authenticator app to finish sign-in.'**
  String get accountEntryMfaSubtitle;

  /// No description provided for @accountEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use your Forja account, or open the browser to sign in on the web.'**
  String get accountEntrySubtitle;

  /// No description provided for @accountEntryAuthCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Authenticator code'**
  String get accountEntryAuthCodeLabel;

  /// No description provided for @accountEntryShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get accountEntryShowPassword;

  /// No description provided for @accountEntryHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get accountEntryHidePassword;

  /// No description provided for @accountEntryVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying…'**
  String get accountEntryVerifying;

  /// No description provided for @accountEntryVerifyCode.
  ///
  /// In en, this message translates to:
  /// **'Verify code'**
  String get accountEntryVerifyCode;

  /// No description provided for @accountEntryConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get accountEntryConnecting;

  /// No description provided for @accountEntryCreateOnWeb.
  ///
  /// In en, this message translates to:
  /// **'Create an account on the web →'**
  String get accountEntryCreateOnWeb;

  /// No description provided for @accountEntryContinueNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Continue without an account'**
  String get accountEntryContinueNoAccount;

  /// No description provided for @accountEntryGuestNote.
  ///
  /// In en, this message translates to:
  /// **'Guest mode keeps everything on this device. You can sign in later from Settings.'**
  String get accountEntryGuestNote;

  /// No description provided for @accountLinkExpired.
  ///
  /// In en, this message translates to:
  /// **'This code expired. Start again to get a new one.'**
  String get accountLinkExpired;

  /// No description provided for @accountLinkCancelled.
  ///
  /// In en, this message translates to:
  /// **'Linking was cancelled. Start again to get a new code.'**
  String get accountLinkCancelled;

  /// No description provided for @accountLinkSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Signing you in'**
  String get accountLinkSigningIn;

  /// No description provided for @accountLinkCreatingSession.
  ///
  /// In en, this message translates to:
  /// **'Creating a secure session for this device.'**
  String get accountLinkCreatingSession;

  /// No description provided for @accountLinkThisDevice.
  ///
  /// In en, this message translates to:
  /// **'LINK THIS DEVICE'**
  String get accountLinkThisDevice;

  /// Followed directly by a web address such as www.example.com/connect.
  ///
  /// In en, this message translates to:
  /// **'Open '**
  String get accountLinkOpen;

  /// No description provided for @accountLinkEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the code or scan the QR from your phone.'**
  String get accountLinkEnterCode;

  /// No description provided for @accountGetNewCode.
  ///
  /// In en, this message translates to:
  /// **'Get a new code'**
  String get accountGetNewCode;

  /// No description provided for @accountLinkThisTv.
  ///
  /// In en, this message translates to:
  /// **'LINK THIS TV'**
  String get accountLinkThisTv;

  /// No description provided for @accountLinkOpenInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open link page in browser'**
  String get accountLinkOpenInBrowser;

  /// No description provided for @accountPacksUrlCopied.
  ///
  /// In en, this message translates to:
  /// **'URL copied — open on your phone'**
  String get accountPacksUrlCopied;

  /// No description provided for @accountPacksOpenCommunityFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open Community Packs.'**
  String get accountPacksOpenCommunityFailed;

  /// No description provided for @accountPacksLoadingOfficial.
  ///
  /// In en, this message translates to:
  /// **'Loading official packs…'**
  String get accountPacksLoadingOfficial;

  /// No description provided for @accountPacksLoadOfficialFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load official packs. Skip and add them later in Settings.'**
  String get accountPacksLoadOfficialFailed;

  /// No description provided for @accountPacksPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing official packs…'**
  String get accountPacksPreparing;

  /// No description provided for @accountPacksInstalledWithErrors.
  ///
  /// In en, this message translates to:
  /// **'Installed with {count} error(s): {details}'**
  String accountPacksInstalledWithErrors(int count, String details);

  /// No description provided for @accountPacksFinishing.
  ///
  /// In en, this message translates to:
  /// **'Finishing…'**
  String get accountPacksFinishing;

  /// No description provided for @accountPacksInstallFailed.
  ///
  /// In en, this message translates to:
  /// **'Install failed. You can skip and add packs later in Settings.'**
  String get accountPacksInstallFailed;

  /// No description provided for @accountPacksTitleChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose official packs'**
  String get accountPacksTitleChoose;

  /// No description provided for @accountPacksTitleUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock the best experience'**
  String get accountPacksTitleUnlock;

  /// No description provided for @accountPacksBodyPicking.
  ///
  /// In en, this message translates to:
  /// **'Recommended packs are checked. Add or remove any, then Install.'**
  String get accountPacksBodyPicking;

  /// No description provided for @accountPacksBodyIntro.
  ///
  /// In en, this message translates to:
  /// **'Packs add catalogs, stream sources, live sports, and more. Pick official ForjaHQ packs, or browse Community Packs and choose on the web.'**
  String get accountPacksBodyIntro;

  /// No description provided for @accountPacksLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get accountPacksLoading;

  /// No description provided for @accountPacksTvCommunity.
  ///
  /// In en, this message translates to:
  /// **'Choose packs on your phone\n{url}'**
  String accountPacksTvCommunity(String url);

  /// No description provided for @accountPacksSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get accountPacksSkip;

  /// No description provided for @accountProfileOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open this profile. Check your connection and retry.'**
  String get accountProfileOpenFailed;

  /// No description provided for @accountProfileMaxProfiles.
  ///
  /// In en, this message translates to:
  /// **'Maximum of 5 profiles per account.'**
  String get accountProfileMaxProfiles;

  /// No description provided for @accountProfileSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save profile.'**
  String get accountProfileSaveFailed;

  /// No description provided for @accountProfileDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete profile.'**
  String get accountProfileDeleteFailed;

  /// No description provided for @accountProfileLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load profiles. Check your connection and retry.'**
  String get accountProfileLoadFailed;

  /// No description provided for @accountProfileCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your profile'**
  String get accountProfileCreateTitle;

  /// No description provided for @accountProfileAdd.
  ///
  /// In en, this message translates to:
  /// **'Add profile'**
  String get accountProfileAdd;

  /// No description provided for @accountProfileEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get accountProfileEditTitle;

  /// No description provided for @accountProfileAccountTag.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get accountProfileAccountTag;

  /// No description provided for @accountProfileManage.
  ///
  /// In en, this message translates to:
  /// **'Manage profiles'**
  String get accountProfileManage;

  /// No description provided for @accountProfileWhosWatching.
  ///
  /// In en, this message translates to:
  /// **'Who’s watching?'**
  String get accountProfileWhosWatching;

  /// No description provided for @accountProfileLoadingProfiles.
  ///
  /// In en, this message translates to:
  /// **'Loading profiles…'**
  String get accountProfileLoadingProfiles;

  /// No description provided for @accountProfileLoadWhosWatchingFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load who’s watching right now.'**
  String get accountProfileLoadWhosWatchingFailed;

  /// No description provided for @accountProfileCreateHint.
  ///
  /// In en, this message translates to:
  /// **'Create a profile to sync settings on this device.'**
  String get accountProfileCreateHint;

  /// No description provided for @accountProfileManageHint.
  ///
  /// In en, this message translates to:
  /// **'Edit a profile or add a new one.'**
  String get accountProfileManageHint;

  /// No description provided for @accountProfileChooseHint.
  ///
  /// In en, this message translates to:
  /// **'Choose the profile whose settings you want on this device.'**
  String get accountProfileChooseHint;

  /// No description provided for @accountProfileUseAnotherAccount.
  ///
  /// In en, this message translates to:
  /// **'Use another account'**
  String get accountProfileUseAnotherAccount;

  /// No description provided for @accountProfileDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get accountProfileDone;

  /// No description provided for @accountProfileAccountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account settings'**
  String get accountProfileAccountSettings;

  /// No description provided for @accountProfileNewName.
  ///
  /// In en, this message translates to:
  /// **'New profile'**
  String get accountProfileNewName;

  /// No description provided for @accountProfileNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Profile name'**
  String get accountProfileNameLabel;

  /// No description provided for @accountProfileChooseAvatar.
  ///
  /// In en, this message translates to:
  /// **'CHOOSE AN AVATAR'**
  String get accountProfileChooseAvatar;

  /// No description provided for @accountProfileSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get accountProfileSaving;

  /// No description provided for @accountProfileSave.
  ///
  /// In en, this message translates to:
  /// **'Save profile'**
  String get accountProfileSave;

  /// No description provided for @accountProfileDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete profile'**
  String get accountProfileDelete;

  /// No description provided for @accountSplashLoadingProfile.
  ///
  /// In en, this message translates to:
  /// **'Loading profile…'**
  String get accountSplashLoadingProfile;

  /// No description provided for @accountSplashSavingCurrent.
  ///
  /// In en, this message translates to:
  /// **'Saving current profile…'**
  String get accountSplashSavingCurrent;

  /// No description provided for @accountSplashLoadingNamed.
  ///
  /// In en, this message translates to:
  /// **'Loading {name}…'**
  String accountSplashLoadingNamed(String name);

  /// No description provided for @accountSplashSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing settings…'**
  String get accountSplashSyncing;

  /// No description provided for @accountSplashPulling.
  ///
  /// In en, this message translates to:
  /// **'Pulling your tabs and sources…'**
  String get accountSplashPulling;

  /// No description provided for @accountSplashApplying.
  ///
  /// In en, this message translates to:
  /// **'Applying playback preferences…'**
  String get accountSplashApplying;

  /// No description provided for @appBootAlmostReady.
  ///
  /// In en, this message translates to:
  /// **'Almost ready…'**
  String get appBootAlmostReady;

  /// No description provided for @accountSplashWarmingHome.
  ///
  /// In en, this message translates to:
  /// **'Warming up Home…'**
  String get accountSplashWarmingHome;

  /// No description provided for @accountSplashOpeningSyncing.
  ///
  /// In en, this message translates to:
  /// **'Opening while settings finish syncing. IPTV portals load when ready.'**
  String get accountSplashOpeningSyncing;

  /// No description provided for @appBootPluginsBackground.
  ///
  /// In en, this message translates to:
  /// **'Plugins keep downloading in the background.'**
  String get appBootPluginsBackground;

  /// No description provided for @appBootOpeningLiveIptv.
  ///
  /// In en, this message translates to:
  /// **'Opening Live & IPTV…'**
  String get appBootOpeningLiveIptv;

  /// No description provided for @appBootOpeningNamed.
  ///
  /// In en, this message translates to:
  /// **'Opening {label}…'**
  String appBootOpeningNamed(String label);

  /// No description provided for @appBootWarmingCatalog.
  ///
  /// In en, this message translates to:
  /// **'Warming catalog…'**
  String get appBootWarmingCatalog;

  /// No description provided for @appBootLoadingPlugins.
  ///
  /// In en, this message translates to:
  /// **'Loading plugins…'**
  String get appBootLoadingPlugins;

  /// No description provided for @appBootJustAMoment.
  ///
  /// In en, this message translates to:
  /// **'Just a moment…'**
  String get appBootJustAMoment;

  /// No description provided for @appBootStartingProxy.
  ///
  /// In en, this message translates to:
  /// **'Starting stream proxy…'**
  String get appBootStartingProxy;

  /// No description provided for @appBootStartingTorrent.
  ///
  /// In en, this message translates to:
  /// **'Starting torrent engine…'**
  String get appBootStartingTorrent;

  /// No description provided for @accountLinkSomethingWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get accountLinkSomethingWrong;

  /// No description provided for @accountTvContinueGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue as guest'**
  String get accountTvContinueGuest;

  /// No description provided for @accountTvTitle.
  ///
  /// In en, this message translates to:
  /// **'Your cinema.\nOn the big screen.'**
  String get accountTvTitle;

  /// No description provided for @accountTvBody.
  ///
  /// In en, this message translates to:
  /// **'The couch is ready. So is Forja. Open a film, chase a series, catch the match, or flip through live TV.'**
  String get accountTvBody;

  /// No description provided for @accountLinkCouldNot.
  ///
  /// In en, this message translates to:
  /// **'COULD NOT LINK'**
  String get accountLinkCouldNot;

  /// No description provided for @syncPortalLimitUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get syncPortalLimitUnlimited;

  /// No description provided for @syncPortalLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Portal limit reached.'**
  String get syncPortalLimitReached;

  /// No description provided for @syncPortalLimitMax.
  ///
  /// In en, this message translates to:
  /// **'Maximum of {count} portals per profile'**
  String syncPortalLimitMax(int count);

  /// No description provided for @appBootGettingReady.
  ///
  /// In en, this message translates to:
  /// **'Getting things ready…'**
  String get appBootGettingReady;

  /// No description provided for @appBootSlowCatalog.
  ///
  /// In en, this message translates to:
  /// **'Loading catalog services is taking longer than expected.'**
  String get appBootSlowCatalog;

  /// No description provided for @appBootWarmingShell.
  ///
  /// In en, this message translates to:
  /// **'Warming up the shell…'**
  String get appBootWarmingShell;

  /// No description provided for @appBootLoadingProfile.
  ///
  /// In en, this message translates to:
  /// **'Loading your profile…'**
  String get appBootLoadingProfile;

  /// No description provided for @appBootCheckingConnection.
  ///
  /// In en, this message translates to:
  /// **'Checking connection…'**
  String get appBootCheckingConnection;

  /// No description provided for @sharedDownloadsNoSavedFile.
  ///
  /// In en, this message translates to:
  /// **'No saved file'**
  String get sharedDownloadsNoSavedFile;

  /// No description provided for @sharedDownloadsSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get sharedDownloadsSaved;

  /// No description provided for @sharedDownloadsSeasonNumber.
  ///
  /// In en, this message translates to:
  /// **'Season {number}'**
  String sharedDownloadsSeasonNumber(int number);

  /// No description provided for @sharedDownloadsDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get sharedDownloadsDownloading;

  /// No description provided for @sharedDownloadsDownloadingCount.
  ///
  /// In en, this message translates to:
  /// **'Downloading · {count}'**
  String sharedDownloadsDownloadingCount(int count);

  /// No description provided for @sharedDownloadsSavedCount.
  ///
  /// In en, this message translates to:
  /// **'Saved · {count}'**
  String sharedDownloadsSavedCount(int count);

  /// No description provided for @sharedDownloadsPlayOnline.
  ///
  /// In en, this message translates to:
  /// **'Play online'**
  String get sharedDownloadsPlayOnline;

  /// No description provided for @sharedDownloadsView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get sharedDownloadsView;

  /// No description provided for @sharedDownloadsExternalNoOffline.
  ///
  /// In en, this message translates to:
  /// **'External links can’t be saved offline'**
  String get sharedDownloadsExternalNoOffline;

  /// No description provided for @sharedDownloadsTorrentsNoOffline.
  ///
  /// In en, this message translates to:
  /// **'Torrents aren\'t available for offline download yet'**
  String get sharedDownloadsTorrentsNoOffline;

  /// No description provided for @sharedDownloadsDashNoOffline.
  ///
  /// In en, this message translates to:
  /// **'DASH streams can\'t be saved offline yet'**
  String get sharedDownloadsDashNoOffline;

  /// No description provided for @sharedDownloadsStreamNoOffline.
  ///
  /// In en, this message translates to:
  /// **'This stream can’t be saved offline'**
  String get sharedDownloadsStreamNoOffline;

  /// No description provided for @sharedDownloadsFree.
  ///
  /// In en, this message translates to:
  /// **'Free {size}'**
  String sharedDownloadsFree(String size);

  /// No description provided for @sharedDownloadsAlreadySaved.
  ///
  /// In en, this message translates to:
  /// **'Already saved offline'**
  String get sharedDownloadsAlreadySaved;

  /// No description provided for @sharedDownloadsAlreadyDownloading.
  ///
  /// In en, this message translates to:
  /// **'Already downloading {title}'**
  String sharedDownloadsAlreadyDownloading(String title);

  /// No description provided for @sharedDownloadsDownloadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Downloading {title}'**
  String sharedDownloadsDownloadingTitle(String title);

  /// No description provided for @sharedDownloadsFailedToStart.
  ///
  /// In en, this message translates to:
  /// **'Download failed to start'**
  String get sharedDownloadsFailedToStart;

  /// No description provided for @sharedDownloadsLinkExpired.
  ///
  /// In en, this message translates to:
  /// **'Stream link expired — open Sources and download again'**
  String get sharedDownloadsLinkExpired;

  /// No description provided for @sharedDownloadsFileMissing.
  ///
  /// In en, this message translates to:
  /// **'Download file is missing'**
  String get sharedDownloadsFileMissing;

  /// No description provided for @sharedDownloadsFileUnplayableDelete.
  ///
  /// In en, this message translates to:
  /// **'Downloaded file can’t be played — delete it and download again'**
  String get sharedDownloadsFileUnplayableDelete;

  /// No description provided for @sharedDownloadsFileUnplayable.
  ///
  /// In en, this message translates to:
  /// **'Downloaded file can’t be played'**
  String get sharedDownloadsFileUnplayable;

  /// No description provided for @sharedDownloadsNoOnlineStream.
  ///
  /// In en, this message translates to:
  /// **'No online stream'**
  String get sharedDownloadsNoOnlineStream;

  /// No description provided for @sharedDownloadsFindingStream.
  ///
  /// In en, this message translates to:
  /// **'Finding a stream…'**
  String get sharedDownloadsFindingStream;

  /// No description provided for @sharedDownloadsSizeUnknown.
  ///
  /// In en, this message translates to:
  /// **'Size unknown'**
  String get sharedDownloadsSizeUnknown;

  /// No description provided for @sharedDownloadsFileMovedOrDeleted.
  ///
  /// In en, this message translates to:
  /// **'File was moved or deleted from disk'**
  String get sharedDownloadsFileMovedOrDeleted;

  /// No description provided for @sharedDownloadsEmptyUrl.
  ///
  /// In en, this message translates to:
  /// **'Empty download URL'**
  String get sharedDownloadsEmptyUrl;

  /// No description provided for @sharedDownloadsServerHttp.
  ///
  /// In en, this message translates to:
  /// **'Server returned HTTP {code}: {phrase}'**
  String sharedDownloadsServerHttp(int code, String phrase);

  /// No description provided for @sharedDownloadsServerPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Server returned a playlist/page, not a video file'**
  String get sharedDownloadsServerPlaylist;

  /// No description provided for @sharedDownloadsReconnectingRemaining.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting remaining data (attempt {attempt})...'**
  String sharedDownloadsReconnectingRemaining(int attempt);

  /// No description provided for @sharedDownloadsReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting (attempt {attempt})...'**
  String sharedDownloadsReconnecting(int attempt);

  /// No description provided for @sharedDownloadsFileMissingShort.
  ///
  /// In en, this message translates to:
  /// **'Download file missing'**
  String get sharedDownloadsFileMissingShort;

  /// No description provided for @sharedDownloadsIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Download incomplete — delete and try again'**
  String get sharedDownloadsIncomplete;

  /// No description provided for @sharedDownloadsNotPlayableVideo.
  ///
  /// In en, this message translates to:
  /// **'Downloaded file is not a playable video'**
  String get sharedDownloadsNotPlayableVideo;

  /// No description provided for @sharedDownloadsTooSmall.
  ///
  /// In en, this message translates to:
  /// **'Download too small to be a video file'**
  String get sharedDownloadsTooSmall;

  /// No description provided for @sharedDownloadsSaveFinalFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save final file: {error}'**
  String sharedDownloadsSaveFinalFailed(String error);

  /// No description provided for @sharedServicesUpdateReadyToInstall.
  ///
  /// In en, this message translates to:
  /// **'Forja {version} is ready to install.'**
  String sharedServicesUpdateReadyToInstall(String version);

  /// No description provided for @sharedServicesOpenDownloadUrl.
  ///
  /// In en, this message translates to:
  /// **'Open download URL'**
  String get sharedServicesOpenDownloadUrl;

  /// No description provided for @sharedServicesUpdateFileGone.
  ///
  /// In en, this message translates to:
  /// **'The downloaded update file is no longer available.'**
  String get sharedServicesUpdateFileGone;

  /// No description provided for @sharedServicesUpdateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check for updates: {error}'**
  String sharedServicesUpdateCheckFailed(String error);

  /// No description provided for @sharedServicesUpdateServerNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Update server is not configured in this build.'**
  String get sharedServicesUpdateServerNotConfigured;

  /// No description provided for @sharedServicesUpdateServerUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the update server. Check your connection.'**
  String get sharedServicesUpdateServerUnreachable;

  /// No description provided for @sharedServicesUpdateServerHttp.
  ///
  /// In en, this message translates to:
  /// **'Update server returned HTTP {code}.'**
  String sharedServicesUpdateServerHttp(int code);

  /// No description provided for @sharedServicesUpdateManifestInvalid.
  ///
  /// In en, this message translates to:
  /// **'Update manifest was invalid.'**
  String get sharedServicesUpdateManifestInvalid;

  /// No description provided for @sharedServicesUpdateNoInstaller.
  ///
  /// In en, this message translates to:
  /// **'No installer is published for this device architecture yet.'**
  String get sharedServicesUpdateNoInstaller;

  /// No description provided for @sharedServicesUpdateNoAsset.
  ///
  /// In en, this message translates to:
  /// **'Found {version} but no matching installer asset.'**
  String sharedServicesUpdateNoAsset(String version);

  /// No description provided for @sharedLanServerUp.
  ///
  /// In en, this message translates to:
  /// **'Server up'**
  String get sharedLanServerUp;

  /// No description provided for @sharedLanServerUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Server unreachable'**
  String get sharedLanServerUnreachable;

  /// No description provided for @sharedLanWaitingForPair.
  ///
  /// In en, this message translates to:
  /// **'waiting for pair'**
  String get sharedLanWaitingForPair;

  /// No description provided for @sharedLanPaired.
  ///
  /// In en, this message translates to:
  /// **'paired'**
  String get sharedLanPaired;

  /// No description provided for @sharedLanIdleLower.
  ///
  /// In en, this message translates to:
  /// **'idle'**
  String get sharedLanIdleLower;

  /// No description provided for @sharedLanPlayingLower.
  ///
  /// In en, this message translates to:
  /// **'playing'**
  String get sharedLanPlayingLower;

  /// No description provided for @sharedLanIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get sharedLanIdle;

  /// No description provided for @sharedLanActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get sharedLanActive;

  /// No description provided for @sharedLanPlaying.
  ///
  /// In en, this message translates to:
  /// **'Playing'**
  String get sharedLanPlaying;

  /// No description provided for @sharedLanDesktopOnline.
  ///
  /// In en, this message translates to:
  /// **'Desktop online'**
  String get sharedLanDesktopOnline;

  /// No description provided for @sharedLanPairWithDesktop.
  ///
  /// In en, this message translates to:
  /// **'Pair with a desktop Forja server in Settings → LAN.'**
  String get sharedLanPairWithDesktop;

  /// No description provided for @sharedLanDesktopOffline.
  ///
  /// In en, this message translates to:
  /// **'Desktop server is offline. Direct streams still work.'**
  String get sharedLanDesktopOffline;

  /// No description provided for @sharedMiscBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get sharedMiscBack;

  /// No description provided for @sharedMiscAirPlayCantPlay.
  ///
  /// In en, this message translates to:
  /// **'AirPlay can\'t play this stream'**
  String get sharedMiscAirPlayCantPlay;

  /// No description provided for @sharedPlaybackOpeningPlayer.
  ///
  /// In en, this message translates to:
  /// **'Opening player…'**
  String get sharedPlaybackOpeningPlayer;

  /// No description provided for @sharedPlaybackProbingStreams.
  ///
  /// In en, this message translates to:
  /// **'Probing streams…'**
  String get sharedPlaybackProbingStreams;

  /// No description provided for @sharedPlaybackProbingStreamsProgress.
  ///
  /// In en, this message translates to:
  /// **'Probing streams ({done}/{total})…'**
  String sharedPlaybackProbingStreamsProgress(int done, int total);

  /// No description provided for @sharedPlaybackCheckingServers.
  ///
  /// In en, this message translates to:
  /// **'Checking servers…'**
  String get sharedPlaybackCheckingServers;

  /// No description provided for @sharedPlaybackFindingServers.
  ///
  /// In en, this message translates to:
  /// **'Finding servers…'**
  String get sharedPlaybackFindingServers;

  /// No description provided for @sharedPlaybackFindingForjaServers.
  ///
  /// In en, this message translates to:
  /// **'Finding Forja servers…'**
  String get sharedPlaybackFindingForjaServers;

  /// No description provided for @sharedPlaybackStartingStream.
  ///
  /// In en, this message translates to:
  /// **'Starting stream…'**
  String get sharedPlaybackStartingStream;

  /// No description provided for @sharedPlaybackHintStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting playback'**
  String get sharedPlaybackHintStarting;

  /// No description provided for @sharedPlaybackHintTesting.
  ///
  /// In en, this message translates to:
  /// **'Testing which links play'**
  String get sharedPlaybackHintTesting;

  /// No description provided for @sharedPlaybackHintAsking.
  ///
  /// In en, this message translates to:
  /// **'Asking servers for streams'**
  String get sharedPlaybackHintAsking;

  /// No description provided for @sharedPlaybackHintLookingUp.
  ///
  /// In en, this message translates to:
  /// **'Looking up available providers'**
  String get sharedPlaybackHintLookingUp;

  /// No description provided for @sharedPlaybackProbeSummary.
  ///
  /// In en, this message translates to:
  /// **'{checked} / {total} checked · {ready} up'**
  String sharedPlaybackProbeSummary(int checked, int total, int ready);

  /// No description provided for @sharedPlaybackProbeSummarySkipped.
  ///
  /// In en, this message translates to:
  /// **'{checked} / {total} checked · {ready} up · {skipped} skipped on TV'**
  String sharedPlaybackProbeSummarySkipped(
    int checked,
    int total,
    int ready,
    int skipped,
  );

  /// No description provided for @sharedPlaybackSearchAgain.
  ///
  /// In en, this message translates to:
  /// **'Search again'**
  String get sharedPlaybackSearchAgain;

  /// No description provided for @sharedPlaybackSavedLinkBroken.
  ///
  /// In en, this message translates to:
  /// **'That saved link is no longer working'**
  String get sharedPlaybackSavedLinkBroken;

  /// No description provided for @sharedPlaybackProbeWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get sharedPlaybackProbeWaiting;

  /// No description provided for @sharedPlaybackProbeChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking'**
  String get sharedPlaybackProbeChecking;

  /// No description provided for @sharedPlaybackProbeUp.
  ///
  /// In en, this message translates to:
  /// **'Up'**
  String get sharedPlaybackProbeUp;

  /// No description provided for @sharedPlaybackProbeDown.
  ///
  /// In en, this message translates to:
  /// **'Down'**
  String get sharedPlaybackProbeDown;

  /// No description provided for @sharedPlaybackProbeSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get sharedPlaybackProbeSkipped;

  /// No description provided for @sharedPlaybackHideServers.
  ///
  /// In en, this message translates to:
  /// **'Hide servers'**
  String get sharedPlaybackHideServers;

  /// No description provided for @sharedPlaybackShowServers.
  ///
  /// In en, this message translates to:
  /// **'Show servers'**
  String get sharedPlaybackShowServers;

  /// No description provided for @sharedPlaybackTapServerFirst.
  ///
  /// In en, this message translates to:
  /// **'Tap a server to check it first'**
  String get sharedPlaybackTapServerFirst;

  /// No description provided for @sharedPlaybackPressBackToCancel.
  ///
  /// In en, this message translates to:
  /// **'Press Back to cancel'**
  String get sharedPlaybackPressBackToCancel;

  /// No description provided for @sharedPlaybackTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get sharedPlaybackTryAgain;

  /// No description provided for @sharedPlaybackCouldNotStart.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t start playback'**
  String get sharedPlaybackCouldNotStart;

  /// No description provided for @sharedPlaybackNoPluginsOn.
  ///
  /// In en, this message translates to:
  /// **'No Forja plugins are on for this title. Open Sources → Forja and turn on providers.'**
  String get sharedPlaybackNoPluginsOn;

  /// No description provided for @sharedPlaybackNoWorkingStream.
  ///
  /// In en, this message translates to:
  /// **'None of the Forja plugins returned a working stream right now.'**
  String get sharedPlaybackNoWorkingStream;

  /// No description provided for @sharedPlaybackNoProvidersEnabled.
  ///
  /// In en, this message translates to:
  /// **'No Forja providers are enabled for green Play'**
  String get sharedPlaybackNoProvidersEnabled;

  /// No description provided for @sharedPlaybackNoProvidersMatchLanguages.
  ///
  /// In en, this message translates to:
  /// **'No Forja providers match the selected languages'**
  String get sharedPlaybackNoProvidersMatchLanguages;

  /// No description provided for @sharedPlaybackUnableHandleLink.
  ///
  /// In en, this message translates to:
  /// **'Unable to handle this link'**
  String get sharedPlaybackUnableHandleLink;

  /// No description provided for @sharedPlaybackFailedLoadVideo.
  ///
  /// In en, this message translates to:
  /// **'Failed to load video'**
  String get sharedPlaybackFailedLoadVideo;

  /// No description provided for @sharedPlaybackErrorWith.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String sharedPlaybackErrorWith(String error);

  /// No description provided for @sharedPlaybackDrmAndroidOnly.
  ///
  /// In en, this message translates to:
  /// **'This title is DRM-protected — desktop playback is not available yet.'**
  String get sharedPlaybackDrmAndroidOnly;

  /// No description provided for @sharedPlaybackEpisodeNumber.
  ///
  /// In en, this message translates to:
  /// **'Episode {number}'**
  String sharedPlaybackEpisodeNumber(int number);

  /// No description provided for @sharedPlaybackLabelEpisode.
  ///
  /// In en, this message translates to:
  /// **'{label} · Episode {episode}'**
  String sharedPlaybackLabelEpisode(String label, int episode);

  /// No description provided for @sharedPlaybackSeasonEpisode.
  ///
  /// In en, this message translates to:
  /// **'Season {season} · Episode {episode}'**
  String sharedPlaybackSeasonEpisode(int season, int episode);

  /// No description provided for @shellNavbarName.
  ///
  /// In en, this message translates to:
  /// **'Navbar'**
  String get shellNavbarName;

  /// No description provided for @shellReloadingNamed.
  ///
  /// In en, this message translates to:
  /// **'Reloading {name}…'**
  String shellReloadingNamed(String name);

  /// No description provided for @shellNamedReloaded.
  ///
  /// In en, this message translates to:
  /// **'{name} reloaded'**
  String shellNamedReloaded(String name);

  /// No description provided for @shellSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search…'**
  String get shellSearchHint;

  /// No description provided for @shellSearchHintNamed.
  ///
  /// In en, this message translates to:
  /// **'Search {label}…'**
  String shellSearchHintNamed(String label);

  /// No description provided for @shellUpdateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading update…'**
  String get shellUpdateDownloading;

  /// No description provided for @shellUpdateDownloadingVersion.
  ///
  /// In en, this message translates to:
  /// **'Downloading Forja {version}…'**
  String shellUpdateDownloadingVersion(String version);

  /// No description provided for @shellUpdateSoftwareUpdate.
  ///
  /// In en, this message translates to:
  /// **'Software update'**
  String get shellUpdateSoftwareUpdate;

  /// No description provided for @shellUpdateNewVersionReady.
  ///
  /// In en, this message translates to:
  /// **'A new version is ready'**
  String get shellUpdateNewVersionReady;

  /// No description provided for @shellUpdateYouAreOn.
  ///
  /// In en, this message translates to:
  /// **'You’re on v{version}'**
  String shellUpdateYouAreOn(String version);

  /// No description provided for @shellUpdateWhatsNew.
  ///
  /// In en, this message translates to:
  /// **'What’s new'**
  String get shellUpdateWhatsNew;

  /// No description provided for @shellUpdateHintOkBrowse.
  ///
  /// In en, this message translates to:
  /// **'OK to browse'**
  String get shellUpdateHintOkBrowse;

  /// No description provided for @shellUpdateHintRailNotes.
  ///
  /// In en, this message translates to:
  /// **'↑↓ versions  ·  → notes  ·  OK to exit'**
  String get shellUpdateHintRailNotes;

  /// No description provided for @shellUpdateHintScrollVersions.
  ///
  /// In en, this message translates to:
  /// **'↑↓ scroll  ·  ← versions  ·  OK to exit'**
  String get shellUpdateHintScrollVersions;

  /// No description provided for @shellUpdateHintScroll.
  ///
  /// In en, this message translates to:
  /// **'↑↓ scroll  ·  OK to exit'**
  String get shellUpdateHintScroll;

  /// No description provided for @shellUpdateNoNotes.
  ///
  /// In en, this message translates to:
  /// **'No release notes were published for this update.'**
  String get shellUpdateNoNotes;

  /// No description provided for @shellUpdateNoNotesVersion.
  ///
  /// In en, this message translates to:
  /// **'No release notes were published for v{version}.'**
  String shellUpdateNoNotesVersion(String version);

  /// No description provided for @shellUpdateContinueInBackground.
  ///
  /// In en, this message translates to:
  /// **'Continue in background'**
  String get shellUpdateContinueInBackground;

  /// No description provided for @shellUpdateReleasedToday.
  ///
  /// In en, this message translates to:
  /// **'released today'**
  String get shellUpdateReleasedToday;

  /// No description provided for @shellUpdateReleasedYesterday.
  ///
  /// In en, this message translates to:
  /// **'released yesterday'**
  String get shellUpdateReleasedYesterday;

  /// No description provided for @shellUpdateReleasedDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'released {days} days ago'**
  String shellUpdateReleasedDaysAgo(int days);

  /// No description provided for @shellUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed: {error}'**
  String shellUpdateFailed(String error);

  /// No description provided for @shellUpdateDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {error}'**
  String shellUpdateDownloadFailed(String error);

  /// No description provided for @shellUpdateCouldNotOpen.
  ///
  /// In en, this message translates to:
  /// **'Could not open the update: {error}'**
  String shellUpdateCouldNotOpen(String error);

  /// No description provided for @shellUpdateInstall.
  ///
  /// In en, this message translates to:
  /// **'Install update'**
  String get shellUpdateInstall;

  /// No description provided for @shellUpdateSkipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get shellUpdateSkipForNow;

  /// No description provided for @shellUpdateSeeFullChangelog.
  ///
  /// In en, this message translates to:
  /// **'See full changelog on the web'**
  String get shellUpdateSeeFullChangelog;

  /// No description provided for @shellUpdateViewFullChangelog.
  ///
  /// In en, this message translates to:
  /// **'View full changelog'**
  String get shellUpdateViewFullChangelog;

  /// No description provided for @shellUpdateDownloadComplete.
  ///
  /// In en, this message translates to:
  /// **'Download complete'**
  String get shellUpdateDownloadComplete;

  /// No description provided for @shellUpdateDownloadCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Download\ncomplete'**
  String get shellUpdateDownloadCompleteTitle;

  /// No description provided for @shellUpdateMustCloseWindows.
  ///
  /// In en, this message translates to:
  /// **'Forja must close before you install the update. Choose Install to close Forja and launch the installer, or skip for now.'**
  String get shellUpdateMustCloseWindows;

  /// No description provided for @shellUpdateMustCloseMac.
  ///
  /// In en, this message translates to:
  /// **'Forja must close before you install the update. Choose Install to close Forja and open the disk image, or skip for now.'**
  String get shellUpdateMustCloseMac;

  /// No description provided for @shellUpdateMakeExecutable.
  ///
  /// In en, this message translates to:
  /// **'Make the file executable, then run it:\nchmod +x \"{fileName}\"\n./{fileName}'**
  String shellUpdateMakeExecutable(String fileName);

  /// No description provided for @shellUpdateInstallAndClose.
  ///
  /// In en, this message translates to:
  /// **'Install and close Forja'**
  String get shellUpdateInstallAndClose;

  /// No description provided for @shellUpdateDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get shellUpdateDone;

  /// No description provided for @shellUpdateOpenDownloads.
  ///
  /// In en, this message translates to:
  /// **'Open downloads folder'**
  String get shellUpdateOpenDownloads;

  /// No description provided for @shellProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get shellProfile;

  /// No description provided for @shellGuest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get shellGuest;

  /// No description provided for @shellEmptyPluginsTitle.
  ///
  /// In en, this message translates to:
  /// **'Plugins'**
  String get shellEmptyPluginsTitle;

  /// No description provided for @shellEmptyPluginsBodyTv.
  ///
  /// In en, this message translates to:
  /// **'Install hub and stream packs from a URL or profile.'**
  String get shellEmptyPluginsBodyTv;

  /// No description provided for @shellEmptyPluginsBody.
  ///
  /// In en, this message translates to:
  /// **'Install hub and stream packs from a manifest URL, or sync packs from your profile.'**
  String get shellEmptyPluginsBody;

  /// No description provided for @shellEmptyAddonsBodyTv.
  ///
  /// In en, this message translates to:
  /// **'IPTV, Live Sports, torrent, Stremio, Nuvio, and more.'**
  String get shellEmptyAddonsBodyTv;

  /// No description provided for @shellEmptyAddonsBody.
  ///
  /// In en, this message translates to:
  /// **'Turn on IPTV, Live Sports, torrent, Stremio, Nuvio, and other playback surfaces.'**
  String get shellEmptyAddonsBody;

  /// No description provided for @shellEmptyFeaturesBodyTv.
  ///
  /// In en, this message translates to:
  /// **'Choose which tabs appear in the rail.'**
  String get shellEmptyFeaturesBodyTv;

  /// No description provided for @shellEmptyFeaturesBody.
  ///
  /// In en, this message translates to:
  /// **'Choose which tabs appear: Home, Anime, IPTV, Live Sports, Lists, and more.'**
  String get shellEmptyFeaturesBody;

  /// No description provided for @shellEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn on a feature to get started'**
  String get shellEmptyTitle;

  /// No description provided for @shellEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Pick Plugins, Addons, or Features.'**
  String get shellEmptyHint;

  /// No description provided for @shellPressBackAgainToExit.
  ///
  /// In en, this message translates to:
  /// **'Press Back again to exit'**
  String get shellPressBackAgainToExit;

  /// No description provided for @shellPressExitAgainToExit.
  ///
  /// In en, this message translates to:
  /// **'Press Exit again to exit'**
  String get shellPressExitAgainToExit;

  /// No description provided for @shellDismissCategories.
  ///
  /// In en, this message translates to:
  /// **'Dismiss categories'**
  String get shellDismissCategories;

  /// No description provided for @shellCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get shellCategories;

  /// No description provided for @shellUpdating.
  ///
  /// In en, this message translates to:
  /// **'Updating'**
  String get shellUpdating;

  /// No description provided for @accountAvatarCategoryCharacters.
  ///
  /// In en, this message translates to:
  /// **'Characters'**
  String get accountAvatarCategoryCharacters;

  /// No description provided for @accountAvatarCategoryCreatures.
  ///
  /// In en, this message translates to:
  /// **'Creatures'**
  String get accountAvatarCategoryCreatures;

  /// No description provided for @accountAvatarCategorySpace.
  ///
  /// In en, this message translates to:
  /// **'Space'**
  String get accountAvatarCategorySpace;

  /// No description provided for @accountAvatarCategoryRetro.
  ///
  /// In en, this message translates to:
  /// **'Retro'**
  String get accountAvatarCategoryRetro;

  /// No description provided for @foundationReadMore.
  ///
  /// In en, this message translates to:
  /// **'Read More'**
  String get foundationReadMore;

  /// No description provided for @foundationReadLess.
  ///
  /// In en, this message translates to:
  /// **'Read Less'**
  String get foundationReadLess;

  /// No description provided for @foundationRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get foundationRetry;

  /// No description provided for @foundationBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get foundationBack;

  /// No description provided for @foundationNothingHere.
  ///
  /// In en, this message translates to:
  /// **'Nothing here'**
  String get foundationNothingHere;

  /// No description provided for @foundationNoCategories.
  ///
  /// In en, this message translates to:
  /// **'No categories'**
  String get foundationNoCategories;

  /// No description provided for @foundationNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get foundationNoMatches;

  /// No description provided for @foundationSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get foundationSearch;

  /// No description provided for @foundationAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get foundationAll;

  /// No description provided for @foundationFactName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get foundationFactName;

  /// No description provided for @foundationFactStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get foundationFactStatus;

  /// No description provided for @foundationFactLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get foundationFactLanguage;

  /// No description provided for @foundationFactFirstAired.
  ///
  /// In en, this message translates to:
  /// **'First Aired'**
  String get foundationFactFirstAired;

  /// No description provided for @foundationFactLastAired.
  ///
  /// In en, this message translates to:
  /// **'Last Aired'**
  String get foundationFactLastAired;

  /// No description provided for @foundationFactSeasons.
  ///
  /// In en, this message translates to:
  /// **'Seasons'**
  String get foundationFactSeasons;

  /// No description provided for @foundationFactEpisodes.
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get foundationFactEpisodes;

  /// No description provided for @foundationFactNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get foundationFactNetwork;

  /// No description provided for @foundationFactReleaseDate.
  ///
  /// In en, this message translates to:
  /// **'Release Date'**
  String get foundationFactReleaseDate;

  /// No description provided for @foundationFactRuntime.
  ///
  /// In en, this message translates to:
  /// **'Runtime'**
  String get foundationFactRuntime;

  /// No description provided for @foundationFactProduction.
  ///
  /// In en, this message translates to:
  /// **'Production'**
  String get foundationFactProduction;

  /// No description provided for @foundationFactOrigin.
  ///
  /// In en, this message translates to:
  /// **'Origin'**
  String get foundationFactOrigin;

  /// No description provided for @foundationFactCreatedBy.
  ///
  /// In en, this message translates to:
  /// **'Created by'**
  String get foundationFactCreatedBy;

  /// No description provided for @foundationFactBudget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get foundationFactBudget;

  /// No description provided for @foundationFactRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get foundationFactRevenue;

  /// No description provided for @foundationStatusReleased.
  ///
  /// In en, this message translates to:
  /// **'Released'**
  String get foundationStatusReleased;

  /// No description provided for @foundationStatusEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get foundationStatusEnded;

  /// No description provided for @foundationStatusReturningSeries.
  ///
  /// In en, this message translates to:
  /// **'Returning Series'**
  String get foundationStatusReturningSeries;

  /// No description provided for @foundationStatusInProduction.
  ///
  /// In en, this message translates to:
  /// **'In Production'**
  String get foundationStatusInProduction;

  /// No description provided for @foundationStatusCanceled.
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get foundationStatusCanceled;

  /// No description provided for @foundationStatusPlanned.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get foundationStatusPlanned;

  /// No description provided for @foundationStatusPostProduction.
  ///
  /// In en, this message translates to:
  /// **'Post Production'**
  String get foundationStatusPostProduction;

  /// No description provided for @foundationStatusRumored.
  ///
  /// In en, this message translates to:
  /// **'Rumored'**
  String get foundationStatusRumored;

  /// No description provided for @foundationMonthJan.
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get foundationMonthJan;

  /// No description provided for @foundationMonthFeb.
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get foundationMonthFeb;

  /// No description provided for @foundationMonthMar.
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get foundationMonthMar;

  /// No description provided for @foundationMonthApr.
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get foundationMonthApr;

  /// No description provided for @foundationMonthMay.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get foundationMonthMay;

  /// No description provided for @foundationMonthJun.
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get foundationMonthJun;

  /// No description provided for @foundationMonthJul.
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get foundationMonthJul;

  /// No description provided for @foundationMonthAug.
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get foundationMonthAug;

  /// No description provided for @foundationMonthSep.
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get foundationMonthSep;

  /// No description provided for @foundationMonthOct.
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get foundationMonthOct;

  /// No description provided for @foundationMonthNov.
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get foundationMonthNov;

  /// No description provided for @foundationMonthDec.
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get foundationMonthDec;

  /// Layout of a short date in the facts panel. The caller passes the literal placeholders back, so the package can fill them.
  ///
  /// In en, this message translates to:
  /// **'{month} {day}, {year}'**
  String foundationDatePattern(String month, String day, String year);

  /// No description provided for @foundationWordSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get foundationWordSeeAll;

  /// No description provided for @foundationWordBecauseYouWatched.
  ///
  /// In en, this message translates to:
  /// **'Because you watched'**
  String get foundationWordBecauseYouWatched;

  /// No description provided for @foundationWordPlanToWatch.
  ///
  /// In en, this message translates to:
  /// **'Plan to Watch'**
  String get foundationWordPlanToWatch;

  /// No description provided for @foundationWordWatching.
  ///
  /// In en, this message translates to:
  /// **'Watching'**
  String get foundationWordWatching;

  /// No description provided for @foundationWordOnHold.
  ///
  /// In en, this message translates to:
  /// **'On Hold'**
  String get foundationWordOnHold;

  /// No description provided for @foundationWordCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get foundationWordCompleted;

  /// No description provided for @foundationWordDropped.
  ///
  /// In en, this message translates to:
  /// **'Dropped'**
  String get foundationWordDropped;

  /// No description provided for @foundationWordEpisodes.
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get foundationWordEpisodes;

  /// No description provided for @foundationWordReload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get foundationWordReload;

  /// No description provided for @foundationWordClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get foundationWordClose;

  /// No description provided for @foundationWordComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get foundationWordComingSoon;

  /// No description provided for @foundationWordScore.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get foundationWordScore;

  /// No description provided for @foundationWordAnyScore.
  ///
  /// In en, this message translates to:
  /// **'Any score'**
  String get foundationWordAnyScore;

  /// No description provided for @foundationWordYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get foundationWordYear;

  /// No description provided for @foundationWordAnyYear.
  ///
  /// In en, this message translates to:
  /// **'Any year'**
  String get foundationWordAnyYear;

  /// No description provided for @foundationWordGenre.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get foundationWordGenre;

  /// No description provided for @foundationWordCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get foundationWordCountry;

  /// No description provided for @foundationWordLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get foundationWordLanguage;

  /// No description provided for @foundationWordFilms.
  ///
  /// In en, this message translates to:
  /// **'Films'**
  String get foundationWordFilms;

  /// No description provided for @foundationWordSeries.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get foundationWordSeries;

  /// No description provided for @foundationWordAction.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get foundationWordAction;

  /// No description provided for @foundationWordAdventure.
  ///
  /// In en, this message translates to:
  /// **'Adventure'**
  String get foundationWordAdventure;

  /// No description provided for @foundationWordAnimation.
  ///
  /// In en, this message translates to:
  /// **'Animation'**
  String get foundationWordAnimation;

  /// No description provided for @foundationWordComedy.
  ///
  /// In en, this message translates to:
  /// **'Comedy'**
  String get foundationWordComedy;

  /// No description provided for @foundationWordCrime.
  ///
  /// In en, this message translates to:
  /// **'Crime'**
  String get foundationWordCrime;

  /// No description provided for @foundationWordDocumentary.
  ///
  /// In en, this message translates to:
  /// **'Documentary'**
  String get foundationWordDocumentary;

  /// No description provided for @foundationWordDrama.
  ///
  /// In en, this message translates to:
  /// **'Drama'**
  String get foundationWordDrama;

  /// No description provided for @foundationWordFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get foundationWordFamily;

  /// No description provided for @foundationWordFantasy.
  ///
  /// In en, this message translates to:
  /// **'Fantasy'**
  String get foundationWordFantasy;

  /// No description provided for @foundationWordHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get foundationWordHistory;

  /// No description provided for @foundationWordHorror.
  ///
  /// In en, this message translates to:
  /// **'Horror'**
  String get foundationWordHorror;

  /// No description provided for @foundationWordMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get foundationWordMusic;

  /// No description provided for @foundationWordMystery.
  ///
  /// In en, this message translates to:
  /// **'Mystery'**
  String get foundationWordMystery;

  /// No description provided for @foundationWordRomance.
  ///
  /// In en, this message translates to:
  /// **'Romance'**
  String get foundationWordRomance;

  /// No description provided for @foundationWordSciFi.
  ///
  /// In en, this message translates to:
  /// **'Sci-Fi'**
  String get foundationWordSciFi;

  /// No description provided for @foundationWordThriller.
  ///
  /// In en, this message translates to:
  /// **'Thriller'**
  String get foundationWordThriller;

  /// No description provided for @foundationWordWar.
  ///
  /// In en, this message translates to:
  /// **'War'**
  String get foundationWordWar;

  /// No description provided for @foundationWordWestern.
  ///
  /// In en, this message translates to:
  /// **'Western'**
  String get foundationWordWestern;

  /// No description provided for @foundationWordKids.
  ///
  /// In en, this message translates to:
  /// **'Kids'**
  String get foundationWordKids;

  /// No description provided for @foundationWordUsa.
  ///
  /// In en, this message translates to:
  /// **'USA'**
  String get foundationWordUsa;

  /// No description provided for @foundationWordUk.
  ///
  /// In en, this message translates to:
  /// **'UK'**
  String get foundationWordUk;

  /// No description provided for @foundationWordFrance.
  ///
  /// In en, this message translates to:
  /// **'France'**
  String get foundationWordFrance;

  /// No description provided for @foundationWordGermany.
  ///
  /// In en, this message translates to:
  /// **'Germany'**
  String get foundationWordGermany;

  /// No description provided for @foundationWordJapan.
  ///
  /// In en, this message translates to:
  /// **'Japan'**
  String get foundationWordJapan;

  /// No description provided for @foundationWordKorea.
  ///
  /// In en, this message translates to:
  /// **'Korea'**
  String get foundationWordKorea;

  /// No description provided for @foundationWordIndia.
  ///
  /// In en, this message translates to:
  /// **'India'**
  String get foundationWordIndia;

  /// No description provided for @foundationWordItaly.
  ///
  /// In en, this message translates to:
  /// **'Italy'**
  String get foundationWordItaly;

  /// No description provided for @foundationWordSpain.
  ///
  /// In en, this message translates to:
  /// **'Spain'**
  String get foundationWordSpain;

  /// No description provided for @foundationWordCanada.
  ///
  /// In en, this message translates to:
  /// **'Canada'**
  String get foundationWordCanada;

  /// No description provided for @foundationWordAustralia.
  ///
  /// In en, this message translates to:
  /// **'Australia'**
  String get foundationWordAustralia;

  /// No description provided for @foundationWordChina.
  ///
  /// In en, this message translates to:
  /// **'China'**
  String get foundationWordChina;

  /// No description provided for @foundationWordBrazil.
  ///
  /// In en, this message translates to:
  /// **'Brazil'**
  String get foundationWordBrazil;

  /// No description provided for @foundationWordMexico.
  ///
  /// In en, this message translates to:
  /// **'Mexico'**
  String get foundationWordMexico;

  /// No description provided for @foundationWordSweden.
  ///
  /// In en, this message translates to:
  /// **'Sweden'**
  String get foundationWordSweden;

  /// No description provided for @foundationWordNorway.
  ///
  /// In en, this message translates to:
  /// **'Norway'**
  String get foundationWordNorway;

  /// No description provided for @foundationWordDenmark.
  ///
  /// In en, this message translates to:
  /// **'Denmark'**
  String get foundationWordDenmark;

  /// No description provided for @foundationWordTurkey.
  ///
  /// In en, this message translates to:
  /// **'Turkey'**
  String get foundationWordTurkey;

  /// No description provided for @foundationWordHongKong.
  ///
  /// In en, this message translates to:
  /// **'Hong Kong'**
  String get foundationWordHongKong;

  /// No description provided for @foundationWordTaiwan.
  ///
  /// In en, this message translates to:
  /// **'Taiwan'**
  String get foundationWordTaiwan;

  /// No description provided for @foundationWordThailand.
  ///
  /// In en, this message translates to:
  /// **'Thailand'**
  String get foundationWordThailand;

  /// No description provided for @foundationWordEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get foundationWordEnglish;

  /// No description provided for @foundationWordJapanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get foundationWordJapanese;

  /// No description provided for @foundationWordKorean.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get foundationWordKorean;

  /// No description provided for @foundationWordFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get foundationWordFrench;

  /// No description provided for @foundationWordSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get foundationWordSpanish;

  /// No description provided for @foundationWordGerman.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get foundationWordGerman;

  /// No description provided for @foundationWordItalian.
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get foundationWordItalian;

  /// No description provided for @foundationWordPortuguese.
  ///
  /// In en, this message translates to:
  /// **'Portuguese'**
  String get foundationWordPortuguese;

  /// No description provided for @foundationWordChinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get foundationWordChinese;

  /// No description provided for @foundationWordHindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get foundationWordHindi;

  /// No description provided for @foundationWordArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get foundationWordArabic;

  /// No description provided for @foundationWordTurkish.
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get foundationWordTurkish;

  /// No description provided for @foundationWordThai.
  ///
  /// In en, this message translates to:
  /// **'Thai'**
  String get foundationWordThai;

  /// No description provided for @foundationWordSwedish.
  ///
  /// In en, this message translates to:
  /// **'Swedish'**
  String get foundationWordSwedish;

  /// No description provided for @foundationWordNorwegian.
  ///
  /// In en, this message translates to:
  /// **'Norwegian'**
  String get foundationWordNorwegian;

  /// No description provided for @foundationWordDanish.
  ///
  /// In en, this message translates to:
  /// **'Danish'**
  String get foundationWordDanish;

  /// No description provided for @foundationWordSub.
  ///
  /// In en, this message translates to:
  /// **'SUB'**
  String get foundationWordSub;

  /// No description provided for @foundationWordDub.
  ///
  /// In en, this message translates to:
  /// **'DUB'**
  String get foundationWordDub;

  /// No description provided for @foundationWordRuntimeHours.
  ///
  /// In en, this message translates to:
  /// **'h'**
  String get foundationWordRuntimeHours;

  /// No description provided for @foundationWordRuntimeMinutes.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get foundationWordRuntimeMinutes;

  /// No description provided for @foundationWordThousandsSeparator.
  ///
  /// In en, this message translates to:
  /// **'comma'**
  String get foundationWordThousandsSeparator;

  /// No description provided for @foundationWordMoneySymbol.
  ///
  /// In en, this message translates to:
  /// **'\$'**
  String get foundationWordMoneySymbol;

  /// No description provided for @foundationWordMoneySymbolPlace.
  ///
  /// In en, this message translates to:
  /// **'before'**
  String get foundationWordMoneySymbolPlace;

  /// No description provided for @foundationWordTrailers.
  ///
  /// In en, this message translates to:
  /// **'Trailers'**
  String get foundationWordTrailers;

  /// No description provided for @foundationWordOfficial.
  ///
  /// In en, this message translates to:
  /// **'Official'**
  String get foundationWordOfficial;

  /// No description provided for @foundationWordGeoblocked.
  ///
  /// In en, this message translates to:
  /// **'Geoblocked'**
  String get foundationWordGeoblocked;

  /// No description provided for @foundationWordEnds.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get foundationWordEnds;

  /// No description provided for @foundationWordClock.
  ///
  /// In en, this message translates to:
  /// **'12h'**
  String get foundationWordClock;

  /// No description provided for @foundationWordLanguageNames.
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get foundationWordLanguageNames;

  /// No description provided for @authSupabaseNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Supabase is not configured for this build.'**
  String get authSupabaseNotConfigured;

  /// No description provided for @authWebLoginNoTokens.
  ///
  /// In en, this message translates to:
  /// **'Web login did not return usable tokens.'**
  String get authWebLoginNoTokens;

  /// No description provided for @authWebLoginNoSession.
  ///
  /// In en, this message translates to:
  /// **'Web login did not return a usable session.'**
  String get authWebLoginNoSession;

  /// No description provided for @authSignInToCreateProfile.
  ///
  /// In en, this message translates to:
  /// **'Sign in to create a profile.'**
  String get authSignInToCreateProfile;

  /// No description provided for @authEnterProfileName.
  ///
  /// In en, this message translates to:
  /// **'Enter a profile name.'**
  String get authEnterProfileName;

  /// No description provided for @authMaxProfiles.
  ///
  /// In en, this message translates to:
  /// **'Maximum of 5 profiles per account.'**
  String get authMaxProfiles;

  /// No description provided for @authCouldNotCreateProfile.
  ///
  /// In en, this message translates to:
  /// **'Could not create profile.'**
  String get authCouldNotCreateProfile;

  /// No description provided for @authSignInToEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Sign in to edit a profile.'**
  String get authSignInToEditProfile;

  /// No description provided for @authCouldNotSaveProfile.
  ///
  /// In en, this message translates to:
  /// **'Could not save profile.'**
  String get authCouldNotSaveProfile;

  /// No description provided for @authSignInToDeleteProfile.
  ///
  /// In en, this message translates to:
  /// **'Sign in to delete a profile.'**
  String get authSignInToDeleteProfile;

  /// No description provided for @authEveryAccountNeedsProfile.
  ///
  /// In en, this message translates to:
  /// **'Every account needs one profile.'**
  String get authEveryAccountNeedsProfile;

  /// No description provided for @authCouldNotDeleteProfile.
  ///
  /// In en, this message translates to:
  /// **'Could not delete profile.'**
  String get authCouldNotDeleteProfile;

  /// No description provided for @authTvLinkNoCode.
  ///
  /// In en, this message translates to:
  /// **'TV linking did not return a usable code.'**
  String get authTvLinkNoCode;

  /// No description provided for @packsInstallNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing to install'**
  String get packsInstallNothing;

  /// No description provided for @packsInstallInstalling.
  ///
  /// In en, this message translates to:
  /// **'Installing {label} ({index}/{total})…'**
  String packsInstallInstalling(String label, int index, int total);

  /// No description provided for @packsInstallActivating.
  ///
  /// In en, this message translates to:
  /// **'Activating Features…'**
  String get packsInstallActivating;

  /// No description provided for @portalsChipLabel.
  ///
  /// In en, this message translates to:
  /// **'Portals'**
  String get portalsChipLabel;

  /// No description provided for @settingsLiveSportsChip.
  ///
  /// In en, this message translates to:
  /// **'Live Sports'**
  String get settingsLiveSportsChip;

  /// No description provided for @engineScheduleLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get engineScheduleLoading;

  /// No description provided for @engineScheduleLoadingNamed.
  ///
  /// In en, this message translates to:
  /// **'Loading {name}… {index}/{total}'**
  String engineScheduleLoadingNamed(String name, int index, int total);

  /// No description provided for @pluginSyncProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'Syncing plugins…'**
  String get pluginSyncProgressLabel;

  /// No description provided for @foundationWordSearchChannels.
  ///
  /// In en, this message translates to:
  /// **'Search channels'**
  String get foundationWordSearchChannels;

  /// No description provided for @foundationWordSearchChannelsHint.
  ///
  /// In en, this message translates to:
  /// **'Search channels…'**
  String get foundationWordSearchChannelsHint;

  /// No description provided for @foundationWordSearchChannelsOrCategoriesHint.
  ///
  /// In en, this message translates to:
  /// **'Search channels or categories…'**
  String get foundationWordSearchChannelsOrCategoriesHint;

  /// No description provided for @foundationWordEpisodeRange.
  ///
  /// In en, this message translates to:
  /// **'Episode range'**
  String get foundationWordEpisodeRange;

  /// No description provided for @foundationWordYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get foundationWordYes;

  /// No description provided for @foundationWordNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get foundationWordNo;

  /// No description provided for @foundationWordCopyShareCode.
  ///
  /// In en, this message translates to:
  /// **'Copy share code'**
  String get foundationWordCopyShareCode;

  /// No description provided for @foundationWordEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get foundationWordEdit;

  /// No description provided for @foundationWordDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get foundationWordDelete;

  /// No description provided for @foundationWordCards.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get foundationWordCards;

  /// No description provided for @foundationWordNumberChips.
  ///
  /// In en, this message translates to:
  /// **'Number chips'**
  String get foundationWordNumberChips;

  /// No description provided for @foundationWordMovies.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get foundationWordMovies;

  /// No description provided for @foundationWordTv.
  ///
  /// In en, this message translates to:
  /// **'TV'**
  String get foundationWordTv;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
