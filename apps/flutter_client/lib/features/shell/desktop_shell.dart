import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../design/tokens.dart';
import '../cinema/watch_screen.dart';
import '../shortcuts/global_shortcuts.dart';
import '../now_playing/now_playing_screen.dart';
import 'playback_bar.dart';
import 'sidebar.dart';
import 'title_bar.dart';

/// Windows shell: title bar, sidebar, content, playback bar. Only the
/// content changes between screens; the playback session is shared.
class DesktopShell extends ConsumerWidget {
  const DesktopShell({
    super.key,
    required this.location,
    required this.child,
    this.uri,
  });

  final String location;

  /// Full location with its query (search text, series name…).
  final String? uri;
  final Widget child;

  /// Keeps the screens (and the video player) mounted when full screen
  /// takes the shell chrome away.
  static final _content = GlobalKey(debugLabel: 'shell content');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (location != Routes.now) {
        ref.read(lastLocationProvider.notifier).set(location);
      }
      // Alt ← / Alt → walk these (W-S3).
      ref.read(navHistoryProvider.notifier).visit(uri ?? location);
    });
    final collapsed =
        ref.watch(sidebarCollapsedProvider) ??
        MediaQuery.sizeOf(context).width < 1280;
    final watching = location == Routes.watch;
    final content = KeyedSubtree(key: _content, child: child);
    // Keyboard shortcuts of the whole window (W-S3), Ctrl K included.
    return GlobalShortcuts(
      // W-C4: the full-screen player alone, the window in full screen.
      child: watching && ref.watch(videoFullscreenProvider)
          ? Scaffold(backgroundColor: c.video, body: content)
          : Scaffold(
              backgroundColor: c.bg,
              body: Column(
                children: [
                  TitleBar(sideWidth: collapsed ? 64 : 232, location: location),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Settings brings its own navigation (W-S1…S3).
                        if (!location.startsWith(Routes.settings))
                          Sidebar(location: location, collapsed: collapsed),
                        Expanded(child: ClipRect(child: content)),
                      ],
                    ),
                  ),
                  // W-C3 and W-F2 have their own controls.
                  if (!watching && location != Routes.focusPlayer)
                    const PlaybackBar(),
                ],
              ),
            ),
    );
  }
}
