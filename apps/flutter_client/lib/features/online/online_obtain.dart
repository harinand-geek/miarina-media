import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../design/mm_icons.g.dart';
import '../../engine/media_engine.dart' show PlaybackSnapshot, PlaybackStatus;
import '../../engine/media_engine.dart';
import '../../design/tokens.dart';
import '../../design/widgets/pressable.dart';
import '../../l10n/app_localizations.dart';
import '../../src/rust/api/library.dart' show LibraryItem;
import '../get/get_data.dart';
import '../now_playing/now_playing_shared.dart' show InfoChip;
import '../now_playing/sound_view.dart' show MmSwitch;
import '../playback/playback.dart';
import '../playback/settings_store.dart';
import '../settings/settings_screen.dart'
    show SettingsGroup, SettingsMenu, SettingsRow;
import 'online_data.dart';

/// Obtenir for online results (decision 0011, lot 4): a track heard online
/// joins the library through the usual download queue, and from then on
/// plays from its file, offline included.

const onlineSettingsKey = 'online.settings';

/// [OnlineSettings.format] when the dialog asks every time.
const askFormat = 'ask';

@immutable
class OnlineSettings {
  const OnlineSettings({
    this.autoObtain = false,
    this.format = askFormat,
    this.lastFormat,
  });

  factory OnlineSettings.fromJson(Object? raw) {
    if (raw is! Map) return const OnlineSettings();
    return OnlineSettings(
      autoObtain: raw['autoObtain'] == true,
      format: raw['format'] is String ? raw['format'] as String : askFormat,
      lastFormat: raw['lastFormat'] is String
          ? raw['lastFormat'] as String
          : null,
    );
  }

  /// Obtain the online tracks played to the end (off by default).
  final bool autoObtain;

  /// [askFormat], or the offer key used without asking.
  final String format;

  /// The offer chosen last: preselected in the dialog.
  final String? lastFormat;

  /// The offer automatic obtaining uses.
  String get autoFormat =>
      format != askFormat ? format : (lastFormat ?? 'original');

  OnlineSettings copyWith({
    bool? autoObtain,
    String? format,
    String? lastFormat,
  }) => OnlineSettings(
    autoObtain: autoObtain ?? this.autoObtain,
    format: format ?? this.format,
    lastFormat: lastFormat ?? this.lastFormat,
  );

  Map<String, Object?> toJson() => {
    'autoObtain': autoObtain,
    'format': format,
    'lastFormat': ?lastFormat,
  };
}

class OnlineSettingsNotifier extends AsyncNotifier<OnlineSettings> {
  SettingsStore get _store => ref.read(settingsStoreProvider);

  @override
  Future<OnlineSettings> build() async {
    try {
      return OnlineSettings.fromJson(await _store.read(onlineSettingsKey));
    } catch (_) {
      return const OnlineSettings();
    }
  }

  Future<void> save(OnlineSettings next) async {
    state = AsyncData(next);
    try {
      await _store.write(onlineSettingsKey, next.toJson());
    } catch (_) {
      // Kept for this session only.
    }
  }
}

final onlineSettingsProvider =
    AsyncNotifierProvider<OnlineSettingsNotifier, OnlineSettings>(
      OnlineSettingsNotifier.new,
    );

/// The library entries of the videos already obtained, keyed by video id.
/// The key is the ids joined with commas ([onlineLocalKey]).
final onlineLocalProvider = FutureProvider.autoDispose
    .family<Map<String, LibraryItem>, String>((ref, ids) async {
      // A download that finished may have added one of them.
      ref.watch(
        downloadsProvider.select(
          (s) => s.tasks.values.where((t) => t.state == 'completed').length,
        ),
      );
      final list = [
        for (final id in ids.split(','))
          if (id.isNotEmpty) id,
      ];
      return ref.watch(onlineApiProvider).local(list);
    }, retry: (_, _) => null);

String onlineLocalKey(Iterable<String> videoIds) => videoIds.join(',');

