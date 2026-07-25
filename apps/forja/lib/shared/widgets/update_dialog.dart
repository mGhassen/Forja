import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/services/app_update_download_service.dart';
import 'package:forja/shared/services/app_updater_release_notes.dart';
import 'package:forja/shared/services/app_updater_service.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/forja_logo.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

// Conditional import for Android-only package
import 'package:ota_update/ota_update.dart'
    if (dart.library.html) 'package:ota_update/ota_update_stub.dart';

/// Layout tokens - scaled from the **available viewport**, not fixed px.
///
/// Header/logo/gaps shrink on short windows so the pinned footer always fits
/// and only the changelog scrolls.
class _UpdateLayout {
  const _UpdateLayout._({
    required this.isTv,
    required this.contentWidth,
    required this.logoWidth,
    required this.logoHeight,
    required this.headlineSize,
    required this.versionSize,
    required this.metaSize,
    required this.bodySize,
    required this.sectionSize,
    required this.logoTopGap,
    required this.blockGap,
    required this.metaGap,
    required this.noticeGap,
    required this.dividerBeforeGap,
    required this.dividerAfterGap,
    required this.sectionLabelGap,
    required this.footerGap,
    required this.padTop,
    required this.padBottom,
    required this.padHorizontal,
    required this.buttonHeight,
    required this.buttonFontSize,
    required this.skipFontSize,
    required this.downloadPercentSize,
    required this.downloadLogoWidth,
    required this.downloadGapLarge,
    required this.downloadGapSmall,
  });

  final bool isTv;
  final double contentWidth;
  final double logoWidth;
  final double logoHeight;
  final double headlineSize;
  final double versionSize;
  final double metaSize;
  final double bodySize;
  final double sectionSize;
  final double logoTopGap;
  final double blockGap;
  final double metaGap;
  final double noticeGap;
  final double dividerBeforeGap;
  final double dividerAfterGap;
  final double sectionLabelGap;
  final double footerGap;
  final double padTop;
  final double padBottom;
  final double padHorizontal;
  final double buttonHeight;
  final double buttonFontSize;
  final double skipFontSize;
  final double downloadPercentSize;
  final double downloadLogoWidth;
  final double downloadGapLarge;
  final double downloadGapSmall;

  /// [width]/[height] are the SafeArea / LayoutBuilder constraints.
  factory _UpdateLayout.of(
    BuildContext context, {
    required double width,
    required double height,
  }) {
    final isTv =
        (ShellScope.maybeOf(context)?.profile ??
            resolveShellProfile(context)) ==
        ShellProfile.tv;

    // 0 = short window (~520), 1 = comfortable (~900+). Drives logo/type/gaps.
    final scale = ((height - 520) / 380).clamp(0.0, 1.0);

    double lerp(double a, double b) => a + (b - a) * scale;

    if (isTv) {
      final contentWidth = (width * 0.44).clamp(280.0, 380.0);
      final logoHeight = (height * 0.08).clamp(36.0, 56.0);
      return _UpdateLayout._(
        isTv: true,
        contentWidth: contentWidth,
        logoWidth: logoHeight * forjaLogoAspectRatio,
        logoHeight: logoHeight,
        headlineSize: 26,
        versionSize: 18,
        metaSize: 12,
        bodySize: 13,
        sectionSize: 11,
        logoTopGap: lerp(10, 22),
        blockGap: lerp(6, 10),
        metaGap: 6,
        noticeGap: 8,
        dividerBeforeGap: lerp(10, 16),
        dividerAfterGap: lerp(6, 10),
        sectionLabelGap: 6,
        footerGap: 14,
        padTop: 16,
        padBottom: 16,
        padHorizontal: ((width - contentWidth) / 2).clamp(40.0, width),
        buttonHeight: 42,
        buttonFontSize: 14,
        skipFontSize: 13,
        downloadPercentSize: 38,
        downloadLogoWidth: (width.clamp(240.0, 400.0) * 0.22),
        downloadGapLarge: 28,
        downloadGapSmall: 8,
      );
    }

    final isWide = width > 720;
    // Wider so the version rail + notes sit side by side.
    final contentWidth = isWide ? 780.0 : (width - 48).clamp(280.0, width);
    // Logo tracks viewport height (~10%), capped so it never eats the page.
    final logoHeight = (height * 0.10).clamp(40.0, 88.0);
    final logoWidth = (logoHeight * forjaLogoAspectRatio).clamp(
      0.0,
      contentWidth * 0.85,
    );

    return _UpdateLayout._(
      isTv: false,
      contentWidth: contentWidth,
      logoWidth: logoWidth,
      logoHeight: logoWidth / forjaLogoAspectRatio,
      headlineSize: lerp(24, width > 600 ? 34 : 28),
      versionSize: lerp(17, 22),
      metaSize: 14,
      bodySize: 15,
      sectionSize: 13,
      logoTopGap: lerp(10, 28),
      blockGap: lerp(6, 12),
      metaGap: lerp(4, 10),
      noticeGap: lerp(6, 12),
      dividerBeforeGap: lerp(10, 20),
      dividerAfterGap: lerp(8, 14),
      sectionLabelGap: 8,
      footerGap: lerp(10, 16),
      padTop: lerp(12, 24),
      padBottom: lerp(12, 24),
      padHorizontal: contentWidth >= width - 56
          ? 28
          : (width - contentWidth) / 2,
      buttonHeight: 54,
      buttonFontSize: 16,
      skipFontSize: 15,
      downloadPercentSize: lerp(40, 56),
      downloadLogoWidth: (width.clamp(240.0, 400.0) * 0.38),
      downloadGapLarge: lerp(28, 48),
      downloadGapSmall: 8,
    );
  }
}

