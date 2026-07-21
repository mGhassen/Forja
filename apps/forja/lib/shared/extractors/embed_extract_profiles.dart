/// Thin registry of per-provider [EmbedExtractProfile] entries.
///
/// Policy lives in `providers/<id>/profile.dart`; this file only resolves by id.
library;

import 'package:forja/shared/extractors/core/embed_extract_profile.dart';
import 'package:forja/shared/extractors/providers/vidlink/profile.dart';
import 'package:forja/shared/extractors/providers/vixsrc/profile.dart';
import 'package:forja/shared/extractors/providers/vidnest/profile.dart';
import 'package:forja/shared/extractors/providers/vidzee/profile.dart';
import 'package:forja/shared/extractors/providers/vidrock/profile.dart';
import 'package:forja/shared/extractors/providers/vidfast/profile.dart';
import 'package:forja/shared/extractors/providers/2embed/profile.dart';
import 'package:forja/shared/extractors/providers/autoembed/profile.dart';
import 'package:forja/shared/extractors/providers/vidlove/profile.dart';
import 'package:forja/shared/extractors/providers/111movies/profile.dart';
import 'package:forja/shared/extractors/providers/vidsrcsbs/profile.dart';
import 'package:forja/shared/extractors/providers/moviesapi/profile.dart';
import 'package:forja/shared/extractors/providers/vidapi/profile.dart';
import 'package:forja/shared/extractors/providers/videasy/profile.dart';
import 'package:forja/shared/extractors/providers/vidsrc/profile.dart';
import 'package:forja/shared/extractors/providers/vidsrcwin/profile.dart';
import 'package:forja/shared/extractors/providers/anitaro/profile.dart';

export 'package:forja/shared/extractors/core/embed_extract_profile.dart';

abstract final class EmbedExtractProfiles {
  static const generic = EmbedExtractProfile(
    id: '_generic',
    timeout: Duration(seconds: 45),
  );

  static final Map<String, EmbedExtractProfile> catalog = {
    'vidlink': vidlinkExtractProfile,
    'vixsrc': vixsrcExtractProfile,
    'vidnest': vidnestExtractProfile,
    'vidzee': vidzeeExtractProfile,
    'vidrock': vidrockExtractProfile,
    'vidfast': vidfastExtractProfile,
    '2embed': p2embedExtractProfile,
    'autoembed': autoembedExtractProfile,
    'vidlove': vidloveExtractProfile,
    '111movies': p111moviesExtractProfile,
    'vidsrcsbs': vidsrcsbsExtractProfile,
    'moviesapi': moviesapiExtractProfile,
    'vidapi': vidapiExtractProfile,
    'videasy': videasyExtractProfile,
    'vidsrc': vidsrcExtractProfile,
    'vidsrcwin': vidsrcwinExtractProfile,
    'anitaro': anitaroExtractProfile,
  };

  static EmbedExtractProfile resolve(String? providerId) {
    if (providerId == null || providerId.trim().isEmpty) return generic;
    return catalog[providerId] ??
        EmbedExtractProfile(id: providerId, timeout: generic.timeout);
  }

  /// Template HostRequired IDs that must have an explicit catalog entry.
  static const requiredTemplateIds = <String>[
    'vidlink',
    'vixsrc',
    'vidnest',
    'vidzee',
    'vidrock',
    'vidfast',
    '2embed',
    'autoembed',
    'vidlove',
    'vidsrcsbs',
    '111movies',
    'moviesapi',
    'vidapi',
    'vidsrcwin',
  ];
}
