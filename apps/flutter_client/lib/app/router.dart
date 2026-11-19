import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../design/tokens.dart';
import '../features/common/coming_soon.dart';
import '../features/home/listen_home_screen.dart';
import '../features/library/albums_screen.dart';
import '../features/library/group_screen.dart';
import '../features/library/library_data.dart';
import '../features/library/tracks_screen.dart';
import '../features/now_playing/mobile_player.dart';
import '../features/now_playing/now_playing_screen.dart';
import '../features/shell/desktop_shell.dart';
import '../features/shell/mobile_shell.dart';

/// Route paths, one per screen ID of the handoff (Handoff §05).
abstract final class Routes {
  static const listenHome = '/listen';
  static const albums = '/listen/music/albums';
  static const album = '/listen/music/albums/album';
  static const artists = '/listen/music/artists';
  static const artist = '/listen/music/artists/artist';
  static const tracks = '/listen/music/tracks';
  static const playlists = '/listen/music/playlists';
  static const favorites = '/listen/music/favorites';
  static const cinema = '/listen/cinema';
  static const personalVideos = '/listen/cinema/personal';
  static const focus = '/listen/focus';
  static const audiobooks = '/listen/focus/books';
  static const get = '/get';
  static const settings = '/settings';
  static const now = '/now';
  static const player = '/player';
}

/// Windows gets the sidebar shell, Android the tab shell (tablets included:
/// they get a navigation rail in a later lot). Overridden in tests.
final desktopShellProvider = Provider<bool>((ref) => !Platform.isAndroid);

// Development hook for automated screenshots (no input injection): the
// screen to start on, e.g. --dart-define=MM_START_ROUTE=/now?tab=queue.
const _startRoute = String.fromEnvironment('MM_START_ROUTE');

/// First screen: the Listen home (handoff D1). Overridden in tests.
final initialRouteProvider = Provider<String>(
  (ref) => _startRoute.isEmpty ? Routes.listenHome : _startRoute,
);

final routerProvider = Provider<GoRouter>((ref) {
  final desktop = ref.watch(desktopShellProvider);
  GoRoute screen(String path, Widget Function() build) => GoRoute(
    path: path,
    pageBuilder: (context, state) =>
        _ScreenPage(key: state.pageKey, child: build()),
  );
  return GoRouter(
    initialLocation: ref.watch(initialRouteProvider),
    routes: [
      // A-03, above the tab shell.
      GoRoute(
        path: Routes.player,
        pageBuilder: (context, state) => PlayerPage(key: state.pageKey),
      ),
      ShellRoute(
        builder: (context, state, child) => desktop
            ? DesktopShell(location: state.uri.path, child: child)
            : MobileShell(location: state.uri.path, child: child),
        routes: [
          screen(Routes.listenHome, () => const ListenHomeScreen()),
          screen(
            Routes.albums,
            () => const GroupsScreen(kind: GroupKind.album),
          ),
          screen(
            Routes.artists,
            () => const GroupsScreen(kind: GroupKind.artist),
          ),
          GoRoute(
            path: Routes.album,
            pageBuilder: (context, state) => _ScreenPage(
              key: state.pageKey,
              child: GroupScreen(
                kind: GroupKind.album,
                name: state.uri.queryParameters['name'] ?? '',
              ),
            ),
          ),
          GoRoute(
            path: Routes.artist,
            pageBuilder: (context, state) => _ScreenPage(
              key: state.pageKey,
              child: GroupScreen(
                kind: GroupKind.artist,
                name: state.uri.queryParameters['name'] ?? '',
              ),
            ),
          ),
          screen(Routes.tracks, () => const TracksScreen()),
          GoRoute(
            path: Routes.now,
            pageBuilder: (context, state) => _ScreenPage(
              key: state.pageKey,
              child: NowPlayingScreen(
                tab:
                    NowTab.values
                        .asNameMap()[state.uri.queryParameters['tab']] ??
                    NowTab.lyrics,
              ),
            ),
          ),
          screen(Routes.playlists, () => const ComingSoon(screenId: 'W-M5')),
          screen(Routes.favorites, () => const ComingSoon(screenId: 'W-M1c')),
          screen(Routes.cinema, () => const ComingSoon(screenId: 'W-C1')),
          screen(
            Routes.personalVideos,
            () => const ComingSoon(screenId: 'W-C1'),
          ),
          screen(Routes.focus, () => const ComingSoon(screenId: 'W-F1')),
          screen(Routes.audiobooks, () => const ComingSoon(screenId: 'W-F1')),
          screen(Routes.get, () => const ComingSoon(screenId: 'Obtenir')),
          screen(Routes.settings, () => const ComingSoon(screenId: 'W-S1')),
        ],
      ),
    ],
  );
});

/// Screen change (handoff §03): content fades in and rises 8 px in 160 ms;
/// navigation chrome does not move. Reduced motion: 120 ms fade only.
class _ScreenPage extends CustomTransitionPage<void> {
  _ScreenPage({super.key, required super.child})
    : super(
        transitionDuration: const Duration(milliseconds: 160),
        reverseTransitionDuration: const Duration(milliseconds: 120),
        transitionsBuilder: (context, animation, secondary, child) {
          final motion = MmMotion.of(context);
          final curved = CurvedAnimation(
            parent: animation,
            curve: MmMotion.standard,
          );
          return FadeTransition(
            opacity: curved,
            child: motion.reduced
                ? child
                : AnimatedBuilder(
                    animation: curved,
                    builder: (context, c) => Transform.translate(
                      offset: Offset(0, (1 - curved.value) * motion.screenRise),
                      child: c,
                    ),
                    child: child,
                  ),
          );
        },
      );
}
