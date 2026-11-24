import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/cover_art.dart';
import '../../design/widgets/logo.dart';
import '../../design/widgets/pressable.dart';
import '../../l10n/app_localizations.dart';
import '../../src/rust/api/indexer.dart';
import '../../src/rust/api/library.dart';
import '../cinema/cinema_widgets.dart';
import '../library/groups.dart';
import '../library/library_data.dart';
import '../settings/settings_data.dart';
import 'import_data.dart';

String kindLabel(L10n t, FolderKind k) => switch (k) {
  FolderKind.music => t.tabMusic,
  FolderKind.video => t.kindVideo,
  FolderKind.focus => t.tabFocus,
};

/// Picks a folder and follows it with [kind]; returns its path.
Future<String?> pickFolder(WidgetRef ref, FolderKind kind) async {
  final path = await getDirectoryPath();
  if (path == null) return null;
  await ref.read(libraryFoldersProvider.notifier).add(path, kind);
  return path;
}

/// Scans the followed folders now (the worker then reads them).
Future<void> scanFolders(WidgetRef ref) async {
  final folders = await ref.read(libraryFoldersProvider.future);
  if (folders.isEmpty) return;
  await ref.read(indexerApiProvider).scan([for (final f in folders) f.path]);
  refreshLibraryWith(ref.invalidate);
}

