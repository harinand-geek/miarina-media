import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/cover_art.dart';
import '../../design/widgets/pressable.dart';
import '../../design/widgets/states.dart';
import '../../l10n/app_localizations.dart';
import '../common/state_views.dart';
import '../import/import_data.dart';
import '../library/groups.dart';
import '../online/online_obtain.dart' show OnlineObtainListener;
import '../playback/playback.dart' show skippedMissingProvider;
import 'health_data.dart';
import '../../app/malagasy_fallback.dart';

/// File and folder pickers of the health screens (system dialogs; tests
/// answer them).
final locateFilePickerProvider = Provider<Future<String?> Function(String)>(
  (_) =>
      (label) async => (await openFile(
        acceptedTypeGroups: [
          XTypeGroup(label: label, extensions: mediaExtensions),
        ],
      ))?.path,
);

final searchFolderPickerProvider = Provider<Future<String?> Function()>(
  (_) =>
      () => getDirectoryPath(),
);

/// Whether durations can be read (FFmpeg present): duplicates need them.
final durationsReadableProvider = FutureProvider<bool>((ref) async {
  try {
    return (await ref.read(indexerApiProvider).status()).hasFfmpeg;
  } catch (_) {
    return true;
  }
});

/// "58 Mo", "2,4 Go": binary units, as Windows Explorer shows them.
String formatSize(BuildContext context, int bytes) {
  final t = L10n.of(context);
  final locale = intlLocaleOf(context);
  String n(double v) =>
      NumberFormat(v < 10 ? '#,##0.#' : '#,##0', locale).format(v);
  const k = 1024.0;
  if (bytes < k * k) return t.sizeKb(n(bytes / k));
  if (bytes < k * k * k) return t.sizeMb(n(bytes / (k * k)));
  return t.sizeGb(n(bytes / (k * k * k)));
}

void _toast(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
}

/// "Localiser…": the user points at the file of a missing entry.
Future<void> locateMissing(
  BuildContext context,
  WidgetRef ref,
  int libraryId,
) async {
  final t = L10n.of(context);
  final file = await ref.read(locateFilePickerProvider)(t.mediaFiles);
  if (file == null) return;
  try {
    await ref.read(healthApiProvider).relocate(libraryId, file);
    if (context.mounted) _toast(context, t.fileLocated);
  } catch (_) {
    if (context.mounted) _toast(context, t.locateFailed);
  }
  refreshLibrary(ref);
}

/// "E:\" → "E:", other volumes as they are.
String volumeLabel(String root) {
  final drive = RegExp(r'^([A-Za-z]:)[\\/]?$').firstMatch(root);
  return drive?.group(1) ?? root;
}

/// Deepest folder holding every path.
String commonFolder(List<String> paths) {
  if (paths.isEmpty) return '';
  final sep = paths.first.contains('\\') ? '\\' : '/';
  List<String> parts(String p) {
    final s = p.split(RegExp(r'[\\/]'));
    return s.sublist(0, s.length - 1);
  }

  var common = parts(paths.first);
  for (final p in paths.skip(1)) {
    final other = parts(p);
    var i = 0;
    while (i < common.length && i < other.length && common[i] == other[i]) {
      i++;
    }
    common = common.sublist(0, i);
  }
  final out = common.join(sep);
  return common.length == 1 ? '$out$sep' : out;
}

/// A path that keeps its file name visible: the folder part is cut first.
class PathText extends StatelessWidget {
  const PathText(this.path, {super.key, required this.style});

