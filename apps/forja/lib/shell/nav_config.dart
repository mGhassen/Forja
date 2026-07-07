import 'package:flutter/material.dart';
import 'package:forja/features/home/home_screen.dart';
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
import 'package:forja/features/anime/anime_screen.dart';
import 'package:forja/features/anime_arabic/anime_arabic_screen.dart';
import 'package:forja/features/asian_drama/asian_drama_screen.dart';
import 'package:forja/features/similar/similar_hub_screen.dart';
import 'package:forja/features/downloader/media_downloader_screen.dart';
import 'package:forja/features/arabic/arabic_screen.dart';
import 'package:forja/features/live_matches/live_matches_screen.dart';
import 'package:forja/features/magnet/magnet_player_screen.dart';
import 'package:forja/features/iptv/iptv/screens/iptv_pt_screen.dart';

/// Nav item metadata keyed by nav ID.
const Map<String, Map<String, dynamic>> navMeta = {
  'home':         {'icon': Icons.home_outlined,              'active': Icons.home,                    'label': 'Home'},
  'discover':     {'icon': Icons.explore_outlined,            'active': Icons.explore,                 'label': 'Discover'},
  'similar':      {'icon': Icons.auto_awesome_outlined, 'active': Icons.auto_awesome, 'label': 'Similar'},
  'downloader':   {'icon': Icons.cloud_download_outlined, 'active': Icons.cloud_download, 'label': 'Media Downloader'},
  'search':       {'icon': Icons.search,                      'active': Icons.search,                  'label': 'Search'},
  'mylist':       {'icon': Icons.bookmark_outline,            'active': Icons.bookmark,                'label': 'My List'},
  'magnet':       {'icon': Icons.link_rounded,                'active': Icons.link_rounded,            'label': 'Magnet'},
  'live_matches': {'icon': Icons.sports_soccer_outlined,      'active': Icons.sports_soccer_rounded,   'label': 'Live Matches'},
  'iptv':         {'icon': Icons.live_tv_outlined,            'active': Icons.live_tv,                 'label': 'IPTV'},
  'audiobooks':   {'icon': Icons.menu_book_outlined,          'active': Icons.menu_book,               'label': 'Audiobooks'},
  'books':        {'icon': Icons.import_contacts_rounded,     'active': Icons.import_contacts_rounded, 'label': 'Books'},
  'music':        {'icon': Icons.music_note_outlined,         'active': Icons.music_note,              'label': 'Music'},
  'comics':       {'icon': Icons.auto_stories_outlined,       'active': Icons.auto_stories,            'label': 'Comics'},
  'manga':        {'icon': Icons.book_outlined,               'active': Icons.book,                    'label': 'Manga'},
  'jellyfin':     {'icon': Icons.dns_outlined,                'active': Icons.dns_rounded,             'label': 'Jellyfin'},
  'anime':        {'icon': Icons.play_circle_outline,         'active': Icons.play_circle_filled,      'label': 'Anime'},
  'anime_arabic': {'icon': Icons.subtitles_outlined,           'active': Icons.subtitles,                'label': 'Anime Arabic'},
  'asian_drama':  {'icon': Icons.theater_comedy_outlined,     'active': Icons.theater_comedy,          'label': 'Asian Drama'},
  'arabic':       {'icon': Icons.movie_filter_outlined,       'active': Icons.movie_filter,            'label': 'Arabic'},
  'settings':     {'icon': Icons.settings_outlined,           'active': Icons.settings,                'label': 'Settings'},
};

typedef TabBuilder = Widget Function();

/// Lazy tab factories — widgets are created on first visit only.
final Map<String, TabBuilder> navTabBuilders = {
  'home': () => const HomeScreen(),
  'discover': () => const DiscoverScreen(),
  'similar': () => const SimilarHubScreen(),
  'downloader': () => const MediaDownloaderScreen(),
  'search': () => const SearchScreen(),
  'mylist': () => const MyListScreen(),
  'magnet': () => const MagnetPlayerScreen(),
  'live_matches': () => const LiveMatchesScreen(),
  'iptv': () => const IptvPtScreen(),
  'audiobooks': () => const AudiobookScreen(),
  'books': () => const BooksScreen(),
  'music': () => const MusicScreen(),
  'comics': () => ComicsScreen(initialSearch: null),
  'manga': () => MangaScreen(initialSearch: null),
  'jellyfin': () => const JellyfinScreen(),
  'anime': () => const AnimeScreen(),
  'anime_arabic': () => const AnimeArabicScreen(),
  'asian_drama': () => const AsianDramaScreen(),
  'arabic': () => const ArabicScreen(),
  'settings': () => const SettingsScreen(),
};
