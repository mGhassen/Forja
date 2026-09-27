import 'package:flutter/material.dart';
import 'package:forja_foundation/blocks/props_map.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Prebuilt page: filter chrome ([menu] + [tabs]) over an expand [cards] grid.
///
/// My List shape (kind underline menu → status tabs → poster grid) — **not** a
/// `myList*` product type. Host paints real menu/tabs children; this block only
/// stacks them.
///
/// ```
/// ┌──── menu (kinds, optional) ───┐
/// ├──── tabs (status) ────────────┤
/// │                               │
/// │         cards (grid)          │
/// │                               │
/// └───────────────────────────────┘
/// ```
/// Kind-menu pages (Downloads, My List) sit under the window title bar.
/// Poster grids inside the scope share the menu's left inset.
/// Trailing page panel for [TabsCardsBlock]. The list docks a widget here so
/// it spans the page, beside the kind menu, instead of starting under it.
class TabsCardsDock extends ChangeNotifier {
  String? _key;
  Widget? _panel;
  bool _disposed = false;

  String? get key => _key;
  Widget? get panel => _panel;

  void present(String? key, Widget? panel) {
    if (_disposed || _key == key) return;
    _key = key;
    _panel = panel;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class TabsCardsDockHost extends InheritedNotifier<TabsCardsDock> {
  const TabsCardsDockHost({
    super.key,
    required TabsCardsDock dock,
    required super.child,
  }) : super(notifier: dock);

  static TabsCardsDock? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<TabsCardsDockHost>()
        ?.notifier;
  }
}

class TabsCardsPageScope extends InheritedWidget {
  const TabsCardsPageScope({super.key, required super.child});

  static bool of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TabsCardsPageScope>() !=
        null;
  }

  @override
  bool updateShouldNotify(TabsCardsPageScope oldWidget) => false;
}

class TabsCardsBlock extends StatefulWidget {
  const TabsCardsBlock({
    super.key,
    this.menu,
    this.tabs,
    required this.cards,
    this.backgroundColor,
  });

  factory TabsCardsBlock.fromProps(
    Map<String, dynamic> props, {
    Widget? menu,
    Widget? tabs,
    required Widget cards,
  }) {
    return TabsCardsBlock(
      menu: menu,
      tabs: tabs,
      cards: cards,
      backgroundColor: propsColor(props, 'backgroundColor'),
    );
  }

  final Widget? menu;
  final Widget? tabs;
  final Widget cards;
  final Color? backgroundColor;

  @override
  State<TabsCardsBlock> createState() => _TabsCardsBlockState();
}

class _TabsCardsBlockState extends State<TabsCardsBlock> {
  final TabsCardsDock _dock = TabsCardsDock();

  @override
  void dispose() {
    _dock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.backgroundColor ?? ForjaShellColors.bgDark;
    final windowTop = MediaQuery.paddingOf(context).top;
    final belowTitle =
        ShellTokens.shellHeaderTopPadding - ShellTokens.tabHeaderTopPadding;
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?widget.menu,
        ?widget.tabs,
        Expanded(child: widget.cards),
      ],
    );
    return TabsCardsDockHost(
      dock: _dock,
      child: TabsCardsPageScope(
        child: ColoredBox(
          color: bg,
          child: Padding(
            padding: EdgeInsets.only(
              top: windowTop + (belowTitle > 0 ? belowTitle : 0),
            ),
            child: ListenableBuilder(
              listenable: _dock,
              builder: (context, _) {
                final panel = _dock.panel;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: panel == null ? 1 : 60, child: column),
                    if (panel != null)
                      Expanded(
                        flex: 40,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(
                              ShellTokens.posterCardRadius,
                            ),
                          ),
                          child: panel,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
