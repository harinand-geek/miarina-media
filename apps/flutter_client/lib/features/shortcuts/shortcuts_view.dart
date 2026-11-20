import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/pressable.dart';
import '../../l10n/app_localizations.dart';
import '../search/search_data.dart' show fold;
import 'keymap.dart';

String actionLabel(L10n t, ShortcutAction a) => switch (a) {
  ShortcutAction.playPause => t.keyPlayPause,
  ShortcutAction.previous => t.keyPrevious,
  ShortcutAction.next => t.keyNext,
  ShortcutAction.seekBack => t.keySeekBack,
  ShortcutAction.seekForward => t.keySeekForward,
  ShortcutAction.volumeUp => t.keyVolumeUp,
  ShortcutAction.volumeDown => t.keyVolumeDown,
  ShortcutAction.mute => t.keyMute,
  ShortcutAction.search => t.keySearch,
  ShortcutAction.back => t.keyBack,
  ShortcutAction.forward => t.keyForward,
  ShortcutAction.toggleSidebar => t.keyToggleSidebar,
  ShortcutAction.nowPlaying => t.keyNowPlaying,
  ShortcutAction.fullscreen => t.keyFullscreen,
  ShortcutAction.subtitles => t.keySubtitles,
  ShortcutAction.audioTrack => t.keyAudioTrack,
  ShortcutAction.frameStep => t.keyFrameStep,
  ShortcutAction.bookmark => t.keyBookmark,
  ShortcutAction.lyrics => t.keyLyrics,
  ShortcutAction.miniPlayer => t.keyMiniPlayer,
  ShortcutAction.speedDown => t.keySpeedDown,
  ShortcutAction.speedUp => t.keySpeedUp,
};

String keyLabel(L10n t, KeySpec? k) => k == null
    ? t.keyNone
    : k.label(shiftName: t.keyShift, spaceName: t.keySpace);

/// W-S3: every shortcut, by context, changeable. A key already used where
/// the shortcut works is reported before anything is saved.
class ShortcutsView extends ConsumerStatefulWidget {
  const ShortcutsView({super.key});

  @override
  ConsumerState<ShortcutsView> createState() => _ShortcutsViewState();
}

class _ShortcutsViewState extends ConsumerState<ShortcutsView> {
  String _filter = '';
  ShortcutAction? _editing;
  ({ShortcutAction action, KeySpec key, ShortcutAction other})? _conflict;

  static const _groups = [
    (
      ShortcutScope.global,
      [
        ShortcutAction.playPause,
        ShortcutAction.previous,
        ShortcutAction.next,
        ShortcutAction.seekBack,
        ShortcutAction.seekForward,
        ShortcutAction.volumeUp,
        ShortcutAction.volumeDown,
        ShortcutAction.mute,
      ],
    ),
    (
      null,
      [
        ShortcutAction.search,
        ShortcutAction.back,
        ShortcutAction.forward,
        ShortcutAction.toggleSidebar,
        ShortcutAction.nowPlaying,
      ],
    ),
    (
      ShortcutScope.video,
      [
        ShortcutAction.fullscreen,
        ShortcutAction.subtitles,
        ShortcutAction.audioTrack,
        ShortcutAction.frameStep,
      ],
    ),
    (
      ShortcutScope.focus,
      [
        ShortcutAction.bookmark,
        ShortcutAction.lyrics,
        ShortcutAction.miniPlayer,
        ShortcutAction.speedDown,
        ShortcutAction.speedUp,
      ],
    ),
  ];

  String _groupTitle(L10n t, int i) => switch (i) {
    0 => t.keysPlayback,
    1 => t.keysNavigation,
    2 => t.keysVideo,
    _ => t.keysFocus,
  };

  KeyEventResult _capture(FocusNode node, KeyEvent e) {
    final action = _editing;
    if (action == null || e is! KeyDownEvent) return KeyEventResult.handled;
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      setState(() => _editing = null);
      return KeyEventResult.handled;
    }
    final key = KeySpec.fromEvent(e);
    if (key == null) return KeyEventResult.handled; // A modifier alone.
    final map = ref.read(keymapProvider).value ?? const Keymap();
    final other = map.conflictFor(action, key);
    setState(() {
      _editing = null;
      if (other != null) {
        _conflict = (action: action, key: key, other: other);
      }
    });
    if (other == null) ref.read(keymapProvider.notifier).assign(action, key);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final map = ref.watch(keymapProvider).value ?? const Keymap();
    final wide = MediaQuery.sizeOf(context).width >= 1100;

    bool shown(ShortcutAction a) =>
        _filter.isEmpty ||
        fold(actionLabel(t, a)).contains(fold(_filter)) ||
        fold(keyLabel(t, map.keyOf(a))).contains(fold(_filter));

