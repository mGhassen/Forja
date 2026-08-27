import 'package:flutter/material.dart';
import 'package:forja/shared/design/src/shell_input_policy.dart';
import 'package:forja/shared/design/src/shell_metrics.dart';
import 'package:forja/shared/design/src/shell_platform.dart';
import 'package:forja/shared/design/src/shell_profile.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';

class ShellScope extends InheritedWidget {
  const ShellScope({
    super.key,
    required this.profile,
    required this.config,
    required super.child,
  });

  final ShellProfile profile;
  final ShellPlatformConfig config;

  ShellMetrics get metrics => config.metrics;
  ShellInputPolicy get inputPolicy => config.inputPolicy;
  ShellChromeKind get chromeKind => config.chromeKind;

  static ShellScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ShellScope>();
    assert(scope != null, 'ShellScope not found in context');
    return scope!;
  }

  static ShellProfile profileOf(BuildContext context) => of(context).profile;

  static ShellMetrics metricsOf(BuildContext context) => of(context).metrics;

  static ShellInputPolicy inputPolicyOf(BuildContext context) =>
      of(context).inputPolicy;

  static ShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellScope>();

  /// Re-provide shell context inside [showDialog] / overlay routes.
  ///
  /// When [hostContext] is already under [ShellScope], that scope is copied.
  /// Root-navigator routes (e.g. anime resolver) may lack an ancestor scope;
  /// fall back to [resolveShellProfile] like [UpdateDialog].
  static Widget rehost(BuildContext hostContext, Widget child) {
    final existing = maybeOf(hostContext);
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
  bool updateShouldNotify(ShellScope oldWidget) =>
      profile != oldWidget.profile || config != oldWidget.config;
}

/// Builds [ShellScope] from [resolveShellProfile].
class ShellScopeBuilder extends StatefulWidget {
  const ShellScopeBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, ShellProfile profile) builder;

  @override
  State<ShellScopeBuilder> createState() => _ShellScopeBuilderState();
}

class _ShellScopeBuilderState extends State<ShellScopeBuilder> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profile = resolveShellProfile(context);
    ShellTvFocusCoordinator.tvBackPolicyEnabled =
        shellPlatformConfigFor(profile).inputPolicy.leanbackOnly;
  }

  @override
  Widget build(BuildContext context) {
    final profile = resolveShellProfile(context);
    final config = shellPlatformConfigFor(profile);
    return ShellScope(
      profile: profile,
      config: config,
      child: Builder(builder: (context) => widget.builder(context, profile)),
    );
  }
}
