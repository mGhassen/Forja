part of 'iptv_controller.dart';

class _CatalogSnap {
  final List<IptvCategory> categories;
  final List<IptvStream> streams;
  const _CatalogSnap({required this.categories, required this.streams});
}

class _Candidate {
  final VerifiedPortal portal;
  final IptvStream stream;
  final String url;
  const _Candidate({
    required this.portal,
    required this.stream,
    required this.url,
  });
}
