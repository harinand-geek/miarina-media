import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../playback/settings_store.dart';

/// Where a shortcut works: everywhere, in the video player, in the Focus
/// player. Two shortcuts conflict when they share a key and their scopes
/// overlap (global overlaps everything).
enum ShortcutScope { global, video, focus }

/// Every keyboard shortcut of W-S3, with its default key.
enum ShortcutAction {
  playPause(ShortcutScope.global),
  previous(ShortcutScope.global),
  next(ShortcutScope.global),
  seekBack(ShortcutScope.global),
  seekForward(ShortcutScope.global),
  volumeUp(ShortcutScope.global),
  volumeDown(ShortcutScope.global),
  mute(ShortcutScope.global),
  search(ShortcutScope.global),
  back(ShortcutScope.global),
  forward(ShortcutScope.global),
  toggleSidebar(ShortcutScope.global),
  nowPlaying(ShortcutScope.global),
  fullscreen(ShortcutScope.video),
  subtitles(ShortcutScope.video),
  audioTrack(ShortcutScope.video),
  frameStep(ShortcutScope.video),
  bookmark(ShortcutScope.focus),
  lyrics(ShortcutScope.global),
  miniPlayer(ShortcutScope.global),
  speedDown(ShortcutScope.global),
  speedUp(ShortcutScope.global);

  const ShortcutAction(this.scope);

  final ShortcutScope scope;

  /// False for an action whose feature is not built yet (P1): listed, its
  /// key reserved, not changeable. Every action works now (the mini player, W-M4, was the last one);
  /// such an action would return false here.
  bool get available => true;
}

/// A key with its modifiers.
@immutable
class KeySpec {
  const KeySpec(
    this.key, {
    this.ctrl = false,
    this.alt = false,
    this.shift = false,
  });

  final LogicalKeyboardKey key;
  final bool ctrl;
  final bool alt;
  final bool shift;

  bool get plain => !ctrl && !alt;

  /// Whether [e] (a key down or repeat) is this key with these modifiers.
  bool matches(KeyEvent e) {
    final k = HardwareKeyboard.instance;
    return e.logicalKey == key &&
        k.isControlPressed == ctrl &&
        k.isAltPressed == alt &&
        k.isShiftPressed == shift;
  }

  /// The key of [e] with the modifiers held, or null for a modifier alone.
  static KeySpec? fromEvent(KeyEvent e) {
    if (_modifiers.contains(e.logicalKey)) return null;
    final k = HardwareKeyboard.instance;
    return KeySpec(
      e.logicalKey,
      ctrl: k.isControlPressed,
      alt: k.isAltPressed,
      shift: k.isShiftPressed,
    );
  }

  static final _modifiers = {
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.alt,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.meta,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
  };

  String encode() => [
    if (ctrl) 'ctrl',
    if (alt) 'alt',
    if (shift) 'shift',
    '${key.keyId}',
  ].join('+');

  static KeySpec? decode(String text) {
    final parts = text.split('+');
    final id = int.tryParse(parts.last);
    if (id == null) return null;
    final key = LogicalKeyboardKey.findKeyByKeyId(id);
    if (key == null) return null;
    return KeySpec(
      key,
      ctrl: parts.contains('ctrl'),
      alt: parts.contains('alt'),
      shift: parts.contains('shift'),
    );
  }

  /// "Ctrl Maj P", "←", "Espace" ([shiftName] and [spaceName] localised).
  String label({String shiftName = 'Maj', String spaceName = 'Espace'}) {
    final name = switch (key) {
      LogicalKeyboardKey.arrowLeft => '←',
      LogicalKeyboardKey.arrowRight => '→',
      LogicalKeyboardKey.arrowUp => '↑',
      LogicalKeyboardKey.arrowDown => '↓',
      LogicalKeyboardKey.space => spaceName,
      _ => key.keyLabel.isEmpty ? key.debugName ?? '?' : key.keyLabel,
    };
    return [
      if (ctrl) 'Ctrl',
      if (alt) 'Alt',
      if (shift) shiftName,
      name.length == 1 ? name.toUpperCase() : name,
    ].join(' ');
  }

  @override
  bool operator ==(Object other) =>
      other is KeySpec &&
      other.key == key &&
      other.ctrl == ctrl &&
      other.alt == alt &&
      other.shift == shift;

  @override
  int get hashCode => Object.hash(key, ctrl, alt, shift);
}

