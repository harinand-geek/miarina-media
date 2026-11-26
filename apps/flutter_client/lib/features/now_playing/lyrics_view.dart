import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/pressable.dart';
import '../../design/widgets/track_bar.dart';
import '../../l10n/app_localizations.dart';
import '../playback/playback.dart';
import '../online/online_obtain.dart' show onlineSettingsProvider;
import '../online/online_playback.dart' show onlineResolvingProvider;
import 'lyrics_search.dart' show LyricsActions, LyricsSearchDialog;
import 'online_lyrics.dart';
import 'lyrics.dart';

/// Reads the lyrics of a local file (the .lrc next to it); replaced in tests.
final lyricsLoaderProvider = Provider<Future<Lyrics?> Function(String path)>(
  (ref) => loadSidecarLyrics,
);

/// Lyrics of the current entry: the .lrc file with the same name next to
/// it, else those kept or found online (decision 0011, lot 7) for music.
final currentLyricsProvider = FutureProvider<Lyrics?>((ref) async {
  final entry = ref.watch(queueProvider.select((q) => q.current));
  if (entry == null) return null;
  // Chosen or imported by the user for this entry just now.
  final chosen = ref.watch(chosenLyricsProvider);
  if (chosen.lyrics != null && identical(chosen.entry, entry)) {
    return chosen.lyrics;
  }
  final uri = entry.source.uri;
  if (uri.isScheme('file')) {
    final side = await ref.read(lyricsLoaderProvider)(uri.toFilePath());
    if (side != null) return side;
  }
  // Music only: not films, podcasts or courses; an online clip is a song.
  if ((entry.isVideo && entry.onlineId == null) || entry.focusKey != null) {
    return null;
  }
  // An online track's uploaded subtitles come with its stream: once found.
  if (entry.onlineId != null && ref.watch(onlineResolvingProvider)) {
    return null;
  }
  final online = ref.watch(
    onlineSettingsProvider.select((s) => s.value?.onlineLyrics ?? true),
  );
  try {
    return await loadOnlineLyrics(ref, entry, online: online);
  } catch (_) {
    return null;
  }
});

/// Synchronised lyrics (W-M3, A-03): current line in full white, sung lines
/// at 32 %, the next ones at 50 %; a click seeks to the line.
class LyricsView extends ConsumerStatefulWidget {
  const LyricsView({
    super.key,
    this.fontSize = 26,
    this.padding = const EdgeInsets.fromLTRB(18, 18, 18, 0),
  });

  final double fontSize;
  final EdgeInsets padding;

  @override
  ConsumerState<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView> {
  final _scroll = ScrollController();
  final _keys = <int, GlobalKey>{};
  int _shown = -2;

  // Rebuilt only when the sung line changes, not on every frame.
  Lyrics? _builtFor;
  int _builtIndex = -2;
  Widget? _built;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Theme or text scale changed: the memoised list must be rebuilt.
    _built = null;
  }