/// Full-screen update gate - App Store / Play Store style, not a card dialog.
class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  static Future<void> show(BuildContext hostContext, UpdateInfo updateInfo) {
    return showGeneralDialog<void>(
      context: hostContext,
      barrierDismissible: false,
      barrierColor: AppTheme.bgDark,
      barrierLabel: 'Software update',
      transitionDuration: const Duration(milliseconds: 480),
      pageBuilder: (dialogContext, _, _) =>
          _scopeHost(hostContext, UpdateDialog(updateInfo: updateInfo)),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  static Widget _scopeHost(BuildContext hostContext, Widget child) {
    final existing = ShellScope.maybeOf(hostContext);
    if (existing != null) {
      return ShellScope(
        profile: existing.profile,
        config: existing.config,
        child: child,
      );
    }
    final profile = resolveShellProfile(hostContext);
    final config = shellPlatformConfigFor(profile);
    return ShellScope(profile: profile, config: config, child: child);
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  final AppUpdateDownloadService _desktopDownload =
      AppUpdateDownloadService.instance;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _showingDownloadComplete = false;
  int _selectedChangelog = 0;

  @override
  void initState() {
    super.initState();
    _desktopDownload.state.addListener(_onDesktopDownloadChanged);
    final current = _desktopDownload.state.value;
    if (current.phase == AppUpdateDownloadPhase.downloading &&
        current.updateInfo?.latestVersion == widget.updateInfo.latestVersion) {
      _isDownloading = true;
      _downloadProgress = current.progress;
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Always re-check disk: Settings may have cleared installers while the
      // in-memory service still said "completed".
      unawaited(_reconcileCachedInstaller());
    }
  }

  Future<void> _reconcileCachedInstaller() async {
    final usable = await _desktopDownload.hasUsableCachedInstaller(
      widget.updateInfo,
    );
    if (!mounted || !usable) return;
    _onDesktopDownloadChanged();
  }

  @override
  void dispose() {
    _desktopDownload.state.removeListener(_onDesktopDownloadChanged);
    super.dispose();
  }

  void _onDesktopDownloadChanged() {
    final current = _desktopDownload.state.value;
    if (current.updateInfo?.latestVersion != widget.updateInfo.latestVersion ||
        !mounted) {
      return;
    }

    if (current.phase == AppUpdateDownloadPhase.downloading) {
      setState(() {
        _isDownloading = true;
        _downloadProgress = current.progress;
      });
    } else if (current.phase == AppUpdateDownloadPhase.failed) {
      setState(() => _isDownloading = false);
    } else if (current.phase == AppUpdateDownloadPhase.completed) {
      setState(() {
        _isDownloading = false;
        _downloadProgress = 1;
      });
      if (!_showingDownloadComplete) {
        _showingDownloadComplete = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showCompletedDesktopDownload(current);
        });
      }
    }
  }

