import 'package:flutter/material.dart';
import 'package:forja/features/settings/ui/settings_ui.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shell/desktop/desktop_window_chrome.dart';
import 'package:forja_foundation/components/button.dart';
import 'package:forja_foundation/tokens/forja_settings_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Authenticator (TOTP) step for a session that is still AAL1 — used by the
/// sign-in screen and by account switching.
///
/// The code field is a [SettingsTextField]: leanback D-pad focus only
/// highlights it, OK / Enter opens editing; desktop types on focus.
class MfaChallengeView extends StatefulWidget {
  const MfaChallengeView({
    super.key,
    required this.onVerified,
    this.onCancel,
    this.title = 'Authenticator code',
    this.cancelLabel = 'Cancel',
  });

  final VoidCallback onVerified;
  final VoidCallback? onCancel;
  final String title;
  final String cancelLabel;

  /// Fullscreen route with the challenge; resolves true once verified, false
  /// when cancelled or when no verified factor exists on this account.
  static Future<bool> present(BuildContext context) async {
    final ok = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => DesktopWindowChrome.wrapShell(
          child: Scaffold(
            backgroundColor: AppTheme.bgDark,
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: MfaChallengeView(
                      onVerified: () => Navigator.of(context).pop(true),
                      onCancel: () => Navigator.of(context).pop(false),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return ok == true;
  }

  @override
  State<MfaChallengeView> createState() => _MfaChallengeViewState();
}

class _MfaChallengeViewState extends State<MfaChallengeView> {
  final _codeController = TextEditingController();
  String? _factorId;
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    final factors = SyncService.instance.listTotpFactors();
    if (factors.isEmpty) {
      _message =
          'Authenticator required. Finish MFA on the web portal, then sign in again.';
      _messageIsError = true;
    } else {
      _factorId = factors.first.id;
      _message = 'Enter the 6-digit code from your authenticator app.';
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final factorId = _factorId;
    final code = _codeController.text.trim();
    if (factorId == null || code.length < 6) {
      setState(() {
        _message = 'Enter the 6-digit authenticator code.';
        _messageIsError = true;
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await SyncService.instance.verifyMfaTotp(factorId: factorId, code: code);
      if (!mounted) return;
      _codeController.clear();
      widget.onVerified();
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
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFactor = _factorId != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.title,
          style: TextStyle(
            color: ForjaShellColors.textPrimary,
            fontSize: SettingsTokens.typeSizeOf(context, 22),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        if (hasFactor)
          SettingsTextField(
            controller: _codeController,
            label: 'Authenticator code',
            hint: '123456',
            keyboardType: TextInputType.number,
            maxLength: 8,
            enabled: !_busy,
            autofocus: true,
            onSubmitted: _busy ? null : (_) => _submit(),
          ),
        if (_message != null) ...[
          const SizedBox(height: 12),
          Text(
            _message!,
            style: TextStyle(
              color: _messageIsError
                  ? const Color(0xFFF87171)
                  : ForjaShellColors.brandGreen,
              fontSize: SettingsTokens.typeSizeOf(context, 13),
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 20),
        FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (hasFactor)
                Button(
                  variant: ButtonVariant.primary,
                  label: _busy ? 'Verifying…' : 'Verify code',
                  loading: _busy,
                  onPressed: _busy ? null : _submit,
                ),
              if (widget.onCancel != null)
                Button(
                  label: widget.cancelLabel,
                  onPressed: _busy ? null : widget.onCancel,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
