import 'package:flutter/material.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja_foundation/components/button.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/mobile_chrome_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_chip.dart';
import 'package:forja_foundation/widgets/feedback/bottom_sheet_panel.dart';

/// Phone presentation of the hub top-bar Categories menu: a bottom sheet
/// with a wrap of chips. Same items and result as the desktop dropdown.
///
/// Returns the picked category id, [allValue] for "All", or null when the
/// sheet is dismissed.
Future<String?> showKitCategoriesMobileSheet({
  required BuildContext context,
  required List<({String id, String label})> categories,
  required String? selectedId,
  required String allValue,
  String title = 'Categories',
  String allLabel = 'All',
}) {
  final shellScope = ShellScope.maybeOf(context);
  final maxHeight =
      MediaQuery.sizeOf(context).height *
      MobileChromeTokens.categoriesSheetMaxFraction;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: ForjaShellColors.cinematic.menuSurface,
    barrierColor: Colors.black.withValues(
      alpha: MobileChromeTokens.sheetScrimAlpha,
    ),
    constraints: BoxConstraints(maxHeight: maxHeight),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(MobileChromeTokens.sheetTopRadius),
      ),
    ),
    builder: (sheetContext) {
      final sheet = KitCategoriesMobileSheet(
        title: title,
        allLabel: allLabel,
        categories: categories,
        selectedId: selectedId,
        onPick: (id) => Navigator.of(sheetContext).pop(id ?? allValue),
        onClose: () => Navigator.of(sheetContext).pop(),
      );
      if (shellScope == null) return sheet;
      return ShellScope(
        profile: shellScope.profile,
        config: shellScope.config,
        child: sheet,
      );
    },
  );
}

/// Sheet body: handle, title + close, wrap of category chips.
class KitCategoriesMobileSheet extends StatelessWidget {
  const KitCategoriesMobileSheet({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onPick,
    required this.onClose,
    this.title = 'Categories',
    this.allLabel = 'All',
  });

  final List<({String id, String label})> categories;

  /// Null = "All" selected.
  final String? selectedId;

  /// Null id = "All".
  final ValueChanged<String?> onPick;
  final VoidCallback onClose;
  final String title;
  final String allLabel;

  @override
  Widget build(BuildContext context) {
    final cinematic = ForjaShellColors.cinematic;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: MobileChromeTokens.sheetHandleTopGap),
        const Center(child: ForjaSheetHandle()),
        const SizedBox(height: MobileChromeTokens.sheetHandleBottomGap),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            MobileChromeTokens.categoriesSheetPadH,
            0,
            MobileChromeTokens.categoriesSheetPadH / 2,
            MobileChromeTokens.sheetHeaderPadBottom,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cinematic.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: MobileChromeTokens.sheetTitleFontSize,
                  ),
                ),
              ),
              Button(
                variant: ButtonVariant.plainIcon,
                size: ButtonSize.icon,
                icon: Icons.close_rounded,
                tooltip: 'Close',
                color: cinematic.textSecondary,
                onPressed: onClose,
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              MobileChromeTokens.categoriesSheetPadH,
              0,
              MobileChromeTokens.categoriesSheetPadH,
              MobileChromeTokens.categoriesSheetPadBottom + bottomInset,
            ),
            child: Wrap(
              spacing: MobileChromeTokens.categoriesSheetChipGap,
              runSpacing: MobileChromeTokens.categoriesSheetChipGap,
              children: [
                ForjaShellChip(
                  label: allLabel,
                  selected: selectedId == null,
                  onTap: () => onPick(null),
                ),
                for (final c in categories)
                  ForjaShellChip(
                    label: c.label,
                    selected: c.id == selectedId,
                    onTap: () => onPick(c.id),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