const _defaults = <ShortcutAction, KeySpec>{
  ShortcutAction.playPause: KeySpec(LogicalKeyboardKey.space),
  ShortcutAction.previous: KeySpec(LogicalKeyboardKey.arrowLeft, ctrl: true),
  ShortcutAction.next: KeySpec(LogicalKeyboardKey.arrowRight, ctrl: true),
  ShortcutAction.seekBack: KeySpec(LogicalKeyboardKey.arrowLeft),
  ShortcutAction.seekForward: KeySpec(LogicalKeyboardKey.arrowRight),
  ShortcutAction.volumeUp: KeySpec(LogicalKeyboardKey.arrowUp),
  ShortcutAction.volumeDown: KeySpec(LogicalKeyboardKey.arrowDown),
  ShortcutAction.mute: KeySpec(LogicalKeyboardKey.keyM),
  ShortcutAction.search: KeySpec(LogicalKeyboardKey.keyK, ctrl: true),
  ShortcutAction.back: KeySpec(LogicalKeyboardKey.arrowLeft, alt: true),
  ShortcutAction.forward: KeySpec(LogicalKeyboardKey.arrowRight, alt: true),
  ShortcutAction.toggleSidebar: KeySpec(LogicalKeyboardKey.keyB, ctrl: true),
  ShortcutAction.nowPlaying: KeySpec(
    LogicalKeyboardKey.keyP,
    ctrl: true,
    shift: true,
  ),
  ShortcutAction.fullscreen: KeySpec(LogicalKeyboardKey.keyF),
  ShortcutAction.subtitles: KeySpec(LogicalKeyboardKey.keyC),
  ShortcutAction.audioTrack: KeySpec(LogicalKeyboardKey.keyA),
  ShortcutAction.frameStep: KeySpec(LogicalKeyboardKey.period),
  ShortcutAction.bookmark: KeySpec(LogicalKeyboardKey.keyB),
  ShortcutAction.lyrics: KeySpec(LogicalKeyboardKey.keyL, ctrl: true),
  ShortcutAction.miniPlayer: KeySpec(LogicalKeyboardKey.keyM, ctrl: true),
  ShortcutAction.speedDown: KeySpec(LogicalKeyboardKey.bracketLeft),
  ShortcutAction.speedUp: KeySpec(LogicalKeyboardKey.bracketRight),
};

bool overlaps(ShortcutScope a, ShortcutScope b) =>
    a == b || a == ShortcutScope.global || b == ShortcutScope.global;

/// The current keys: defaults, then the user's changes (a key, or none).
@immutable
class Keymap {
  const Keymap([this.changes = const {}]);

  final Map<ShortcutAction, KeySpec?> changes;

  KeySpec? keyOf(ShortcutAction a) =>
      changes.containsKey(a) ? changes[a] : _defaults[a];

  KeySpec? defaultOf(ShortcutAction a) => _defaults[a];

  /// The action [e] triggers among those of [scopes], most specific scope
  /// first (a player's own key wins over a global one).
  ShortcutAction? actionFor(KeyEvent e, Set<ShortcutScope> scopes) {
    ShortcutAction? global;
    for (final a in ShortcutAction.values) {
      if (!a.available || !scopes.contains(a.scope)) continue;
      final k = keyOf(a);
      if (k == null || !k.matches(e)) continue;
      if (a.scope != ShortcutScope.global) return a;
      global ??= a;
    }
    return global;
  }

  /// Another action already using [key] where [action] works.
  ShortcutAction? conflictFor(ShortcutAction action, KeySpec key) {
    for (final a in ShortcutAction.values) {
      if (a == action || !overlaps(a.scope, action.scope)) continue;
      if (keyOf(a) == key) return a;
    }
    return null;
  }

  Keymap withKey(ShortcutAction a, KeySpec? key) {
    final next = {...changes};
    if (key == _defaults[a]) {
      next.remove(a);
    } else {
      next[a] = key;
    }
    return Keymap(next);
  }

  Map<String, String?> toJson() => {
    for (final e in changes.entries) e.key.name: e.value?.encode(),
  };

  static Keymap fromJson(Object? raw) {
    if (raw is! Map) return const Keymap();
    final changes = <ShortcutAction, KeySpec?>{};
    for (final e in raw.entries) {
      final action = ShortcutAction.values.asNameMap()[e.key];
      if (action == null) continue;
      final v = e.value;
      if (v == null) {
        changes[action] = null;
      } else if (v is String) {
        final k = KeySpec.decode(v);
        if (k != null) changes[action] = k;
      }
    }
    return Keymap(changes);
  }
}

final keymapProvider = AsyncNotifierProvider<KeymapController, Keymap>(
  KeymapController.new,
);

class KeymapController extends AsyncNotifier<Keymap> {
  static const storeKey = 'shortcuts';

  @override
  Future<Keymap> build() async =>
      Keymap.fromJson(await ref.read(settingsStoreProvider).read(storeKey));

  Future<void> _save(Keymap next) async {
    state = AsyncData(next);
    await ref.read(settingsStoreProvider).write(storeKey, next.toJson());
  }

  /// Gives [key] to [action]; the action that had it (a conflict the user
  /// confirmed) loses it.
  Future<void> assign(ShortcutAction action, KeySpec? key) async {
    var map = await future;
    final other = key == null ? null : map.conflictFor(action, key);
    if (other != null) map = map.withKey(other, null);
    await _save(map.withKey(action, key));
  }

  Future<void> reset() => _save(const Keymap());
}

/// The keymap now (defaults until the saved one is read).
Keymap keymapOf(Ref ref) => ref.read(keymapProvider).value ?? const Keymap();
