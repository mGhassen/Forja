part of 'search_screen.dart';

mixin _SearchBuild on ConsumerState<SearchScreen> {
  SearchScreenState get _s => this as SearchScreenState;

  double _searchPageTopInset(BuildContext context) =>
      ShellTokens.searchPageInset;

  PreferredSizeWidget _buildOverlayAppBar() {
    return AppBar(
      backgroundColor: AppTheme.bgDark,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      titleSpacing: 0,
      title: TextField(
        controller: _s._controller,
        focusNode: _s._focusNode,
        autofocus: true,
        onChanged: _s._onSearchChanged,
        onSubmitted: (_) => _s._submitSearchField(),
        textInputAction: TextInputAction.search,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: ForjaShellColors.sectionAccent,
        decoration: InputDecoration(
          hintText: 'Search movies, shows…',
          hintStyle: TextStyle(
            color: ForjaShellColors.cinematic.textSecondary.withValues(
              alpha: 0.7,
            ),
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
        ),
      ),
      actions: [
        if (_s._controller.text.isNotEmpty)
          ForjaCloseButton.compact(
            tooltip: null,
            color: ForjaShellColors.cinematic.textPrimary,
            onTap: () {
              _s._controller.clear();
              _s._onSearchChanged('');
            },
          ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget buildShellSearchBar() {
    if (_s._isDesktopLayout(context)) return const SizedBox.shrink();
    return ShellSearchBar(
      controller: _s._controller,
      focusNode: _s._focusNode,
      query: _s._query,
      onChanged: _s._onSearchChanged,
      onSubmitted: (_) => _s._submitSearchField(),
      onClear: () {
        _s._controller.clear();
        _s._onSearchChanged('');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _s._watchSearchResultsProvider();
    ref.watch(searchAddonProvidersProvider);

    Widget body;
    if (widget.overlay) {
      body = ValueListenableBuilder<AppThemePreset>(
        valueListenable: AppTheme.themeNotifier,
        builder: (context, _, _) {
          if (_s._isDesktopLayout(context)) {
            return ColoredBox(
              color: AppTheme.bgDark,
              child: _buildDesktopLayout(context),
            );
          }
          return Scaffold(
            backgroundColor: AppTheme.bgDark,
            appBar: _buildOverlayAppBar(),
            body: _buildMobileBody(context),
          );
        },
      );
    } else if (_s._isDesktopLayout(context)) {
      body = _buildDesktopLayout(context);
    } else {
      body = _buildMobileBody(context);
    }

    return TvFocusGraph(tabId: 'search', child: body);
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final focused = _s._focusedResult;
    final results = _s._flatResults();
    final backdropUrl = focused?.backdropUrl ?? focused?.posterUrl;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (backdropUrl != null && backdropUrl.isNotEmpty)
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: backdropUrl,
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppTheme.bgDark,
                  AppTheme.bgDark.withValues(alpha: 0.92),
                  AppTheme.bgDark.withValues(alpha: 0.55),
                ],
                stops: const [0.0, 0.42, 1.0],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            ShellTokens.usesCompactNavDrawer(context)
                ? ShellTokens.compactChromeLeadingInset(context)
                : ShellTokens.searchPageInset,
            _searchPageTopInset(context),
            ShellTokens.searchPageInset,
            ShellTokens.searchPageInset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSearchField(context),
              const SizedBox(height: 24),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: _buildHelpersList(context)),
                    const SizedBox(width: ShellTokens.searchColumnGap),
                    Expanded(
                      flex: 7,
                      child: _buildResultsColumn(context, results),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField(BuildContext context) {
    final tvFocus = _s._tvFocus(context);
    final browseOnly = tvFocus && !_s._searchFieldEditing;
    const hint = 'Search movies, shows...';
    final hintStyle = TextStyle(
      color: ForjaShellColors.textSecondary.withValues(alpha: 0.7),
      fontSize: 32,
      fontWeight: FontWeight.w600,
      height: 1.15,
    );
    final showBrowsePlaceholder =
        browseOnly && _s._focusNode.hasFocus && _s._query.isEmpty;

    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        TextField(
          controller: _s._controller,
          focusNode: _s._focusNode,
          autofocus: !tvFocus,
          readOnly: browseOnly,
          showCursor: !browseOnly || _s._query.isNotEmpty,
          enableInteractiveSelection: !browseOnly,
          onChanged: _s._onSearchChanged,
          onSubmitted: (_) => _s._submitSearchField(),
          textInputAction: TextInputAction.search,
          style: TextStyle(
            color: ForjaShellColors.textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.w600,
            height: 1.15,
          ),
          cursorColor: ForjaShellColors.textPrimary,
          cursorHeight: 36,
          decoration: InputDecoration(
            hintText: showBrowsePlaceholder ? null : hint,
            hintStyle: hintStyle,
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
            suffixIcon: _s._query.isNotEmpty
                ? ForjaCloseButton.compact(
                    tooltip: null,
                    color: ForjaShellColors.textSecondary,
                    focusNode: _s._closeFocusNode,
                    onKeyEvent: _s._searchCloseKeyEvent,
                    onTap: () {
                      _s._controller.clear();
                      _s._onSearchChanged('');
                      _s._focusSearchFieldBrowse();
                    },
                  )
                : null,
          ),
        ),
        if (showBrowsePlaceholder)
          TvSearchBrowsePlaceholder(
            active: true,
            placeholder: hint,
            hintStyle: hintStyle,
            caretHeight: 36,
          ),
      ],
    );
  }

  Widget _buildHelperTitle(String title, {required bool selected}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected
                ? ForjaShellColors.textPrimary
                : ForjaShellColors.textSecondary,
            fontSize: selected ? 18 : 16,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            height: 1.25,
          ),
        ),
      ),
    );
  }

  Widget _buildHelpersList(BuildContext context) {
    if (_s._trendingHelperTitles.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final titles = _s._trendingHelperTitles;
    return TvCatalogRow(
      tabId: 'search',
      rowId: 'helpers',
      sortOrder: 0,
      itemCount: titles.length,
      orientation: ShellTvRowOrientation.vertical,
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: ListView.separated(
          controller: _s._helpersScrollController,
          clipBehavior: Clip.none,
          padding: const EdgeInsets.only(right: 8, bottom: 8),
          physics: const ClampingScrollPhysics(),
          itemCount: titles.length,
          separatorBuilder: (_, _) => const SizedBox(height: 1),
          itemBuilder: (context, index) {
            final title = titles[index];
            final count = titles.length;
            return FocusTraversalOrder(
              order: NumericFocusOrder(index.toDouble()),
              child: shellFocusableTap(
                context: context,
                onTap: () => _s._applyHelperQuery(title),
                borderRadius: 4,
                scaleOnFocus: 1.0,
                navLeftAlways: true,
                listIndex: index,
                tvTabId: 'search',
                tvRowId: 'helpers',
                tvZone: ShellTvZone.chipStrip,
                tvItemIndex: index,
                focusNode: index == 0 ? _s._firstHelperFocusNode : null,
                onUpEdge: _s._helperUpEdge(index),
                onDownEdge: _s._helperDownEdge(index, count),
                onRightEdge: _s._helperRightEdge(index),
                ensureVisibleMode: ShellTvEnsureVisibleMode.row,
                onFocusChange: (focused) {
                  if (focused) {
                    _s._setHelperFocusedIndex(index);
                  } else {
                    _s._clearHelperFocusedIndex(index);
                  }
                },
                child: _buildHelperTitle(
                  title,
                  selected: _s._helperFocusedIndex == index,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildResultsColumn(
    BuildContext context,
    List<_FlatSearchResult> results,
  ) {
    if (_s._query.isEmpty) {
      return Align(
        alignment: Alignment.topLeft,
        child: _buildEmpty(hint: 'Start typing to search'),
      );
    }
    if (results.isEmpty && _s._isSearching) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.current.primaryColor),
      );
    }
    if (results.isEmpty) {
      return Align(
        alignment: Alignment.topLeft,
        child: _buildEmpty(hint: 'No results found'),
      );
    }

    const gridColumns = 4;
    final tvFocus = _s._tvFocus(context);

    return TvGrid(
      tabId: 'search',
      rowId: 'results',
      sortOrder: 1,
      columns: gridColumns,
      itemCount: results.length,
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: GridView.builder(
          controller: _s._resultsScrollController,
          clipBehavior: Clip.none,
          padding: const EdgeInsets.only(bottom: 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridColumns,
            mainAxisSpacing: 16,
            crossAxisSpacing: 14,
            childAspectRatio: 2 / 3,
          ),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final item = results[index];
            final firstColumn = index % gridColumns == 0;
            final firstRow = index ~/ gridColumns == 0;
            return Padding(
              padding: const EdgeInsets.all(4),
              child: _SearchFilmCard(
                result: item,
                selected: index == _s._gridFocusedIndex,
                gridIndex: index,
                onTap: () => _s._setGridFocusedIndex(index),
                onOpen: () => _s._openResult(item),
                onLeftEdge: firstColumn && tvFocus
                    ? () => _s._focusHelperAtVisualLevelFromGrid(index)
                    : null,
                onUpEdge:
                    firstRow && tvFocus ? _s._focusSearchFieldBrowse : null,
                onFocusChange: (focused) {
                  if (focused) {
                    setState(() {
                      _s._gridFocusedIndex = index;
                      _s._helperFocusedIndex = null;
                    });
                  } else {
                    _s._clearGridFocusedIndex(index);
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMobileBody(BuildContext context) {
    final isWide = shellUsesWideLayout(context);
    final bottomPad = isWide ? 24.0 : ShellTokens.bottomNavHeight;

    Widget body;
    if (_s._query.isEmpty) {
      body = _buildEmpty();
    } else if (_s._sections.isEmpty && _s._isSearching) {
      body = Center(
        child: CircularProgressIndicator(color: AppTheme.current.primaryColor),
      );
    } else if (_s._sections.isEmpty && !_s._isSearching) {
      body = _buildEmpty(hint: 'No results found');
    } else {
      body = ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(bottom: bottomPad),
        itemCount: _s._sections.length + (_s._isSearching ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _s._sections.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white24,
                  ),
                ),
              ),
            );
          }
          final section = _s._sections[index];
          return _buildSliderSection(section);
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ShellTokens.bodyHorizontalPadding,
      ),
      child: body,
    );
  }

  Widget _buildSliderSection(_SearchSection section) {
    final isWide = shellUsesWideLayout(context);
    final cardWidth = isWide
        ? ShellTokens.searchCardWidthDesktop
        : ShellTokens.searchCardWidthCompact;
    final cardHeight = cardWidth * 1.5;

    return Padding(
      padding: const EdgeInsets.only(top: ShellTokens.sectionTopSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (section.icon != null && section.icon!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(
                    imageUrl: section.icon!,
                    width: 20,
                    height: 20,
                    errorWidget: (_, _, _) => const Icon(
                      Icons.extension,
                      size: 16,
                      color: Colors.white38,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ] else if (section.isTmdb) ...[
                const Icon(Icons.movie, size: 18, color: Colors.amber),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  section.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${section.results.length}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          HorizontalScroller(
            height: cardHeight + 32,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: section.results.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = section.results[index];
              if (item is Movie) {
                return SizedBox(
                  width: cardWidth,
                  child: _SearchCard(
                    movie: item,
                    listIndex: index,
                    onTap: () => _s._openDetails(item),
                  ),
                );
              } else {
                final map = item as Map<String, dynamic>;
                return SizedBox(
                  width: cardWidth,
                  child: _StremioSearchCard(
                    item: map,
                    listIndex: index,
                    onTap: () => _s._openStremioItem(map),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty({String? hint}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 80,
            color: Colors.white.withValues(alpha: 0.05),
          ),
          const SizedBox(height: 16),
          Text(
            hint ??
                (_s._query.isEmpty
                    ? 'Search for your favorite content'
                    : 'No results found'),
            style: const TextStyle(color: Colors.white38),
          ),
        ],
      ),
    );
  }
}
