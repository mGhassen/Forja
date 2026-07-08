/// Classic TMDB genre filters for the Home top-bar Categories menu.
const homeGenreCategories = <({
  String id,
  String label,
  List<int> movieGenres,
  List<int> tvGenres,
})>[
  (id: 'action', label: 'Action', movieGenres: [28], tvGenres: [10759]),
  (id: 'adventure', label: 'Adventure', movieGenres: [12], tvGenres: [10759]),
  (id: 'animation', label: 'Animation', movieGenres: [16], tvGenres: [16]),
  (id: 'comedy', label: 'Comedy', movieGenres: [35], tvGenres: [35]),
  (id: 'crime', label: 'Crime', movieGenres: [80], tvGenres: [80]),
  (id: 'documentary', label: 'Documentary', movieGenres: [99], tvGenres: [99]),
  (id: 'drama', label: 'Drama', movieGenres: [18], tvGenres: [18]),
  (id: 'family', label: 'Family', movieGenres: [10751], tvGenres: [10751]),
  (id: 'fantasy', label: 'Fantasy', movieGenres: [14], tvGenres: [10765]),
  (id: 'horror', label: 'Horror', movieGenres: [27], tvGenres: [9648]),
  (id: 'music', label: 'Music', movieGenres: [10402], tvGenres: [10402]),
  (id: 'mystery', label: 'Mystery', movieGenres: [9648], tvGenres: [9648]),
  (id: 'romance', label: 'Romance', movieGenres: [10749], tvGenres: [10749]),
  (id: 'scifi', label: 'Sci-Fi', movieGenres: [878], tvGenres: [10765]),
  (id: 'thriller', label: 'Thriller', movieGenres: [53], tvGenres: [80]),
  (id: 'war', label: 'War', movieGenres: [10752], tvGenres: [10768]),
];

({List<int> movieGenres, List<int> tvGenres})? lookupHomeGenre(String? id) {
  if (id == null) return null;
  for (final genre in homeGenreCategories) {
    if (genre.id == id) {
      return (movieGenres: genre.movieGenres, tvGenres: genre.tvGenres);
    }
  }
  return null;
}

String? homeGenreLabel(String? id) {
  if (id == null) return null;
  for (final genre in homeGenreCategories) {
    if (genre.id == id) return genre.label;
  }
  return null;
}