/// The download of a video's page still under way, if any.
DownloadTask? onlineTaskOf(DownloadsState s, String? watchUrl) =>
    watchUrl == null
    ? null
    : s.tasks.values
          .where(
            (t) =>
                t.info.url == watchUrl &&
                (t.running || t.queued || t.state == 'waiting'),
          )
          .firstOrNull;

/// What to obtain: an online result, or the online entry playing.
typedef ObtainTarget = ({String videoId, String title, String? thumbnail});

/// Name of an offer, by its key.
(String, String) offerText(L10n t, OnlineOffer o) => switch (o.key) {
  'original' => (t.onlineFormatOriginal, t.onlineFormatOriginalBody),
  'mp3-320' => (t.onlineFormatMp3High, t.onlineFormatMp3HighBody),
  'mp3-128' => (t.onlineFormatMp3Low, t.onlineFormatMp3LowBody),
  _ => (o.label, ''),
};

/// Queues the download of [target] in [offer]; false when refused.
Future<bool> startObtain(
  DownloadsController downloads,
  ObtainTarget target,
  OnlineOffer offer,
  String watchUrl,
) async {
  try {
    await downloads.start(
      StartRequest(
        url: watchUrl,
        title: target.title,
        isAudio: true,
        engine: 'ytdlp',
        formatId: offer.formatId,
        formatLabel: offer.label,
        extension_: offer.extension_,
        startNow: true,
        // Accepted by the core only from its source thumbnails folder,
        // where online pictures are cached.
        thumbnail: target.thumbnail,
      ),
    );
    return true;
  } catch (_) {
    return false;
  }
}

void _toast(BuildContext context, String text, {SnackBarAction? action}) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(text),
        action: action,
      ),
    );
}

/// « Obtenir… »: the format (asked unless one is always used), then the
/// usual download queue.
Future<void> obtainOnline(
  BuildContext context,
  WidgetRef ref,
  ObtainTarget target,
) async {
  final t = L10n.of(context);
  final api = ref.read(onlineApiProvider);
  final url = api.watchUrl(target.videoId);
  final offers = api.offers();
  if (url == null || offers.isEmpty) {
    _toast(context, t.onlineObtainFailed);
    return;
  }
  final settings = await ref.read(onlineSettingsProvider.future);
  var offer = offers.where((o) => o.key == settings.format).firstOrNull;
  if (offer == null) {
    if (!context.mounted) return;
    final choice = await showDialog<(String, bool)>(
      context: context,
      builder: (_) => ObtainDialog(
        title: target.title,
        offers: offers,
        initial: settings.lastFormat,
      ),
    );
    if (choice == null) return;
    offer = offers.firstWhere((o) => o.key == choice.$1);
    await ref
        .read(onlineSettingsProvider.notifier)
        .save(
          settings.copyWith(
            lastFormat: offer.key,
            format: choice.$2 ? offer.key : null,
          ),
        );
  }
  final ok = await startObtain(
    ref.read(downloadsProvider.notifier),
    target,
    offer,
    url,
  );
  if (!context.mounted) return;
  _toast(
    context,
    ok ? t.onlineObtainStarted(target.title) : t.onlineObtainFailed,
    action: ok
        ? SnackBarAction(
            label: t.onlineSeeDownloads,
            onPressed: () => context.go(Routes.getDownloads),
          )
        : null,
  );
}

/// The format choice: one row per offer, explained; « Toujours utiliser
/// ce format » skips it next time (changeable in Réglages › Lecture).
/// Pops `(offer key, always)`.
class ObtainDialog extends StatefulWidget {
  const ObtainDialog({
    super.key,
    required this.title,
    required this.offers,
    this.initial,
  });

  final String title;
  final List<OnlineOffer> offers;
  final String? initial;

  @override
  State<ObtainDialog> createState() => _ObtainDialogState();
}

