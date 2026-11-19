import 'package:flutter/widgets.dart';

import 'app/launch_args.dart';
import 'engine/engine_factory.dart';
import 'poc/poc_app.dart';
import 'src/rust/frb_generated.dart';

// POC measurement hook: Android has no command line, so a test build can name
// the file to open with --dart-define=POC_OPEN=... (and POC_SUB=...).
const _pocOpen = String.fromEnvironment('POC_OPEN');
const _pocSub = String.fromEnvironment('POC_SUB');

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  initializeEngines();
  final launch = LaunchArgs.parse([
    ...args,
    if (_pocOpen.isNotEmpty) _pocOpen,
    if (_pocSub.isNotEmpty) '--sub=$_pocSub',
  ]);
  runApp(PocApp(launchArgs: launch));
}
