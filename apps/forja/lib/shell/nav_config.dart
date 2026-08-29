import 'package:flutter/material.dart';
import 'package:forja/features/discover/discover_screen.dart';
import 'package:forja/features/search/search_screen.dart';
import 'package:forja/features/my_list/my_list_screen.dart';
import 'package:forja/features/settings/settings_screen.dart';
import 'package:forja/features/music/music_screen.dart';
import 'package:forja/features/audiobooks/audiobook_screen.dart';
import 'package:forja/features/books/books_screen.dart';
import 'package:forja/features/comics/comics_screen.dart';
import 'package:forja/features/manga/manga_screen.dart';
import 'package:forja/features/jellyfin/jellyfin_screen.dart';
import 'package:forja/features/anime_arabic/anime_arabic_screen.dart';
import 'package:forja/features/similar/similar_hub_screen.dart';
import 'package:forja/features/downloader/media_downloader_screen.dart';
import 'package:forja/features/live_matches/live_matches_screen.dart';
import 'package:forja/features/magnet/magnet_player_screen.dart';
import 'package:forja/features/iptv/iptv/screens/iptv_pt_screen.dart';
import 'package:forja/shared/catalog/plugin_nav.dart';
import 'package:forja/shell/nav_destination.dart';

export 'package:forja/shell/nav_destination.dart';

/// Tabs withheld from the shell and Settings → Features for now.
/// Destinations and [navTabBuilders] stay registered - remove an ID here to restore.
const Set<String> temporarilyHiddenNavIds = {
  'search',
  'discover',
  'similar',
  'downloader',
  'magnet',
  'audiobooks',
  'books',
  'music',
  'comics',
  'manga',
  'jellyfin',
  'anime_arabic',
};

/// App-owned shell destinations (not catalog hubs).
const Map<String, NavDestination> coreNavDestinations = {
  'discover': NavDestination(
    id: 'discover',
    icon: Icons.explore_outlined,
    activeIcon: Icons.explore,
    label: 'Discover',
  ),
  'similar': NavDestination(
    id: 'similar',
    icon: Icons.auto_awesome_outlined,
    activeIcon: Icons.auto_awesome,
    label: 'Similar',
  ),
  'downloader': NavDestination(
    id: 'downloader',
    icon: Icons.cloud_download_outlined,
    activeIcon: Icons.cloud_download,
    label: 'Media Downloader',
  ),
  'search': NavDestination(
    id: 'search',
    icon: Icons.search,
    activeIcon: Icons.search,
    label: 'Search',
    iconAsset: 'assets/images/nav/search.png',
  ),
  'mylist': NavDestination(
    id: 'mylist',
    icon: Icons.bookmark_outline,
    activeIcon: Icons.bookmark,
    label: 'My List',
  ),
  'magnet': NavDestination(
    id: 'magnet',
    icon: Icons.link_rounded,
    activeIcon: Icons.link_rounded,
    label: 'Magnet',
  ),
  'live_matches': NavDestination(
    id: 'live_matches',
    icon: Icons.sports_soccer_outlined,
    activeIcon: Icons.sports_soccer_rounded,
    label: 'Live Sports',
    iconAsset: 'assets/images/nav/live-matches.png',
  ),
  'iptv': NavDestination(
    id: 'iptv',
    icon: Icons.live_tv_outlined,
    activeIcon: Icons.live_tv,
    label: 'IPTV',
    iconAsset: 'assets/images/nav/iptv.png',
  ),
  'audiobooks': NavDestination(
    id: 'audiobooks',
    icon: Icons.menu_book_outlined,
    activeIcon: Icons.menu_book,
    label: 'Audiobooks',
  ),
  'books': NavDestination(
    id: 'books',
    icon: Icons.import_contacts_rounded,
    activeIcon: Icons.import_contacts_rounded,
    label: 'Books',
  ),
  'music': NavDestination(
    id: 'music',
    icon: Icons.music_note_outlined,
    activeIcon: Icons.music_note,
    label: 'Music',
  ),
  'comics': NavDestination(
    id: 'comics',
    icon: Icons.auto_stories_outlined,
    activeIcon: Icons.auto_stories,
    label: 'Comics',
  ),
  'manga': NavDestination(
    id: 'manga',
    icon: Icons.book_outlined,
    activeIcon: Icons.book,
    label: 'Manga',
  ),
  'jellyfin': NavDestination(
    id: 'jellyfin',
    icon: Icons.dns_outlined,
    activeIcon: Icons.dns_rounded,
    label: 'Jellyfin',
  ),
  'anime_arabic': NavDestination(
    id: 'anime_arabic',
    icon: Icons.subtitles_outlined,
    activeIcon: Icons.subtitles,
    label: 'Anime Arabic',
  ),
  'settings': NavDestination(
    id: 'settings',
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings,
    label: 'Settings',
  ),
};

/// Core + hub destinations from [PluginNavRegistry] (plugin `nav` specs).
Map<String, NavDestination> get navDestinations => {
      ...coreNavDestinations,
      ...PluginNavRegistry.destinations,
    };

/// Rail accents (desktop + Android TV). Icons stay neutral while idle and
/// reveal their destination color when selected, hovered, or D-pad focused.
const Map<String, Color> coreNavDestinationAccentColors = {
  'discover': Color(0xFF2DD4BF),
  'similar': Color(0xFFA78BFA),
  'downloader': Color(0xFF38BDF8),
  'search': Color(0xFF60A5FA),
  'mylist': Color(0xFFFBBF24),
  'magnet': Color(0xFFF472B6),
  'live_matches': Color(0xFFFB923C),
  'iptv': Color(0xFF22D3EE),
  'audiobooks': Color(0xFFC084FC),
  'books': Color(0xFFD97706),
  'music': Color(0xFFEC4899),
  'comics': Color(0xFFF97316),
  'manga': Color(0xFFE879F9),
  'jellyfin': Color(0xFF8B5CF6),
  'anime_arabic': Color(0xFF34D399),
  'settings': Color(0xFF94A3B8),
};

Map<String, Color> get navDestinationAccentColors => {
      ...coreNavDestinationAccentColors,
      ...PluginNavRegistry.accents,
    };

/// Lazy tab factories - widgets are created on first visit only.
const Map<String, TabBuilder> coreNavTabBuilders = {
  'discover': DiscoverScreen.new,
  'similar': SimilarHubScreen.new,
  'downloader': MediaDownloaderScreen.new,
  'search': SearchScreen.new,
  'mylist': MyListScreen.new,
  'magnet': MagnetPlayerScreen.new,
  'live_matches': LiveMatchesScreen.new,
  'iptv': IptvPtScreen.new,
  'audiobooks': AudiobookScreen.new,
  'books': BooksScreen.new,
  'music': MusicScreen.new,
  'comics': _comicsTab,
  'manga': _mangaTab,
  'jellyfin': JellyfinScreen.new,
  'anime_arabic': AnimeArabicScreen.new,
  'settings': SettingsScreen.new,
};

Widget _comicsTab() => ComicsScreen(initialSearch: null);
Widget _mangaTab() => MangaScreen(initialSearch: null);

/// Core builders + catalog hub builders from [PluginNavRegistry].
Map<String, TabBuilder> get navTabBuilders => {
      ...coreNavTabBuilders,
      ...PluginNavRegistry.builders,
    };
