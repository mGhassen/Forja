import 'package:flutter/material.dart';
import 'package:rust/rust.dart';

class StreamSourcePanel {
  static Future<void> show(
    BuildContext context, {
    required List<StreamSource> sources,
    required String? currentUrl,
    required String? current111477FileUrl,
    required bool is111477,
    required Future<void> Function(StreamSource source, int index) onSelect,
    bool useSidePanel = true,
  }) async {
    if (sources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No sources available'), duration: Duration(seconds: 1)),
      );
      return;
    }

    if (useSidePanel && MediaQuery.sizeOf(context).width >= 700) {
      await showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Sources',
        barrierColor: Colors.black54,
        pageBuilder: (ctx, _, _) => Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: const Color(0xFF141414),
            child: SizedBox(
              width: 360,
              height: MediaQuery.sizeOf(ctx).height,
              child: _SourceList(
                sources: sources,
                currentUrl: currentUrl,
                current111477FileUrl: current111477FileUrl,
                is111477: is111477,
                onSelect: (s, i) async {
                  Navigator.pop(ctx);
                  await onSelect(s, i);
                },
              ),
            ),
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: 420,
          child: _SourceList(
            sources: sources,
            currentUrl: currentUrl,
            current111477FileUrl: current111477FileUrl,
            is111477: is111477,
            onSelect: (s, i) async {
              Navigator.pop(ctx);
              await onSelect(s, i);
            },
          ),
        ),
      ),
    );
  }
}

class _SourceList extends StatelessWidget {
  const _SourceList({
    required this.sources,
    required this.currentUrl,
    required this.current111477FileUrl,
    required this.is111477,
    required this.onSelect,
  });

  final List<StreamSource> sources;
  final String? currentUrl;
  final String? current111477FileUrl;
  final bool is111477;
  final Future<void> Function(StreamSource source, int index) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Video Sources',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Colors.white12),
        Expanded(
          child: ListView.builder(
            itemCount: sources.length,
            itemBuilder: (context, index) {
              final source = sources[index];
              final isCurrent = is111477
                  ? source.url == current111477FileUrl
                  : source.url == currentUrl;
              return ListTile(
                leading: Icon(
                  Icons.play_circle_outline,
                  color: isCurrent ? const Color(0xFF7C3AED) : Colors.white70,
                ),
                title: Text(
                  source.title,
                  style: TextStyle(
                    color: isCurrent ? const Color(0xFF7C3AED) : Colors.white,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  source.type.toUpperCase(),
                  style: TextStyle(
                    color: isCurrent
                        ? const Color(0xFF7C3AED).withValues(alpha: 0.7)
                        : Colors.white54,
                    fontSize: 11,
                  ),
                ),
                trailing: isCurrent ? const Icon(Icons.check, color: Color(0xFF7C3AED)) : null,
                onTap: () => onSelect(source, index),
              );
            },
          ),
        ),
      ],
    );
  }
}
