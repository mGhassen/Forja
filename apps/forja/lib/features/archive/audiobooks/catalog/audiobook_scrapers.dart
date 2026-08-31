import 'package:html/parser.dart' as hp;

class AudiobookChapterHit {
  final String title;
  final String url;

  const AudiobookChapterHit({required this.title, required this.url});
}

class AudiobookBrowseHit {
  final String pageUrl;
  final String title;
  final String coverUrl;

  const AudiobookBrowseHit({
    required this.pageUrl,
    required this.title,
    this.coverUrl = '',
  });
}

const zaudiobooksAudioBase = 'https://files01.freeaudiobooks.top/audio/';

String stripAudioQuery(String url) {
  final q = url.indexOf('?');
  return q >= 0 ? url.substring(0, q) : url;
}

List<AudiobookChapterHit> parseZaudiobooksTracksFromHtml(String html) {
  final lines = html.split('\n');
  var startIndex = -1;
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].contains('tracks = [')) {
      startIndex = i;
      break;
    }
  }
  if (startIndex < 0) return [];

  final chapters = <AudiobookChapterHit>[];
  var skipTrack = false;

  for (var i = startIndex; i < lines.length; i++) {
    final line = lines[i];
    if (line.contains('name')) {
      final nameMatch = RegExp(r'name:\s*"?([^",]+)"?').firstMatch(line);
      final name = nameMatch?.group(1)?.trim().toLowerCase() ?? '';
      skipTrack = name == 'welcome';
    }
    if (line.contains('chapter_link_dropbox')) {
      if (skipTrack) continue;
      final linkMatch =
          RegExp(r'chapter_link_dropbox:\s*"?([^",]+)"?').firstMatch(line);
      final link = linkMatch?.group(1)?.trim() ?? '';
      if (link.isEmpty) continue;
      final chapterNumber = chapters.length + 1;
      chapters.add(AudiobookChapterHit(
        title: 'Chapter ${chapterNumber.toString().padLeft(3, '0')}',
        url: '$zaudiobooksAudioBase$link',
      ));
    }
    if (line.contains('],')) break;
  }
  return chapters;
}

List<AudiobookChapterHit> parseMpegSourcesFromHtml(
  String html,
  String selector,
) {
  final document = hp.parse(html);
  final sources = document.querySelectorAll(selector);
  final chapters = <AudiobookChapterHit>[];
  for (var i = 0; i < sources.length; i++) {
    final src = sources[i].attributes['src'] ?? '';
    if (src.isEmpty) continue;
    chapters.add(AudiobookChapterHit(
      title: 'Chapter ${(i + 1).toString().padLeft(3, '0')}',
      url: stripAudioQuery(src),
    ));
  }
  return chapters;
}

List<AudiobookChapterHit> parseHdAudiobooksChaptersFromHtml(String html) {
  final fromEntry = parseMpegSourcesFromHtml(html, '.entry source[type="audio/mpeg"]');
  if (fromEntry.isNotEmpty) return fromEntry;
  return parseMpegSourcesFromHtml(html, '.entry-box source[type="audio/mpeg"]');
}

List<AudiobookBrowseHit> parseGoldenBrowseFromHtml(String html) {
  final document = hp.parse(html);
  final ptCvLinks = document.querySelectorAll('div.pt-cv-title a');
  if (ptCvLinks.isNotEmpty) {
    return _browseHitsFromLinks(ptCvLinks);
  }

  final hits = <AudiobookBrowseHit>[];
  for (final article in document.querySelectorAll('li.ilovewp-post')) {
    final titleElement = article.querySelector('h2.title-post a');
    final pageUrl = titleElement?.attributes['href'] ?? '';
    final title = titleElement?.text.trim() ?? '';
    if (pageUrl.isEmpty || title.isEmpty) continue;
    final img = article.querySelector('div.post-cover img');
    var cover = img?.attributes['data-src'] ?? img?.attributes['src'] ?? '';
    cover = upscaleCoverUrl(cover);
    hits.add(AudiobookBrowseHit(pageUrl: pageUrl, title: title, coverUrl: cover));
  }
  return hits;
}