  Future<void> _showCompletedDesktopDownload(
    AppUpdateDownloadState current,
  ) async {
    final filePath = current.filePath;
    if (filePath == null) return;
    await _DownloadCompleteScreen.show(
      context: context,
      filePath: filePath,
      dirPath: File(filePath).parent.path,
      fileName: File(filePath).uri.pathSegments.last,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.bgDark,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final layout = _UpdateLayout.of(
              context,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
            );

            if (_isDownloading) {
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: layout.padHorizontal,
                  vertical: layout.padTop,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - layout.padTop * 2,
                    maxWidth: layout.contentWidth,
                  ),
                  child: Center(
                    child: _buildDownloadingBody(layout),
                  ),
                ),
              );
            }

            // Fill the viewport: header + footer pinned, only changelog scrolls.
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: layout.contentWidth,
                height: constraints.maxHeight,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    layout.padTop,
                    24,
                    layout.padBottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildOfferHeader(layout),
                      Expanded(child: _buildReleaseNotes(layout)),
                      SizedBox(height: layout.footerGap),
                      _UpdateFooter(
                        layout: layout,
                        onUpdate: _handleUpdate,
                        onSkip: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOfferHeader(_UpdateLayout layout) {
    final published = _formatPublishedDate(widget.updateInfo.publishedAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ForjaLogo(
            width: layout.logoWidth,
            height: layout.logoHeight,
            letterStyles: {
              for (final letter in forjaLetterOrder)
                letter: ForjaLetterStyle(
                  color: ForjaLogoColors.peacock[letter]!,
                ),
            },
            halo: ForjaLogoHalo(
              color: ForjaShellColors.brandGreen,
              centerAlpha: 0.14,
              midAlpha: 0.06,
              blurSigma: layout.logoHeight * 0.08,
              glowSourceSize: layout.logoHeight * 0.7,
            ),
          ),
        ),
        SizedBox(height: layout.logoTopGap),
        Text(
          'A new version\nis ready',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: layout.headlineSize,
            fontWeight: FontWeight.w800,
            height: 1.08,
            letterSpacing: -0.8,
            color: ForjaShellColors.textPrimary,
          ),
        ),
        SizedBox(height: layout.blockGap),
        Text(
          'v${widget.updateInfo.latestVersion}',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: layout.versionSize,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: ForjaShellColors.brandGreen,
          ),
        ),
        SizedBox(height: layout.metaGap),
        Text(
          'You’re on v${widget.updateInfo.currentVersion}'
          '${published != null ? '  ·  $published' : ''}',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: layout.metaSize,
            height: 1.4,
            color: ForjaShellColors.textSecondary,
          ),
        ),
        if (_platformNotice != null) ...[
          SizedBox(height: layout.noticeGap),
          Text(
            _platformNotice!,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: layout.metaSize,
              height: 1.45,
              color: const Color(0xFFFBBF24),
            ),
          ),
        ],
        SizedBox(height: layout.dividerBeforeGap),
        Divider(height: 1, color: ForjaShellColors.borderSubtle),
        SizedBox(height: layout.dividerAfterGap),
        Text(
          'What’s new',
          style: GoogleFonts.plusJakartaSans(
            fontSize: layout.sectionSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: ForjaShellColors.textSecondary,
          ),
        ),
        SizedBox(height: layout.sectionLabelGap),
      ],
    );
  }

  Widget _buildReleaseNotes(_UpdateLayout layout) {
    final changelogs = widget.updateInfo.changelogs;
    final showRail = changelogs.length > 1;
    final railWidth = layout.isTv ? 96.0 : 118.0;

    final notesBody = _buildSelectedChangelogBody(layout, changelogs);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: showRail
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: railWidth,
                      child: _ChangelogVersionRail(
                        layout: layout,
                        changelogs: changelogs,
                        selected: _selectedChangelog,
                        onSelect: (i) => setState(() => _selectedChangelog = i),
                      ),
                    ),
                    SizedBox(width: layout.isTv ? 12 : 18),
                    Expanded(
                      child: _ReleaseNotesScroller(
                        layout: layout,
                        child: notesBody,
                      ),
                    ),
                  ],
                )
              : _ReleaseNotesScroller(layout: layout, child: notesBody),
        ),
        SizedBox(height: layout.isTv ? 8 : 12),
        _FullChangelogLink(
          layout: layout,
          url: widget.updateInfo.fullChangelogUrl,
        ),
      ],
    );
  }

  Widget _buildSelectedChangelogBody(
    _UpdateLayout layout,
    List<VersionChangelog> changelogs,
  ) {
    if (changelogs.isEmpty) {
      return Text(
        'No release notes were published for this update.',
        style: GoogleFonts.plusJakartaSans(
          fontSize: layout.bodySize,
          height: 1.6,
          color: ForjaShellColors.textSecondary,
        ),
      );
    }

    final index = _selectedChangelog.clamp(0, changelogs.length - 1);
    final selected = changelogs[index];
    final sections = _ReleaseNotesParser.parseSections(selected.body);

    if (sections.isEmpty) {
      return Text(
        'No release notes were published for v${selected.version}.',
        style: GoogleFonts.plusJakartaSans(
          fontSize: layout.bodySize,
          height: 1.6,
          color: ForjaShellColors.textSecondary,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (changelogs.length == 1)
          _ReleaseNoteVersionHeader(
            title: selected.version,
            layout: layout,
            isFirst: true,
          ),
        for (var i = 0; i < sections.length; i++) ...[
          if (sections[i].title != null && !sections[i].isVersion)
            _ReleaseNoteGroupHeader(
              title: sections[i].title!,
              layout: layout,
              isFirst: i == 0 && changelogs.length > 1,
            ),
          if (sections[i].title != null && sections[i].isVersion)
            _ReleaseNoteVersionHeader(
              title: sections[i].title!,
              layout: layout,
              isFirst: i == 0,
            ),
          ...sections[i].items.map(
            (item) => _ReleaseNoteRow(item: item, layout: layout),
          ),
        ],
      ],
    );
  }

  Widget _buildDownloadingBody(_UpdateLayout layout) {
    final percent = (_downloadProgress * 100).clamp(0, 100).round();
    final logoWidth = layout.downloadLogoWidth;
    final logoHeight = logoWidth / forjaLogoAspectRatio;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ForjaLogo(
          width: logoWidth,
          height: logoHeight,
          letterStyles: {
            for (final letter in forjaLetterOrder)
              letter: ForjaLetterStyle(
                color: ForjaShellColors.brandGreen,
                opacity: 0.85,
              ),
          },
        ),
        SizedBox(height: layout.downloadGapLarge),
        Text(
          '$percent%',
          style: GoogleFonts.plusJakartaSans(
            fontSize: layout.downloadPercentSize,
            fontWeight: FontWeight.w800,
            letterSpacing: -2,
            color: ForjaShellColors.textPrimary,
          ),
        ),
        SizedBox(height: layout.downloadGapSmall),
        Text(
          'Downloading update…',
          style: GoogleFonts.plusJakartaSans(
            fontSize: layout.bodySize,
            color: ForjaShellColors.textSecondary,
          ),
        ),
        SizedBox(height: layout.isTv ? 20 : 32),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: _downloadProgress > 0 ? _downloadProgress : null,
            minHeight: layout.isTv ? 3 : 4,
            backgroundColor: ForjaShellColors.borderSubtle,
            valueColor: const AlwaysStoppedAnimation<Color>(
              ForjaShellColors.brandGreen,
            ),
          ),
        ),
        SizedBox(height: layout.isTv ? 8 : 12),
        Text(
          'v${widget.updateInfo.latestVersion}',
          style: GoogleFonts.plusJakartaSans(
            fontSize: layout.metaSize,
            color: ForjaShellColors.iconMuted,
          ),
        ),
        SizedBox(height: layout.isTv ? 18 : 28),
        _UpdateTextAction(
          layout: layout,
          label: 'Continue in background',
          onTap: () {
            _desktopDownload.continueInBackground();
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  String? get _platformNotice => null;

  String? _formatPublishedDate(DateTime publishedAt) {
    final diff = DateTime.now().difference(publishedAt);
    if (diff.inDays == 0) return 'released today';
    if (diff.inDays == 1) return 'released yesterday';
    if (diff.inDays < 14) return 'released ${diff.inDays} days ago';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return 'released ${months[publishedAt.month - 1]} ${publishedAt.day}';
  }

  Future<void> _handleUpdate() async {
    if (Platform.isAndroid) {
      await _downloadAndInstallAndroid();
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await _desktopDownload.start(widget.updateInfo);
    } else {
      await AppUpdaterService().openDownloadPage(widget.updateInfo.downloadUrl);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _downloadAndInstallAndroid() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      OtaUpdate()
          .execute(
            widget.updateInfo.downloadUrl,
            destinationFilename: 'Forja_${widget.updateInfo.latestVersion}.apk',
          )
          .listen(
            (OtaEvent event) {
              if (!mounted) return;
              setState(() {
                switch (event.status) {
                  case OtaStatus.DOWNLOADING:
                    final value = event.value;
                    if (value != null) {
                      _downloadProgress = (value as num).toDouble() / 100.0;
                    }
                    break;
                  case OtaStatus.INSTALLING:
                    _downloadProgress = 1.0;
                    break;
                  case OtaStatus.ALREADY_RUNNING_ERROR:
                  case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
                  case OtaStatus.INTERNAL_ERROR:
                  case OtaStatus.DOWNLOAD_ERROR:
                  case OtaStatus.CHECKSUM_ERROR:
                    ForjaToast.error('Update failed: ${event.status}');
                    Navigator.of(context).pop();
                    break;
                  default:
                    break;
                }
              });
            },
            onError: (error) {
              if (mounted) {
                setState(() => _isDownloading = false);
                ForjaToast.error('Download failed: $error');
              }
            },
          );
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        ForjaToast.error('Update failed: $e');
      }
    }
  }
}