class _ObtainDialogState extends State<ObtainDialog> {
  late String _key =
      widget.offers.where((o) => o.key == widget.initial).firstOrNull?.key ??
      widget.offers.first.key;
  bool _always = false;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    return AlertDialog(
      backgroundColor: c.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MmRadius.sheet),
        side: BorderSide(color: c.overlayBorder),
      ),
      title: Text(
        t.onlineObtainTitle(widget.title),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: MmType.title.copyWith(color: c.fg),
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.onlineObtainBody,
              style: MmType.bodySm.copyWith(color: c.muted),
            ),
            const SizedBox(height: 12),
            for (final o in widget.offers)
              _OfferRow(
                offer: o,
                selected: o.key == _key,
                onTap: () => setState(() => _key = o.key),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.onlineFormatAlways,
                    style: MmType.bodySm.copyWith(color: c.fg),
                  ),
                ),
                MmSwitch(
                  value: _always,
                  label: t.onlineFormatAlways,
                  onChanged: (v) => setState(() => _always = v),
                ),
              ],
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
          onPressed: () => Navigator.of(context).pop((_key, _always)),
          child: Text(t.tabGet, style: MmType.labelStrong),
        ),
      ],
    );
  }
}

class _OfferRow extends StatelessWidget {
  const _OfferRow({
    required this.offer,
    required this.selected,
    required this.onTap,
  });

  final OnlineOffer offer;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final (title, body) = offerText(L10n.of(context), offer);
    return Pressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: title,
      borderRadius: BorderRadius.circular(MmRadius.md),
      hoverColor: c.cardHover,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? PhosphorFill.checkCircle : PhosphorRegular.circle,
              size: 20,
              color: selected ? c.accent : c.muted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: MmType.labelStrong.copyWith(color: c.fg)),
                  if (body.isNotEmpty)
                    Text(body, style: MmType.caption.copyWith(color: c.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The end of a result's row: « Hors connexion » once obtained, the
/// download's progress, or the Obtenir button.
class OnlineObtainButton extends ConsumerWidget {
  const OnlineObtainButton({
    super.key,
    required this.track,
    this.local,
    this.picture,
  });

  final OnlineTrack track;

  /// The library entry, when the result was obtained.
  final LibraryItem? local;

  /// The result's picture (local file), kept as the cover.
  final String? picture;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    if (local != null) {
      return Tooltip(
        message: t.onlineOffline,
        child: Semantics(
          label: t.onlineOffline,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(PhosphorFill.checkCircle, size: 18, color: c.accent),
          ),
        ),
      );
    }
    final url = ref.read(onlineApiProvider).watchUrl(track.videoId);
    final task = ref.watch(
      downloadsProvider.select((s) => onlineTaskOf(s, url)),
    );
    if (task != null) {
      return Tooltip(
        message: t.onlineObtaining,
        child: Semantics(
          label: t.onlineObtaining,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: task.percent > 0 ? task.percent : null,
                  color: c.accent,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Pressable(
      onTap: () => obtainOnline(context, ref, (
        videoId: track.videoId,
        title: track.title,
        thumbnail: picture,
      )),
      semanticLabel: '${t.tabGet} ${track.title}',
      tooltip: t.tabGet,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(PhosphorRegular.downloadSimple, size: 18, color: c.muted),
      ),
    );
  }
}

/// Now playing: Obtenir for the online entry playing, or « Hors
/// connexion » once it is in the library.
class OnlineObtainChip extends ConsumerWidget {
  const OnlineObtainChip({super.key, required this.entry});

  final QueueEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = L10n.of(context);
    final id = entry.onlineId;
    if (id == null) return const SizedBox.shrink();
    final local = ref.watch(onlineLocalProvider(id)).value?[id];
    final url = ref.read(onlineApiProvider).watchUrl(id);
    final task = ref.watch(
      downloadsProvider.select((s) => onlineTaskOf(s, url)),
    );
    if (local != null) {
      return InfoChip(
        icon: PhosphorFill.checkCircle,
        label: t.onlineOffline,
        active: true,
      );
    }
    if (task != null) {
      return InfoChip(
        icon: PhosphorRegular.downloadSimple,
        label: t.onlineObtaining,
      );
    }
    return InfoChip(
      icon: PhosphorRegular.downloadSimple,
      label: t.tabGet,
      tooltip: t.onlineObtainBody,
      onTap: () => obtainOnline(context, ref, (
        videoId: id,
        title: entry.title,
        thumbnail: entry.artwork,
      )),
    );
  }
}

/// Réglages › Lecture › Écoute en ligne.
class OnlineSettingsGroup extends ConsumerWidget {
  const OnlineSettingsGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = L10n.of(context);
    final s = ref.watch(onlineSettingsProvider).value;
    if (s == null) return const SizedBox.shrink();
    final save = ref.read(onlineSettingsProvider.notifier).save;
    final offers = ref.read(onlineApiProvider).offers();
    return SettingsGroup(
      title: t.onlineSettingsSection,
      rows: [
        SettingsRow(
          title: t.onlineAutoObtain,
          body: t.onlineAutoObtainBody,
          control: MmSwitch(
            value: s.autoObtain,
            label: t.onlineAutoObtain,
            onChanged: (v) => save(s.copyWith(autoObtain: v)),
          ),
        ),
        SettingsRow(
          title: t.onlineObtainFormat,
          body: t.onlineObtainFormatBody,
          control: SettingsMenu<String>(
            label: t.onlineObtainFormat,
            values: [
              (askFormat, t.onlineFormatAsk),
              for (final o in offers) (o.key, offerText(t, o).$1),
            ],
            selected: offers.any((o) => o.key == s.format)
                ? s.format
                : askFormat,
            onChanged: (v) => save(s.copyWith(format: v)),
          ),
        ),
      ],
    );
  }
}