List<AudiobookBrowseHit> parseFulllengthBrowseFromHtml(String html) {
  final document = hp.parse(html);
  final links = document.querySelectorAll(
    'h2.entry-title a, h1.entry-title a, article h2 a',
  );
  return _browseHitsFromLinks(links);
}

List<AudiobookBrowseHit> parseHdBrowseFromHtml(String html) {
  final document = hp.parse(html);
  final articleLinks = document.querySelectorAll('article h2 a');
  if (articleLinks.isNotEmpty) {
    return _browseHitsFromLinks(articleLinks);
  }
  final links = document.querySelectorAll(
    'h1[itemprop="headline"] a, article h1 a, h2.entry-title a',
  );
  return _browseHitsFromLinks(links);
}

List<AudiobookBrowseHit> parseAudiozaicBrowseFromHtml(String html) {
  final document = hp.parse(html);
  final hits = <AudiobookBrowseHit>[];
  for (final article in document.querySelectorAll('article.vce-post')) {
    final titleElement = article.querySelector('h2.entry-title a');
    final pageUrl = titleElement?.attributes['href'] ?? '';
    final title = titleElement?.text.trim() ?? '';
    if (pageUrl.isEmpty || title.isEmpty) continue;
    final img = article.querySelector('div.meta-image img');
    var cover = img?.attributes['data-src'] ?? img?.attributes['src'] ?? '';
    cover = upscaleCoverUrl(cover);
    hits.add(AudiobookBrowseHit(pageUrl: pageUrl, title: title, coverUrl: cover));
  }
  return hits;
}

List<AudiobookBrowseHit> parseBigBrowseFromHtml(String html) {
  final document = hp.parse(html);
  final links = document.querySelectorAll(
    'h1.title-page a, h2.entry-title a, article h2 a',
  );
  return _browseHitsFromLinks(links);
}

List<AudiobookBrowseHit> parseZaudiobooksBrowseFromHtml(String html) {
  final document = hp.parse(html);
  final links = document.querySelectorAll(
    'h1.page-title a, h2.entry-title a, article h2 a, .inner-article-content a',
  );
  final hits = <AudiobookBrowseHit>[];
  final seen = <String>{};
  for (final link in links) {
    final pageUrl = link.attributes['href'] ?? '';
    if (pageUrl.isEmpty || !pageUrl.contains('zaudiobooks.com')) continue;
    if (seen.contains(pageUrl)) continue;
    seen.add(pageUrl);
    final title = link.text.trim();
    if (title.isEmpty) continue;
    final img = link.parent?.querySelector('img') ??
        link.parent?.parent?.querySelector('img');
    var cover = img?.attributes['src'] ?? img?.attributes['data-src'] ?? '';
    cover = upscaleCoverUrl(cover);
    hits.add(AudiobookBrowseHit(pageUrl: pageUrl, title: title, coverUrl: cover));
  }
  return hits;
}

List<AudiobookBrowseHit> parseFulllengthSearchFromHtml(String html) {
  final document = hp.parse(html);
  final articles = document.querySelectorAll('article, .post');
  final hits = <AudiobookBrowseHit>[];
  final seen = <String>{};
  for (final article in articles) {
    final titleElement = article.querySelector('h1.entry-title a, h2.entry-title a');
    final pageUrl = titleElement?.attributes['href'] ?? '';
    final title = titleElement?.text.trim() ?? '';
    if (pageUrl.isEmpty || title.isEmpty || seen.contains(pageUrl)) continue;
    seen.add(pageUrl);
    final img = article.querySelector('.wp-caption img, img');
    var cover = img?.attributes['src'] ?? img?.attributes['data-src'] ?? '';
    cover = upscaleCoverUrl(cover);
    hits.add(AudiobookBrowseHit(pageUrl: pageUrl, title: title, coverUrl: cover));
  }
  return hits;
}

