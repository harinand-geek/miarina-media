import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/cover_art.dart';
import '../../design/widgets/play_button.dart';
import '../../design/widgets/pressable.dart';
import '../../design/widgets/track_bar.dart';
import '../../engine/media_engine.dart';
import '../../l10n/app_localizations.dart';
import '../common/state_views.dart';
import '../../src/rust/api/focus.dart';
import '../cinema/watch_screen.dart' show speedLabel;
import '../playback/playback.dart';
import '../shortcuts/keymap.dart';
import 'focus_data.dart';
import 'focus_screen.dart';

/// The Focus details of what plays (kind, program, place in it).
final focusCurrentProvider = FutureProvider<FocusItem?>((ref) async {
  final id = ref.watch(queueProvider.select((q) => q.current?.libraryId));
  if (id == null) return null;
  return ref.watch(focusApiProvider).entry(id);
});

/// Text shown in the "Texte" tab: a .txt or .vtt file with the same name
/// next to the media (256 KiB at most). Overridden in tests.
final transcriptLoaderProvider =
    Provider<Future<String?> Function(String mediaPath)>(
      (ref) => loadSidecarTranscript,
    );

Future<String?> loadSidecarTranscript(String mediaPath) async {
  final dot = mediaPath.lastIndexOf('.');
  final base = dot > 0 ? mediaPath.substring(0, dot) : mediaPath;
  for (final ext in const ['txt', 'vtt']) {
    final f = File('$base.$ext');
    try {
      if (!await f.exists() || await f.length() > 256 * 1024) continue;
      final text = utf8.decode(await f.readAsBytes(), allowMalformed: true);
      final shown = ext == 'vtt' ? vttText(text) : text.trim();
      if (shown.isNotEmpty) return shown;
    } on FileSystemException {
      continue;
    }
  }
  return null;
}

/// The words of a WebVTT file, without header, cue numbers and times.
String vttText(String vtt) {
  final lines = <String>[];
  for (final raw in const LineSplitter().convert(vtt)) {
    final line = raw.trim();
    if (line.isEmpty ||
        line.startsWith('WEBVTT') ||
        line.startsWith('NOTE') ||
        line.contains('-->') ||
        RegExp(r'^\d+$').hasMatch(line)) {
      continue;
    }
    lines.add(line.replaceAll(RegExp('<[^>]+>'), ''));
  }
  return lines.join('\n');
}

enum _Tab { bookmarks, chapters, text }

/// W-F2 long-format player: −10 / +30 s, play 72, speed in front and
/// remembered per program, bookmarks (B, diamonds on the bar), estimated
/// end at the chosen speed, chapter timer; tabs Signets / Chapitres / Texte.
class FocusPlayerScreen extends ConsumerStatefulWidget {
  const FocusPlayerScreen({super.key});

  @override
  ConsumerState<FocusPlayerScreen> createState() => _FocusPlayerScreenState();
}

class _FocusPlayerScreenState extends ConsumerState<FocusPlayerScreen> {
  final _focus = FocusNode(debugLabel: 'focus player');
  _Tab _tab = _Tab.bookmarks;
  late final ProviderContainer _container;

