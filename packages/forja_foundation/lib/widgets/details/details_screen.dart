import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';

/// Catalog details page paint — loading / error / body slots (RFC-106 Zone A).
///
/// Host wires MetaRuntime, Riverpod, play, and back chrome into these slots.
class DetailsScreen extends StatelessWidget {
  const DetailsScreen({
    super.key,
    required this.backgroundColor,
    this.loading = false,
    this.errorMessage,
    this.onRetry,
    this.loadingChild,
    this.errorChild,
    this.body,
    this.overlay,
  });

  final Color backgroundColor;
  final bool loading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final Widget? loadingChild;
  final Widget? errorChild;
  final Widget? body;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    Widget content;
    if (loading) {
          content = loadingChild ??
          Center(
            child: CircularProgressIndicator(color: theme.brandGreen),
          );
    } else if (errorMessage != null && errorMessage!.trim().isNotEmpty) {
      content = errorChild ??
          Center(
            child: Padding(
              padding: EdgeInsets.all(theme.spaceLg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.textSecondary),
                  ),
                  if (onRetry != null) ...[
                    SizedBox(height: theme.spaceMd),
                    TextButton(onPressed: onRetry, child: const Text('Retry')),
                  ],
                ],
              ),
            ),
          );
    } else {
      content = body ?? const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          content,
          ?overlay,
        ],
      ),
    );
  }
}
