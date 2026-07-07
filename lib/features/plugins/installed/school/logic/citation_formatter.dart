/// Builds a formatted citation string from a handful of raw source fields.
/// Not a full bibliographic engine — covers the common fields students need
/// for APA, MLA, and Chicago style across a few source types.
enum CitationStyle { apa, mla, chicago }

enum SourceType { book, website, journalArticle, newspaper, video }

extension CitationStyleLabel on CitationStyle {
  String get label => switch (this) {
        CitationStyle.apa => 'APA',
        CitationStyle.mla => 'MLA',
        CitationStyle.chicago => 'Chicago',
      };
}

extension SourceTypeLabel on SourceType {
  String get label => switch (this) {
        SourceType.book => 'Book',
        SourceType.website => 'Website',
        SourceType.journalArticle => 'Journal article',
        SourceType.newspaper => 'Newspaper article',
        SourceType.video => 'Video',
      };
}

/// Raw fields a citation form collects. Any field can be left blank; the
/// formatter skips absent pieces rather than emitting "null".
class CitationFields {
  const CitationFields({
    this.author = '',
    this.title = '',
    this.year = '',
    this.container = '', // publisher, website/journal name, etc.
    this.url = '',
    this.accessDate = '',
    this.volume = '',
    this.issue = '',
    this.pages = '',
    this.city = '',
  });

  final String author;
  final String title;
  final String year;
  final String container;
  final String url;
  final String accessDate;
  final String volume;
  final String issue;
  final String pages;
  final String city;

  Map<String, String> toJson() => {
        'author': author,
        'title': title,
        'year': year,
        'container': container,
        'url': url,
        'accessDate': accessDate,
        'volume': volume,
        'issue': issue,
        'pages': pages,
        'city': city,
      };

  factory CitationFields.fromJson(Map<String, dynamic> json) => CitationFields(
        author: json['author'] as String? ?? '',
        title: json['title'] as String? ?? '',
        year: json['year'] as String? ?? '',
        container: json['container'] as String? ?? '',
        url: json['url'] as String? ?? '',
        accessDate: json['accessDate'] as String? ?? '',
        volume: json['volume'] as String? ?? '',
        issue: json['issue'] as String? ?? '',
        pages: json['pages'] as String? ?? '',
        city: json['city'] as String? ?? '',
      );
}

String formatCitation(
  CitationStyle style,
  SourceType type,
  CitationFields f,
) {
  return switch (style) {
    CitationStyle.apa => _apa(type, f),
    CitationStyle.mla => _mla(type, f),
    CitationStyle.chicago => _chicago(type, f),
  };
}

String _join(Iterable<String> parts, {String sep = ' '}) =>
    parts.where((p) => p.trim().isNotEmpty).join(sep);

String _apa(SourceType type, CitationFields f) {
  final author = f.author.isNotEmpty ? '${f.author}.' : '';
  final year = f.year.isNotEmpty ? '(${f.year}).' : '';
  final title = f.title.isNotEmpty ? '${f.title}.' : '';
  return switch (type) {
    SourceType.book => _join([author, year, title, f.container]),
    SourceType.website => _join([author, year, title, f.container, f.url]),
    SourceType.journalArticle => _join([
        author,
        year,
        title,
        _join([
          f.container,
          if (f.volume.isNotEmpty)
            f.issue.isNotEmpty ? '${f.volume}(${f.issue}),' : '${f.volume},',
          if (f.pages.isNotEmpty) f.pages,
        ]),
      ]),
    SourceType.newspaper => _join([author, year, title, f.container]),
    SourceType.video => _join([author, year, '[Video]. ${f.title}.', f.container, f.url]),
  };
}

String _mla(SourceType type, CitationFields f) {
  final author = f.author.isNotEmpty ? '${f.author}.' : '';
  final title = f.title.isNotEmpty ? '"${f.title}."' : '';
  final titleBook = f.title.isNotEmpty ? '${f.title}.' : '';
  return switch (type) {
    SourceType.book =>
      _join([author, titleBook, f.container, f.year.isNotEmpty ? '${f.year}.' : '']),
    SourceType.website => _join([
        author,
        title,
        f.container.isNotEmpty ? '${f.container},' : '',
        f.year.isNotEmpty ? '${f.year},' : '',
        f.url,
      ]),
    SourceType.journalArticle => _join([
        author,
        title,
        f.container.isNotEmpty ? '${f.container},' : '',
        f.volume.isNotEmpty ? 'vol. ${f.volume},' : '',
        f.issue.isNotEmpty ? 'no. ${f.issue},' : '',
        f.year.isNotEmpty ? '${f.year},' : '',
        f.pages.isNotEmpty ? 'pp. ${f.pages}.' : '',
      ]),
    SourceType.newspaper => _join([
        author,
        title,
        f.container.isNotEmpty ? '${f.container},' : '',
        f.year.isNotEmpty ? '${f.year}.' : '',
      ]),
    SourceType.video => _join([author, title, f.container, f.year.isNotEmpty ? '${f.year},' : '', f.url]),
  };
}

String _chicago(SourceType type, CitationFields f) {
  final author = f.author.isNotEmpty ? '${f.author}.' : '';
  final title = f.title.isNotEmpty ? '"${f.title}."' : '';
  final titleBook = f.title.isNotEmpty ? '${f.title}.' : '';
  return switch (type) {
    SourceType.book => _join([
        author,
        titleBook,
        f.city.isNotEmpty ? '${f.city}:' : '',
        f.container.isNotEmpty
            ? (f.year.isNotEmpty ? '${f.container}, ${f.year}.' : '${f.container}.')
            : '',
      ]),
    SourceType.website => _join([
        author,
        title,
        f.container.isNotEmpty ? '${f.container}.' : '',
        f.accessDate.isNotEmpty ? 'Accessed ${f.accessDate}.' : '',
        f.url,
      ]),
    SourceType.journalArticle => _join([
        author,
        title,
        _join([
          f.container,
          f.volume,
          if (f.issue.isNotEmpty) 'no. ${f.issue}',
        ]),
        f.year.isNotEmpty ? '(${f.year}):' : '',
        f.pages.isNotEmpty ? '${f.pages}.' : '',
      ]),
    SourceType.newspaper => _join([
        author,
        title,
        f.container.isNotEmpty ? '${f.container},' : '',
        f.year.isNotEmpty ? '${f.year}.' : '',
      ]),
    SourceType.video => _join([author, title, f.container, f.year.isNotEmpty ? '${f.year}.' : '', f.url]),
  };
}
