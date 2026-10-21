import 'dart:async';

import 'package:rust/rust.dart';

/// Tunables for the green Play fallback window (RFC-122 T13).
///
/// The engine race used to abort every sibling probe at the first verified
/// source and open the player with that one row. A dead first row then had
/// nothing to fall back to. These values keep the race open a little longer
/// after the first win so the player receives backup rows behind the winner.
abstract final class EngineRaceFallbackPolicy {
  /// How long the race stays open after the first verified source, collecting
  /// backup rows from probes that are still running. The player route is
  /// pushed at the first win; this window runs behind it.
  static const Duration window = Duration(milliseconds: 800);

  /// Close the window early once this many extra verified rows arrived.
  static const int extraWins = 2;

  /// Cap on extracted-but-unprobed rows appended behind the verified ones at
  /// close. Each unprobed row costs the player one open attempt on failover.
  static const int maxUnprobedRows = 4;

  /// How many times one player failover chain may ask the host for streams:
  /// the first call drains verified backups, the next runs the race again.
  static const int reloadPasses = 2;
}

/// Backup rows gathered after the race winner, in probe order.
///
/// Created at the first verified source. [addVerified] appends rows from
/// later probe wins; [addUnprobedRows] parks extracted rows that were never
/// probed. The window closes on [EngineRaceFallbackPolicy.extraWins] extra
/// wins, on [window] elapsed, or on an explicit [close]. `onClose` runs
/// before [closed] completes so the race can park its unprobed rows on every
/// close path; [drain] then hands out each row once, winner excluded.
class EngineRaceFallbacks {
  EngineRaceFallbacks({
    required List<StreamSource> winner,
    Duration window = EngineRaceFallbackPolicy.window,
    int extraWins = EngineRaceFallbackPolicy.extraWins,
    void Function()? onClose,
  }) : _winnerUrls = {for (final s in winner) s.url},
       _extraWins = extraWins,
       _onClose = onClose {
    _timer = Timer(window, close);
  }

  final Set<String> _winnerUrls;
  final int _extraWins;
  final void Function()? _onClose;

  final List<StreamSource> _verified = [];
  final List<Map<String, dynamic>> _unprobedRows = [];
  final Set<String> _seenUrls = {};
  final Set<String> _handedOut = {};
  final Completer<void> _closed = Completer<void>();
  Timer? _timer;
  bool _closing = false;

  bool get isClosed => _closing;

  /// Completes when the window closes (extra wins, timeout, or [close]).
  Future<void> get closed => _closed.future;

  int get verifiedCount => _verified.length;

  /// Verified backup rows in probe order (winner excluded).
  List<StreamSource> get verified => List.unmodifiable(_verified);

  /// Extracted rows parked at close that were never probed.
  List<Map<String, dynamic>> get unprobedRows =>
      List.unmodifiable(_unprobedRows);

  /// Append rows from a later probe win. Ignored once closed. Rows whose URL
  /// matches the winner or an earlier backup are dropped.
  void addVerified(List<StreamSource> rows) {
    if (isClosed) return;
    for (final s in rows) {
      if (_winnerUrls.contains(s.url)) continue;
      if (!_seenUrls.add(s.url)) continue;
      _verified.add(s);
    }
    if (_verified.length >= _extraWins) close();
  }

  /// Park extracted rows that were never probed. Capped by [max].
  void addUnprobedRows(
    List<Map<String, dynamic>> rows, {
    int max = EngineRaceFallbackPolicy.maxUnprobedRows,
  }) {
    for (final row in rows) {
      if (_unprobedRows.length >= max) break;
      final url = row['url']?.toString() ?? '';
      if (url.isEmpty || _winnerUrls.contains(url) || _seenUrls.contains(url)) {
        continue;
      }
      _seenUrls.add(url);
      _unprobedRows.add(row);
    }
  }

  /// Close the window. Idempotent. The close hook runs first (rows it parks
  /// are visible to every [drain] waiter), then [closed] completes.
  void close() {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    _timer = null;
    _onClose?.call();
    _closed.complete();
  }

  /// Verified rows not yet offered and not in [exclude], after the window
  /// closes. Each row is offered once across calls; a row skipped as failed
  /// counts as offered and is never returned later.
  Future<List<StreamSource>> drain({
    Iterable<String> exclude = const [],
  }) async {
    await closed;
    final skip = exclude.toSet();
    final out = <StreamSource>[];
    for (final s in _verified) {
      final consumed = !_handedOut.add(s.url);
      if (consumed || skip.contains(s.url)) continue;
      out.add(s);
    }
    return out;
  }

