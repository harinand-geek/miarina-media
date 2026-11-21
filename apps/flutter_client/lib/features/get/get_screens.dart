import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/cover_art.dart';
import '../../design/widgets/pressable.dart';
import '../../l10n/app_localizations.dart';
import '../common/open_media.dart';
import '../home/home_data.dart';
import '../library/library_data.dart';
import 'get_data.dart';

// Obtenir, ported to the identical from the Tauri app (screens 1 to 3 of
// Windows v2: home, analysis, downloads).

String _lang(BuildContext context) =>
    Localizations.localeOf(context).languageCode;

String bytes(BuildContext context, int n) =>
    formatBytes(n, lang: _lang(context));

void _toast(BuildContext context, String text, {SnackBarAction? action}) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        action: action,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

/// Folder picker of "Changer"; tests answer it.
final downloadFolderPickerProvider = Provider<Future<String?> Function()>(
  (_) =>
      () => getDirectoryPath(),
);

/// Shows a folder, or a file selected in it, in the Windows file manager.
final revealProvider =
    Provider<Future<void> Function(String path, {bool select})>(
      (_) => (path, {select = false}) async {
        if (!Platform.isWindows) return;
        await Process.run('explorer.exe', [select ? '/select,$path' : path]);
      },
    );

// ------------------------------------------------------------------- shared

class _Button extends StatelessWidget {
  const _Button(
    this.label,
    this.onTap, {
    this.primary = false,
    this.icon,
    this.height = 40,
  });

  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final fg = primary ? const Color(0xFF062320) : c.fg;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      pressScale: 0.98,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          height: height,
          padding: EdgeInsets.symmetric(horizontal: primary ? 20 : 16),
          decoration: BoxDecoration(
            color: primary ? c.accent : c.surface2,
            borderRadius: BorderRadius.circular(MmRadius.sm),
            border: primary ? null : Border.all(color: c.lineStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MmType.labelStrong.copyWith(
                    fontSize: 13.5,
                    fontWeight: primary ? FontWeight.w700 : FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Local picture of a task or analysis (source thumbnail), else a quiet
/// placeholder with the kind of media.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.path, required this.audio, required this.width});

  final String? path;
  final bool audio;
  final double width;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final file = path;
    return Container(
      width: width,
      height: width * 9 / 16,
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(MmRadius.md),
        border: Border.all(color: c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: file != null && file.isNotEmpty
          ? Image.file(
              File(file),
              fit: BoxFit.cover,
              cacheWidth: (width * 2).round(),
              errorBuilder: (_, _, _) => _placeholder(c),
            )
          : _placeholder(c),
    );
  }

  Widget _placeholder(MmColors c) => Center(
    child: Icon(
      audio ? PhosphorRegular.musicNote : PhosphorRegular.filmStrip,
      size: width / 4,
      color: c.faintIcon,
    ),
  );
}

class _Progress extends StatelessWidget {
  const _Progress({required this.value, required this.color});

  static const height = 4.0;

  /// 0..1, null = indeterminate.
  final double? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(MmRadius.pill),
      child: SizedBox(
        height: height,
        child: LinearProgressIndicator(
          value: value,
          color: color,
          backgroundColor: c.line,
          minHeight: height,
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------- home

/// Windows v2 screen 1: from link to library.
class GetHomeScreen extends ConsumerStatefulWidget {
  const GetHomeScreen({super.key});

  @override
  ConsumerState<GetHomeScreen> createState() => _GetHomeScreenState();
}

class _LinkIssue {
  const _LinkIssue(this.message, {this.warn = true, this.fix});

  final String message;
  final bool warn;
  final String? fix;
}

class _GetHomeScreenState extends ConsumerState<GetHomeScreen> {
  final _field = TextEditingController();
  final _focus = FocusNode(debugLabel: 'link');
  _LinkIssue? _issue;

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// `example.com/video` → `https://example.com/video` when that is valid.
  Future<String?> _suggestFix(String value) async {
    final v = value.trim();
    if (v.isEmpty ||
        v.contains('://') ||
        v.contains(RegExp(r'\s')) ||
        !v.contains('.')) {
      return null;
    }
    final candidate = 'https://${v.replaceFirst(RegExp(r'^/+'), '')}';
    final check = await ref.read(getApiProvider).checkLink(candidate);
    return check.error == null ? candidate : null;
  }

  Future<void> _submit({String? value, String tab = 'video'}) async {
    final t = L10n.of(context);
    final text = value ?? _field.text;
    final check = await ref.read(getApiProvider).checkLink(text);
    if (!mounted) return;
    final url = check.url;
    if (check.error != null || url == null) {
      final code = check.error;
      final fix = code == 'malformed' || code == 'missing_host'
          ? await _suggestFix(text)
          : null;
      if (!mounted) return;
      setState(
        () => _issue = _LinkIssue(
          fix != null
              ? t.getLinkMissingHttps
              : switch (code) {
                  'empty' => t.getLinkEmpty,
                  'too_long' => t.getLinkTooLong,
                  'unsupported_scheme' => t.getLinkScheme,
                  'contains_credentials' => t.getLinkCredentials,
                  _ => t.getLinkMalformed,
                },
          warn: code != 'empty',
          fix: fix,
        ),
      );
      _focus.requestFocus();
      return;
    }
    setState(() => _issue = null);
    context.go(
      Uri(
        path: Routes.getAnalysis,
        queryParameters: {'url': url, 'tab': tab},
      ).toString(),
    );
  }

  Future<void> _paste() async {
    final t = L10n.of(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    _focus.requestFocus();
    if (text.isEmpty) {
      setState(() => _issue = _LinkIssue(t.getClipboardEmpty, warn: false));
      return;
    }
    _field.text = text;
    setState(() => _issue = null);
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 1100 + 232;
    final issue = _issue;

    final linkCard = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(MmRadius.xl),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.only(left: 14, right: 9),
                  decoration: BoxDecoration(
                    color: c.bg,
                    borderRadius: BorderRadius.circular(MmRadius.md),
                    border: Border.all(
                      color: issue == null
                          ? c.lineStrong
                          : issue.warn
                          ? c.warning.withValues(alpha: 0.6)
                          : c.accent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        PhosphorRegular.link,
                        size: 20,
                        color: issue?.warn ?? false ? c.warning : c.muted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          key: const ValueKey('get-link'),
                          controller: _field,
                          focusNode: _focus,
                          onChanged: (_) {
                            if (_issue != null) setState(() => _issue = null);
                          },
                          onSubmitted: (_) => _submit(),
                          style: MmType.monoStyle(size: 14, color: c.fg),
                          cursorColor: c.accent,
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: 'https://',
                            hintStyle: MmType.monoStyle(
                              size: 14,
                              color: c.faint,
                            ),
                          ),
                        ),
                      ),
                      _Button(
                        t.getPaste,
                        _paste,
                        icon: PhosphorRegular.clipboardText,
                        height: 30,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _Button(
                t.getAnalyze,
                _submit,
                primary: true,
                height: 48,
                icon: PhosphorRegular.arrowRight,
              ),
            ],
          ),
          if (issue != null) ...[
            const SizedBox(height: 12),
            _IssueNote(
              issue: issue,
              onFix: issue.fix == null
                  ? null
                  : () {
                      _field.text = issue.fix!;
                      _submit(value: issue.fix);
                    },
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(MmRadius.xs),
                  border: Border.all(color: c.lineStrong),
                ),
                child: Text(
                  'Ctrl V',
                  style: MmType.monoStyle(size: 11, color: c.muted),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                t.getHintPaste,
                style: MmType.caption.copyWith(fontSize: 12.5, color: c.muted),
              ),
            ],
          ),
        ],
      ),
    );

    final quick = [
      _Quick(
        PhosphorRegular.musicNote,
        t.getQAudio,
        t.getQAudioDesc,
        () => _submit(tab: 'audio'),
      ),
      _Quick(
        PhosphorRegular.playlist,
        t.getQPlaylist,
        t.getQPlaylistDesc,
        null,
      ),
      _Quick(PhosphorRegular.stack, t.getQBatch, t.getQBatchDesc, null),
      _Quick(
        PhosphorRegular.shareNetwork,
        t.getQTorrent,
        t.getQTorrentDesc,
        () => context.go(Routes.getTorrents),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(48, 36, 48, 36),
      children: [
        Text(
          t.getHomeTitle,
          style: MmType.display.copyWith(fontSize: 28, color: c.fg),
        ),
        const SizedBox(height: 6),
        Text(t.getHomeSub, style: MmType.body.copyWith(color: c.muted)),
        const SizedBox(height: 32),
        linkCard,
        const SizedBox(height: 32),
        LayoutBuilder(
          builder: (context, box) {
            final cols = box.maxWidth >= 1000 ? 4 : 2;
            const gap = 14.0;
            final w = (box.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [for (final q in quick) SizedBox(width: w, child: q)],
            );
          },
        ),
        const SizedBox(height: 32),
        if (wide)
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 125, child: _ContinueSection()),
              SizedBox(width: 28),
              Expanded(flex: 100, child: _RecentSection()),
            ],
          )
        else ...const [
          _ContinueSection(),
          SizedBox(height: 28),
          _RecentSection(),
        ],
      ],
    );
  }
}