/// Mounted by the shells: obtains the online tracks played to the end when
/// the setting is on, and says so.
class OnlineObtainListener extends ConsumerStatefulWidget {
  const OnlineObtainListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OnlineObtainListener> createState() =>
      _OnlineObtainListenerState();
}

class _OnlineObtainListenerState extends ConsumerState<OnlineObtainListener> {
  /// Videos already handled this session: never obtained twice.
  final _handled = <String>{};

  /// « En entier »: the end, or 90 % of a track of at least 30 s.
  static bool _heard(PlaybackSnapshot s) =>
      s.status == PlaybackStatus.ended ||
      (s.duration >= const Duration(seconds: 30) &&
          s.position.inMilliseconds >= s.duration.inMilliseconds * 0.9);

  void _check(PlaybackSnapshot? s) {
    if (s == null || !_heard(s)) return;
    final settings = ref.read(onlineSettingsProvider).value;
    if (settings == null || !settings.autoObtain) return;
    final entry = ref.read(queueProvider).current;
    final id = entry?.onlineId;
    if (id == null || s.source?.uri != entry!.source.uri) return;
    if (!_handled.add(id)) return;
    unawaited(_obtain(entry, id, settings));
  }

  Future<void> _obtain(
    QueueEntry entry,
    String id,
    OnlineSettings settings,
  ) async {
    final api = ref.read(onlineApiProvider);
    final url = api.watchUrl(id);
    if (url == null) return;
    if ((await api.local([id])).isNotEmpty) return;
    if (onlineTaskOf(ref.read(downloadsProvider), url) != null) return;
    final offers = api.offers();
    final offer =
        offers.where((o) => o.key == settings.autoFormat).firstOrNull ??
        offers.firstOrNull;
    if (offer == null) return;
    final ok = await startObtain(
      ref.read(downloadsProvider.notifier),
      (videoId: id, title: entry.title, thumbnail: entry.artwork),
      offer,
      url,
    );
    if (!ok || !mounted) return;
    _toast(context, L10n.of(context).onlineObtainAuto(entry.title));
  }

  @override
  Widget build(BuildContext context) {
    // Loaded now and kept: the check reads it synchronously.
    ref.listen(onlineSettingsProvider, (_, _) {});
    ref.listen(playbackProvider, (_, next) => _check(next.value));
    return widget.child;
  }
}
