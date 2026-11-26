import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/pressable.dart';
import '../../design/widgets/track_bar.dart' show formatClock;
import '../../l10n/app_localizations.dart';
import '../browser/browser_data.dart' show browserProvider;
import '../playback/playback.dart';
import 'lyrics.dart';
import 'online_lyrics.dart';

/// When a track has no lyrics (owner's request, like Lark Player): look
/// them up by hand, on the web, or from a .lrc file.

/// The actions under « Pas de paroles pour ce titre ».
class LyricsActions extends ConsumerWidget {
  const LyricsActions({super.key, required this.entry});

  final QueueEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    Widget action(IconData icon, String label, VoidCallback onTap) => Pressable(
      onTap: onTap,
      semanticLabel: label,
      borderRadius: BorderRadius.circular(MmRadius.pill),
      hoverColor: c.cardHover,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(MmRadius.pill),
          border: Border.all(color: c.lineStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: c.fgSoft),
            const SizedBox(width: 8),
            // A narrow phone panel: shortened rather than overflowing.
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MmType.labelStrong.copyWith(
                  fontSize: 13,
                  color: c.fgSoft,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        action(
          PhosphorRegular.magnifyingGlass,
          t.lyricsSearch,
          () => showDialog<void>(
            context: context,
            builder: (_) => LyricsSearchDialog(entry: entry),
          ),
        ),
        action(
          PhosphorRegular.globe,
          t.lyricsSearchWeb,
          () => searchLyricsOnWeb(context, ref, entry),
        ),
        action(
          PhosphorRegular.fileArrowUp,
          t.lyricsImport,
          () => importLyricsFile(context, ref, entry),
        ),
      ],
    );
  }
}

/// The artist to show and search with: none when the app only knows it as
/// « Artiste inconnu ».
String? knownArtist(L10n t, QueueEntry entry) {
  final a = entry.subtitle?.trim();
  return a == null || a.isEmpty || a == t.unknownArtist ? null : a;
}

/// « Chercher sur le web »: a Google search for the song's lyrics, in the
/// app's browser.
Future<void> searchLyricsOnWeb(
  BuildContext context,
  WidgetRef ref,
  QueueEntry entry,
) async {
  final t = L10n.of(context);
  final words = [entry.title, ?knownArtist(t, entry), t.lyricsWebWord];
  final url = Uri.https('www.google.com', '/search', {
    'q': words.join(' '),
  }).toString();
  final browser = ref.read(browserProvider.notifier);
  context.go(Routes.getBrowser);
  // The browser starts with its screen: the tab opens once it is up.
  for (var i = 0; i < 50; i++) {
    final available = ref.read(browserProvider).available;
    if (available == false) return;
    if (available == true) break;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  browser.tabNew(url);
}

/// « Importer un .lrc »: a lyrics file chosen by the user, kept for the
/// track.
Future<void> importLyricsFile(
  BuildContext context,
  WidgetRef ref,
  QueueEntry entry,
) async {
  final t = L10n.of(context);
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(label: 'LRC', extensions: ['lrc', 'txt']),
    ],
  );
  if (file == null) return;
  if (await file.length() > maxLrcBytes) return;
  var text = utf8.decode(await file.readAsBytes(), allowMalformed: true);
  if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) text = text.substring(1);
  final synced = parseLrc(text) != null;
  if (!synced && parsePlainLyrics(text) == null) {
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(t.lyricsImportEmpty),
        ),
      );
    }
    return;
  }
  await keepLyrics(ref, entry, text, label: file.name, synced: synced);
}

/// Title and artist to edit, then the results to choose from: LRCLIB's
/// (synchronised) and Tononkira's (Malagasy songs, plain text).
class LyricsSearchDialog extends ConsumerStatefulWidget {
  const LyricsSearchDialog({super.key, required this.entry});

  final QueueEntry entry;

  @override
  ConsumerState<LyricsSearchDialog> createState() => _LyricsSearchState();
}

class _LyricsSearchState extends ConsumerState<LyricsSearchDialog> {
  late final _title = TextEditingController(text: widget.entry.title);
  late final _artist = TextEditingController(
    text: knownArtist(L10n.of(context), widget.entry) ?? '',
  );
  List<LyricsOption>? _results;
  bool _busy = false;
  String? _picking;

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final title = _title.text.trim();
    if (title.isEmpty || _busy) return;
    setState(() => _busy = true);
    final artist = _artist.text.trim();
    final results = await ref
        .read(onlineLyricsApiProvider)
        .search(title, artist.isEmpty ? null : artist, widget.entry.duration)
        .catchError((Object _) => <LyricsOption>[]);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _results = results;
    });
  }

  Future<void> _pick(LyricsOption o) async {
    final nav = Navigator.of(context);
    var body = o.lrc;
    final synced = body != null;
    if (body == null && o.url != null) {
      setState(() => _picking = o.url);
      body = await ref
          .read(onlineLyricsApiProvider)
          .fetch(o.url!)
          .catchError((Object _) => null);
      if (!mounted) return;
      setState(() => _picking = null);
    }
    if (body == null) return;
    await keepLyrics(
      ref,
      widget.entry,
      body,
      label: sourceLabel(o.source),
      synced: synced,
    );
    nav.pop();
  }

  InputDecoration _field(MmColors c, String label) => InputDecoration(
    labelText: label,
    isDense: true,
    filled: true,
    fillColor: c.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(MmRadius.md),
      borderSide: BorderSide(color: c.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(MmRadius.md),
      borderSide: BorderSide(color: c.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(MmRadius.md),
      borderSide: BorderSide(color: c.accent),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final results = _results;
    return AlertDialog(
      backgroundColor: c.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MmRadius.sheet),
        side: BorderSide(color: c.overlayBorder),
      ),
      title: Text(t.lyricsSearch, style: MmType.title.copyWith(color: c.fg)),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              style: MmType.body.copyWith(color: c.fg),
              cursorColor: c.accent,
              decoration: _field(c, t.lyricsFieldTitle),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _artist,
              style: MmType.body.copyWith(color: c.fg),
              cursorColor: c.accent,
              decoration: _field(c, t.lyricsFieldArtist),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 12),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (results != null && results.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  t.lyricsNoResult,
                  textAlign: TextAlign.center,
                  style: MmType.bodySm.copyWith(color: c.muted),
                ),
              )
            else if (results != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final o in results)
                      Pressable(
                        onTap: _picking == null ? () => _pick(o) : null,
                        semanticLabel: o.track,
                        borderRadius: BorderRadius.circular(MmRadius.md),
                        hoverColor: c.cardHover,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 7,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      o.track,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: MmType.labelStrong.copyWith(
                                        color: c.fg,
                                      ),
                                    ),
                                    Text(
                                      [
                                        ?o.artist,
                                        sourceLabel(o.source),
                                        o.lrc != null
                                            ? t.lyricsSynced
                                            : t.lyricsPlain,
                                      ].join(' · '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: MmType.caption.copyWith(
                                        color: c.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_picking == o.url && o.url != null)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              else if (o.duration case final d?)
                                Text(
                                  formatClock(d),
                                  style: MmType.monoStyle(
                                    size: 11.5,
                                    color: c.muted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
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
          onPressed: _busy ? null : _search,
          child: Text(t.lyricsSearchGo, style: MmType.labelStrong),
        ),
      ],
    );
  }
}