List<AudiobookBrowseHit> parseHdSearchFromHtml(String html) {
  final document = hp.parse(html);
  final articles = document.querySelectorAll('article, .post');
  final hits = <AudiobookBrowseHit>[];
  final seen = <String>{};
  for (final article in articles) {
    final titleElement = article.querySelector(
      'h2 a, h1[itemprop="headline"] a, h1 a, h2.entry-title a',
    );
    final pageUrl = titleElement?.attributes['href'] ?? '';
    final title = titleElement?.text.trim() ?? '';
    if (pageUrl.isEmpty || title.isEmpty || seen.contains(pageUrl)) continue;
    seen.add(pageUrl);
    final img = article.querySelector('img[itemprop="image"], img');
    var cover = img?.attributes['src'] ?? img?.attributes['content'] ?? '';
    cover = upscaleCoverUrl(cover);
    hits.add(AudiobookBrowseHit(pageUrl: pageUrl, title: title, coverUrl: cover));
  }
  return hits;
}

List<AudiobookBrowseHit> parseBigSearchFromHtml(String html) {
  final document = hp.parse(html);
  final articles = document.querySelectorAll('article, .post');
  final hits = <AudiobookBrowseHit>[];
  final seen = <String>{};
  for (final article in articles) {
    final titleElement = article.querySelector('h1.title-page a, h2.entry-title a');
    final pageUrl = titleElement?.attributes['href'] ?? '';
    final title = titleElement?.text.trim() ?? '';
    if (pageUrl.isEmpty || title.isEmpty || seen.contains(pageUrl)) continue;
    seen.add(pageUrl);
    final img = article.querySelector('.wp-caption img, img');
    var cover = img?.attributes['data-lazy-src'] ??
        img?.attributes['src'] ??
        img?.attributes['data-src'] ??
        '';
    cover = upscaleCoverUrl(cover);
    hits.add(AudiobookBrowseHit(pageUrl: pageUrl, title: title, coverUrl: cover));
  }
  return hits;
}

List<AudiobookBrowseHit> parseZaudiobooksSearchFromHtml(String html) {
  final document = hp.parse(html);
  final articles = document.querySelectorAll('article, .post, .inner-article-content');
  final hits = <AudiobookBrowseHit>[];
  final seen = <String>{};
  for (final article in articles) {
    final titleElement = article.querySelector(
      'h1.page-title a, h2.entry-title a, h2 a',
    );
    final pageUrl = titleElement?.attributes['href'] ?? '';
    var title = titleElement?.text.trim() ?? '';
    if (title.isEmpty) {
      final og = article.querySelector('meta[property="og:title"]');
      title = og?.attributes['content'] ?? '';
    }
    if (pageUrl.isEmpty || title.isEmpty || seen.contains(pageUrl)) continue;
    if (!pageUrl.contains('zaudiobooks.com')) continue;
    seen.add(pageUrl);
    final img = article.querySelector('.inner-article-content img, img');
    var cover = img?.attributes['src'] ?? '';
    cover = upscaleCoverUrl(cover);
    hits.add(AudiobookBrowseHit(pageUrl: pageUrl, title: title, coverUrl: cover));
  }
  return hits;
}

List<AudiobookBrowseHit> _browseHitsFromLinks(dynamic links) {
  final hits = <AudiobookBrowseHit>[];
  final seen = <String>{};
  for (final link in links) {
    final pageUrl = link.attributes['href'] ?? '';
    final title = link.text.trim();
    if (pageUrl.isEmpty || title.isEmpty || seen.contains(pageUrl)) continue;
    seen.add(pageUrl);
    hits.add(AudiobookBrowseHit(pageUrl: pageUrl, title: title));
  }
  return hits;
}

String upscaleCoverUrl(String coverUrl) {
  if (coverUrl.contains('-') && coverUrl.contains('x')) {
    return coverUrl.replaceFirstMapped(
      RegExp(r'-\d+x\d+\.(jpg|jpeg|png|webp)'),
      (match) => '.${match.group(1)}',
    );
  }
  return coverUrl;
}
