/// Inline layout payloads for core shell tabs rendered by [CatalogShell.hostTab].
class HostCatalogLayouts {
  HostCatalogLayouts._();

  static const String hostPluginId = '_host_';

  static Map<String, dynamic>? forTab(String tabId) {
    switch (tabId) {
      case 'mylist':
        return myList;
      default:
        return null;
    }
  }

  static final Map<String, dynamic> myList = {
    'pages': {
      'mylist': {
        'widgets': [
          {'type': 'host.my_list', 'id': 'my_list'},
        ],
      },
    },
  };
}