class _UpdateFooter extends StatelessWidget {
  const _UpdateFooter({
    required this.layout,
    required this.onUpdate,
    required this.onSkip,
  });

  final _UpdateLayout layout;
  final VoidCallback onUpdate;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final install = _UpdatePrimaryAction(
      layout: layout,
      label: 'Install update',
      autoFocus: true,
      onTap: onUpdate,
    );

    final skip = _UpdateTextAction(
      layout: layout,
      label: 'Skip for now',
      onTap: onSkip,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: ForjaShellColors.borderSubtle),
        SizedBox(height: layout.isTv ? 12 : 16),
        install,
        SizedBox(height: layout.isTv ? 12 : 12),
        Center(child: skip),
      ],
    );
  }
}

/// Scroll region for the release notes with a scrollbar + top fade so the
/// pinned footer reads as a separate layer.
class _ChangelogVersionRail extends StatelessWidget {
  const _ChangelogVersionRail({
    required this.layout,
    required this.changelogs,
    required this.selected,
    required this.onSelect,
  });

  final _UpdateLayout layout;
  final List<VersionChangelog> changelogs;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: ForjaShellColors.borderSubtle),
        ),
      ),
      child: ListView.builder(
        padding: EdgeInsets.only(right: layout.isTv ? 8 : 12),
        itemCount: changelogs.length,
        itemBuilder: (context, index) {
          final version = changelogs[index].version;
          final active = index == selected;
          return Padding(
            padding: EdgeInsets.only(bottom: layout.isTv ? 4 : 6),
            child: ForjaInteractive(
              onTap: () => onSelect(index),
              builder: (hover, pressed) {
                final lit = active || hover || pressed;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: EdgeInsets.symmetric(
                    horizontal: layout.isTv ? 8 : 10,
                    vertical: layout.isTv ? 8 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? ForjaShellColors.brandGreen.withValues(alpha: 0.14)
                        : lit
                        ? ForjaShellColors.surfaceElevated
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: active
                          ? ForjaShellColors.brandGreen.withValues(alpha: 0.45)
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    'v$version',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: layout.isTv ? 12 : 13,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                      color: active
                          ? ForjaShellColors.brandGreen
                          : ForjaShellColors.textSecondary,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _FullChangelogLink extends StatelessWidget {
  const _FullChangelogLink({required this.layout, required this.url});

  final _UpdateLayout layout;
  final String url;

  Future<void> _open() async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ForjaInteractive(
        onTap: _open,
        builder: (hover, pressed) {
          final active = hover || pressed;
          final color = active
              ? ForjaShellColors.brandGreen
              : ForjaShellColors.textSecondary;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'See full changelog on the web',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: layout.metaSize,
                  fontWeight: FontWeight.w600,
                  color: color,
                  decoration: TextDecoration.underline,
                  decorationColor: color,
                ),
              ),
              SizedBox(height: layout.isTv ? 2 : 4),
              Text(
                url,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: (layout.metaSize - 1).clamp(11, 13).toDouble(),
                  color: ForjaShellColors.textSecondary.withValues(alpha: 0.85),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReleaseNotesScroller extends StatefulWidget {
  const _ReleaseNotesScroller({required this.layout, required this.child});

  final _UpdateLayout layout;
  final Widget child;

  @override
  State<_ReleaseNotesScroller> createState() => _ReleaseNotesScrollerState();
}

class _ReleaseNotesScrollerState extends State<_ReleaseNotesScroller> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: !widget.layout.isTv,
      child: SingleChildScrollView(
        controller: _controller,
        padding: EdgeInsets.only(
          right: widget.layout.isTv ? 0 : 10,
          bottom: widget.layout.isTv ? 8 : 12,
        ),
        child: widget.child,
      ),
    );
  }
}

class _ReleaseNoteVersionHeader extends StatelessWidget {
  const _ReleaseNoteVersionHeader({
    required this.title,
    required this.layout,
    required this.isFirst,
  });

  final String title;
  final _UpdateLayout layout;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: isFirst ? 0 : (layout.isTv ? 18 : 26),
        bottom: layout.isTv ? 8 : 10,
      ),
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: layout.versionSize,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: ForjaShellColors.textPrimary,
        ),
      ),
    );
  }
}