class _IssueNote extends StatelessWidget {
  const _IssueNote({required this.issue, required this.onFix});

  final _LinkIssue issue;
  final VoidCallback? onFix;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    if (!issue.warn) {
      return Row(
        children: [
          Icon(PhosphorRegular.info, size: 16, color: c.accent),
          const SizedBox(width: 6),
          Text(issue.message, style: MmType.caption.copyWith(color: c.muted)),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(MmRadius.sm),
        border: Border.all(color: c.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(PhosphorRegular.linkBreak, size: 18, color: c.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              issue.message,
              style: MmType.caption.copyWith(fontSize: 12.5, color: c.fg),
            ),
          ),
          if (onFix != null)
            _Button(
              t.getAddHttps,
              onFix,
              height: 32,
              icon: PhosphorRegular.magicWand,
            ),
        ],
      ),
    );
  }
}

class _Quick extends StatelessWidget {
  const _Quick(this.icon, this.title, this.detail, this.onTap);

  final IconData icon;
  final String title;
  final String detail;

  /// Null: planned, shown disabled with its badge.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final planned = onTap == null;
    return Tooltip(
      message: planned ? t.getPlannedHint : '',
      child: Pressable(
        onTap: onTap,
        semanticLabel: title,
        hoverColor: c.surface2,
        borderRadius: BorderRadius.circular(MmRadius.md),
        child: Container(
          height: 94,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(MmRadius.md),
            border: Border.all(color: c.line),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: planned ? c.surface2 : c.accentSubtle,
                      borderRadius: BorderRadius.circular(MmRadius.md),
                    ),
                    child: Icon(
                      icon,
                      size: 22,
                      color: planned ? c.faint : c.chipText,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MmType.labelStrong.copyWith(
                            fontSize: 14,
                            color: planned ? c.muted : c.fg,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          detail,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: MmType.caption.copyWith(
                            fontSize: 12.5,
                            color: c.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (planned)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: c.warningSubtle,
                      borderRadius: BorderRadius.circular(MmRadius.xs),
                      border: Border.all(color: c.warningBorder),
                    ),
                    child: Text(
                      t.getPlanned,
                      style: MmType.monoStyle(
                        size: 9.5,
                        color: c.warning,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHead extends StatelessWidget {
  const _SectionHead(this.title, this.link, this.onLink);

  final String title;
  final String link;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: MmType.heading.copyWith(fontSize: 16, color: c.fg),
          ),
        ),
        Pressable(
          onTap: onLink,
          semanticLabel: link,
          child: Text(
            link,
            style: MmType.labelStrong.copyWith(
              fontSize: 13,
              color: c.accentStrong,
            ),
          ),
        ),
      ],
    );
  }
}

class _ContinueSection extends ConsumerWidget {
  const _ContinueSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final resume =
        (ref.watch(homeProvider).value?.resume ?? const <ResumeItem>[])
            .take(3)
            .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHead(
          t.getContinue,
          t.getSeeLibrary,
          () => context.go(Routes.listenHome),
        ),
        const SizedBox(height: 12),
        if (resume.isEmpty)
          Text(
            t.getContinueEmpty,
            style: MmType.bodySm.copyWith(color: c.muted),
          )
        else
          LayoutBuilder(
            builder: (context, box) {
              const gap = 14.0;
              final w = (box.maxWidth - gap * 2) / 3;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, r) in resume.indexed) ...[
                    if (i > 0) const SizedBox(width: gap),
                    SizedBox(width: w, child: _ContinueCard(r)),
                  ],
                ],
              );
            },
          ),
      ],
    );
  }
}

class _ContinueCard extends ConsumerWidget {
  const _ContinueCard(this.r);