  void _follow(int index) {
    if (index == _shown) return;
    _shown = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[index < 0 ? 0 : index]?.currentContext;
      if (ctx == null || !_scroll.hasClients) return;
      final motion = MmMotion.of(context);
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.3,
        duration: motion.reduced
            ? Duration.zero
            : const Duration(milliseconds: 420),
        curve: MmMotion.standard,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final lyrics = ref.watch(currentLyricsProvider);
    final snap = currentSnapshot(ref);
    return lyrics.when(
      loading: () => const SizedBox.expand(),
      error: (_, _) => _none(c, t),
      data: (l) {
        if (l == null) return _none(c, t);
        if (!l.synced) return _plain(l, c);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: InterpolatedPosition(
                position: snap.position,
                duration: snap.duration,
                playing: snap.isPlaying && !snap.buffering,
                speed: snap.speed,
                builder: (context, position) {
                  final current = l.indexAt(position);
                  _follow(current);
                  if (identical(_builtFor, l) &&
                      _builtIndex == current &&
                      _built != null) {
                    return _built!;
                  }
                  _builtFor = l;
                  _builtIndex = current;
                  return _built = ShaderMask(
                    shaderCallback: (r) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x00FFFFFF),
                        Color(0xFFFFFFFF),
                        Color(0xFFFFFFFF),
                        Color(0x00FFFFFF),
                      ],
                      stops: [0, 0.08, 0.86, 1],
                    ).createShader(r),
                    blendMode: BlendMode.dstIn,
                    child: ListView.builder(
                      controller: _scroll,
                      padding: widget.padding.copyWith(bottom: 160),
                      itemCount: l.lines.length,
                      itemBuilder: (context, i) {
                        final line = l.lines[i];
                        final alpha = i == current
                            ? 1.0
                            : (i < current ? 0.32 : 0.5);
                        return Pressable(
                          key: _keys.putIfAbsent(i, GlobalKey.new),
                          onTap: () =>
                              ref.read(mediaEngineProvider)?.seek(line.time),
                          semanticLabel: line.text,
                          pressScale: 0.99,
                          borderRadius: BorderRadius.circular(MmRadius.md),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: AnimatedDefaultTextStyle(
                              duration: MmMotion.of(context).screen,
                              curve: MmMotion.standard,
                              style: MmType.display.copyWith(
                                fontSize: widget.fontSize,
                                height: 1.25,
                                color: c.fg.withValues(alpha: alpha),
                              ),
                              child: Text(line.text),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            _footer(l, c, t, t.lyricsHint(l.source ?? '')),
          ],
        );
      },
    );
  }

  /// Plain lyrics (Tononkira): the whole text to scroll, nothing timed.
  Widget _plain(Lyrics l, MmColors c) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: ListView.builder(
          padding: widget.padding.copyWith(bottom: 48),
          itemCount: l.lines.length,
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(
              l.lines[i].text,
              style: MmType.display.copyWith(
                fontSize: widget.fontSize * 0.72,
                height: 1.35,
                color: c.fg.withValues(alpha: 0.86),
              ),
            ),
          ),
        ),
      ),
      _footer(l, c, L10n.of(context), l.source ?? ''),
    ],
  );

  /// Where the lyrics come from; kept ones can be replaced or deleted.
  Widget _footer(Lyrics l, MmColors c, L10n t, String text) {
    final entry = ref.read(queueProvider).current;
    final editable = l.kept && entry != null;
    if (l.source == null && !editable) return const SizedBox.shrink();
    Widget button(IconData icon, String label, VoidCallback onTap) => Pressable(
      onTap: onTap,
      semanticLabel: label,
      tooltip: label,
      borderRadius: BorderRadius.circular(MmRadius.pill),
      hoverColor: c.cardHover,
      child: SizedBox(
        width: 32,
        height: 32,
        child: Icon(icon, size: 17, color: c.muted),
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(18, editable ? 2 : 8, 10, editable ? 6 : 14),
      child: Row(
        children: [
          Icon(PhosphorRegular.fileText, size: 15, color: c.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l.source == null ? '' : text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MmType.caption.copyWith(color: c.muted),
            ),
          ),
          if (editable) ...[
            button(
              PhosphorRegular.magnifyingGlass,
              t.lyricsSearchOther,
              () => showDialog<void>(
                context: context,
                builder: (_) => LyricsSearchDialog(entry: entry),
              ),
            ),
            button(PhosphorRegular.trash, t.lyricsDelete, () async {
              await forgetLyrics(ref, entry);
              ref.invalidate(currentLyricsProvider);
            }),
          ],
        ],
      ),
    );
  }

  Widget _none(MmColors c, L10n t) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorRegular.quotes, size: 36, color: c.faintIcon),
          const SizedBox(height: 12),
          Text(
            t.lyricsNoneTitle,
            textAlign: TextAlign.center,
            style: MmType.title.copyWith(color: c.fg),
          ),
          // Look them up by hand, on the web, or from a file (music only).
          if (ref.read(queueProvider).current case final entry?
              when !entry.isVideo || entry.onlineId != null) ...[
            const SizedBox(height: 16),
            LyricsActions(entry: entry),
          ],
        ],
      ),
    ),
  );
}
