import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/pressable.dart';
import '../../l10n/app_localizations.dart';
import '../cinema/cinema_widgets.dart' show PillSegment;
import '../now_playing/sound_view.dart' show MmSwitch;
import '../settings/settings_screen.dart' show SettingsGroup, SettingsRow;
import '../shortcuts/keymap.dart';
import '../shortcuts/shortcuts_view.dart' show actionLabel;
import 'capture_data.dart';
import 'screen_tools.dart' show hotkeyOf;

/// Picks the pictures' folder (overridden in tests).
final captureFolderPickerProvider = Provider<Future<String?> Function(String)>(
  (_) =>
      (initial) => getDirectoryPath(initialDirectory: initial),
);

String captureShortcutLabel(L10n t, CaptureShortcut s) => switch (s) {
  CaptureShortcut.region => t.capRegion,
  CaptureShortcut.full => t.capFull,
  CaptureShortcut.record => t.capRecord,
};

/// Réglages › Capture d'écran (design_handoff_outils_pc § 1).
class CaptureSettingsView extends ConsumerStatefulWidget {
  const CaptureSettingsView({super.key});

  @override
  ConsumerState<CaptureSettingsView> createState() =>
      _CaptureSettingsViewState();
}

class _CaptureSettingsViewState extends ConsumerState<CaptureSettingsView> {
  CaptureShortcut? _editing;
  final _listen = FocusNode(debugLabel: 'capture-key');

  @override
  void dispose() {
    _listen.dispose();
    super.dispose();
  }

  void _toast(String text) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
  }

  void _edit(CaptureShortcut? s) {
    setState(() => _editing = s);
    ref.read(captureKeyEditingProvider.notifier).set(s != null);
    if (s != null) _listen.requestFocus();
  }

  String _keys(L10n t, KeySpec k) =>
      k.label(shiftName: t.keyShift, spaceName: t.keySpace);

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    final editing = _editing;
    if (editing == null) return KeyEventResult.ignored;
    if (e is! KeyDownEvent) return KeyEventResult.handled;
    final t = L10n.of(context);
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      _edit(null);
      return KeyEventResult.handled;
    }
    final key = KeySpec.fromEvent(e);
    if (key == null) return KeyEventResult.handled; // A modifier alone.
    if (!(key.ctrl || key.alt || key.shift)) {
      _toast(t.capNeedModifier);
      return KeyEventResult.handled;
    }
    if (hotkeyOf(editing.index, key) == null) {
      _toast(t.capKeyUnsupported);
      return KeyEventResult.handled;
    }
    final settings =
        ref.read(captureSettingsProvider).value ?? const CaptureSettings();
    // Another capture shortcut, or a key of the app's own (W-S3).
    for (final other in CaptureShortcut.values) {
      if (other != editing && settings.keyOf(other) == key) {
        _toast(t.capConflict(_keys(t, key), captureShortcutLabel(t, other)));
        return KeyEventResult.handled;
      }
    }
    final keymap = ref.read(keymapProvider).value ?? const Keymap();
    for (final a in ShortcutAction.values) {
      if (keymap.keyOf(a) == key) {
        _toast(t.capConflict(_keys(t, key), actionLabel(t, a)));
        return KeyEventResult.handled;
      }
    }
    unawaited(
      ref
          .read(captureSettingsProvider.notifier)
          .change((s) => s.withKey(editing, key)),
    );
    _edit(null);
    return KeyEventResult.handled;
  }

  Future<void> _pickFolder(String current) async {
    final dir = await ref.read(captureFolderPickerProvider)(current);
    if (dir == null || dir.isEmpty) return;
    await ref
        .read(captureSettingsProvider.notifier)
        .change((s) => s.copyWith(folder: dir));
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    // A shortcut Windows refused: said once, when it happens.
    ref.listen(captureKeyFailuresProvider, (before, now) {
      final settings = ref.read(captureSettingsProvider).value;
      for (final s in now.difference(before ?? const {})) {
        final k = settings?.keyOf(s);
        if (k != null) _toast(t.capTaken(_keys(t, k)));
      }
    });
    final settings = ref.watch(captureSettingsProvider).value;
    if (settings == null) return const SizedBox.shrink();
    final failures = ref.watch(captureKeyFailuresProvider);
    final folder = captureFolder(settings, ref.watch(captureApiProvider));
    final edit = ref.read(captureSettingsProvider.notifier).change;

    SettingsRow shortcut(CaptureShortcut s, String body) => SettingsRow(
      title: captureShortcutLabel(t, s),
      body: failures.contains(s) ? '$body · ${t.capTakenShort}' : body,
      control: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_editing == s)
            Focus(
              focusNode: _listen,
              onKeyEvent: _onKey,
              child: _Listening(t.capListening),
            )
          else
            _Keycaps(
              settings.keyOf(s) == null
                  ? [t.capNoKey]
                  : _keys(t, settings.keyOf(s)!).split(' '),
              warning: failures.contains(s),
            ),
          const SizedBox(width: 10),
          _SmallButton(
            _editing == s ? t.capCancel : t.capEdit,
            () => _edit(_editing == s ? null : s),
          ),
        ],
      ),
    );

    SettingsRow toggle(
      String title,
      String? body,
      bool value,
      CaptureSettings Function(bool) set,
    ) => SettingsRow(
      title: title,
      body: body,
      control: MmSwitch(
        value: value,
        label: title,
        onChanged: (v) => unawaited(edit((_) => set(v))),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Intro card.
        Container(
          margin: const EdgeInsets.only(top: 2, bottom: 22),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(MmRadius.xl),
            border: Border.all(color: c.line),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.bg,
                  borderRadius: BorderRadius.circular(MmRadius.lg),
                  border: Border.all(color: c.line),
                ),
                child: Icon(
                  PhosphorRegular.selection,
                  size: 20,
                  color: c.accentStrong,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.capIntroTitle,
                      style: MmType.heading.copyWith(fontSize: 15, color: c.fg),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.capIntroBody,
                      style: MmType.caption.copyWith(
                        fontSize: 12.5,
                        color: c.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              _PrimaryButton(
                t.capTry,
                PhosphorRegular.frameCorners,
                () => unawaited(ref.read(captureProvider.notifier).region()),
              ),
            ],
          ),
        ),
        SettingsGroup(
          rows: [
            shortcut(CaptureShortcut.region, t.capRegionDesc),
            shortcut(CaptureShortcut.full, t.capFullDesc),
            shortcut(CaptureShortcut.record, t.capRecordDesc),
          ],
        ),
        SettingsGroup(
          rows: [
            SettingsRow(
              title: t.capFormat,
              body: t.capFormatDesc,
              control: PillSegment<String>(
                values: const [
                  ('png', 'PNG'),
                  ('jpg', 'JPG'),
                  ('webp', 'WebP'),
                ],
                selected: settings.format,
                onChanged: (v) => unawaited(edit((s) => s.copyWith(format: v))),
              ),
            ),
            SettingsRow(
              title: t.capDelay,
              body: t.capDelayDesc,
              control: PillSegment<int>(
                values: [
                  for (final d in captureDelays)
                    (d, d == 0 ? t.capDelayNone : t.capDelaySecs(d)),
                ],
                selected: settings.delay,
                onChanged: (v) => unawaited(edit((s) => s.copyWith(delay: v))),
              ),
            ),
            SettingsRow(
              title: t.capSaveTo,
              control: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Text(
                      folder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MmType.monoStyle(
                        size: 12.5,
                        weight: 500,
                        color: c.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _SmallButton(t.capOpenFolder, () async {
                    await Directory(folder).create(recursive: true);
                    await Process.run('explorer.exe', [folder]);
                  }),
                  const SizedBox(width: 8),
                  _SmallButton(t.capEdit, () => _pickFolder(folder)),
                ],
              ),
            ),
            toggle(
              t.capCopySetting,
              t.capCopySettingDesc,
              settings.copy,
              (v) => settings.copyWith(copy: v),
            ),
            toggle(
              t.capPreview,
              t.capPreviewDesc,
              settings.preview,
              (v) => settings.copyWith(preview: v),
            ),
            toggle(
              t.capSound,
              null,
              settings.sound,
              (v) => settings.copyWith(sound: v),
            ),
            toggle(
              t.capCursor,
              null,
              settings.cursor,
              (v) => settings.copyWith(cursor: v),
            ),
          ],
        ),
      ],
    );
  }
}

