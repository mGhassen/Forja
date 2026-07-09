import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:forja/features/iptv/iptv/channel_guide/iptv_channel_guide.dart';

enum _GuideStep { groups, channels }

class IptvChannelGuidePanel extends StatefulWidget {
  const IptvChannelGuidePanel({
    super.key,
    required this.guide,
    required this.selectedGroupId,
    required this.currentChannelId,
    required this.onGroupSelected,
    required this.onChannelSelected,
    required this.onClose,
  });

  final IptvChannelGuide guide;
  final String selectedGroupId;
  final String currentChannelId;
  final ValueChanged<String> onGroupSelected;
  final ValueChanged<IptvGuideChannel> onChannelSelected;
  final VoidCallback onClose;

  static const double wideBreakpoint = 700;
  static const double groupsWidth = 200;
  static const double channelsWidth = 280;

  @override
  State<IptvChannelGuidePanel> createState() => _IptvChannelGuidePanelState();
}

class _IptvChannelGuidePanelState extends State<IptvChannelGuidePanel> {
  _GuideStep _step = _GuideStep.groups;
  final ScrollController _groupScroll = ScrollController();
  final ScrollController _channelScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  @override
  void didUpdateWidget(covariant IptvChannelGuidePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentChannelId != widget.currentChannelId ||
        oldWidget.selectedGroupId != widget.selectedGroupId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
    }
  }

  @override
  void dispose() {
    _groupScroll.dispose();
    _channelScroll.dispose();
    super.dispose();
  }

  void _scrollToCurrent() {
    final wide = MediaQuery.sizeOf(context).width >=
        IptvChannelGuidePanel.wideBreakpoint;
    if (!wide && _step == _GuideStep.groups) return;

    final channels = widget.guide.channelsForGroup(widget.selectedGroupId);
    final idx = channels.indexWhere((c) => c.id == widget.currentChannelId);
    if (idx >= 0 && _channelScroll.hasClients) {
      _channelScroll.animateTo(
        (idx * 64.0).clamp(0.0, _channelScroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }

    final gIdx =
        widget.guide.groups.indexWhere((g) => g.id == widget.selectedGroupId);
    if (gIdx >= 0 && _groupScroll.hasClients) {
      _groupScroll.animateTo(
        (gIdx * 44.0).clamp(0.0, _groupScroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide =
        MediaQuery.sizeOf(context).width >= IptvChannelGuidePanel.wideBreakpoint;

    return Positioned.fill(
      child: Row(
        children: [
          if (wide) _buildPanelShell(wide: true) else _buildMobilePanel(),
          Expanded(
            child: GestureDetector(
              onTap: widget.onClose,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.black.withValues(alpha: 0.45)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobilePanel() {
    return _buildPanelShell(wide: false);
  }

  Widget _buildPanelShell({required bool wide}) {
    final panelWidth = wide
        ? IptvChannelGuidePanel.groupsWidth + IptvChannelGuidePanel.channelsWidth
        : 300.0;

    return SizedBox(
      width: panelWidth,
      child: Material(
        color: const Color(0xFF12121A),
        child: SafeArea(
          right: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(wide: wide),
              Expanded(
                child: wide ? _buildWideBody() : _buildNarrowBody(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({required bool wide}) {
    final showBack = !wide && _step == _GuideStep.channels;
    final groupName =
        widget.guide.groupById(widget.selectedGroupId)?.name ?? 'Channels';

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              onPressed: () => setState(() => _step = _GuideStep.groups),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            )
          else
            const SizedBox(width: 8),
          Expanded(
            child: Text(
              showBack ? groupName : 'Channels',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.bebasNeue(
                color: Colors.white,
                fontSize: 20,
                letterSpacing: 1,
              ),
            ),
          ),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildWideBody() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: IptvChannelGuidePanel.groupsWidth,
          child: _buildGroupList(),
        ),
        Container(
          width: 1,
          color: Colors.white.withValues(alpha: 0.06),
        ),
        SizedBox(
          width: IptvChannelGuidePanel.channelsWidth,
          child: _buildChannelList(widget.selectedGroupId),
        ),
      ],
    );
  }

  Widget _buildNarrowBody() {
    if (_step == _GuideStep.groups) {
      return _buildGroupList(onPick: (id) {
        widget.onGroupSelected(id);
        setState(() => _step = _GuideStep.channels);
      });
    }
    return _buildChannelList(widget.selectedGroupId);
  }

  Widget _buildGroupList({ValueChanged<String>? onPick}) {
    return ListView.builder(
      controller: _groupScroll,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: widget.guide.groups.length,
      itemBuilder: (_, i) {
        final g = widget.guide.groups[i];
        final selected = g.id == widget.selectedGroupId;
        return InkWell(
          onTap: () {
            widget.onGroupSelected(g.id);
            onPick?.call(g.id);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF00E5FF).withValues(alpha: 0.12)
                  : Colors.transparent,
              border: Border(
                left: BorderSide(
                  color: selected
                      ? const Color(0xFF00E5FF)
                      : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Text(
              g.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: selected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChannelList(String groupId) {
    final channels = widget.guide.channelsForGroup(groupId);
    if (channels.isEmpty) {
      return Center(
        child: Text(
          'No channels',
          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      controller: _channelScroll,
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: channels.length,
      itemBuilder: (_, i) {
        final ch = channels[i];
        final active = ch.id == widget.currentChannelId;
        return _GuideChannelTile(
          channel: ch,
          active: active,
          onTap: () => widget.onChannelSelected(ch),
        );
      },
    );
  }
}

class _GuideChannelTile extends StatelessWidget {
  const _GuideChannelTile({
    required this.channel,
    required this.active,
    required this.onTap,
  });

  final IptvGuideChannel channel;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Material(
        color: active
            ? const Color(0xFF00E5FF).withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                _ChannelLogo(url: channel.logoUrl ?? ''),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    channel.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: active ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (active)
                  const Icon(Icons.volume_up_rounded,
                      color: Color(0xFF00E5FF), size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelLogo extends StatelessWidget {
  const _ChannelLogo({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _placeholder();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
        loadingBuilder: (ctx, child, prog) {
          if (prog == null) return child;
          return _placeholder();
        },
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.live_tv_rounded, color: Colors.white38, size: 20),
    );
  }
}
