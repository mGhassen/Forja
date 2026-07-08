class MediaTrailer {
  const MediaTrailer({
    required this.key,
    required this.name,
    required this.type,
    this.official = false,
    this.site = 'YouTube',
  });

  final String key;
  final String name;
  final String type;
  final bool official;
  final String site;

  String get youtubeThumbnail => 'https://img.youtube.com/vi/$key/hqdefault.jpg';

  String get youtubeUrl => 'https://www.youtube.com/watch?v=$key';
}
