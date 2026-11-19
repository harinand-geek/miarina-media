import 'package:material_ui/material_ui.dart';

import '../../design/tokens.dart';
import 'playback_bar.dart';
import 'sidebar.dart';
import 'title_bar.dart';

/// Windows shell: title bar, sidebar, content, playback bar. Only the
/// content changes between screens; the playback session is shared.
class DesktopShell extends StatelessWidget {
  const DesktopShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final collapsed = MediaQuery.sizeOf(context).width < 1280;
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
                Expanded(child: ClipRect(child: child)),
              ],
            ),
          ),
          const PlaybackBar(),
        ],
      ),
    );
  }
}
