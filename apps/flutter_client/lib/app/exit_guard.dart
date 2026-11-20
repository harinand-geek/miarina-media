import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../src/rust/api/app.dart' as rust;
import '../src/rust/frb_generated.dart' show RustLib;

/// What closing the app does in the core (`api/app.rs`), as the Tauri app
/// on exit: the torrent session stops, running downloads flush their
/// partial files. Tests answer it.
final appShutdownProvider = Provider<Future<void> Function()>(
  (_) => () async {
    if (!Platform.isWindows || !RustLib.instance.initialized) return;
    await rust.appShutdown();
  },
);

/// Longest wait before the window closes anyway.
const shutdownLimit = Duration(seconds: 8);

/// Runs [appShutdownProvider] when the window is asked to close (title bar,
/// Alt+F4, taskbar), then lets it close; a stuck core never keeps the
/// window open longer than [shutdownLimit].
class ExitGuard extends ConsumerStatefulWidget {
  const ExitGuard({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ExitGuard> createState() => _ExitGuardState();
}

class _ExitGuardState extends ConsumerState<ExitGuard> {
  late final AppLifecycleListener _listener;
  Future<void>? _closing;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(onExitRequested: _onExit);
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  Future<AppExitResponse> _onExit() async {
    // Asked twice (impatient clicks): one shutdown.
    _closing ??= ref
        .read(appShutdownProvider)()
        .timeout(shutdownLimit, onTimeout: () {});
    try {
      await _closing;
    } catch (_) {
      // Closing never fails.
    }
    return AppExitResponse.exit;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
