class WatchProvider {
  const WatchProvider({
    required this.id,
    required this.name,
    required this.logoPath,
  });

  final int id;
  final String name;
  final String logoPath;

  /// Small chrome (chip / before Films). w185 stays sharp on 2–3x displays.
  String get logoUrl => 'https://image.tmdb.org/t/p/w185$logoPath';

  /// Strip cards — TMDB logos are brand marks, not fill art; pair with contain.
  String get logoCardUrl => 'https://image.tmdb.org/t/p/w500$logoPath';

  factory WatchProvider.fromJson(Map<String, dynamic> json) {
    return WatchProvider(
      id: json['provider_id'] as int,
      name: json['provider_name'] as String? ?? '',
      logoPath: json['logo_path'] as String? ?? '',
    );
  }
}
