import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Leanback account link: large code + QR → portal `/connect`, then poll.
class TvAccountLinkScreen extends StatefulWidget {
  const TvAccountLinkScreen({
    super.key,
    required this.onAuthenticated,
    required this.onContinueAsGuest,
  });

  final VoidCallback onAuthenticated;
  final VoidCallback onContinueAsGuest;

  @override
  State<TvAccountLinkScreen> createState() => _TvAccountLinkScreenState();
}

class _TvAccountLinkScreenState extends State<TvAccountLinkScreen> {
  TvDeviceLinkSession? _session;
  String? _error;
  bool _starting = true;
  bool _linking = false;
  Timer? _pollTimer;
  final FocusNode _guestFocus = FocusNode(debugLabel: 'tv_link_guest');
  final FocusNode _retryFocus = FocusNode(debugLabel: 'tv_link_retry');

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _guestFocus.dispose();
    _retryFocus.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    _pollTimer?.cancel();
    setState(() {
      _starting = true;
      _error = null;
      _session = null;
      _linking = false;
    });
    try {
      final session = await TvDeviceLinkAuth.create();
      if (!mounted) return;
      setState(() {
        _session = session;
        _starting = false;
      });
      _beginPoll(session);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _guestFocus.requestFocus();
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = e.message;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _retryFocus.requestFocus();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = e.toString();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _retryFocus.requestFocus();
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
              ? 'This code expired. Generate a new one.'
              : 'Linking was cancelled. Generate a new code.';
          _session = null;
        });
        return;
      case TvDeviceLinkPollStatus.error:
        // Transient network errors — keep polling unless message is terminal.
        if (result.error?.toLowerCase().contains('already used') == true) {
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
            _linking = false;
            _error = e is AuthException ? e.message : e.toString();
            _session = null;
          });
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final uriHost = () {
      try {
        return Uri.parse(TvDeviceLinkAuth.webUrl).host;
      } catch (_) {
        return 'forja.app';
      }
    }();

    return ColoredBox(
      color: AppTheme.appBackground,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
              child: _starting
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: ForjaShellColors.progressFill,
                        ),
                        SizedBox(height: 24),
                        Text(
                          'Preparing TV link…',
                          style: TextStyle(
                            color: ForjaShellColors.textSecondary,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    )
                  : _linking
                      ? const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: ForjaShellColors.progressFill,
                            ),
                            SizedBox(height: 24),
                            Text(
                              'Signing in…',
                              style: TextStyle(
                                color: ForjaShellColors.textPrimary,
                                fontSize: 22,
                              ),
                            ),
                          ],
                        )
                      : session == null
                          ? _ErrorPane(
                              message: _error ?? 'Could not start TV linking.',
                              retryFocus: _retryFocus,
                              guestFocus: _guestFocus,
                              onRetry: () => unawaited(_start()),
                              onGuest: widget.onContinueAsGuest,
                            )
                          : _LinkPane(
                              userCode: session.userCode,
                              verificationUri: session.verificationUri,
                              verificationUriComplete:
                                  session.verificationUriComplete,
                              hostLabel: uriHost,
                              guestFocus: _guestFocus,
                              onGuest: widget.onContinueAsGuest,
                              error: _error,
                            ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkPane extends StatelessWidget {
  const _LinkPane({
    required this.userCode,
    required this.verificationUri,
    required this.verificationUriComplete,
    required this.hostLabel,
    required this.guestFocus,
    required this.onGuest,
    this.error,
  });

  final String userCode;
  final String verificationUri;
  final String verificationUriComplete;
  final String hostLabel;
  final FocusNode guestFocus;
  final VoidCallback onGuest;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final displayCode = userCode.length == 8
        ? '${userCode.substring(0, 4)} ${userCode.substring(4)}'
        : userCode;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Link your Forja account',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: ForjaShellColors.textPrimary,
            fontSize: 36,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'On your phone or computer, open $hostLabel/connect\nand enter this code — or scan the QR.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: ForjaShellColors.textSecondary,
            fontSize: 18,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 36),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                displayCode,
                textAlign: TextAlign.center,
                style: GoogleFonts.robotoMono(
                  color: ForjaShellColors.textPrimary,
                  fontSize: 56,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 6,
                ),
              ),
            ),
            const SizedBox(width: 48),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: QrImageView(
                  data: verificationUriComplete,
                  version: QrVersions.auto,
                  size: 180,
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
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          verificationUri.replaceFirst(RegExp(r'^https?://'), ''),
          style: const TextStyle(
            color: ForjaShellColors.iconMuted,
            fontSize: 15,
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 16),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFF87171), fontSize: 15),
          ),
        ],
        const SizedBox(height: 40),
        shellFocusableTap(
          context: context,
          focusNode: guestFocus,
          onTap: onGuest,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            child: Text(
              'Continue as guest',
              style: TextStyle(
                color: ForjaShellColors.textSecondary,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({
    required this.message,
    required this.retryFocus,
    required this.guestFocus,
    required this.onRetry,
    required this.onGuest,
  });

  final String message;
  final FocusNode retryFocus;
  final FocusNode guestFocus;
  final VoidCallback onRetry;
  final VoidCallback onGuest;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFF87171),
            fontSize: 18,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),
        shellFocusableTap(
          context: context,
          focusNode: retryFocus,
          onTap: onRetry,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            child: Text(
              'Try again',
              style: TextStyle(
                color: ForjaShellColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        shellFocusableTap(
          context: context,
          focusNode: guestFocus,
          onTap: onGuest,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            child: Text(
              'Continue as guest',
              style: TextStyle(
                color: ForjaShellColors.textSecondary,
                fontSize: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
