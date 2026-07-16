class WatchProvider {
  const WatchProvider({
    required this.id,
    required this.name,
    required this.logoPath,
  });

  final int id;
  final String name;
  final String logoPath;

  String get logoUrl => 'https://image.tmdb.org/t/p/w92$logoPath';

  /// Higher-res tile for top-bar cards (fills the card).
  String get logoCardUrl => 'https://image.tmdb.org/t/p/w300$logoPath';

  factory WatchProvider.fromJson(Map<String, dynamic> json) {
    return WatchProvider(
      id: json['provider_id'] as int,
      name: json['provider_name'] as String? ?? '',
      logoPath: json['logo_path'] as String? ?? '',
    );
  }
}
