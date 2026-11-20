import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../focus/focus_data.dart';
import '../mini/mini_player.dart' show miniPlayerProvider;
import '../playback/playback.dart';
import '../shell/title_bar.dart' show searchFocusProvider;
import 'keymap.dart';

/// Volume to come back to after mute (shared by the bar and the M key).
final muteProvider = NotifierProvider<MuteController, double>(
  MuteController.new,
);

class MuteController extends Notifier<double> {
  @override
  double build() => 1;

  Future<void> toggle() async {
    final engine = ref.read(mediaEngineProvider);
    if (engine == null) return;
    final volume = engine.current.volume;
    if (volume <= 0.001) {
      await engine.setVolume(state <= 0.001 ? 1 : state);
    } else {
      state = volume;
      await engine.setVolume(0);
    }
  }
}

/// Screens visited, for Alt ← / Alt → (the window has no browser history).
@immutable
class NavHistory {
  const NavHistory({this.stack = const [], this.index = -1});

  final List<String> stack;
  final int index;
}

final navHistoryProvider = NotifierProvider<NavHistoryController, NavHistory>(
  NavHistoryController.new,
);

class NavHistoryController extends Notifier<NavHistory> {
  String? _moving;

  @override
  NavHistory build() => const NavHistory();

  void visit(String location) {
    if (location == _moving) {
      _moving = null;
      return;
    }
    final s = state;
    if (s.index >= 0 && s.stack[s.index] == location) return;
    final stack = [...s.stack.take(s.index + 1), location];
    final trimmed = stack.length > 50
        ? stack.sublist(stack.length - 50)
        : stack;
    state = NavHistory(stack: trimmed, index: trimmed.length - 1);
  }

  String? back() => _move(-1);
  String? forward() => _move(1);

  String? _move(int by) {
    final s = state;
    final i = s.index + by;
    if (i < 0 || i >= s.stack.length) return null;
    state = NavHistory(stack: s.stack, index: i);
    return _moving = s.stack[i];
  }
}

/// Manual sidebar state (Ctrl B); null follows the window width.
final sidebarCollapsedProvider = NotifierProvider<SidebarCollapsed, bool?>(
  SidebarCollapsed.new,
);

class SidebarCollapsed extends Notifier<bool?> {
  @override
  bool? build() => null;

  void set(bool value) => state = value;
}

const _speedSteps = [0.5, 0.75, 0.8, 1.0, 1.25, 1.5, 1.75, 2.0];

/// Keyboard shortcuts of the whole window (W-S3, global scope). Players
/// handle their own keys first; plain keys are left to text fields.
class GlobalShortcuts extends ConsumerWidget {
  const GlobalShortcuts({super.key, required this.child});

  final Widget child;

  static bool typing() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.widget is EditableText ||
        ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read the saved keys at once, not on the first key press.
    ref.watch(keymapProvider);
    return Focus(
      autofocus: true,
      onKeyEvent: (node, e) {
        if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        final map = ref.read(keymapProvider).value ?? const Keymap();
        final action = map.actionFor(e, const {ShortcutScope.global});
        if (action == null) return KeyEventResult.ignored;
        if (map.keyOf(action)!.plain && typing()) return KeyEventResult.ignored;
        const repeating = {
          ShortcutAction.seekBack,
          ShortcutAction.seekForward,
          ShortcutAction.volumeUp,
          ShortcutAction.volumeDown,
        };
        if (e is KeyRepeatEvent && !repeating.contains(action)) {
          return KeyEventResult.handled;
        }
        run(context, ref, action);
        return KeyEventResult.handled;
      },
      child: child,
    );
  }

  static void run(BuildContext context, WidgetRef ref, ShortcutAction a) {
    final engine = ref.read(mediaEngineProvider);
    final queue = ref.read(queueProvider.notifier);
    final router = GoRouter.of(context);
    Future<void> seekBy(int seconds) async {
      if (engine == null) return;
      final s = engine.current;
      var to = s.position + Duration(seconds: seconds);
      if (to < Duration.zero) to = Duration.zero;
      if (s.duration > Duration.zero && to > s.duration) to = s.duration;
      await engine.seek(to);
    }

    Future<void> speed(int direction) async {
      if (engine == null) return;
      final now = engine.current.speed;
      final steps = direction > 0
          ? _speedSteps.where((s) => s > now + 0.001)
          : _speedSteps.reversed.where((s) => s < now - 0.001);
      final next = steps.firstOrNull;
      if (next == null) return;
      final key = ref.read(queueProvider).current?.focusKey;
      key == null
          ? await engine.setSpeed(next)
          : await ref.read(focusMemoryProvider.notifier).setRate(key, next);
    }

    switch (a) {
      case ShortcutAction.playPause:
        queue.togglePlay();
      case ShortcutAction.previous:
        queue.previous();
      case ShortcutAction.next:
        queue.next();
      case ShortcutAction.seekBack:
        seekBy(-10);
      case ShortcutAction.seekForward:
        seekBy(10);
      case ShortcutAction.volumeUp:
        if (engine != null) {
          engine.setVolume((engine.current.volume + 0.05).clamp(0.0, 1.0));
        }
      case ShortcutAction.volumeDown:
        if (engine != null) {
          engine.setVolume((engine.current.volume - 0.05).clamp(0.0, 1.0));
        }
      case ShortcutAction.mute:
        ref.read(muteProvider.notifier).toggle();
      case ShortcutAction.search:
        ref.read(searchFocusProvider).requestFocus();
      case ShortcutAction.back:
        final to = ref.read(navHistoryProvider.notifier).back();
        if (to != null) router.go(to);
      case ShortcutAction.forward:
        final to = ref.read(navHistoryProvider.notifier).forward();
        if (to != null) router.go(to);
      case ShortcutAction.toggleSidebar:
        final auto = MediaQuery.sizeOf(context).width < 1280;
        ref
            .read(sidebarCollapsedProvider.notifier)
            .set(!(ref.read(sidebarCollapsedProvider) ?? auto));
      case ShortcutAction.nowPlaying:
        final current = ref.read(queueProvider).current;
        router.go(
          current?.isVideo ?? false
              ? Routes.watch
              : current?.focusKey != null
              ? Routes.focusPlayer
              : Routes.now,
        );
      case ShortcutAction.lyrics:
        router.go('${Routes.now}?tab=lyrics');
      case ShortcutAction.speedDown:
        speed(-1);
      case ShortcutAction.speedUp:
        speed(1);
      // Handled by the players, or not built yet.
      case ShortcutAction.fullscreen ||
          ShortcutAction.subtitles ||
          ShortcutAction.audioTrack ||
          ShortcutAction.frameStep ||
          ShortcutAction.bookmark:
        break;
      case ShortcutAction.miniPlayer:
        ref.read(miniPlayerProvider.notifier).toggle();
    }
  }
}
