import 'dart:async';

import 'package:flutter/material.dart';

import 'package:forja/l10n/l10n.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:forja_foundation/components/button.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
/// Shared code/QR connect step for TV cold start and Settings → Profile.
class DeviceLinkConnectView extends StatefulWidget {
  const DeviceLinkConnectView({
    super.key,
    required this.onAuthenticated,
    this.onBack,
    this.autoStart = true,
    this.compact = false,
    this.backFocusNode,
    this.autofocusBack = false,
  });

  final VoidCallback onAuthenticated;
  final VoidCallback? onBack;
  final bool autoStart;
  final bool compact;
  final FocusNode? backFocusNode;
  final bool autofocusBack;

  @override
  State<DeviceLinkConnectView> createState() => _DeviceLinkConnectViewState();
}

class _DeviceLinkConnectViewState extends State<DeviceLinkConnectView> {
  TvDeviceLinkSession? _session;
  bool _creating = false;
  bool _linking = false;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_start());
      });
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  String get _hostLabel {
    try {
      return Uri.parse(TvDeviceLinkAuth.webUrl).host;
    } catch (_) {
      return 'www.forjahq.xyz';
    }
  }

  Future<void> _start() async {
    _pollTimer?.cancel();
    setState(() {
      _error = null;
      _session = null;
      _creating = true;
      _linking = false;
    });

    try {
      final session = await TvDeviceLinkAuth.create();
      if (!mounted) return;
      setState(() {
        _session = session;
        _creating = false;
      });
      _beginPoll(session);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _error = e.toString();
      });
    }
  }

  void _beginPoll(TvDeviceLinkSession session) {
    _pollTimer?.cancel();
    final interval = Duration(seconds: session.interval.clamp(3, 15));
    _pollTimer = Timer.periodic(interval, (_) => unawaited(_pollOnce(session)));
    unawaited(_pollOnce(session));
  }

  Future<void> _pollOnce(TvDeviceLinkSession session) async {
    if (!mounted || _linking) return;
    final l10n = context.l10n;
    final result = await TvDeviceLinkAuth.poll(session.deviceCode);
    if (!mounted) return;

    switch (result.status) {
      case TvDeviceLinkPollStatus.pending:
        return;
      case TvDeviceLinkPollStatus.expired:
      case TvDeviceLinkPollStatus.denied:
        _pollTimer?.cancel();
        setState(() {
          _error = result.status == TvDeviceLinkPollStatus.expired
              ? l10n.accountLinkExpired
              : l10n.accountLinkCancelled;
          _session = null;
        });
        return;
      case TvDeviceLinkPollStatus.error:
        final msg = (result.error ?? '').toLowerCase();
        final fatal = msg.contains('already used') ||
            msg.contains('could not reach forja') ||
            msg.contains('not configured');
        if (fatal) {
          _pollTimer?.cancel();
          setState(() {
            _error = result.error;
            _session = null;
          });
        }
        return;
      case TvDeviceLinkPollStatus.approved:
        _pollTimer?.cancel();
        setState(() => _linking = true);
        try {
          await SyncService.instance.signInWithBrowserTokens(
            accessToken: result.accessToken!,
            refreshToken: result.refreshToken!,
          );
          if (!mounted) return;
          widget.onAuthenticated();
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _error = e is AuthException ? e.message : e.toString();
            _session = null;
            _linking = false;
          });
        }
    }
  }

  void _cancel() {
    _pollTimer?.cancel();
    widget.onBack?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_linking) {
      return const _DeviceLinkLinkingIndicator();
    }

    final code = _session?.userCode;
    final display = code != null && code.length == 8
        ? '${code.substring(0, 4)}-${code.substring(4)}'
        : code;
    final qrUri = _session?.verificationUriComplete;
    final loading = _creating || (_session == null && _error == null);

    if (widget.compact) {
      return _CompactConnectLayout(
        hostLabel: _hostLabel,
        loading: loading,
        qrUri: qrUri,
        displayCode: display,
        error: _error,
        onBack: widget.onBack == null ? null : _cancel,
        onRetry: _error != null ? () => unawaited(_start()) : null,
      );
    }

    return _TvConnectLayout(
      hostLabel: _hostLabel,
      loading: loading,
      qrUri: qrUri,
      displayCode: display,
      error: _error,
      backFocusNode: widget.backFocusNode,
      autofocusBack: widget.autofocusBack,
      onBack: widget.onBack == null ? null : _cancel,
      onRetry: _error != null ? () => unawaited(_start()) : null,
    );
  }
}

