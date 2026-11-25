import 'package:material_ui/material_ui.dart';

import '../../design/tokens.dart';
import '../../design/widgets/cover_art.dart';
import '../../l10n/app_localizations.dart';
import '../../src/rust/api/library.dart';
import '../../design/widgets/track_bar.dart' show formatClock;

/// « Infos du morceau » (phone): what the library knows about a title, in the
/// grouped blocks of the expressive sheets. Read only.
Future<void> showTrackInfo(BuildContext context, LibraryItem item) {
  final c = MmColors.of(context);
  final dark = c.brightness == Brightness.dark;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: dark ? c.surface : c.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (context) => _TrackInfo(item: item),
  );
}

class _TrackInfo extends StatelessWidget {
  const _TrackInfo({required this.item});

  final LibraryItem item;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final dark = c.brightness == Brightness.dark;
    final block = dark ? c.surface2 : Color.lerp(c.bg, c.fg, 0.055)!;
    final secs = item.durationSecs;
    final rows = <(String, String)>[
      (t.colTitle, item.title),
      (t.colArtist, item.artist ?? t.unknownArtist),
      if (item.album != null) (t.colAlbum, item.album!),
      if (item.format != null) (t.colFormat, item.format!),
      if (secs != null)
        (
          t.colDuration,
          formatClock(Duration(milliseconds: (secs * 1000).round())),
        ),
      (t.trackPlays, t.playsCount(item.plays)),
      (t.trackFile, item.path),
    ];
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        14,
        10,
        14,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.faintIcon,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: Row(
              children: [
                CoverArt(
                  size: 64,
                  radius: 16,
                  seed: item.id,
                  imagePath: item.thumbnail,
                  shadow: false,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    t.trackInfo,
                    style: MmType.title.copyWith(color: c.fg),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              decoration: BoxDecoration(
                color: block,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(i == 0 ? 24 : 6),
                  bottom: Radius.circular(i == rows.length - 1 ? 24 : 6),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rows[i].$1,
                    style: MmType.caption.copyWith(color: c.muted),
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    rows[i].$2,
                    style: MmType.body.copyWith(fontSize: 15, color: c.fg),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
