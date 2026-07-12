import 'dart:io';

import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/services/app_updater_service.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/forja_logo.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

// Conditional import for Android-only package
import 'package:ota_update/ota_update.dart'
    if (dart.library.html) 'package:ota_update/ota_update_stub.dart';

/// Layout tokens — scaled down on Android TV (10-foot UI).
class _UpdateLayout {
  const _UpdateLayout._({
    required this.isTv,
    required this.contentWidth,
    required this.headlineSize,
    required this.versionSize,
    required this.metaSize,
    required this.bodySize,
    required this.sectionSize,
    required this.logoWidthFactor,
    required this.logoTopGap,
    required this.blockGap,
    required this.dividerBeforeGap,
    required this.dividerAfterGap,
    required this.sectionLabelGap,
    required this.footerGap,
    required this.buttonHeight,
    required this.buttonFontSize,
    required this.skipFontSize,
    required this.downloadPercentSize,
    required this.downloadLogoFactor,
    required this.downloadGapLarge,
    required this.downloadGapSmall,
  });

  final bool isTv;
  final double contentWidth;
  final double headlineSize;
  final double versionSize;
  final double metaSize;
  final double bodySize;
  final double sectionSize;
  final double logoWidthFactor;
  final double logoTopGap;
  final double blockGap;
  final double dividerBeforeGap;
  final double dividerAfterGap;
  final double sectionLabelGap;
  final double footerGap;
  final double buttonHeight;
  final double buttonFontSize;
  final double skipFontSize;
  final double downloadPercentSize;
  final double downloadLogoFactor;
  final double downloadGapLarge;
  final double downloadGapSmall;

  factory _UpdateLayout.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isTv = (ShellScope.maybeOf(context)?.profile ??
            resolveShellProfile(context)) ==
        ShellProfile.tv;
    final isWide = !isTv && size.width > 720;

    if (isTv) {
      final contentWidth = (size.width * 0.44).clamp(280.0, 380.0);
      return _UpdateLayout._(
        isTv: true,
        contentWidth: contentWidth,
        headlineSize: 26,
        versionSize: 18,
        metaSize: 12,
        bodySize: 13,
        sectionSize: 11,
        logoWidthFactor: 0.30,
        logoTopGap: 22,
        blockGap: 10,
        dividerBeforeGap: 16,
        dividerAfterGap: 10,
        sectionLabelGap: 6,
        footerGap: 14,
        buttonHeight: 42,
        buttonFontSize: 14,
        skipFontSize: 13,
        downloadPercentSize: 38,
        downloadLogoFactor: 0.22,
        downloadGapLarge: 28,
        downloadGapSmall: 8,
      );
    }

    return _UpdateLayout._(
      isTv: false,
      contentWidth: isWide ? 520 : size.width - 56,
      headlineSize: size.width > 600 ? 40 : 34,
      versionSize: 22,
      metaSize: 14,
      bodySize: 15,
      sectionSize: 13,
      logoWidthFactor: 0.55,
      logoTopGap: 40,
      blockGap: 14,
      dividerBeforeGap: 24,
      dividerAfterGap: 16,
      sectionLabelGap: 8,
      footerGap: 20,
      buttonHeight: 54,
      buttonFontSize: 16,
      skipFontSize: 15,
      downloadPercentSize: 56,
      downloadLogoFactor: 0.38,
      downloadGapLarge: 48,
      downloadGapSmall: 8,
    );
  }

  double horizontalInset(double screenWidth) {
    if (isTv) {
      return ((screenWidth - contentWidth) / 2).clamp(40.0, screenWidth);
    }
    if (contentWidth >= screenWidth - 56) return 28;
    return (screenWidth - contentWidth) / 2;
  }
}

