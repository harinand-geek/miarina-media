import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/pressable.dart';
import '../../l10n/app_localizations.dart';
import '../get/get_data.dart' show etaLabel, formatBytes;
import '../get/get_screens.dart' show revealProvider;
import 'torrents_data.dart';

// Obtenir › Torrents (Windows v2 screen 9, TOR-01..04), ported from the
// Tauri app: nothing runs until the session is enabled; sharing is shown
// and stoppable at any time.

String _lang(BuildContext context) =>
    Localizations.localeOf(context).languageCode;

/// "4,2 Mo/s", "310 Ko/s" (as the Tauri app: MB/s from 1 MB, else KB/s).
String _rate(BuildContext context, double bytesPerSec) {
  final fr = _lang(context) == 'fr';
  if (bytesPerSec >= 1024 * 1024) {
    final v = (bytesPerSec / (1024 * 1024)).toStringAsFixed(1);
    return '${fr ? v.replaceAll('.', ',') : v} ${fr ? 'Mo/s' : 'MB/s'}';
  }
  return '${(bytesPerSec / 1024).round()} ${fr ? 'Ko/s' : 'KB/s'}';
}

String _size(BuildContext context, int bytes) =>
    formatBytes(bytes, lang: _lang(context));

/// The message of a failure, from the core's stable codes.
String torrentError(L10n t, Object e) {
  final text = '$e';
  if (text.contains('torrent_link')) return t.torLinkInvalid;
  if (text.contains('torrent_duplicate')) return t.torDuplicate;
  if (text.contains('torrent_selection')) return t.torSelection;
  if (text.contains('torrent_session_changed') ||
      text.contains('torrent_expired')) {
    return t.torSessionChanged;
  }
  return t.torFailed;
}

class TorrentsScreen extends ConsumerStatefulWidget {
  const TorrentsScreen({super.key});

  @override
  ConsumerState<TorrentsScreen> createState() => _TorrentsScreenState();
}

class _TorrentsScreenState extends ConsumerState<TorrentsScreen> {
  TorrentSnapshot? _snapshot;
  TorrentPreview? _preview;
  final _selected = <int>{};
  bool _sequential = false;
  bool _busy = false;
  String? _error;
  final _magnet = TextEditingController();
  Timer? _poll;

  TorrentsApi get _api => ref.read(torrentsApiProvider);

