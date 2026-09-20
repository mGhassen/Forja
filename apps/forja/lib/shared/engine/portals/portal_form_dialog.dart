import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja/shared/engine/portals/portals_host.dart';
import 'package:forja/shared/engine/portals/share/portal_share.dart';
import 'package:forja/shared/player/live/tv_focus.dart';
import 'package:forja/shared/sync/models/account_features.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/tv/shell_tv_focus.dart';
import 'package:forja/shell/tv/tv_focus_graph.dart';
import 'package:forja_foundation/components/button.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/guide/guide_chrome_style.dart';
import 'package:forja_foundation/widgets/guide/guide_focus_paint.dart';

/// Combined Add / Import / Edit portal dialog (classic IPTV UX).
///
/// Collapsed: share-code paste. Expand: platform tabs + credentials.
/// After a resolved share code: name-portal phase with dice.
Future<bool?> showPortalFormDialog(
  BuildContext context, {
  VerifiedPortal? existing,
  required String pluginId,
  /// Isolated overlay graph — never the live hub ladder (`iptv` cats/items).
  String tabId = PortalFormDialog.tvTabId,
  int currentPortalCount = 0,
  VoidCallback? onSuccess,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PortalFormDialog(
      existing: existing,
      pluginId: pluginId,
      tabId: tabId,
      currentPortalCount: currentPortalCount,
      onSuccess: onSuccess,
    ),
  );
}

enum _PortalImportPhase { shareCode, namePortal }

class PortalFormDialog extends StatefulWidget {
  /// Dedicated TV focus tab so the dialog never joins hub cats@1 / items@2.
  static const tvTabId = 'portal-form';

  const PortalFormDialog({
    super.key,
    this.existing,
    required this.pluginId,
    this.tabId = tvTabId,
    this.currentPortalCount = 0,
    this.onSuccess,
  });

  final VerifiedPortal? existing;
  final String pluginId;
  final String tabId;
  final int currentPortalCount;
  final VoidCallback? onSuccess;

  @override
  State<PortalFormDialog> createState() => _PortalFormDialogState();
}

class _PortalFormDialogState extends State<PortalFormDialog> {
  static const _portalDialogRowId = 'portal-dialog';

  bool get _tv => liveUseTvFocus(context);

  bool get _compact => !_tv;

  bool get _dense => _tv || _compact;

  static const _codeLen = PortalShare.shareCodeLength;

  double get _codeBoxWidth => _tv ? 28.0 : (_compact ? 30.0 : 38.0);

  double get _codeBoxHeight => _tv ? 42.0 : (_compact ? 52.0 : 76.0);

  double get _codeFontSize => _tv ? 17.0 : (_compact ? 20.0 : 26.0);

  late final TextEditingController _labelCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _userCtrl;
  late final TextEditingController _passCtrl;
  late final TextEditingController _uaCtrl;
  late final TextEditingController _pasteCtrl;
  late final FocusNode _pasteFocus;
  late final FocusNode _labelFocus;
  late final FocusNode _urlFocus;
  late final FocusNode _userFocus;
  late final FocusNode _passFocus;
  late final FocusNode _uaFocus;
  late final FocusNode _expandFocus;
  late final FocusNode _submitFocus;
  late final FocusNode _cancelFocus;
  late final FocusNode _labelSuffixFocus;
  late final FocusNode _passSuffixFocus;
  late final List<FocusNode> _platformTabFocus;
  FocusOnKeyEventCallback? _pasteKeyHandler;
  bool _obscurePassword = true;
  bool _importingShareCode = false;
  bool _showManualForm = false;
  bool _addSucceeded = false;
  bool _submitInFlight = false;
  String? _successName;
  _PortalImportPhase _importPhase = _PortalImportPhase.shareCode;
  String? _shareCodeError;
  String? _lastImportedCode;
  bool _expandFocused = false;
  bool _expandHovered = false;
  bool _pasteEditing = false;
  int? _tabHoverIndex;
  String? _formError;
  PortalPlatform _platform = PortalPlatform.xtream;

  bool get _editing => widget.existing != null;

  bool get _namingImported =>
      !_editing && _importPhase == _PortalImportPhase.namePortal;

  ShellTvFocusMeta get _pasteTvMeta => ShellTvFocusMeta(
        tabId: widget.tabId,
        zone: ShellTvZone.row,
        rowId: _portalDialogRowId,
        itemIndex: 0,
      );

  void _registerPasteTvNode() {
    if (!liveUseTvFocus(context)) return;
    ShellTvFocusCoordinator.registerItemNode(
      tabId: widget.tabId,
      rowId: _portalDialogRowId,
      index: 0,
      node: _pasteFocus,
    );
  }

