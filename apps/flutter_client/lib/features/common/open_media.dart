import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../l10n/app_localizations.dart';
import '../../src/rust/api/cinema.dart';
import '../../src/rust/api/focus.dart';
import '../../src/rust/api/library.dart';
import '../cinema/cinema_screen.dart';
import '../focus/focus_data.dart';
import '../library/library_data.dart';
import '../playback/playback.dart';

/// Plays a library entry the way its section does: a video in its player
/// (an episode with the rest of its series), a Focus item in its program at
/// its speed, a track on its own. [fromStart] ignores the resume point.
Future<void> openMedia(
  BuildContext context,
  WidgetRef ref,
  LibraryItem item, {
  CinemaItem? video,
  FocusItem? focus,
  bool fromStart = false,
}) async {
  final t = L10n.of(context);
  if (video != null) {
    await playVideo(ref, t, video, fromStart: fromStart);
    if (context.mounted) context.push(Routes.watch);
    return;
  }
  if (focus != null) {
    final items = await ref.read(focusProgramProvider(focus.program).future);
    final i = items.indexWhere((f) => f.item.id == focus.item.id);
    await playFocus(
      ref.read(queueProvider.notifier),
      i < 0 ? [focus] : items,
      start: i < 0 ? 0 : i,
      fromStart: fromStart,
    );
    if (context.mounted) context.push(Routes.focusPlayer);
    return;
  }
  await ref.read(queueProvider.notifier).playAll([
    queueEntryOf(item, unknownArtist: t.unknownArtist),
  ], fromStart: fromStart);
  if (item.isVideo && context.mounted) context.push(Routes.watch);
}
