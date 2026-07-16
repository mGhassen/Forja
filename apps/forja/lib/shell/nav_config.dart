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

class NavDestination {
  const NavDestination({
    required this.id,
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.iconAsset,
  });

  final String id;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String? iconAsset;
}

class NavDestinationIcon extends StatelessWidget {
  const NavDestinationIcon({
    super.key,
    required this.destination,
    required this.selected,
    required this.color,
    this.size = 24,
  });

  final NavDestination destination;
  final bool selected;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = destination.iconAsset;
    if (asset != null) {
      return ColorFiltered(
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        child: Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      );
    }
    return Icon(
      selected ? destination.activeIcon : destination.icon,
      color: color,
      size: size,
    );
  }
}

/// Tabs withheld from the shell and Settings → Navigation for now.
/// Destinations and [navTabBuilders] stay registered — remove an ID here to restore.
const Set<String> temporarilyHiddenNavIds = {
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
  'arabic',
};

/// Single source of nav item metadata keyed by nav ID.
const Map<String, NavDestination> navDestinations = {
  'home': NavDestination(
    id: 'home',
    icon: Icons.home_outlined,
    activeIcon: Icons.home,
    label: 'Home',
    iconAsset: 'assets/images/nav/home.png',
  ),
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
    label: 'Live Matches',
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
  'anime': NavDestination(
    id: 'anime',
    icon: Icons.animation_outlined,
    activeIcon: Icons.animation,
    label: 'Anime',
    iconAsset: 'assets/images/nav/anime.png',
  ),
  'anime_arabic': NavDestination(
    id: 'anime_arabic',
    icon: Icons.subtitles_outlined,
    activeIcon: Icons.subtitles,
    label: 'Anime Arabic',
  ),
  'asian_drama': NavDestination(
    id: 'asian_drama',
    icon: Icons.theater_comedy_outlined,
    activeIcon: Icons.theater_comedy,
    label: 'Asian Drama',
    iconAsset: 'assets/images/nav/asian-drama.png',
  ),
  'arabic': NavDestination(
    id: 'arabic',
    icon: Icons.movie_filter_outlined,
    activeIcon: Icons.movie_filter,
    label: 'Arabic',
  ),
  'settings': NavDestination(
    id: 'settings',
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings,
    label: 'Settings',
  ),
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