class _ReleaseNoteGroupHeader extends StatelessWidget {
  const _ReleaseNoteGroupHeader({
    required this.title,
    required this.layout,
    required this.isFirst,
  });

  final String title;
  final _UpdateLayout layout;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: isFirst ? 0 : (layout.isTv ? 14 : 20),
        bottom: layout.isTv ? 8 : 10,
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: layout.sectionSize + 4,
            decoration: BoxDecoration(
              color: ForjaShellColors.brandGreen,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: layout.isTv ? 8 : 10),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: layout.sectionSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: ForjaShellColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpdatePrimaryAction extends StatelessWidget {
  const _UpdatePrimaryAction({
    required this.layout,
    required this.label,
    required this.onTap,
    this.autoFocus = false,
  });

  final _UpdateLayout layout;
  final String label;
  final VoidCallback onTap;
  final bool autoFocus;

  @override
  Widget build(BuildContext context) {
    return ForjaInteractive(
      onTap: onTap,
      autoFocus: autoFocus,
      builder: (hover, pressed) {
        final active = hover || pressed;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: layout.buttonHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? ForjaShellColors.brandGreen.withValues(alpha: 0.88)
                : ForjaShellColors.brandGreen,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: layout.buttonFontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
              color: AppTheme.bgDark,
            ),
          ),
        );
      },
    );
  }
}

