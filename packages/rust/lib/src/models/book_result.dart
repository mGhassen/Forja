class BookResult {
  final String title;
  final String series;
  final String author;
  final String publisher;
  final String year;
  final String language;
  final String pages;
  final String size;
  final String format;
  final String isbn;
  final String editionId;
  final String editionUrl;
  final String fileId;
  final List<Map<String, String>> downloadLinks;

  const BookResult({
    required this.title,
    required this.series,
    required this.author,
    required this.publisher,
    required this.year,
    required this.language,
    required this.pages,
    required this.size,
    required this.format,
    required this.isbn,
    required this.editionId,
    required this.editionUrl,
    required this.fileId,
    required this.downloadLinks,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'series': series,
        'author': author,
        'publisher': publisher,
        'year': year,
        'language': language,
        'pages': pages,
        'size': size,
        'format': format,
        'isbn': isbn,
        'editionId': editionId,
        'editionUrl': editionUrl,
        'fileId': fileId,
        'downloadLinks': downloadLinks,
      };

  factory BookResult.fromJson(Map<String, dynamic> json) => BookResult(
        title: json['title'] ?? '',
        series: json['series'] ?? '',
        author: json['author'] ?? '',
        publisher: json['publisher'] ?? '',
        year: json['year'] ?? '',
        language: json['language'] ?? '',
        pages: json['pages'] ?? '',
        size: json['size'] ?? '',
        format: json['format'] ?? '',
        isbn: json['isbn'] ?? '',
        editionId: json['editionId'] ?? '',
        editionUrl: json['editionUrl'] ?? '',
        fileId: json['fileId'] ?? '',
        downloadLinks: (json['downloadLinks'] as List<dynamic>?)
                ?.map((e) => Map<String, String>.from(e as Map))
                .toList() ??
            [],
      );
}