  final String path;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final cut = path.lastIndexOf(RegExp(r'[\\/]'));
    if (cut < 0) {
      return Text(
        path,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    return LayoutBuilder(
      builder: (context, box) => Row(
        children: [
          Flexible(
            child: Text(
              path.substring(0, cut + 1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: box.maxWidth * 0.75),
            child: Text(
              path.substring(cut + 1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthHeader extends StatelessWidget {
  const _HealthHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: MmType.display.copyWith(color: c.fg)),
        const SizedBox(height: 2),
        Text(subtitle, style: MmType.bodySm.copyWith(color: c.muted)),
      ],
    );
  }
}

enum _Tone { primary, secondary, ghost }

class _Button extends StatelessWidget {
  const _Button(
    this.label,
    this.onTap, {
    this.tone = _Tone.secondary,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final _Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final (bg, fg, border) = switch (tone) {
      _Tone.primary => (c.accent, const Color(0xFF062320), c.accent),
      _Tone.secondary => (c.surface2, c.fg, c.lineStrong),
      _Tone.ghost => (Colors.transparent, c.muted, Colors.transparent),
    };
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      pressScale: 0.97,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(MmRadius.pill),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MmType.labelStrong.copyWith(fontSize: 13, color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// W-O2a: missing files grouped by probable cause; relocate, update the
/// paths, or remove from the library on request. Nothing is deleted
/// automatically.
class MissingScreen extends ConsumerWidget {
  const MissingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final mobile = MediaQuery.sizeOf(context).width < 720;
    final pad = mobile ? 16.0 : 32.0;
    final groups = ref.watch(missingProvider);
    final dismissed =
        ref.watch(missingDismissedProvider).value ?? const <String>{};

    if (groups.hasError) {
      return LibraryErrorView(
        error: groups.error!,
        onRetry: () => ref.invalidate(missingProvider),
      );
    }
    if (!groups.hasValue) {
      return SkeletonList(rowHeight: 60, padding: pad);
    }
    final all = groups.value!;
    if (all.isEmpty) {
      return LibraryMessage(
        icon: PhosphorRegular.checkCircle,
        title: t.missingEmptyTitle,
        body: t.missingEmptyBody,
      );
    }
    final visible = [
      for (final g in all)
        if (!dismissed.contains(g.key)) g,
    ];
    final hidden = all.length - visible.length;
    final total = all.fold<int>(0, (n, g) => n + g.files.length);
    return ListView(
      padding: EdgeInsets.fromLTRB(pad, mobile ? 12 : 24, pad, 32),
      children: [
        _HealthHeader(
          title: t.missingTitle,
          subtitle: t.missingSubtitle(total),
        ),
        const SizedBox(height: 16),
        for (final g in visible) ...[
          _MissingCard(group: g),
          const SizedBox(height: 16),
        ],
        if (hidden > 0)
          Row(
            children: [
              Text(
                t.missingHiddenGroups(hidden),
                style: MmType.caption.copyWith(fontSize: 12.5, color: c.muted),
              ),
              const SizedBox(width: 8),
              _Button(
                t.missingShowAll,
                () => ref.read(missingDismissedProvider.notifier).showAll(),
                tone: _Tone.ghost,
              ),
            ],
          ),
      ],
    );
  }
}

class _MissingCard extends ConsumerStatefulWidget {
  const _MissingCard({required this.group});

  final MissingGroupInfo group;

  @override
  ConsumerState<_MissingCard> createState() => _MissingCardState();
}

class _MissingCardState extends ConsumerState<_MissingCard> {
  static const _shown = 6;
  bool _busy = false;

  MissingGroupInfo get g => widget.group;
  List<int> get _ids => [for (final f in g.files) f.id];

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _searchFolder() async {
    final t = L10n.of(context);
    final folder = await ref.read(searchFolderPickerProvider)();
    if (folder == null) return;
    final r = await ref.read(healthApiProvider).relocateIn(_ids, folder);
    refreshLibrary(ref);
    if (!mounted) return;
    _toast(
      context,
      [
        t.missingFoundCount(r.found),
        if (r.left > 0) t.missingLeftCount(r.left),
      ].join(' · '),
    );
  }

  Future<void> _updatePaths() async {
    final t = L10n.of(context);
    final moved = [
      for (final f in g.files)
        if (f.found != null) f,
    ];
    final n = await ref
        .read(healthApiProvider)
        .relocateFound(
          [for (final f in moved) f.id],
          [for (final f in moved) f.found!],
        );
    refreshLibrary(ref);
    if (mounted) _toast(context, t.missingPathsUpdated(n));
  }

  Future<void> _remove() async {
    final t = L10n.of(context);
    final c = MmColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MmRadius.sheet),
          side: BorderSide(color: c.overlayBorder),
        ),
        title: Text(
          t.missingRemoveTitle(g.files.length),
          style: MmType.title.copyWith(color: c.fg),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            t.missingRemoveBody,
            style: MmType.body.copyWith(color: c.fgSoft),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              t.cancel,
              style: MmType.labelStrong.copyWith(color: c.fg),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              t.remove,
              style: MmType.labelStrong.copyWith(color: c.danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(healthApiProvider).remove(_ids);
    refreshLibrary(ref);
  }

  void _dismiss() => ref.read(missingDismissedProvider.notifier).dismiss(g.key);

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final n = g.files.length;
    final (
      icon,
      tint,
      tile,
      title,
      body,
      status,
      statusColor,
    ) = switch (g.cause) {
      MissingCause.volumeAbsent => (
        PhosphorRegular.plugs,
        c.warning,
        c.warningSubtle,
        t.missingVolumeTitle(volumeLabel(g.folder)),
        t.missingVolumeBody(n, commonFolder([for (final f in g.files) f.path])),
        t.missingStatusVolume,
        c.warning,
      ),
      MissingCause.moved => (
        PhosphorRegular.folderSimpleDashed,
        c.accent,
        c.accentSubtle,
        t.missingMovedTitle,
        t.missingMovedBody(n, g.target ?? ''),
        t.missingStatusFound,
        c.accent,
      ),
      MissingCause.notFound => (
        PhosphorRegular.linkBreak,
        c.danger,
        c.danger.withValues(alpha: 0.16),
        t.missingLostTitle(n),
        t.missingLostBody(n),
        t.missingStatusLost,
        c.danger,
      ),
    };
    final busy = _busy;
    VoidCallback? act(Future<void> Function() f) => busy ? null : () => _run(f);
    final actions = switch (g.cause) {
      MissingCause.volumeAbsent => [
        _Button(t.missingRelocate, act(_searchFolder)),
        _Button(t.missingHide, busy ? null : _dismiss, tone: _Tone.ghost),
      ],
      MissingCause.moved => [
        _Button(t.missingUpdatePaths, act(_updatePaths), tone: _Tone.primary),
        _Button(t.missingIgnore, busy ? null : _dismiss, tone: _Tone.ghost),
      ],
      MissingCause.notFound => [
        n == 1
            ? _Button(
                t.missingLocate,
                act(() => locateMissing(context, ref, g.files.first.id)),
              )
            : _Button(t.missingSearchFolder, act(_searchFolder)),
        _Button(t.missingRemove, act(_remove), tone: _Tone.ghost),
      ],
    };

    final head = Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: tile,
            borderRadius: BorderRadius.circular(MmRadius.md),
          ),
          child: Icon(icon, size: 24, color: tint),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: MmType.heading.copyWith(fontSize: 15, color: c.fg),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: MmType.caption.copyWith(fontSize: 12.5, color: c.muted),
              ),
            ],
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(MmRadius.xl),
        border: Border.all(color: c.surface2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final row = Wrap(spacing: 8, runSpacing: 8, children: actions);
              if (box.maxWidth < 640) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    head,
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(left: 58),
                      child: row,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: head),
                  const SizedBox(width: 12),
                  row,
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 58),
            child: Column(
              children: [
                for (final f in g.files.take(_shown))
                  _FileLine(path: f.path, status: status, color: statusColor),
                if (n > _shown)
                  _FileLine(
                    path: t.missingMore(n - _shown),
                    status: '',
                    color: c.muted,
                    plain: true,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FileLine extends StatelessWidget {
  const _FileLine({
    required this.path,
    required this.status,
    required this.color,
    this.plain = false,
  });

  final String path;
  final String status;
  final Color color;
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Container(
      height: 32,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.surface2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: plain
                ? Text(
                    path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MmType.caption.copyWith(
                      fontSize: 12.5,
                      color: c.muted,
                    ),
                  )
                : PathText(
                    path,
                    style: MmType.monoStyle(size: 12, color: c.muted),
                  ),
          ),
          if (status.isNotEmpty) ...[
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: MmType.labelStrong.copyWith(
                  fontSize: 12.5,
                  color: color,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String qualityLabel(DuplicateVersion v) {
  final codec = (v.codec ?? '').toUpperCase();
  if (v.item.isVideo) {
    return [if (v.height != null) '${v.height}p', codec].join(' ');
  }
  if (v.lossless || v.bitrateKbps == null) return codec;
  return '$codec ${v.bitrateKbps} kb/s';
}

/// W-O2b: titles found in several versions (same title, artist and
/// duration). The best quality is proposed to keep; the others are hidden
/// from the library on request, or sent to the Recycle Bin one by one.
class DuplicatesScreen extends ConsumerStatefulWidget {
  const DuplicatesScreen({super.key});

  @override
  ConsumerState<DuplicatesScreen> createState() => _DuplicatesScreenState();
}

class _DuplicatesScreenState extends ConsumerState<DuplicatesScreen> {
  /// Version kept per group, when not the best one.
  final _choices = <String, int>{};
  bool _busy = false;

  Future<void> _hideAll(List<DuplicateSet> sets) async {
    if (_busy) return;
    final t = L10n.of(context);
    setState(() => _busy = true);
    var n = 0;
    try {
      final api = ref.read(healthApiProvider);
      for (final s in sets) {
        final keep = keptOf(s, _choices);
        for (final v in s.versions) {
          if (v.item.id == keep) continue;
          await api.setAside(keep, v.item.id);
          n++;
        }
      }
    } finally {
      refreshLibrary(ref);
      if (mounted) {
        setState(() {
          _busy = false;
          _choices.clear();
        });
        _toast(context, t.duplicatesHidden(n));
      }
    }
  }

  Future<void> _trash(int keep, DuplicateVersion v) async {
    final t = L10n.of(context);
    final c = MmColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MmRadius.sheet),
          side: BorderSide(color: c.overlayBorder),
        ),
        title: Text(
          t.duplicateTrashTitle,
          style: MmType.title.copyWith(color: c.fg),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                v.item.path,
                style: MmType.monoStyle(size: 12, color: c.fgSoft),
              ),
              const SizedBox(height: 12),
              Text(
                t.duplicateTrashBody,
                style: MmType.body.copyWith(color: c.fgSoft),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              t.cancel,
              style: MmType.labelStrong.copyWith(color: c.fg),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              t.duplicateTrash.replaceAll('…', ''),
              style: MmType.labelStrong.copyWith(color: c.danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(healthApiProvider)
          .setAside(keep, v.item.id, deleteFile: true);
      if (mounted) _toast(context, t.duplicateTrashed);
    } catch (e) {
      if (mounted) _toast(context, '$e');
    }
    refreshLibrary(ref);
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final mobile = MediaQuery.sizeOf(context).width < 720;
    final pad = mobile ? 16.0 : 32.0;
    final sets = ref.watch(duplicatesProvider);

    if (sets.hasError) {
      return LibraryErrorView(
        error: sets.error!,
        onRetry: () => ref.invalidate(duplicatesProvider),
      );
    }
    if (!sets.hasValue) return SkeletonList(rowHeight: 60, padding: pad);
    final all = sets.value!;
    if (all.isEmpty) {
      final readable = ref.watch(durationsReadableProvider).value ?? true;
      return LibraryMessage(
        icon: PhosphorRegular.copy,
        title: t.duplicatesEmptyTitle,
        body: readable
            ? t.duplicatesEmptyBody
            : '${t.duplicatesEmptyBody}\n\n${t.duplicatesNeedFfmpeg}',
      );
    }
    final extra = all.fold<int>(0, (n, s) => n + s.versions.length - 1);
    return ListView(
      padding: EdgeInsets.fromLTRB(pad, mobile ? 12 : 24, pad, 32),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 16,
          runSpacing: 12,
          children: [
            _HealthHeader(
              title: t.duplicatesTitle,
              subtitle: t.duplicatesSubtitle(
                all.length,
                formatSize(context, recoverableBytes(all, _choices)),
              ),
            ),
            _Button(
              t.duplicatesKeepBest,
              _busy || _choices.isEmpty ? null : () => setState(_choices.clear),
              icon: PhosphorRegular.sealCheck,
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (final s in all) ...[
          _DuplicateCard(
            set: s,
            kept: keptOf(s, _choices),
            onKeep: _busy
                ? null
                : (id) => setState(() => _choices[duplicateKey(s)] = id),
            onTrash: _busy ? null : (v) => _trash(keptOf(s, _choices), v),
          ),
          const SizedBox(height: 16),
        ],
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 10,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Text(
                t.duplicatesNote,
                style: MmType.caption.copyWith(fontSize: 12.5, color: c.muted),
              ),
            ),
            _Button(
              t.duplicatesHideAll(extra),
              _busy ? null : () => _hideAll(all),
            ),
          ],
        ),
      ],
    );
  }
}

class _DuplicateCard extends StatelessWidget {
  const _DuplicateCard({
    required this.set,
    required this.kept,
    required this.onKeep,
    required this.onTrash,
  });

  final DuplicateSet set;
  final int kept;
  final void Function(int id)? onKeep;
  final void Function(DuplicateVersion v)? onTrash;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final cover = set.versions
        .map((v) => v.item.thumbnail)
        .firstWhere((p) => p != null, orElse: () => null);
    final sub = [?set.artist, ?set.album].join(' · ');
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(MmRadius.xl),
        border: Border.all(color: c.surface2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CoverArt(
                size: 44,
                radius: MmRadius.sm,
                seed: set.versions.first.item.id,
                shadow: false,
                imagePath: cover,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      set.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MmType.heading.copyWith(
                        fontSize: 14.5,
                        color: c.fg,
                      ),
                    ),
                    if (sub.isNotEmpty)
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MmType.caption.copyWith(
                          fontSize: 12.5,
                          color: c.muted,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                t.duplicateVersions(set.versions.length),
                style: MmType.caption.copyWith(fontSize: 12.5, color: c.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final v in set.versions)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _VersionRow(
                version: v,
                kept: v.item.id == kept,
                onKeep: onKeep == null ? null : () => onKeep!(v.item.id),
                onTrash: onTrash == null ? null : () => onTrash!(v),
              ),
            ),
        ],
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({
    required this.version,
    required this.kept,
    required this.onKeep,
    required this.onTrash,
  });

  final DuplicateVersion version;
  final bool kept;
  final VoidCallback? onKeep;
  final VoidCallback? onTrash;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final mono = MmType.monoStyle(size: 12, color: c.muted);
    final quality = qualityLabel(version);
    final size = formatSize(context, version.sizeBytes.toInt());
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 620;
        return Pressable(
          onTap: kept ? null : onKeep,
          semanticLabel: '${version.item.path}, $quality, $size',
          selected: kept,
          child: Container(
            height: wide ? 44 : 56,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: kept ? c.accentSubtle : Colors.transparent,
              borderRadius: BorderRadius.circular(MmRadius.sm),
              border: Border.all(
                color: kept
                    ? c.accent.withValues(alpha: 0.45)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  kept ? PhosphorFill.radioButton : PhosphorRegular.circle,
                  size: 20,
                  color: kept ? c.accent : c.faint,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: wide
                      ? PathText(
                          version.item.path,
                          style: MmType.monoStyle(size: 12, color: c.fgSoft),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PathText(
                              version.item.path,
                              style: MmType.monoStyle(
                                size: 12,
                                color: c.fgSoft,
                              ),
                            ),
                            Text('$quality · $size', style: mono),
                          ],
                        ),
                ),
                if (wide) ...[
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 130,
                    child: Text(
                      quality,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mono,
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(size, maxLines: 1, style: mono),
                  ),
                ],
                SizedBox(
                  width: wide ? 140 : 108,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          kept ? t.duplicateKeep : t.duplicateHide,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MmType.labelStrong.copyWith(
                            fontSize: 12.5,
                            color: kept ? c.accent : c.muted,
                          ),
                        ),
                      ),
                      if (!kept) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: t.duplicateTrash,
                          child: Pressable(
                            onTap: onTrash,
                            semanticLabel: t.duplicateTrash,
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: Icon(
                                PhosphorRegular.trash,
                                size: 18,
                                color: c.muted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Shows « introuvable, titre suivant » with "Localiser" when the queue
/// skipped a missing file (W-O2, "Fichier manquant" flow).
class MissingSkipListener extends ConsumerWidget {
  const MissingSkipListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(skippedMissingProvider, (_, skipped) {
      if (skipped == null) return;
      final t = L10n.of(context);
      final id = skipped.entry.libraryId;
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              skipped.next
                  ? t.missingSkipped(skipped.entry.title)
                  : t.missingSkippedLast(skipped.entry.title),
            ),
            action: id == null
                ? null
                : SnackBarAction(
                    label: t.locate,
                    onPressed: () => locateMissing(context, ref, id),
                  ),
          ),
        );
    });
    // The shells' other listener: online tracks obtained when heard to the
    // end (decision 0011).
    return OnlineObtainListener(child: child);
  }
}
