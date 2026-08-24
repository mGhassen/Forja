/// AniList genre filters for the Anime hub Categories menu.
const animeGenreCategories = <({String id, String label})>[
  (id: 'action', label: 'Action'),
  (id: 'adventure', label: 'Adventure'),
  (id: 'comedy', label: 'Comedy'),
  (id: 'drama', label: 'Drama'),
  (id: 'ecchi', label: 'Ecchi'),
  (id: 'fantasy', label: 'Fantasy'),
  (id: 'horror', label: 'Horror'),
  (id: 'mahou_shoujo', label: 'Mahou Shoujo'),
  (id: 'mecha', label: 'Mecha'),
  (id: 'music', label: 'Music'),
  (id: 'mystery', label: 'Mystery'),
  (id: 'psychological', label: 'Psychological'),
  (id: 'romance', label: 'Romance'),
  (id: 'scifi', label: 'Sci-Fi'),
  (id: 'slice_of_life', label: 'Slice of Life'),
  (id: 'sports', label: 'Sports'),
  (id: 'supernatural', label: 'Supernatural'),
  (id: 'thriller', label: 'Thriller'),
];

String? animeGenreLabel(String? id) {
  if (id == null) return null;
  for (final g in animeGenreCategories) {
    if (g.id == id) return g.label;
  }
  return null;
}
