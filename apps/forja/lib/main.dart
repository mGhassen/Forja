import 'package:forja/app/bootstrap.dart';
import 'package:forja/pip_float/pip_float_main.dart' as pip_float;

Future<void> main() => bootstrapForja(title: 'Forja');

/// Secondary-engine PiP float — must live in this library (macOS FlutterEngine API).
@pragma('vm:entry-point')
Future<void> pipFloatMain() => pip_float.pipFloatMain();