class _DeviceLinkLinkingIndicator extends StatelessWidget {
  const _DeviceLinkLinkingIndicator();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: ForjaShellColors.brandGreen,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.accountLinkSigningIn,
          style: GoogleFonts.dmSans(
            color: ForjaShellColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.accountLinkCreatingSession,
          style: GoogleFonts.dmSans(
            color: ForjaShellColors.textSecondary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _CompactConnectLayout extends StatelessWidget {
  const _CompactConnectLayout({
    required this.hostLabel,
    required this.loading,
    required this.qrUri,
    required this.displayCode,
    required this.error,
    this.onBack,
    this.onRetry,
  });

  final String hostLabel;
  final bool loading;
  final String? qrUri;
  final String? displayCode;
  final String? error;
  final VoidCallback? onBack;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.accountLinkThisDevice,
          style: GoogleFonts.dmMono(
            color: ForjaShellColors.brandGreen,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
          ),
        ),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            style: const TextStyle(
              color: ForjaShellColors.textSecondary,
              fontSize: 14,
              height: 1.45,
            ),
            children: [
              TextSpan(text: l10n.accountLinkOpen),
              TextSpan(
                text: '$hostLabel/connect',
                style: const TextStyle(
                  color: ForjaShellColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.accountLinkEnterCode,
          style: const TextStyle(
            color: ForjaShellColors.textSecondary,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DeviceLinkQrWithCode(
                loading: loading || qrUri == null,
                qrUri: qrUri,
                displayCode: displayCode,
                qrSize: 132,
              ),
              if (onBack != null) ...[
                const SizedBox(height: 16),
                Button(
                  label: l10n.settingsUiCancel,
                  icon: Icons.close_rounded,
                  onPressed: onBack,
                ),
              ],
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 16),
          Text(
            error!,
            style: const TextStyle(
              color: Color(0xFFF87171),
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            Button(
              label: l10n.accountGetNewCode,
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ],
      ],
    );
  }
}

class _TvConnectLayout extends StatelessWidget {
  const _TvConnectLayout({
    required this.hostLabel,
    required this.loading,
    required this.qrUri,
    required this.displayCode,
    required this.error,
    required this.backFocusNode,
    required this.autofocusBack,
    this.onBack,
    this.onRetry,
  });

  final String hostLabel;
  final bool loading;
  final String? qrUri;
  final String? displayCode;
  final String? error;
  final FocusNode? backFocusNode;
  final bool autofocusBack;
  final VoidCallback? onBack;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.accountLinkThisTv,
                    style: GoogleFonts.dmMono(
                      color: ForjaShellColors.brandGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.6,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text.rich(
                    TextSpan(
                      style: GoogleFonts.dmSans(
                        color: ForjaShellColors.textSecondary,
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                      children: [
                        TextSpan(text: l10n.accountLinkOpen),
                        TextSpan(
                          text: '$hostLabel/connect',
                          style: const TextStyle(
                            color: ForjaShellColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.accountLinkEnterCode,
                    style: GoogleFonts.dmSans(
                      color: ForjaShellColors.textSecondary,
                      fontSize: 16,
                      height: 1.45,
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 22),
                    Text(
                      error!,
                      style: GoogleFonts.dmSans(
                        color: const Color(0xFFF87171),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    if (onRetry != null) ...[
                      const SizedBox(height: 20),
                      Button(
                        label: l10n.accountGetNewCode,
                        icon: Icons.refresh_rounded,
                        onPressed: onRetry,
                      ),
                    ],
                  ],
                  if (onBack != null && backFocusNode != null) ...[
                    const SizedBox(height: 28),
                    _TvFlatAction(
                      focusNode: backFocusNode!,
                      autofocus: autofocusBack,
                      label: l10n.accountBack,
                      onTap: onBack!,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 48),
            DeviceLinkQrWithCode(
              loading: loading || qrUri == null,
              qrUri: qrUri,
              displayCode: displayCode,
            ),
          ],
        ),
      ],
    );
  }
}

/// QR + pairing code with a single loading spinner while the session is created.
class DeviceLinkQrWithCode extends StatelessWidget {
  const DeviceLinkQrWithCode({
    super.key,
    required this.loading,
    required this.qrUri,
    required this.displayCode,
    this.qrSize = 168,
  });

  final bool loading;
  final String? qrUri;
  final String? displayCode;
  final double qrSize;

  Future<void> _openUri() async {
    final raw = qrUri;
    if (raw == null || raw.isEmpty) return;
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const spinner = SizedBox(
      width: 28,
      height: 28,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: ForjaShellColors.brandGreen,
      ),
    );

    if (loading) {
      return SizedBox(
        width: qrSize + 20,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: qrSize + 20,
              child: const Center(child: spinner),
            ),
          ],
        ),
      );
    }

    final qr = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: QrImageView(
          data: qrUri!,
          version: QrVersions.auto,
          size: qrSize,
          backgroundColor: Colors.white,
          eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: Color(0xFF141414),
          ),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: Color(0xFF141414),
          ),
        ),
      ),
    );

    final qrWidget = PlatformInfo.isDesktop
        ? MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Tooltip(
              message: l10n.accountLinkOpenInBrowser,
              child: GestureDetector(
                onTap: () => unawaited(_openUri()),
                child: qr,
              ),
            ),
          )
        : qr;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        qrWidget,
        const SizedBox(height: 18),
        Text(
          displayCode ?? '',
          style: GoogleFonts.dmMono(
            color: ForjaShellColors.textPrimary,
            fontSize: qrSize >= 160 ? 36 : 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

class _TvFlatAction extends StatelessWidget {
  const _TvFlatAction({
    required this.focusNode,
    required this.label,
    required this.onTap,
    this.autofocus = false,
  });

  final FocusNode focusNode;
  final String label;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return FocusableControl(
      focusNode: focusNode,
      autoFocus: autofocus,
      onTap: onTap,
      borderRadius: 8,
      scaleOnFocus: 1.0,
      showFocusBorder: true,
      showFocusFill: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.dmSans(
                color: ForjaShellColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
