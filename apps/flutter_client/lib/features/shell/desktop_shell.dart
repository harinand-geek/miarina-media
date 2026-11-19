import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../design/tokens.dart';
import '../cinema/watch_screen.dart';
import '../now_playing/now_playing_screen.dart';
import 'playback_bar.dart';
import 'sidebar.dart';
import 'title_bar.dart';

/// Windows shell: title bar, sidebar, content, playback bar. Only the
/// content changes between screens; the playback session is shared.
class DesktopShell extends ConsumerWidget {
  const DesktopShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  /// Keeps the screens (and the video player) mounted when full screen
  /// takes the shell chrome away.
  static final _content = GlobalKey(debugLabel: 'shell content');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    if (location != Routes.now) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(lastLocationProvider.notifier).set(location),
      );
    }
    final collapsed = MediaQuery.sizeOf(context).width < 1280;
    final watching = location == Routes.watch;
    // W-C4: the full-screen player alone, the window in full screen.
    final content = KeyedSubtree(key: _content, child: child);
    if (watching && ref.watch(videoFullscreenProvider)) {
      return Scaffold(backgroundColor: c.video, body: content);
    }
    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          TitleBar(sideWidth: collapsed ? 64 : 232),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Sidebar(location: location, collapsed: collapsed),
                Expanded(child: ClipRect(child: content)),
              ],
            ),
          ),
          // W-C3 has its own controls under the picture.
          if (!watching) const PlaybackBar(),
        ],
      ),
    );
  }
}