class _UpdateTextAction extends StatelessWidget {
  const _UpdateTextAction({
    required this.layout,
    required this.label,
    required this.onTap,
  });

  final _UpdateLayout layout;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ForjaInteractive(
      onTap: onTap,
      builder: (hover, pressed) {
        final active = hover || pressed;
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: layout.isTv ? 6 : 10,
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: layout.skipFontSize,
              fontWeight: FontWeight.w600,
              color: active
                  ? ForjaShellColors.textPrimary
                  : ForjaShellColors.textSecondary,
              decoration: active ? TextDecoration.underline : null,
              decorationColor: ForjaShellColors.textSecondary,
            ),
          ),
        );
      },
    );
  }
}

class _ReleaseNoteRow extends StatelessWidget {
  const _ReleaseNoteRow({required this.item, required this.layout});

  final _ReleaseNoteItem item;
  final _UpdateLayout layout;

  @override
  Widget build(BuildContext context) {
    if (item.url != null) {
      return Padding(
        padding: EdgeInsets.only(bottom: layout.isTv ? 6 : 8),
        child: _ReleaseNoteLink(
          label: item.text,
          url: item.url!,
          fontSize: layout.bodySize,
        ),
      );
    }

    final leading = item.prefix != null
        ? _ReleaseNoteTag(prefix: item.prefix!, layout: layout)
        : Padding(
            padding: EdgeInsets.only(top: layout.isTv ? 6 : 8),
            child: Container(
              width: layout.isTv ? 5 : 6,
              height: layout.isTv ? 5 : 6,
              decoration: const BoxDecoration(
                color: ForjaShellColors.brandGreen,
                shape: BoxShape.circle,
              ),
            ),
          );

    return Padding(
      padding: EdgeInsets.only(bottom: layout.isTv ? 8 : 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: layout.isTv ? 54 : 68,
            child: Align(alignment: Alignment.topLeft, child: leading),
          ),
          SizedBox(width: layout.isTv ? 8 : 12),
          Expanded(
            child: Text(
              item.text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: layout.bodySize,
                height: 1.5,
                color: ForjaShellColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReleaseNoteTag extends StatelessWidget {
  const _ReleaseNoteTag({required this.prefix, required this.layout});

  final String prefix;
  final _UpdateLayout layout;

  static Color _colorFor(String prefix) {
    switch (prefix.toLowerCase()) {
      case 'add':
        return ForjaShellColors.brandGreen;
      case 'fix':
        return const Color(0xFF60A5FA);
      case 'change':
        return const Color(0xFFFBBF24);
      case 'remove':
        return const Color(0xFFF87171);
      default:
        return ForjaShellColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(prefix);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: layout.isTv ? 6 : 8,
        vertical: layout.isTv ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        prefix.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: (layout.bodySize - 4).clamp(9, 12).toDouble(),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: color,
        ),
      ),
    );
  }
}

class _ReleaseNoteLink extends StatelessWidget {
  const _ReleaseNoteLink({
    required this.label,
    required this.url,
    required this.fontSize,
  });

  final String label;
  final String url;
  final double fontSize;

  Future<void> _open() async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ForjaInteractive(
      onTap: _open,
      builder: (hover, pressed) {
        final active = hover || pressed;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.north_east_rounded,
              size: fontSize + 1,
              color: active
                  ? ForjaShellColors.brandGreen
                  : ForjaShellColors.iconMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: fontSize,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? ForjaShellColors.brandGreen
                      : ForjaShellColors.textPrimary,
                  decoration: TextDecoration.underline,
                  decorationColor: active
                      ? ForjaShellColors.brandGreen
                      : ForjaShellColors.textSecondary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReleaseNoteItem {
  const _ReleaseNoteItem({required this.text, this.url, this.prefix});

  final String text;
  final String? url;

  /// Action prefix parsed from `**Add/Change/Fix/Remove:**` - null for links
  /// and free-form bullets.
  final String? prefix;
}

class _ReleaseNoteSection {
  const _ReleaseNoteSection({
    this.title,
    required this.items,
    this.isVersion = false,
  });

  final String? title;
  final List<_ReleaseNoteItem> items;
  final bool isVersion;
}

abstract final class _ReleaseNotesParser {
  static final _urlPattern = RegExp(r'https?://[^\s)\]]+');
  static final _bulletPattern = RegExp(r'^[-*•]\s+');
  static final _prefixPattern = RegExp(
    r'^\*\*\s*(Add|Change|Fix|Remove)\s*:\s*\*\*\s*',
    caseSensitive: false,
  );

  static List<_ReleaseNoteSection> parseSections(String raw) {
    final sections = <_ReleaseNoteSection>[];
    String? currentTitle;
    var currentIsVersion = false;
    String? pendingVersionTitle;
    var currentItems = <_ReleaseNoteItem>[];

    void flushGroup() {
      if (currentItems.isEmpty) {
        currentTitle = null;
        currentIsVersion = false;
        return;
      }
      sections.add(
        _ReleaseNoteSection(
          title: currentTitle,
          items: List.of(currentItems),
          isVersion: currentIsVersion,
        ),
      );
      currentItems = [];
      currentTitle = null;
      currentIsVersion = false;
    }

    void flushPendingVersion() {
      if (pendingVersionTitle == null) return;
      sections.add(
        _ReleaseNoteSection(
          title: pendingVersionTitle,
          items: const [],
          isVersion: true,
        ),
      );
      pendingVersionTitle = null;
    }

    for (final rawLine in raw.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Multi-version aggregate uses `# X.Y.Z` as version headers.
      if (line.startsWith('# ') && !line.startsWith('##')) {
        flushGroup();
        flushPendingVersion();
        pendingVersionTitle = line.substring(2).trim();
        continue;
      }

      if (line.startsWith('### ')) {
        flushGroup();
        flushPendingVersion();
        currentTitle = line.substring(4).trim();
        currentIsVersion = false;
        continue;
      }

      if (!_bulletPattern.hasMatch(line)) continue;

      flushPendingVersion();
      currentItems.add(_parseBullet(line));
    }

    flushGroup();
    flushPendingVersion();
    return sections;
  }

  static _ReleaseNoteItem _parseBullet(String line) {
    var text = line.replaceFirst(_bulletPattern, '').trim();

    String? prefix;
    final prefixMatch = _prefixPattern.firstMatch(text);
    if (prefixMatch != null) {
      prefix =
          prefixMatch.group(1)![0].toUpperCase() +
          prefixMatch.group(1)!.substring(1).toLowerCase();
      text = text.substring(prefixMatch.end).trim();
    }

    // Drop any remaining inline bold markers.
    text = text.replaceAllMapped(
      RegExp(r'\*\*(.+?)\*\*'),
      (match) => match.group(1) ?? '',
    );

    final urlMatch = _urlPattern.firstMatch(text);
    if (urlMatch == null) {
      return _ReleaseNoteItem(text: text, prefix: prefix);
    }

    final url = urlMatch.group(0)!;
    var label = text.replaceFirst(url, '').trim();
    label = label.replaceAll(RegExp(r'[:：]\s*$'), '').trim();
    if (label.isEmpty) label = 'View full changelog';

    return _ReleaseNoteItem(text: label, url: url);
  }
}

class _DownloadCompleteScreen extends StatelessWidget {
  const _DownloadCompleteScreen({
    required this.filePath,
    required this.dirPath,
    required this.fileName,
  });

  final String filePath;
  final String dirPath;
  final String fileName;

  static Future<void> show({
    required BuildContext context,
    required String filePath,
    required String dirPath,
    required String fileName,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: AppTheme.bgDark,
      barrierLabel: 'Download complete',
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, _, _) => UpdateDialog._scopeHost(
        context,
        _DownloadCompleteScreen(
          filePath: filePath,
          dirPath: dirPath,
          fileName: fileName,
        ),
      ),
      transitionBuilder: (context, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.bgDark,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final layout = _UpdateLayout.of(
              context,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
            );

            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: layout.contentWidth,
                height: constraints.maxHeight,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    layout.padHorizontal > 24 ? 0 : 24,
                    layout.padTop,
                    layout.padHorizontal > 24 ? 0 : 24,
                    layout.padBottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(),
                      Text(
                        'Download\ncomplete',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: layout.headlineSize,
                          fontWeight: FontWeight.w800,
                          height: 1.08,
                          letterSpacing: -0.8,
                          color: ForjaShellColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: layout.isTv ? 14 : 20),
                      SelectableText(
                        filePath,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: layout.isTv ? 10 : 12,
                          height: 1.5,
                          color: ForjaShellColors.brandGreen,
                        ),
                      ),
                      SizedBox(height: layout.isTv ? 16 : 24),
                      Text(
                        Platform.isWindows
                            ? 'Forja must close before you install the update. Choose Install to close Forja and launch the installer, or skip for now.'
                            : Platform.isMacOS
                            ? 'Forja must close before you install the update. Choose Install to close Forja and open the disk image, or skip for now.'
                            : 'Make the file executable, then run it:\n'
                                  'chmod +x "$fileName"\n./$fileName',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: layout.bodySize,
                          height: 1.55,
                          color: ForjaShellColors.textSecondary,
                        ),
                      ),
                      const Spacer(flex: 2),
                      _UpdatePrimaryAction(
                        layout: layout,
                        label: Platform.isMacOS || Platform.isWindows
                            ? 'Install and close Forja'
                            : 'Done',
                        onTap: Platform.isMacOS || Platform.isWindows
                            ? () => _installDesktopUpdate(context)
                            : () => Navigator.of(context).pop(),
                      ),
                      SizedBox(height: layout.isTv ? 8 : 12),
                      Center(
                        child: _UpdateTextAction(
                          layout: layout,
                          label: Platform.isMacOS || Platform.isWindows
                              ? 'Skip for now'
                              : 'Open downloads folder',
                          onTap: Platform.isMacOS || Platform.isWindows
                              ? () => Navigator.of(context).pop()
                              : () async {
                                  if (Platform.isLinux) {
                                    await Process.run('xdg-open', [dirPath]);
                                  }
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                },
                        ),
                      ),
                      SizedBox(height: layout.isTv ? 8 : 12),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _installDesktopUpdate(BuildContext context) async {
    try {
      if (Platform.isMacOS) {
        await Process.start('open', [
          filePath,
        ], mode: ProcessStartMode.detached);
      } else {
        await Process.start(
          filePath,
          const [],
          mode: ProcessStartMode.detached,
        );
      }
      exit(0);
    } catch (error) {
      if (context.mounted) {
        ForjaToast.error('Could not open the update: $error');
      }
    }
  }
}
