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
import '../../design/widgets/pressable.dart';
import '../../l10n/app_localizations.dart';
import '../cinema/cinema_widgets.dart' show PillSegment;
import '../get/get_screens.dart' show bytes;
import 'convert_data.dart';

// Outils PC › Convertir (design_handoff_outils_pc, screen 4): categories
// on the left, the conversion queue on the right, a status bar below. The
// handoff describes the Tauri app; it is rebuilt here with the same tokens.

/// "Ajouter des fichiers": the files chosen (tests answer it).
final convertFilePickerProvider =
    Provider<Future<List<String>> Function(String label, List<String> ext)>(
      (_) =>
          (label, ext) async => [
            for (final f in await openFiles(
              acceptedTypeGroups: [XTypeGroup(label: label, extensions: ext)],
            ))
              f.path,
          ],
    );

String _clock(Duration d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
}

String choiceLabel(L10n t, ConvertChoice c) => switch (c.target) {
  'join' => t.toolJoin,
  'cut' => t.toolCut,
  'crop' => t.toolCrop,
  'compress' => t.toolCompress,
  'frames' => t.toolFrames,
  'record' => t.toolRecord,
  'extract' => t.toolExtract,
  'resize' => t.toolResize,
  final f => '→ ${f.toUpperCase()}',
};

String choiceHelp(L10n t, ConvertChoice c) => switch (c.target) {
  'mp4' => t.fmtHelpMp4,
  'mkv' => t.fmtHelpMkv,
  'webm' => t.fmtHelpWebm,
  'avi' => t.fmtHelpAvi,
  '3gp' => t.fmtHelp3gp,
  'mov' => t.fmtHelpMov,
  'gif' => t.fmtHelpGif,
  'mp3' => t.fmtHelpMp3,
  'm4a' => t.fmtHelpM4a,
  'flac' => t.fmtHelpFlac,
  'wav' => t.fmtHelpWav,
  'ogg' => t.fmtHelpOgg,
  'opus' => t.fmtHelpOpus,
  'png' => t.fmtHelpPng,
  'jpg' => t.fmtHelpJpg,
  'webp' => t.fmtHelpWebp,
  'ico' => t.fmtHelpIco,
  'bmp' => t.fmtHelpBmp,
  'join' =>
    c.category == ConvertCategory.video
        ? t.toolHelpJoinVideo
        : t.toolHelpJoinAudio,
  'cut' => t.toolHelpCut,
  'crop' => t.toolHelpCrop,
  'compress' => t.toolHelpCompress,
  'frames' => t.toolHelpFrames,
  'record' => t.toolHelpRecord,
  'extract' => t.toolHelpExtract,
  _ => t.toolHelpResize,
};

IconData _toolIcon(String target) => switch (target) {
  'join' => PhosphorRegular.arrowsMerge,
  'cut' => PhosphorRegular.scissors,
  'crop' => PhosphorRegular.crop,
  'compress' => PhosphorRegular.fileZip,
  'frames' => PhosphorRegular.images,
  'record' => PhosphorRegular.record,
  'extract' => PhosphorRegular.waveform,
  _ => PhosphorRegular.arrowsOutSimple,
};

IconData _categoryIcon(ConvertCategory c) => switch (c) {
  ConvertCategory.video => PhosphorRegular.filmStrip,
  ConvertCategory.audio => PhosphorRegular.musicNote,
  ConvertCategory.image => PhosphorRegular.image,
};

String _categoryLabel(L10n t, ConvertCategory c) => switch (c) {
  ConvertCategory.video => t.catVideo,
  ConvertCategory.audio => t.catAudio,
  ConvertCategory.image => t.catImage,
};

/// The handoff's category tints (text, ground).
(Color, Color) _tint(MmColors c, ConvertCategory cat) {
  final dark = c.brightness == Brightness.dark;
  return switch (cat) {
    ConvertCategory.video => (c.chipText, c.accentSubtle),
    ConvertCategory.audio =>
      dark
          ? (const Color(0xFF8FB3D9), const Color(0xFF242424))
          : (const Color(0xFF2F5F8F), const Color(0xFFE3EDF7)),
    ConvertCategory.image =>
      dark
          ? (const Color(0xFFE8B04B), const Color(0xFF2B2616))
          : (const Color(0xFF8A5D00), const Color(0xFFFBF0D9)),
  };
}

