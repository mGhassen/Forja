part of 'iptv_controller.dart';

mixin _IptvControllerNav on ChangeNotifier {
  IptvController get _c => this as IptvController;

  void back() {
    switch (_c.view) {
      case IptvView.portalList:
      case IptvView.sectionPick:
      case IptvView.browser:
        if (_c.portalPanelOpen) {
          _c.closePortalPanel();
        }
        break;
      case IptvView.episodeList:
        _c.view = IptvView.browser;
        _c.activeSeries = null;
        _c.episodes = const [];
        break;
      case IptvView.channelsHub:
        _c.view = IptvView.browser;
        _c.activeHardcoded = null;
        break;
      case IptvView.channelResults:
        _c.stopChannelSearch();
        _c.view = IptvView.browser;
        _c.activeHardcoded = null;
        _c.channelResults = const [];
        _c.channelStatus = '';
        break;
    }
    notifyListeners();
  }
}
