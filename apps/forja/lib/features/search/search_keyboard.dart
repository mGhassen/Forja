import 'package:flutter/material.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:forja/shared/theme/app_theme.dart';

/// On-screen QWERTY keyboard for the cinematic search page (desktop / TV).
class SearchKeyboard extends StatefulWidget {
  const SearchKeyboard({
    super.key,
    required this.onCharacter,
    required this.onBackspace,
    required this.onSubmit,
    this.onSpace,
  });

  final ValueChanged<String> onCharacter;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;
  final VoidCallback? onSpace;

  @override
  State<SearchKeyboard> createState() => _SearchKeyboardState();
}

class _SearchKeyboardState extends State<SearchKeyboard> {
  bool _shift = false;

  static const _row1 = ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '.'];
  static const _row2 = ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'];
  static const _row3 = ['z', 'x', 'c', 'v', 'b', 'n', 'm', '@'];

  void _type(String char) {
    final out = _shift ? char.toUpperCase() : char;
    widget.onCharacter(out);
    if (_shift && char.length == 1 && RegExp(r'[a-z]').hasMatch(char)) {
      setState(() => _shift = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildRow(_row1.map((c) => _letterKey(c)).toList()),
        const SizedBox(height: ShellTokens.searchKeyboardKeyGap),
        _buildRow([
          _spacer(flex: 1),
          ..._row2.map((c) => _letterKey(c)),
          _spacer(flex: 1),
        ]),
        const SizedBox(height: ShellTokens.searchKeyboardKeyGap),
        _buildRow([
          _actionKey(
            icon: Icons.arrow_upward,
            active: _shift,
            onTap: () => setState(() => _shift = !_shift),
            flex: 2,
          ),
          ..._row3.map((c) => _letterKey(c)),
          _actionKey(icon: Icons.backspace_outlined, onTap: widget.onBackspace, flex: 2),
        ]),
        const SizedBox(height: ShellTokens.searchKeyboardKeyGap),
        _buildRow([
          _actionKey(label: '123?', flex: 2, onTap: () {}),
          _actionKey(icon: Icons.chevron_left, onTap: () {}, flex: 1),
          _actionKey(icon: Icons.chevron_right, onTap: () {}, flex: 1),
          _actionKey(
            label: '',
            onTap: widget.onSpace ?? () => widget.onCharacter(' '),
            flex: 6,
            child: const SizedBox.shrink(),
          ),
          _letterKey('-', flex: 1),
          _letterKey('_', flex: 1),
          _actionKey(
            onTap: widget.onSubmit,
            flex: 3,
            background: AppTheme.current.primaryColor,
            foreground: Colors.black,
            child: const Icon(Icons.arrow_forward, size: 22),
          ),
        ]),
      ],
    );
  }

  Widget _buildRow(List<Widget> children) {
    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: ShellTokens.searchKeyboardKeyGap),
          children[i],
        ],
      ],
    );
  }

  Widget _spacer({required int flex}) => Expanded(flex: flex, child: const SizedBox());

  Widget _letterKey(String char, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: _SearchKey(
        label: _shift ? char.toUpperCase() : char,
        onTap: () => _type(char),
      ),
    );
  }

  Widget _actionKey({
    String label = '',
    IconData? icon,
    required VoidCallback onTap,
    int flex = 1,
    bool active = false,
    Color? background,
    Color? foreground,
    Widget? child,
  }) {
    return Expanded(
      flex: flex,
      child: _SearchKey(
        label: label,
        onTap: onTap,
        active: active,
        background: background,
        foreground: foreground,
        child: child ?? (icon != null ? Icon(icon, size: 18) : null),
      ),
    );
  }
}

class _SearchKey extends StatelessWidget {
  const _SearchKey({
    required this.label,
    required this.onTap,
    this.child,
    this.background,
    this.foreground,
    this.active = false,
  });

  final String label;
  final VoidCallback onTap;
  final Widget? child;
  final Color? background;
  final Color? foreground;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final bg = background ??
        (active ? Colors.white : ForjaShellColors.surfaceElevated);
    final fg = foreground ?? (active ? Colors.black : ForjaShellColors.textPrimary);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ShellTokens.searchKeyboardKeyRadius),
        child: Ink(
          height: ShellTokens.searchKeyboardKeyHeight,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(ShellTokens.searchKeyboardKeyRadius),
            border: Border.all(
              color: active ? Colors.white : ForjaShellColors.borderSubtle,
            ),
          ),
          child: Center(
            child: child ??
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontSize: label.length > 2 ? 11 : 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
          ),
        ),
      ),
    );
  }
}
