part of 'iptv_catalog_workspace.dart';

class _PortalExpiryTone {
  const _PortalExpiryTone({required this.color, required this.label});

  final Color color;
  final String label;
}

const _expiryMonthIndex = <String, int>{
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

DateTime? _parsePortalExpiryDate(String expiry) {
  final s = expiry.trim();
  if (s.isEmpty || s.toLowerCase() == 'unknown') return null;

  final ts = int.tryParse(s);
  if (ts != null) {
    return DateTime.fromMillisecondsSinceEpoch(ts * 1000);
  }

  final parts = s.split(RegExp(r'\s+'));
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = _expiryMonthIndex[parts[1].toLowerCase()];
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}

_PortalExpiryTone _portalExpiryTone(String expiry) {
  final label = expiry.trim().isEmpty ? 'Unknown' : expiry.trim();
  final end = _parsePortalExpiryDate(label);
  if (end == null) {
    return _PortalExpiryTone(
      color: const Color(0xFF9CA3AF),
      label: label == 'Unknown' ? 'Ends: Unknown' : 'Ends: $label',
    );
  }

  final today = DateTime.now();
  final midnightToday = DateTime(today.year, today.month, today.day);
  final days = end.difference(midnightToday).inDays;

  final Color color;
  if (days < 0) {
    color = const Color(0xFFEF4444);
  } else if (days <= 7) {
    color = const Color(0xFFF59E0B);
  } else if (days <= 30) {
    color = const Color(0xFFEAB308);
  } else {
    color = const Color(0xFF22C55E);
  }

  final prefix = days < 0 ? 'Expired' : 'Ends';
  return _PortalExpiryTone(color: color, label: '$prefix $label');
}

enum _PortalImportPhase { shareCode, namePortal }

class _PortalFormDialog extends StatefulWidget {
  const _PortalFormDialog({required this.ctrl, this.existing});

  final IptvController ctrl;
  final VerifiedPortal? existing;

  @override
  State<_PortalFormDialog> createState() => _PortalFormDialogState();
}

class _PortalFormDialogState extends State<_PortalFormDialog> {
  static const _codeLen = IptvPortalShare.shareCodeLength;
  static const _portalDialogRowId = 'iptv-portal-dialog';

  bool get _tv => iptvUseTvFocus(context);

  bool get _compact => !_tv;

  bool get _dense => _tv || _compact;

  double get _codeBoxWidth => _tv ? 28.0 : (_compact ? 30.0 : 38.0);

  double get _codeBoxHeight => _tv ? 42.0 : (_compact ? 52.0 : 76.0);

  double get _codeFontSize => _tv ? 17.0 : (_compact ? 20.0 : 26.0);

  late final TextEditingController _labelCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _userCtrl;
  late final TextEditingController _passCtrl;
  late final TextEditingController _pasteCtrl;
  late final FocusNode _pasteFocus;
  late final FocusNode _labelFocus;
  late final FocusNode _urlFocus;
  late final FocusNode _userFocus;
  late final FocusNode _passFocus;
  late final FocusNode _expandFocus;
  late final FocusNode _submitFocus;
  late final FocusNode _cancelFocus;
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

  bool get _editing => widget.existing != null;

  bool get _namingImported =>
      !_editing && _importPhase == _PortalImportPhase.namePortal;

  ShellTvFocusMeta get _pasteTvMeta => const ShellTvFocusMeta(
        tabId: 'iptv',
        zone: ShellTvZone.row,
        rowId: _portalDialogRowId,
        itemIndex: 0,
      );

  void _registerPasteTvNode() {
    if (!iptvUseTvFocus(context)) return;
    ShellTvFocusCoordinator.registerItemNode(
      tabId: 'iptv',
      rowId: _portalDialogRowId,
      index: 0,
      node: _pasteFocus,
    );
  }

  void _unregisterPasteTvNode() {
    ShellTvFocusCoordinator.unregisterItemNode(
      tabId: 'iptv',
      rowId: _portalDialogRowId,
      index: 0,
      node: _pasteFocus,
    );
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _labelCtrl = TextEditingController(text: e?.label ?? '');
    _urlCtrl = TextEditingController(text: e?.portal.url ?? '');
    _userCtrl = TextEditingController(text: e?.portal.username ?? '');
    _passCtrl = TextEditingController(text: e?.portal.password ?? '');
    _pasteCtrl = TextEditingController();
    _pasteFocus = FocusNode(debugLabel: 'iptv-share-paste');
    _labelFocus = FocusNode(debugLabel: 'iptv-portal-label');
    _urlFocus = FocusNode(debugLabel: 'iptv-portal-url');
    _userFocus = FocusNode(debugLabel: 'iptv-portal-user');
    _passFocus = FocusNode(debugLabel: 'iptv-portal-pass');
    _expandFocus = FocusNode(debugLabel: 'iptv-portal-expand');
    _submitFocus = FocusNode(debugLabel: 'iptv-portal-submit');
    _cancelFocus = FocusNode(debugLabel: 'iptv-portal-cancel');
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
      if (iptvUseTvFocus(context)) {
        if (_editing) {
          _labelFocus.requestFocus();
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

  KeyEventResult _handlePasteKey(FocusNode node, KeyEvent event) {
    if (mounted &&
        iptvUseTvFocus(context) &&
        !_editing &&
        !_namingImported) {
      if (!_pasteEditing) {
        final arrow = shellTvHandleRowArrows(
          event: event,
          tvMeta: _pasteTvMeta,
          onUpEdge: () {}, // top of dialog — keep focus off header close
          onDownEdge: () => _focusDialogItem(1),
        );
        if (arrow == KeyEventResult.handled) return arrow;

        if (shellTvIsActivateKey(event)) {
          setState(() => _pasteEditing = true);
          return KeyEventResult.handled;
        }
      } else {
        if (shellTvIsNavigationKey(event) &&
            event.logicalKey == LogicalKeyboardKey.arrowUp) {
          return KeyEventResult.handled;
        }
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          setState(() => _pasteEditing = false);
          return KeyEventResult.handled;
        }
      }
    }
    return _pasteKeyHandler?.call(node, event) ?? KeyEventResult.ignored;
  }

  int get _dialogTvItemCount {
    if (_namingImported) return 3;
    if (_editing) return 6;
    if (_showManualForm) return 8;
    return 2;
  }

  int get _dialogOkIndex {
    if (_namingImported) return 1;
    if (_editing) return 4;
    return _showManualForm ? 6 : 2;
  }

  int get _dialogCancelIndex {
    if (_namingImported) return 2;
    if (_editing) return 5;
    return _showManualForm ? 7 : 3;
  }

  void _focusDialogItem(int index) {
    if (!mounted || !iptvUseTvFocus(context)) return;
    final clamped = index.clamp(0, _dialogTvItemCount - 1);
    if (_namingImported) {
      final nodes = [_labelFocus, _submitFocus, _cancelFocus];
      nodes[clamped].requestFocus();
      return;
    }
    if (_editing) {
      final nodes = [
        _labelFocus,
        _urlFocus,
        _userFocus,
        _passFocus,
        _submitFocus,
        _cancelFocus,
      ];
      nodes[clamped].requestFocus();
      return;
    }
    if (!_showManualForm) {
      switch (clamped) {
        case 0:
          _pasteFocus.requestFocus();
        default:
          _expandFocus.requestFocus();
      }
      return;
    }
    switch (clamped) {
      case 0:
        _pasteFocus.requestFocus();
      case 1:
        _expandFocus.requestFocus();
      case 2:
        _labelFocus.requestFocus();
      case 3:
        _urlFocus.requestFocus();
      case 4:
        _userFocus.requestFocus();
      case 5:
        _passFocus.requestFocus();
      case 6:
        _submitFocus.requestFocus();
      default:
        _cancelFocus.requestFocus();
    }
  }

  @override
  void dispose() {
    _unregisterPasteTvNode();
    _pasteFocus.onKeyEvent = _pasteKeyHandler;
    _labelCtrl.dispose();
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _pasteCtrl.dispose();
    _pasteFocus.dispose();
    _labelFocus.dispose();
    _urlFocus.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    _expandFocus.dispose();
    _submitFocus.dispose();
    _cancelFocus.dispose();
    super.dispose();
  }

  String _joinedShareCode() => IptvPortalShare.normalizeCode(_pasteCtrl.text);

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

    final cleaned = value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (cleaned != value) {
      _pasteCtrl.value = TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(offset: cleaned.length),
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
        if (mounted && iptvUseTvFocus(context)) {
          _focusDialogItem(2);
        } else if (mounted) {
          _labelFocus.requestFocus();
        }
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && iptvUseTvFocus(context)) {
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
    if (code.length != _codeLen || _importingShareCode) return;
    if (code == _lastImportedCode) return;
    await _importShareCode(code);
  }

  Future<void> _importShareCode(String code) async {
    if (!IptvPortalShare.isValidCode(code)) return;

    setState(() {
      _importingShareCode = true;
      _shareCodeError = null;
    });

    try {
      final portal = await IptvPortalShare.resolveShare(code);
      if (!mounted) return;
      if (portal == null) {
        setState(() {
          _importingShareCode = false;
          _shareCodeError = 'Share code not found or invalid';
        });
        return;
      }
      _urlCtrl.text = portal.url;
      _userCtrl.text = portal.username;
      _passCtrl.text = portal.password;
      _labelCtrl.clear();
      _lastImportedCode = code;
      setState(() {
        _importingShareCode = false;
        _importPhase = _PortalImportPhase.namePortal;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _labelFocus.requestFocus();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _importingShareCode = false;
        _shareCodeError = 'Could not load share code';
      });
    }
  }

  void _cancelNamePortal() {
    if (widget.ctrl.isAdding) return;
    setState(() {
      _importPhase = _PortalImportPhase.shareCode;
      _labelCtrl.clear();
      _urlCtrl.clear();
      _userCtrl.clear();
      _passCtrl.clear();
      _lastImportedCode = null;
      _shareCodeError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (iptvUseTvFocus(context)) {
        _focusDialogItem(0);
      } else {
        _pasteFocus.requestFocus();
      }
    });
  }

  void _trySubmitFromEnter() {
    if (_addSucceeded || _submitInFlight || widget.ctrl.isAdding) return;
    if (!_editing && !_showManualForm && !_namingImported) return;
    _submit();
  }

  Future<void> _submit() async {
    if (_addSucceeded || _submitInFlight || widget.ctrl.isAdding) return;
    final ctrl = widget.ctrl;
    final label = _labelCtrl.text;
    if (_editing) {
      setState(() => _submitInFlight = true);
      await ctrl.updatePortal(
        existing: widget.existing!,
        url: _urlCtrl.text,
        username: _userCtrl.text,
        password: _passCtrl.text,
        label: label,
      );
      if (!mounted) return;
      setState(() => _submitInFlight = false);
      if (ctrl.addError == null) {
        Navigator.of(context).pop();
      }
      return;
    }
    setState(() => _submitInFlight = true);
    await ctrl.addManual(
      url: _urlCtrl.text,
      username: _userCtrl.text,
      password: _passCtrl.text,
      label: label,
      // Keep panel (and this dialog) mounted; select portal without dismissing.
      closePanel: false,
    );
    if (!mounted) return;
    if (ctrl.addError != null) {
      setState(() => _submitInFlight = false);
      return;
    }
    final name = label.trim().isNotEmpty
        ? label.trim()
        : (ctrl.activePortal?.displayLabel ?? 'Portal');
    setState(() {
      _submitInFlight = false;
      _addSucceeded = true;
      _successName = name;
    });
    Future<void>.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      Navigator.of(context).pop();
    });
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
    widget.ctrl.dismissAddDialog();
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
                style: IptvShellStyle.overlayTitle.copyWith(
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
            color: IptvShellStyle.textSecondary,
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
          style: IptvShellStyle.overlayTitle.copyWith(
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
              color: IptvShellStyle.textPrimary,
            ),
          ),
        ),
        SizedBox(height: _tv ? 12 : 14),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color: IptvShellStyle.textSecondary,
            fontSize: 13,
          ),
        ),
        SizedBox(height: _tv ? 16 : 20),
      ],
    );
  }

  Widget _portalDialogCloseButton({required VoidCallback? onTap}) {
    final icon = ForjaPlainIcon(
      icon: Icons.close_rounded,
      tooltip: 'Close',
      color: IptvShellStyle.iconMuted,
      size: 22,
      onTap: onTap,
    );
    if (iptvUseTvFocus(context)) {
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
    final tv = iptvUseTvFocus(context);
    final child = Tooltip(
      message: tooltip,
      child: Icon(icon, color: color, size: _tv ? 22 : 24),
    );
    return iptvTap(
      context: context,
      onTap: onTap,
      borderRadius: 8,
      focusNode: focusNode,
      tvRowId: 'iptv-portal-dialog',
      tvItemIndex: tvItemIndex,
      onUpEdge: () => _focusDialogItem(tvItemIndex - 1),
      onDownEdge: () => _focusDialogItem(tvItemIndex + 1),
      onLeftEdge: tv && tvItemIndex == _dialogCancelIndex
          ? () => _focusDialogItem(_dialogOkIndex)
          : null,
      onRightEdge: tv && tvItemIndex == _dialogOkIndex
          ? () => _focusDialogItem(_dialogCancelIndex)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    final tv = iptvUseTvFocus(context);
    if (tv) {
      iptvSyncRow(
        rowId: 'iptv-portal-dialog',
        sortOrder: 50,
        itemCount: _dialogTvItemCount,
        orientation: ShellTvRowOrientation.vertical,
      );
    } else {
      iptvSyncRow(rowId: 'iptv-portal-dialog', sortOrder: 50, itemCount: 0);
    }
    final labelIndex = _namingImported
        ? 0
        : (_editing ? 0 : (_showManualForm ? 2 : -1));
    final urlIndex = _editing ? 1 : (_showManualForm ? 3 : -1);
    final userIndex = _editing ? 2 : (_showManualForm ? 4 : -1);
    final passIndex = _editing ? 3 : (_showManualForm ? 5 : -1);
    final shareOnlyCollapsed =
        !_editing && !_showManualForm && !_namingImported;
    final gapAfterTitle = _tv ? 8.0 : (_compact ? 14.0 : 22.0);
    final gapBetweenFields = _tv ? 14.0 : (_compact ? 18.0 : 28.0);
    final gapBeforeManual = _tv ? 14.0 : (_compact ? 18.0 : 28.0);
    final gapBeforeActions = _tv ? 10.0 : (_compact ? 12.0 : 20.0);
    // Collapsed: room to vertically center "Share code" + code boxes as one block.
    final collapsedBodyHeight = _tv ? 152.0 : (_compact ? 172.0 : 196.0);
    final surfacePadding = _tv
        ? const EdgeInsets.fromLTRB(14, 12, 10, 14)
        : _compact
            ? const EdgeInsets.fromLTRB(16, 16, 12, 16)
            : EdgeInsets.fromLTRB(
                24,
                shareOnlyCollapsed ? 12 : 20,
                16,
                _editing || _showManualForm || _namingImported ? 24 : 20,
              );
    final screenH = MediaQuery.sizeOf(context).height;
    final maxHeight = _tv
        ? (screenH * 0.62).clamp(320.0, 460.0)
        : screenH -
            MediaQuery.viewInsetsOf(context).bottom -
            (_compact ? 32.0 : 64.0);
    final dialogMaxWidth = _tv ? 360.0 : 440.0;
    final titleLabel = _namingImported
        ? 'Portal name'
        : (_editing ? 'Edit Portal' : 'Add Portal');
    final expandBtnSize = _tv ? 34.0 : 38.0;
    final expandOverlap = expandBtnSize / 2;
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, _) {
        final adding = ctrl.isAdding || _submitInFlight;
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
            child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: _tv ? 28 : (_compact ? 20 : 24),
          vertical: _tv ? 36 : (_compact ? 16 : 32),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: dialogMaxWidth, maxHeight: maxHeight),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Padding(
                padding: EdgeInsets.only(
                  bottom: showExpandToggle ? expandOverlap : 0,
                ),
                child: DecoratedBox(
                  decoration: IptvShellStyle.dialogSurface(),
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
                                    style: IptvShellStyle.overlayTitle.copyWith(
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
                            ),
                            if (ctrl.addError != null) ...[
                              SizedBox(
                                height: _tv ? 6 : (_compact ? 8 : 12),
                              ),
                              Text(
                                ctrl.addError!,
                                style: GoogleFonts.plusJakartaSans(
                                  color: IptvShellStyle.liveBadge,
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
                                  color: IptvShellStyle.textSecondary,
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
                                          style: IptvShellStyle.overlayTitle
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
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    titleLabel,
                                    style: IptvShellStyle.overlayTitle.copyWith(
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
                            Flexible(
                              fit: FlexFit.loose,
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (!_editing) _shareCodeSection(),
                                    AnimatedSize(
                                      duration:
                                          const Duration(milliseconds: 280),
                                      curve: Curves.easeOutCubic,
                                      alignment: Alignment.topCenter,
                                      clipBehavior: Clip.hardEdge,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          if (!_editing)
                                            SizedBox(height: gapBeforeManual),
                                          _portalField(
                                            _labelCtrl,
                                            'Portal name',
                                            hint: 'My provider',
                                            focusNode: _labelFocus,
                                            dialogIndex: labelIndex,
                                          ),
                                          SizedBox(height: gapBetweenFields),
                                          _portalField(
                                            _urlCtrl,
                                            'URL',
                                            hint:
                                                'http://portal.example.com:8080',
                                            focusNode: _urlFocus,
                                            dialogIndex: urlIndex,
                                          ),
                                          SizedBox(height: gapBetweenFields),
                                          _portalField(
                                            _userCtrl,
                                            'Username',
                                            hint: 'username',
                                            focusNode: _userFocus,
                                            dialogIndex: userIndex,
                                          ),
                                          SizedBox(height: gapBetweenFields),
                                          _portalField(
                                            _passCtrl,
                                            'Password',
                                            hint: 'password',
                                            obscure: _obscurePassword,
                                            focusNode: _passFocus,
                                            dialogIndex: passIndex,
                                            suffix: ForjaPlainIcon(
                                              icon: _obscurePassword
                                                  ? Icons.visibility_outlined
                                                  : Icons
                                                      .visibility_off_outlined,
                                              tooltip: _obscurePassword
                                                  ? 'Show password'
                                                  : 'Hide password',
                                              color: IptvShellStyle.iconMuted,
                                              size: 20,
                                              onTap: () => setState(
                                                () => _obscurePassword =
                                                    !_obscurePassword,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (ctrl.addError != null) ...[
                                      SizedBox(
                                        height: _tv ? 6 : (_compact ? 8 : 12),
                                      ),
                                      Text(
                                        ctrl.addError!,
                                        style: GoogleFonts.plusJakartaSans(
                                          color: IptvShellStyle.liveBadge,
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
                                  color: IptvShellStyle.textSecondary,
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
        );
      },
    );
  }

  Widget _manualFormToggle({required double size}) {
    final tv = iptvUseTvFocus(context);
    final tvFocused = tv && _expandFocused;
    final active = iptvFocusActive(
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
            ? iptvFocusButtonDecoration(
                active: true,
                tvFocused: tvFocused,
                borderRadius: radius,
                idleBg: IptvShellStyle.surface,
                idleBorder: IptvShellStyle.border,
                subtle: true,
              )
            : BoxDecoration(
                color: IptvShellStyle.surface,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: IptvShellStyle.border),
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
          color: iptvFocusFg(
            IptvShellStyle.textSecondary,
            active: active,
            tvFocused: tvFocused,
          ),
          size: iconSize,
        ),
      ),
    );
    return iptvTap(
      context: context,
      onTap: _importingShareCode ? null : _toggleManualForm,
      borderRadius: radius,
      focusNode: tv ? _expandFocus : null,
      tvRowId: tv ? 'iptv-portal-dialog' : null,
      tvItemIndex: tv ? 1 : null,
      onUpEdge: tv ? () => _focusDialogItem(0) : null,
      onDownEdge: tv
          ? () => _focusDialogItem(_showManualForm ? 2 : 1)
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _codeBoxHeight,
          child: Stack(
            children: [
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
                  readOnly: iptvUseTvFocus(context) && !_pasteEditing,
                  enableInteractiveSelection:
                      !iptvUseTvFocus(context) || _pasteEditing,
                  maxLength: _codeLen,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.visiblePassword,
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
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  ],
                  onChanged: _onSharePasteChanged,
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
                  color: IptvShellStyle.accent,
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
              color: IptvShellStyle.liveBadge,
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
    final borderColor = iptvDialogFieldBorderColor(focused: pasteFocused);
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
            color: IptvShellStyle.textPrimary,
            fontSize: _codeFontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
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
    int dialogIndex = -1,
  }) {
    final tv = iptvUseTvFocus(context);
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
            color: IptvShellStyle.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        SizedBox(height: _tv ? 3 : (compact ? 4 : 6)),
        if (tv && focusNode != null && dialogIndex >= 0)
          _IptvPortalDialogField(
            controller: c,
            focusNode: focusNode,
            obscureText: obscure,
            hintText: hint,
            hintStyle: hintStyle,
            suffixIcon: suffix,
            style: GoogleFonts.plusJakartaSans(
              color: IptvShellStyle.textPrimary,
              fontSize: _tv ? 13 : 14,
            ),
            onArrowUp: () => _focusDialogItem(dialogIndex - 1),
            onArrowDown: () => _focusDialogItem(dialogIndex + 1),
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
              color: IptvShellStyle.textPrimary,
              fontSize: _tv ? 12 : (compact ? 13 : 14),
            ),
            decoration: iptvDialogFieldDecoration(
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
