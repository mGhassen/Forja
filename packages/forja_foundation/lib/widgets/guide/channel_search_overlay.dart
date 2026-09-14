import 'package:flutter/material.dart';
import 'package:forja_foundation/components/network_image.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/guide/channel_guide.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paint-only channel search overlay.
///
/// Host owns TV browse/edit text fields and back-key routing — inject
/// [queryFieldBuilder] when needed.
class ChannelSearchOverlay extends StatefulWidget {
  const ChannelSearchOverlay({
    super.key,
    required this.guide,
    required this.currentChannelId,
    required this.onChannelSelected,
    required this.onClose,
    this.queryFieldBuilder,
    this.maxVisibleResults = 8,
  });

  final ChannelGuide guide;
  final String currentChannelId;
  final ValueChanged<GuideChannel> onChannelSelected;
  final VoidCallback onClose;
  final Widget Function({
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    required VoidCallback onSubmit,
  })? queryFieldBuilder;
  final int maxVisibleResults;

  static const double resultRowHeight = 58;
  static const double panelWidth = 400;

  @override
  State<ChannelSearchOverlay> createState() => _ChannelSearchOverlayState();
}

class _ChannelSearchOverlayState extends State<ChannelSearchOverlay> {
  final TextEditingController _queryCtrl = TextEditingController();

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  List<GuideChannel> get _results {
    final all = widget.guide.searchChannels(_queryCtrl.text);
    if (all.length <= widget.maxVisibleResults) return all;
    return all.take(widget.maxVisibleResults).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final accent = ForjaShellColors.brandGreen;
    final field = widget.queryFieldBuilder?.call(
          controller: _queryCtrl,
          onChanged: (_) => setState(() {}),
          onSubmit: () {
            if (results.isNotEmpty) {
              widget.onChannelSelected(results.first);
            }
          },
        ) ??
        TextField(
          controller: _queryCtrl,
          autofocus: true,
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search channels',
            hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white38),
            border: InputBorder.none,
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            if (results.isNotEmpty) widget.onChannelSelected(results.first);
          },
        );

    return Material(
      color: const Color(0xE016161F),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: ChannelSearchOverlay.panelWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.white54, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: field),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                  ),
                ],
              ),
            ),
            if (results.isEmpty && _queryCtrl.text.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'No channels',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: ChannelSearchOverlay.resultRowHeight *
                      widget.maxVisibleResults,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemExtent: ChannelSearchOverlay.resultRowHeight,
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final ch = results[i];
                    final playing = ch.id == widget.currentChannelId;
                    return InkWell(
                      onTap: () => widget.onChannelSelected(ch),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: SizedBox(
                                width: 36,
                                height: 36,
                                child: ch.logoUrl == null || ch.logoUrl!.isEmpty
                                    ? ColoredBox(
                                        color:
                                            Colors.white.withValues(alpha: 0.06),
                                        child: const Icon(
                                          Icons.tv,
                                          size: 18,
                                          color: Colors.white38,
                                        ),
                                      )
                                    : ForjaNetworkImage(
                                        url: ch.logoUrl!,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                ch.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  color: playing ? accent : Colors.white,
                                  fontSize: 13,
                                  fontWeight: playing
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
