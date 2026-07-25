import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/supabase/forja_passkeys.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AccountEntryScreen extends StatefulWidget {
  const AccountEntryScreen({
    super.key,
    required this.onAuthenticated,
    required this.onContinueAsGuest,
  });

  final VoidCallback onAuthenticated;
  final VoidCallback onContinueAsGuest;

  @override
  State<AccountEntryScreen> createState() => _AccountEntryScreenState();
}

class _AccountEntryScreenState extends State<AccountEntryScreen>
    with TickerProviderStateMixin {
  static const _words = ['stream', 'sync', 'live', 'play'];

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _mfaController = TextEditingController();
  bool _obscurePassword = true;
  bool _busy = false;
  bool _webBusy = false;
  bool _passkeyBusy = false;
  bool _mfaBusy = false;
  String? _mfaFactorId;
  String? _message;
  bool _messageIsError = false;
  int _wordIndex = 0;
  Timer? _wordTimer;
  Completer<void>? _webCancel;
  String? _captchaToken;
  int _captchaKey = 0;

  late final AnimationController _breathe;
  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _wordTimer = Timer.periodic(const Duration(milliseconds: 3200), (_) {
      if (!mounted || _busy || _webBusy) return;
      setState(() => _wordIndex = (_wordIndex + 1) % _words.length);
    });
  }

  @override
  void dispose() {
    _wordTimer?.cancel();
    // Do not cancel web login here - disposing during browser handoff used to
    // abort the wait after the portal already got ok:true (browser closes,
    // app stays signed out). Explicit Cancel / Continue as guest still abort.
    _breathe.dispose();
    _enter.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _mfaController.dispose();
    super.dispose();
  }

  bool get _awaitingMfa => _mfaFactorId != null;

  Future<void> _finishAuthenticated() async {
    if (SyncService.instance.requiresMfaChallenge()) {
      final factors = SyncService.instance.listTotpFactors();
      if (factors.isEmpty) {
        setState(() {
          _message =
              'Authenticator required. Finish MFA on the web portal, then use Web login.';
          _messageIsError = true;
        });
        return;
      }
      setState(() {
        _mfaFactorId = factors.first.id;
        _message = 'Enter the 6-digit code from your authenticator app.';
        _messageIsError = false;
      });
      return;
    }
    widget.onAuthenticated();
  }

  Future<void> _submitMfa() async {
    final factorId = _mfaFactorId;
    final code = _mfaController.text.trim();
    if (factorId == null || code.length < 6) {
      setState(() {
        _message = 'Enter the 6-digit authenticator code.';
        _messageIsError = true;
      });
      return;
    }
    setState(() {
      _mfaBusy = true;
      _message = null;
    });
    try {
      await SyncService.instance.verifyMfaTotp(factorId: factorId, code: code);
      if (!mounted) return;
      setState(() {
        _mfaFactorId = null;
        _mfaController.clear();
      });
      widget.onAuthenticated();
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.message;
        _messageIsError = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'Could not verify the code. Try again.';
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _mfaBusy = false);
    }
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _message = 'Enter your email and password.';
        _messageIsError = true;
      });
      return;
    }
    if (ForjaCaptcha.isConfigured &&
        (_captchaToken == null || _captchaToken!.isEmpty)) {
      setState(() {
        _message = 'Complete the captcha check, then try again.';
        _messageIsError = true;
      });
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final response = await SyncService.instance.signInWithPassword(
        email: email,
        password: password,
        captchaToken: _captchaToken,
      );
      if (!mounted) return;
      if (response.session == null) {
        setState(() {
          _message =
              'Check your email and open the confirmation link, then come back to sign in.';
          _messageIsError = false;
        });
        return;
      }
      await _finishAuthenticated();
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.message;
        _messageIsError = true;
        _captchaToken = null;
        _captchaKey++;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message =
            'Could not connect to Forja. Check your connection and retry.';
        _messageIsError = true;
        _captchaToken = null;
        _captchaKey++;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _passkeyLogin() async {
    if (!ForjaPasskeys.supported) return;
    if (ForjaCaptcha.isConfigured &&
        (_captchaToken == null || _captchaToken!.isEmpty)) {
      setState(() {
        _message = 'Complete the captcha check, then try again.';
        _messageIsError = true;
      });
      return;
    }

    setState(() {
      _passkeyBusy = true;
      _message = null;
    });
    try {
      final response = await SyncService.instance.signInWithPasskey(
        captchaToken: _captchaToken,
      );
      if (!mounted) return;
      if (response.session == null) {
        setState(() {
          _message = 'Passkey sign-in did not complete. Try again.';
          _messageIsError = true;
        });
        return;
      }
      await _finishAuthenticated();
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.message;
        _messageIsError = true;
        _captchaToken = null;
        _captchaKey++;
      });
    } catch (error) {
      if (!mounted) return;
      debugPrint('[Account] passkey sign-in failed: $error');
      setState(() {
        _message = ForjaPasskeys.userMessage(error);
        _messageIsError = true;
        _captchaToken = null;
        _captchaKey++;
      });
    } finally {
      if (mounted) setState(() => _passkeyBusy = false);
    }
  }

  Future<void> _webLogin() async {
    final cancel = Completer<void>();
    _webCancel = cancel;
    setState(() {
      _webBusy = true;
      _message =
          'Opening browser - sign in on the web, then return here. '
          'Tap Cancel if the browser does not open.';
      _messageIsError = false;
    });
    try {
      final response = await SyncService.instance.signInWithBrowser(
        cancel: cancel.future,
      );
      if (!mounted) return;
      if (response.session == null) {
        setState(() {
          _message = 'Web login did not complete. Try again.';
          _messageIsError = true;
        });
        return;
      }
      await _finishAuthenticated();
    } on AuthException catch (error) {
      if (!mounted) return;
      final cancelled = error.message == 'Web login cancelled.';
      setState(() {
        _message = cancelled
            ? null
            : error.message;
        _messageIsError = !cancelled;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message =
            'Could not finish web login. Check that the portal is reachable.';
        _messageIsError = true;
      });
    } finally {
      _webCancel = null;
      if (mounted) setState(() => _webBusy = false);
    }
  }

  void _cancelWebLogin() {
    final cancel = _webCancel;
    if (cancel == null || cancel.isCompleted) return;
    cancel.complete();
  }

  void _continueAsGuest() {
    _cancelWebLogin();
    widget.onContinueAsGuest();
  }

  Future<void> _openSignup() async {
    final uri = DesktopBrowserAuth.signupUri();
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      setState(() {
        _message = 'Could not open the signup page in your browser.';
        _messageIsError = true;
      });
    }
  }

  /// Password auth locks the form. Web login only locks email/password submit
  /// so Cancel / guest stay available if the browser never returns.
  bool get _formLocked => _busy || _webBusy || _passkeyBusy || _mfaBusy;
  bool get _passwordLocked => _busy || _passkeyBusy || _mfaBusy;
  bool get _captchaReady =>
      !ForjaCaptcha.isConfigured ||
      (_captchaToken != null && _captchaToken!.isNotEmpty);
  bool get _canSubmitPassword => !_formLocked && _captchaReady;
  bool get _canSubmitPasskey =>
      ForjaPasskeys.supported && !_formLocked && _captchaReady;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 980;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: AnimatedBuilder(
        animation: Listenable.merge([_breathe, _enter]),
        builder: (context, _) {
          final t = Curves.easeOutCubic.transform(_enter.value);
          final glow = 0.10 + (_breathe.value * 0.06);
          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _AccountAtmospherePainter(
                  breathe: _breathe.value,
                  greenGlow: glow,
                ),
              ),
              SafeArea(
                child: Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * 18),
                    child: wide
                        ? Row(
                            children: [
                              Expanded(flex: 11, child: _buildStory()),
                              Expanded(
                                flex: 10,
                                child: _buildForm(maxWidth: 420),
                              ),
                            ],
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 24,
                            ),
                            child: Column(
                              children: [
                                _buildStory(compact: true),
                                const SizedBox(height: 28),
                                _buildForm(maxWidth: 440),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStory({bool compact = false}) {
    final word = _words[_wordIndex];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 8 : 56,
        compact ? 12 : 48,
        compact ? 8 : 40,
        compact ? 8 : 48,
      ),
      child: Align(
        alignment: compact ? Alignment.center : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: compact
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/icon/logo-dark.png',
                width: compact ? 96 : 118,
                fit: BoxFit.contain,
              ),
              SizedBox(height: compact ? 28 : 40),
              Text(
                'CREATIVE PLAYER',
                textAlign: compact ? TextAlign.center : TextAlign.start,
                style: GoogleFonts.spaceMono(
                  color: ForjaShellColors.brandGreen.withValues(alpha: 0.85),
                  fontSize: 11,
                  letterSpacing: 3.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Text.rich(
                TextSpan(
                  style: GoogleFonts.oswald(
                    color: ForjaShellColors.textPrimary,
                    fontSize: compact ? 40 : 56,
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                  children: [
                    const TextSpan(text: 'One player.\nYour sources.\nEvery '),
                    TextSpan(
                      text: word,
                      style: TextStyle(color: ForjaShellColors.brandGreen),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
                textAlign: compact ? TextAlign.center : TextAlign.start,
              ),
              SizedBox(height: compact ? 16 : 22),
              Text(
                'Sign in to sync settings and profiles across every screen. '
                'New accounts live on the web - not in the app.',
                textAlign: compact ? TextAlign.center : TextAlign.start,
                style: GoogleFonts.plusJakartaSans(
                  color: ForjaShellColors.textSecondary.withValues(alpha: 0.95),
                  fontSize: 15,
                  height: 1.55,
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 36),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: const [
                    _StoryChip('Playback'),
                    _StoryChip('IPTV guides'),
                    _StoryChip('Profiles'),
                    _StoryChip('Desk → TV'),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm({required double maxWidth}) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Welcome back',
                  style: GoogleFonts.oswald(
                    color: ForjaShellColors.textPrimary,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _awaitingMfa
                      ? 'Enter the code from your authenticator app to finish sign-in.'
                      : 'Use your Forja account, or open the browser to sign in on the web.',
                  style: GoogleFonts.plusJakartaSans(
                    color: ForjaShellColors.textSecondary,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 32),
                if (_awaitingMfa) ...[
                  _HairlineField(
                    controller: _mfaController,
                    enabled: !_mfaBusy,
                    label: 'Authenticator code',
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    prefix: Icons.phonelink_lock_rounded,
                    onSubmitted: (_) => _submitMfa(),
                  ),
                ] else ...[
                  _HairlineField(
                    controller: _emailController,
                    enabled: !_formLocked,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    prefix: Icons.alternate_email_rounded,
                  ),
                  const SizedBox(height: 18),
                  _HairlineField(
                    controller: _passwordController,
                    enabled: !_formLocked,
                    label: 'Password',
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    prefix: Icons.lock_outline_rounded,
                    onSubmitted: (_) => _submit(),
                    suffix: IconButton(
                      tooltip: _obscurePassword
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: _formLocked
                          ? null
                          : () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: ForjaShellColors.textSecondary,
                      ),
                    ),
                  ),
                  if (ForjaCaptcha.isConfigured)
                    IgnorePointer(
                      ignoring: _formLocked,
                      child: Opacity(
                        opacity: _formLocked ? 0.55 : 1,
                        child: TurnstileCaptcha(
                          key: ValueKey(_captchaKey),
                          onToken: (token) {
                            if (!mounted) return;
                            setState(() => _captchaToken = token);
                          },
                        ),
                      ),
                    ),
                ],
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _message!,
                    style: GoogleFonts.plusJakartaSans(
                      color: _messageIsError
                          ? const Color(0xFFFF8A80)
                          : ForjaShellColors.brandGreen,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                if (_awaitingMfa)
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _mfaBusy ? null : _submitMfa,
                      style: FilledButton.styleFrom(
                        backgroundColor: ForjaShellColors.brandGreen,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: ForjaShellColors.brandGreen
                            .withValues(alpha: 0.35),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _mfaBusy ? 'Verifying…' : 'Verify code',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 52,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: _canSubmitPassword ? _submit : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: ForjaShellColors.brandGreen,
                              foregroundColor: Colors.black,
                              disabledBackgroundColor: ForjaShellColors
                                  .brandGreen
                                  .withValues(alpha: 0.35),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              _busy ? 'Connecting…' : 'Sign in',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                        if (ForjaPasskeys.supported) ...[
                          const SizedBox(width: 8),
                          _AuthIconButton(
                            tooltip: _passkeyBusy
                                ? 'Waiting for passkey…'
                                : 'Sign in with passkey',
                            icon: _passkeyBusy
                                ? Icons.hourglass_top_rounded
                                : Icons.fingerprint_rounded,
                            onPressed:
                                _canSubmitPasskey ? _passkeyLogin : null,
                          ),
                        ],
                        const SizedBox(width: 8),
                        _AuthIconButton(
                          tooltip: _webBusy
                              ? 'Cancel web login'
                              : 'Web login',
                          icon: _webBusy
                              ? Icons.close_rounded
                              : Icons.language_rounded,
                          onPressed: _passwordLocked
                              ? null
                              : (_webBusy ? _cancelWebLogin : _webLogin),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 22),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _formLocked ? null : _openSignup,
                    style: TextButton.styleFrom(
                      foregroundColor: ForjaShellColors.brandGreen,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Create an account on the web →',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Divider(
                  height: 1,
                  color: ForjaShellColors.borderSubtle.withValues(alpha: 0.9),
                ),
                const SizedBox(height: 18),
                TextButton.icon(
                  onPressed: _busy ? null : _continueAsGuest,
                  icon: Icon(
                    Icons.person_outline_rounded,
                    size: 20,
                    color: ForjaShellColors.textSecondary.withValues(
                      alpha: _busy ? 0.4 : 1,
                    ),
                  ),
                  label: Text(
                    'Continue without an account',
                    style: GoogleFonts.plusJakartaSans(
                      color: ForjaShellColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Guest mode keeps everything on this device. You can sign in later from Settings.',
                  style: GoogleFonts.plusJakartaSans(
                    color: ForjaShellColors.textSecondary.withValues(
                      alpha: 0.85,
                    ),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthIconButton extends StatelessWidget {
  const _AuthIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      child: Tooltip(
        message: tooltip,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: ForjaShellColors.textPrimary,
            padding: EdgeInsets.zero,
            side: BorderSide(
              color: ForjaShellColors.textPrimary.withValues(alpha: 0.35),
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
          ),
          child: Icon(icon, size: 22),
        ),
      ),
    );
  }
}

class _StoryChip extends StatelessWidget {
  const _StoryChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(
          color: ForjaShellColors.textPrimary.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.spaceMono(
          color: ForjaShellColors.textSecondary,
          fontSize: 10,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HairlineField extends StatelessWidget {
  const _HairlineField({
    required this.controller,
    required this.label,
    required this.prefix,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final IconData prefix;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onSubmitted: onSubmitted,
      style: GoogleFonts.plusJakartaSans(
        color: ForjaShellColors.textPrimary,
        fontSize: 15,
      ),
      cursorColor: ForjaShellColors.brandGreen,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.plusJakartaSans(
          color: ForjaShellColors.textSecondary,
        ),
        prefixIcon: Icon(prefix, color: ForjaShellColors.textSecondary),
        suffixIcon: suffix,
        filled: false,
        border: const UnderlineInputBorder(
          borderSide: BorderSide(color: ForjaShellColors.borderSubtle),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: ForjaShellColors.textPrimary.withValues(alpha: 0.22),
          ),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: ForjaShellColors.brandGreen, width: 1.6),
        ),
        disabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: ForjaShellColors.borderSubtle.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

class _AccountAtmospherePainter extends CustomPainter {
  _AccountAtmospherePainter({
    required this.breathe,
    required this.greenGlow,
  });

  final double breathe;
  final double greenGlow;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppTheme.bgDark,
    );

    final green = Paint()
      ..shader = RadialGradient(
        center: Alignment(-0.75 + breathe * 0.08, -0.35),
        radius: 1.05,
        colors: [
          ForjaShellColors.brandGreen.withValues(alpha: greenGlow),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, green);

    final flame = Paint()
      ..shader = RadialGradient(
        center: Alignment(0.85, 0.7 - breathe * 0.1),
        radius: 0.85,
        colors: [
          const Color(0xFFFF4D1C).withValues(alpha: 0.08 + breathe * 0.04),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, flame);

    final grain = Paint()
      ..color = Colors.white.withValues(alpha: 0.015)
      ..strokeWidth = 1;
    final rng = math.Random(42);
    for (var i = 0; i < 180; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), 0.6, grain);
    }

    final rule = Paint()
      ..color = ForjaShellColors.textPrimary.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    if (size.width >= 980) {
      final x = size.width * (11 / 21);
      canvas.drawLine(Offset(x, 48), Offset(x, size.height - 48), rule);
    }
  }

  @override
  bool shouldRepaint(covariant _AccountAtmospherePainter oldDelegate) =>
      oldDelegate.breathe != breathe || oldDelegate.greenGlow != greenGlow;
}
