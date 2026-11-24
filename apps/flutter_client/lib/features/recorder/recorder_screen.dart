import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/pressable.dart';
import '../../engine/media_engine.dart' show MediaSource;
import '../../l10n/app_localizations.dart';
import '../capture/capture_data.dart';
import '../capture/screen_tools.dart';
import '../cinema/cinema_widgets.dart' show PillSegment;
import '../convert/convert_data.dart' show convertPendingProvider;
import '../now_playing/sound_view.dart' show MmSwitch;
import '../playback/playback.dart';
import '../shortcuts/shortcuts_view.dart' show keyLabel;
import 'recorder_data.dart';

/// The screens, for the « Plein écran » card (overridden in tests).
final recorderScreensProvider =
    FutureProvider.autoDispose<List<({Rect rect, bool primary})>>((ref) async {
      final tools = ref.watch(screenToolsProvider);
      return tools == null ? const [] : tools.monitors();
    });

/// Picks the recordings' folder (overridden in tests).
final recorderFolderPickerProvider = Provider<Future<String?> Function(String)>(
  (_) =>
      (initial) => getDirectoryPath(initialDirectory: initial),
);

/// Whether a recording's file is still there (overridden in tests).
final recordingExistsProvider = Provider<bool Function(String)>(
  (_) =>
      (path) => File(path).existsSync(),
);

String clockOf(int ms) {
  final s = ms ~/ 1000;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(s ~/ 3600)}:${two(s ~/ 60 % 60)}:${two(s % 60)}';
}

String _size(int bytes) {
  if (bytes >= 1 << 30) return '${(bytes / (1 << 30)).toStringAsFixed(1)} Go';
  return '${(bytes / (1 << 20)).toStringAsFixed(bytes < 10 << 20 ? 1 : 0)} Mo';
}

/// Outils PC › Enregistrer l'écran (design_handoff_outils_pc § 3).
class RecorderScreen extends ConsumerStatefulWidget {
  const RecorderScreen({super.key});

