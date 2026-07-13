enum StreamProviderProbeStatus {
  pending,
  trying,
  success,
  failed,

  /// Headless WebView sniffers blocked on Android TV (issue 031).
  skippedOnTv,
}

class StreamProviderProbe {
  const StreamProviderProbe({
    required this.id,
    required this.label,
    required this.status,
    this.isPreferred = false,
  });

  final String id;
  final String label;
  final StreamProviderProbeStatus status;
  final bool isPreferred;

  StreamProviderProbe copyWith({
    StreamProviderProbeStatus? status,
  }) {
    return StreamProviderProbe(
      id: id,
      label: label,
      status: status ?? this.status,
      isPreferred: isPreferred,
    );
  }
}