  final ResumeItem r;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final item = r.item;
    final secs = item.durationSecs ?? 0;
    final ratio = secs > 0
        ? (r.position.inMilliseconds / 1000 / secs).clamp(0.0, 1.0)
        : 0.0;
    final left = r.remaining;
    final meta = item.isVideo && left != null
        ? t.getMinutesLeft((left.inSeconds / 60).round().clamp(1, 9999))
        : (item.artist ?? '');
    return Pressable(
      onTap: () =>
          openMedia(context, ref, item, video: r.video, focus: r.focus),
      semanticLabel: t.getPlayTitle(item.title),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, box) => Stack(
              children: [
                CoverArt(
                  size: box.maxWidth,
                  aspectRatio: 16 / 9,
                  radius: MmRadius.md,
                  seed: item.id,
                  shadow: false,
                  imagePath: item.thumbnail,
                ),
                Positioned(
                  right: 8,
                  bottom: 10,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c.coral,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(PhosphorFill.play, size: 16, color: c.coralInk),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 3,
                    color: Colors.black.withValues(alpha: 0.3),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: ratio,
                      heightFactor: 1,
                      child: ColoredBox(color: c.coral),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MmType.labelStrong.copyWith(fontSize: 13, color: c.fg),
          ),
          Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MmType.caption.copyWith(fontSize: 12, color: c.muted),
          ),
        ],
      ),
    );
  }
}