  /// The bookmark just added (seconds): highlighted, "Ajouter une note…".
  int? _fresh;

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _focus.dispose();
    final container = _container;
    Future.microtask(() {
      try {
        container.invalidate(listenStateProvider);
      } on StateError {
        // The app is closing.
      }
    });
    super.dispose();
  }

  Future<void> _skip(Duration by) async {
    final engine = ref.read(mediaEngineProvider);
    if (engine == null) return;
    final s = engine.current;
    var to = s.position + by;
    if (to < Duration.zero) to = Duration.zero;
    if (s.duration > Duration.zero && to > s.duration) to = s.duration;
    await engine.seek(to);
  }

  Future<void> _bookmark() async {
    final id = ref.read(queueProvider).current?.libraryId;
    final engine = ref.read(mediaEngineProvider);
    if (id == null || engine == null) return;
    final at = engine.current.position;
    await ref.read(focusMemoryProvider.notifier).addMark(id, at);
    setState(() {
      _tab = _Tab.bookmarks;
      _fresh = at.inSeconds;
    });
  }

  void _leave() => context.canPop() ? context.pop() : context.go(Routes.focus);

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      if (e is KeyDownEvent) _leave();
      return KeyEventResult.handled;
    }
    // Keys from Settings › Shortcuts. Long format: forward is +30 s here.
    final map = ref.read(keymapProvider).value ?? const Keymap();
    switch (map.actionFor(e, const {
      ShortcutScope.focus,
      ShortcutScope.global,
    })) {
      case ShortcutAction.bookmark:
        if (e is KeyDownEvent) _bookmark();
      case ShortcutAction.seekBack:
        _skip(const Duration(seconds: -10));
      case ShortcutAction.seekForward:
        _skip(const Duration(seconds: 30));
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final mobile = MediaQuery.sizeOf(context).width < 720;
    final entry = ref.watch(queueProvider.select((q) => q.current));
    final info = ref.watch(focusCurrentProvider).value;
    final snap = currentSnapshot(ref);
    final memory = ref.watch(focusMemoryProvider).value ?? const FocusMemory();
    final key = entry?.focusKey;
    final rate = snap.speed;
    final marks = entry?.libraryId == null
        ? const <Bookmark>[]
        : memory.marksOf(entry!.libraryId!);

    if (entry == null) {
      return Center(
        child: Text(
          t.nothingPlaying,
          style: MmType.body.copyWith(color: c.muted),
        ),
      );
    }

    final total = snap.duration > Duration.zero
        ? snap.duration
        : entry.duration ?? Duration.zero;
    final overline = info == null
        ? null
        : [
            t.programPosition(kindLabel(t, info.kind), info.number, info.of),
            ?ref
                .watch(focusLibraryProvider)
                .value
                ?.programs
                .where((p) => p.name == info.program)
                .firstOrNull
                ?.artist,
          ].join(' · ').toUpperCase();

    final back = Pressable(
      onTap: _leave,
      semanticLabel: t.back,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorRegular.caretLeft, size: 20, color: c.fgSoft),
          const SizedBox(width: 2),
          Text(
            mobile ? t.tabFocus : t.navPodcasts,
            style: MmType.label.copyWith(fontSize: 13, color: c.fgSoft),
          ),
        ],
      ),
    );

    final heading = Row(
      children: [
        CoverArt(
          size: mobile ? 112 : 168,
          radius: MmRadius.card,
          seed: (entry.album ?? entry.title).hashCode,
          imagePath: entry.artwork,
        ),
        SizedBox(width: mobile ? 16 : 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (overline != null)
                Text(overline, style: MmType.overline.copyWith(color: c.muted)),
              const SizedBox(height: 6),
              Text(
                entry.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: MmType.display.copyWith(
                  fontSize: mobile ? 22 : 30,
                  height: mobile ? 28 / 22 : 36 / 30,
                  color: c.fg,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                [
                  ?entry.album,
                  if (total > Duration.zero) shortDuration(total),
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MmType.bodySm.copyWith(fontSize: 13.5, color: c.muted),
              ),
            ],
          ),
        ),
      ],
    );

    final bar = InterpolatedPosition(
      position: snap.position,
      duration: total,
      playing: snap.isPlaying && !snap.buffering,
      speed: snap.speed,
      builder: (context, position) {
        final ratio = total > Duration.zero
            ? position.inMilliseconds / total.inMilliseconds
            : 0.0;
        final end = DateTime.now().add(leftAt(total, position, rate));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 26,
              child: LayoutBuilder(
                builder: (context, box) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: TrackBar(
                        value: ratio,
                        fillColor: c.coral,
                        height: 26,
                        semanticLabel: t.seek,
                        semanticValue:
                            '${formatClock(position)} / ${formatClock(total)}',
                        step: total > Duration.zero
                            ? 10000 / total.inMilliseconds
                            : 0.05,
                        onChanged: total > Duration.zero ? (_) {} : null,
                        onChangeEnd: total > Duration.zero
                            ? (v) => ref
                                  .read(mediaEngineProvider)
                                  ?.seek(
                                    Duration(
                                      milliseconds: (v * total.inMilliseconds)
                                          .round(),
                                    ),
                                  )
                            : null,
                      ),
                    ),
                    if (total > Duration.zero)
                      for (final b in marks)
                        Positioned(
                          left:
                              box.maxWidth *
                                  (b.at * 1000 / total.inMilliseconds).clamp(
                                    0.0,
                                    1.0,
                                  ) -
                              5,
                          top: 0,
                          child: IgnorePointer(
                            child: Transform.rotate(
                              angle: 0.785398,
                              child: Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: c.fg,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            DefaultTextStyle(
              style: MmType.monoStyle(size: 12.5, color: c.muted),
              child: Row(
                children: [
                  Text(formatClock(position)),
                  Expanded(
                    child: Text(
                      t.estimatedEnd(
                        DateFormat.Hm(
                          Localizations.localeOf(context).toString(),
                        ).format(end),
                        speedLabel(rate),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Text('−${formatClock(total - position)}'),
                ],
              ),
            ),
          ],
        );
      },
    );

    Widget skip(bool back) => Pressable(
      onTap: () => _skip(Duration(seconds: back ? -10 : 30)),
      tooltip: back ? t.replay10 : t.forward30,
      semanticLabel: back ? t.replay10 : t.forward30,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              back
                  ? PhosphorRegular.arrowCounterClockwise
                  : PhosphorRegular.arrowClockwise,
              size: 34,
              color: c.fgSoft,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                back ? '10' : '30',
                style: MmType.captionStrong.copyWith(
                  fontSize: 11,
                  height: 1,
                  color: c.fgSoft,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final speeds = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(t.speed, style: MmType.captionStrong.copyWith(color: c.muted)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: c.sidebar,
            borderRadius: BorderRadius.circular(MmRadius.pill),
            border: Border.all(color: c.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final s in FocusMemory.speeds)
                Pressable(
                  onTap: key == null
                      ? () => ref.read(mediaEngineProvider)?.setSpeed(s)
                      : () => ref
                            .read(focusMemoryProvider.notifier)
                            .setRate(key, s),
                  selected: (rate - s).abs() < 0.01,
                  semanticLabel: '${t.speed} ${speedLabel(s)}',
                  child: Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: (rate - s).abs() < 0.01
                          ? c.surface
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(MmRadius.pill),
                    ),
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        speedLabel(s),
                        style: MmType.monoStyle(
                          size: 12,
                          weight: 700,
                          color: (rate - s).abs() < 0.01 ? c.fg : c.muted,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    final bookmarkButton = Pressable(
      onTap: _bookmark,
      tooltip: t.bookmarkAdd,
      semanticLabel: t.bookmarkAdd,
      child: Container(
        height: 42,
        padding: const EdgeInsets.fromLTRB(12, 0, 16, 0),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(MmRadius.pill),
          border: Border.all(color: c.lineStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorRegular.bookmarkSimple, size: 20, color: c.fg),
            const SizedBox(width: 6),
            Text(t.bookmark, style: MmType.labelStrong.copyWith(color: c.fg)),
            const SizedBox(width: 6),
            Text('B', style: MmType.monoStyle(size: 11, color: c.muted)),
          ],
        ),
      ),
    );

    final transport = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 18,
      runSpacing: 14,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            skip(true),
            const SizedBox(width: 14),
            PlayPauseButton(
              playing: snap.isPlaying,
              size: 72,
              glyphSize: 40,
              onPressed: () => ref.read(queueProvider.notifier).togglePlay(),
              playLabel: t.play,
              pauseLabel: t.pause,
            ),
            const SizedBox(width: 14),
            skip(false),
          ],
        ),
        if (!mobile) Container(width: 1, height: 40, color: c.line),
        speeds,
        bookmarkButton,
      ],
    );

    final timer = ref.watch(sleepTimerProvider);
    final hasChapters = snap.chapters.isNotEmpty;
    final aids = ref.watch(speechAidsProvider).value;
    final aidsCtl = ref.read(speechAidsProvider.notifier);
    final caps = ref.watch(mediaEngineProvider)?.capabilities;
    final chips = Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Chip(
          icon: PhosphorRegular.moon,
          label: hasChapters ? t.sleepEndOfChapter : t.sleepEndOfEpisode,
          active: timer.active,
          onTap: () {
            final ctl = ref.read(sleepTimerProvider.notifier);
            if (timer.active) return ctl.cancel();
            final i = snap.chapterAt();
            if (hasChapters && i + 1 < snap.chapters.length) {
              final until = snap.chapters[i + 1].start - snap.position;
              ctl.after(
                Duration(milliseconds: (until.inMilliseconds / rate).round()),
              );
            } else {
              ctl.atEndOfTrack();
            }
          },
        ),
        if ((caps?.skipSilence ?? false) && aids != null)
          _Chip(
            icon: PhosphorRegular.scissors,
            label: t.skipSilence,
            active: aids.skipSilence,
            onTap: () => aidsCtl.save(
              SpeechAids(
                skipSilence: !aids.skipSilence,
                voiceBoost: aids.voiceBoost,
              ),
            ),
          ),
        if ((caps?.voiceBoost ?? false) && aids != null)
          _Chip(
            icon: PhosphorRegular.userSound,
            label: t.voiceBoost,
            active: aids.voiceBoost,
            onTap: () => aidsCtl.save(
              SpeechAids(
                skipSilence: aids.skipSilence,
                voiceBoost: !aids.voiceBoost,
              ),
            ),
          ),
      ],
    );

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(alignment: Alignment.centerLeft, child: back),
        const SizedBox(height: 22),
        heading,
        const SizedBox(height: 22),
        bar,
        const SizedBox(height: 22),
        transport,
        const SizedBox(height: 22),
        chips,
        const SizedBox(height: 18),
        // W-E3 when the file stopped with an error.
        const Align(
          alignment: Alignment.centerLeft,
          child: PlaybackErrorOverlay(),
        ),
      ],
    );

    final panel = _SidePanel(
      tab: _tab,
      onTab: (tab) => setState(() => _tab = tab),
      snap: snap,
      marks: marks,
      entry: entry,
      fresh: _fresh,
    );

    final content = mobile
        ? ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.paddingOf(context).top + 8,
              16,
              24,
            ),
            children: [
              main,
              const SizedBox(height: 20),
              SizedBox(height: 420, child: panel),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(36, 22, 36, 22),
                  child: main,
                ),
              ),
              Container(
                width: 380,
                decoration: BoxDecoration(
                  color: c.sidebar,
                  border: Border(left: BorderSide(color: c.divider)),
                ),
                child: panel,
              ),
            ],
          );

    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: ColoredBox(color: c.bg, child: content),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final enabled = onTap != null;
    return Pressable(
      onTap: onTap,
      selected: active,
      semanticLabel: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: active ? c.coralSubtle : Colors.transparent,
            borderRadius: BorderRadius.circular(MmRadius.pill),
            border: Border.all(
              color: active ? c.coralChipBorder : c.lineStrong,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: active ? c.coralStrong : c.fgSoft),
              const SizedBox(width: 6),
              Text(
                label,
                style: MmType.label.copyWith(
                  fontSize: 12.5,
                  color: active ? c.coralStrong : c.fgSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidePanel extends ConsumerWidget {
  const _SidePanel({
    required this.tab,
    required this.onTab,
    required this.snap,
    required this.marks,
    required this.entry,
    this.fresh,
  });

  final _Tab tab;
  final ValueChanged<_Tab> onTab;
  final PlaybackSnapshot snap;
  final List<Bookmark> marks;
  final QueueEntry entry;

  /// The bookmark just added (seconds).
  final int? fresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final engine = ref.read(mediaEngineProvider);

    Widget tabButton(_Tab value, String label, {bool future = false}) =>
        Expanded(
          child: Pressable(
            onTap: () => onTab(value),
            selected: tab == value,
            semanticLabel: label,
            child: AnimatedContainer(
              duration: MmMotion.of(context).state,
              height: 32,
              decoration: BoxDecoration(
                color: tab == value ? c.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(MmRadius.pill),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MmType.labelStrong.copyWith(
                        fontSize: 12.5,
                        color: tab == value ? c.fg : c.muted,
                      ),
                    ),
                  ),
                  if (future) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: c.faint),
                      ),
                      child: Text(
                        t.futureBadge,
                        style: MmType.monoStyle(
                          size: 8.5,
                          weight: 700,
                          color: c.muted,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );

    Widget body;
    switch (tab) {
      case _Tab.bookmarks:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: marks.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        t.bookmarksEmpty,
                        style: MmType.bodySm.copyWith(color: c.muted),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (final b in marks)
                          _BookmarkRow(
                            mark: b,
                            fresh: b.at == fresh,
                            chapter: _chapterTitle(snap, b.at),
                            onTap: () => engine?.seek(Duration(seconds: b.at)),
                            onNote: () => editBookmarkNote(
                              context,
                              ref,
                              entry.libraryId!,
                              b,
                            ),
                            onRemove: () => ref
                                .read(focusMemoryProvider.notifier)
                                .removeMark(entry.libraryId!, b.at),
                          ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      t.bookmarksHint,
                      style: MmType.caption.copyWith(color: c.faint),
                    ),
                  ),
                  if (marks.isNotEmpty)
                    Pressable(
                      onTap: () => _export(context, ref),
                      semanticLabel: t.bookmarksExport,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Text(
                          t.bookmarksExport,
                          style: MmType.captionStrong.copyWith(color: c.fg),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      case _Tab.chapters:
        final current = snap.chapterAt();
        body = snap.chapters.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  t.chaptersNone,
                  style: MmType.bodySm.copyWith(color: c.muted),
                ),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (var i = 0; i < snap.chapters.length; i++)
                    Pressable(
                      onTap: () => engine?.seek(snap.chapters[i].start),
                      selected: i == current,
                      semanticLabel:
                          snap.chapters[i].title ?? t.episodeNumber(i + 1),
                      borderRadius: BorderRadius.circular(10),
                      hoverColor: c.cardHover,
                      child: Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: i == current ? c.surface : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 62,
                              child: Text(
                                formatClock(snap.chapters[i].start),
                                style: MmType.monoStyle(
                                  size: 12,
                                  color: c.muted,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                snap.chapters[i].title ??
                                    '${t.chapters} ${i + 1}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MmType.label.copyWith(
                                  fontWeight: i == current
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: i == current ? c.coralStrong : c.fg,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
      case _Tab.text:
        body = _TranscriptView(path: entry.source.uri);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: c.bg,
            borderRadius: BorderRadius.circular(MmRadius.pill),
            border: Border.all(color: c.divider),
          ),
          child: Row(
            children: [
              tabButton(_Tab.bookmarks, t.bookmarks),
              tabButton(_Tab.chapters, t.chapters),
              tabButton(_Tab.text, t.transcript, future: true),
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
  }

  /// "Exporter…": the bookmarks as a text file chosen by the user.
  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final t = L10n.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final uri = entry.source.uri;
    final text = bookmarksText(
      title: entry.title,
      path: uri.isScheme('file') ? uri.toFilePath() : '$uri',
      marks: marks,
      chapterOf: (at) => _chapterTitle(snap, at),
      clock: (at) => formatClock(Duration(seconds: at)),
    );
    try {
      final saved = await ref.read(textSaverProvider)(
        '${entry.title} - ${t.bookmarks}.txt',
        text,
      );
      if (saved != null) {
        messenger?.showSnackBar(
          SnackBar(content: Text(t.bookmarksExported(saved))),
        );
      }
    } catch (_) {
      messenger?.showSnackBar(SnackBar(content: Text(t.bookmarksExportFailed)));
    }
  }

  static String? _chapterTitle(PlaybackSnapshot s, int at) {
    final i = s.chapterAt(Duration(seconds: at));
    return i < 0 ? null : s.chapters[i].title;
  }
}

class _BookmarkRow extends StatelessWidget {
  const _BookmarkRow({
    required this.mark,
    required this.fresh,
    required this.chapter,
    required this.onTap,
    required this.onNote,
    required this.onRemove,
  });

  final Bookmark mark;

  /// Just added: teal, with "Ajouter une note…" (mockup W-F2).
  final bool fresh;
  final String? chapter;
  final VoidCallback onTap;
  final VoidCallback onNote;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final addNote = fresh && mark.note == null;
    return Pressable(
      onTap: onTap,
      semanticLabel: '${t.bookmark} ${formatClock(Duration(seconds: mark.at))}',
      borderRadius: BorderRadius.circular(MmRadius.md),
      hoverColor: fresh ? null : c.cardHover,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
        decoration: BoxDecoration(
          color: fresh ? c.accentSubtle : null,
          borderRadius: BorderRadius.circular(MmRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 62,
              child: Text(
                formatClock(Duration(seconds: mark.at)),
                style: MmType.monoStyle(
                  size: 12.5,
                  weight: 700,
                  color: fresh ? c.accent : c.coralStrong,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chapter ?? t.bookmark,
                    style: MmType.labelStrong.copyWith(color: c.fg),
                  ),
                  if (addNote)
                    Pressable(
                      onTap: onNote,
                      semanticLabel: t.bookmarkAddNote,
                      child: Text(
                        t.bookmarkAddNote,
                        style: MmType.caption.copyWith(
                          fontSize: 12.5,
                          color: c.accent,
                        ),
                      ),
                    )
                  else
                    Text(
                      mark.note ?? t.bookmarkNoNote,
                      style: MmType.caption.copyWith(
                        fontSize: 12.5,
                        color: c.muted,
                      ),
                    ),
                ],
              ),
            ),
            MenuAnchor(
              style: MenuStyle(
                backgroundColor: WidgetStatePropertyAll(c.surface2),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: c.overlayBorder),
                  ),
                ),
              ),
              menuChildren: [
                MenuItemButton(
                  leadingIcon: Icon(
                    PhosphorRegular.notePencil,
                    size: 18,
                    color: c.muted,
                  ),
                  onPressed: onNote,
                  child: Text(
                    mark.note == null ? t.bookmarkAddNote : t.bookmarkEditNote,
                    style: MmType.label.copyWith(color: c.fg),
                  ),
                ),
                MenuItemButton(
                  leadingIcon: Icon(
                    PhosphorRegular.trashSimple,
                    size: 18,
                    color: c.danger,
                  ),
                  onPressed: onRemove,
                  child: Text(
                    t.bookmarkRemove,
                    style: MmType.label.copyWith(color: c.danger),
                  ),
                ),
              ],
              builder: (context, menu, _) => Pressable(
                onTap: () => menu.isOpen ? menu.close() : menu.open(),
                tooltip: t.moreOptions,
                semanticLabel:
                    '${t.moreOptions} ${formatClock(Duration(seconds: mark.at))}',
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(
                    PhosphorRegular.dotsThree,
                    size: 18,
                    color: c.faint,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Ajouter une note…" / "Modifier la note…" of a bookmark.
Future<void> editBookmarkNote(
  BuildContext context,
  WidgetRef ref,
  int id,
  Bookmark mark,
) async {
  final note = await showDialog<String>(
    context: context,
    builder: (_) => _NoteDialog(initial: mark.note ?? '', at: mark.at),
  );
  if (note == null) return;
  await ref.read(focusMemoryProvider.notifier).setNote(id, mark.at, note);
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.initial, required this.at});

  final String initial;
  final int at;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    void save() => Navigator.of(context).pop(_text.text);
    return AlertDialog(
      backgroundColor: c.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MmRadius.sheet),
        side: BorderSide(color: c.overlayBorder),
      ),
      title: Text(
        t.bookmarkNoteTitle(formatClock(Duration(seconds: widget.at))),
        style: MmType.title.copyWith(color: c.fg),
      ),
      content: SizedBox(
        width: 420,
        child: TextField(
          key: const ValueKey('bookmark-note'),
          controller: _text,
          autofocus: true,
          maxLength: FocusMemory.maxNote,
          minLines: 2,
          maxLines: 4,
          style: MmType.body.copyWith(color: c.fg),
          cursorColor: c.accent,
          onSubmitted: (_) => save(),
          decoration: InputDecoration(
            hintText: t.bookmarkAddNote,
            hintStyle: MmType.body.copyWith(color: c.faint),
            filled: true,
            fillColor: c.bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(MmRadius.md),
              borderSide: BorderSide(color: c.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(MmRadius.md),
              borderSide: BorderSide(color: c.accent),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            t.cancel,
            style: MmType.labelStrong.copyWith(color: c.fg),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: c.accent,
            foregroundColor: const Color(0xFF062320),
          ),
          onPressed: save,
          child: Text(t.save, style: MmType.labelStrong),
        ),
      ],
    );
  }
}

/// Saves a text file where the user chooses; its path, or null when the
/// dialog is canceled (tests answer it).
final textSaverProvider =
    Provider<Future<String?> Function(String name, String text)>(
      (_) => (name, text) async {
        final location = await getSaveLocation(
          suggestedName: name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_'),
          acceptedTypeGroups: const [
            XTypeGroup(label: 'Texte', extensions: ['txt']),
          ],
        );
        if (location == null) return null;
        final path = location.path.toLowerCase().endsWith('.txt')
            ? location.path
            : '${location.path}.txt';
        await File(path).writeAsString(text);
        return path;
      },
    );

class _TranscriptView extends ConsumerStatefulWidget {
  const _TranscriptView({required this.path});

  final Uri path;

  @override
  ConsumerState<_TranscriptView> createState() => _TranscriptViewState();
}

class _TranscriptViewState extends ConsumerState<_TranscriptView> {
  // Read once per file, not on every position update.
  Uri? _for;
  late Future<String?> _text;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    if (_for != widget.path) {
      _for = widget.path;
      final load = ref.read(transcriptLoaderProvider);
      _text = widget.path.isScheme('file')
          ? load(widget.path.toFilePath())
          : Future.value(null);
    }
    return FutureBuilder<String?>(
      future: _text,
      builder: (context, snap) {
        final text = snap.data;
        if (text != null) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: SelectableText(
              text,
              style: MmType.body.copyWith(height: 1.6, color: c.fgSoft),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: c.surface2,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PhosphorRegular.textAlignLeft,
                  size: 28,
                  color: c.muted,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                t.transcriptTitle,
                textAlign: TextAlign.center,
                style: MmType.heading.copyWith(fontSize: 15, color: c.fg),
              ),
              const SizedBox(height: 6),
              Text(
                t.transcriptBody,
                textAlign: TextAlign.center,
                style: MmType.bodySm.copyWith(height: 20 / 13, color: c.muted),
              ),
            ],
          ),
        );
      },
    );
  }
}
