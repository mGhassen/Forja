part of 'iptv_pt_screen.dart';

class _IptvCatalogShell extends StatelessWidget {
  const _IptvCatalogShell({
    required this.ctrl,
    required this.compact,
    required this.wide,
  });

  final IptvController ctrl;
  final bool compact;
  final bool wide;

  static const double _panelWidth = 380;

  bool _useSidePanel(BuildContext context) =>
      wide || ShellTokens.isAndroidTvDevice || !compact;

  @override
  Widget build(BuildContext context) {
    // PiP shrinks the whole window; skip heavy catalog layout in a tiny
    // frame (avoids top-bar/grid asserts). Key off *size*, not sticky
    // [PipService.isDesktopActive] — that flag can lag after leave and left
    // IPTV as a permanent black screen.
    return LayoutBuilder(
      builder: (context, constraints) {
        final pipSized = (Platform.isMacOS || Platform.isWindows) &&
            (constraints.maxWidth < 520 || constraints.maxHeight < 400);
        if (pipSized) {
          return const ColoredBox(color: Colors.black);
        }

        return Column(
          children: [
            IptvCatalogTopBar(
              ctrl: ctrl,
              onTogglePanel: ctrl.togglePortalPanel,
              onSection: ctrl.requestSection,
            ),
            Expanded(
              child: Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _BrowserView(
                          ctrl: ctrl,
                          compact: compact,
                          wide: wide,
                          embedded: true,
                        ),
                      ),
                      if (ctrl.portalPanelOpen && _useSidePanel(context))
                        IptvPortalPanel(
                          ctrl: ctrl,
                          width: _panelWidth,
                          onClose: ctrl.closePortalPanel,
                        ),
                    ],
                  ),
                  if (ctrl.portalPanelOpen && !_useSidePanel(context))
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: ctrl.closePortalPanel,
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.45),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () {},
                              child: IptvPortalPanel(
                                ctrl: ctrl,
                                width: MediaQuery.sizeOf(context).width * 0.92,
                                onClose: ctrl.closePortalPanel,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