  void _unregisterPasteTvNode() {
    ShellTvFocusCoordinator.unregisterItemNode(
      tabId: widget.tabId,
      rowId: _portalDialogRowId,
      index: 0,
      node: _pasteFocus,
    );
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _platform = e?.portal.platform ?? PortalPlatform.xtream;
    // Optional portal name only — panel falls back to username when empty.
    _labelCtrl = TextEditingController(text: e?.label.trim() ?? '');
    _urlCtrl = TextEditingController(text: e?.portal.url ?? '');
    final initialUser = e?.portal.username ?? '';
    _userCtrl = TextEditingController(
      text: initialUser == PortalPlatform.m3uUsernameSentinel
          ? ''
          : initialUser,
    );
    _passCtrl = TextEditingController(text: e?.portal.password ?? '');
    _uaCtrl = TextEditingController(text: e?.portal.userAgent ?? '');
    _pasteCtrl = TextEditingController();
    _pasteFocus = FocusNode(debugLabel: 'iptv-share-paste');
    _labelFocus = FocusNode(debugLabel: 'iptv-portal-label');
    _urlFocus = FocusNode(debugLabel: 'iptv-portal-url');
    _userFocus = FocusNode(debugLabel: 'iptv-portal-user');
    _passFocus = FocusNode(debugLabel: 'iptv-portal-pass');
    _uaFocus = FocusNode(debugLabel: 'iptv-portal-ua');
    _expandFocus = FocusNode(debugLabel: 'iptv-portal-expand');
    _submitFocus = FocusNode(debugLabel: 'iptv-portal-submit');
    _cancelFocus = FocusNode(debugLabel: 'iptv-portal-cancel');
    _labelSuffixFocus = FocusNode(debugLabel: 'iptv-portal-label-random');
    _passSuffixFocus = FocusNode(debugLabel: 'iptv-portal-pass-eye');
    _platformTabFocus = [
      FocusNode(debugLabel: 'iptv-portal-tab-xtream'),
      FocusNode(debugLabel: 'iptv-portal-tab-m3u'),
      FocusNode(debugLabel: 'iptv-portal-tab-stalker'),
    ];
    if (_editing) _showManualForm = true;
    _pasteKeyHandler = _pasteFocus.onKeyEvent;
    _pasteFocus.onKeyEvent = _handlePasteKey;
    _pasteFocus.addListener(() {
      if (!_pasteFocus.hasFocus && _pasteEditing && mounted) {
        setState(() => _pasteEditing = false);
      }
      if (mounted) setState(() {});
    });
    _pasteCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _registerPasteTvNode();
      if (liveUseTvFocus(context)) {
        if (_editing) {
          _focusSelectedPlatformTab();
        } else {
          _focusDialogItem(1);
        }
      } else if (_editing) {
        _labelFocus.requestFocus();
      } else {
        _pasteFocus.requestFocus();
      }
    });
  }

  /// Leave share-code edit / IME; keep browse highlight on the paste field.
  void _endPasteEditing({bool keepFocus = true}) {
    if (!mounted) return;
    if (_pasteEditing) setState(() => _pasteEditing = false);
    if (!keepFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_pasteFocus.hasFocus) _pasteFocus.requestFocus();
    });
  }

  KeyEventResult _handlePasteKey(FocusNode node, KeyEvent event) {
    if (mounted &&
        liveUseTvFocus(context) &&
        !_editing &&
        !_namingImported) {
      if (!_pasteEditing) {
        final arrow = shellTvHandleRowArrows(
          event: event,
          tvMeta: _pasteTvMeta,
          onUpEdge: () {}, // top of dialog - keep focus off header close
          onDownEdge: () => _focusDialogItem(1),
        );
        if (arrow == KeyEventResult.handled) return arrow;

        if (shellTvIsActivateKey(event)) {
          setState(() => _pasteEditing = true);
          return KeyEventResult.handled;
        }
      } else {
        if (shellTvIsActivateKey(event)) {
          _endPasteEditing(keepFocus: true);
          return KeyEventResult.handled;
        }
        if (shellTvIsNavigationKey(event) &&
            event.logicalKey == LogicalKeyboardKey.arrowUp) {
          return KeyEventResult.handled;
        }
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.escape ||
                event.logicalKey == LogicalKeyboardKey.goBack)) {
          _endPasteEditing(keepFocus: true);
          return KeyEventResult.handled;
        }
      }
    }
    return _pasteKeyHandler?.call(node, event) ?? KeyEventResult.ignored;
  }

  static const _kPlatformTabs = <(PortalPlatform, String)>[
    (PortalPlatform.xtream, 'Xtream'),
    (PortalPlatform.m3u, 'M3U'),
    (PortalPlatform.stalker, 'Stalker'),
  ];

  int get _platformTabIndex => switch (_platform) {
        PortalPlatform.xtream => 0,
        PortalPlatform.m3u => 1,
        PortalPlatform.stalker => 2,
      };

  List<FocusNode> get _credentialFocusNodes =>
      _platform == PortalPlatform.m3u
          ? [_uaFocus]
          : [_userFocus, _passFocus];

  List<FocusNode> get _dialogFocusChain {
    if (_namingImported) {
      return [_labelFocus, _submitFocus, _cancelFocus];
    }
    if (_editing) {
      return [
        ..._platformTabFocus,
        _labelFocus,
        _urlFocus,
        ..._credentialFocusNodes,
        _submitFocus,
        _cancelFocus,
      ];
    }
    if (_showManualForm) {
      return [
        _pasteFocus,
        _expandFocus,
        ..._platformTabFocus,
        _labelFocus,
        _urlFocus,
        ..._credentialFocusNodes,
        _submitFocus,
        _cancelFocus,
      ];
    }
    return [_pasteFocus, _expandFocus];
  }

  int get _dialogTvItemCount => _dialogFocusChain.length;

  int _indexOfNode(FocusNode node) => _dialogFocusChain.indexOf(node);

  int get _dialogOkIndex => _indexOfNode(_submitFocus);

  int get _dialogCancelIndex => _indexOfNode(_cancelFocus);

  int get _lastFieldIndex {
    final submit = _dialogOkIndex;
    return submit > 0 ? submit - 1 : 0;
  }

  void _focusDialogItem(int index) {
    if (!mounted || !liveUseTvFocus(context)) return;
    final nodes = _dialogFocusChain;
    if (nodes.isEmpty) return;
    nodes[index.clamp(0, nodes.length - 1)].requestFocus();
  }

  void _focusSelectedPlatformTab() {
    _platformTabFocus[_platformTabIndex].requestFocus();
  }

  void _selectPlatform(PortalPlatform platform) {
    if (_platform == platform) return;
    setState(() => _platform = platform);
  }

  @override
  void dispose() {
    _unregisterPasteTvNode();
    _pasteFocus.onKeyEvent = _pasteKeyHandler;
    _labelCtrl.dispose();
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _uaCtrl.dispose();
    _pasteCtrl.dispose();
    _pasteFocus.dispose();
    _labelFocus.dispose();
    _urlFocus.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    _uaFocus.dispose();
    _expandFocus.dispose();
    _submitFocus.dispose();
    _cancelFocus.dispose();
    _labelSuffixFocus.dispose();
    _passSuffixFocus.dispose();
    for (final node in _platformTabFocus) {
      node.dispose();
    }
    super.dispose();
  }

  String _joinedShareCode() {
    final raw = _pasteCtrl.text.trim();
    if (PortalShare.isEmbeddedToken(raw)) return raw;
    return PortalShare.normalizeCode(raw);
  }

  bool get _pasteIsEmbedded =>
      PortalShare.isEmbeddedToken(_pasteCtrl.text.trim());

  int get _activeCodeIndex {
    final sel = _pasteCtrl.selection.baseOffset;
    if (sel >= 0 && sel < _codeLen) return sel;
    return _pasteCtrl.text.length.clamp(0, _codeLen - 1);
  }

  void _onSharePasteChanged(String value) {
    if (_shareCodeError != null) {
      setState(() => _shareCodeError = null);
    }
    _lastImportedCode = null;

    final trimmed = value.replaceAll(RegExp(r'\s+'), '');
    if (trimmed.startsWith(PortalShare.embeddedPrefix) ||
        trimmed.toUpperCase().startsWith('F1.')) {
      final token = trimmed.startsWith(PortalShare.embeddedPrefix)
          ? trimmed
          : 'F1.${trimmed.substring(3)}';
      if (token != value) {
        _pasteCtrl.value = TextEditingValue(
          text: token,
          selection: TextSelection.collapsed(offset: token.length),
        );
      }
      setState(() {});
      _tryAutoImportShareCode();
      return;
    }

    final cleaned = trimmed.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final clipped =
        cleaned.length > _codeLen ? cleaned.substring(0, _codeLen) : cleaned;
    if (clipped != value) {
      _pasteCtrl.value = TextEditingValue(
        text: clipped,
        selection: TextSelection.collapsed(offset: clipped.length),
      );
      setState(() {});
      _tryAutoImportShareCode();
      return;
    }
    setState(() {});
    _tryAutoImportShareCode();
  }

  void _toggleManualForm() {
    if (_importingShareCode || _namingImported) return;
    final opening = !_showManualForm;
    setState(() => _showManualForm = !_showManualForm);
    if (opening) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && liveUseTvFocus(context)) {
          _focusSelectedPlatformTab();
        } else if (mounted) {
          _labelFocus.requestFocus();
        }
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && liveUseTvFocus(context)) {
          _focusDialogItem(0);
        } else if (mounted) {
          _pasteFocus.requestFocus();
        }
      });
    }
  }

  void _focusShareCodeCell(int index) {
    _pasteFocus.requestFocus();
    final offset = index.clamp(0, _pasteCtrl.text.length);
    _pasteCtrl.selection = TextSelection.collapsed(offset: offset);
    setState(() {});
  }

  Future<void> _tryAutoImportShareCode() async {
    final code = _joinedShareCode();
    if (_importingShareCode) return;
    if (PortalShare.isEmbeddedToken(code)) {
      if (code.length < PortalShare.embeddedPrefix.length + 16) return;
    } else if (code.length != _codeLen) {
      return;
    }
    if (code == _lastImportedCode) return;
    await _importShareCode(code);
  }

  Future<void> _importShareCode(String code) async {
    if (!PortalShare.isValidCode(code)) return;

    setState(() {
      _importingShareCode = true;
      _shareCodeError = null;
    });

    try {
      final portal = await PortalShare.resolveShare(code);
      if (!mounted) return;
      if (portal == null) {
        setState(() {
          _importingShareCode = false;
          _shareCodeError = PortalShare.isEmbeddedToken(code)
              ? 'Share code invalid'
              : 'Share code not found or invalid';
        });
        return;
      }
      _urlCtrl.text = portal.url;
      _userCtrl.text =
          portal.username == PortalPlatform.m3uUsernameSentinel
              ? ''
              : portal.username;
      _passCtrl.text = portal.password;
      _uaCtrl.text = portal.userAgent;
      _labelCtrl.clear();
      _lastImportedCode = code;
      setState(() {
        _platform = portal.platform;
        _importingShareCode = false;
        _importPhase = _PortalImportPhase.namePortal;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _labelFocus.requestFocus();
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      setState(() {
        _importingShareCode = false;
        _shareCodeError = msg.contains('unavailable')
            ? 'Share service temporarily unavailable. Try again later.'
            : 'Could not load share code';
      });
    }
  }

  void _cancelNamePortal() {
    setState(() {
      _importPhase = _PortalImportPhase.shareCode;
      _platform = PortalPlatform.xtream;
      _labelCtrl.clear();
      _urlCtrl.clear();
      _userCtrl.clear();
      _passCtrl.clear();
      _uaCtrl.clear();
      _lastImportedCode = null;
      _shareCodeError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (liveUseTvFocus(context)) {
        _focusDialogItem(0);
      } else {
        _pasteFocus.requestFocus();
      }
    });
  }

  void _trySubmitFromEnter() {
    if (_addSucceeded || _submitInFlight) return;
    if (!_editing && !_showManualForm && !_namingImported) return;
    _submit();
  }

  Future<void> _submit() async {
    if (_addSucceeded || _submitInFlight) return;
    final label = _labelCtrl.text.trim();
    final url = _urlCtrl.text.trim();
    final username = _platform == PortalPlatform.m3u
        ? PortalPlatform.m3uUsernameSentinel
        : _userCtrl.text.trim();
    final password = _passCtrl.text;
    final userAgent = _uaCtrl.text.trim();

    if (_platform == PortalPlatform.m3u && label.isEmpty) {
      setState(() => _formError = 'Portal name required for M3U playlists');
      return;
    }
    if (url.isEmpty) {
      setState(() => _formError = 'URL required');
      return;
    }
    if (_platform == PortalPlatform.xtream &&
        (username.isEmpty || password.trim().isEmpty) &&
        !_editing) {
      setState(() => _formError = 'URL, username, and password required');
      return;
    }
    if (_platform == PortalPlatform.stalker && username.isEmpty) {
      setState(() => _formError = 'MAC (username) required');
      return;
    }

    if (!_editing &&
        !AccountFeatures.instance.canAddPortal(widget.currentPortalCount)) {
      final msg = AccountFeatures.instance.iptvPortalLimitReachedMessage();
      setState(() => _formError = msg);
      ForjaToast.warning(msg);
      return;
    }

    setState(() {
      _submitInFlight = true;
      _formError = null;
    });

    try {
      final params = <String, dynamic>{
        'url': url,
        'username': username,
        'password': password,
        'label': label,
        'platform': _platform.wire,
        if (userAgent.isNotEmpty) 'userAgent': userAgent,
      };
      if (_editing) {
        final key = PortalsHost.packPortalKey(widget.existing!.portal);
        params['key'] = key;
        if (password.trim().isEmpty) params.remove('password');
      }
      final env = await PortalsHost.run(
        pluginId: widget.pluginId,
        action: _editing ? 'editPortal' : 'addPortal',
        params: params,
      );
      if (!mounted) return;
      if (!env.ok) {
        setState(() {
          _submitInFlight = false;
          _formError = env.error?.message ?? 'Action failed';
        });
        return;
      }
      widget.onSuccess?.call();
      if (_editing) {
        if (!mounted) return;
        setState(() => _submitInFlight = false);
        Navigator.of(context).pop(true);
        return;
      }
      final name = label.isNotEmpty
          ? label
          : (username.isEmpty || username == PortalPlatform.m3uUsernameSentinel
              ? 'Portal'
              : username);
      setState(() {
        _submitInFlight = false;
        _addSucceeded = true;
        _successName = name;
      });
      Future<void>.delayed(const Duration(milliseconds: 1600), () {
        if (!mounted) return;
        Navigator.of(context).pop(true);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitInFlight = false;
        _formError = e.toString();
      });
    }
  }

  Future<void> _pickPlaylistFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['m3u', 'm3u8'],
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) return;
    setState(() => _urlCtrl.text = Uri.file(path).toString());
  }

  void _cancel() {
    if (_addSucceeded) {
      Navigator.of(context).pop();
      return;
    }
    if (_namingImported) {
      _cancelNamePortal();
      return;
    }
    Navigator.of(context).pop();
  }

  Widget _successBody() {
    final name = _successName ?? 'Portal';
    return Column(
      key: const ValueKey<String>('success'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Portal added',
                style: GuideChromeStyle.overlayTitle.copyWith(
                  fontSize: _tv ? 17 : 19,
                ),
              ),
            ),
            _portalDialogCloseButton(onTap: _cancel),
          ],
        ),
        SizedBox(height: _tv ? 18 : 22),
        Center(
          child: Icon(
            Icons.check_circle_rounded,
            color: ForjaShellColors.brandGreen,
            size: _tv ? 42 : 48,
          ),
        ),
        SizedBox(height: _tv ? 10 : 12),
        Text(
          name,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color: GuideChromeStyle.textSecondary,
            fontSize: 13,
          ),
        ),
        SizedBox(height: _tv ? 8 : 10),
      ],
    );
  }

  Widget _loadingBody() {
    final label = _editing ? 'Saving…' : 'Adding portal…';
    return Column(
      key: const ValueKey<String>('loading'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _editing ? 'Edit Portal' : 'Add Portal',
          style: GuideChromeStyle.overlayTitle.copyWith(
            fontSize: _tv ? 17 : 19,
          ),
        ),
        SizedBox(height: _tv ? 28 : 36),
        Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: GuideChromeStyle.textPrimary,
            ),
          ),
        ),
        SizedBox(height: _tv ? 12 : 14),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color: GuideChromeStyle.textSecondary,
            fontSize: 13,
          ),
        ),
        SizedBox(height: _tv ? 16 : 20),
      ],
    );
  }

  Widget _portalDialogCloseButton({required VoidCallback? onTap}) {
    final icon = Button(
      variant: ButtonVariant.plainIcon,
      size: ButtonSize.icon,
      icon: Icons.close_rounded,
      tooltip: 'Close',
      color: GuideChromeStyle.iconMuted,
      iconSize: 22,
      onPressed: onTap,
    );
    if (liveUseTvFocus(context)) {
      return ExcludeFocus(child: icon);
    }
    return icon;
  }

  Widget _portalDialogActionIcon({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
    required FocusNode focusNode,
    required int tvItemIndex,
  }) {
    final tv = liveUseTvFocus(context);
    final focused = tv && focusNode.hasFocus;
    final child = Tooltip(
      message: tooltip,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(6),
        decoration: guideFocusButtonDecoration(
          active: false,
          tvFocused: focused,
          borderRadius: 8,
          idleBg: Colors.transparent,
          idleBorder: Colors.transparent,
          subtle: true,
        ),
        child: Icon(icon, color: color, size: _tv ? 22 : 24),
      ),
    );
    return liveTap(
      context: context,
      onTap: onTap,
      borderRadius: 8,
      scaleOnFocus: 1,
      focusNode: focusNode,
      tvTabId: widget.tabId,
      tvRowId: _portalDialogRowId,
      tvItemIndex: tvItemIndex,
      onFocusChange: tv ? (_) => setState(() {}) : null,
      onUpEdge: () => _focusDialogItem(_lastFieldIndex),
      onDownEdge: () {},
      onLeftEdge: tv && tvItemIndex == _dialogCancelIndex
          ? () => _focusDialogItem(_dialogOkIndex)
          : () {},
      onRightEdge: tv && tvItemIndex == _dialogOkIndex
          ? () => _focusDialogItem(_dialogCancelIndex)
          : () {},
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tv = liveUseTvFocus(context);
    final labelIndex = _indexOfNode(_labelFocus);
    final urlIndex = _indexOfNode(_urlFocus);
    final userIndex = _indexOfNode(_userFocus);
    final passIndex = _indexOfNode(_passFocus);
    final uaIndex = _indexOfNode(_uaFocus);
    final shareOnlyCollapsed =
        !_editing && !_showManualForm && !_namingImported;
    final gapAfterTitle = _tv ? 8.0 : (_compact ? 14.0 : 22.0);
    final gapBetweenFields = _tv ? 10.0 : (_compact ? 18.0 : 28.0);
    final gapBeforeManual = _tv ? 12.0 : (_compact ? 18.0 : 28.0);
    final gapBeforeActions = _tv ? 10.0 : (_compact ? 12.0 : 20.0);
    // Collapsed: room to vertically center "Share code" + paste field as one block.
    final collapsedBodyHeight = _tv ? 152.0 : (_compact ? 172.0 : 196.0);
    final surfacePadding = _tv
        ? const EdgeInsets.fromLTRB(16, 14, 12, 12)
        : _compact
            ? const EdgeInsets.fromLTRB(16, 16, 12, 16)
            : EdgeInsets.fromLTRB(
                24,
                shareOnlyCollapsed ? 12 : 20,
                16,
                _editing || _showManualForm || _namingImported ? 24 : 20,
              );
    final screenH = MediaQuery.sizeOf(context).height;
    final tvInsetV = 20.0;
    final maxHeight = _tv
        ? (screenH - tvInsetV * 2).clamp(400.0, screenH)
        : screenH -
            MediaQuery.viewInsetsOf(context).bottom -
            (_compact ? 32.0 : 64.0);
    final dialogMaxWidth = _tv ? 420.0 : 440.0;
    final titleLabel = _namingImported
        ? 'Portal name'
        : (_editing ? 'Edit Portal' : 'Add Portal');
    final expandBtnSize = _tv ? 34.0 : 38.0;
    final expandOverlap = expandBtnSize / 2;
    return TvKitRow(
      tabId: widget.tabId,
      rowId: _portalDialogRowId,
      sortOrder: 0,
      itemCount: tv ? _dialogTvItemCount : 0,
      orientation: ShellTvRowOrientation.vertical,
      registerWhen: liveUseTvFocus,
      child: Builder(
        builder: (_) {
          final adding = _submitInFlight;
          final showExpandToggle =
              !_editing && !_namingImported && !_addSucceeded && !adding;
          return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.enter):
                _trySubmitFromEnter,
            const SingleActivator(LogicalKeyboardKey.numpadEnter):
                _trySubmitFromEnter,
          },
          child: Focus(
            autofocus: false,
            child: ShellTvContainDpad(
              child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: _tv ? 24 : (_compact ? 20 : 24),
          vertical: _tv ? tvInsetV : (_compact ? 16 : 32),
        ),
        child: SizedBox(
          width: dialogMaxWidth,
          child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: dialogMaxWidth,
            maxHeight: maxHeight,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Padding(
                padding: EdgeInsets.only(
                  bottom: showExpandToggle ? expandOverlap : 0,
                ),
                child: DecoratedBox(
                  decoration: GuideChromeStyle.dialogSurface(),
                  child: Padding(
                    padding: surfacePadding,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: _addSucceeded
                          ? _successBody()
                          : adding
                          ? _loadingBody()
                          : Column(
                        key: ValueKey<String>(
                          _namingImported
                              ? 'name'
                              : (shareOnlyCollapsed ? 'share' : 'manual'),
                        ),
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_namingImported) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    titleLabel,
                                    style: GuideChromeStyle.overlayTitle.copyWith(
                                      fontSize: _tv ? 17 : 19,
                                    ),
                                  ),
                                ),
                                _portalDialogCloseButton(
                                  onTap: _cancel,
                                ),
                              ],
                            ),
                            SizedBox(height: gapAfterTitle),
                            _portalField(
                              _labelCtrl,
                              'Portal name',
                              hint: 'My provider',
                              focusNode: _labelFocus,
                              dialogIndex: labelIndex,
                              suffixFocus: _labelSuffixFocus,
                              suffix: _portalFieldSuffix(
                                icon: Icons.casino_outlined,
                                tooltip: 'Random name',
                                fieldFocus: _labelFocus,
                                suffixFocus: _labelSuffixFocus,
                                dialogIndex: labelIndex,
                                onTap: () => setState(
                                  () => _labelCtrl.text =
                                      PortalName.generate(),
                                ),
                              ),
                            ),
                            if (_formError != null) ...[
                              SizedBox(
                                height: _tv ? 6 : (_compact ? 8 : 12),
                              ),
                              Text(
                                _formError!,
                                style: GoogleFonts.plusJakartaSans(
                                  color: GuideChromeStyle.liveBadge,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            SizedBox(height: gapBeforeActions),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _portalDialogActionIcon(
                                  icon: Icons.check_rounded,
                                  color: ForjaShellColors.brandGreen,
                                  tooltip: 'Add',
                                  focusNode: _submitFocus,
                                  tvItemIndex: _dialogOkIndex,
                                  onTap: _submit,
                                ),
                                const SizedBox(width: 4),
                                _portalDialogActionIcon(
                                  icon: Icons.close_rounded,
                                  color: GuideChromeStyle.textSecondary,
                                  tooltip: 'Cancel',
                                  focusNode: _cancelFocus,
                                  tvItemIndex: _dialogCancelIndex,
                                  onTap: _cancel,
                                ),
                              ],
                            ),
                          ] else if (shareOnlyCollapsed) ...[
                            SizedBox(
                              height: collapsedBodyHeight,
                              child: Stack(
                                children: [
                                  Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Share code',
                                          style: GuideChromeStyle.overlayTitle
                                              .copyWith(
                                            fontSize: _tv ? 17 : 19,
                                          ),
                                        ),
                                        SizedBox(
                                          height: _tv
                                              ? 12
                                              : (_compact ? 14 : 18),
                                        ),
                                        _shareCodeSection(),
                                      ],
                                    ),
                                  ),
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: _portalDialogCloseButton(
                                      onTap: _cancel,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            if (_editing)
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      titleLabel,
                                      style: GuideChromeStyle.overlayTitle
                                          .copyWith(
                                        fontSize: _tv ? 17 : 19,
                                      ),
                                    ),
                                  ),
                                  _portalDialogCloseButton(
                                    onTap: _cancel,
                                  ),
                                ],
                              )
                            else
                              Align(
                                alignment: Alignment.centerRight,
                                child: _portalDialogCloseButton(
                                  onTap: _cancel,
                                ),
                              ),
                            if (!_editing) ...[
                              SizedBox(height: gapAfterTitle),
                              _shareCodeSection(),
                            ],
                            SizedBox(height: gapBetweenFields),
                            _platformTabs(),
                            SizedBox(height: gapBeforeManual),
                            Flexible(
                              fit: FlexFit.loose,
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                          _portalField(
                                            _labelCtrl,
                                            _platform == PortalPlatform.m3u
                                                ? 'Portal name (required)'
                                                : 'Portal name',
                                            hint: _platform ==
                                                    PortalPlatform.m3u
                                                ? 'France IPTV'
                                                : 'My provider',
                                            focusNode: _labelFocus,
                                            dialogIndex: labelIndex,
                                            suffixFocus: _labelSuffixFocus,
                                            suffix: _portalFieldSuffix(
                                              icon: Icons.casino_outlined,
                                              tooltip: 'Random name',
                                              fieldFocus: _labelFocus,
                                              suffixFocus: _labelSuffixFocus,
                                              dialogIndex: labelIndex,
                                              onTap: () => setState(
                                                () => _labelCtrl.text =
                                                    PortalName.generate(),
                                              ),
                                            ),
                                          ),
                                          SizedBox(height: gapBetweenFields),
                                          _portalField(
                                            _urlCtrl,
                                            _platform == PortalPlatform.m3u
                                                ? 'Playlist URL'
                                                : 'URL',
                                            hint: _platform ==
                                                    PortalPlatform.m3u
                                                ? 'https://example.com/playlist.m3u'
                                                : _platform ==
                                                        PortalPlatform
                                                            .stalker
                                                    ? 'http://portal.example.com/c/'
                                                    : 'http://portal.example.com:8080',
                                            focusNode: _urlFocus,
                                            dialogIndex: urlIndex,
                                            suffix: _platform ==
                                                    PortalPlatform.m3u
                                                ? Button(
                                                    variant:
                                                        ButtonVariant.plainIcon,
                                                    size: ButtonSize.icon,
                                                    icon: Icons
                                                        .folder_open_rounded,
                                                    tooltip:
                                                        'Choose local file',
                                                    color: GuideChromeStyle
                                                        .iconMuted,
                                                    iconSize: 20,
                                                    onPressed:
                                                        _pickPlaylistFile,
                                                  )
                                                : null,
                                          ),
                                          if (_platform !=
                                              PortalPlatform.m3u) ...[
                                            SizedBox(height: gapBetweenFields),
                                            _portalField(
                                              _userCtrl,
                                              _platform ==
                                                      PortalPlatform.stalker
                                                  ? 'MAC address'
                                                  : 'Username',
                                              hint: _platform ==
                                                      PortalPlatform
                                                          .stalker
                                                  ? '00:1A:79:XX:XX:XX (MAG OUI)'
                                                  : 'username',
                                              focusNode: _userFocus,
                                              dialogIndex: userIndex,
                                              suffix: _platform ==
                                                      PortalPlatform
                                                          .stalker
                                                  ? Button(
                                                      variant: ButtonVariant
                                                          .plainIcon,
                                                      size: ButtonSize.icon,
                                                      icon: Icons
                                                          .autorenew_rounded,
                                                      tooltip:
                                                          'Generate MAC',
                                                      color: GuideChromeStyle
                                                          .iconMuted,
                                                      iconSize: 20,
                                                      onPressed: () => setState(
                                                        () => _userCtrl.text =
                                                            StalkerMac
                                                                .generate(),
                                                      ),
                                                    )
                                                  : null,
                                            ),
                                            SizedBox(height: gapBetweenFields),
                                            _portalField(
                                              _passCtrl,
                                              _platform ==
                                                      PortalPlatform.stalker
                                                  ? 'Serial (optional)'
                                                  : 'Password',
                                              hint: _platform ==
                                                      PortalPlatform
                                                          .stalker
                                                  ? 'device serial'
                                                  : 'password',
                                              obscure: _platform ==
                                                      PortalPlatform
                                                          .xtream &&
                                                  _obscurePassword,
                                              focusNode: _passFocus,
                                              dialogIndex: passIndex,
                                              suffixFocus:
                                                  _platform ==
                                                          PortalPlatform
                                                              .xtream
                                                      ? _passSuffixFocus
                                                      : null,
                                              suffix: _platform ==
                                                      PortalPlatform.xtream
                                                  ? _portalFieldSuffix(
                                                      icon: _obscurePassword
                                                          ? Icons
                                                              .visibility_outlined
                                                          : Icons
                                                              .visibility_off_outlined,
                                                      tooltip: _obscurePassword
                                                          ? 'Show password'
                                                          : 'Hide password',
                                                      fieldFocus: _passFocus,
                                                      suffixFocus:
                                                          _passSuffixFocus,
                                                      dialogIndex: passIndex,
                                                      onTap: () => setState(
                                                        () =>
                                                            _obscurePassword =
                                                                !_obscurePassword,
                                                      ),
                                                    )
                                                  : null,
                                            ),
                                          ],
                                          if (_platform ==
                                              PortalPlatform.m3u) ...[
                                            SizedBox(height: gapBetweenFields),
                                            _portalField(
                                              _uaCtrl,
                                              'User-Agent (optional)',
                                              hint: 'VLC/3.0.20 LibVLC/3.0.20',
                                              focusNode: _uaFocus,
                                              dialogIndex: uaIndex,
                                            ),
                                          ],
                                    if (_formError != null) ...[
                                      SizedBox(
                                        height: _tv ? 6 : (_compact ? 8 : 12),
                                      ),
                                      Text(
                                        _formError!,
                                        style: GoogleFonts.plusJakartaSans(
                                          color: GuideChromeStyle.liveBadge,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                          if (!_namingImported &&
                              (_editing || _showManualForm)) ...[
                            SizedBox(height: gapBeforeActions),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _portalDialogActionIcon(
                                  icon: Icons.check_rounded,
                                  color: ForjaShellColors.brandGreen,
                                  tooltip: _editing ? 'Save' : 'Add',
                                  focusNode: _submitFocus,
                                  tvItemIndex: _dialogOkIndex,
                                  onTap: _submit,
                                ),
                                const SizedBox(width: 4),
                                _portalDialogActionIcon(
                                  icon: Icons.close_rounded,
                                  color: GuideChromeStyle.textSecondary,
                                  tooltip: 'Cancel',
                                  focusNode: _cancelFocus,
                                  tvItemIndex: _dialogCancelIndex,
                                  onTap: _cancel,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (showExpandToggle)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Center(
                    child: _manualFormToggle(size: expandBtnSize),
                  ),
                ),
            ],
          ),
        ),
        ),
      ),
            ),
          ),
        );
        },
      ),
    );
  }

  Widget _manualFormToggle({required double size}) {
    final tv = liveUseTvFocus(context);
    final tvFocused = tv && _expandFocused;
    final active = liveFocusActive(
      context,
      hovered: _expandHovered,
      focused: _expandFocused,
    );
    final radius = size * 0.28;
    final iconSize = size * 0.55;
    final child = Tooltip(
      message: _showManualForm ? 'Hide manual entry' : 'Enter URL manually',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: size,
        height: size,
        decoration: active || tvFocused
            ? guideFocusButtonDecoration(
                active: true,
                tvFocused: tvFocused,
                borderRadius: radius,
                idleBg: GuideChromeStyle.surface,
                idleBorder: GuideChromeStyle.border,
                subtle: true,
              )
            : BoxDecoration(
                color: GuideChromeStyle.surface,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: GuideChromeStyle.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
        child: Icon(
          _showManualForm
              ? Icons.keyboard_arrow_up_rounded
              : Icons.keyboard_arrow_down_rounded,
          color: guideFocusFg(
            GuideChromeStyle.textSecondary,
            active: active,
            tvFocused: tvFocused,
          ),
          size: iconSize,
        ),
      ),
    );
    return liveTap(
      context: context,
      onTap: _importingShareCode ? null : _toggleManualForm,
      borderRadius: radius,
      focusNode: tv ? _expandFocus : null,
      tvTabId: widget.tabId,
      tvRowId: tv ? _portalDialogRowId : null,
      tvItemIndex: tv ? 1 : null,
      onUpEdge: tv ? () => _focusDialogItem(0) : null,
      onDownEdge: tv
          ? () {
              if (_showManualForm) {
                _focusSelectedPlatformTab();
              } else {
                _focusDialogItem(1);
              }
            }
          : null,
      onFocusChange: tv
          ? (focused) => setState(() => _expandFocused = focused)
          : null,
      onHoverChange: (hovered) {
        if (_expandHovered == hovered) return;
        setState(() => _expandHovered = hovered);
      },
      child: child,
    );
  }

  Widget _shareCodeSection() {
    final embedded = _pasteIsEmbedded;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _codeBoxHeight,
          child: Stack(
            children: [
              if (embedded)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      _pasteCtrl.text.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.jetBrainsMono(
                        color: GuideChromeStyle.accent,
                        fontSize: _tv ? 11 : (_compact ? 12 : 13),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 4; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      _shareCodeCell(i),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '-',
                        style: GoogleFonts.jetBrainsMono(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: _tv ? 14 : (_compact ? 16 : 22),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    for (var i = 4; i < 8; i++) ...[
                      if (i > 4) const SizedBox(width: 6),
                      _shareCodeCell(i),
                    ],
                  ],
                ),
              Positioned.fill(
                child: TextField(
                  controller: _pasteCtrl,
                  focusNode: _pasteFocus,
                  enabled: !_importingShareCode,
                  readOnly: liveUseTvFocus(context) && !_pasteEditing,
                  enableInteractiveSelection:
                      !liveUseTvFocus(context) || _pasteEditing,
                  onTap: liveUseTvFocus(context) && !_pasteEditing
                      ? () {
                          if (!_pasteEditing) {
                            setState(() => _pasteEditing = true);
                          }
                        }
                      : null,
                  textAlign: TextAlign.center,
                  textCapitalization: embedded
                      ? TextCapitalization.none
                      : TextCapitalization.characters,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.done,
                  showCursor: false,
                  style: const TextStyle(
                    color: Colors.transparent,
                    fontSize: 1,
                    height: 1,
                  ),
                  cursorColor: Colors.transparent,
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[A-Za-z0-9._\-]'),
                    ),
                  ],
                  onChanged: _onSharePasteChanged,
                  onSubmitted: (_) => _endPasteEditing(keepFocus: true),
                ),
              ),
            ],
          ),
        ),
        if (_importingShareCode) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: GuideChromeStyle.accent,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Loading share code…',
                style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ],
        if (_shareCodeError != null) ...[
          const SizedBox(height: 10),
          Text(
            _shareCodeError!,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: GuideChromeStyle.liveBadge,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _shareCodeCell(int index) {
    final text = index < _pasteCtrl.text.length ? _pasteCtrl.text[index] : '';
    final pasteFocused = _pasteFocus.hasFocus;
    final active = pasteFocused && index == _activeCodeIndex;
    final borderColor = guideDialogFieldBorderColor(focused: pasteFocused);
    return GestureDetector(
      onTap: () => _focusShareCodeCell(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: _codeBoxWidth,
        height: _codeBoxHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: active ? 0.08 : 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
            width: pasteFocused ? 1.5 : 1,
          ),
        ),
        child: Text(
          text,
          style: GoogleFonts.jetBrainsMono(
            color: GuideChromeStyle.textPrimary,
            fontSize: _codeFontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _platformTabs() {
    final tv = liveUseTvFocus(context);
    const tabH = 42.0;
    return SizedBox(
      height: tabH,
      child: Row(
        children: [
          for (var i = 0; i < _kPlatformTabs.length; i++)
            Expanded(child: _platformTab(index: i, height: tabH, tv: tv)),
        ],
      ),
    );
  }

  Widget _platformTab({
    required int index,
    required double height,
    required bool tv,
  }) {
    final (platform, label) = _kPlatformTabs[index];
    final selected = _platform == platform;
    final mouse = ShellScope.inputPolicyOf(context).scaleOnHover;
    final focused = tv && _platformTabFocus[index].hasFocus;
    final hovered = mouse && _tabHoverIndex == index;
    final active = selected || focused || hovered;
    final tabIndex = _indexOfNode(_platformTabFocus[index]);
    final labelIndex = _indexOfNode(_labelFocus);
    final firstTabIndex = _indexOfNode(_platformTabFocus.first);
    final upTarget = firstTabIndex > 0 ? firstTabIndex - 1 : -1;
    final fg = focused || hovered
        ? ForjaShellColors.brandGreen
        : selected
            ? ForjaShellColors.textPrimary
            : GuideChromeStyle.textSecondary;

    final face = SizedBox(
      height: height,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: fg,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ),
          Container(
            height: 2,
            color: active ? ForjaShellColors.brandGreen : Colors.transparent,
          ),
        ],
      ),
    );

    Widget child = face;
    if (mouse) {
      child = MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _tabHoverIndex = index),
        onExit: (_) {
          if (_tabHoverIndex == index) setState(() => _tabHoverIndex = null);
        },
        child: child,
      );
    }

    if (!tv) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _selectPlatform(platform),
        child: child,
      );
    }

    return liveTap(
      context: context,
      onTap: () => _selectPlatform(platform),
      borderRadius: 0,
      scaleOnFocus: 1,
      suppressInkHover: true,
      focusNode: _platformTabFocus[index],
      tvTabId: widget.tabId,
      tvRowId: _portalDialogRowId,
      tvItemIndex: tabIndex,
      onFocusChange: (_) => setState(() {}),
      onLeftEdge: () {
        if (index > 0) _platformTabFocus[index - 1].requestFocus();
      },
      onRightEdge: () {
        if (index < _kPlatformTabs.length - 1) {
          _platformTabFocus[index + 1].requestFocus();
        }
      },
      onUpEdge: () {
        if (upTarget >= 0) _focusDialogItem(upTarget);
      },
      onDownEdge: () => _focusDialogItem(labelIndex),
      child: child,
    );
  }

  Widget _portalFieldSuffix({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required FocusNode fieldFocus,
    required FocusNode suffixFocus,
    required int dialogIndex,
  }) {
    final tv = liveUseTvFocus(context);
    if (!tv) {
      return Button(
        variant: ButtonVariant.plainIcon,
        size: ButtonSize.icon,
        icon: icon,
        tooltip: tooltip,
        color: GuideChromeStyle.iconMuted,
        iconSize: 20,
        onPressed: onTap,
      );
    }
    final focused = suffixFocus.hasFocus;
    return liveTap(
      context: context,
      onTap: onTap,
      borderRadius: 8,
      scaleOnFocus: 1,
      suppressInkHover: true,
      focusNode: suffixFocus,
      onFocusChange: (_) => setState(() {}),
      onLeftEdge: () => fieldFocus.requestFocus(),
      onRightEdge: () {},
      onUpEdge: () {
        if (identical(fieldFocus, _labelFocus) &&
            (_editing || _showManualForm) &&
            !_namingImported) {
          _focusSelectedPlatformTab();
          return;
        }
        _focusDialogItem(dialogIndex - 1);
      },
      onDownEdge: () => _focusDialogItem(dialogIndex + 1),
      child: Tooltip(
        message: tooltip,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(4),
          decoration: guideFocusButtonDecoration(
            active: false,
            tvFocused: focused,
            borderRadius: 8,
            idleBg: Colors.transparent,
            idleBorder: Colors.transparent,
            subtle: true,
          ),
          child: Icon(icon, color: GuideChromeStyle.iconMuted, size: 20),
        ),
      ),
    );
  }

  Widget _portalField(
    TextEditingController c,
    String label, {
    String? hint,
    bool obscure = false,
    Widget? suffix,
    FocusNode? focusNode,
    FocusNode? suffixFocus,
    int dialogIndex = -1,
  }) {
    final tv = liveUseTvFocus(context);
    final compact = _dense;
    final hintStyle = GoogleFonts.plusJakartaSans(
      color: Colors.white.withValues(alpha: 0.25),
      fontSize: _tv ? 12 : (compact ? 13 : 14),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            color: GuideChromeStyle.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        SizedBox(height: _tv ? 3 : (compact ? 4 : 6)),
        if (tv && focusNode != null && dialogIndex >= 0)
          _PortalDialogField(
            controller: c,
            focusNode: focusNode,
            obscureText: obscure,
            hintText: hint,
            hintStyle: hintStyle,
            suffixIcon: suffix == null
                ? null
                : (suffixFocus == null ? ExcludeFocus(child: suffix) : suffix),
            style: GoogleFonts.plusJakartaSans(
              color: GuideChromeStyle.textPrimary,
              fontSize: _tv ? 13 : 14,
            ),
            onArrowUp: () {
              if (identical(focusNode, _labelFocus) &&
                  (_editing || _showManualForm) &&
                  !_namingImported) {
                _focusSelectedPlatformTab();
                return;
              }
              _focusDialogItem(dialogIndex - 1);
            },
            onArrowDown: () => _focusDialogItem(dialogIndex + 1),
            onArrowRight: suffixFocus == null
                ? null
                : () => suffixFocus.requestFocus(),
            onSubmit: _trySubmitFromEnter,
          )
        else
          TextField(
            controller: c,
            focusNode: focusNode,
            obscureText: obscure,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _trySubmitFromEnter(),
            style: GoogleFonts.plusJakartaSans(
              color: GuideChromeStyle.textPrimary,
              fontSize: _tv ? 12 : (compact ? 13 : 14),
            ),
            decoration: guideDialogFieldDecoration(
              focused: focusNode?.hasFocus ?? false,
              hintText: hint,
              hintStyle: hintStyle,
              suffixIcon: suffix,
            ),
          ),
      ],
    );
  }
}