  @override
  void initState() {
    super.initState();
    _refresh();
    // While the screen is shown, as the Tauri app.
    _poll = Timer.periodic(
      const Duration(milliseconds: 1500),
      (_) => _refresh(),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    _magnet.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final next = await _api.list();
      if (mounted) setState(() => _snapshot = next);
    } catch (_) {}
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    final t = L10n.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await _refresh();
    } catch (e) {
      if (mounted) setState(() => _error = torrentError(t, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _inspect({String? magnet, String? file}) => _run(() async {
    final next = await _api.preview(magnet: magnet, file: file);
    setState(() {
      _preview = next;
      _selected
        ..clear()
        ..addAll(next.files.map((f) => f.index));
    });
  });

  Future<void> _openFile() async {
    final t = L10n.of(context);
    final file = await ref.read(torrentFilePickerProvider)(t.torOpenFile);
    if (file != null) await _inspect(file: file);
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final s = _snapshot;
    final enabled = s?.enabled ?? false;
    final rows = s?.rows ?? const <TorrentRow>[];
    final sharing = rows.any(
      (r) => r.phase == 'downloading' || r.phase == 'finished',
    );
    final pill = !enabled
        ? t.torSessionOff
        : sharing
        ? t.torSessionSharing
        : t.torSessionOn;
    final preview = _preview;

    return ListView(
      padding: const EdgeInsets.fromLTRB(48, 32, 48, 32),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 16,
          runSpacing: 12,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t.getNavTorrents,
                    style: MmType.display.copyWith(fontSize: 24, color: c.fg),
                  ),
                  const SizedBox(height: 4),
                  Text(t.torSub, style: MmType.bodySm.copyWith(color: c.muted)),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: enabled && sharing ? c.coralSubtle : c.surface2,
                      borderRadius: BorderRadius.circular(MmRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: enabled && sharing ? c.coralStrong : c.muted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          pill,
                          style: MmType.captionStrong.copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: enabled && sharing ? c.coralStrong : c.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _Secondary(
                  enabled ? t.torStopAll : t.torEnable,
                  _busy
                      ? null
                      : () => _run(() async {
                          if (enabled) {
                            await _api.disable();
                            setState(() => _preview = null);
                          } else {
                            await _api.enable();
                          }
                        }),
                  icon: enabled
                      ? PhosphorRegular.minusCircle
                      : PhosphorRegular.playCircle,
                  color: enabled ? c.danger : null,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(MmRadius.lg),
              border: Border.all(color: c.danger.withValues(alpha: 0.4)),
            ),
            child: Text(_error!, style: MmType.bodySm.copyWith(color: c.fg)),
          ),
          const SizedBox(height: 20),
        ],
        if (enabled) ...[
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: c.bg,
                    borderRadius: BorderRadius.circular(MmRadius.sm),
                    border: Border.all(color: c.lineStrong),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        PhosphorRegular.shareNetwork,
                        size: 18,
                        color: c.muted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          key: const ValueKey('magnet'),
                          controller: _magnet,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (v) =>
                              v.trim().isEmpty ? null : _inspect(magnet: v),
                          style: MmType.monoStyle(size: 13, color: c.fg),
                          cursorColor: c.accent,
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: 'magnet:?xt=urn:btih:…',
                            hintStyle: MmType.monoStyle(
                              size: 13,
                              color: c.faint,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _Primary(
                _busy ? t.torWait : t.torInspect,
                _busy || _magnet.text.trim().isEmpty
                    ? null
                    : () => _inspect(magnet: _magnet.text),
                height: 44,
              ),
              const SizedBox(width: 10),
              _Secondary(
                t.torOpenFile,
                _busy ? null : _openFile,
                icon: PhosphorRegular.filePlus,
                height: 44,
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        if (preview != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(MmRadius.md),
              border: Border.all(color: c.accent),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  preview.name,
                  style: MmType.labelStrong.copyWith(fontSize: 14, color: c.fg),
                ),
                const SizedBox(height: 8),
                Text(
                  t.torPreviewNote,
                  style: MmType.caption.copyWith(
                    fontSize: 12.5,
                    color: c.muted,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 256),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final f in preview.files)
                        _Check(
                          checked: _selected.contains(f.index),
                          onChanged: (on) => setState(
                            () => on
                                ? _selected.add(f.index)
                                : _selected.remove(f.index),
                          ),
                          label: f.path,
                          trailing: _size(context, f.size.toInt()),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _Check(
                  checked: _sequential,
                  onChanged: (on) => setState(() => _sequential = on),
                  label: t.torSequential,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Primary(
                      t.torStart,
                      _busy || _selected.isEmpty
                          ? null
                          : () => _run(() async {
                              await _api.start(
                                preview.hash,
                                _selected.toList()..sort(),
                                sequential: _sequential,
                              );
                              setState(() => _preview = null);
                            }),
                    ),
                    const SizedBox(width: 10),
                    _Secondary(
                      t.cancel,
                      _busy ? null : () => setState(() => _preview = null),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        for (final row in rows) ...[
          _TorrentCard(
            row: row,
            busy: _busy,
            enabled: enabled,
            act: (action) => _run(() => _api.action(row.hash, action)),
          ),
          const SizedBox(height: 10),
        ],
        if (enabled && rows.isEmpty && preview == null)
          Container(
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MmRadius.md),
              border: Border.all(color: c.lineStrong),
            ),
            child: Text(
              t.torEmpty,
              textAlign: TextAlign.center,
              style: MmType.bodySm.copyWith(color: c.muted),
            ),
          ),
        if (enabled && s != null) ...[
          const SizedBox(height: 10),
          _Limits(
            snapshot: s,
            busy: _busy,
            share: (ratio, hours) => _run(() async {
              final messenger = ScaffoldMessenger.maybeOf(context);
              await _api.sharing(ratio, hours);
              if (mounted) {
                messenger?.showSnackBar(
                  SnackBar(
                    content: Text(t.torLimitsSaved),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }),
            apply: (down, up) => _run(() async {
              final messenger = ScaffoldMessenger.maybeOf(context);
              await _api.limits(down, up);
              if (mounted) {
                messenger?.showSnackBar(
                  SnackBar(
                    content: Text(t.torLimitsSaved),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }),
          ),
        ],
      ],
    );
  }
}

class _Primary extends StatelessWidget {
  const _Primary(this.label, this.onTap, {this.height = 36});

  final String label;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.accent,
            borderRadius: BorderRadius.circular(MmRadius.sm),
          ),
          child: Text(
            label,
            style: MmType.labelStrong.copyWith(
              fontSize: 13.5,
              color: const Color(0xFF062320),
            ),
          ),
        ),
      ),
    );
  }
}

class _Secondary extends StatelessWidget {
  const _Secondary(
    this.label,
    this.onTap, {
    this.icon,
    this.color,
    this.height = 36,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final fg = color ?? c.fg;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: c.surface2,
            borderRadius: BorderRadius.circular(MmRadius.sm),
            border: Border.all(color: c.lineStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: MmType.labelStrong.copyWith(fontSize: 13, color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({
    required this.checked,
    required this.onChanged,
    required this.label,
    this.trailing,
  });

  final bool checked;
  final ValueChanged<bool> onChanged;
  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Pressable(
      onTap: () => onChanged(!checked),
      semanticLabel: label,
      selected: checked,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              checked ? PhosphorFill.checkSquare : PhosphorRegular.square,
              size: 18,
              color: checked ? c.accent : c.muted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: MmType.bodySm.copyWith(color: c.fg)),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: MmType.monoStyle(size: 12, color: c.muted),
              ),
          ],
        ),
      ),
    );
  }
}

class _TorrentCard extends StatelessWidget {
  const _TorrentCard({
    required this.row,
    required this.busy,
    required this.enabled,
    required this.act,
  });

  final TorrentRow row;
  final bool busy;
  final bool enabled;
  final void Function(String action) act;

  Future<void> _remove(BuildContext context) async {
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
          t.torRemoveTitle,
          style: MmType.title.copyWith(color: c.fg),
        ),
        content: Text(
          t.torRemoveBody,
          style: MmType.body.copyWith(color: c.fgSoft),
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
              t.torRemove,
              style: MmType.labelStrong.copyWith(color: c.danger),
            ),
          ),
        ],
      ),
    );
    if (ok == true) act('remove');
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final total = row.total.toInt();
    final done = row.done.toInt();
    final ratio = total > 0
        ? (row.uploaded.toInt() / total).toStringAsFixed(1)
        : '0.0';
    final stats = <(IconData, String, String, Color?)>[];
    late IconData icon;
    late String meta;
    switch (row.phase) {
      case 'finished':
        icon = PhosphorRegular.checkCircle;
        meta = t.torDoneSharing(_size(context, total));
        stats.addAll([
          (
            PhosphorRegular.arrowUp,
            t.torSharing,
            _rate(context, row.upSpeed),
            c.coral,
          ),
          (PhosphorRegular.equals, t.torRatio, ratio, null),
          (PhosphorRegular.user, t.torPeers, '${row.peers}', null),
        ]);
      case 'paused':
        icon = PhosphorRegular.pauseCircle;
        meta = total > 0 && done >= total
            ? t.torDoneMeta(_size(context, total))
            : t.torPausedMeta(_size(context, done), _size(context, total));
        stats.add((PhosphorRegular.equals, t.torRatio, ratio, null));
      case 'error':
        icon = PhosphorRegular.warningCircle;
        meta = t.torError;
      case 'checking':
        icon = PhosphorRegular.arrowsClockwise;
        meta = t.torChecking;
      case 'inactive':
        icon = PhosphorRegular.minusCircle;
        meta = t.torInactive;
      default:
        icon = PhosphorRegular.downloadSimple;
        meta = '${_size(context, done)} / ${_size(context, total)}';
        stats.addAll([
          (
            PhosphorRegular.downloadSimple,
            t.torDown,
            _rate(context, row.downSpeed),
            c.accentStrong,
          ),
          (PhosphorRegular.arrowUp, t.torUp, _rate(context, row.upSpeed), null),
          (PhosphorRegular.user, t.torPeers, '${row.peers}', null),
          if (row.downSpeed > 0)
            (
              PhosphorRegular.clock,
              t.torLeft,
              etaLabel(((total - done) / row.downSpeed).round()),
              null,
            ),
        ]);
    }
    final stopped = row.phase == 'paused' || row.phase == 'error';
    final (primaryIcon, primaryLabel, primaryAction) = stopped
        ? (PhosphorRegular.play, t.torResume, 'resume')
        : row.phase == 'finished'
        ? (PhosphorRegular.minusCircle, t.torStopSharing, 'pause')
        : (PhosphorRegular.pause, t.pause, 'pause');
    final percent = total > 0 ? done / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(MmRadius.md),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: row.phase == 'error' ? c.danger : c.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MmType.labelStrong.copyWith(
                        fontSize: 13.5,
                        color: c.fg,
                      ),
                    ),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MmType.monoStyle(size: 11.5, color: c.muted),
                    ),
                  ],
                ),
              ),
              _Secondary(
                primaryLabel,
                busy ||
                        !enabled ||
                        row.phase == 'inactive' ||
                        row.phase == 'checking'
                    ? null
                    : () => act(primaryAction),
                icon: primaryIcon,
                height: 32,
              ),
              Consumer(
                builder: (context, ref, _) => _IconAction(
                  PhosphorRegular.folderOpen,
                  t.getOpenFolder,
                  busy ? null : () => ref.read(revealProvider)(row.folder),
                ),
              ),
              _IconAction(
                PhosphorRegular.x,
                t.torRemoveNamed(row.name),
                busy || !enabled ? null : () => _remove(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(MmRadius.pill),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 4,
              color: row.phase == 'error'
                  ? c.danger
                  : row.phase == 'paused'
                  ? c.muted
                  : c.accent,
              backgroundColor: c.line,
            ),
          ),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 20,
              runSpacing: 6,
              children: [
                for (final (icon, label, value, tone) in stats)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 15, color: tone ?? c.muted),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: MmType.captionStrong.copyWith(
                          fontSize: 12,
                          color: c.fg,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        value,
                        style: MmType.monoStyle(size: 12, color: c.muted),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Tooltip(
      message: label,
      child: Pressable(
        onTap: onTap,
        semanticLabel: label,
        child: Opacity(
          opacity: onTap == null ? 0.4 : 1,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(icon, size: 18, color: c.muted),
          ),
        ),
      ),
    );
  }
}

