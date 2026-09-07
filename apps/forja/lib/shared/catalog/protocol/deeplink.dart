/// Deep links: `forja://catalog/{pluginId}/{action}?id=`
class CatalogDeepLink {
  const CatalogDeepLink({
    required this.pluginId,
    this.action = 'details',
    this.id,
    this.params = const {},
  });

  final String pluginId;
  final String action;
  final String? id;
  final Map<String, String> params;

  static CatalogDeepLink? parse(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    if (uri.scheme != 'forja') return null;
    if (uri.host != 'catalog') return null;
    final segs = uri.pathSegments;
    if (segs.isEmpty) return null;
    final pluginId = segs.first;
    final action = segs.length > 1 ? segs[1] : 'details';
    final q = Map<String, String>.from(uri.queryParameters);
    final id = q.remove('id');
    return CatalogDeepLink(
      pluginId: pluginId,
      action: action,
      id: id,
      params: q,
    );
  }

  @override
  String toString() {
    return Uri(
      scheme: 'forja',
      host: 'catalog',
      pathSegments: [pluginId, action],
      queryParameters: {
        'id': ?id,
        ...params,
      },
    ).toString();
  }
}