  @override
  ConsumerState<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends ConsumerState<RecorderScreen> {
  RecorderSettingsController get _settings =>
      ref.read(recorderSettingsProvider.notifier);

  Future<void> _pickWindow() async {
    final t = L10n.of(context);
    final tools = ref.read(screenToolsProvider);
    if (tools == null) return;
    final windows = await tools.windows();
    if (!mounted) return;
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = MmColors.of(ctx);
        return AlertDialog(
          backgroundColor: c.surface,
          title: Text(
            t.recPickWindow,
            style: MmType.title.copyWith(color: c.fg),
          ),
          content: SizedBox(
            width: 480,
            child: windows.isEmpty
                ? Text(
                    t.recNoWindows,
                    style: MmType.body.copyWith(color: c.muted),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final w in windows)
                        Pressable(
                          onTap: () => Navigator.of(ctx).pop(w.title),
                          semanticLabel: w.title,
                          hoverColor: c.cardHover,
                          borderRadius: BorderRadius.circular(MmRadius.sm),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  PhosphorRegular.appWindow,
                                  size: 18,
                                  color: c.muted,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    w.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: MmType.bodySm.copyWith(color: c.fg),
                                  ),
                                ),
                                Text(
                                  '${w.rect.width.round()} × ${w.rect.height.round()}',
                                  style: MmType.monoStyle(
                                    size: 11.5,
                                    color: c.faint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(t.cancel),
            ),
          ],
        );
      },
    );
    if (chosen != null) {
      await _settings.change(
        (s) => s.copyWith(source: 'window', window: chosen),
      );
    }
  }

  Future<void> _pickFolder(String current) async {
    final dir = await ref.read(recorderFolderPickerProvider)(current);
    if (dir == null || dir.isEmpty) return;
    await _settings.change((s) => s.copyWith(folder: dir));
  }

  Future<void> _play(RecentRecording r) async {
    await ref.read(queueProvider.notifier).playAll([
      QueueEntry(
        source: MediaSource.file(r.path),
        title: r.name,
        isVideo: r.format != 'gif',
      ),
    ]);
    if (mounted) context.go(Routes.watch);
  }

  void _convert(RecentRecording r) {
    ref.read(convertPendingProvider.notifier).set([r.path]);
    context.go(Routes.convert);
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    ref.read(recorderProvider.notifier).fileWord = t.recFileWord;
    final settings = ref.watch(recorderSettingsProvider).value;
    final rec = ref.watch(recorderProvider);
    final recents = ref.watch(recentRecordingsProvider).value ?? const [];
    final screens = ref.watch(recorderScreensProvider).value ?? const [];
    final api = ref.watch(recorderApiProvider);
    final recordKey = ref
        .watch(captureSettingsProvider)
        .value
        ?.keyOf(CaptureShortcut.record);
    if (settings == null) return const SizedBox.shrink();
    final s = settings;
    final folder = s.folder ?? api?.defaultDir() ?? '';
    final monitor = screens.isEmpty
        ? null
        : screens[s.monitor.clamp(0, screens.length - 1)].rect;
    final edit = _settings.change;

    Widget sourceCard(
      String value,
      IconData icon,
      String label,
      String desc, {
      Widget? extra,
    }) {
      final on = s.source == value;
      return Expanded(
        child: Pressable(
          onTap: () {
            if (value == 'window' && (s.window == null || on)) {
              unawaited(_pickWindow());
              return;
            }
            unawaited(edit((x) => x.copyWith(source: value)));
          },
          selected: on,
          semanticLabel: label,
          borderRadius: BorderRadius.circular(MmRadius.xl),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: on ? c.selected : c.surface,
              borderRadius: BorderRadius.circular(MmRadius.xl),
              border: Border.all(color: on ? c.chipBorder : c.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                        icon,
                        size: 20,
                        color: on ? c.accentStrong : c.muted,
                      ),
                    ),
                    const Spacer(),
                    _RadioDot(on: on),
                  ],
                ),
                const SizedBox(height: 10),
                Text(label, style: MmType.heading.copyWith(color: c.fg)),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: MmType.caption.copyWith(
                    fontSize: 12.5,
                    height: 18 / 12.5,
                    color: c.muted,
                  ),
                ),
                ?extra,
              ],
            ),
          ),
        ),
      );
    }

    Widget line(String label, Widget control, {String? desc}) => Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: MmType.label.copyWith(color: c.fg)),
                if (desc != null)
                  Text(desc, style: MmType.caption.copyWith(color: c.muted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          control,
        ],
      ),
    );

    Widget card(String title, List<Widget> lines) => Container(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(MmRadius.xl),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              title.toUpperCase(),
              style: MmType.overline.copyWith(color: c.faint),
            ),
          ),
          ...lines,
        ],
      ),
    );

    Widget toggle(
      String label,
      String desc,
      bool value,
      RecorderSettings Function(bool) set,
    ) => line(
      label,
      MmSwitch(
        value: value,
        label: label,
        onChanged: rec.busy ? null : (v) => unawaited(edit((_) => set(v))),
      ),
      desc: desc,
    );

    final summary = [
      s.format.toUpperCase(),
      '${s.fps} ${t.recFpsUnit}',
      if (s.format == 'gif')
        t.recSumNoSound
      else
        [
          s.systemAudio ? t.recSumSystem : t.recSumNoSystem,
          if (s.mic) t.recSumMic,
        ].join(' + '),
    ].join(' · ');

    final recording =
        rec.phase == RecPhase.recording || rec.phase == RecPhase.paused;
    return ListView(
      padding: const EdgeInsets.fromLTRB(48, 32, 48, 32),
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t.recNav, style: MmType.titleLg.copyWith(color: c.fg)),
                const SizedBox(height: 4),
                Text(
                  t.recSubtitle,
                  style: MmType.bodySm.copyWith(color: c.muted),
                ),
                const SizedBox(height: 20),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      sourceCard(
                        'screen',
                        PhosphorRegular.monitor,
                        t.recScreen,
                        t.recScreenDesc(
                          s.monitor.clamp(
                                0,
                                screens.isEmpty ? 0 : screens.length - 1,
                              ) +
                              1,
                          monitor?.width.round() ?? 0,
                          monitor?.height.round() ?? 0,
                        ),
                        extra: screens.length > 1
                            ? Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: PillSegment<int>(
                                  values: [
                                    for (var i = 0; i < screens.length; i++)
                                      (i, t.recScreenN(i + 1)),
                                  ],
                                  selected: s.monitor.clamp(
                                    0,
                                    screens.length - 1,
                                  ),
                                  onChanged: (v) => unawaited(
                                    edit(
                                      (x) => x.copyWith(
                                        source: 'screen',
                                        monitor: v,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      sourceCard(
                        'window',
                        PhosphorRegular.appWindow,
                        t.recWindow,
                        s.window ?? t.recWindowDesc,
                        extra: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: _SmallButton(t.recPickWindow, _pickWindow),
                        ),
                      ),
                      const SizedBox(width: 10),
                      sourceCard(
                        'region',
                        PhosphorRegular.frameCorners,
                        t.recRegion,
                        s.region == null
                            ? t.recRegionDesc
                            : t.recRegionSize(
                                s.region!.width.round(),
                                s.region!.height.round(),
                              ),
                        extra: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: _SmallButton(t.recDraw, () async {
                            await edit((x) => x.copyWith(source: 'region'));
                            await ref.read(captureProvider.notifier).region();
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _TwoCards(
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 320),
                      child: card(t.recVideo, [
                        line(
                          t.recFormat,
                          PillSegment<String>(
                            values: const [
                              ('mp4', 'MP4'),
                              ('mkv', 'MKV'),
                              ('webm', 'WebM'),
                              ('gif', 'GIF'),
                            ],
                            selected: s.format,
                            onChanged: (v) =>
                                unawaited(edit((x) => x.copyWith(format: v))),
                          ),
                        ),
                        line(
                          t.recFps,
                          PillSegment<int>(
                            values: [for (final f in recorderFps) (f, '$f')],
                            selected: s.fps,
                            onChanged: (v) =>
                                unawaited(edit((x) => x.copyWith(fps: v))),
                          ),
                        ),
                        line(
                          t.recQuality,
                          PillSegment<String>(
                            values: [
                              ('medium', t.recQMedium),
                              ('high', t.recQHigh),
                              ('original', t.recQOriginal),
                            ],
                            selected: s.quality,
                            onChanged: (v) =>
                                unawaited(edit((x) => x.copyWith(quality: v))),
                          ),
                        ),
                        line(
                          t.recFolder,
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 200,
                                ),
                                child: Text(
                                  folder,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: MmType.monoStyle(
                                    size: 12,
                                    color: c.muted,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _SmallButton(
                                t.capEdit,
                                () => _pickFolder(folder),
                              ),
                            ],
                          ),
                        ),
                      ]),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 320),
                      child: card(t.recSoundOptions, [
                        toggle(
                          t.recSystemAudio,
                          t.recSystemAudioDesc,
                          s.systemAudio,
                          (v) => s.copyWith(systemAudio: v),
                        ),
                        toggle(
                          t.recMic,
                          t.recMicDesc,
                          s.mic,
                          (v) => s.copyWith(mic: v),
                        ),
                        toggle(
                          t.recCursor,
                          t.recCursorDesc,
                          s.cursor,
                          (v) => s.copyWith(cursor: v),
                        ),
                        toggle(
                          t.recCountdown,
                          t.recCountdownDesc,
                          s.countdown,
                          (v) => s.copyWith(countdown: v),
                        ),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Launch bar.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(MmRadius.xl),
                    border: Border.all(color: c.line),
                  ),
                  child: Row(
                    children: [
                      _LaunchButton(
                        recording: recording,
                        label: recording
                            ? t.recStopAt(clockOf(rec.elapsedMs))
                            : t.recStart,
                        onTap: api == null || rec.phase == RecPhase.finalizing
                            ? null
                            : () => unawaited(
                                ref.read(recorderProvider.notifier).toggle(),
                              ),
                      ),
                      const SizedBox(width: 16),
                      if (recordKey != null) ...[
                        Text(
                          t.recOrPress,
                          style: MmType.caption.copyWith(
                            fontSize: 12.5,
                            color: c.muted,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _Kbd(keyLabel(t, recordKey)),
                        const SizedBox(width: 6),
                        Text(
                          t.recAnywhere,
                          style: MmType.caption.copyWith(
                            fontSize: 12.5,
                            color: c.muted,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Flexible(
                        child: Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MmType.monoStyle(size: 12, color: c.faint),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  t.recRecent,
                  style: MmType.heading.copyWith(fontSize: 15, color: c.fg),
                ),
                const SizedBox(height: 10),
                if (recents.isEmpty)
                  Text(
                    t.recEmpty,
                    style: MmType.bodySm.copyWith(color: c.muted),
                  )
                else
                  for (final r in recents)
                    _RecentRow(
                      recording: r,
                      there: ref.watch(recordingExistsProvider)(r.path),
                      onPlay: () => unawaited(_play(r)),
                      onConvert: () => _convert(r),
                      onFolder: () =>
                          Process.run('explorer.exe', ['/select,${r.path}']),
                      onRemove: () => unawaited(
                        ref
                            .read(recentRecordingsProvider.notifier)
                            .remove(r.path),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Side by side when there is room, else one above the other.
class _TwoCards extends StatelessWidget {
  const _TwoCards({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => box.maxWidth >= 660
        ? IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: children[0]),
                const SizedBox(width: 10),
                Expanded(child: children[1]),
              ],
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [children[0], const SizedBox(height: 10), children[1]],
          ),
  );
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: on ? c.accent : c.lineStrong, width: 1.5),
      ),
      child: on
          ? Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: c.accent,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}

class _Kbd extends StatelessWidget {
  const _Kbd(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(MmRadius.xs + 1),
        border: Border.all(color: c.lineStrong),
      ),
      child: Text(
        text,
        style: MmType.monoStyle(size: 11.5, weight: 600, color: c.fg),
      ),
    );
  }
}

class _LaunchButton extends StatelessWidget {
  const _LaunchButton({
    required this.recording,
    required this.label,
    required this.onTap,
  });

  final bool recording;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    const ink = Color(0xFF062320);
    final fg = recording ? Colors.white : ink;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      pressScale: 0.98,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: recording ? c.danger : c.accent,
            borderRadius: BorderRadius.circular(MmRadius.sm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                recording ? PhosphorFill.stop : PhosphorFill.record,
                size: 20,
                color: recording ? Colors.white : const Color(0xFFC8423B),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: MmType.labelStrong.copyWith(fontSize: 14, color: fg),
              ),
            ],
          ),
        ),
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
        height: 32,
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
            style: MmType.labelStrong.copyWith(fontSize: 12.5, color: c.fg),
          ),
        ),
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({
    required this.recording,
    required this.there,
    required this.onPlay,
    required this.onConvert,
    required this.onFolder,
    required this.onRemove,
  });

  final RecentRecording recording;
  final bool there;
  final VoidCallback onPlay;
  final VoidCallback onConvert;
  final VoidCallback onFolder;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final r = recording;
    Widget action(IconData icon, String label, VoidCallback? onTap) =>
        Pressable(
          onTap: onTap,
          semanticLabel: label,
          tooltip: label,
          hoverColor: c.cardHover,
          borderRadius: BorderRadius.circular(MmRadius.sm),
          child: Opacity(
            opacity: onTap == null ? 0.4 : 1,
            child: SizedBox(
              width: 34,
              height: 34,
              child: Icon(icon, size: 18, color: c.fgSoft),
            ),
          ),
        );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(MmRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 40.5,
            decoration: BoxDecoration(
              color: c.hatchA,
              borderRadius: BorderRadius.circular(MmRadius.md),
            ),
            child: Icon(PhosphorRegular.filmStrip, size: 20, color: c.faint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MmType.labelStrong.copyWith(color: c.fg),
                ),
                Text(
                  r.format.toUpperCase(),
                  style: MmType.monoStyle(size: 11.5, color: c.muted),
                ),
              ],
            ),
          ),
          Icon(
            there ? PhosphorFill.checkCircle : PhosphorRegular.warningCircle,
            size: 16,
            color: there ? c.accent : c.warning,
          ),
          const SizedBox(width: 6),
          Text(
            there ? t.recSaved : t.recMissing,
            style: MmType.caption.copyWith(color: there ? c.fgSoft : c.warning),
          ),
          const SizedBox(width: 10),
          Text(
            '${clockOf((r.seconds * 1000).round())} · ${_size(r.size)}',
            style: MmType.monoStyle(size: 11.5, color: c.muted),
          ),
          const SizedBox(width: 12),
          action(PhosphorRegular.play, t.recPlay, there ? onPlay : null),
          action(
            PhosphorRegular.arrowsClockwise,
            t.recConvert,
            there ? onConvert : null,
          ),
          action(
            PhosphorRegular.folderOpen,
            t.recShowFolder,
            there ? onFolder : null,
          ),
          action(PhosphorRegular.x, t.recRemove, onRemove),
        ],
      ),
    );
  }
}