/// Rate limits, and when finished torrents stop sharing (target ratio,
/// seeding time in hours; 0 = no rule).
class _Limits extends StatefulWidget {
  const _Limits({
    required this.snapshot,
    required this.busy,
    required this.apply,
    required this.share,
  });

  final TorrentSnapshot snapshot;
  final bool busy;
  final void Function(int download, int upload) apply;
  final void Function(double ratio, int hours) share;

  @override
  State<_Limits> createState() => _LimitsState();
}

class _LimitsState extends State<_Limits> {
  late final _down = TextEditingController(
    text: '${widget.snapshot.downloadLimit.toInt() ~/ 1024}',
  );
  late final _up = TextEditingController(
    text: '${widget.snapshot.uploadLimit.toInt() ~/ 1024}',
  );
  late final _ratio = TextEditingController(
    text: _ratioText(widget.snapshot.targetRatio),
  );
  late final _hours = TextEditingController(
    text: '${widget.snapshot.seedHours}',
  );

  static String _ratioText(double r) =>
      r == r.roundToDouble() ? r.toStringAsFixed(1) : '$r';

  @override
  void dispose() {
    _down.dispose();
    _up.dispose();
    _ratio.dispose();
    _hours.dispose();
    super.dispose();
  }

  void _commitSharing() {
    final ratio = double.tryParse(_ratio.text.trim().replaceAll(',', '.'));
    final hours = int.tryParse(_hours.text.trim()) ?? 0;
    final r = (ratio ?? 0).clamp(0.0, 100.0);
    if (r == widget.snapshot.targetRatio &&
        hours == widget.snapshot.seedHours) {
      return;
    }
    widget.share(r, hours.clamp(0, 24 * 365));
  }

