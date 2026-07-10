import 'package:flutter/material.dart';
import 'package:forja/shared/design/src/shell_input_policy.dart';
import 'package:forja/shared/design/src/shell_metrics.dart';
import 'package:forja/shared/design/src/shell_platform.dart';
import 'package:forja/shared/design/src/shell_profile.dart';

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
  static Widget rehost(BuildContext hostContext, Widget child) {
    final scope = of(hostContext);
    return ShellScope(
      profile: scope.profile,
      config: scope.config,
      child: child,
    );
  }

  @override
  bool updateShouldNotify(ShellScope oldWidget) =>
      profile != oldWidget.profile || config != oldWidget.config;
}

/// Builds [ShellScope] from [resolveShellProfile].
class ShellScopeBuilder extends StatelessWidget {
  const ShellScopeBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, ShellProfile profile) builder;

  @override
  Widget build(BuildContext context) {
    final profile = resolveShellProfile(context);
    return ShellScope(
      profile: profile,
      config: shellPlatformConfigFor(profile),
      child: Builder(builder: (context) => builder(context, profile)),
    );
  }
}
