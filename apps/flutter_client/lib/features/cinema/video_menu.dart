import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../src/rust/api/cinema.dart';
import '../get/get_screens.dart' show revealProvider;
import '../library/tag_editor.dart';
import '../playback/playback.dart';
import '../playback/playback_memory.dart';
import 'cinema_data.dart';

/// Where "Capturer l'image" takes its picture: the playing position for
/// the playing video, else its resume point, else a tenth of the way in
/// (the first frame is often black), as in the Tauri app.
Future<Duration> frameTimeOf(WidgetRef ref, CinemaItem v) async {
  final id = v.item.id;
  if (ref.read(queueProvider).current?.libraryId == id) {
    final at = ref.read(mediaEngineProvider)?.current.position;
    if (at != null && at > Duration.zero) return at;
  }
  final saved = await ref.read(playbackMemoryProvider).savedPosition(id);
  if (saved != null) return saved;
  final secs = v.item.durationSecs ?? 0;
  return Duration(milliseconds: (secs * 100).round());
}

/// « Modifier les tags » of a video; the Cinema lists show the result.
Future<void> editVideoTags(
  BuildContext context,
  WidgetRef ref,
  CinemaItem v,
) async {
  final frameAt = await frameTimeOf(ref, v);
  if (!context.mounted) return;
  final updated = await showTagEditor(context, v.item, frameAt: frameAt);
  if (updated == null) return;
  ref
    ..invalidate(cinemaLibraryProvider)
    ..invalidate(seriesProvider);
}

/// Right click (long press on Android) on a video: play, watched or not,
/// edit tags, show in File Explorer.
Future<void> showVideoMenu(
  BuildContext context,
  WidgetRef ref,
  CinemaItem v,
  Offset at, {
  required bool seen,
  required VoidCallback onPlay,
}) async {
  final c = MmColors.of(context);
  final t = L10n.of(context);
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  PopupMenuItem<int> item(int value, IconData icon, String label) =>
      PopupMenuItem<int>(
        value: value,
        height: 34,
        child: Row(
          children: [
            Icon(icon, size: 18, color: c.muted),
            const SizedBox(width: 10),
            Text(
              label,
              style: MmType.label.copyWith(
                color: c.fg,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
  final missing = v.item.missing;
  final choice = await showMenu<int>(
    context: context,
    position: RelativeRect.fromRect(
      at & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    color: c.surface2,
    constraints: const BoxConstraints(minWidth: 230),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: c.overlayBorder),
    ),
    menuPadding: const EdgeInsets.all(6),
    items: [
      if (!missing) item(0, PhosphorFill.play, t.playSelection),
      item(
        1,
        seen ? PhosphorRegular.circle : PhosphorRegular.checkCircle,
        seen ? t.markUnseen : t.markSeen,
      ),
      if (!missing) ...[
        const PopupMenuDivider(height: 9),
        item(2, PhosphorRegular.notePencil, t.editTags),
        if (Platform.isWindows)
          item(3, PhosphorRegular.folderOpen, t.showInExplorer),
      ],
    ],
  );
  if (!context.mounted) return;
  switch (choice) {
    case 0:
      onPlay();
    case 1:
      await ref.read(seenMarksProvider.notifier).mark([v.item.id], seen: !seen);
    case 2:
      await editVideoTags(context, ref, v);
    case 3:
      await ref.read(revealProvider)(v.item.path, select: true);
  }
}