    Widget group(int i) {
      final actions = _groups[i].$2.where(shown).toList();
      if (actions.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _groupTitle(t, i).toUpperCase(),
                style: MmType.overline.copyWith(color: c.muted),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: c.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(MmRadius.lg),
                border: Border.all(color: c.divider),
              ),
              child: Column(
                children: [
                  for (var k = 0; k < actions.length; k++) ...[
                    if (k > 0) Divider(height: 1, color: c.divider),
                    _ShortcutRow(
                      action: actions[k],
                      keySpec: map.keyOf(actions[k]),
                      editing: _editing == actions[k],
                      conflict:
                          _conflict?.other == actions[k] ||
                          _conflict?.action == actions[k],
                      onEdit: actions[k].available
                          ? () => setState(() {
                              _conflict = null;
                              _editing = actions[k];
                            })
                          : null,
                      onCapture: _capture,
                      onRemove: () {
                        setState(() => _editing = null);
                        ref
                            .read(keymapProvider.notifier)
                            .assign(actions[k], null);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    final conflict = _conflict;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: TextField(
                  onChanged: (v) => setState(() => _filter = v),
                  style: MmType.bodySm.copyWith(color: c.fg),
                  cursorColor: c.accent,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: t.keysSearch,
                    hintStyle: MmType.bodySm.copyWith(color: c.faint),
                    prefixIcon: Icon(
                      PhosphorRegular.magnifyingGlass,
                      size: 16,
                      color: c.faint,
                    ),
                    filled: true,
                    fillColor: c.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(MmRadius.pill),
                      borderSide: BorderSide(color: c.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(MmRadius.pill),
                      borderSide: BorderSide(color: c.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(MmRadius.pill),
                      borderSide: BorderSide(color: c.accent),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Pressable(
              onTap: map.changes.isEmpty
                  ? null
                  : () {
                      setState(() => _conflict = null);
                      ref.read(keymapProvider.notifier).reset();
                    },
              semanticLabel: t.keysReset,
              child: Opacity(
                opacity: map.changes.isEmpty ? 0.5 : 1,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(MmRadius.pill),
                    border: Border.all(color: c.lineStrong),
                  ),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      t.keysReset,
                      style: MmType.labelStrong.copyWith(
                        fontSize: 13,
                        color: c.fg,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (conflict != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            decoration: BoxDecoration(
              color: c.warningSubtle,
              borderRadius: BorderRadius.circular(MmRadius.md),
              border: Border.all(color: c.warningBorder),
            ),
            child: Row(
              children: [
                Icon(PhosphorRegular.warning, size: 18, color: c.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t.keyConflict(
                      keyLabel(t, conflict.key),
                      actionLabel(t, conflict.other),
                    ),
                    style: MmType.bodySm.copyWith(color: c.fg),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _conflict = null),
                  child: Text(
                    t.cancel,
                    style: MmType.labelStrong.copyWith(color: c.fgSoft),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ref
                        .read(keymapProvider.notifier)
                        .assign(conflict.action, conflict.key);
                    setState(() => _conflict = null);
                  },
                  child: Text(
                    t.keyReplace,
                    style: MmType.labelStrong.copyWith(color: c.warning),
                  ),
                ),
              ],
            ),
          ),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Column(children: [group(0), group(2)])),
              const SizedBox(width: 16),
              Expanded(child: Column(children: [group(1), group(3)])),
            ],
          )
        else
          for (var i = 0; i < _groups.length; i++) group(i),
        Text(t.keysHint, style: MmType.caption.copyWith(color: c.accent)),
      ],
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.action,
    required this.keySpec,
    required this.editing,
    required this.conflict,
    required this.onEdit,
    required this.onCapture,
    required this.onRemove,
  });

  final ShortcutAction action;
  final KeySpec? keySpec;
  final bool editing;
  final bool conflict;
  final VoidCallback? onEdit;
  final FocusOnKeyEventCallback onCapture;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final p1 = !action.available;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: conflict ? c.warningSubtle : c.bg,
        borderRadius: BorderRadius.circular(MmRadius.xs + 1),
        border: Border.all(
          color: editing
              ? c.accent
              : conflict
              ? c.warning
              : c.lineStrong,
        ),
      ),
      child: Text(
        editing ? t.keyPress : keyLabel(t, keySpec),
        style: MmType.monoStyle(
          size: 11.5,
          weight: 700,
          color: editing
              ? c.accent
              : conflict
              ? c.warning
              : keySpec == null
              ? c.faint
              : c.fg,
        ),
      ),
    );
    return Container(
      color: conflict ? c.warningSubtle.withValues(alpha: 0.5) : null,
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      constraints: const BoxConstraints(minHeight: 40),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    actionLabel(t, action),
                    style: MmType.bodySm.copyWith(color: p1 ? c.muted : c.fg),
                  ),
                ),
                if (p1) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: c.warningSubtle,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: c.warningBorder),
                    ),
                    child: Text(
                      'P1',
                      style: MmType.monoStyle(
                        size: 9.5,
                        weight: 700,
                        color: c.warning,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (editing)
            Focus(autofocus: true, onKeyEvent: onCapture, child: chip)
          else
            Pressable(
              onTap: onEdit,
              semanticLabel:
                  '${actionLabel(t, action)} : ${keyLabel(t, keySpec)}',
              child: chip,
            ),
          SizedBox(
            width: 30,
            child: editing && keySpec != null
                ? Pressable(
                    onTap: onRemove,
                    tooltip: t.keyRemove,
                    semanticLabel: t.keyRemove,
                    child: Icon(PhosphorRegular.x, size: 14, color: c.muted),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
