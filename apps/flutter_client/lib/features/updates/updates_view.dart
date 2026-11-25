import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitType;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/pressable.dart';
import '../../l10n/app_localizations.dart';
import '../get/get_data.dart';
import '../playback/playback.dart';
import '../settings/settings_screen.dart';
import '../torrents/torrents_data.dart';
import 'updates_data.dart';

/// Messages shown above any screen (update available, kept ready).
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Closes the app after the installer started (tests answer it): through
/// the exit guard, so torrents stop and downloads flush first.
final appCloserProvider = Provider<Future<void> Function()>(
  (_) =>
      () => ServicesBinding.instance.exitApplication(AppExitType.cancelable),
);

String _mib(BuildContext context, int bytes) {
  final fr = Localizations.localeOf(context).languageCode == 'fr';
  final n = NumberFormat('#,##0.#', fr ? 'fr' : 'en').format(bytes / 1048576);
  return '$n ${fr ? 'Mio' : 'MiB'}';
}

String _errorText(L10n t, String error) => switch (error) {
  'update_converting' => t.updConverting,
  'update_network' => t.updNetwork,
  'update_permission' => t.updAllowInstall,
  _ => error,
};

/// Looks for an update 15 s after launch and every six hours while the app
/// is in front (0.1.x `UpdateMonitor`); says so when one is found.
class UpdateMonitor extends ConsumerStatefulWidget {
  const UpdateMonitor({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UpdateMonitor> createState() => _UpdateMonitorState();
}

class _UpdateMonitorState extends ConsumerState<UpdateMonitor> {
  Timer? _first;
  Timer? _every;

  @override
  void initState() {
    super.initState();
    if (!ref.read(updatesApiProvider).enabled) return;
    // A download finished (or interrupted) in an earlier session.
    unawaited(ref.read(updatesProvider.notifier).restore());
    _first = Timer(const Duration(seconds: 15), _check);
    _every = Timer.periodic(const Duration(hours: 6), (_) => _check());
  }

  @override
  void dispose() {
    _first?.cancel();
    _every?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    final front =
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.hidden &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused;
    if (!front) return;
    final release = await ref.read(updatesProvider.notifier).check();
    final messenger = rootMessengerKey.currentState;
    final context = rootMessengerKey.currentContext;
    if (release == null || messenger == null || context == null) return;
    if (!context.mounted) return;
    final t = L10n.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(t.updAvailable(release.version)),
        action: SnackBarAction(
          label: t.updView,
          // The messenger sits above the router: go through it directly.
          onPressed: () =>
              ref.read(routerProvider).go(sectionPath(SettingsSection.updates)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Settings › Mises à jour, ported from 0.1.x (UPD-01..07): never installs
/// without the user; verified before installing.
class UpdatesSettings extends ConsumerStatefulWidget {
  const UpdatesSettings({super.key});

  @override
  ConsumerState<UpdatesSettings> createState() => _UpdatesSettingsState();
}

class _UpdatesSettingsState extends ConsumerState<UpdatesSettings> {
  Timer? _progress;
  int _done = 0;
  bool _sharing = false;

  @override
  void dispose() {
    _progress?.cancel();
    super.dispose();
  }

  /// Progress read once a second while downloading.
  void _follow(UpdatePhase phase) {
    if (phase == UpdatePhase.downloading && _progress == null) {
      _progress = Timer.periodic(const Duration(seconds: 1), (_) {
        final n = ref.read(updatesApiProvider).progress();
        if (mounted) setState(() => _done = n);
      });
    } else if (phase != UpdatePhase.downloading) {
      _progress?.cancel();
      _progress = null;
    }
  }

  /// UPD-04: torrent sharing stops with the app; said before installing.
  Future<void> _checkSharing() async {
    try {
      final s = await ref.read(torrentsApiProvider).list();
      final sharing =
          s.enabled &&
          s.rows.any((r) => r.phase != 'paused' && r.phase != 'error');
      if (mounted && sharing != _sharing) setState(() => _sharing = sharing);
    } catch (_) {}
  }

  Future<void> _install() async {
    if (await ref.read(updatesProvider.notifier).install()) {
      await ref.read(appCloserProvider)();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final api = ref.watch(updatesApiProvider);
    final s = ref.watch(updatesProvider);
    final notifier = ref.read(updatesProvider.notifier);
    _follow(s.phase);
    if (!api.enabled) {
      return SettingsGroup(
        rows: [
          SettingsRow(
            title: t.updVersion(appVersion.isEmpty ? '—' : appVersion),
            body: t.updDevBuild,
            control: const SizedBox(),
          ),
        ],
      );
    }

    final downloads = ref.watch(downloadsProvider);
    final summary = DownloadsSummary.of(downloads);
    final converting = downloads.ordered.any((x) => x.state == 'processing');
    final playing = ref.watch(
      playbackProvider.select((p) => p.value?.isPlaying ?? false),
    );
    if (s.ready) unawaited(_checkSharing());

    final release = s.release;
    final size = release == null ? '' : _mib(context, release.size.toInt());
    final done = s.phase == UpdatePhase.downloading ? _done : s.downloaded;
    final channel = s.channel == 'beta' ? t.updBeta : 'Stable';
    final error = s.error.isEmpty ? null : _errorText(t, s.error);

    Widget button(String label, VoidCallback? onTap, {bool primary = false}) =>
        Pressable(
          onTap: onTap,
          semanticLabel: label,
          child: Opacity(
            opacity: onTap == null ? 0.6 : 1,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: primary ? c.accent : null,
                borderRadius: BorderRadius.circular(MmRadius.sm),
                border: primary ? null : Border.all(color: c.lineStrong),
              ),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: MmType.labelStrong.copyWith(
                    fontSize: 13.5,
                    color: primary ? const Color(0xFF062320) : c.fg,
                  ),
                ),
              ),
            ),
          ),
        );

    final rows = <Widget>[];
    if (release != null) {
      final notes = release.notes
          .split('\n')
          .map((l) => l.replaceFirst(RegExp(r'^\s*[-•*]\s*'), '').trim())
          .where((l) => l.isNotEmpty)
          .toList();
      final warnings = [
        if (summary.running.isNotEmpty)
          t.updActive('${summary.running.length}'),
        if (playing) t.updStopsPlayback,
        if (_sharing) t.updStopsSharing,
        if (converting) t.updConverting,
      ];
      final title = s.ready
          ? t.updReady(release.version)
          : s.phase == UpdatePhase.downloading
          ? t.updDownloading(release.version)
          : t.updAvailable(release.version);
      final badge = s.ready
          ? t.updBadgeReady
          : s.phase == UpdatePhase.downloading
          ? t.updBadgeDownloading
          : t.updBadge;
      rows.add(
        Semantics(
          container: true,
          label: t.updAvailable(release.version),
          child: Container(
            margin: const EdgeInsets.only(bottom: 22),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(MmRadius.card),
              border: Border.all(color: c.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c.bg,
                        borderRadius: BorderRadius.circular(MmRadius.md),
                        border: Border.all(color: c.line),
                      ),
                      child: Icon(
                        PhosphorRegular.downloadSimple,
                        size: 20,
                        color: c.accentStrong,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: MmType.heading.copyWith(color: c.fg),
                          ),
                          Text(
                            t.updInstalled(s.installed, channel, size),
                            style: MmType.monoStyle(size: 12, color: c.muted),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: s.ready ? c.accentSubtle : c.surface2,
                        borderRadius: BorderRadius.circular(MmRadius.xs),
                      ),
                      child: Text(
                        badge,
                        style: MmType.captionStrong.copyWith(
                          fontSize: 11.5,
                          color: s.ready ? c.chipText : c.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  for (final n in notes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '•  $n',
                        style: MmType.bodySm.copyWith(color: c.fg),
                      ),
                    ),
                ],
                if (s.phase == UpdatePhase.downloading) ...[
                  const SizedBox(height: 14),
                  Semantics(
                    label: t.updProgress,
                    child: LinearProgressIndicator(
                      value: release.size > BigInt.zero
                          ? (done / release.size.toInt()).clamp(0.0, 1.0)
                          : null,
                      color: c.accent,
                      backgroundColor: c.line,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.updProgressText(_mib(context, done), size),
                    style: MmType.monoStyle(size: 12, color: c.muted),
                  ),
                ],
                if (s.phase == UpdatePhase.available && done > 0) ...[
                  const SizedBox(height: 10),
                  Text(
                    t.updPartial(_mib(context, done), size),
                    style: MmType.monoStyle(size: 12, color: c.muted),
                  ),
                ],
                if (s.ready) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(
                        PhosphorRegular.sealCheck,
                        size: 16,
                        color: c.chipText,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        t.updVerified,
                        style: MmType.captionStrong.copyWith(
                          fontSize: 12.5,
                          color: c.chipText,
                        ),
                      ),
                    ],
                  ),
                  for (final w in warnings)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            PhosphorRegular.warning,
                            size: 16,
                            color: c.warning,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              w,
                              style: MmType.captionStrong.copyWith(
                                fontSize: 12.5,
                                color: c.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      error,
                      style: MmType.caption.copyWith(
                        fontSize: 12.5,
                        color: c.danger,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (s.phase == UpdatePhase.available)
                      button(
                        done > 0 ? t.updResume : t.updDownload(size),
                        notifier.download,
                        primary: true,
                      ),
                    if (s.phase == UpdatePhase.downloading)
                      button(t.cancel, notifier.cancel),
                    if (s.ready) ...[
                      button(
                        s.phase == UpdatePhase.installing
                            ? t.updInstalling
                            : t.updInstall,
                        s.phase == UpdatePhase.installing || converting
                            ? null
                            : _install,
                        primary: true,
                      ),
                      button(
                        t.updLater,
                        s.phase == UpdatePhase.installing
                            ? null
                            : () => ScaffoldMessenger.maybeOf(context)
                                  ?.showSnackBar(
                                    SnackBar(content: Text(t.updKeptReady)),
                                  ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  Platform.isAndroid ? t.updAndroidNote : t.updWindowsNote,
                  style: MmType.caption.copyWith(
                    fontSize: 12.5,
                    height: 1.45,
                    color: c.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...rows,
        SettingsGroup(
          rows: [
            if (release == null)
              SettingsRow(
                title: s.phase == UpdatePhase.checking
                    ? t.updChecking
                    : s.checked
                    ? t.updLatest(s.installed)
                    : t.updVersion(s.installed),
                body: error ?? t.updAutoCheck,
                control: button(
                  t.updCheck,
                  s.phase == UpdatePhase.checking ? null : notifier.check,
                ),
              ),
            SettingsRow(
              title: t.updChannel,
              body: t.updChannelDesc,
              control: SettingsMenu<String>(
                label: t.updChannel,
                values: [('stable', 'Stable'), ('beta', t.updBeta)],
                selected: s.channel,
                onChanged: (v) => notifier.setPrefs(channel: v),
              ),
            ),
            SettingsRow(
              title: t.updAuto,
              body: t.updAutoDesc,
              control: Switch(
                value: s.autoDownload,
                activeThumbColor: c.accent,
                onChanged: (v) => notifier.setPrefs(autoDownload: v),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