/// Full-screen update gate — App Store / Play Store style, not a card dialog.
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
      pageBuilder: (dialogContext, _, _) => _scopeHost(
        hostContext,
        UpdateDialog(updateInfo: updateInfo),
      ),
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
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final layout = _UpdateLayout.of(context);
    final horizontalPad = layout.horizontalInset(size.width);

    return Material(
      color: AppTheme.bgDark,
      child: SafeArea(
        child: _isDownloading
            ? LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPad,
                      vertical: layout.isTv ? 24 : 36,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                        maxWidth: layout.contentWidth,
                      ),
                      child: Center(
                        child: _buildDownloadingBody(size, layout),
                      ),
                    ),
                  );
                },
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPad,
                      layout.isTv ? 16 : 24,
                      horizontalPad,
                      padding.bottom > 0 ? 12 : 24,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                        maxWidth: layout.contentWidth,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildOfferBody(size, layout),
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

  Widget _buildOfferBody(Size size, _UpdateLayout layout) {
    final logoWidth = size.width.clamp(280.0, 520.0) * layout.logoWidthFactor;
    final logoHeight = logoWidth / forjaLogoAspectRatio;
    final items = _ReleaseNotesParser.parse(widget.updateInfo.releaseNotes);
    final published = _formatPublishedDate(widget.updateInfo.publishedAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ForjaLogo(
            width: logoWidth,
            height: logoHeight,
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
              blurSigma: logoHeight * 0.08,
              glowSourceSize: logoHeight * 0.7,
            ),
          ),
        ),
        SizedBox(height: layout.logoTopGap),
        Text(
          'A new version\nis ready',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
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
          style: GoogleFonts.inter(
            fontSize: layout.versionSize,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: ForjaShellColors.brandGreen,
          ),
        ),
        SizedBox(height: layout.isTv ? 6 : 10),
        Text(
          'You’re on v${widget.updateInfo.currentVersion}'
          '${published != null ? '  ·  $published' : ''}',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: layout.metaSize,
            height: 1.4,
            color: ForjaShellColors.textSecondary,
          ),
        ),
        if (_platformNotice != null) ...[
          SizedBox(height: layout.isTv ? 8 : 12),
          Text(
            _platformNotice!,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
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
          style: GoogleFonts.inter(
            fontSize: layout.sectionSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: ForjaShellColors.textSecondary,
          ),
        ),
        SizedBox(height: layout.sectionLabelGap),
        if (items.isEmpty)
          Text(
            'No release notes were published for this version.',
            style: GoogleFonts.inter(
              fontSize: layout.bodySize,
              height: 1.6,
              color: ForjaShellColors.textSecondary,
            ),
          )
        else
          ...items.map((item) => _ReleaseNoteRow(item: item, layout: layout)),
      ],
    );
  }

  Widget _buildDownloadingBody(Size size, _UpdateLayout layout) {
    final percent = (_downloadProgress * 100).clamp(0, 100).round();
    final logoWidth =
        size.width.clamp(240.0, 400.0) * layout.downloadLogoFactor;
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
          style: GoogleFonts.inter(
            fontSize: layout.downloadPercentSize,
            fontWeight: FontWeight.w800,
            letterSpacing: -2,
            color: ForjaShellColors.textPrimary,
          ),
        ),
        SizedBox(height: layout.downloadGapSmall),
        Text(
          'Downloading update…',
          style: GoogleFonts.inter(
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
          style: GoogleFonts.inter(
            fontSize: layout.metaSize,
            color: ForjaShellColors.iconMuted,
          ),
        ),
      ],
    );
  }

  String? get _platformNotice {
    if (widget.updateInfo.isIOS) {
      return 'Install opens GitHub in your browser.';
    }
    if (widget.updateInfo.isMacOS) {
      return 'Install opens GitHub in your browser.';
    }
    return null;
  }

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
    } else if (Platform.isWindows || Platform.isLinux) {
      await _downloadAndInstallDesktop();
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

  Future<void> _downloadAndInstallDesktop() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      Directory? downloadsDir;
      try {
        downloadsDir = await getDownloadsDirectory();
      } catch (_) {
        downloadsDir = null;
      }
      final dir = downloadsDir ?? await getTemporaryDirectory();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final extension = Platform.isWindows ? '.exe' : '.AppImage';
      final fileName = 'Forja-${widget.updateInfo.latestVersion}$extension';
      final filePath = path.join(dir.path, fileName);
      final file = File(filePath);

      final request = http.Request('GET', Uri.parse(widget.updateInfo.downloadUrl));
      final response = await request.send();

      final contentLength = response.contentLength ?? 0;
      var downloadedBytes = 0;
      var lastUpdateTime = DateTime.now().millisecondsSinceEpoch;

      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;

        final now = DateTime.now().millisecondsSinceEpoch;
        if (contentLength > 0 &&
            mounted &&
            (now - lastUpdateTime > 100 || downloadedBytes == contentLength)) {
          lastUpdateTime = now;
          setState(() {
            _downloadProgress = downloadedBytes / contentLength;
          });
        }
      }

      await sink.close();

      if (mounted) {
        setState(() => _isDownloading = false);
        await _DownloadCompleteScreen.show(
          context: context,
          filePath: filePath,
          dirPath: dir.path,
          fileName: fileName,
        );
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        ForjaToast.error('Download failed: $e');
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
        install,
        SizedBox(height: layout.isTv ? 12 : 12),
        Center(child: skip),
      ],
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
            style: GoogleFonts.inter(
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
            style: GoogleFonts.inter(
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

    return Padding(
      padding: EdgeInsets.only(bottom: layout.isTv ? 6 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: layout.isTv ? 6 : 8),
            child: Container(
              width: layout.isTv ? 5 : 6,
              height: layout.isTv ? 5 : 6,
              decoration: const BoxDecoration(
                color: ForjaShellColors.brandGreen,
                shape: BoxShape.circle,
              ),
            ),
          ),
          SizedBox(width: layout.isTv ? 10 : 14),
          Expanded(
            child: Text(
              item.text,
              style: GoogleFonts.inter(
                fontSize: layout.bodySize,
                height: 1.55,
                color: ForjaShellColors.textPrimary,
              ),
            ),
          ),
        ],
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
                style: GoogleFonts.inter(
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
  const _ReleaseNoteItem({required this.text, this.url});

  final String text;
  final String? url;
}

abstract final class _ReleaseNotesParser {
  static final _urlPattern = RegExp(r'https?://[^\s)\]]+');

  static List<_ReleaseNoteItem> parse(String raw) {
    final lines = raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return lines.map((line) {
      var text = line.replaceAllMapped(
        RegExp(r'\*\*(.+?)\*\*'),
        (match) => match.group(1) ?? '',
      );
      text = text.replaceFirst(RegExp(r'^[-*•]\s*'), '');

      final urlMatch = _urlPattern.firstMatch(text);
      if (urlMatch == null) {
        return _ReleaseNoteItem(text: text);
      }

      final url = urlMatch.group(0)!;
      var label = text.replaceFirst(url, '').trim();
      label = label.replaceAll(RegExp(r'[:：]\s*$'), '').trim();
      if (label.isEmpty) label = 'View full changelog';

      return _ReleaseNoteItem(text: label, url: url);
    }).toList();
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
    final size = MediaQuery.sizeOf(context);
    final layout = _UpdateLayout.of(context);
    final horizontalPad = layout.horizontalInset(size.width);

    return Material(
      color: AppTheme.bgDark,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPad,
            layout.isTv ? 24 : 36,
            horizontalPad,
            layout.isTv ? 24 : 36,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: layout.contentWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Text(
                  'Download\ncomplete',
                  style: GoogleFonts.inter(
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
                      ? 'Close Forja and run the installer to finish updating.'
                      : 'Make the file executable, then run it:\n'
                          'chmod +x "$fileName"\n./$fileName',
                  style: GoogleFonts.inter(
                    fontSize: layout.bodySize,
                    height: 1.55,
                    color: ForjaShellColors.textSecondary,
                  ),
                ),
                const Spacer(flex: 2),
                _UpdatePrimaryAction(
                  layout: layout,
                  label: 'Done',
                  onTap: () => Navigator.of(context).pop(),
                ),
                SizedBox(height: layout.isTv ? 8 : 12),
                Center(
                  child: _UpdateTextAction(
                    layout: layout,
                    label: 'Open downloads folder',
                    onTap: () async {
                      if (Platform.isWindows) {
                        await Process.run('explorer', ['/select,', filePath]);
                      } else if (Platform.isLinux) {
                        await Process.run('xdg-open', [dirPath]);
                      }
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                ),
                SizedBox(height: layout.isTv ? 8 : 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
