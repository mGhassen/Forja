import 'package:flutter/material.dart';
import 'package:forja/shared/downloads/download_page_store.dart';
import 'package:forja/shared/downloads/download_service.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Live save bar on a Downloads hub poster. Hidden once nothing is still saving.
class DownloadHubPosterFrame extends StatelessWidget {
  const DownloadHubPosterFrame({
    super.key,
    required this.mediaId,
    required this.child,
  });

  final String mediaId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DownloadService.instance.tasksNotifier,
      builder: (context, _) {
        final progress = downloadHubActiveProgress(
          DownloadService.instance.tasksNotifier.value,
          mediaId,
        );
        if (progress == null) return child;
        return Stack(
          children: [
            child,
            Positioned(
              left: 10,
              right: 10,
              bottom: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress.fraction,
                  minHeight: 3,
                  backgroundColor: Colors.white24,
                  color: ForjaShellColors.brandGreen,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
