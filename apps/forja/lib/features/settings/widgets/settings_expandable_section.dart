import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';

/// Collapsible settings section with animated expand/collapse.
class SettingsExpandableSection extends StatefulWidget {
  const SettingsExpandableSection({
    super.key,
    required this.id,
    required this.icon,
    required this.title,
    required this.children,
    this.initiallyExpanded = false,
  });

  final String id;
  final IconData icon;
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  State<SettingsExpandableSection> createState() =>
      _SettingsExpandableSectionState();
}

class _SettingsExpandableSectionState extends State<SettingsExpandableSection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: ShellTokens.settingsSectionBottomSpacing,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: _isExpanded ? 0.04 : 0.02),
          borderRadius: BorderRadius.circular(
            ShellTokens.settingsSectionRadius,
          ),
          border: Border.all(
            color: _isExpanded
                ? AppTheme.current.primaryColor.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(
                ShellTokens.settingsSectionRadius,
              ),
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.icon,
                      size: 20,
                      color: _isExpanded
                          ? AppTheme.current.primaryColor
                          : Colors.white54,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          color: _isExpanded ? Colors.white : Colors.white70,
                          fontSize: ShellTokens.settingsSectionTitleSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _isExpanded
                            ? AppTheme.current.primaryColor
                            : Colors.white30,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: Padding(
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.children,
                ),
              ),
              secondChild: const SizedBox.shrink(),
              crossFadeState: _isExpanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 200),
              sizeCurve: Curves.easeInOut,
            ),
          ],
        ),
      ),
    );
  }
}