/// W-O1 first launch: language and look, folders, scan. Every step can be
/// skipped; nothing needs an account.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  int _step = 0;

  Future<void> _finish() async {
    await ref.read(onboardingProvider.notifier).finish();
    if (mounted) context.go(Routes.listenHome);
  }

  Future<void> _analyse() async {
    setState(() => _step = 2);
    await scanFolders(ref);
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final steps = [t.stepAppearance, t.stepFolders, t.stepScan];
    final side = Container(
      width: 420,
      padding: const EdgeInsets.fromLTRB(44, 48, 44, 40),
      decoration: BoxDecoration(
        color: c.sidebar,
        border: Border(right: BorderSide(color: c.divider)),
      ),
      // Scrolls on short windows; the note stays at the bottom otherwise.
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(MmRadius.card),
                    ),
                    child: const Center(child: MiarinaLogo(size: 30)),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    t.welcomeHeadline,
                    style: MmType.displayXl.copyWith(
                      fontSize: 30,
                      height: 36 / 30,
                      color: c.fg,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t.welcomeLocal,
                    style: MmType.body.copyWith(color: c.fgSoft),
                  ),
                  const SizedBox(height: 28),
                  for (final (i, label) in steps.indexed)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: i == _step ? c.surface : Colors.transparent,
                        borderRadius: BorderRadius.circular(MmRadius.md),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i < _step
                                  ? c.accent
                                  : i == _step
                                  ? c.fg
                                  : c.surface2,
                            ),
                            child: Center(
                              child: i < _step
                                  ? Icon(
                                      PhosphorRegular.check,
                                      size: 16,
                                      color: c.bg,
                                    )
                                  : Text(
                                      '${i + 1}',
                                      style: MmType.captionStrong.copyWith(
                                        color: i == _step ? c.bg : c.muted,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              label,
                              style: MmType.labelStrong.copyWith(
                                color: i <= _step ? c.fg : c.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  Text(
                    t.welcomeFoot,
                    style: MmType.caption.copyWith(color: c.faint),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final Widget step = switch (_step) {
      0 => _AppearanceStep(onNext: () => setState(() => _step = 1)),
      1 => _FoldersStep(
        onBack: () => setState(() => _step = 0),
        onNext: _analyse,
      ),
      _ => _ScanStep(onDone: _finish),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (MediaQuery.sizeOf(context).width >= 1100) side,
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(56, 48, 56, 40),
                  child: AnimatedSwitcher(
                    duration: MmMotion.of(context).screen,
                    child: KeyedSubtree(key: ValueKey(_step), child: step),
                  ),
                ),
              ),
              Positioned(
                right: 24,
                top: 16,
                child: Pressable(
                  onTap: _finish,
                  semanticLabel: t.skip,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      t.skip,
                      style: MmType.label.copyWith(color: c.muted),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Row(children: children);
}

class _Big extends StatelessWidget {
  const _Big({
    required this.label,
    required this.onTap,
    this.coral = false,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool coral;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final bg = outlined ? Colors.transparent : (coral ? c.coral : c.accent);
    final fg = outlined ? c.fg : (coral ? c.coralInk : const Color(0xFF062320));
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      pressScale: 0.97,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          height: 44,
          constraints: BoxConstraints(minWidth: outlined ? 0 : 200),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(MmRadius.pill),
            border: outlined ? Border.all(color: c.lineStrong) : null,
          ),
          child: Center(
            widthFactor: 1,
            child: Text(label, style: MmType.heading.copyWith(color: fg)),
          ),
        ),
      ),
    );
  }
}

class _AppearanceStep extends ConsumerWidget {
  const _AppearanceStep({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final look = ref.watch(appearanceProvider).value ?? const AppearancePrefs();
    final ctl = ref.read(appearanceProvider.notifier);
    final lang = look.language ?? Localizations.localeOf(context).languageCode;

    Widget langChip(String? code, String label, {bool future = false}) {
      final on = code == lang;
      return Pressable(
        onTap: future ? null : () => ctl.save(look.copyWith(language: code)),
        selected: on,
        semanticLabel: label,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: on ? c.accentSubtle : Colors.transparent,
            borderRadius: BorderRadius.circular(MmRadius.pill),
            border: Border.all(color: on ? c.accent : c.lineStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MmType.labelStrong.copyWith(
                    color: on ? c.chipText : (future ? c.faint : c.fg),
                  ),
                ),
              ),
              if (future) ...[
                const SizedBox(width: 6),
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
      );
    }

    Widget themeCard(ThemePref p, String label) {
      final on = look.theme == p;
      final light = p == ThemePref.light;
      return Expanded(
        child: Pressable(
          onTap: () => ctl.save(look.copyWith(theme: p)),
          selected: on,
          semanticLabel: label,
          child: Container(
            height: 180,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.sidebar,
              borderRadius: BorderRadius.circular(MmRadius.lg),
              border: Border.all(
                color: on ? c.accent : c.line,
                width: on ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(MmRadius.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: ColoredBox(
                            color: light
                                ? const Color(0xFFF4F6F8)
                                : const Color(0xFF16212B),
                          ),
                        ),
                        if (p == ThemePref.system)
                          const Expanded(
                            child: ColoredBox(color: Color(0xFFF4F6F8)),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.right,
                  style: MmType.labelStrong.copyWith(color: c.fg),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.stepAppearance, style: MmType.display.copyWith(color: c.fg)),
        const SizedBox(height: 26),
        Text(t.language, style: MmType.labelStrong.copyWith(color: c.fg)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            langChip('fr', 'Français'),
            langChip('en', 'English'),
            langChip('mg', 'Malagasy'),
          ],
        ),
        const SizedBox(height: 26),
        Text(t.theme, style: MmType.labelStrong.copyWith(color: c.fg)),
        const SizedBox(height: 10),
        Row(
          children: [
            themeCard(ThemePref.dark, t.themeDark),
            const SizedBox(width: 14),
            themeCard(ThemePref.light, t.themeLight),
            const SizedBox(width: 14),
            themeCard(ThemePref.system, t.themeFollow),
          ],
        ),
        const Spacer(),
        _Footer(
          children: [
            const Spacer(),
            _Big(label: t.continueLabel, onTap: onNext),
          ],
        ),
      ],
    );
  }
}

/// Followed folders with their type, added count of media, removal.
class FolderList extends ConsumerWidget {
  const FolderList({super.key, required this.folders, this.counts = const {}});

  final List<WatchedFolder> folders;
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final ctl = ref.read(libraryFoldersProvider.notifier);
    return Column(
      children: [
        for (final f in folders)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(MmRadius.lg),
              border: Border.all(color: c.line),
            ),
            child: Row(
              children: [
                Icon(PhosphorRegular.folder, size: 20, color: c.fgSoft),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MmType.monoStyle(
                          size: 12,
                          weight: 700,
                          color: c.fg,
                        ),
                      ),
                      if (counts[f.path] != null)
                        Text(
                          t.folderFiles(counts[f.path]!),
                          style: MmType.caption.copyWith(color: c.muted),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                PillSegment<FolderKind>(
                  values: [
                    for (final k in FolderKind.values) (k, kindLabel(t, k)),
                  ],
                  selected: f.kind,
                  onChanged: (k) => ctl.setKind(f.path, k),
                ),
                Pressable(
                  onTap: () => ctl.remove(f.path),
                  tooltip: t.removeFolder,
                  semanticLabel: '${t.removeFolder} ${f.path}',
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(PhosphorRegular.x, size: 16, color: c.muted),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FoldersStep extends ConsumerStatefulWidget {
  const _FoldersStep({required this.onBack, required this.onNext});

  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  ConsumerState<_FoldersStep> createState() => _FoldersStepState();
}

class _FoldersStepState extends ConsumerState<_FoldersStep> {
  final _counts = <String, int>{};

  @override
  void initState() {
    super.initState();
    unawaited(_suggest());
  }

  Future<void> _suggest() async {
    final api = ref.read(indexerApiProvider);
    final current = await ref.read(libraryFoldersProvider.future);
    if (current.isEmpty) {
      for (final f in await suggestedFolders(api)) {
        await ref.read(libraryFoldersProvider.notifier).add(f.path, f.kind);
      }
    }
    await _count();
  }

  Future<void> _count() async {
    final api = ref.read(indexerApiProvider);
    for (final f in await ref.read(libraryFoldersProvider.future)) {
      if (_counts.containsKey(f.path)) continue;
      final n = await api.count(f.path);
      if (mounted) setState(() => _counts[f.path] = n);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final folders =
        ref.watch(libraryFoldersProvider).value ?? const <WatchedFolder>[];
    final files = folders.fold<int>(0, (n, f) => n + (_counts[f.path] ?? 0));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.foldersTitle, style: MmType.display.copyWith(color: c.fg)),
        const SizedBox(height: 6),
        Text(t.foldersBody, style: MmType.bodySm.copyWith(color: c.muted)),
        const SizedBox(height: 20),
        Expanded(
          child: ListView(
            children: [
              FolderList(folders: folders, counts: _counts),
              const SizedBox(height: 6),
              Pressable(
                onTap: () async {
                  final path = await pickFolder(ref, FolderKind.music);
                  if (path != null) await _count();
                },
                semanticLabel: t.addFolder,
                child: Container(
                  height: 110,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(MmRadius.lg),
                    border: Border.all(color: c.lineStrong),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PhosphorRegular.folderPlus,
                          size: 22,
                          color: c.accent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          t.addFolder,
                          style: MmType.heading.copyWith(color: c.accent),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Footer(
          children: [
            _Big(label: t.back, outlined: true, onTap: widget.onBack),
            Expanded(
              child: Text(
                t.foldersSummary(folders.length, files),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MmType.bodySm.copyWith(color: c.muted),
              ),
            ),
            const SizedBox(width: 14),
            _Big(
              label: t.analyse,
              onTap: folders.isEmpty ? null : widget.onNext,
            ),
          ],
        ),
      ],
    );
  }
}

/// Progress of the background scan, refreshed every second while shown.
final indexStatusProvider = StreamProvider.autoDispose<IndexStatus>((ref) {
  final api = ref.watch(indexerApiProvider);
  final out = StreamController<IndexStatus>();
  Future<void> read() async {
    try {
      final s = await api.status();
      if (!out.isClosed) out.add(s);
    } catch (e, st) {
      if (!out.isClosed) out.addError(e, st);
    }
  }

  unawaited(read());
  final timer = Timer.periodic(const Duration(seconds: 1), (_) => read());
  ref.onDispose(() {
    timer.cancel();
    out.close();
  });
  return out.stream;
});

/// Files done out of the total, counting what the worker can do (tags
/// always, durations and pictures only with FFmpeg).
(int done, int total) scanCounts(IndexStatus s) {
  final total = s.total.toInt();
  final left = s.hasFfmpeg
      ? (s.toTag > s.toProbe ? s.toTag : s.toProbe).toInt()
      : s.toTag.toInt();
  return (total - left, total);
}

class _ScanStep extends ConsumerWidget {
  const _ScanStep({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final status = ref.watch(indexStatusProvider).value;
    final albums =
        ref.watch(groupsProvider(GroupKind.album)).value ??
        const <LibraryGroup>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.scanTitle, style: MmType.display.copyWith(color: c.fg)),
        const SizedBox(height: 6),
        Text(t.scanBody, style: MmType.bodySm.copyWith(color: c.muted)),
        const SizedBox(height: 20),
        if (status != null) ScanProgressCard(status: status),
        const SizedBox(height: 24),
        if (albums.isNotEmpty) ...[
          SectionHeader(t.readyNow),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final a in albums.take(8)) ...[
                  SizedBox(
                    width: 112,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CoverArt(
                          size: 112,
                          radius: MmRadius.md,
                          seed: a.name.hashCode,
                          imagePath: a.thumbnail,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          a.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MmType.captionStrong.copyWith(color: c.fg),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
              ],
            ),
          ),
        ],
        const Spacer(),
        _Footer(
          children: [
            Expanded(
              child: Text(
                status != null && !status.hasFfmpeg
                    ? t.scanNoFfmpeg
                    : t.scanEco,
                style: MmType.caption.copyWith(color: c.faint),
              ),
            ),
            const SizedBox(width: 16),
            _Big(label: t.startListening, coral: true, onTap: onDone),
          ],
        ),
      ],
    );
  }
}

/// "1 984 fichiers sur environ 3 200", bar, and the counters.
class ScanProgressCard extends StatelessWidget {
  const ScanProgressCard({super.key, required this.status});

  final IndexStatus status;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final (done, total) = scanCounts(status);
    final ratio = total == 0 ? 1.0 : done / total;
    Widget stat(int n, String label) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.sidebar,
          borderRadius: BorderRadius.circular(MmRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$n', style: MmType.title.copyWith(fontSize: 20, color: c.fg)),
            Text(label, style: MmType.caption.copyWith(color: c.muted)),
          ],
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(20),
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
              Expanded(
                child: Text(
                  t.scanProgress(done, total),
                  style: MmType.heading.copyWith(fontSize: 15, color: c.fg),
                ),
              ),
              Text(
                '${(ratio * 100).round()} %',
                style: MmType.monoStyle(size: 12, weight: 700, color: c.accent),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(MmRadius.pill),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: ratio,
                backgroundColor: c.line,
                color: c.accent,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              stat(status.audio.toInt(), t.statTracks),
              const SizedBox(width: 10),
              stat(status.albums.toInt(), t.statAlbums),
              const SizedBox(width: 10),
              stat(status.video.toInt(), t.statVideos),
              const SizedBox(width: 10),
              stat(status.unreadable.toInt(), t.statUnreadable),
            ],
          ),
        ],
      ),
    );
  }
}