class _RecentSection extends ConsumerWidget {
  const _RecentSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final done = ref
        .watch(downloadsProvider.select((s) => s.history))
        .where((h) => h.completed)
        .take(4)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHead(
          t.getRecent,
          t.getNavHistory,
          () => context.go('${Routes.getDownloads}?tab=done'),
        ),
        const SizedBox(height: 12),
        if (done.isEmpty)
          Text(t.getHomeEmpty, style: MmType.bodySm.copyWith(color: c.muted))
        else
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MmRadius.md),
              border: Border.all(color: c.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, h) in done.indexed)
                  Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: c.surface,
                      border: i == 0
                          ? null
                          : Border(top: BorderSide(color: c.line)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isAudioLabel(h.formatLabel)
                              ? PhosphorRegular.musicNote
                              : PhosphorRegular.filmStrip,
                          size: 20,
                          color: c.muted,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                h.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MmType.labelStrong.copyWith(
                                  fontSize: 13,
                                  color: c.fg,
                                ),
                              ),
                              Text(
                                [
                                  h.formatLabel,
                                  if (h.doneBytes > BigInt.zero)
                                    bytes(context, h.doneBytes.toInt()),
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MmType.monoStyle(
                                  size: 11.5,
                                  color: c.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Pressable(
                          onTap: () => playDownload(context, ref, h),
                          semanticLabel: t.getPlayTitle(h.title),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: c.coralSubtle,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              PhosphorFill.play,
                              size: 16,
                              color: c.coralStrong,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

bool _isAudioLabel(String label) => RegExp(
  r'^(MP3|M4A|FLAC|OGG|OPUS|WAV|AAC)',
  caseSensitive: false,
).hasMatch(label);

/// Plays what a finished download became in the library.
Future<void> playDownload(
  BuildContext context,
  WidgetRef ref,
  HistoryInfo h,
) async {
  final t = L10n.of(context);
  final path = h.finalPath;
  final item = path == null
      ? null
      : await ref.read(libraryApiProvider).itemByPath(path);
  if (!context.mounted) return;
  if (item == null) {
    _toast(context, t.getFileGone);
    return;
  }
  await openMedia(context, ref, item);
}

// ----------------------------------------------------------------- analysis

/// Windows v2 screen 2: formats of the pasted link.
class GetAnalysisScreen extends ConsumerStatefulWidget {
  const GetAnalysisScreen({super.key, required this.url, this.tab = 'video'});

  final String url;
  final String tab;

  @override
  ConsumerState<GetAnalysisScreen> createState() => _GetAnalysisScreenState();
}

class _GetAnalysisScreenState extends ConsumerState<GetAnalysisScreen> {
  late Future<Analysis> _analysis = _run();
  int _attempt = 0;

  Future<Analysis> _run() async {
    await ref.read(downloadsProvider.notifier).started;
    return ref.read(getApiProvider).analyze(widget.url);
  }

  void _retry() => setState(() {
    _attempt++;
    _analysis = _run();
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Analysis>(
      future: _analysis,
      builder: (context, snap) {
        final a = snap.data;
        if (snap.hasError) {
          // Technical details stay in the log, never on screen.
          debugPrint('analysis failed: ${snap.error}');
          return _Scroll(
            child: _NoMedia(detail: '', code: 'other', onRetry: _retry),
          );
        }
        if (a == null) {
          return _Scroll(
            child: _Waiting(key: ValueKey(_attempt), url: widget.url),
          );
        }
        return switch (a.status) {
          AnalysisStatus.ready => _AnalysisResult(
            info: a.info!,
            tab: widget.tab,
          ),
          AnalysisStatus.noMedia => _Scroll(
            child: _NoMedia(code: a.code, detail: a.detail, onRetry: _retry),
          ),
          AnalysisStatus.needsTools => _Scroll(
            child: _ToolsPrompt(tools: a.tools, onInstalled: _retry),
          ),
        };
      },
    );
  }
}

/// Scrolling area with the Back link (the action bar stays below it).
class _Scroll extends StatelessWidget {
  const _Scroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(48, 24, 48, 24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Pressable(
            onTap: () => context.go(Routes.get),
            semanticLabel: t.getBack,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(PhosphorRegular.arrowLeft, size: 18, color: c.muted),
                const SizedBox(width: 6),
                Text(
                  t.getBack,
                  style: MmType.labelStrong.copyWith(
                    fontSize: 13,
                    color: c.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        child,
      ],
    );
  }
}

/// The honest wait (decision 0006): what happens, how long, a tip; no fake
/// progress.
class _Waiting extends StatefulWidget {
  const _Waiting({super.key, required this.url});

  final String url;

  @override
  State<_Waiting> createState() => _WaitingState();
}

class _WaitingState extends State<_Waiting> {
  final _start = DateTime.now();
  late final Timer _tick = Timer.periodic(
    const Duration(seconds: 1),
    (_) => setState(() {}),
  );

  @override
  void initState() {
    super.initState();
    _tick;
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final elapsed = DateTime.now().difference(_start).inSeconds;
    final host = (Uri.tryParse(widget.url)?.host ?? '').replaceFirst(
      RegExp(r'^(www|m)\.'),
      '',
    );
    final stage = elapsed >= 25
        ? t.getPrepStage4
        : elapsed >= 12
        ? t.getPrepStage3
        : elapsed >= 4
        ? t.getPrepStage2
        : t.getPrepStage1(host.isEmpty ? t.getPrepThisSite : host);
    final tips = [t.getPrepTip1, t.getPrepTip2, t.getPrepTip3, t.getPrepTip4];
    final tip = tips[(elapsed ~/ 5) % tips.length];
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: c.accentSubtle,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    PhosphorRegular.downloadSimple,
                    size: 28,
                    color: c.accentStrong,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.getPrepTitle,
                        style: MmType.heading.copyWith(
                          fontSize: 17,
                          color: c.fg,
                        ),
                      ),
                      Text(
                        [
                          if (host.isNotEmpty) host,
                          t.getPrepElapsed(elapsed),
                        ].join(' · '),
                        style: MmType.monoStyle(size: 12.5, color: c.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Progress(value: null, color: c.accent),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Text(stage, style: MmType.body.copyWith(color: c.fg)),
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(PhosphorRegular.lightbulb, size: 22, color: c.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.getPrepTip,
                          style: MmType.overline.copyWith(color: c.muted),
                        ),
                        const SizedBox(height: 2),
                        Text(tip, style: MmType.bodySm.copyWith(color: c.fg)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "No downloadable media found": Miarina never bypasses logins, DRM or
/// live restrictions, and says so.
class _NoMedia extends StatelessWidget {
  const _NoMedia({
    required this.code,
    required this.detail,
    required this.onRetry,
  });

  final String code;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final reason = code == 'network'
        ? t.getWhyNetwork
        : code.startsWith('http:')
        ? t.getWhyHttp(code.substring(5))
        : code == 'platform'
        ? t.getWhyPlatform
        : detail;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Column(
            children: [
              Icon(PhosphorRegular.linkBreak, size: 40, color: c.danger),
              const SizedBox(height: 12),
              Text(
                t.getNoMediaTitle,
                textAlign: TextAlign.center,
                style: MmType.title.copyWith(fontSize: 18, color: c.fg),
              ),
              const SizedBox(height: 12),
              Text(
                t.getNoMediaBody,
                textAlign: TextAlign.center,
                style: MmType.bodySm.copyWith(height: 1.55, color: c.muted),
              ),
              if (reason.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  t.getNoMediaReason(reason),
                  textAlign: TextAlign.center,
                  style: MmType.caption.copyWith(
                    fontSize: 12.5,
                    color: c.muted,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _Button(t.getTryAgain, onRetry, height: 36),
            ],
          ),
        ),
      ),
    );
  }
}

/// Consent before downloading yt-dlp and FFmpeg (decision D3).
class _ToolsPrompt extends ConsumerStatefulWidget {
  const _ToolsPrompt({required this.tools, required this.onInstalled});

  final List<ToolStatus> tools;
  final VoidCallback onInstalled;

  @override
  ConsumerState<_ToolsPrompt> createState() => _ToolsPromptState();
}

class _ToolsPromptState extends ConsumerState<_ToolsPrompt> {
  bool _installing = false;
  String? _error;

  Future<void> _install() async {
    setState(() {
      _installing = true;
      _error = null;
    });
    try {
      await ref.read(getApiProvider).installTools();
      widget.onInstalled();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final missing = [
      for (final tool in widget.tools)
        if (!tool.installed) tool,
    ];
    final total = missing.fold<int>(0, (n, x) => n + x.downloadBytes.toInt());
    final progress = ref.watch(downloadsProvider.select((s) => s.toolProgress));
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(MmRadius.lg),
            border: Border.all(color: c.surface2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: c.surface2,
                      borderRadius: BorderRadius.circular(MmRadius.md),
                    ),
                    child: Icon(
                      PhosphorRegular.downloadSimple,
                      size: 20,
                      color: c.accentStrong,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.getToolsNeeded,
                          style: MmType.heading.copyWith(
                            fontSize: 15,
                            color: c.fg,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t.getToolsBody,
                          style: MmType.bodySm.copyWith(color: c.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (final tool in missing) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: tool.name,
                              style: MmType.labelStrong.copyWith(
                                fontSize: 13,
                                color: c.fg,
                              ),
                            ),
                            TextSpan(
                              text: '  ${tool.version} · ${tool.license}',
                              style: MmType.caption.copyWith(
                                fontSize: 13,
                                color: c.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Text(switch (progress[tool.name]) {
                      (final done, final all) => t.getBytesOf(
                        bytes(context, done),
                        bytes(context, all),
                      ),
                      null => bytes(context, tool.downloadBytes.toInt()),
                    }, style: MmType.monoStyle(size: 12.5, color: c.muted)),
                  ],
                ),
                if (_installing) ...[
                  const SizedBox(height: 6),
                  _Progress(
                    value: switch (progress[tool.name]) {
                      (final done, final all) when all > 0 => done / all,
                      _ => 0,
                    },
                    color: c.accent,
                  ),
                ],
                const SizedBox(height: 12),
              ],
              if (_error != null) ...[
                Text(
                  _error!,
                  style: MmType.caption.copyWith(
                    fontSize: 12.5,
                    color: c.danger,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Button(
                    t.getNotNow,
                    _installing ? null : () => context.go(Routes.get),
                    height: 36,
                  ),
                  _Button(
                    _installing
                        ? t.getDownloadingShort
                        : t.getDownloadTools(bytes(context, total)),
                    _installing ? null : _install,
                    primary: true,
                    height: 36,
                    icon: PhosphorRegular.downloadSimple,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalysisResult extends ConsumerStatefulWidget {
  const _AnalysisResult({required this.info, required this.tab});

  final MediaInfo info;
  final String tab;

  @override
  ConsumerState<_AnalysisResult> createState() => _AnalysisResultState();
}

class _AnalysisResultState extends ConsumerState<_AnalysisResult> {
  late String _tab = widget.tab;
  final _selected = <String, String>{};
  bool _starting = false;

  List<FormatOffer> _formats(String tab) => switch (tab) {
    'audio' => widget.info.audio,
    'video' => widget.info.video,
    _ => const [],
  };

  Future<void> _start({required bool now}) async {
    if (_starting) return;
    final t = L10n.of(context);
    final info = widget.info;
    final format = _current;
    if (format == null) return;
    setState(() => _starting = true);
    try {
      await ref
          .read(downloadsProvider.notifier)
          .start(
            StartRequest(
              url: info.url,
              title: downloadTitle(info, format),
              isAudio: _tab == 'audio',
              engine: info.engine,
              formatId: format.id == 'original' ? null : format.id,
              formatLabel: _quality(context, format),
              extension_: format.extension_,
              startNow: now,
              thumbnail: info.thumbnail,
            ),
          );
      if (!mounted) return;
      if (now) {
        context.go(Routes.getDownloads);
      } else {
        _toast(
          context,
          t.getAddedToQueue(shortQuality(format)),
          action: SnackBarAction(
            label: t.getView,
            onPressed: () => context.go(Routes.getDownloads),
          ),
        );
      }
    } catch (e) {
      if (mounted) _toast(context, '$e');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  FormatOffer? get _current {
    final formats = _formats(_tab);
    final chosen = _selected[_tab];
    for (final f in formats) {
      if (f.id == chosen) return f;
    }
    return defaultFormat(formats);
  }

  String _quality(BuildContext context, FormatOffer f) => f.id == 'original'
      ? L10n.of(context).getOriginalFile(f.quality)
      : f.quality;

  @override
  void initState() {
    super.initState();
    // A direct audio file only has an "Audio seul" format: open that tab.
    if (_formats(_tab).isEmpty) {
      for (final tab in const ['video', 'audio']) {
        if (_formats(tab).isNotEmpty) {
          _tab = tab;
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final info = widget.info;
    final formats = _formats(_tab);
    final format = _current;
    final canDownload = format != null && _tab != 'subs';
    final source = [
      info.host,
      info.publisher == info.host ? null : info.publisher,
      info.license,
    ].whereType<String>().join(' · ');
    int height(FormatOffer f) =>
        int.tryParse(RegExp(r'^\d+').stringMatch(f.quality) ?? '') ?? 0;
    final best = info.video.fold<int>(
      0,
      (n, f) => height(f) > n ? height(f) : n,
    );
    final duration = info.durationSecs;
    final dir = ref.watch(getSettingsProvider).value?.downloadDir ?? '';
    final note = _tab == 'subs'
        ? t.getSubsPlanned
        : _tab == 'audio'
        ? t.getNoteAudio
        : t.getNoteVideo;

    final tabs = [
      ('video', PhosphorRegular.filmStrip, t.getFmtVideo),
      ('audio', PhosphorRegular.musicNote, t.getQAudio),
      ('subs', PhosphorRegular.closedCaptioning, t.getFmtSubs),
    ];

    return Column(
      children: [
        Expanded(
          child: _Scroll(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Stack(
                      children: [
                        _Thumb(
                          path: info.thumbnail,
                          audio: _tab == 'audio',
                          width: 224,
                        ),
                        if (duration != null)
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(
                                  MmRadius.xs,
                                ),
                              ),
                              child: Text(
                                etaLabel(duration.round()),
                                style: MmType.monoStyle(
                                  size: 11.5,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            info.title,
                            style: MmType.display.copyWith(
                              fontSize: 22,
                              color: c.fg,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            info.engine == 'http'
                                ? '$source · ${info.supportsResume ? t.getDirectResume : t.getDirectNoResume}'
                                : source,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MmType.monoStyle(size: 12.5, color: c.muted),
                          ),
                          if (best > 0) ...[
                            const SizedBox(height: 8),
                            Container(
                              height: 26,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: c.surface2,
                                borderRadius: BorderRadius.circular(
                                  MmRadius.pill,
                                ),
                                border: Border.all(color: c.line),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    PhosphorRegular.highDefinition,
                                    size: 15,
                                    color: c.muted,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    t.getUpTo(best >= 2160 ? '4K' : '${best}p'),
                                    style: MmType.captionStrong.copyWith(
                                      fontSize: 12,
                                      color: c.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: c.line)),
                  ),
                  child: Row(
                    children: [
                      for (final (id, icon, label) in tabs) ...[
                        Pressable(
                          onTap: () => setState(() => _tab = id),
                          semanticLabel: label,
                          selected: _tab == id,
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: _tab == id
                                      ? c.accent
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  icon,
                                  size: 18,
                                  color: _tab == id ? c.fg : c.muted,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  label,
                                  style: MmType.labelStrong.copyWith(
                                    fontSize: 13.5,
                                    color: _tab == id ? c.fg : c.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 880),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (formats.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 20,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(MmRadius.lg),
                            border: Border.all(color: c.lineStrong),
                          ),
                          child: Text(switch (_tab) {
                            'video' => t.getNoVideoFormats,
                            'audio' => t.getNoAudioFormats,
                            _ => t.getNoSubsFormats,
                          }, style: MmType.bodySm.copyWith(color: c.muted)),
                        ),
                      for (final f in formats) ...[
                        _FormatRow(
                          quality: _quality(context, f),
                          detail: f.detail,
                          tag: switch (f.tag) {
                            'Recommended' => t.getTagRecommended,
                            null => null,
                            _ => t.getTagBest,
                          },
                          size: f.sizeBytes == null
                              ? '—'
                              : bytes(context, f.sizeBytes!.toInt()),
                          selected: f.id == format?.id,
                          onTap: () => setState(() => _selected[_tab] = f.id),
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        note,
                        style: MmType.caption.copyWith(color: c.muted),
                      ),
                      if (info.needsFfmpeg)
                        Text(
                          t.getNeedsFfmpeg,
                          style: MmType.caption.copyWith(color: c.warning),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 48),
          decoration: BoxDecoration(
            color: c.sidebar,
            border: Border(top: BorderSide(color: c.line)),
          ),
          child: Row(
            children: [
              Icon(PhosphorRegular.folder, size: 20, color: c.muted),
              const SizedBox(width: 12),
              Flexible(
                child: Tooltip(
                  message: dir,
                  child: Text(
                    dir,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MmType.monoStyle(size: 12.5, color: c.muted),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Pressable(
                onTap: () => pickDownloadDir(context, ref),
                semanticLabel: t.getChange,
                child: Text(
                  t.getChange,
                  style: MmType.labelStrong.copyWith(
                    fontSize: 13,
                    color: c.accentStrong,
                  ),
                ),
              ),
              const Spacer(),
              _Button(
                t.getAddToQueue,
                canDownload && !_starting ? () => _start(now: false) : null,
              ),
              const SizedBox(width: 12),
              _Button(
                _starting
                    ? t.getStarting
                    : format?.sizeBytes != null
                    ? t.getDownloadSize(
                        bytes(context, format!.sizeBytes!.toInt()),
                      )
                    : t.getDownload,
                canDownload && !_starting ? () => _start(now: true) : null,
                primary: true,
                icon: PhosphorRegular.downloadSimple,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Changer": another download folder; it must accept files.
Future<void> pickDownloadDir(BuildContext context, WidgetRef ref) async {
  final t = L10n.of(context);
  final path = await ref.read(downloadFolderPickerProvider)();
  if (path == null) return;
  try {
    await ref.read(getApiProvider).setDownloadDir(path);
    ref.invalidate(getSettingsProvider);
  } catch (_) {
    if (context.mounted) _toast(context, t.getDirRefused);
  }
}

class _FormatRow extends StatelessWidget {
  const _FormatRow({
    required this.quality,
    required this.detail,
    required this.tag,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final String quality;
  final String detail;
  final String? tag;
  final String size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: '$quality, $detail, $size',
      selected: selected,
      hoverColor: selected ? null : c.surface2,
      borderRadius: BorderRadius.circular(MmRadius.lg),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? c.accentSubtle : c.surface,
          borderRadius: BorderRadius.circular(MmRadius.lg),
          border: Border.all(color: selected ? c.accent : c.line),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? c.accent : c.faint,
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: selected
                  ? Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: c.accent,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 150,
              child: Text(
                quality,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MmType.labelStrong.copyWith(fontSize: 14, color: c.fg),
              ),
            ),
            Expanded(
              child: Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MmType.monoStyle(size: 12.5, color: c.muted),
              ),
            ),
            if (tag != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.accentSubtle,
                  borderRadius: BorderRadius.circular(MmRadius.xs),
                ),
                child: Text(
                  tag!,
                  style: MmType.captionStrong.copyWith(
                    fontSize: 11,
                    color: c.chipText,
                  ),
                ),
              ),
            SizedBox(
              width: 84,
              child: Text(
                size,
                textAlign: TextAlign.end,
                style: MmType.monoStyle(size: 12.5, color: c.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- downloads

/// Icon + words for each state (DL-02, DL-06): conversion is its own step,
/// and a resume is only promised when the source supports it.
({IconData icon, String text, Color color, String detail}) statusOf(
  BuildContext context,
  DownloadTask task,
  DateTime now,
) {
  final c = MmColors.of(context);
  final t = L10n.of(context);
  final lang = _lang(context);
  final pct = task.percent.floor();
  final resumeAt = task.supportsResume && task.downloaded > 0
      ? t.getStResumeAt(pct)
      : '';
  if (task.offline) {
    return (
      icon: PhosphorRegular.wifiSlash,
      text: t.getStOffline,
      color: c.warning,
      detail: resumeAt,
    );
  }
  if (task.retrying) {
    return (
      icon: PhosphorRegular.wifiSlash,
      text: t.getStRetry(retryIn(task, now)),
      color: c.danger,
      detail: resumeAt,
    );
  }
  final ext = task.info.fileName.contains('.')
      ? task.info.fileName.split('.').last.toUpperCase()
      : '';
  switch (task.state) {
    case 'downloading':
      final parts = [
        task.total != null
            ? '${formatBytes(task.downloaded, lang: lang)} / ${formatBytes(task.total!, lang: lang)}'
            : formatBytes(task.downloaded, lang: lang),
        if (task.bytesPerSec > 0) formatSpeed(task.bytesPerSec, lang: lang),
        if (task.etaSecs != null) etaLabel(task.etaSecs!),
      ];
      return (
        icon: PhosphorRegular.downloadSimple,
        text: task.bytesPerSec > 0 ? t.getStDownloading : t.getStarting,
        color: c.accentStrong,
        detail: parts.join(' · '),
      );
    case 'processing':
      return (
        icon: PhosphorRegular.arrowsClockwise,
        text: ext.isEmpty
            ? t.getStConverting
            : task.info.isAudio
            ? t.getStConvertingTo(ext)
            : t.getStFinalizing(ext),
        color: c.accentStrong,
        detail: t.getStStep,
      );
    case 'paused':
      return (
        icon: PhosphorRegular.pauseCircle,
        text: task.supportsResume || task.downloaded == 0
            ? t.getStPaused
            : t.getStPausedRestart,
        color: c.warning,
        detail: task.total != null
            ? formatBytes(task.total!, lang: lang)
            : '$pct %',
      );
    case 'failed':
      final code = task.info.errorCode;
      final disk = code == 'disk_full' || code == 'insufficient_space';
      final denied = code == 'access_denied';
      return (
        icon: PhosphorRegular.warningCircle,
        text: disk
            ? t.getStDiskFull
            : denied
            ? t.getStAccessDenied
            : t.getStFailed,
        color: c.danger,
        detail: [
          resumeAt,
          if (disk) t.getStDiskFullHint,
          if (denied) t.getStAccessDeniedHint,
        ].where((s) => s.isNotEmpty).join(' · '),
      );
    case 'analyzing':
      return (
        icon: PhosphorRegular.hourglass,
        text: t.getStAnalyzing,
        color: c.muted,
        detail: '',
      );
    default:
      return (
        icon: PhosphorRegular.clock,
        text: t.getStQueued,
        color: c.muted,
        detail: task.total != null ? formatBytes(task.total!, lang: lang) : '',
      );
  }
}

/// Reason of a failed download in the interface language when the engine
/// failure is a known one (the stored reason is the engine's English).
String? failureReason(String? reason, L10n t) {
  if (reason == null) return null;
  if (reason.startsWith('the disk is full')) return t.getWhyDiskFull;
  if (reason.startsWith('not enough free space')) return t.getWhyNoSpace;
  if (reason.startsWith('the destination folder cannot be written to')) {
    return t.getWhyDenied;
  }
  return reason;
}

/// Windows v2 screen 3: active, done and failed downloads.
class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key, this.tab = 'active'});

  /// active, done or failed.
  final String tab;

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  late String _tab = widget.tab;
  Timer? _clock;

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final state = ref.watch(downloadsProvider);
    final summary = ref.watch(downloadsSummaryProvider);
    final lang = _lang(context);
    final all = state.ordered;
    final active = [
      for (final x in all)
        if (x.open && x.state != 'failed') x,
    ];
    final failedTasks = [
      for (final x in all)
        if (x.state == 'failed') x,
    ];
    // A download the user canceled is not a failure.
    final failedHistory = [
      for (final h in state.history)
        if (!h.completed && !h.canceled) h,
    ];
    final done = [
      for (final h in state.history)
        if (h.completed) h,
    ];
    final queuedIds = [
      for (final x in active)
        if (x.queued) x.id,
    ];
    final anyRunning = active.any((x) => x.running);
    final anyPaused = active.any((x) => x.state == 'paused');
    // A retry countdown needs the clock.
    final counting = all.any((x) => x.retrying);
    if (counting && _clock == null) {
      _clock = Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() {}),
      );
    } else if (!counting && _clock != null) {
      _clock!.cancel();
      _clock = null;
    }
    final settings = ref.watch(getSettingsProvider).value;
    final subtitle = anyRunning
        ? t.getDlSubRunning(
            summary.running.length,
            formatSpeed(summary.speed, lang: lang),
          )
        : anyPaused
        ? t.getDlSubPaused
        : t.getDlSubIdle((settings?.maxDownloads ?? 3).toInt());
    final counts = {
      'active': active.length,
      'done': done.length,
      'failed': failedTasks.length + failedHistory.length,
    };
    final rows = <Widget>[
      if (_tab == 'active')
        for (final x in active) _TaskRow(task: x, queuedIds: queuedIds),
      if (_tab == 'failed') ...[
        for (final x in failedTasks) _TaskRow(task: x),
        for (final h in failedHistory) _FailedHistoryRow(entry: h),
      ],
      if (_tab == 'done')
        for (final h in done) _DoneRow(entry: h),
    ];
    final now = DateTime.now();
    return ListView(
      padding: const EdgeInsets.fromLTRB(48, 32, 48, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.getNavDownloads,
                    style: MmType.display.copyWith(fontSize: 24, color: c.fg),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: MmType.bodySm.copyWith(color: c.muted)),
                ],
              ),
            ),
            _Button(
              anyRunning || !anyPaused ? t.getPauseAll : t.getResumeAll,
              !anyRunning && !anyPaused
                  ? null
                  : () => ref
                        .read(downloadsProvider.notifier)
                        .pauseAll(anyRunning),
              icon: anyRunning || !anyPaused
                  ? PhosphorRegular.pause
                  : PhosphorRegular.play,
              height: 36,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: c.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (id, label) in [
                  ('active', t.getTabActive(counts['active']!)),
                  ('done', t.getTabDone(counts['done']!)),
                  ('failed', t.getTabFailed(counts['failed']!)),
                ])
                  Pressable(
                    onTap: () => setState(() => _tab = id),
                    semanticLabel: label,
                    selected: _tab == id,
                    child: Container(
                      height: 30,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _tab == id ? c.lineStrong : Colors.transparent,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        label,
                        style: MmType.labelStrong.copyWith(
                          fontSize: 12.5,
                          color: _tab == id ? c.fg : c.muted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        for (final row in rows) ...[row, const SizedBox(height: 8)],
        if (rows.isEmpty)
          Container(
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MmRadius.md),
              border: Border.all(color: c.lineStrong),
            ),
            child: Text(
              t.getDlNothing,
              textAlign: TextAlign.center,
              style: MmType.bodySm.copyWith(color: c.muted),
            ),
          ),
        // Rebuilt every second while a retry is counted down.
        if (counting) SizedBox.shrink(key: ValueKey(now.second)),
      ],
    );
  }
}

class _Action {
  const _Action(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
}

class _TaskRow extends ConsumerWidget {
  const _TaskRow({required this.task, this.queuedIds = const []});

  final DownloadTask task;

  /// Waiting tasks in queue order (they can be reordered).
  final List<String> queuedIds;

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
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
          t.getCancelTitle,
          style: MmType.title.copyWith(color: c.fg),
        ),
        content: Text(
          t.getCancelBody(task.info.title),
          style: MmType.body.copyWith(color: c.fgSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              t.getKeepDownloading,
              style: MmType.labelStrong.copyWith(color: c.fg),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              t.getCancelConfirm,
              style: MmType.labelStrong.copyWith(color: c.danger),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(downloadsProvider.notifier).action(task.id, 'cancel');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final title = task.info.title;
    final status = statusOf(context, task, DateTime.now());
    final busy = task.state == 'processing' || task.state == 'analyzing';
    final controller = ref.read(downloadsProvider.notifier);
    void act(String a) => controller.action(task.id, a);
    final main = task.state == 'failed'
        ? _Action(
            PhosphorRegular.arrowClockwise,
            t.getActRetry(title),
            () => act('retry'),
          )
        : task.state == 'paused'
        ? _Action(
            PhosphorRegular.play,
            t.getActResume(title),
            () => act('resume'),
          )
        : task.queued
        ? _Action(
            PhosphorRegular.play,
            t.getActStart(title),
            () => act('start_now'),
          )
        : _Action(
            PhosphorRegular.pause,
            busy ? t.getCannotPause : t.getActPause(title),
            busy ? null : () => act('pause'),
          );
    final actions = [
      main,
      // Partial data kept: a resume is tried first; starting over is a
      // separate, explicit choice (PAR-04).
      if (task.state == 'failed' && task.downloaded > 0)
        _Action(
          PhosphorRegular.arrowCounterClockwise,
          t.getActRestart(title),
          () => act('restart'),
        ),
      _Action(
        PhosphorRegular.folderOpen,
        t.getOpenFolder,
        () => ref.read(revealProvider)(task.info.destDir),
      ),
      task.state == 'failed'
          ? _Action(
              PhosphorRegular.x,
              t.getRemoveNamed(title),
              () => act('cancel'),
            )
          : _Action(
              PhosphorRegular.x,
              t.getCancelNamed(title),
              () => _confirmCancel(context, ref),
            ),
    ];
    final value = task.state == 'queued'
        ? 0.0
        : task.state == 'processing' ||
              (task.state == 'downloading' && task.total == null)
        ? null
        : task.percent / 100;
    final barColor = task.state == 'failed' || task.retrying
        ? c.danger
        : task.state == 'paused'
        ? c.muted
        : c.accent;
    return _Row(
      thumbnail: task.info.thumbnail,
      audio: task.info.isAudio,
      title: title,
      format: task.info.formatLabel,
      status: status,
      percent: task.state == 'queued' ? null : '${task.percent.floor()}%',
      progress: _Progress(value: value, color: barColor),
      actions: actions,
      reorder: task.queued
          ? _Reorder(
              id: task.id,
              label: t.getReorderNamed(title),
              onMove: (delta) {
                final at = queuedIds.indexOf(task.id);
                final to = at + delta;
                if (at >= 0 && to >= 0 && to < queuedIds.length) {
                  _moveTo(ref, task.id, queuedIds[to]);
                }
              },
              onDrop: (from) => _moveTo(ref, from, task.id),
            )
          : null,
    );
  }
}

/// Moves `id` to the place of `target` in the manager's order of open
/// tasks (as the Tauri app).
void _moveTo(WidgetRef ref, String id, String target) {
  if (id == target) return;
  final open = [
    for (final t in ref.read(downloadsProvider).ordered)
      if (t.open) t.id,
  ];
  final index = open.indexOf(target);
  if (index >= 0) ref.read(downloadsProvider.notifier).move(id, index);
}

class _DoneRow extends ConsumerWidget {
  const _DoneRow({required this.entry});

  final HistoryInfo entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final path = entry.finalPath;
    return _Row(
      thumbnail: null,
      audio: _isAudioLabel(entry.formatLabel),
      title: entry.title,
      format: entry.formatLabel,
      status: (
        icon: PhosphorRegular.checkCircle,
        text: t.getStDone,
        color: c.accentStrong,
        detail: bytes(context, entry.doneBytes.toInt()),
      ),
      percent: '100%',
      progress: _Progress(value: 1, color: c.accent),
      actions: [
        _Action(
          PhosphorRegular.play,
          t.getPlayTitle(entry.title),
          () => playDownload(context, ref, entry),
        ),
        _Action(
          PhosphorRegular.folderOpen,
          t.getShowInFolder,
          path == null
              ? null
              : () => ref.read(revealProvider)(path, select: true),
        ),
      ],
    );
  }
}

class _FailedHistoryRow extends StatelessWidget {
  const _FailedHistoryRow({required this.entry});

  final HistoryInfo entry;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    return _Row(
      thumbnail: null,
      audio: _isAudioLabel(entry.formatLabel),
      title: entry.title,
      format: entry.formatLabel,
      status: (
        icon: PhosphorRegular.warningCircle,
        text: failureReason(entry.reason, t) ?? t.getStFailed,
        color: c.danger,
        detail: '',
      ),
      percent: null,
      progress: null,
      actions: const [],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.thumbnail,
    required this.audio,
    required this.title,
    required this.format,
    required this.status,
    required this.percent,
    required this.progress,
    required this.actions,
    this.reorder,
  });

  final String? thumbnail;
  final bool audio;
  final String title;
  final String format;
  final ({IconData icon, String text, Color color, String detail}) status;
  final String? percent;
  final Widget? progress;
  final List<_Action> actions;

  /// Waiting rows: the thumbnail is a handle (Alt + arrows, or drag it
  /// onto another waiting row).
  final _Reorder? reorder;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(MmRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          reorder == null
              ? _Thumb(path: thumbnail, audio: audio, width: 72)
              : _Handle(
                  reorder: reorder!,
                  thumb: _Thumb(path: thumbnail, audio: audio, width: 72),
                ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MmType.labelStrong.copyWith(
                          fontSize: 13.5,
                          color: c.fg,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      format,
                      style: MmType.monoStyle(size: 11.5, color: c.muted),
                    ),
                  ],
                ),
                if (progress != null) ...[const SizedBox(height: 8), progress!],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(status.icon, size: 15, color: status.color),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        status.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MmType.captionStrong.copyWith(
                          fontSize: 12,
                          color: status.color,
                        ),
                      ),
                    ),
                    if (status.detail.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        status.detail,
                        style: MmType.monoStyle(size: 12, color: c.muted),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              percent ?? '',
              textAlign: TextAlign.end,
              style: MmType.monoStyle(size: 12.5, color: c.muted),
            ),
          ),
          const SizedBox(width: 16),
          for (final a in actions)
            Tooltip(
              message: a.label,
              child: Pressable(
                onTap: a.onTap,
                semanticLabel: a.label,
                hoverColor: c.line,
                borderRadius: BorderRadius.circular(MmRadius.sm),
                child: Opacity(
                  opacity: a.onTap == null ? 0.4 : 1,
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: Icon(a.icon, size: 20, color: c.muted),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    final r = reorder;
    if (r == null) return row;
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data != r.id,
      onAcceptWithDetails: (d) => r.onDrop(d.data),
      builder: (context, candidates, _) => candidates.isEmpty
          ? row
          : DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(MmRadius.lg),
                border: Border.all(color: c.accent, width: 2),
              ),
              child: row,
            ),
    );
  }
}

/// How a waiting row moves in the queue.
class _Reorder {
  const _Reorder({
    required this.id,
    required this.label,
    required this.onMove,
    required this.onDrop,
  });

  final String id;
  final String label;

  /// -1 up, 1 down (Alt + arrows).
  final void Function(int delta) onMove;

  /// Another waiting row dropped on this one.
  final void Function(String from) onDrop;
}

class _Handle extends StatefulWidget {
  const _Handle({required this.reorder, required this.thumb});

  final _Reorder reorder;
  final Widget thumb;

  @override
  State<_Handle> createState() => _HandleState();
}

class _HandleState extends State<_Handle> {
  bool _focused = false;
  final _focus = FocusNode(debugLabel: 'reorder');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final r = widget.reorder;
    return Tooltip(
      message: r.label,
      child: Draggable<String>(
        data: r.id,
        // Vertical, as the list: a plain click stays a click (focus).
        affinity: Axis.vertical,
        feedback: Opacity(opacity: 0.85, child: widget.thumb),
        childWhenDragging: Opacity(opacity: 0.4, child: widget.thumb),
        child: Focus(
          focusNode: _focus,
          onFocusChange: (f) => setState(() => _focused = f),
          onKeyEvent: (node, e) {
            if (e is! KeyDownEvent || !HardwareKeyboard.instance.isAltPressed) {
              return KeyEventResult.ignored;
            }
            if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
              r.onMove(-1);
              return KeyEventResult.handled;
            }
            if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
              r.onMove(1);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Semantics(
            label: r.label,
            button: true,
            child: Listener(
              // A press selects the handle for Alt + arrows (raw pointer:
              // the drag recognizer does not compete with it).
              onPointerDown: (_) => _focus.requestFocus(),
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(MmRadius.md),
                    border: Border.all(
                      color: _focused ? c.accent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: widget.thumb,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
