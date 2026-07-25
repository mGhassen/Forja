import 'dart:io';

import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/navigation/shell_back_icon_button.dart';
import 'package:forja/shared/player/controls/player_app_menu.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rust/rust.dart';

/// Handoff screen while playback runs in an external app.
class ExternalPlayerHandoffScreen extends StatefulWidget {
  const ExternalPlayerHandoffScreen({
    super.key,
    required this.title,
    required this.playerName,
    required this.launched,
    required this.builtInEngine,
    required this.onRelaunch,
    required this.onSwitchBuiltIn,
    required this.onSelectPlayer,
  });

  final String title;
  final String playerName;
  final bool launched;
  final BuiltInPlayerEngine builtInEngine;
  final VoidCallback onRelaunch;
  final VoidCallback onSwitchBuiltIn;
  final PlayerMenuSelectHandler onSelectPlayer;

  @override
  State<ExternalPlayerHandoffScreen> createState() =>
      _ExternalPlayerHandoffScreenState();
}

class _ExternalPlayerHandoffScreenState
    extends State<ExternalPlayerHandoffScreen> {
  bool _pickingPlayer = false;

  TextStyle get _titleStyle => GoogleFonts.plusJakartaSans(
        color: ForjaShellColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.25,
      );

  TextStyle get _captionStyle => GoogleFonts.plusJakartaSans(
        color: ForjaShellColors.textSecondary,
        fontSize: 13,
        height: 1.45,
      );

  @override
  Widget build(BuildContext context) {
    return ShellScopeBuilder(
      builder: (context, _) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final isDesktop =
        Platform.isMacOS || Platform.isWindows || Platform.isLinux;

    return Scaffold(
      backgroundColor: DesignTokens.bgDark,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: isDesktop ? 12 : 4,
              left: 12,
              // Picker owns its FocusScope - keep Back out of the D-pad walk.
              child: ExcludeFocus(
                excluding: _pickingPlayer,
                child: ShellBackIconButton(
                  icon: Icons.chevron_left_rounded,
                  size: 28,
                  tooltip: 'Back',
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: _HandoffCard(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: _pickingPlayer
                          ? _PlayerPickerBody(
                              key: const ValueKey('picker'),
                              playerName: widget.playerName,
                              builtInEngine: widget.builtInEngine,
                              onSelectPlayer: widget.onSelectPlayer,
                              onCancel: () =>
                                  setState(() => _pickingPlayer = false),
                            )
                          : _StatusBody(
                              key: const ValueKey('status'),
                              title: widget.title,
                              playerName: widget.playerName,
                              launched: widget.launched,
                              titleStyle: _titleStyle,
                              captionStyle: _captionStyle,
                              onRelaunch: widget.onRelaunch,
                              onChangePlayer: widget.launched
                                  ? () => setState(() => _pickingPlayer = true)
                                  : null,
                              onSwitchBuiltIn: widget.onSwitchBuiltIn,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HandoffCard extends StatelessWidget {
  const _HandoffCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ForjaShellColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ForjaShellColors.borderSubtle),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }
}

class _StatusBody extends StatelessWidget {
  const _StatusBody({
    super.key,
    required this.title,
    required this.playerName,
    required this.launched,
    required this.titleStyle,
    required this.captionStyle,
    required this.onRelaunch,
    required this.onChangePlayer,
    required this.onSwitchBuiltIn,
  });

  final String title;
  final String playerName;
  final bool launched;
  final TextStyle titleStyle;
  final TextStyle captionStyle;
  final VoidCallback onRelaunch;
  final VoidCallback? onChangePlayer;
  final VoidCallback onSwitchBuiltIn;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (launched)
                const _LiveStatusBadge()
              else
                const _LaunchingIndicator(),
              const SizedBox(height: 20),
              Text(
                launched ? title : 'Opening in $playerName…',
                style: titleStyle,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (launched) ...[
                const SizedBox(height: 8),
                Text(
                  'via $playerName',
                  style: captionStyle.copyWith(
                    fontWeight: FontWeight.w500,
                    color: ForjaShellColors.iconActive,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Forja keeps the stream alive while you watch externally.',
                  style: captionStyle,
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                const SizedBox(height: 12),
                Text(
                  title,
                  style: captionStyle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        if (launched) ...[
          const Divider(height: 1, color: ForjaShellColors.borderSubtle),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HandoffActionRow(
                  icon: Icons.refresh_rounded,
                  label: 'Re-launch in $playerName',
                  onTap: onRelaunch,
                ),
                if (onChangePlayer != null)
                  _HandoffActionRow(
                    icon: Icons.smart_display_outlined,
                    label: 'Change player',
                    onTap: onChangePlayer,
                    showChevron: true,
                  ),
                _HandoffActionRow(
                  icon: Icons.play_circle_outline_rounded,
                  label: 'Watch in Forja instead',
                  onTap: onSwitchBuiltIn,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PlayerPickerBody extends StatelessWidget {
  const _PlayerPickerBody({
    super.key,
    required this.playerName,
    required this.builtInEngine,
    required this.onSelectPlayer,
    required this.onCancel,
  });

  final String playerName;
  final BuiltInPlayerEngine builtInEngine;
  final PlayerMenuSelectHandler onSelectPlayer;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Choose player',
                  style: GoogleFonts.plusJakartaSans(
                    color: ForjaShellColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              // Order 0: ↑ from first list row lands here (exit).
              FocusTraversalOrder(
                order: const NumericFocusOrder(0),
                child: ForjaCloseButton.compact(
                  color: ForjaShellColors.textSecondary,
                  onTap: onCancel,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: ForjaShellColors.borderSubtle),
        FocusTraversalOrder(
          order: const NumericFocusOrder(1),
          child: PlayerAppMenu.buildPickerList(
            usingBuiltIn: false,
            builtInEngine: builtInEngine,
            externalPlayerName: playerName,
            physics: const NeverScrollableScrollPhysics(),
            onSelect: ({builtInEngine, externalPlayer}) async {
              onCancel();
              await onSelectPlayer(
                builtInEngine: builtInEngine,
                externalPlayer: externalPlayer,
              );
            },
          ),
        ),
        FocusTraversalOrder(
          order: const NumericFocusOrder(2),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: _HandoffActionRow(
              icon: Icons.close_rounded,
              label: 'Cancel',
              onTap: onCancel,
            ),
          ),
        ),
      ],
    );
    if (!tv) return body;
    // Ordered walk: Close(0) → engines/apps(1) → Cancel(2); no wrap to last.
    return FocusScope(
      debugLabel: 'handoff-choose-player',
      autofocus: true,
      child: ShellTvLinearFocusScope(
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: PlayerPopupListFocusScope(
            child: _TvPickerFocusOnOpen(child: body),
          ),
        ),
      ),
    );
  }
}

/// Lands primary focus on the first picker control after open.
class _TvPickerFocusOnOpen extends StatefulWidget {
  const _TvPickerFocusOnOpen({required this.child});

  final Widget child;

  @override
  State<_TvPickerFocusOnOpen> createState() => _TvPickerFocusOnOpenState();
}

class _TvPickerFocusOnOpenState extends State<_TvPickerFocusOnOpen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final scope = FocusScope.of(context);
      if (scope.focusedChild != null) return;
      scope.nextFocus();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _LiveStatusBadge extends StatelessWidget {
  const _LiveStatusBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: ForjaShellColors.brandGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ForjaShellColors.brandGreen.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: ForjaShellColors.brandGreen,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: ForjaShellColors.brandGreen.withValues(alpha: 0.5),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Stream active',
            style: GoogleFonts.plusJakartaSans(
              color: ForjaShellColors.brandGreen,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _LaunchingIndicator extends StatelessWidget {
  const _LaunchingIndicator();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: ForjaShellColors.brandGreen,
      ),
    );
  }
}

class _HandoffActionRow extends StatelessWidget {
  const _HandoffActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showChevron = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return ForjaInteractive(
      onTap: onTap,
      hoverScale: 1,
      pressScale: 1,
      builder: (active, pressed) {
        final highlight = active || pressed;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            color: highlight ? ForjaShellColors.inkHover : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: highlight
                    ? ForjaShellColors.iconHover
                    : ForjaShellColors.iconActive,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    color: ForjaShellColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (showChevron)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: highlight
                      ? ForjaShellColors.iconHover
                      : ForjaShellColors.iconMuted,
                ),
            ],
          ),
        );
      },
    );
  }
}