class _Keycaps extends StatelessWidget {
  const _Keycaps(this.keys, {this.warning = false});

  final List<String> keys;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Container(
            constraints: const BoxConstraints(minWidth: 30),
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: c.surface2,
              borderRadius: BorderRadius.circular(MmRadius.sm),
              border: Border.all(color: warning ? c.warning : c.lineStrong),
              // The keycap's thicker bottom edge.
              boxShadow: [
                BoxShadow(
                  color: warning ? c.warning : c.lineStrong,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              widthFactor: 1,
              child: Text(
                keys[i],
                style: MmType.monoStyle(
                  size: 12,
                  weight: 600,
                  color: warning ? c.warning : c.fg,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Listening extends StatelessWidget {
  const _Listening(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(MmRadius.sm),
        border: Border.all(color: c.accent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorRegular.keyboard, size: 16, color: c.chipText),
          const SizedBox(width: 8),
          Text(
            text,
            style: MmType.caption.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: c.chipText,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(MmRadius.sm),
          border: Border.all(color: c.lineStrong),
        ),
        child: Center(
          widthFactor: 1,
          child: Text(
            label,
            style: MmType.labelStrong.copyWith(fontSize: 13, color: c.fg),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton(this.label, this.icon, this.onTap);

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    const ink = Color(0xFF062320);
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      pressScale: 0.98,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: c.accent,
          borderRadius: BorderRadius.circular(MmRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: ink),
            const SizedBox(width: 8),
            Text(
              label,
              style: MmType.labelStrong.copyWith(fontSize: 13.5, color: ink),
            ),
          ],
        ),
      ),
    );
  }
}
