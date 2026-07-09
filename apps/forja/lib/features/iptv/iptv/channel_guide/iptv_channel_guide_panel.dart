import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:forja/features/iptv/iptv/channel_guide/iptv_channel_guide.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';

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
  static const double panelWidthWide = 480;
  static const double panelWidthNarrow = 300;

  @override
  State<IptvChannelGuidePanel> createState() => _IptvChannelGuidePanelState();
}

class _IptvChannelGuidePanelState extends State<IptvChannelGuidePanel> {
  _GuideStep _step = _GuideStep.groups;
  final ScrollController _groupScroll = ScrollController();
  final ScrollController _channelScroll = ScrollController();

  static const Color _groupsBg = Color(0xFF0C0C12);
  static const Color _channelsBg = Color(0xFF16161F);
  static const Color _accent = Color(0xFF00E5FF);

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

  IptvGuideChannel? get _currentChannel {
    for (final c in widget.guide.channels) {
      if (c.id == widget.currentChannelId) return c;
    }
    return null;
  }

  void _scrollToCurrent() {
    final gIdx =
        widget.guide.groups.indexWhere((g) => g.id == widget.selectedGroupId);
    if (gIdx >= 0 && _groupScroll.hasClients) {
      _groupScroll.animateTo(
        (gIdx * 48.0).clamp(0.0, _groupScroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }

    final wide = MediaQuery.sizeOf(context).width >=
        IptvChannelGuidePanel.wideBreakpoint;
    if (!wide && _step == _GuideStep.groups) return;

    final channels = widget.guide.channelsForGroup(widget.selectedGroupId);
    final idx = channels.indexWhere((c) => c.id == widget.currentChannelId);
    if (idx >= 0 && _channelScroll.hasClients) {
      _channelScroll.animateTo(
        (idx * 68.0).clamp(0.0, _channelScroll.position.maxScrollExtent),
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
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onClose,
              behavior: HitTestBehavior.opaque,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.42),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: _buildPanelShell(wide: wide),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelShell({required bool wide}) {
    final panelWidth = wide
        ? IptvChannelGuidePanel.panelWidthWide
        : IptvChannelGuidePanel.panelWidthNarrow;

    return Material(
      elevation: 16,
      shadowColor: Colors.black.withValues(alpha: 0.6),
      color: _channelsBg,
      child: SizedBox(
        width: panelWidth,
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
    final playing = _currentChannel;

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
      decoration: BoxDecoration(
        color: _channelsBg,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (showBack)
                IconButton(
                  onPressed: () => setState(() => _step = _GuideStep.groups),
                  icon:
                      const Icon(Icons.arrow_back_rounded, color: Colors.white),
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
          if (playing != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Row(
                children: [
                  _ChannelLogo(url: playing.logoUrl ?? '', size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Now playing',
                          style: GoogleFonts.poppins(
                            color: _accent.withValues(alpha: 0.85),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                        Text(
                          playing.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWideBody() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: _groupsBg,
              border: Border(
                right: BorderSide(color: Color(0x1AFFFFFF)),
              ),
            ),
            child: _buildGroupList(),
          ),
        ),
        Expanded(
          flex: 7,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _channelsBg,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(6, 0),
                ),
              ],
            ),
            child: _buildChannelList(widget.selectedGroupId),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowBody() {
    if (_step == _GuideStep.groups) {
      return DecoratedBox(
        decoration: const BoxDecoration(color: _groupsBg),
        child: _buildGroupList(onPick: (id) {
          widget.onGroupSelected(id);
          setState(() => _step = _GuideStep.channels);
        }),
      );
    }
    return DecoratedBox(
      decoration: const BoxDecoration(color: _channelsBg),
      child: _buildChannelList(widget.selectedGroupId),
    );
  }

  bool _groupHasPlayingChannel(String groupId) {
    return widget.guide
        .channelsForGroup(groupId)
        .any((c) => c.id == widget.currentChannelId);
  }

  Widget _buildGroupList({ValueChanged<String>? onPick}) {
    return ListView.builder(
      controller: _groupScroll,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: widget.guide.groups.length,
      itemBuilder: (_, i) {
        final g = widget.guide.groups[i];
        final selected = g.id == widget.selectedGroupId;
        final hasPlaying = _groupHasPlayingChannel(g.id);
        return InkWell(
          onTap: () {
            widget.onGroupSelected(g.id);
            onPick?.call(g.id);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: selected
                  ? _accent.withValues(alpha: 0.18)
                  : Colors.transparent,
              border: Border(
                left: BorderSide(
                  color: selected ? _accent : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    g.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: selected ? Colors.white : Colors.white60,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
                if (hasPlaying && !selected)
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(left: 6),
                    decoration: const BoxDecoration(
                      color: _accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                if (selected)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.chevron_right_rounded,
                        color: _accent, size: 18),
                  ),
              ],
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

  static const Color _accent = Color(0xFF00E5FF);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Material(
        elevation: active ? 2 : 0,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        color: active
            ? _accent.withValues(alpha: 0.2)
            : ForjaShellColors.cinematic.menuSurface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            decoration: active
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _accent.withValues(alpha: 0.55),
                      width: 1,
                    ),
                  )
                : null,
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
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (active)
                  const Icon(Icons.play_arrow_rounded,
                      color: _accent, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelLogo extends StatelessWidget {
  const _ChannelLogo({required this.url, this.size = 40});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _placeholder();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: size,
        height: size,
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
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.live_tv_rounded,
          color: Colors.white38, size: size * 0.5),
    );
  }
}
