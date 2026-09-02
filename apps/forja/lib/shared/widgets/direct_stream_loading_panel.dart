import 'package:flutter/material.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/stream_provider_probe.dart';

/// Direct / HTTP stream resolve body for [LoadingOverlay].
class DirectStreamLoadingPanel extends StatelessWidget {
  const DirectStreamLoadingPanel({
    super.key,
    required this.message,
    this.subtitle,
    this.probes = const [],
  });

  final String message;
  final String? subtitle;
  final List<StreamProviderProbe> probes;

  bool get _probeMode => probes.isNotEmpty;

  int get _probeTotal => probes.length;

  int get _probeChecked => probes
      .where(
        (p) =>
            p.status != StreamProviderProbeStatus.trying &&
            p.status != StreamProviderProbeStatus.pending,
      )
      .length;

  int get _probeReady => probes
      .where((p) => p.status == StreamProviderProbeStatus.success)
      .length;

  int get _probeSkipped => probes
      .where((p) => p.status == StreamProviderProbeStatus.skippedOnTv)
      .length;

  List<String> get _skippedProbeLabels => probes
      .where((p) => p.status == StreamProviderProbeStatus.skippedOnTv)
      .map((p) => p.label)
      .toList(growable: false);

  double get _probeProgress =>
      _probeTotal > 0 ? _probeChecked / _probeTotal : 0;

  List<StreamProviderProbe> get _tryingProbes => probes
      .where((p) => p.status == StreamProviderProbeStatus.trying)
      .toList(growable: false);

  bool get _probeWorkActive => _tryingProbes.isNotEmpty;

  String get _headline {
    if (!_probeMode) return _sentenceCase(message);
    final msg = message.trim().toUpperCase();
    if (msg.contains('OPENING')) return 'Opening player…';
    if (msg.contains('PROBING')) return 'Probing streams…';
    if (_tryingProbes.isNotEmpty || msg.contains('CHECKING')) {
      return 'Checking servers…';
    }
    if (msg.contains('FINDING') || msg.contains('LOOKING')) {
      return 'Finding servers…';
    }
    return _sentenceCase(message);
  }

  String? get _hint {
    if (!_probeMode) return subtitle;
    final msg = message.trim().toUpperCase();
    if (msg.contains('OPENING')) return 'Starting playback';
    if (msg.contains('PROBING')) return 'Testing which links play';
    if (_tryingProbes.isNotEmpty || msg.contains('CHECKING')) {
      return 'Asking servers for streams';
    }
    if (msg.contains('FINDING') || msg.contains('LOOKING') || msg.isEmpty) {
      return 'Looking up available providers';
    }
    return subtitle;
  }

  static String _sentenceCase(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 'Starting stream…';
    if (t.endsWith('…') || t.endsWith('...')) return t;
    return '$t…';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _headline,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1.25,
            letterSpacing: 0.15,
            fontFamily: 'Poppins',
          ),
        ),
        if (_hint != null && _hint!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              _hint!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.52),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
                letterSpacing: 0.1,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
        if (_probeMode) ...[
          const SizedBox(height: 22),
          SizedBox(
            width: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: _probeProgress),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: _probeWorkActive ? null : (value > 0 ? value : null),
                  minHeight: 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _probeSkipped > 0
                ? '$_probeChecked / $_probeTotal checked · $_probeReady up · $_probeSkipped skipped on TV'
                : '$_probeChecked / $_probeTotal checked · $_probeReady up',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              fontFamily: 'Poppins',
            ),
          ),
          if (_probeSkipped > 0) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _skippedProbeLabels.join(' · '),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}