  /// Unprobed rows not yet handed out and not in [exclude]. Sync: callers use
  /// it after [drain] so the window is already closed.
  List<Map<String, dynamic>> takeUnprobedRows({
    Iterable<String> exclude = const [],
  }) {
    final skip = exclude.toSet();
    final out = <Map<String, dynamic>>[];
    for (final row in _unprobedRows) {
      final url = row['url']?.toString() ?? '';
      final consumed = !_handedOut.add(url);
      if (consumed || skip.contains(url)) continue;
      out.add(row);
    }
    return out;
  }
}

/// Player failover reload: hand out the race backups first, then run the
/// full resolve once they are gone.
///
/// [fallbacks] null (no race behind this session) → [reload] directly.
/// [convertUnprobed] turns parked raw rows into player sources without a
/// network probe; null skips unprobed rows.
Future<List<StreamSource>?> drainFallbacksThenReload({
  required EngineRaceFallbacks? fallbacks,
  required Future<List<StreamSource>?> Function() reload,
  Iterable<String> failedUrls = const [],
  Future<List<StreamSource>> Function(List<Map<String, dynamic>> rows)?
  convertUnprobed,
}) async {
  if (fallbacks != null) {
    final failed = failedUrls.toList();
    final late = await fallbacks.drain(exclude: failed);
    if (convertUnprobed != null) {
      final raw = fallbacks.takeUnprobedRows(exclude: failed);
      if (raw.isNotEmpty) late.addAll(await convertUnprobed(raw));
    }
    if (late.isNotEmpty) return late;
  }
  return reload();
}

/// Pool admission after the first win: in-flight extracts keep running until
/// the window closes, but no new plugin starts once a winner is chosen. New
/// extractions would compete with the player's first frame and be killed at
/// close anyway.
bool engineRacePoolAdmits({
  required bool winnerChosen,
  required bool closed,
}) => !winnerChosen && !closed;

/// True when [row]'s catalog URL already failed in a player this session.
bool streamRowUrlFailed(Map<String, dynamic> row, Set<String> failedUrls) {
  final url = row['url']?.toString() ?? '';
  return url.isNotEmpty && failedUrls.contains(url);
}

/// Drop sources whose play or catalog URL already failed in a player. A row
/// that probes OK over HTTP but fails to decode must not re-verify as a win.
List<StreamSource> dropFailedStreamSources(
  List<StreamSource> sources,
  Iterable<String> failedUrls,
) {
  final failed = failedUrls.toSet();
  if (failed.isEmpty) return sources;
  return [
    for (final s in sources)
      if (!failed.contains(s.url) &&
          !(s.catalogUrl != null && failed.contains(s.catalogUrl)))
        s,
  ];
}

/// Reload result for the player: the fresh winner rows, then the verified
/// backups of that race, then its parked unprobed rows. Waits for the race
/// window to close (bounded by [EngineRaceFallbackPolicy.window]).
Future<List<StreamSource>> reloadSourcesWithFallbacks({
  required List<StreamSource> sources,
  required EngineRaceFallbacks? fallbacks,
  Iterable<String> failedUrls = const [],
  Future<List<StreamSource>> Function(List<Map<String, dynamic>> rows)?
  convertUnprobed,
}) async {
  final out = <StreamSource>[...sources];
  if (fallbacks == null) return out;
  final failed = failedUrls.toList();
  final seen = {for (final s in out) s.url};
  for (final s in await fallbacks.drain(exclude: failed)) {
    if (seen.add(s.url)) out.add(s);
  }
  if (convertUnprobed != null) {
    final raw = fallbacks.takeUnprobedRows(exclude: failed);
    if (raw.isNotEmpty) {
      for (final s in await convertUnprobed(raw)) {
        if (seen.add(s.url)) out.add(s);
      }
    }
  }
  return out;
}

/// True when a reload batch is worth opening: it holds at least one URL this
/// failover chain has not tried yet. A batch of already-dead URLs ends the
/// chain instead of re-opening them.
bool reloadBatchHasUntriedUrl({
  required List<StreamSource> batch,
  required Set<String> triedUrls,
}) {
  if (batch.isEmpty) return false;
  return batch.any((s) => !triedUrls.contains(s.url));
}