  void _commit() {
    final down = int.tryParse(_down.text.trim()) ?? 0;
    final up = int.tryParse(_up.text.trim()) ?? 0;
    final now = (
      widget.snapshot.downloadLimit.toInt() ~/ 1024,
      widget.snapshot.uploadLimit.toInt() ~/ 1024,
    );
    if ((down, up) == now) return;
    widget.apply(down * 1024, up * 1024);
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    Widget field(
      String label,
      String hint,
      TextEditingController ctrl,
      Key key, {
      bool decimal = false,
      VoidCallback? commit,
      String? suffix,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: MmType.labelStrong.copyWith(fontSize: 12.5, color: c.fg),
        ),
        const SizedBox(height: 6),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: c.bg,
            borderRadius: BorderRadius.circular(MmRadius.sm),
            border: Border.all(color: c.lineStrong),
          ),
          child: Focus(
            onFocusChange: (f) {
              if (!f) (commit ?? _commit)();
            },
            child: TextField(
              key: key,
              controller: ctrl,
              enabled: !widget.busy,
              keyboardType: TextInputType.numberWithOptions(decimal: decimal),
              inputFormatters: [
                decimal
                    ? FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                    : FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(7),
              ],
              onSubmitted: (_) => (commit ?? _commit)(),
              style: MmType.monoStyle(size: 12.5, color: c.fg),
              cursorColor: c.accent,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                suffixText: suffix,
                suffixStyle: MmType.monoStyle(size: 12.5, color: c.muted),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          hint,
          style: MmType.caption.copyWith(fontSize: 11.5, color: c.muted),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MmRadius.md),
        border: Border.all(color: c.line),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final cols = box.maxWidth >= 800 ? 4 : 2;
          const gap = 16.0;
          final w = (box.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              SizedBox(
                width: w,
                child: field(
                  t.torDownLimit,
                  t.torUnlimited,
                  _down,
                  const ValueKey('limit-down'),
                ),
              ),
              SizedBox(
                width: w,
                child: field(
                  t.torUpLimit,
                  t.torCapped,
                  _up,
                  const ValueKey('limit-up'),
                ),
              ),
              SizedBox(
                width: w,
                child: field(
                  t.torTargetRatio,
                  t.torRatioDesc,
                  _ratio,
                  const ValueKey('share-ratio'),
                  decimal: true,
                  commit: _commitSharing,
                ),
              ),
              SizedBox(
                width: w,
                child: field(
                  t.torSeedTime,
                  t.torSeedDesc,
                  _hours,
                  const ValueKey('share-hours'),
                  commit: _commitSharing,
                  suffix: 'h',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
