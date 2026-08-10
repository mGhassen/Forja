import 'package:forja/shared/extractors/core/embed_extract_profile.dart';

/// Host sniff for VSEmbed (`vsembed.su`) when the Rust rcp/prorcp chain fails.
///
/// Live player loads `cloudorchestranova.com` + vsdec WASM; stream URLs only
/// appear after the landing play click / autoplay boot.
const vidsrcExtractProfile = EmbedExtractProfile(
  id: 'vidsrc',
  timeout: Duration(seconds: 75),
  forceDirect: true,
  deferUntilStrongStream: true,
  cdnHostsPreferEmbedReferer: [
    'cloudorchestranova',
    'cloudnestra',
    'vidsrcme',
  ],
);
