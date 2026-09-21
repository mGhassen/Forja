/// JSON props readers for block `fromProps` (RFC-112).
///
/// Packs emit serializable maps only — no Widgets or callbacks here.
library;

import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

String? propsString(Map<String, dynamic> props, String key) {
  final v = props[key];
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

String propsStringOr(Map<String, dynamic> props, String key, String fallback) =>
    propsString(props, key) ?? fallback;

List<String> propsStringList(Map<String, dynamic> props, String key) {
  final v = props[key];
  if (v is! List) return const [];
  final out = <String>[];
  for (final e in v) {
    final s = e?.toString().trim() ?? '';
    if (s.isNotEmpty) out.add(s);
  }
  return out;
}

double? propsNum(Map<String, dynamic> props, String key) {
  final v = props[key];
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}

double propsNumOr(Map<String, dynamic> props, String key, double fallback) =>
    propsNum(props, key) ?? fallback;

/// Desktop px length from pack → TV × [ShellTokens.tvChromeScale].
///
/// Use for width/height/gap/pad/fontSize on catalog mounts. Keep [propsNum]
/// for fractions, scales, progress, aspect ratios, and other non-length numbers.
/// Poster card widths stay on [ShellTokens.posterCardWidthTv], not this helper.
double? propsLength(
  BuildContext context,
  Map<String, dynamic> props,
  String key,
) {
  final v = propsNum(props, key);
  if (v == null) return null;
  return ShellTokens.chromeScale(
    v,
    tv: ShellPaintScope.usesTvDensityOf(context),
  );
}

/// Pack length or [fallback] as-is (caller passes density-aware defaults).
double propsLengthOr(
  BuildContext context,
  Map<String, dynamic> props,
  String key,
  double fallback,
) =>
    propsLength(context, props, key) ?? fallback;

/// Icon size from pack, or [desktopFallback] scaled on TV.
///
/// Unlike [propsLengthOr], the fallback is a **desktop** baseline — leanback
/// applies [ShellTokens.tvChromeScale]. Pack-provided values still go through
/// [propsLength] (already scaled).
double propsIconSizeOr(
  BuildContext context,
  Map<String, dynamic> props,
  String key,
  double desktopFallback,
) =>
    propsLength(context, props, key) ??
    ShellTokens.iconSizeFor(
      desktopFallback,
      tv: ShellPaintScope.usesTvDensityOf(context),
    );

int? propsInt(Map<String, dynamic> props, String key) {
  final v = props[key];
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

bool propsBool(Map<String, dynamic> props, String key, [bool fallback = false]) {
  final v = props[key];
  if (v is bool) return v;
  if (v == 1 || v == '1' || v == 'true') return true;
  if (v == 0 || v == '0' || v == 'false') return false;
  return fallback;
}

/// `#RRGGBB` / `#AARRGGBB` / `0x…` → [Color], or null.
Color? propsColor(Map<String, dynamic> props, String key) {
  final raw = propsString(props, key);
  if (raw == null) return null;
  var s = raw;
  if (s.startsWith('#')) s = s.substring(1);
  if (s.startsWith('0x') || s.startsWith('0X')) s = s.substring(2);
  if (s.length == 6) s = 'FF$s';
  if (s.length != 8) return null;
  final value = int.tryParse(s, radix: 16);
  if (value == null) return null;
  return Color(value);
}
