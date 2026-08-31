import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/iptv/controller/iptv_controller.dart';

/// Session-scoped IPTV controller (wraps existing [ChangeNotifier]).
final iptvControllerProvider = ChangeNotifierProvider<IptvController>((ref) {
  final ctrl = IptvController();
  ref.onDispose(() => ctrl.dispose());
  return ctrl;
});