ConvertCategory _categoryOf(String name) =>
    ConvertCategory.values.asNameMap()[name] ?? ConvertCategory.video;

class ConvertScreen extends ConsumerStatefulWidget {
  const ConvertScreen({super.key});

  @override
  ConsumerState<ConvertScreen> createState() => _ConvertScreenState();
}

class _ConvertScreenState extends ConsumerState<ConvertScreen> {
  ConvertCategory? _open = ConvertCategory.video;
  StreamSubscription<ConvertEnd>? _ended;

  @override
  void initState() {
    super.initState();
    _ended = ref.read(convertProvider.notifier).ended.listen(_onEnd);
    // A recording sent here: say what to do with it.
    if (ref.read(convertPendingProvider).isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _toast(L10n.of(context).recConvertPick);
      });
    }
  }

  @override
  void dispose() {
    _ended?.cancel();
    super.dispose();
  }

  void _toast(String text, {SnackBarAction? action}) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          action: action,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  Future<void> _onEnd(ConvertEnd end) async {
    if (!mounted || end != ConvertEnd.finished) return;
    final t = L10n.of(context);
    final s = ref.read(convertProvider);
    if (s.notify) {
      _toast(
        t.convDone,
        action: SnackBarAction(
          label: t.convOpenFolder,
          onPressed: () => Process.run('explorer.exe', [s.outDir]),
        ),
      );
    }
    if (s.shutdown) {
      await shutdownPc();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          final c = MmColors.of(ctx);
          return AlertDialog(
            backgroundColor: c.surface2,
            title: Text(
              t.convShutdownTitle,
              style: MmType.title.copyWith(color: c.fg),
            ),
            content: Text(
              t.convShutdownBody,
              style: MmType.body.copyWith(color: c.fgSoft),
            ),
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: const Color(0xFF062320),
                ),
                onPressed: () {
                  cancelShutdown();
                  ref.read(convertProvider.notifier).setShutdown(false);
                  Navigator.of(ctx).pop();
                },
                child: Text(t.convShutdownCancel, style: MmType.labelStrong),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _choose(ConvertChoice choice) async {
    if (choice.target == 'record') {
      context.go(Routes.recorder);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => _ChoiceDialog(choice: choice),
    );
  }

  Future<void> _remove() async {
    final t = L10n.of(context);
    final s = ref.read(convertProvider);
    final job = s.jobs.where((j) => j.id == s.selected).firstOrNull;
    if (job == null) return;
    if (job.state == 'converting') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final c = MmColors.of(ctx);
          return AlertDialog(
            backgroundColor: c.surface2,
            content: Text(
              t.convRemoveRunning(job.name),
              style: MmType.body.copyWith(color: c.fgSoft),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(t.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(t.convRemove, style: TextStyle(color: c.danger)),
              ),
            ],
          );
        },
      );
      if (ok != true) return;
    }
    await ref.read(convertProvider.notifier).remove(job.id);
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final s = ref.watch(convertProvider);
    final ctl = ref.read(convertProvider.notifier);
    final available = ref.watch(convertApiProvider) != null;
    ref.listen(droppedFilesProvider, (_, next) async {
      final files = next.value;
      if (files == null || files.isEmpty) return;
      final ok = await ctl.addDropped(files);
      if (!ok && mounted) _toast(t.convDropNoChoice);
    });

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.navConvert, style: MmType.titleLg.copyWith(color: c.fg)),
                const SizedBox(height: 4),
                Text(t.convLead, style: MmType.bodySm.copyWith(color: c.muted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _ToolButton(
            label: t.convRemove,
            icon: PhosphorRegular.minusCircle,
            onTap: s.selected == null ? null : _remove,
          ),
          const SizedBox(width: 8),
          _ToolButton(
            label: t.convClear,
            icon: PhosphorRegular.broom,
            onTap: s.jobs.isEmpty ? null : ctl.clear,
          ),
          Container(
            width: 1,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: c.line,
          ),
          if (s.running)
            _ToolButton(
              label: t.convStop,
              icon: PhosphorFill.stop,
              iconColor: c.danger,
              onTap: ctl.stop,
            )
          else
            _ToolButton(
              label: t.convStart,
              icon: PhosphorFill.play,
              primary: true,
              onTap: available && s.hasWork ? ctl.start : null,
            ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        if (!available)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
            child: Text(
              t.convToolsMissing,
              style: MmType.bodySm.copyWith(color: c.warning),
            ),
          ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.divider)),
            ),
            child: LayoutBuilder(
              builder: (context, box) {
                final left = (box.maxWidth * 0.3).clamp(232.0, 360.0);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: left,
                      decoration: BoxDecoration(
                        border: Border(right: BorderSide(color: c.divider)),
                      ),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          for (final cat in ConvertCategory.values)
                            _CategoryCard(
                              category: cat,
                              open: _open == cat,
                              onToggle: () => setState(
                                () => _open = _open == cat ? null : cat,
                              ),
                              onChoose: available ? _choose : null,
                            ),
                        ],
                      ),
                    ),
                    const Expanded(child: _Queue()),
                  ],
                );
              },
            ),
          ),
        ),
        _StatusBar(state: s),
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
    this.iconColor,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final fg = primary ? const Color(0xFF062320) : c.fg;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      borderRadius: BorderRadius.circular(MmRadius.sm),
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          height: primary ? 40 : 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: primary ? c.accent : c.surface2,
            borderRadius: BorderRadius.circular(MmRadius.sm),
            border: primary ? null : Border.all(color: c.lineStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: iconColor ?? fg),
              const SizedBox(width: 8),
              Text(
                label,
                style: MmType.labelStrong.copyWith(fontSize: 13.5, color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.open,
    required this.onToggle,
    required this.onChoose,
  });

  final ConvertCategory category;
  final bool open;
  final VoidCallback onToggle;
  final ValueChanged<ConvertChoice>? onChoose;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final (tint, ground) = _tint(c, category);
    final choices = convertCatalog[category]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: open ? c.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(MmRadius.xl),
        border: Border.all(color: open ? c.line : Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Pressable(
            onTap: onToggle,
            semanticLabel: _categoryLabel(t, category),
            selected: open,
            hoverColor: c.cardHover,
            borderRadius: BorderRadius.circular(MmRadius.lg),
            child: SizedBox(
              height: 40,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Icon(_categoryIcon(category), size: 20, color: tint),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _categoryLabel(t, category),
                        style: MmType.labelStrong.copyWith(color: c.fg),
                      ),
                    ),
                    Text(
                      '${choices.length}',
                      style: MmType.monoStyle(size: 11.5, color: c.faint),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      open
                          ? PhosphorRegular.caretUp
                          : PhosphorRegular.caretDown,
                      size: 16,
                      color: c.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
              child: LayoutBuilder(
                builder: (context, box) {
                  final columns = (box.maxWidth / 84).floor().clamp(2, 6);
                  final w = (box.maxWidth - 6 * (columns - 1)) / columns;
                  return Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final choice in choices)
                        SizedBox(
                          width: w,
                          child: _ChoiceTile(
                            choice: choice,
                            tint: tint,
                            ground: ground,
                            onTap: onChoose == null
                                ? null
                                : () => onChoose!(choice),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.choice,
    required this.tint,
    required this.ground,
    required this.onTap,
  });

  final ConvertChoice choice;
  final Color tint;
  final Color ground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final label = choice.tool
        ? choiceLabel(t, choice)
        : '→ ${choice.target.toUpperCase()}';
    return Pressable(
      onTap: onTap,
      tooltip: choiceHelp(t, choice),
      semanticLabel: '$label, ${choiceHelp(t, choice)}',
      hoverColor: c.cardHover,
      borderRadius: BorderRadius.circular(MmRadius.lg),
      child: Container(
        height: 88,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: BorderRadius.circular(MmRadius.lg),
          border: Border.all(color: c.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (choice.tool)
              Container(
                width: 44,
                height: 28,
                decoration: BoxDecoration(
                  color: c.surface2,
                  borderRadius: BorderRadius.circular(MmRadius.sm),
                ),
                child: Icon(_toolIcon(choice.target), size: 20, color: c.muted),
              )
            else
              Container(
                height: 28,
                constraints: const BoxConstraints(minWidth: 44),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ground,
                  borderRadius: BorderRadius.circular(MmRadius.sm),
                ),
                child: Text(
                  choice.target.toUpperCase(),
                  style: MmType.monoStyle(
                    size: 11.5,
                    color: tint,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: MmType.captionStrong.copyWith(
                fontSize: 12,
                height: 15 / 12,
                color: c.fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- dialog

class _ChoiceDialog extends ConsumerStatefulWidget {
  const _ChoiceDialog({required this.choice});

  final ConvertChoice choice;

  @override
  ConsumerState<_ChoiceDialog> createState() => _ChoiceDialogState();
}

class _ChoiceDialogState extends ConsumerState<_ChoiceDialog> {
  final _files = <String>[];
  String _quality = 'source';
  int _height = 0;
  int _kbps = 192;
  String _crop = '16:9';
  int _every = 10;
  int _width = 1280;
  // Compresser: AV1 by quality unless asked otherwise.
  String _codec = 'av1';
  bool _bySize = false;
  final _targetSize = TextEditingController();
  final _from = TextEditingController(text: '00:00:00');
  final _to = TextEditingController();
  bool _adding = false;

  ConvertChoice get _c => widget.choice;

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    _targetSize.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (_c.target == 'compress') _quality = 'medium';
    // A recording sent here: it waits in this dialog.
    final pending = ref.read(convertPendingProvider);
    for (final p in pending) {
      if (convertAccepts(_c.category, p) && !_files.contains(p)) _files.add(p);
    }
    // Taken once (not while the dialog is being built).
    if (pending.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(convertPendingProvider.notifier).set(const []),
      );
    }
  }

  void _addFiles(Iterable<String> paths) {
    setState(() {
      for (final p in paths) {
        if (convertAccepts(_c.category, p) && !_files.contains(p)) {
          _files.add(p);
        }
      }
    });
  }

  Future<void> _pickFiles() async {
    final files = await ref.read(convertFilePickerProvider)(
      _categoryLabel(L10n.of(context), _c.category),
      convertExtensions[_c.category]!,
    );
    _addFiles(files);
  }

  Future<void> _pickFolder() async {
    final dir = await getDirectoryPath();
    if (dir == null) return;
    final found = <String>[];
    try {
      await for (final e in Directory(dir).list()) {
        if (e is File) found.add(e.path);
        if (found.length > 500) break;
      }
    } catch (_) {}
    found.sort();
    _addFiles(found);
  }

  Future<void> _changeDir() async {
    final dir = await getDirectoryPath(
      initialDirectory: ref.read(convertProvider).outDir,
    );
    if (dir != null) await ref.read(convertProvider.notifier).setOutDir(dir);
  }

  /// "hh:mm:ss" (or "mm:ss", "ss") in ms; null when unreadable.
  static int? _parse(String text) {
    final parts = text.trim().split(':');
    if (text.trim().isEmpty || parts.length > 3) return null;
    var total = 0.0;
    for (final p in parts) {
      final v = double.tryParse(p.replaceAll(',', '.'));
      if (v == null || v < 0) return null;
      total = total * 60 + v;
    }
    return (total * 1000).round();
  }

  Future<void> _add() async {
    final t = L10n.of(context);
    if (_files.isEmpty || _adding) return;
    if (_c.joins && _files.length < 2) {
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(t.convJoinNeedsTwo)));
      return;
    }
    var from = 0;
    var to = 0;
    if (_c.target == 'cut') {
      from = _parse(_from.text) ?? 0;
      to = _to.text.trim().isEmpty ? 0 : (_parse(_to.text) ?? 0);
      if (to != 0 && to <= from) to = 0;
    }
    final ctl = ref.read(convertProvider.notifier);
    final options = ctl.optionsFor(
      quality: _quality,
      height: _height,
      audioKbps: _kbps,
      fromMs: from,
      toMs: to,
      crop: _c.target == 'crop' ? _crop : '',
      frameEvery: _c.target == 'frames' ? _every : 0,
      width: _c.target == 'resize' ? _width : 0,
      codec: _codec,
      targetMb: _c.target == 'compress' && _bySize
          ? (int.tryParse(_targetSize.text.trim()) ?? 0).clamp(0, 100000)
          : 0,
    );
    setState(() => _adding = true);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await ctl.add(_c, List.of(_files), options);
      nav.pop();
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(t.convFailed('$e'))));
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final (tint, ground) = _tint(c, _c.category);
    final outDir = ref.watch(convertProvider).outDir;
    final video = _c.category == ConvertCategory.video;
    final audio = _c.category == ConvertCategory.audio;
    final lossless = ['flac', 'wav'].contains(_c.target);

    Widget row(String label, Widget control) => Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: MmType.labelStrong.copyWith(fontSize: 13.5, color: c.fg),
            ),
          ),
          control,
        ],
      ),
    );
    Widget time(TextEditingController ctl, String hint, Key key) => SizedBox(
      width: 100,
      height: 36,
      child: TextField(
        key: key,
        controller: ctl,
        style: MmType.monoStyle(size: 12.5, color: c.fg),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9:.,]')),
        ],
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: MmType.monoStyle(size: 12.5, color: c.faint),
          filled: true,
          fillColor: c.bg,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(MmRadius.sm),
            borderSide: BorderSide(color: c.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(MmRadius.sm),
            borderSide: BorderSide(color: c.line),
          ),
        ),
      ),
    );

    final options = <Widget>[
      if (video &&
          [
            'mp4',
            'mkv',
            'webm',
            'avi',
            'mov',
            '3gp',
            'join',
            'crop',
          ].contains(_c.target))
        row(
          t.optQuality,
          PillSegment<String>(
            values: [
              ('source', t.optSource),
              ('high', t.optHigh),
              ('medium', t.optMedium),
              ('small', t.optSmall),
            ],
            selected: _quality,
            onChanged: (v) => setState(() => _quality = v),
          ),
        ),
      if (_c.target == 'compress') ...[
        row(
          t.optCodec,
          PillSegment<String>(
            values: [('av1', t.optCodecAv1), ('h264', t.optCodecH264)],
            selected: _codec,
            onChanged: (v) => setState(() => _codec = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            _codec == 'av1' ? t.optCodecAv1Note : t.optCodecH264Note,
            style: MmType.caption.copyWith(fontSize: 12, color: c.muted),
          ),
        ),
        row(
          t.optGoal,
          PillSegment<bool>(
            values: [(false, t.optGoalQuality), (true, t.optGoalSize)],
            selected: _bySize,
            onChanged: (v) => setState(() => _bySize = v),
          ),
        ),
        if (_bySize)
          row(
            t.optTargetMb,
            SizedBox(
              width: 120,
              child: TextField(
                key: const ValueKey('compress-size'),
                controller: _targetSize,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '200',
                  suffixText: t.optMb,
                ),
              ),
            ),
          )
        else
          row(
            t.optQuality,
            PillSegment<String>(
              values: [
                ('high', t.optHigh),
                ('medium', t.optBalanced),
                ('small', t.optSmall),
              ],
              selected: _quality,
              onChanged: (v) => setState(() => _quality = v),
            ),
          ),
      ],
      if (video && !['cut', 'crop'].contains(_c.target))
        row(
          t.optResolution,
          PillSegment<int>(
            // 3GP: small phones' sizes (480p at most).
            values: _c.target == '3gp'
                ? const [
                    (0, '480p'),
                    (360, '360p'),
                    (240, '240p'),
                    (144, '144p'),
                  ]
                : [
                    (0, t.optSource),
                    (1080, '1080p'),
                    (720, '720p'),
                    (480, '480p'),
                  ],
            selected: _height,
            onChanged: (v) => setState(() => _height = v),
          ),
        ),
      if (_c.target == 'crop')
        row(
          t.optCrop,
          PillSegment<String>(
            values: const [
              ('16:9', '16:9'),
              ('4:3', '4:3'),
              ('1:1', '1:1'),
              ('9:16', '9:16'),
            ],
            selected: _crop,
            onChanged: (v) => setState(() => _crop = v),
          ),
        ),
      if (_c.target == 'frames')
        row(
          t.optEvery,
          PillSegment<int>(
            values: [
              for (final s in const [1, 5, 10, 30]) (s, t.optSeconds(s)),
            ],
            selected: _every,
            onChanged: (v) => setState(() => _every = v),
          ),
        ),
      if (audio && !lossless && _c.target != 'cut')
        row(
          '${t.optBitrate} (kbit/s)',
          PillSegment<int>(
            values: const [
              (128, '128'),
              (192, '192'),
              (256, '256'),
              (320, '320'),
            ],
            selected: _kbps,
            onChanged: (v) => setState(() => _kbps = v),
          ),
        ),
      if (_c.category == ConvertCategory.image &&
          ['jpg', 'webp'].contains(_c.target))
        row(
          t.optQuality,
          PillSegment<String>(
            values: [
              ('source', t.optSource),
              ('high', t.optHigh),
              ('medium', t.optMedium),
            ],
            selected: _quality,
            onChanged: (v) => setState(() => _quality = v),
          ),
        ),
      if (_c.target == 'resize')
        row(
          t.optWidth,
          PillSegment<int>(
            values: const [
              (1920, '1920'),
              (1280, '1280'),
              (800, '800'),
              (400, '400'),
            ],
            selected: _width,
            onChanged: (v) => setState(() => _width = v),
          ),
        ),
      if (_c.target == 'cut')
        row(
          t.optKeep,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              time(_from, '00:00:00', const ValueKey('cut-from')),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  PhosphorRegular.arrowRight,
                  size: 16,
                  color: c.muted,
                ),
              ),
              time(_to, '00:00:30', const ValueKey('cut-to')),
            ],
          ),
        ),
      row(
        t.optOutDir,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Tooltip(
                message: outDir,
                child: Text(
                  outDir,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MmType.monoStyle(size: 12, color: c.muted),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Pressable(
              onTap: _changeDir,
              semanticLabel: t.getChange,
              child: Text(
                t.getChange,
                style: MmType.labelStrong.copyWith(
                  fontSize: 13,
                  color: c.accentStrong,
                ),
              ),
            ),
          ],
        ),
      ),
    ];

    final title = _c.tool
        ? choiceLabel(t, _c)
        : t.convTo(_c.target.toUpperCase());

    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MmRadius.xl),
        side: BorderSide(color: c.overlayBorder),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    height: 36,
                    constraints: const BoxConstraints(minWidth: 52),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _c.tool
                        ? Icon(_toolIcon(_c.target), size: 20, color: tint)
                        : Text(
                            _c.target.toUpperCase(),
                            style: MmType.monoStyle(
                              size: 12.5,
                              color: tint,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: MmType.title.copyWith(color: c.fg)),
                        Text(
                          choiceHelp(t, _c),
                          style: MmType.bodySm.copyWith(
                            fontSize: 12.5,
                            color: c.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Pressable(
                    onTap: () => Navigator.of(context).pop(),
                    semanticLabel: t.close,
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(PhosphorRegular.x, size: 20, color: c.muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: c.bg,
                          borderRadius: BorderRadius.circular(MmRadius.lg),
                          border: Border.all(color: c.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_files.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  t.convNoFiles,
                                  style: MmType.bodySm.copyWith(color: c.muted),
                                ),
                              ),
                            for (final f in _files)
                              SizedBox(
                                height: 44,
                                child: Row(
                                  children: [
                                    const SizedBox(width: 6),
                                    Icon(
                                      _categoryIcon(_c.category),
                                      size: 18,
                                      color: tint,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        f.split(RegExp(r'[\\/]')).last,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: MmType.labelStrong.copyWith(
                                          fontSize: 13,
                                          color: c.fg,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _size(context, f),
                                      style: MmType.monoStyle(
                                        size: 11.5,
                                        color: c.muted,
                                      ),
                                    ),
                                    Pressable(
                                      onTap: () =>
                                          setState(() => _files.remove(f)),
                                      semanticLabel: t.convRemove,
                                      child: SizedBox(
                                        width: 32,
                                        height: 32,
                                        child: Icon(
                                          PhosphorRegular.x,
                                          size: 16,
                                          color: c.muted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              children: [
                                _ToolButton(
                                  label: t.convAddFiles,
                                  icon: PhosphorRegular.plus,
                                  onTap: _pickFiles,
                                ),
                                _ToolButton(
                                  label: t.convAddFolder,
                                  icon: PhosphorRegular.folderPlus,
                                  onTap: _pickFolder,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...options,
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ToolButton(
                    label: t.cancel,
                    icon: PhosphorRegular.x,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  _ToolButton(
                    label: t.convAddToList(_files.length),
                    icon: PhosphorRegular.listPlus,
                    primary: true,
                    onTap: _files.isEmpty || _adding ? null : _add,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _size(BuildContext context, String path) {
    try {
      return bytes(context, File(path).lengthSync());
    } catch (_) {
      return '';
    }
  }
}

// ------------------------------------------------------------------ queue

class _Queue extends ConsumerWidget {
  const _Queue();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final s = ref.watch(convertProvider);
    Widget head(String text) => Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: MmType.overline.copyWith(color: c.faint),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.divider)),
          ),
          child: Row(
            children: [
              SizedBox(width: 80, child: head(t.colPreview)),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: head(t.colSource(s.jobs.length))),
              const SizedBox(width: 16),
              Expanded(child: head(t.colOutput)),
            ],
          ),
        ),
        Expanded(
          child: s.jobs.isEmpty
              ? Center(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(MmRadius.xl),
                      border: Border.all(color: c.lineStrong),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PhosphorRegular.arrowsClockwise,
                          size: 40,
                          color: c.faintIcon,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          t.convEmptyTitle,
                          style: MmType.title.copyWith(color: c.fg),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.convEmptyBody,
                          textAlign: TextAlign.center,
                          style: MmType.bodySm.copyWith(color: c.muted),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    for (final job in s.jobs) ...[
                      _JobRow(job: job, selected: job.id == s.selected),
                      const SizedBox(height: 8),
                    ],
                    Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(MmRadius.lg),
                        border: Border.all(color: c.lineStrong),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorRegular.fileArrowUp,
                            size: 18,
                            color: c.faint,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              t.convDropHint,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: MmType.bodySm.copyWith(
                                fontSize: 12.5,
                                color: c.faint,
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

class _JobRow extends ConsumerWidget {
  const _JobRow({required this.job, required this.selected});

  final ConvertJob job;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final cat = _categoryOf(job.category);
    final (tint, _) = _tint(c, cat);
    final src = job.source;
    final ext = job.inputs.first.split('.').last.toUpperCase();
    final meta = [
      if (src.size > BigInt.zero) bytes(context, src.size.toInt()),
      if (src.width > 0) '${src.width} × ${src.height}',
      if (src.kbps > 0) '${src.kbps} kbit/s',
      if (src.durationSecs > 0)
        _clock(Duration(milliseconds: (src.durationSecs * 1000).round())),
    ].join(' · ');
    final choice = ConvertChoice(cat, job.target);
    final tool = switch (job.target) {
      'join' ||
      'cut' ||
      'crop' ||
      'compress' ||
      'frames' ||
      'extract' ||
      'resize' => choiceLabel(t, choice),
      _ => t.convLineSame,
    };
    final out = switch (job.target) {
      'frames' => '→ JPG',
      'join' || 'compress' when cat == ConvertCategory.video => '→ MP4',
      'join' || 'extract' when cat == ConvertCategory.audio => '→ MP3',
      'cut' || 'crop' || 'resize' => '→ $ext',
      final f => '→ ${f.toUpperCase()}',
    };
    final (stateIcon, stateColor, stateText) = switch (job.state) {
      'converting' => (
        PhosphorRegular.arrowsClockwise,
        c.chipText,
        t.stConverting,
      ),
      'done' => (PhosphorRegular.checkCircle, c.accent, t.stDone),
      'stopped' => (PhosphorRegular.pauseCircle, c.muted, t.stStopped),
      'failed' => (PhosphorRegular.warningCircle, c.danger, t.stFailed),
      _ => (PhosphorRegular.clock, c.muted, t.stWaiting),
    };
    final right = switch (job.state) {
      'converting' => '${job.percent.round()}%',
      'done' when job.outSize != null => bytes(context, job.outSize!.toInt()),
      _ => '',
    };
    final title = job.inputs.length > 1
        ? '${job.name} + ${job.inputs.length - 1}'
        : job.name;
    return Pressable(
      onTap: () => ref.read(convertProvider.notifier).select(job.id),
      semanticLabel: '$title, $stateText',
      selected: selected,
      borderRadius: BorderRadius.circular(MmRadius.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? c.selected : c.surface,
          borderRadius: BorderRadius.circular(MmRadius.lg),
          border: Border.all(color: selected ? c.chipBorder : c.line),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              height: 45,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: c.hatchA,
                        borderRadius: BorderRadius.circular(MmRadius.md),
                      ),
                      child: Icon(_categoryIcon(cat), size: 22, color: tint),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(MmRadius.xs),
                      ),
                      child: Text(
                        ext,
                        style: MmType.monoStyle(size: 9.5, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MmType.labelStrong.copyWith(
                      fontSize: 13.5,
                      color: c.fg,
                    ),
                  ),
                  if (meta.isNotEmpty)
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MmType.monoStyle(size: 11.5, color: c.muted),
                    ),
                  Text(
                    tool,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MmType.caption.copyWith(color: c.faint),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          out,
                          style: MmType.monoStyle(
                            size: 13,
                            color: c.fg,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        right,
                        style: MmType.monoStyle(size: 12, color: c.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(MmRadius.pill),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(
                        end: job.state == 'done'
                            ? 1
                            : (job.percent / 100).clamp(0.0, 1.0),
                      ),
                      duration: const Duration(milliseconds: 900),
                      builder: (context, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 4,
                        backgroundColor: c.line,
                        color: job.state == 'converting' || job.state == 'done'
                            ? c.accent
                            : c.faintIcon,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Tooltip(
                    message: job.error ?? '',
                    child: Row(
                      children: [
                        Icon(stateIcon, size: 15, color: stateColor),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            job.state == 'failed' && job.error != null
                                ? '$stateText · ${job.error}'
                                : stateText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MmType.captionStrong.copyWith(
                              fontSize: 12,
                              color: stateColor,
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
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- status bar

class _StatusBar extends ConsumerWidget {
  const _StatusBar({required this.state});

  final ConvertState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final ctl = ref.read(convertProvider.notifier);
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: c.sidebar,
        border: Border(top: BorderSide(color: c.divider)),
      ),
      child: Row(
        children: [
          Icon(PhosphorRegular.folder, size: 15, color: c.muted),
          const SizedBox(width: 6),
          Flexible(
            child: Tooltip(
              message: state.outDir,
              child: Text(
                state.outDir,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MmType.monoStyle(size: 11.5, color: c.muted),
              ),
            ),
          ),
          const SizedBox(width: 14),
          _Check(
            label: t.convMulti,
            value: state.multi,
            onChanged: ctl.setMulti,
          ),
          const Spacer(),
          Text(
            '${t.convElapsed} ',
            style: MmType.caption.copyWith(color: c.muted),
          ),
          Text(
            _clock(state.elapsed),
            style: MmType.monoStyle(size: 12, color: c.fg),
          ),
          const SizedBox(width: 14),
          _Check(
            label: t.convShutdown,
            value: state.shutdown,
            onChanged: ctl.setShutdown,
          ),
          const SizedBox(width: 14),
          _Check(
            label: t.convNotify,
            value: state.notify,
            onChanged: ctl.setNotify,
          ),
        ],
      ),
    );
  }
}

/// The handoff's 14 px check box.
class _Check extends StatelessWidget {
  const _Check({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Pressable(
      onTap: () => onChanged(!value),
      semanticLabel: label,
      selected: value,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: value ? c.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: value ? null : Border.all(color: c.faintIcon, width: 1.5),
            ),
            child: value
                ? const Icon(
                    PhosphorRegular.check,
                    size: 12,
                    color: Color(0xFF062320),
                  )
                : null,
          ),
          const SizedBox(width: 6),
          Text(label, style: MmType.caption.copyWith(color: c.muted)),
        ],
      ),
    );
  }
}