class _PortalDialogField extends StatefulWidget {
  const _PortalDialogField({
    required this.controller,
    required this.focusNode,
    required this.onArrowUp,
    required this.onArrowDown,
    this.onArrowRight,
    this.onSubmit,
    this.obscureText = false,
    this.style,
    this.hintText,
    this.hintStyle,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onArrowUp;
  final VoidCallback onArrowDown;
  final VoidCallback? onArrowRight;
  final VoidCallback? onSubmit;
  final bool obscureText;
  final TextStyle? style;
  final String? hintText;
  final TextStyle? hintStyle;
  final Widget? suffixIcon;

  @override
  State<_PortalDialogField> createState() => _PortalDialogFieldState();
}

class _PortalDialogFieldState extends State<_PortalDialogField> {
  FocusOnKeyEventCallback? _previousHandler;
  bool _editing = false;

  bool get _tvBrowse => liveUseTvFocus(context) && !_editing;

  @override
  void initState() {
    super.initState();
    _attachKeyHandler();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant _PortalDialogField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
      oldWidget.focusNode.onKeyEvent = _previousHandler;
      _attachKeyHandler();
    }
  }

  void _onFocusChange() {
    if (!widget.focusNode.hasFocus && _editing && mounted) {
      setState(() => _editing = false);
    } else if (mounted) {
      setState(() {});
    }
    if (widget.focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.focusNode.hasFocus) return;
        Scrollable.ensureVisible(
          context,
          alignment: 0.15,
          duration: Duration.zero,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      });
    }
  }

  void _attachKeyHandler() {
    _previousHandler = widget.focusNode.onKeyEvent;
    widget.focusNode.onKeyEvent = _handleKey;
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    widget.focusNode.onKeyEvent = _previousHandler;
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (_tvBrowse && shellTvIsActivateKey(event)) {
      setState(() => _editing = true);
      return KeyEventResult.handled;
    }
    if (_tvBrowse && event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        widget.onArrowDown();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        widget.onArrowUp();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
          widget.onArrowRight != null) {
        widget.onArrowRight!();
        return KeyEventResult.handled;
      }
    }
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _editing) {
      setState(() => _editing = false);
      return KeyEventResult.handled;
    }
    return _previousHandler?.call(node, event) ?? KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final browse = liveUseTvFocus(context);
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: widget.obscureText,
      readOnly: browse && !_editing,
      enableInteractiveSelection: !browse || _editing,
      onTap: browse && !_editing
          ? () {
              if (!_editing) setState(() => _editing = true);
            }
          : null,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => widget.onSubmit?.call(),
      style: widget.style,
      decoration: guideDialogFieldDecoration(
        focused: widget.focusNode.hasFocus,
        hintText: widget.hintText,
        hintStyle: widget.hintStyle,
        suffixIcon: widget.suffixIcon,
      ),
    );
  }
}
