import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/cover_art.dart';
import '../../design/widgets/expressive.dart';
import '../../design/widgets/pressable.dart';
import '../../l10n/app_localizations.dart';
import '../../src/rust/api/library.dart';
import '../common/state_views.dart';
import '../library/groups.dart';
import '../library/library_data.dart';
import '../library/phone_library.dart';
import '../library/track_actions.dart';
import '../playback/playback.dart';
import 'phone_home_data.dart';

/// The lists the home suggests (owner's request, 2026-11-28): a tap opens
/// their titles first, to choose one, play them all or shuffle them.
enum MixKind { moment, discover, mostPlayed }

/// « Mix du matin », « Mix du soir »… after the part of the day.
String mixTitle(L10n t, int part) => switch (part) {
  0 => t.mixNight,
  1 => t.mixMorning,
  2 => t.mixAfternoon,
  _ => t.mixEvening,
};

String mixKindTitle(L10n t, MixKind kind, PhoneHome home) => switch (kind) {
  MixKind.moment => mixTitle(t, home.mixPart),
  MixKind.discover => t.discoverTitle,
  MixKind.mostPlayed => t.mostPlayedTitle,
};

List<LibraryItem> mixItems(MixKind kind, PhoneHome home) => switch (kind) {
  MixKind.moment => home.mix,
  MixKind.discover => home.discover,
  MixKind.mostPlayed => home.mostPlayed,
};

/// Opens a suggested list's page.
void openMix(BuildContext context, MixKind kind) {
  HapticFeedback.selectionClick();
  context.push(
    Uri(path: Routes.mix, queryParameters: {'kind': kind.name}).toString(),
  );
}

/// Plays [items] from [start], shuffled or in order (missing files left
/// out).
Future<void> playLibraryItems(
  WidgetRef ref,
  L10n t,
  List<LibraryItem> items, {
  int start = 0,
  bool shuffle = false,
}) async {
  if (start >= 0 && start < items.length && items[start].missing) return;
  final chosen = start >= 0 && start < items.length ? items[start] : null;
  final list = items.where((i) => !i.missing).toList();
  if (list.isEmpty) return;
  final queue = ref.read(queueProvider.notifier);
  if (shuffle != ref.read(queueProvider).shuffle) await queue.toggleShuffle();
  await queue.playAll([
    for (final i in list) queueEntryOf(i, unknownArtist: t.unknownArtist),
  ], start: chosen == null ? 0 : list.indexOf(chosen));
}

/// A suggested list: its covers, title, count and length, play and
/// shuffle, then its titles (tap one to play from it; dots for its
/// actions).
class MixScreen extends ConsumerWidget {
  const MixScreen({super.key, required this.kind});

  final MixKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final home = ref.watch(phoneHomeProvider);
    final data = home.value;
    if (data == null) {
      return home.hasError
          ? LibraryErrorView(
              error: home.error!,
              onRetry: () => ref.invalidate(phoneHomeProvider),
            )
          : const SizedBox.shrink();
    }
    final items = mixItems(kind, data);
    final title = mixKindTitle(t, kind, data);
    if (items.isEmpty) {
      return LibraryMessage(
        icon: PhosphorRegular.musicNotes,
        title: title,
        body: t.noListenYet,
      );
    }
    final secs = items.fold<double>(0, (a, i) => a + (i.durationSecs ?? 0));
    final meta = [
      t.tracksSummary(items.length),
      if (secs > 0) durationWords(secs),
    ].join(' · ');
    final artwork = items
        .map((i) => i.thumbnail)
        .whereType<String>()
        .firstOrNull;
    void play(int i) => playLibraryItems(ref, t, items, start: i);
    void shuffle() => playLibraryItems(ref, t, items, shuffle: true);
    void more(LibraryItem item) => showTrackActions(
      context,
      ref,
      item,
      onChanged: () => ref.invalidate(phoneHomeProvider),
    );

    if (MediaQuery.sizeOf(context).width < 720) {
      return PhoneGroupPage(
        kind: GroupKind.album,
        name: title,
        group: null,
        artwork: artwork,
        items: items,
        meta: meta,
        albums: const [],
        onPlay: play,
        onShuffle: shuffle,
        onMore: more,
        numbered: false,
        backRoute: Routes.listenHome,
      );
    }

    // Windows: a header panel, then the titles.
    final covers = <LibraryItem>[];
    for (final i in items) {
      if (covers.length == 4) break;
      if (i.thumbnail != null &&
          !covers.any((x) => x.thumbnail == i.thumbnail)) {
        covers.add(i);
      }
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: covers.length < 4
                    ? CoverArt(
                        size: 180,
                        radius: 24,
                        seed: title.hashCode,
                        imagePath: artwork,
                        shadow: false,
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Wrap(
                          children: [
                            for (final i in covers)
                              CoverArt(
                                size: 90,
                                radius: 0,
                                seed: i.id,
                                imagePath: i.thumbnail,
                                shadow: false,
                              ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(width: 28),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Pressable(
                      onTap: () => context.canPop()
                          ? context.pop()
                          : context.go(Routes.listenHome),
                      semanticLabel: t.back,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorRegular.caretLeft,
                            size: 16,
                            color: c.fg,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            t.back,
                            style: MmType.label.copyWith(
                              fontSize: 13,
                              color: c.fg,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      style: MmType.displayXl.copyWith(
                        fontWeight: FontWeight.w600,
                        fontVariations: const [FontVariation.weight(600)],
                        color: c.fg,
                      ),
                    ),
                    Text(meta, style: MmType.bodySm.copyWith(color: c.fgSoft)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        MorphButton(
                          onTap: () => play(0),
                          color: c.coral,
                          semanticLabel: t.play,
                          height: 48,
                          radius: 24,
                          pressedRadius: 12,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 0, 22, 0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  PhosphorFill.play,
                                  size: 18,
                                  color: c.coralInk,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  t.play,
                                  style: MmType.labelStrong.copyWith(
                                    color: c.coralInk,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        MorphButton(
                          onTap: shuffle,
                          color: c.surface2,
                          semanticLabel: t.shuffle,
                          height: 48,
                          radius: 24,
                          pressedRadius: 12,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 0, 22, 0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  PhosphorRegular.shuffle,
                                  size: 18,
                                  color: c.fg,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  t.shuffle,
                                  style: MmType.labelStrong.copyWith(
                                    color: c.fg,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 3),
          PhoneTrackRow(
            item: items[i],
            first: i == 0,
            last: i == items.length - 1,
            onTap: () => play(i),
            onMore: () => more(items[i]),
          ),
        ],
      ],
    );
  }
}
